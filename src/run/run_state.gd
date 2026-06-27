class_name RunState
extends RefCounted

# 一局 run:三章,每章节点序列 小怪→奇遇→精英→boss。成长跨节点累积。

const MEDITATE_HEAL := 12
const EVOLVE_AT := [3, 6]
const NODE_SEQ := ["grunt", "encounter", "elite", "boss"]
const CHAPTERS := 3
const CHAPTER_TITLES := ["第一章 · 毒蛛潭", "第二章 · 断魂崖", "第三章 · 华山之巅"]

# 开局构筑在场景间传递(change_scene 不能传参)
static var pending_menpai: StringName = &"shaolin"
static var pending_neigong: StringName = &"yijinjing"
static var pending_arts: Array = [&"luohan", &"chain_kick"]   # 开局选的 2 门初级功夫

var menpai_id: StringName
var neigong_id: StringName
var neigong_level: int = 0
var learned: Array = []             # 已领悟功夫(绝学)id;开局=选的 2 门初级
var mastery: Dictionary = {}
var weight: Dictionary = {}
var evo: Dictionary = {}
var weapon_bonus: int = 0           # 神兵:并入攻击力(+attack)
var node_index: int = 0
var player_hp: int = 40
var max_hp: int = 40
# 基础属性(攻/防默认0不改平衡;血气见 max_hp/base_max_qi)
var base_attack: int = 10        # 基础攻击力(基准10 → 招式默认伤害不变)
var base_dmg_inc: int = 0        # 基础伤害增加%(武器/普通强化,加法区)
var base_extra_dmg: int = 0      # 额外伤害增加%(稀有,独立乘区)
var base_armor: int = 0          # 防御数值(递减减伤)
var base_max_qi: int = 10
# 预留字段(机制后续):装备/暗器/物品/银两/声望/持续debuff
var equipment: Dictionary = {}        # 已穿戴 slot→id
var owned_equipment: Array = []       # 拥有的全部装备 id(含未穿戴)
var hidden_weapons: Dictionary = {}   # 暗器 id→数量
var inventory: Array = []
var money: int = 0
var reputation: int = 0               # 善恶侠名
var conditions: Array = []            # 跨场持续状态(内伤/中毒…)

func _init(menpai := &"shaolin", neigong := &"", arts := []) -> void:
	menpai_id = menpai
	neigong_id = neigong if neigong != &"" else Neigong.starter(menpai)
	learned = (arts.duplicate() if not arts.is_empty() else Menpai.starter_pool(menpai).slice(0, 2))
	node_index = 0
	player_hp = 40; max_hp = 40
	neigong_level = 0
	mastery = {}; weight = {}; evo = {}; weapon_bonus = 0
	base_attack = 10; base_dmg_inc = 0; base_extra_dmg = 0; base_armor = 0; base_max_qi = 10
	equipment = {}; owned_equipment = []; hidden_weapons = {}; inventory = []; money = 0; reputation = 0; conditions = []

# --- 节点 / 章节 ---
func current_node() -> Dictionary:
	var per := NODE_SEQ.size()
	return {"chapter": node_index / per, "type": NODE_SEQ[node_index % per], "in_chapter": node_index % per}

func advance_node() -> void:
	node_index += 1

func is_complete() -> bool:
	return node_index >= CHAPTERS * NODE_SEQ.size()

func chapter_title() -> String:
	return CHAPTER_TITLES[clampi(current_node()["chapter"], 0, 2)]

func current_enemy() -> Dictionary:
	var n := current_node()
	return Enemies.spawn(n["chapter"], n["type"])

# --- 内功 ---
func qi_bonus() -> int:
	return neigong_level * Neigong.qi_per_level(neigong_id)

# --- 装备(武器/防具/饰品,各槽一件;属性走 modifier 聚合) ---
# 获得装备:进行囊;若该槽空,自动穿上。
func obtain_equipment(id: StringName) -> void:
	var d := Equips.def(id)
	if d == null:
		return
	if not owned_equipment.has(id):
		owned_equipment.append(id)
	if not equipment.has(d.slot):
		equip(id)

# 穿上(同槽替换;旧的退回行囊不丢)。
func equip(id: StringName) -> void:
	var d := Equips.def(id)
	if d == null:
		return
	if not owned_equipment.has(id):
		owned_equipment.append(id)
	equipment[d.slot] = id   # 同槽替换
	for art in d.grants:      # 武器解锁专属功夫
		learn(art)

func unequip(slot: StringName) -> void:
	equipment.erase(slot)

func equipped(slot: StringName) -> StringName:
	return equipment.get(slot, &"")

func _is_equipped(id: StringName) -> bool:
	for slot in equipment:
		if equipment[slot] == id:
			return true
	return false

# 行囊里没穿的装备(UI 背包列表)。
func owned_unequipped() -> Array:
	var out: Array = []
	for id in owned_equipment:
		if not _is_equipped(id):
			out.append(id)
	return out

# 已装备汇总的某属性加成(走 Equips.modifiers_for → Stats 同乘区)。
func _equip_stat(stat: String) -> int:
	var sum := 0
	for m in Equips.modifiers_for(equipment):
		if m.get("stat", "") == stat:
			sum += int(m.get("value", 0))
	return sum

# 进战斗时的有效属性(基础 + 内功 + 装备 + 永久加成)。攻防默认0;神兵并入攻击。
func combat_attack() -> int:
	return base_attack + weapon_bonus + _equip_stat("attack")
func combat_dmg_inc() -> int:
	return base_dmg_inc + _equip_stat("dmg_inc")
func combat_extra() -> int:
	return base_extra_dmg + _equip_stat("extra_dmg")
func combat_armor() -> int:
	return base_armor + _equip_stat("armor")
func combat_max_hp() -> int:
	return max_hp + _equip_stat("max_hp")
func combat_max_qi() -> int:
	return base_max_qi + qi_bonus() + _equip_stat("max_qi")

# --- 基础提升三选一 ---
func apply_reward(r: Dictionary) -> void:
	match r.get("type", ""):
		"hp":
			max_hp += 6
			player_hp += 6
		"meditate":
			_meditate()
		"hone":
			_hone(r["id"])

func _meditate() -> void:
	neigong_level += 1
	var dh: int = Neigong.hp_per_level(neigong_id)
	max_hp += dh
	player_hp = mini(max_hp, player_hp + MEDITATE_HEAL + dh)

func _hone(id: StringName) -> void:
	mastery[id] = int(mastery.get(id, 0)) + 2
	weight[id] = int(weight.get(id, 0)) + 1

func learn(id: StringName) -> void:
	if not learned.has(id):
		learned.append(id)

# --- 奇遇效果 ---
# 可通过某获得途径(via)得到的功夫:未学 + 满足门槛 + 该途径对它开放(数据驱动)。
func acquirable_arts(via: String) -> Array:
	var out: Array = []
	for id in Menpai.learnable(menpai_id):
		if not learned.has(id) and Arts.can_learn(id, learned, mastery) and Arts.has_source(id, via):
			out.append(id)
	return out

func unlearned_arts() -> Array:        # 奇遇万能池
	return acquirable_arts("encounter")

func self_learnable_arts() -> Array:   # 磨练自悟池
	return acquirable_arts("practice")

func apply_encounter(effect: Dictionary, rng: RandomNumberGenerator) -> void:
	if effect.has("learn_art") or effect.has("master_move"):
		var un := unlearned_arts()
		if un.size() > 0:
			learn(un[rng.randi_range(0, un.size() - 1)])
	if effect.has("master_master") and learned.size() > 0:
		var mid = learned[rng.randi_range(0, learned.size() - 1)]
		mastery[mid] = int(mastery.get(mid, 0)) + 5   # 一门功夫大进
	if effect.has("weapon_dmg"):
		weapon_bonus += int(effect["weapon_dmg"])
	if effect.has("equip"):
		obtain_equipment(StringName(effect["equip"]))
	if effect.has("hp"):
		max_hp += int(effect["hp"]); player_hp += int(effect["hp"])
	if effect.has("neigong"):
		var lv := int(effect["neigong"])
		neigong_level += lv
		var dh := Neigong.hp_per_level(neigong_id) * lv
		max_hp += dh; player_hp += dh
	if effect.has("heal_full"):
		player_hp = max_hp

# --- 实战熟练 + 进化 ---
func gain_mastery(ids: Array) -> void:
	for id in ids:
		mastery[id] = int(mastery.get(id, 0)) + 1

func evo_level(id: StringName) -> int:
	return int(evo.get(id, {}).get("level", 0))

func pending_evolutions() -> Array:
	var out: Array = []
	for id in mastery:
		var lv: int = evo_level(id)
		if lv < EVOLVE_AT.size() and int(mastery[id]) >= int(EVOLVE_AT[lv]):
			out.append(id)
	return out

func apply_evolution(id: StringName, choice: String) -> void:
	var e: Dictionary = evo.get(id, {"level": 0, "spd": 0, "qi": 0, "dmg": 0, "compiled": false})
	e["level"] = int(e["level"]) + 1
	match choice:
		"spd": e["spd"] = int(e["spd"]) + 1
		"qi": e["qi"] = int(e["qi"]) + 1
		"dmg": e["dmg"] = int(e["dmg"]) + 1
		"compiled": e["compiled"] = true
	evo[id] = e

func compiled_arts() -> Array:
	var out: Array = []
	for id in evo:
		if bool(evo[id].get("compiled", false)):
			out.append(id)
	return out

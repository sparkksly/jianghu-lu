class_name RunState
extends RefCounted

# 一局 run:三章,分层分支地图。每章 3 选择层(2-3候选,玩家择路)+ 章末 boss 层。
# 视野受限:地图只显示本层与下一层(再之后是迷雾)。node_index = 当前层(已过节点数)。

const MEDITATE_HEAL := 12
const EVOLVE_AT := [3, 6]
const LAYERS_PER_CHAPTER := 4   # 每章 3 选择层 + 1 boss 层
const CHAPTERS := 3
const CHAPTER_TITLES := ["第一章 · 毒蛛潭", "第二章 · 断魂崖", "第三章 · 华山之巅"]

# 开局构筑在场景间传递(change_scene 不能传参)
static var pending_menpai: StringName = &"shaolin"
static var pending_neigong: StringName = &"yijinjing"
static var pending_arts: Array = [&"luohan", &"chain_kick"]   # 开局选的 2 门初级功夫

var menpai_id: StringName
var neigong_id: StringName
var neigong_level: int = 0
var qinggong: Array = []            # 习得的轻功 id(category=轻功 的被动,习得即生效,可叠)
var talents: Array = []             # 习得的触发型被动 id(category=天赋,combat 时机响应)
var learned: Array = []             # 已领悟功夫(绝学)id;开局=选的 2 门初级
var mastery: Dictionary = {}
var weight: Dictionary = {}
var evo: Dictionary = {}
var weapon_bonus: int = 0           # 神兵:并入攻击力(+attack)
var node_index: int = 0             # 当前层(0..11)
var layers: Array = []              # 分支地图:每层节点 [{type, edges:[下层slot]}];boss 层单节点
var choice_index: int = -1          # 当前层玩家选的 slot(进战斗前由 select 设)
var prev_slot: int = -1             # 上一层所选 slot(决定本层可走哪些 → 连线约束)
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
var conditions: Array = []            # 预留:跨场持续状态(内伤=战斗内debuff,不在此;此处留给未来跨场效果)

func _init(menpai := &"shaolin", neigong := &"", arts := []) -> void:
	menpai_id = menpai
	neigong_id = neigong if neigong != &"" else Neigong.starter(menpai)
	learned = (arts.duplicate() if not arts.is_empty() else Menpai.starter_pool(menpai).slice(0, 2))
	node_index = 0; choice_index = -1; prev_slot = -1
	qinggong = []; talents = []
	_gen_map()
	player_hp = 40; max_hp = 40
	neigong_level = 0
	mastery = {}; weight = {}; evo = {}; weapon_bonus = 0
	base_attack = 10; base_dmg_inc = 0; base_extra_dmg = 0; base_armor = 0; base_max_qi = 10
	equipment = {}; owned_equipment = []; hidden_weapons = {}; inventory = []; money = 50; reputation = 0; conditions = []

# --- 分支地图生成 ---
func _gen_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	layers = []
	for _ch in CHAPTERS:
		var shop_layer := rng.randi_range(0, LAYERS_PER_CHAPTER - 2)   # 本章仅此选择层有集市
		for l in (LAYERS_PER_CHAPTER - 1):
			layers.append(_gen_choices(rng, l == shop_layer))
		layers.append([{"type": "boss"}])   # 章末 boss
	for layer in layers:                     # 初始化空出边
		for node in layer:
			node["edges"] = []
	for i in range(layers.size() - 1):       # 相邻层连线
		_link(layers[i], layers[i + 1], rng)

# 连线规则(暂随机 + 基本约束):每个上层节点 1-2 条出边;每个下层节点 ≥1 入边(无死路/孤岛)。
# 以后可加更多规则(不交叉/类型偏好/精英前置等)。
func _link(upper: Array, lower: Array, rng: RandomNumberGenerator) -> void:
	var bn := lower.size()
	for u in upper:
		var k := rng.randi_range(1, mini(2, bn))
		u["edges"] = _pick_k(bn, k, rng)
	# 保证下层每个节点都有入边(否则随机从上层补一条)
	var incoming := {}
	for u in upper:
		for t in u["edges"]:
			incoming[t] = true
	for v in bn:
		if not incoming.has(v):
			var ui := rng.randi_range(0, upper.size() - 1)
			if not (v in upper[ui]["edges"]):
				upper[ui]["edges"].append(v)

func _pick_k(n: int, k: int, rng: RandomNumberGenerator) -> Array:
	var all: Array = []
	for i in n:
		all.append(i)
	for i in range(all.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = all[i]; all[i] = all[j]; all[j] = tmp
	var out := all.slice(0, k)
	out.sort()
	return out

func _gen_choices(rng: RandomNumberGenerator, with_shop: bool) -> Array:
	# 保证 ≥1 战斗;集市只在本章指定层出现(with_shop);精英稀有(30%)。
	var picks: Array = [{"type": "elite" if rng.randf() < 0.3 else "grunt"}]
	if with_shop:
		picks.append({"type": "shop"})
	else:
		picks.append({"type": "encounter" if rng.randf() < 0.55 else "grunt"})
	if rng.randf() < 0.5:   # 偶尔第三个候选
		picks.append({"type": "encounter" if rng.randf() < 0.6 else "grunt"})
	for i in range(picks.size() - 1, 0, -1):   # 洗牌
		var j := rng.randi_range(0, i)
		var tmp = picks[i]; picks[i] = picks[j]; picks[j] = tmp
	return picks

# --- 节点 / 章节 ---
func current_chapter() -> int:
	return clampi(node_index / LAYERS_PER_CHAPTER, 0, CHAPTERS - 1)

func current_layer() -> Array:
	return layers[node_index] if node_index < layers.size() else [{"type": "boss"}]

func is_boss_layer() -> bool:
	return current_layer().size() == 1

# 本层可走的 slots:第0层全开;否则=上一层所选节点的出边(连线约束)。
func available_slots() -> Array:
	if node_index >= layers.size():
		return []
	if node_index == 0:
		var out: Array = []
		for i in layers[0].size():
			out.append(i)
		return out
	var prev_layer: Array = layers[node_index - 1]
	if prev_slot < 0 or prev_slot >= prev_layer.size():
		var out2: Array = []        # 兜底:全开(不该发生)
		for i in current_layer().size():
			out2.append(i)
		return out2
	return (prev_layer[prev_slot]["edges"] as Array).duplicate()

func current_type() -> String:
	var layer := current_layer()
	if layer.size() == 1:
		return layer[0]["type"]
	var s := choice_index
	if s < 0 or s >= layer.size():
		var av := available_slots()
		s = int(av[0]) if not av.is_empty() else 0
	return layer[s]["type"]

# 玩家在地图上选当前层 slot。
func select(slot: int) -> void:
	choice_index = slot

# 地图本程:可走候选 [{slot, type, edges}](edges 用于画连线)。
func map_choices() -> Array:
	var out: Array = []
	var layer := current_layer()
	for s in available_slots():
		out.append({"slot": s, "type": layer[s]["type"], "edges": (layer[s]["edges"] as Array).duplicate()})
	return out

# 地图下程:本程可走节点经出边能到达的下一层节点 [{slot, type}](看不到再之后)。
func map_next_nodes() -> Array:
	var nxt := node_index + 1
	if nxt >= layers.size():
		return []
	var layer := current_layer()
	var reach := {}
	for s in available_slots():
		for e in layer[s]["edges"]:
			reach[e] = true
	var slots := reach.keys()
	slots.sort()
	var out: Array = []
	for e in slots:
		out.append({"slot": e, "type": layers[nxt][e]["type"]})
	return out

func current_node() -> Dictionary:
	return {"chapter": current_chapter(), "type": current_type(), "layer": node_index}

func advance_node() -> void:
	prev_slot = choice_index   # 记下本层所选 → 下层据此连线
	node_index += 1
	choice_index = -1

func is_complete() -> bool:
	return node_index >= layers.size()

func chapter_title() -> String:
	return CHAPTER_TITLES[clampi(current_chapter(), 0, 2)]

func current_enemy() -> Dictionary:
	return Enemies.spawn(current_chapter(), current_type(), node_index + maxi(0, choice_index))

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

# --- 银两 ---
func add_money(n: int) -> void:
	money = maxi(0, money + n)

func spend_money(n: int) -> bool:
	if money < n:
		return false
	money -= n
	return true

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

# 习得轻功(category=轻功被动)汇总的某属性加成。
func learn_qinggong(id: StringName) -> void:
	if not qinggong.has(id):
		qinggong.append(id)

func _qinggong_stat(stat: String) -> int:
	var held := {}
	for id in qinggong:
		held[id] = 1
	var sum := 0
	for m in Passives.modifiers_for(held):
		if m.get("stat", "") == stat:
			sum += int(m.get("value", 0))
	return sum

# 触发型被动:习得天赋的 trigger effects [{when, do}],战斗时传入 combat_state.triggers[0]。
func learn_talent(id: StringName) -> void:
	if not talents.has(id):
		talents.append(id)

func combat_triggers() -> Array:
	var out: Array = []
	for id in talents:
		var d := Passives.def(id)
		if d == null:
			continue
		for e in d.effects:
			if e.get("kind", "") == "trigger":
				out.append(e)
	return out

# 进战斗时的有效属性(基础 + 内功 + 轻功 + 装备 + 永久加成)。攻防默认0;神兵并入攻击。
func combat_attack() -> int:
	return base_attack + weapon_bonus + _equip_stat("attack") + _qinggong_stat("attack")
func combat_dmg_inc() -> int:
	return base_dmg_inc + _equip_stat("dmg_inc") + _qinggong_stat("dmg_inc")
func combat_extra() -> int:
	return base_extra_dmg + _equip_stat("extra_dmg") + _qinggong_stat("extra_dmg")
func combat_armor() -> int:
	return base_armor + _equip_stat("armor") + _qinggong_stat("armor")
func combat_max_hp() -> int:
	return max_hp + _equip_stat("max_hp") + _qinggong_stat("max_hp")
func combat_max_qi() -> int:
	return base_max_qi + qi_bonus() + _equip_stat("max_qi") + _qinggong_stat("max_qi")

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
	if effect.has("qinggong"):
		var pool: Array = []
		for id in Passives.by_category(&"轻功"):
			if not qinggong.has(id):
				pool.append(id)
		if pool.size() > 0:
			learn_qinggong(pool[rng.randi_range(0, pool.size() - 1)])
	if effect.has("talent"):
		var tpool: Array = []
		for id in Passives.by_category(&"天赋"):
			if not talents.has(id):
				tpool.append(id)
		if tpool.size() > 0:
			learn_talent(tpool[rng.randi_range(0, tpool.size() - 1)])
	if effect.has("money"):
		add_money(int(effect["money"]))
	if effect.has("reputation"):
		reputation += int(effect["reputation"])
	if effect.has("heal"):
		player_hp = clampi(player_hp + int(effect["heal"]), 1, max_hp)   # 负数=受创,留 1 血保命
	if effect.has("risk"):
		# 赌一把:按 chance 命中 win,否则 lose,递归应用。
		var rk: Dictionary = effect["risk"]
		var won := rng.randf() < float(rk.get("chance", 0.5))
		apply_encounter(rk["win"] if won else rk["lose"], rng)
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

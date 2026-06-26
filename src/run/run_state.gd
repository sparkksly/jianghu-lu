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
var weapon_bonus: int = 0           # 神兵:全攻击招 +伤
var node_index: int = 0
var player_hp: int = 40
var max_hp: int = 40

func _init(menpai := &"shaolin", neigong := &"", arts := []) -> void:
	menpai_id = menpai
	neigong_id = neigong if neigong != &"" else Neigong.starter(menpai)
	learned = (arts.duplicate() if not arts.is_empty() else Menpai.starter_pool(menpai).slice(0, 2))
	node_index = 0
	player_hp = 40; max_hp = 40
	neigong_level = 0
	mastery = {}; weight = {}; evo = {}; weapon_bonus = 0

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
# 可领悟的功夫 = 本派未学 且 满足解锁(高级需初级功夫熟练)。
func unlearned_arts() -> Array:
	var out: Array = []
	for id in Menpai.learnable(menpai_id):
		if not learned.has(id) and Arts.can_learn(id, learned, mastery):
			out.append(id)
	return out

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

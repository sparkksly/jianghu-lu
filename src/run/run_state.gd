class_name RunState
extends RefCounted

# 一局 run 的成长状态:门派/内功、已领悟绝学、招式熟练度/抽取权重/进化。
# 三层成长:基础提升(强身/打坐/磨练) + 实战熟练 → 招式进化。

const MEDITATE_HEAL := 12      # 打坐疗伤
const EVOLVE_AT := [3, 6]      # 熟练度达此值且进化级未到 → 可进化(level 0→1 需3, 1→2 需6)

# 选派在场景间传递(change_scene 不能传参)
static var pending_menpai: StringName = &"shaolin"

var fights_total: int
var fight_index: int
var player_hp: int
var max_hp: int
var menpai_id: StringName
var neigong_id: StringName
var neigong_level: int = 0
var learned: Array = []                 # 已领悟绝学 id(开局=门派入门)
var mastery: Dictionary = {}            # 招式/绝学 id → 熟练计数
var weight: Dictionary = {}             # 招式 id → 抽取额外权重
var evo: Dictionary = {}                # 招式 id → {level,spd,qi,dmg,compiled}

func _init(total: int = 3, hp: int = 40, menpai: StringName = &"shaolin") -> void:
	fights_total = total
	fight_index = 0
	player_hp = hp
	max_hp = hp
	menpai_id = menpai
	neigong_id = Neigong.starter(menpai)
	learned = Menpai.starter_learned(menpai)
	mastery = {}; weight = {}; evo = {}

# 内功带来的额外气(进 sta_max)。
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
	var dh: int = Neigong.hp_per_level(neigong_id)   # 内功长血
	max_hp += dh
	player_hp = mini(max_hp, player_hp + MEDITATE_HEAL + dh)

func _hone(id: StringName) -> void:
	mastery[id] = int(mastery.get(id, 0)) + 2
	weight[id] = int(weight.get(id, 0)) + 1

func learn(id: StringName) -> void:
	if not learned.has(id):
		learned.append(id)

# --- 实战熟练 + 进化 ---
func gain_mastery(ids: Array) -> void:
	for id in ids:
		mastery[id] = int(mastery.get(id, 0)) + 1

func evo_level(id: StringName) -> int:
	return int(evo.get(id, {}).get("level", 0))

# 熟练达标且进化级未到的招 → 待进化(玩家三选一)。
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

# 已化境(压缩成单卡)的绝学 id → 进抽牌池。
func compiled_arts() -> Array:
	var out: Array = []
	for id in evo:
		if bool(evo[id].get("compiled", false)):
			out.append(id)
	return out

func advance() -> void:
	fight_index += 1

func is_complete() -> bool:
	return fight_index >= fights_total

func label() -> String:
	return "第%d战 / 共%d战" % [min(fight_index + 1, fights_total), fights_total]

func enemy_hp() -> int:
	return 30 + fight_index * 10

func enemy_regen() -> int:
	return 5 + fight_index

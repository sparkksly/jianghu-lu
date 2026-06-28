class_name RunRewards
extends RefCounted

# 两种战后三选一:
#  基础提升:强身 / 打坐修炼 / 磨练招式(随机一门基础攻击招)
#  招式进化:某招熟练满 → 迅捷/凝气/沉重(绝学第2次进化可出化境单卡)

# 基础提升三选一(磨练目标 = 随机一门基础招)。
# 机缘奖励池(加权随机抽 3 个不同类型 → 每次三选一有变化)。
# w 越大越常见;额外伤害/顿悟是稀有强力,低权重。数值见 RunState.apply_reward。
const POOL := [
	{"type": "hp", "w": 10},        # 强身:气血上限
	{"type": "meditate", "w": 8},   # 打坐:内功+级
	{"type": "hone", "w": 9},       # 磨练:某基础招熟练+抽率
	{"type": "attack", "w": 8},     # 内力:基础攻击
	{"type": "dmg_inc", "w": 8},    # 刚劲:基础增伤%(加法区)
	{"type": "money", "w": 7},      # 盘缠:银两
	{"type": "armor", "w": 5},      # 横练:防御
	{"type": "extra_dmg", "w": 3},  # 绝劲:额外伤害%(独立乘区,稀有)
	{"type": "learn", "w": 5},      # 顿悟:领悟一门可自悟功夫
]

# 基础提升三选一:从加权池抽 3 个不同类型(顿悟仅当有可自悟功夫时入池)。
static func roll_basic(rng: RandomNumberGenerator, run = null) -> Array:
	var pool: Array = []
	for p in POOL:
		if p["type"] == "learn" and (run == null or run.self_learnable_arts().is_empty()):
			continue
		pool.append(p.duplicate())
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var idx := _weighted_pick(pool, rng)
		var typ: String = pool[idx]["type"]
		pool.remove_at(idx)   # 不重复类型
		out.append(_make_reward(typ, rng, run))
	return out

static func _weighted_pick(pool: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for p in pool:
		total += int(p["w"])
	var r := rng.randi_range(0, total - 1)
	var acc := 0
	for i in pool.size():
		acc += int(pool[i]["w"])
		if r < acc:
			return i
	return pool.size() - 1

static func _make_reward(typ: String, rng: RandomNumberGenerator, run) -> Dictionary:
	match typ:
		"hone":
			var ids: Array = []
			for m in Deck.basic_attacks():
				ids.append(m.id)
			return {"type": "hone", "id": ids[rng.randi_range(0, ids.size() - 1)]}
		"learn":
			var arts: Array = run.self_learnable_arts()
			return {"type": "learn", "id": arts[rng.randi_range(0, arts.size() - 1)]}
		_:
			return {"type": typ}

# 招式进化三选一。is_art=该 id 是绝学;evo_level=已进化次数(首次=0)。
static func roll_evolution(id: StringName, evo_level: int, is_art: bool) -> Array:
	if is_art and evo_level >= 1:   # 绝学第2次进化:可化境为单卡
		return [
			{"type": "evo", "id": id, "choice": "compiled"},
			{"type": "evo", "id": id, "choice": "spd"},
			{"type": "evo", "id": id, "choice": "dmg"},
		]
	return [
		{"type": "evo", "id": id, "choice": "spd"},
		{"type": "evo", "id": id, "choice": "qi"},
		{"type": "evo", "id": id, "choice": "dmg"},
	]

static func label(r: Dictionary) -> String:
	var nm := func(id): return Loc.move_name(id)
	match r.get("type", ""):
		"hp": return "强身   ( +6 气血上限 )"
		"meditate": return "打坐修炼   ( 疗伤 + 内功+1 )"
		"hone": return "磨练招式 · " + nm.call(r["id"]) + "   ( 熟练 + 抽率↑ )"
		"attack": return "内力修为   ( 攻击力 +2 )"
		"dmg_inc": return "刚劲   ( 伤害 +8% )"
		"extra_dmg": return "绝劲   ( 额外伤害 +6% · 稀有 )"
		"armor": return "横练护体   ( 防御 +12 )"
		"money": return "寻得盘缠   ( +35 银两 )"
		"learn": return "顿悟 · " + nm.call(r["id"]) + "   ( 领悟此功 )"
		"evo":
			var n: String = nm.call(r["id"])
			match r["choice"]:
				"spd": return "迅捷 · " + n + "   ( 出招更快 )"
				"qi": return "凝气 · " + n + "   ( 更省气 )"
				"dmg": return "沉重 · " + n + "   ( 伤害 +2 )"
				"compiled": return "化境 · " + n + "   ( 化作一张单卡! )"
	return "?"

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
	{"type": "meditate", "w": 9},   # 打坐:内功+级
	{"type": "hone", "w": 10},      # 磨练:强化你修炼方向的基础招(定向)
	{"type": "qinggong", "w": 6},   # 身法:习得一门轻功
	{"type": "attack", "w": 7},     # 内力:基础攻击
	{"type": "dmg_inc", "w": 7},    # 刚劲:基础增伤%(加法区)
	{"type": "money", "w": 6},      # 盘缠:银两
	{"type": "armor", "w": 5},      # 横练:防御
	{"type": "extra_dmg", "w": 3},  # 绝劲:额外伤害%(独立乘区,稀有)
	{"type": "learn", "w": 7},      # 顿悟:领悟你专精方向的功夫(定向)
]

# 基础提升三选一:从加权池抽 3 个不同类型(顿悟/身法仅当确有可得时入池)。
static func roll_basic(rng: RandomNumberGenerator, run = null) -> Array:
	var pool: Array = []
	for p in POOL:
		if p["type"] == "learn" and (run == null or run.self_learnable_arts().is_empty()):
			continue
		if p["type"] == "qinggong" and (run == null or _unlearned_qinggong(run).is_empty()):
			continue
		pool.append(p.duplicate())
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var idx := _weighted_pick(pool, rng)
		var typ: String = pool[idx]["type"]
		pool.remove_at(idx)   # 不重复类型
		out.append(_make_reward(typ, rng, run))
	return out

# 你的修炼方向:已学功夫所需家族的需求量(招式 tag → 次数),磨练/领悟据此定向。
static func _family_demand(run) -> Dictionary:
	var d: Dictionary = {}
	if run == null:
		return d
	for id in run.learned:
		var a := Arts.def(id)
		if a == null:
			continue
		for s in a.slots:
			if s.has("tag"):
				var t := str(s["tag"])
				d[t] = int(d.get(t, 0)) + 1
	return d

static func _unlearned_qinggong(run) -> Array:
	var out: Array = []
	for id in Passives.by_category(&"轻功"):
		if not run.qinggong.has(id):
			out.append(id)
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
			# 定向:优先磨练你已学功夫所需家族的基础招(强化专精),无方向则随机
			var demand := _family_demand(run)
			var cands: Array = []
			for m in Deck.basic_attacks():
				for t in m.tags:
					if int(demand.get(str(t), 0)) > 0:
						cands.append(m.id)
						break
			if cands.is_empty():
				for m in Deck.basic_attacks():
					cands.append(m.id)
			return {"type": "hone", "id": cands[rng.randi_range(0, cands.size() - 1)]}
		"learn":
			# 定向:优先领悟与你专精家族契合的功夫(配方家族和已学方向重叠)
			var arts: Array = run.self_learnable_arts()
			var demand := _family_demand(run)
			var preferred: Array = []
			for id in arts:
				var a := Arts.def(id)
				if a == null:
					continue
				for s in a.slots:
					if s.has("tag") and int(demand.get(str(s["tag"]), 0)) > 0:
						preferred.append(id)
						break
			var pool: Array = preferred if not preferred.is_empty() else arts
			return {"type": "learn", "id": pool[rng.randi_range(0, pool.size() - 1)]}
		"qinggong":
			var qg := _unlearned_qinggong(run)
			return {"type": "qinggong", "id": qg[rng.randi_range(0, qg.size() - 1)]}
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
		"qinggong": return "身法 · " + Passives.display_name(r["id"]) + "   ( 习得轻功 )"
		"evo":
			var n: String = nm.call(r["id"])
			match r["choice"]:
				"spd": return "迅捷 · " + n + "   ( 出招更快 )"
				"qi": return "凝气 · " + n + "   ( 更省气 )"
				"dmg": return "沉重 · " + n + "   ( 伤害 +2 )"
				"compiled": return "化境 · " + n + "   ( 化作一张单卡! )"
	return "?"

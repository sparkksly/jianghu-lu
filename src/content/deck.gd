class_name Deck
extends RefCounted

static func _m(id, name, kind, su, act, rec, dmg, cost, opts := {}) -> Move:
	var m := Move.new()
	m.id = id; m.move_name = name; m.kind = kind
	m.startup = su; m.active = act; m.recovery = rec
	m.damage = dmg; m.stamina_cost = cost
	# Typed arrays must be assigned carefully
	var hits: Array[int] = []
	for v in opts.get("hits", [0]):
		hits.append(v as int)
	m.hit_offsets = hits
	var tags: Array[StringName] = []
	for t in opts.get("tags", []):
		tags.append(t as StringName)
	m.tags = tags
	m.can_interrupt = opts.get("interrupt", false)
	m.super_armor = opts.get("armor", false)
	m.is_heavy = opts.get("heavy", false)
	m.priority = opts.get("priority", 0)
	m.range_min = opts.get("range", [0, 2])[0]
	m.range_max = opts.get("range", [0, 2])[1]
	m.knockback = opts.get("knockback", false)
	m.stun = opts.get("stun", 0)
	m.distance_delta = opts.get("delta", 0)
	m.grants_guard = opts.get("guard", 0)
	return m

static func starter() -> Array[Move]:
	return [
		# 拳(贴身)
		_m(&"jab", "直拳", Move.Kind.ATTACK, 0, 1, 1, 4, 2, {"tags":[&"拳法"], "range":[0,0], "interrupt":true, "priority":5}),
		_m(&"hook", "摆拳", Move.Kind.ATTACK, 1, 1, 1, 6, 2, {"tags":[&"拳法"], "range":[0,0]}),
		# 掌(贴身~中)
		_m(&"push_palm", "推掌", Move.Kind.ATTACK, 0, 1, 2, 5, 2, {"tags":[&"掌法"], "range":[0,1], "knockback":true}),
		_m(&"chop_palm", "下劈掌", Move.Kind.ATTACK, 2, 1, 1, 9, 3, {"tags":[&"掌法"], "range":[0,1], "heavy":true, "armor":true}),
		# 肘膝(贴身)
		_m(&"elbow_strike", "撞肘", Move.Kind.ATTACK, 1, 1, 1, 6, 2, {"tags":[&"肘膝"], "range":[0,0], "stun":2}),
		_m(&"knee_strike", "膝顶", Move.Kind.ATTACK, 1, 1, 2, 9, 3, {"tags":[&"肘膝"], "range":[0,0], "heavy":true}),
		# 腿(贴身~中)
		_m(&"snap_kick", "弹腿", Move.Kind.ATTACK, 0, 1, 1, 5, 2, {"tags":[&"腿法"], "range":[0,1]}),
		_m(&"sweep_kick", "扫堂腿", Move.Kind.ATTACK, 0, 1, 2, 6, 2, {"tags":[&"腿法"], "range":[0,1]}),
		_m(&"side_kick", "侧踢", Move.Kind.ATTACK, 3, 1, 2, 12, 4, {"tags":[&"腿法"], "range":[0,1], "heavy":true, "armor":true, "knockback":true}),
		# 防/闪/拿
		_m(&"guard", "格挡", Move.Kind.BLOCK, 0, 3, 1, 0, 2, {}),
		_m(&"dodge", "闪身", Move.Kind.DODGE, 0, 2, 1, 0, 2, {"tags":[&"轻功"]}),
		_m(&"grab", "擒拿", Move.Kind.THROW, 0, 1, 1, 5, 3, {"range":[0,0]}),
		# 步法(进快退慢;走位不耗气,只花拍)
		_m(&"step_in", "上步", Move.Kind.STEP, 0, 1, 0, 0, 0, {"tags":[&"身法"], "delta":-1}),
		_m(&"step_back", "撤步", Move.Kind.STEP, 0, 1, 1, 0, 0, {"tags":[&"身法"], "delta":1}),
	]

static func by_id(id: StringName) -> Move:
	for m in starter():
		if m.id == id: return m
	return null

# 门派功夫 = 基础动作合成的连招(绝学)。下面是融合结果模板:
# 伤害按 _fuse_result 用组件重算,模板的 hits/range/delta/guard 保留。
# 配方(用哪些基础动作合成)定义在 menpai.gd。
static func luohan() -> Move:  # 少林:拳法×3 → 罗汉拳(刚猛三连)
	return _m(&"luohan", "罗汉拳", Move.Kind.ATTACK, 0, 3, 1, 21, 0, {"tags":[&"拳法"], "hits":[0,1,2], "range":[0,1]})
static func jingang_fumo() -> Move:  # 少林:格挡+掌法 → 金刚伏魔(护体重掌)
	return _m(&"jingang_fumo", "金刚伏魔", Move.Kind.ATTACK, 0, 1, 2, 10, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "armor":true, "guard":4})
static func taiji_yunshou() -> Move:  # 武当:掌法×2 → 太极云手(柔掌走位)
	return _m(&"taiji_yunshou", "太极云手", Move.Kind.ATTACK, 0, 2, 1, 12, 0, {"tags":[&"掌法"], "hits":[0,1], "range":[0,2], "delta":-1, "priority":6})

# combo result moves (not in hand; produced by fusion) — fast flurries, no 前摇
static func chain_kick() -> Move:
	return _m(&"chain_kick", "连环踢", Move.Kind.ATTACK, 0, 2, 1, 14, 0, {"tags":[&"腿法"], "hits":[0,1], "range":[0,1]})
static func wuying() -> Move:
	return _m(&"wuying", "佛山无影脚", Move.Kind.ATTACK, 0, 3, 1, 22, 0, {"tags":[&"腿法"], "hits":[0,1,2], "armor":true, "range":[0,1]})
static func qiankun() -> Move:
	return _m(&"qiankun", "乾坤大挪移", Move.Kind.THROW, 0, 1, 1, 18, 0, {"range":[0,1]})

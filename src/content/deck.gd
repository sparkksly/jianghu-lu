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
		# 步法(进快退慢)
		_m(&"step_in", "上步", Move.Kind.STEP, 0, 1, 0, 0, 1, {"tags":[&"身法"], "delta":-1}),
		_m(&"step_back", "撤步", Move.Kind.STEP, 0, 1, 1, 0, 1, {"tags":[&"身法"], "delta":1}),
	]

# 门派招式(少林/武当);加入门派进攻池,不在通用 starter()。
static func menpai_moves() -> Array[Move]:
	return [
		# 少林:刚猛贴身 + 棍补中距
		_m(&"beng_quan", "崩拳", Move.Kind.ATTACK, 0, 1, 1, 7, 2, {"tags":[&"拳法"], "range":[0,1]}),
		_m(&"weituo", "韦陀掌", Move.Kind.ATTACK, 1, 1, 1, 8, 3, {"tags":[&"掌法"], "range":[0,1], "armor":true}),
		_m(&"jingang_zhi", "金刚指", Move.Kind.ATTACK, 0, 1, 1, 6, 2, {"tags":[&"指法"], "range":[0,1], "interrupt":true}),
		_m(&"longzhua", "龙爪手", Move.Kind.ATTACK, 1, 1, 1, 7, 2, {"tags":[&"擒拿"], "range":[0,0]}),
		_m(&"shaolin_gun", "少林棍", Move.Kind.ATTACK, 1, 1, 1, 7, 3, {"tags":[&"棍法"], "range":[1,2], "knockback":true}),
		# 武当:柔掌中距
		_m(&"mian_zhang", "绵掌", Move.Kind.ATTACK, 0, 1, 1, 5, 2, {"tags":[&"掌法"], "range":[1,1]}),
		_m(&"wudang_changquan", "武当长拳", Move.Kind.ATTACK, 0, 1, 1, 6, 2, {"tags":[&"拳法"], "range":[0,1]}),
	]

static func by_id(id: StringName) -> Move:
	for m in starter():
		if m.id == id: return m
	for m in menpai_moves():
		if m.id == id: return m
	return null

# 门派连招模板(融合产生;伤害按 _fuse_result 重算,模板的 hits/range/delta/guard 保留)
static func luohan() -> Move:
	return _m(&"luohan", "罗汉拳", Move.Kind.ATTACK, 0, 3, 1, 21, 0, {"tags":[&"拳法"], "hits":[0,1,2], "range":[0,1]})
static func jingang_fumo() -> Move:
	return _m(&"jingang_fumo", "金刚伏魔", Move.Kind.ATTACK, 0, 1, 2, 10, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "armor":true, "guard":4})
static func taiji_yunshou() -> Move:
	return _m(&"taiji_yunshou", "太极云手", Move.Kind.ATTACK, 0, 2, 1, 12, 0, {"tags":[&"掌法"], "hits":[0,1], "range":[0,2], "delta":-1, "priority":6})

# combo result moves (not in hand; produced by fusion) — fast flurries, no 前摇
static func chain_kick() -> Move:
	return _m(&"chain_kick", "连环踢", Move.Kind.ATTACK, 0, 2, 1, 14, 0, {"tags":[&"腿法"], "hits":[0,1], "range":[0,1]})
static func wuying() -> Move:
	return _m(&"wuying", "佛山无影脚", Move.Kind.ATTACK, 0, 3, 1, 22, 0, {"tags":[&"腿法"], "hits":[0,1,2], "armor":true, "range":[0,1]})
static func qiankun() -> Move:
	return _m(&"qiankun", "乾坤大挪移", Move.Kind.THROW, 0, 1, 1, 18, 0, {"range":[0,1]})

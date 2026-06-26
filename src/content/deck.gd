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
	m.tier = opts.get("tier", 1)
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
	for m in advanced_moves():
		if m.id == id: return m
	for m in boss_moves():
		if m.id == id: return m
	return null

# 基础攻击招 = 全部(下劈掌/侧踢等也是基础);开局从这里选 2 门。
static func basic_attacks() -> Array[Move]:
	return Hand.attack_pool(starter())

# 大成招:稀有强力的进阶招(入门掌法→大成掌法),靠领悟/奇遇得,不在开局选项。
static func advanced_moves() -> Array[Move]:
	return [
		_m(&"prajna_palm", "般若掌", Move.Kind.ATTACK, 1, 1, 2, 13, 4, {"tags":[&"掌法"], "range":[0,1], "heavy":true, "armor":true, "tier":2}),
		_m(&"taizu_fist", "太祖长拳", Move.Kind.ATTACK, 0, 2, 1, 7, 3, {"tags":[&"拳法"], "range":[0,1], "hits":[0,1], "tier":2}),
		_m(&"mandarin_kick", "鸳鸯连环腿", Move.Kind.ATTACK, 0, 2, 2, 8, 3, {"tags":[&"腿法"], "range":[0,1], "hits":[0,1], "knockback":true, "tier":2}),
		_m(&"vajra_finger", "大力金刚指", Move.Kind.ATTACK, 1, 1, 1, 10, 3, {"tags":[&"指法"], "range":[0,1], "interrupt":true, "heavy":true, "tier":2}),
	]

# boss 专属招(用现有词缀做特色;不在玩家池)
static func boss_moves() -> Array[Move]:
	return [
		# 青鳞毒叟(西毒/星宿):阴毒、霸体反震
		_m(&"toad_power", "蛤蟆劲", Move.Kind.ATTACK, 2, 1, 2, 10, 3, {"range":[0,1], "armor":true, "heavy":true}),
		_m(&"venom_palm", "毒砂掌", Move.Kind.ATTACK, 1, 1, 1, 11, 3, {"range":[0,1], "heavy":true}),
		_m(&"rot_claw", "腐骨爪", Move.Kind.ATTACK, 1, 1, 1, 7, 2, {"range":[0,0], "stun":2}),
		# 血河老魔(血刀):凶猛重斩
		_m(&"blood_blade", "血河刀", Move.Kind.ATTACK, 1, 1, 1, 12, 3, {"range":[0,1], "heavy":true, "knockback":true}),
		_m(&"soul_reap", "噬魂斩", Move.Kind.ATTACK, 2, 1, 1, 13, 3, {"range":[0,1], "heavy":true, "interrupt":true}),
		_m(&"massacre", "狂屠", Move.Kind.ATTACK, 0, 3, 1, 6, 3, {"range":[0,1], "hits":[0,1,2]}),
		# 无影魔君(东方不败):极快瞬身
		_m(&"phantom_needle", "千幻针", Move.Kind.ATTACK, 0, 2, 0, 5, 2, {"range":[0,1], "hits":[0,1], "priority":7}),
		_m(&"ghost_step", "鬼魅步", Move.Kind.STEP, 0, 1, 0, 0, 0, {"tags":[&"身法"], "delta":-1, "priority":9}),
		_m(&"reaper_stab", "夺命刺", Move.Kind.ATTACK, 1, 1, 1, 12, 3, {"range":[0,0], "interrupt":true, "priority":8}),
	]

# 门派功夫 = 基础动作合成的连招(绝学)。下面是融合结果模板:
# 伤害按 _fuse_result 用组件重算,模板的 hits/range/delta/guard 保留。
# 配方(用哪些基础动作合成)定义在 menpai.gd。
static func luohan() -> Move:  # 少林:拳法×3 → 罗汉拳(刚猛三连)
	return _m(&"luohan", "罗汉拳", Move.Kind.ATTACK, 0, 3, 1, 6, 0, {"tags":[&"拳法"], "hits":[0,1,2], "range":[0,1]})
static func jingang_fumo() -> Move:  # 少林:格挡+掌法 → 金刚伏魔(护体重掌)
	return _m(&"jingang_fumo", "金刚伏魔", Move.Kind.ATTACK, 0, 1, 2, 10, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "armor":true, "guard":4})
static func taiji_yunshou() -> Move:  # 武当:掌法×2 → 太极云手(柔掌走位)
	return _m(&"taiji_yunshou", "太极云手", Move.Kind.ATTACK, 0, 2, 1, 6, 0, {"tags":[&"掌法"], "hits":[0,1], "range":[0,2], "delta":-1, "priority":6})

# combo result moves (not in hand; produced by fusion) — fast flurries, no 前摇
static func chain_kick() -> Move:
	return _m(&"chain_kick", "连环踢", Move.Kind.ATTACK, 0, 2, 1, 7, 0, {"tags":[&"腿法"], "hits":[0,1], "range":[0,1]})
static func wuying() -> Move:
	return _m(&"wuying", "佛山无影脚", Move.Kind.ATTACK, 0, 3, 1, 22, 0, {"tags":[&"腿法"], "hits":[0,1,2], "armor":true, "range":[0,1]})
static func qiankun() -> Move:
	return _m(&"qiankun", "乾坤大挪移", Move.Kind.THROW, 0, 1, 1, 14, 0, {"range":[0,1]})

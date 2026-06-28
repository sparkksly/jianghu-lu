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
	m.inflict = opts.get("inflict", [])
	m.empower = opts.get("empower", [])
	m.tier = opts.get("tier", 1)
	return m

static func starter() -> Array[Move]:
	return [
		# 拳(贴身)
		_m(&"jab", "直拳", Move.Kind.ATTACK, 0, 1, 1, 4, 2, {"tags":[&"拳法"], "range":[0,0], "interrupt":true, "priority":5}),
		_m(&"hook", "摆拳", Move.Kind.ATTACK, 1, 1, 1, 6, 2, {"tags":[&"拳法"], "range":[0,0]}),
		# 掌(贴身~中)
		_m(&"push_palm", "推掌", Move.Kind.ATTACK, 0, 1, 2, 5, 2, {"tags":[&"掌法"], "range":[0,1], "knockback":true, "interrupt":true}),  # 控距:打断+击退,真正拉开
		_m(&"chop_palm", "下劈掌", Move.Kind.ATTACK, 2, 1, 1, 9, 3, {"tags":[&"掌法"], "range":[0,1], "heavy":true, "armor":true}),
		# 肘膝(贴身)
		_m(&"elbow_strike", "撞肘", Move.Kind.ATTACK, 1, 1, 1, 6, 2, {"tags":[&"肘膝"], "range":[0,0], "stun":2}),
		_m(&"knee_strike", "膝顶", Move.Kind.ATTACK, 1, 1, 2, 9, 3, {"tags":[&"肘膝"], "range":[0,0], "heavy":true}),
		# 腿(贴身~中)
		_m(&"snap_kick", "弹腿", Move.Kind.ATTACK, 0, 1, 1, 5, 2, {"tags":[&"腿法"], "range":[0,1]}),
		_m(&"sweep_kick", "扫堂腿", Move.Kind.ATTACK, 0, 1, 2, 6, 2, {"tags":[&"腿法"], "range":[0,1]}),
		_m(&"side_kick", "侧踢", Move.Kind.ATTACK, 3, 1, 2, 12, 4, {"tags":[&"腿法"], "range":[0,1], "heavy":true, "armor":true, "knockback":true}),
		# 防/闪/拿
		_m(&"guard", "格挡", Move.Kind.BLOCK, 0, 2, 0, 0, 1, {}),  # 2拍·1气(硬扛额外耗气见 combat_sim)
		_m(&"dodge", "闪身", Move.Kind.DODGE, 0, 2, 1, 0, 2, {"tags":[&"轻功"]}),
		_m(&"grab", "擒拿", Move.Kind.THROW, 0, 1, 1, 5, 3, {"range":[0,0]}),
		# 步法(进快退慢;走位不耗气,只花拍)
		_m(&"step_in", "上步", Move.Kind.STEP, 0, 1, 0, 0, 0, {"tags":[&"身法"], "delta":-1}),
		_m(&"step_back", "撤步", Move.Kind.STEP, 0, 1, 1, 0, 0, {"tags":[&"身法"], "delta":1}),
	]

static func by_id(id: StringName) -> Move:
	for m in starter():
		if m.id == id: return m
	for m in boss_moves():
		if m.id == id: return m
	return null

# 基础攻击招 = 全部 9 门(下劈掌/侧踢等也是基础);这就是抽牌池。
static func basic_attacks() -> Array[Move]:
	return Hand.attack_pool(starter())

# boss 专属招(用现有词缀做特色;不在玩家池)
static func boss_moves() -> Array[Move]:
	return [
		# 青鳞毒叟(西毒/星宿):阴毒、霸体反震
		_m(&"toad_power", "蛤蟆劲", Move.Kind.ATTACK, 2, 1, 2, 10, 3, {"range":[0,1], "armor":true, "heavy":true, "inflict":[&"neishang"]}),
		_m(&"venom_palm", "毒砂掌", Move.Kind.ATTACK, 1, 1, 1, 11, 3, {"range":[0,1], "heavy":true, "inflict":[&"poison"]}),
		_m(&"rot_claw", "腐骨爪", Move.Kind.ATTACK, 1, 1, 1, 7, 2, {"range":[0,0], "inflict":[&"sunder"]}),
		# 血河老魔(血刀):凶猛重斩
		_m(&"blood_blade", "血河刀", Move.Kind.ATTACK, 1, 1, 1, 12, 3, {"range":[0,1], "heavy":true, "knockback":true, "inflict":[&"bleed"]}),
		_m(&"soul_reap", "噬魂斩", Move.Kind.ATTACK, 2, 1, 1, 13, 3, {"range":[0,1], "heavy":true, "interrupt":true, "inflict":[&"weak"]}),
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
	return _m(&"taiji_yunshou", "太极云手", Move.Kind.ATTACK, 0, 2, 1, 6, 0, {"tags":[&"掌法"], "hits":[0,1], "range":[0,2], "delta":-1, "priority":6, "empower":[&"focus"]})

# --- 初级功夫(补足每派 4 门) ---
static func fuhu() -> Move:  # 少林:拳+肘 → 伏虎拳
	return _m(&"fuhu", "伏虎拳", Move.Kind.ATTACK, 0, 2, 1, 8, 0, {"tags":[&"拳法"], "hits":[0,1], "range":[0,1], "empower":[&"vigor"]})
static func wudang_changquan() -> Move:  # 武当:拳×2 → 武当长拳
	return _m(&"wudang_changquan", "武当长拳", Move.Kind.ATTACK, 0, 2, 1, 7, 0, {"tags":[&"拳法"], "hits":[0,1], "range":[0,1]})
static func mianli() -> Move:  # 武当:闪身+掌 → 绵里藏针(借力柔掌)
	return _m(&"mianli", "绵里藏针", Move.Kind.ATTACK, 0, 1, 1, 7, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1]})
static func rouyun() -> Move:  # 武当:掌+腿 → 柔云腿
	return _m(&"rouyun", "柔云腿", Move.Kind.ATTACK, 0, 2, 1, 7, 0, {"tags":[&"掌法"], "hits":[0,1], "range":[0,1], "delta":-1})

# --- 高级功夫(稀有强力;需初级功夫熟练才能领悟) ---
static func prajna() -> Move:  # 少林:掌×3 → 般若神掌
	return _m(&"prajna", "般若神掌", Move.Kind.ATTACK, 0, 1, 2, 14, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "heavy":true, "armor":true, "guard":3})
static func wuying() -> Move:  # 少林:连环踢+腿×2 → 佛山无影脚(已有,归高级)
	return _m(&"wuying", "佛山无影脚", Move.Kind.ATTACK, 0, 3, 1, 8, 0, {"tags":[&"腿法"], "hits":[0,1,2], "armor":true, "range":[0,1]})
static func da_yunshou() -> Move:  # 武当:掌×3 → 大成云手
	return _m(&"da_yunshou", "大成·云手", Move.Kind.ATTACK, 0, 3, 1, 7, 0, {"tags":[&"掌法"], "hits":[0,1,2], "range":[0,2], "delta":-1, "priority":7})
static func liangyi() -> Move:  # 武当:拳×3 → 两仪连环
	return _m(&"liangyi", "两仪连环", Move.Kind.ATTACK, 0, 3, 1, 8, 0, {"tags":[&"拳法"], "hits":[0,1,2], "range":[0,1], "armor":true})

# --- 少林扩充 ---
static func weituo() -> Move:  # 掌+肘 → 韦陀掌(重掌破霸体 + 铁布)
	return _m(&"weituo", "韦陀掌", Move.Kind.ATTACK, 0, 1, 2, 9, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "heavy":true, "armor":true, "empower":[&"ironbody"]})
static func heihu() -> Move:  # 拳+腿 → 黑虎拳
	return _m(&"heihu", "黑虎拳", Move.Kind.ATTACK, 0, 2, 1, 6, 0, {"tags":[&"拳法"], "hits":[0,1], "range":[0,1]})
static func jinzhong() -> Move:  # 格挡×2 → 金钟罩(强护体 + 疗息)
	return _m(&"jinzhong", "金钟罩", Move.Kind.ATTACK, 0, 1, 1, 4, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "guard":6, "empower":[&"mend"]})
static func jingang_zhang() -> Move:  # 掌+掌+肘 → 大力金刚掌(破防)
	return _m(&"jingang_zhang", "大力金刚掌", Move.Kind.ATTACK, 1, 1, 2, 13, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "heavy":true, "interrupt":true})
static func damo_quan() -> Move:  # 拳+肘+拳 → 达摩伏魔拳(绝世·稀缺)
	return _m(&"damo_quan", "达摩伏魔拳", Move.Kind.ATTACK, 0, 3, 1, 10, 0, {"tags":[&"拳法"], "hits":[0,1,2], "range":[0,1], "armor":true})

# --- 武当扩充 ---
static func lanque() -> Move:  # 闪+腿 → 揽雀尾(化劲走位)
	return _m(&"lanque", "揽雀尾", Move.Kind.ATTACK, 0, 1, 1, 6, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "delta":-1})
static func tuishou() -> Move:  # 格挡+掌 → 太极推手(借力)
	return _m(&"tuishou", "太极推手", Move.Kind.ATTACK, 0, 1, 1, 6, 0, {"tags":[&"掌法"], "hits":[0], "range":[1,1]})
static func tiyun() -> Move:  # 闪×2 → 梯云纵(轻功走位)
	return _m(&"tiyun", "梯云纵", Move.Kind.ATTACK, 0, 1, 0, 4, 0, {"tags":[&"身法"], "hits":[0], "range":[0,2], "delta":-1, "priority":8})
static func sixiang() -> Move:  # 掌+掌+腿 → 四象掌
	return _m(&"sixiang", "四象掌", Move.Kind.ATTACK, 0, 2, 1, 7, 0, {"tags":[&"掌法"], "hits":[0,1], "range":[0,2], "delta":-1})
static func taixu() -> Move:  # 掌+闪+掌 → 太虚剑意(绝世·稀缺)
	return _m(&"taixu", "太虚剑意", Move.Kind.ATTACK, 0, 2, 1, 11, 0, {"tags":[&"掌法"], "hits":[0,1], "range":[0,2], "priority":9, "armor":true})

# --- 通用绝学(铺量) ---
static func saotang() -> Move:  # 腿×2 → 扫膛腿
	return _m(&"saotang", "扫膛腿", Move.Kind.ATTACK, 0, 2, 1, 7, 0, {"tags":[&"腿法"], "hits":[0,1], "range":[0,1], "knockback":true})
static func shuangfeng() -> Move:  # 肘×2 → 双风贯耳
	return _m(&"shuangfeng", "双风贯耳", Move.Kind.ATTACK, 0, 1, 1, 8, 0, {"tags":[&"肘膝"], "hits":[0], "range":[0,0], "stun":1})
static func jiequan() -> Move:  # 拳+掌 → 截拳
	return _m(&"jiequan", "截拳", Move.Kind.ATTACK, 0, 2, 1, 7, 0, {"tags":[&"拳法"], "hits":[0,1], "range":[0,1], "interrupt":true})
static func bajiquan() -> Move:  # 拳+肘+肘 → 八极崩
	return _m(&"bajiquan", "八极崩", Move.Kind.ATTACK, 1, 1, 1, 13, 0, {"tags":[&"肘膝"], "hits":[0], "range":[0,0], "heavy":true, "knockback":true})
static func paiyun() -> Move:  # 掌×4 → 排云双掌
	return _m(&"paiyun", "排云双掌", Move.Kind.ATTACK, 0, 3, 1, 11, 0, {"tags":[&"掌法"], "hits":[0,1,2], "range":[0,1], "armor":true})

# --- 少林铺量 ---
static func luohan_da() -> Move:  # 拳×4 → 罗汉伏魔神拳(罗汉拳升级)
	return _m(&"luohan_da", "罗汉伏魔神拳", Move.Kind.ATTACK, 0, 3, 1, 9, 0, {"tags":[&"拳法"], "hits":[0,1,2], "range":[0,1], "armor":true})
static func weituo_xiang() -> Move:  # 掌+肘+掌 → 韦陀降魔
	return _m(&"weituo_xiang", "韦陀降魔", Move.Kind.ATTACK, 1, 1, 2, 14, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "heavy":true, "interrupt":true})
static func jingang_bu() -> Move:  # 格挡×2+掌 → 金刚不坏(强护体)
	return _m(&"jingang_bu", "金刚不坏", Move.Kind.ATTACK, 0, 1, 1, 5, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "guard":7})
static func yingzhua() -> Move:  # 拳+擒 → 大力鹰爪(爪伤流血)
	return _m(&"yingzhua", "大力鹰爪", Move.Kind.ATTACK, 1, 1, 1, 8, 0, {"tags":[&"擒拿"], "hits":[0], "range":[0,0], "inflict":[&"bleed"]})
static func shibaluohan() -> Move:  # 拳+掌+肘+腿 → 十八罗汉手
	return _m(&"shibaluohan", "十八罗汉手", Move.Kind.ATTACK, 0, 3, 1, 13, 0, {"tags":[&"拳法"], "hits":[0,1,2], "range":[0,1], "armor":true, "interrupt":true})
static func damo_jian() -> Move:  # 掌+掌+拳 → 达摩剑指(稀缺)
	return _m(&"damo_jian", "达摩剑指", Move.Kind.ATTACK, 0, 1, 1, 10, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "interrupt":true, "priority":6})

# --- 武当铺量 ---
static func liangyi_jian() -> Move:  # 掌×3+腿 → 两仪剑法
	return _m(&"liangyi_jian", "两仪剑法", Move.Kind.ATTACK, 0, 3, 1, 12, 0, {"tags":[&"掌法"], "hits":[0,1,2], "range":[0,2], "delta":-1, "priority":7})
static func wuji() -> Move:  # 闪+闪+掌 → 无极玄功
	return _m(&"wuji", "无极玄功", Move.Kind.ATTACK, 0, 1, 1, 8, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "delta":-1})
static func taiji_quan() -> Move:  # 拳+掌+掌 → 太极拳
	return _m(&"taiji_quan", "太极拳", Move.Kind.ATTACK, 0, 2, 1, 8, 0, {"tags":[&"掌法"], "hits":[0,1], "range":[0,1], "delta":-1})
static func sanfeng() -> Move:  # 掌+闪+掌+闪 → 三丰遗剑(绝世·稀缺)
	return _m(&"sanfeng", "三丰遗剑", Move.Kind.ATTACK, 0, 3, 1, 14, 0, {"tags":[&"掌法"], "hits":[0,1,2], "range":[0,2], "priority":9, "armor":true})
static func qingshen() -> Move:  # 闪+身法 → 两仪轻身
	return _m(&"qingshen", "两仪轻身", Move.Kind.ATTACK, 0, 1, 0, 4, 0, {"tags":[&"身法"], "hits":[0], "range":[0,2], "delta":-1, "priority":8})
static func yunlong() -> Move:  # 腿+掌 → 云龙腿
	return _m(&"yunlong", "云龙腿", Move.Kind.ATTACK, 0, 2, 1, 7, 0, {"tags":[&"腿法"], "hits":[0,1], "range":[0,1], "delta":-1})

# --- 高级·绝世神功(t4-5;配方长,门槛高) ---
static func xianglong() -> Move:  # 掌×5 → 降龙十八掌(t5 绝世)
	return _m(&"xianglong", "降龙十八掌", Move.Kind.ATTACK, 1, 1, 2, 22, 0, {"tags":[&"掌法"], "hits":[0], "range":[0,1], "heavy":true, "armor":true, "interrupt":true, "knockback":true, "inflict":[&"neishang"]})
static func jingang_zhi() -> Move:  # 拳拳肘肘 → 大力金刚指(t4 少林)
	return _m(&"jingang_zhi", "大力金刚指", Move.Kind.ATTACK, 1, 1, 1, 16, 0, {"tags":[&"肘膝"], "hits":[0], "range":[0,0], "heavy":true, "interrupt":true, "stun":2})
static func liangyi_hua() -> Move:  # 掌闪掌腿 → 两仪化劲(t4 武当,卸力反制→敌虚弱)
	return _m(&"liangyi_hua", "两仪化劲", Move.Kind.ATTACK, 0, 2, 1, 12, 0, {"tags":[&"掌法"], "hits":[0,1], "range":[0,2], "delta":-1, "priority":8, "empower":[&"vigor"], "inflict":[&"weak"]})

# combo result moves (not in hand; produced by fusion) — fast flurries, no 前摇
static func chain_kick() -> Move:
	return _m(&"chain_kick", "连环踢", Move.Kind.ATTACK, 0, 2, 1, 7, 0, {"tags":[&"腿法"], "hits":[0,1], "range":[0,1]})
static func qiankun() -> Move:
	return _m(&"qiankun", "乾坤大挪移", Move.Kind.THROW, 0, 1, 1, 14, 0, {"range":[0,1]})

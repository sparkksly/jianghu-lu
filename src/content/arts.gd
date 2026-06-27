class_name Arts
extends RefCounted

# 功夫(组合招/绝学)注册表。数据驱动:每门功夫 = 一条 ArtDef。
# 加功夫 = 在 _defs() 加一条(或将来扫描 .tres);依赖写在 ArtDef.requires(见 Requirements)。
# 撞配方(多门功夫同 slots)由 ComboRules.recipe_candidates 多候选消歧。

static func _defs() -> Array:
	var M := func(art, need): return {"type": "art_mastery", "art": art, "need": need}
	return [
		# --- 初级功夫 ---
		ArtDef.make(&"luohan", "罗汉拳", 1, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"拳法"}, {"tag": &"拳法"}], Deck.luohan()),
		ArtDef.make(&"chain_kick", "连环踢", 1, [&"腿法"], [{"tag": &"腿法"}, {"tag": &"腿法"}, {"tag": &"腿法"}], Deck.chain_kick(), [], &"wuying_line", 0),
		ArtDef.make(&"jingang_fumo", "金刚伏魔", 1, [&"掌法"], [{"kind": Move.Kind.BLOCK}, {"tag": &"掌法"}], Deck.jingang_fumo()),
		ArtDef.make(&"fuhu", "伏虎拳", 1, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"肘膝"}], Deck.fuhu()),
		ArtDef.make(&"taiji_yunshou", "太极云手", 1, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}], Deck.taiji_yunshou()),
		ArtDef.make(&"wudang_changquan", "武当长拳", 1, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"拳法"}], Deck.wudang_changquan()),
		ArtDef.make(&"mianli", "绵里藏针", 1, [&"掌法"], [{"kind": Move.Kind.DODGE}, {"tag": &"掌法"}], Deck.mianli()),
		ArtDef.make(&"rouyun", "柔云腿", 1, [&"掌法", &"腿法"], [{"tag": &"掌法"}, {"tag": &"腿法"}], Deck.rouyun()),
		ArtDef.make(&"qiankun", "乾坤大挪移", 1, [&"综合"], [{"kind": Move.Kind.ATTACK}, {"kind": Move.Kind.BLOCK}, {"kind": Move.Kind.THROW}], Deck.qiankun(), [], &"", 0, [{"via": "encounter"}]),  # 绝世神功:只能奇遇得
		# --- 高级功夫(需初级功夫熟练) ---
		ArtDef.make(&"prajna", "般若神掌", 2, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}], Deck.prajna(), [M.call(&"jingang_fumo", 3)]),
		ArtDef.make(&"wuying", "佛山无影脚", 2, [&"腿法"], [{"tag": &"腿法"}, {"tag": &"腿法"}, {"tag": &"腿法"}, {"tag": &"腿法"}], Deck.wuying(), [{"type": "art_known", "art": &"chain_kick"}], &"wuying_line", 1, [{"via": "encounter"}, {"via": "insight", "triggers": [{"type": "tag_hits", "tag": &"腿法", "need": 5}, {"type": "tag_two_combo", "tag": &"腿法"}], "chance": 0.3}]),  # 连环踢升级版:奇遇可学/实战可顿悟,需先会连环踢
		ArtDef.make(&"da_yunshou", "大成·云手", 2, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}], Deck.da_yunshou(), [M.call(&"taiji_yunshou", 3)]),
		ArtDef.make(&"liangyi", "两仪连环", 2, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"拳法"}, {"tag": &"拳法"}], Deck.liangyi(), [M.call(&"wudang_changquan", 3)]),
		# --- 少林扩充 ---
		ArtDef.make(&"weituo", "韦陀掌", 2, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"肘膝"}], Deck.weituo(), [], &"weituo_line", 0),
		ArtDef.make(&"heihu", "黑虎拳", 1, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"腿法"}], Deck.heihu()),
		ArtDef.make(&"jinzhong", "金钟罩", 2, [&"护体"], [{"kind": Move.Kind.BLOCK}, {"kind": Move.Kind.BLOCK}], Deck.jinzhong()),
		ArtDef.make(&"jingang_zhang", "大力金刚掌", 2, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"肘膝"}], Deck.jingang_zhang(), [M.call(&"weituo", 3)], &"weituo_line", 1),  # 韦陀掌升级
		ArtDef.make(&"damo_quan", "达摩伏魔拳", 2, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"肘膝"}, {"tag": &"拳法"}], Deck.damo_quan(), [], &"", 0, [{"via": "encounter"}]),  # 稀缺·仅奇遇
		# --- 武当扩充 ---
		ArtDef.make(&"lanque", "揽雀尾", 1, [&"掌法"], [{"kind": Move.Kind.DODGE}, {"tag": &"腿法"}], Deck.lanque()),
		ArtDef.make(&"tuishou", "太极推手", 1, [&"掌法"], [{"kind": Move.Kind.BLOCK}, {"tag": &"掌法"}], Deck.tuishou()),
		ArtDef.make(&"tiyun", "梯云纵", 1, [&"身法"], [{"kind": Move.Kind.DODGE}, {"kind": Move.Kind.DODGE}], Deck.tiyun(), [], &"", 0, [{"via": "encounter"}, {"via": "insight", "triggers": [{"type": "tag_hits", "tag": &"身法", "need": 5}], "chance": 0.3}]),  # 走位多→实战顿悟轻功
		ArtDef.make(&"sixiang", "四象掌", 2, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"腿法"}], Deck.sixiang(), [M.call(&"rouyun", 3)]),
		ArtDef.make(&"taixu", "太虚剑意", 2, [&"掌法"], [{"tag": &"掌法"}, {"kind": Move.Kind.DODGE}, {"tag": &"掌法"}], Deck.taixu(), [], &"", 0, [{"via": "encounter"}]),  # 稀缺·仅奇遇
		# --- 通用绝学(铺量) ---
		ArtDef.make(&"saotang", "扫膛腿", 1, [&"腿法"], [{"tag": &"腿法"}, {"tag": &"腿法"}], Deck.saotang()),
		ArtDef.make(&"shuangfeng", "双风贯耳", 1, [&"肘膝"], [{"tag": &"肘膝"}, {"tag": &"肘膝"}], Deck.shuangfeng()),
		ArtDef.make(&"jiequan", "截拳", 1, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"掌法"}], Deck.jiequan()),
		ArtDef.make(&"bajiquan", "八极崩", 2, [&"肘膝"], [{"tag": &"拳法"}, {"tag": &"肘膝"}, {"tag": &"肘膝"}], Deck.bajiquan()),
		ArtDef.make(&"paiyun", "排云双掌", 3, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}], Deck.paiyun()),
		# --- 少林铺量 ---
		ArtDef.make(&"luohan_da", "罗汉伏魔神拳", 2, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"拳法"}, {"tag": &"拳法"}, {"tag": &"拳法"}], Deck.luohan_da(), [{"type": "art_known", "art": &"luohan"}], &"luohan_line", 1),
		ArtDef.make(&"weituo_xiang", "韦陀降魔", 2, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"肘膝"}, {"tag": &"掌法"}], Deck.weituo_xiang()),
		ArtDef.make(&"jingang_bu", "金刚不坏", 2, [&"护体"], [{"kind": Move.Kind.BLOCK}, {"kind": Move.Kind.BLOCK}, {"tag": &"掌法"}], Deck.jingang_bu()),
		ArtDef.make(&"yingzhua", "大力鹰爪", 1, [&"擒拿"], [{"tag": &"拳法"}, {"kind": Move.Kind.THROW}], Deck.yingzhua()),
		ArtDef.make(&"shibaluohan", "十八罗汉手", 3, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"掌法"}, {"tag": &"肘膝"}, {"tag": &"腿法"}], Deck.shibaluohan()),
		ArtDef.make(&"damo_jian", "达摩剑指", 2, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"拳法"}], Deck.damo_jian(), [], &"", 0, [{"via": "encounter"}]),
		# --- 武当铺量 ---
		ArtDef.make(&"liangyi_jian", "两仪剑法", 3, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"腿法"}], Deck.liangyi_jian()),
		ArtDef.make(&"wuji", "无极玄功", 2, [&"掌法"], [{"kind": Move.Kind.DODGE}, {"kind": Move.Kind.DODGE}, {"tag": &"掌法"}], Deck.wuji()),
		ArtDef.make(&"taiji_quan", "太极拳", 2, [&"掌法"], [{"tag": &"拳法"}, {"tag": &"掌法"}, {"tag": &"掌法"}], Deck.taiji_quan()),
		ArtDef.make(&"sanfeng", "三丰遗剑", 3, [&"掌法"], [{"tag": &"掌法"}, {"kind": Move.Kind.DODGE}, {"tag": &"掌法"}, {"kind": Move.Kind.DODGE}], Deck.sanfeng(), [], &"", 0, [{"via": "encounter"}]),
		ArtDef.make(&"qingshen", "两仪轻身", 1, [&"身法"], [{"kind": Move.Kind.DODGE}, {"tag": &"身法"}], Deck.qingshen()),
		ArtDef.make(&"yunlong", "云龙腿", 1, [&"腿法"], [{"tag": &"腿法"}, {"tag": &"掌法"}], Deck.yunlong()),
		# --- 高级·绝世神功(t4-5;门槛高,稀缺) ---
		ArtDef.make(&"xianglong", "降龙十八掌", 5, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}], Deck.xianglong(), [{"type": "arts_count", "family": &"掌法", "need": 3}], &"", 0, [{"via": "encounter"}]),
		ArtDef.make(&"jingang_zhi", "大力金刚指", 4, [&"肘膝"], [{"tag": &"拳法"}, {"tag": &"拳法"}, {"tag": &"肘膝"}, {"tag": &"肘膝"}], Deck.jingang_zhi(), [{"type": "arts_count", "family": &"拳法", "need": 2}]),
		ArtDef.make(&"liangyi_hua", "两仪化劲", 4, [&"掌法"], [{"tag": &"掌法"}, {"kind": Move.Kind.DODGE}, {"tag": &"掌法"}, {"tag": &"腿法"}], Deck.liangyi_hua(), [{"type": "arts_count", "family": &"掌法", "need": 2}]),
	]

static func def(id: StringName) -> ArtDef:
	for a in _defs():
		if a.id == id:
			return a
	return null

static func recipe(id: StringName) -> Dictionary:
	var a := def(id)
	return {"slots": a.slots, "result": a.result} if a != null else {}

static func tier(id: StringName) -> int:
	var a := def(id)
	return a.tier if a != null else 1

static func family(id: StringName) -> Array:
	var a := def(id)
	return a.family if a != null else []

static func display_name(id: StringName) -> String:
	var a := def(id)
	return a.art_name if a != null else str(id)

# 配方文本(图鉴用):"拳法 + 拳法 + 拳法 → 罗汉拳"。
static func recipe_text(id: StringName) -> String:
	var a := def(id)
	if a == null:
		return ""
	var parts: Array = []
	for s in a.slots:
		if s.has("id"): parts.append(Loc.move_name(s["id"]))
		elif s.has("tag"): parts.append(str(s["tag"]))
		elif s.has("kind"): parts.append(Loc.kind_name(s["kind"]))
		else: parts.append("任意")
	return " + ".join(parts) + " → " + a.art_name

# 获得途径(数据驱动):该功夫能从哪些 via 获得 + 各自条件。
static func sources(id: StringName) -> Array:
	var a := def(id)
	return a.sources if a != null else []

static func source_via(id: StringName, via: String) -> Dictionary:
	for s in sources(id):
		if s.get("via", "") == via:
			return s
	return {}

static func has_source(id: StringName, via: String) -> bool:
	return not source_via(id, via).is_empty()

# 是否满足领悟条件(通用依赖;高级功夫需前置功夫熟练/数量等)。
static func can_learn(id: StringName, learned: Array, mastery: Dictionary) -> bool:
	var a := def(id)
	if a == null:
		return false
	return Requirements.met(a.requires, {"learned": learned, "mastery": mastery})

# 用已领悟列表构建连招规则(含进化)。
static func build_rules(learned: Array, evo := {}) -> ComboRules:
	var rules := ComboRules.new()
	for id in learned:
		var a := def(id)
		if a != null:
			rules.add_recipe(a.slots, Evolve.apply(a.result, evo.get(id, {})))
	return rules

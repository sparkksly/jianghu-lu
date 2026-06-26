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
		ArtDef.make(&"qiankun", "乾坤大挪移", 1, [&"综合"], [{"kind": Move.Kind.ATTACK}, {"kind": Move.Kind.BLOCK}, {"kind": Move.Kind.THROW}], Deck.qiankun(), [], &"", 0, {}, true),  # 绝世神功:只能奇遇得
		# --- 高级功夫(需初级功夫熟练) ---
		ArtDef.make(&"prajna", "般若神掌", 2, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}], Deck.prajna(), [M.call(&"jingang_fumo", 3)]),
		ArtDef.make(&"wuying", "佛山无影脚", 2, [&"腿法"], [{"tag": &"腿法"}, {"tag": &"腿法"}, {"tag": &"腿法"}, {"tag": &"腿法"}], Deck.wuying(), [{"type": "art_known", "art": &"chain_kick"}], &"wuying_line", 1, {"triggers": [{"type": "tag_hits", "tag": &"腿法", "need": 5}, {"type": "tag_two_combo", "tag": &"腿法"}], "chance": 0.3}),  # 连环踢的升级版:需先会连环踢
		ArtDef.make(&"da_yunshou", "大成·云手", 2, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}], Deck.da_yunshou(), [M.call(&"taiji_yunshou", 3)]),
		ArtDef.make(&"liangyi", "两仪连环", 2, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"拳法"}, {"tag": &"拳法"}], Deck.liangyi(), [M.call(&"wudang_changquan", 3)]),
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

# 有 discovery 的功夫(实战顿悟)不进普通磨练池。
static func is_discovery(id: StringName) -> bool:
	var a := def(id)
	return a != null and not a.discovery.is_empty()

# 稀缺功夫(绝世神功)只能奇遇得,磨练/顿悟不出。
static func is_exotic(id: StringName) -> bool:
	var a := def(id)
	return a != null and a.exotic

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

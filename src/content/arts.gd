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
		ArtDef.make(&"chain_kick", "连环踢", 1, [&"腿法"], [{"tag": &"腿法"}, {"tag": &"腿法"}, {"tag": &"腿法"}], Deck.chain_kick()),
		ArtDef.make(&"jingang_fumo", "金刚伏魔", 1, [&"掌法"], [{"kind": Move.Kind.BLOCK}, {"tag": &"掌法"}], Deck.jingang_fumo()),
		ArtDef.make(&"fuhu", "伏虎拳", 1, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"肘膝"}], Deck.fuhu()),
		ArtDef.make(&"taiji_yunshou", "太极云手", 1, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}], Deck.taiji_yunshou()),
		ArtDef.make(&"wudang_changquan", "武当长拳", 1, [&"拳法"], [{"tag": &"拳法"}, {"tag": &"拳法"}], Deck.wudang_changquan()),
		ArtDef.make(&"mianli", "绵里藏针", 1, [&"掌法"], [{"kind": Move.Kind.DODGE}, {"tag": &"掌法"}], Deck.mianli()),
		ArtDef.make(&"rouyun", "柔云腿", 1, [&"掌法", &"腿法"], [{"tag": &"掌法"}, {"tag": &"腿法"}], Deck.rouyun()),
		ArtDef.make(&"qiankun", "乾坤大挪移", 1, [&"综合"], [{"kind": Move.Kind.ATTACK}, {"kind": Move.Kind.BLOCK}, {"kind": Move.Kind.THROW}], Deck.qiankun()),
		# --- 高级功夫(需初级功夫熟练) ---
		ArtDef.make(&"prajna", "般若神掌", 2, [&"掌法"], [{"tag": &"掌法"}, {"tag": &"掌法"}, {"tag": &"掌法"}], Deck.prajna(), [M.call(&"jingang_fumo", 3)]),
		ArtDef.make(&"wuying", "佛山无影脚", 2, [&"腿法"], [{"id": &"chain_kick"}, {"tag": &"腿法"}, {"tag": &"腿法"}], Deck.wuying(), [M.call(&"chain_kick", 3)]),
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

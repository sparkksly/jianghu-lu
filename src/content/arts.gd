class_name Arts
extends RefCounted

# 门派功夫(组合招/绝学)注册表。分初级(tier1)/高级(tier2)。
# 高级功夫 unlock = 需某门初级功夫的熟练度达标才能领悟。
# 输入都是基础动作 → 合成功夫。

static func _registry() -> Dictionary:
	var P := func(t): return {"tag": t}
	var K := func(k): return {"kind": k}
	return {
		# --- 初级功夫 ---
		&"luohan": {"slots": [P.call(&"拳法"), P.call(&"拳法"), P.call(&"拳法")], "result": Deck.luohan(), "tier": 1, "unlock": {}},
		&"chain_kick": {"slots": [P.call(&"腿法"), P.call(&"腿法"), P.call(&"腿法")], "result": Deck.chain_kick(), "tier": 1, "unlock": {}},
		&"jingang_fumo": {"slots": [K.call(Move.Kind.BLOCK), P.call(&"掌法")], "result": Deck.jingang_fumo(), "tier": 1, "unlock": {}},
		&"fuhu": {"slots": [P.call(&"拳法"), P.call(&"肘膝")], "result": Deck.fuhu(), "tier": 1, "unlock": {}},
		&"taiji_yunshou": {"slots": [P.call(&"掌法"), P.call(&"掌法")], "result": Deck.taiji_yunshou(), "tier": 1, "unlock": {}},
		&"wudang_changquan": {"slots": [P.call(&"拳法"), P.call(&"拳法")], "result": Deck.wudang_changquan(), "tier": 1, "unlock": {}},
		&"mianli": {"slots": [K.call(Move.Kind.DODGE), P.call(&"掌法")], "result": Deck.mianli(), "tier": 1, "unlock": {}},
		&"rouyun": {"slots": [P.call(&"掌法"), P.call(&"腿法")], "result": Deck.rouyun(), "tier": 1, "unlock": {}},
		&"qiankun": {"slots": [K.call(Move.Kind.ATTACK), K.call(Move.Kind.BLOCK), K.call(Move.Kind.THROW)], "result": Deck.qiankun(), "tier": 1, "unlock": {}},
		# --- 高级功夫(需初级功夫熟练) ---
		&"prajna": {"slots": [P.call(&"掌法"), P.call(&"掌法"), P.call(&"掌法")], "result": Deck.prajna(), "tier": 2, "unlock": {"art": &"jingang_fumo", "need": 3}},
		&"wuying": {"slots": [{"id": &"chain_kick"}, P.call(&"腿法"), P.call(&"腿法")], "result": Deck.wuying(), "tier": 2, "unlock": {"art": &"chain_kick", "need": 3}},
		&"da_yunshou": {"slots": [P.call(&"掌法"), P.call(&"掌法"), P.call(&"掌法")], "result": Deck.da_yunshou(), "tier": 2, "unlock": {"art": &"taiji_yunshou", "need": 3}},
		&"liangyi": {"slots": [P.call(&"拳法"), P.call(&"拳法"), P.call(&"拳法")], "result": Deck.liangyi(), "tier": 2, "unlock": {"art": &"wudang_changquan", "need": 3}},
	}

static func recipe(id: StringName) -> Dictionary:
	return _registry().get(id, {})

static func tier(id: StringName) -> int:
	return int(recipe(id).get("tier", 1))

static func unlock(id: StringName) -> Dictionary:
	return recipe(id).get("unlock", {})

static func display_name(id: StringName) -> String:
	var r := recipe(id)
	return (r["result"] as Move).move_name if not r.is_empty() else str(id)

# 是否满足领悟条件(高级功夫需初级功夫熟练)。
static func can_learn(id: StringName, mastery: Dictionary) -> bool:
	var u := unlock(id)
	if u.is_empty():
		return true
	return int(mastery.get(u["art"], 0)) >= int(u["need"])

# 用已领悟列表构建连招规则(含进化)。
static func build_rules(learned: Array, evo := {}) -> ComboRules:
	var rules := ComboRules.new()
	var reg := _registry()
	for id in learned:
		if reg.has(id):
			var res: Move = Evolve.apply(reg[id]["result"], evo.get(id, {}))
			rules.add_recipe(reg[id]["slots"], res)
	return rules

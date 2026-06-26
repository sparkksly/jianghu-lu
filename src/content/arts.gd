class_name Arts
extends RefCounted

# 绝学注册表:连招 id → {slots(配方), result(融合结果)}。
# 绝学靠「领悟」逐个解锁(见 run 成长);战斗的连招规则由已学列表构建。
# 输入都是基础动作 → 合成门派功夫。

static func _registry() -> Dictionary:
	return {
		# 通用绝学(两派都能领悟)
		&"chain_kick": {"slots": [{"tag":&"腿法"}, {"tag":&"腿法"}, {"tag":&"腿法"}], "result": Deck.chain_kick()},
		&"qiankun": {"slots": [{"kind":Move.Kind.ATTACK}, {"kind":Move.Kind.BLOCK}, {"kind":Move.Kind.THROW}], "result": Deck.qiankun()},
		# 少林
		&"luohan": {"slots": [{"tag":&"拳法"}, {"tag":&"拳法"}, {"tag":&"拳法"}], "result": Deck.luohan()},
		&"jingang_fumo": {"slots": [{"kind":Move.Kind.BLOCK}, {"tag":&"掌法"}], "result": Deck.jingang_fumo()},
		# 武当
		&"taiji_yunshou": {"slots": [{"tag":&"掌法"}, {"tag":&"掌法"}], "result": Deck.taiji_yunshou()},
	}

static func recipe(id: StringName) -> Dictionary:
	return _registry().get(id, {})

static func display_name(id: StringName) -> String:
	var r := recipe(id)
	return (r["result"] as Move).move_name if not r.is_empty() else str(id)

# 用已领悟列表构建连招规则。evo:绝学id→进化加成(迅捷/凝气对手拼连招生效;
# 沉重伤害在融合时按组件重算,故主要在化境单卡上吃满)。
static func build_rules(learned: Array, evo := {}) -> ComboRules:
	var rules := ComboRules.new()
	var reg := _registry()
	for id in learned:
		if reg.has(id):
			var res: Move = Evolve.apply(reg[id]["result"], evo.get(id, {}))
			rules.add_recipe(reg[id]["slots"], res)
	return rules

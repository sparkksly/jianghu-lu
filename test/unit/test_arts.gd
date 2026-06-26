extends GutTest

# 绝学注册表 + 按已领悟构建连招规则。

func _m(id: String) -> Move:
	return Deck.by_id(StringName(id))

func test_recipe_lookup():
	assert_false(Arts.recipe(&"luohan").is_empty())
	assert_true(Arts.recipe(&"nope").is_empty())

func test_display_name():
	assert_eq(Arts.display_name(&"luohan"), "罗汉拳")
	assert_eq(Arts.display_name(&"taiji_yunshou"), "太极云手")

func test_build_rules_only_includes_learned():
	var r := Arts.build_rules([&"luohan"])
	assert_not_null(r.recipe_result([_m("jab"), _m("hook"), _m("jab")]), "学了罗汉拳:拳×3可拼")
	assert_null(r.recipe_result([_m("push_palm"), _m("chop_palm")]), "没学云手:掌×2拼不出")

func test_empty_learned_has_no_combos():
	var r := Arts.build_rules([])
	assert_null(r.recipe_result([_m("jab"), _m("hook"), _m("jab")]), "什么都没学:拼不出连招")

func test_jingang_fumo_grants_guard():
	var r := Arts.build_rules([&"jingang_fumo"])
	var res := r.recipe_result([_m("guard"), _m("push_palm")])
	assert_not_null(res)
	assert_eq(res.id, &"jingang_fumo")
	assert_eq(res.grants_guard, 4)

func test_yunshou_recipe():
	var r := Arts.build_rules([&"taiji_yunshou"])
	var res := r.recipe_result([_m("push_palm"), _m("chop_palm")])
	assert_not_null(res)
	assert_eq(res.id, &"taiji_yunshou")

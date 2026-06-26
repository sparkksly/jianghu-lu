extends GutTest

func _m(id: String) -> Move:
	return Deck.by_id(StringName(id))

func test_tier_levels():
	assert_eq(Arts.tier(&"luohan"), 1, "罗汉拳=初级")
	assert_eq(Arts.tier(&"prajna"), 2, "般若神掌=高级")
	assert_false(Arts.recipe(&"luohan").is_empty())

func test_display_name():
	assert_eq(Arts.display_name(&"luohan"), "罗汉拳")
	assert_eq(Arts.display_name(&"prajna"), "般若神掌")

func test_can_learn_basic_always():
	assert_true(Arts.can_learn(&"luohan", [], {}))
	assert_true(Arts.can_learn(&"jingang_fumo", [], {}))

func test_can_learn_advanced_needs_prereq_mastery():
	assert_false(Arts.can_learn(&"prajna", [], {}), "无熟练不能领悟高级")
	assert_false(Arts.can_learn(&"prajna", [], {&"jingang_fumo": 2}), "熟练不足")
	assert_true(Arts.can_learn(&"prajna", [], {&"jingang_fumo": 3}), "初级功夫熟练达标→可领悟")

func test_family_lookup():
	assert_true(&"拳法" in Arts.family(&"luohan"))
	assert_true(&"掌法" in Arts.family(&"prajna"))

func test_recipe_candidates_disambiguates_clash():
	# 般若神掌 与 大成云手 同配方(掌×3) → 两门都会时撞配方,返回两候选
	var r := Arts.build_rules([&"prajna", &"da_yunshou"])
	var cands := r.recipe_candidates([_m("push_palm"), _m("chop_palm"), _m("push_palm")])
	assert_eq(cands.size(), 2, "撞配方→两门候选供玩家选")

func test_def_is_artdef():
	assert_eq(Arts.def(&"luohan").art_name, "罗汉拳")
	assert_eq(Arts.def(&"prajna").tier, 2)

func test_build_rules_luohan_from_three_fists():
	var r := Arts.build_rules([&"luohan"])
	assert_not_null(r.recipe_result([_m("jab"), _m("hook"), _m("jab")]))

func test_empty_learned_no_combos():
	assert_null(Arts.build_rules([]).recipe_result([_m("jab"), _m("hook"), _m("jab")]))

func test_jingang_fumo_grants_guard():
	var r := Arts.build_rules([&"jingang_fumo"])
	var res := r.recipe_result([_m("guard"), _m("push_palm")])
	assert_not_null(res)
	assert_eq(res.grants_guard, 4)

func test_prajna_from_three_palms():
	var r := Arts.build_rules([&"prajna"])
	var res := r.recipe_result([_m("push_palm"), _m("chop_palm"), _m("push_palm")])
	assert_not_null(res)
	assert_eq(res.id, &"prajna")

func test_wuying_is_discovery():
	assert_true(Arts.is_discovery(&"wuying"), "无影脚=实战顿悟")
	assert_false(Arts.is_discovery(&"luohan"))

func test_recipe_text_shows_formula():
	assert_string_contains(Arts.recipe_text(&"luohan"), "罗汉拳")
	assert_string_contains(Arts.recipe_text(&"luohan"), "拳法")

func test_qiankun_is_exotic():
	assert_true(Arts.is_exotic(&"qiankun"), "乾坤=稀缺绝世神功")
	assert_false(Arts.is_exotic(&"luohan"))

func test_wuying_requires_chain_kick():
	assert_false(Arts.can_learn(&"wuying", [], {}), "没会连环踢不能领悟无影脚")
	assert_true(Arts.can_learn(&"wuying", [&"chain_kick"], {}), "会连环踢→可领悟其升级版")

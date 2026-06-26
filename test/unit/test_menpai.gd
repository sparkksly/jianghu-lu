extends GutTest

func test_shaolin_pool_is_seven_attacks():
	var pool := Menpai.pool(&"shaolin")
	assert_eq(pool.size(), 7)
	for m in pool:
		assert_eq(m.kind, Move.Kind.ATTACK, "进攻池皆 ATTACK")

func test_wudang_pool_is_five():
	assert_eq(Menpai.pool(&"wudang").size(), 5)

func test_unknown_menpai_defaults_to_shaolin():
	assert_eq(Menpai.pool(&"???").size(), 7)

func test_shaolin_gun_reaches_mid_far():
	var gun := Deck.by_id(&"shaolin_gun")
	assert_eq(gun.range_min, 1)
	assert_eq(gun.range_max, 2)

func test_luohan_recipe_from_three_fists():
	var r := Menpai.rules(&"shaolin")
	var res := r.recipe_result([Deck.by_id(&"jab"), Deck.by_id(&"hook"), Deck.by_id(&"beng_quan")])
	assert_not_null(res, "拳法×3 应融合")
	assert_eq(res.id, &"luohan")

func test_jingang_fumo_grants_guard():
	var r := Menpai.rules(&"shaolin")
	var res := r.recipe_result([Deck.by_id(&"guard"), Deck.by_id(&"weituo")])
	assert_not_null(res, "格挡+韦陀掌 应融合")
	assert_eq(res.id, &"jingang_fumo")
	assert_eq(res.grants_guard, 4, "金刚伏魔挂护体4拍")

func test_yunshou_recipe_from_two_mian():
	var r := Menpai.rules(&"wudang")
	var res := r.recipe_result([Deck.by_id(&"mian_zhang"), Deck.by_id(&"mian_zhang")])
	assert_not_null(res, "绵掌×2 应融合")
	assert_eq(res.id, &"taiji_yunshou")
	assert_eq(res.distance_delta, -1, "云手贴近一步")

func test_base_rules_have_no_fist_combo():
	# 通用 base 不含门派配方,现有 combo 测试不受影响
	var base := ComboLibrary.build()
	var res := base.recipe_result([Deck.by_id(&"jab"), Deck.by_id(&"hook"), Deck.by_id(&"beng_quan")])
	assert_null(res, "base 不出罗汉拳")

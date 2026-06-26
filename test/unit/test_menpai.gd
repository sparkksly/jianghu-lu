extends GutTest

func _m(id: String) -> Move:
	return Deck.by_id(StringName(id))

# 门派进攻池 = 通用基础动作(两派相同)。差别在能合成的绝学。
func test_both_menpai_draw_from_shared_base_pool():
	var sh := Menpai.pool(&"shaolin")
	var wu := Menpai.pool(&"wudang")
	assert_eq(sh.size(), wu.size(), "两派抽牌池相同(都是基础动作)")
	for m in sh:
		assert_eq(m.kind, Move.Kind.ATTACK)
	# 基础动作里没有门派专属基础招了
	for m in sh:
		assert_false(m.id in [&"beng_quan", &"weituo", &"mian_zhang", &"shaolin_gun"], "门派招不该是基础招")

# 少林:拳法×3 → 罗汉拳(基础拳合成)
func test_shaolin_luohan_from_three_base_fists():
	var r := Menpai.rules(&"shaolin")
	var res := r.recipe_result([_m("jab"), _m("hook"), _m("jab")])
	assert_not_null(res, "三记基础拳应合成罗汉拳")
	assert_eq(res.id, &"luohan")

# 少林:格挡 + 掌法 → 金刚伏魔(挂护体)
func test_shaolin_jingang_fumo_grants_guard():
	var r := Menpai.rules(&"shaolin")
	var res := r.recipe_result([_m("guard"), _m("push_palm")])
	assert_not_null(res, "格挡+基础掌应合成金刚伏魔")
	assert_eq(res.id, &"jingang_fumo")
	assert_eq(res.grants_guard, 4)

# 武当:掌法×2 → 太极云手(走位)
func test_wudang_yunshou_from_two_base_palms():
	var r := Menpai.rules(&"wudang")
	var res := r.recipe_result([_m("push_palm"), _m("chop_palm")])
	assert_not_null(res, "两记基础掌应合成太极云手")
	assert_eq(res.id, &"taiji_yunshou")
	assert_eq(res.distance_delta, -1)

# 通用 base 不含门派绝学配方(现有 combo 测试不受影响)
func test_base_rules_have_no_menpai_combo():
	var base := ComboLibrary.build()
	assert_null(base.recipe_result([_m("jab"), _m("hook"), _m("jab")]), "base 不出罗汉拳")
	assert_null(base.recipe_result([_m("push_palm"), _m("chop_palm")]), "base 不出云手")

# 武当不会合成少林绝学(门派区分)
func test_wudang_cannot_make_shaolin_combo():
	var r := Menpai.rules(&"wudang")
	assert_null(r.recipe_result([_m("jab"), _m("hook"), _m("jab")]), "武当无罗汉拳")

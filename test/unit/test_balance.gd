extends GutTest

func test_power_nonnegative():
	for a in Arts._defs():
		assert_gte(Balance.power(a), 0, str(a.id))

func test_budget_curve_increasing():
	assert_lt(Balance.budget(1), Balance.budget(2))
	assert_lt(Balance.budget(2), Balance.budget(3))
	assert_lt(Balance.budget(4), Balance.budget(5))

func test_all_arts_within_tier_budget():
	# 平衡审查:遍历所有武功,超容差的报出(几百门时一眼看出超模/弱鸡)
	var off: Array = []
	for a in Arts._defs():
		if not Balance.in_tolerance(a):
			off.append("%s(t%d p%d b%d)" % [a.id, a.tier, Balance.power(a), Balance.budget(a.tier)])
	if off.size() > 0:
		gut.p("⚠ 超预算: " + str(off))
	assert_lte(off.size(), 1, "超容差武功应极少")

func test_condition_factor_controllable_is_higher():
	# 可控条件(借力)系数 > 不可控(残血):同 bonus,可控的折算 power 更高 → 可控条件只能配小 bonus
	assert_gt(Balance.CONDITION_FACTOR["leverage"], Balance.CONDITION_FACTOR["hp_below"])

func test_requires_discount_below_one():
	assert_lt(Balance.REQUIRES_DISCOUNT, 1.0, "有门槛→视作更便宜,预算内可更强")

func test_conditional_adds_discounted_power():
	# 条件加成按系数折算进 power
	var a := ArtDef.make(&"_t", "test", 1, [], [{"tag": &"拳法"}], Deck.luohan())
	var base := Balance.power(a)
	a.conditional = [{"when": {"type": "hp_below"}, "bonus": [{"stat": "dmg_inc", "value": 100}]}]
	assert_gt(Balance.power(a), base, "条件加成进 power(打折后)")

func test_advanced_arts_tiers():
	# t4-5 高级功夫存在且落预算
	assert_eq(Arts.tier(&"xianglong"), 5, "降龙十八掌 = t5 绝世")
	assert_eq(Arts.tier(&"jingang_zhi"), 4)
	assert_eq(Arts.tier(&"liangyi_hua"), 4)
	for id in [&"xianglong", &"jingang_zhi", &"liangyi_hua"]:
		assert_true(Balance.in_tolerance(Arts.def(id)), "%s 落 tier 预算" % id)

extends GutTest

func _rng(s := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func test_roll_returns_3_distinct_types():
	var run := RunState.new(&"shaolin")
	for s in range(1, 30):
		var rw := RunRewards.roll_basic(_rng(s), run)
		assert_eq(rw.size(), 3, "三选一")
		var types := {}
		for r in rw: types[r["type"]] = true
		assert_eq(types.size(), 3, "三个类型互异(seed %d)" % s)

func test_pool_has_variety_across_rolls():
	# 多次 roll 应出现多种奖励类型(不再固定 hp/meditate/hone)
	var run := RunState.new(&"shaolin")
	var seen := {}
	for s in range(1, 40):
		for r in RunRewards.roll_basic(_rng(s), run):
			seen[r["type"]] = true
	assert_gte(seen.size(), 6, "奖励种类丰富")

func test_apply_attack_reward():
	var r := RunState.new(&"shaolin")
	var a0 := r.combat_attack()
	r.apply_reward({"type": "attack"})
	assert_eq(r.combat_attack(), a0 + 2)

func test_apply_extra_and_dmg_inc():
	var r := RunState.new(&"shaolin")
	r.apply_reward({"type": "dmg_inc"})
	r.apply_reward({"type": "extra_dmg"})
	assert_eq(r.combat_dmg_inc(), 8)
	assert_eq(r.combat_extra(), 6)

func test_apply_money_and_learn():
	var r := RunState.new(&"shaolin")
	r.money = 0
	r.apply_reward({"type": "money"})
	assert_eq(r.money, 35)
	var arts := r.self_learnable_arts()
	if arts.size() > 0:
		r.apply_reward({"type": "learn", "id": arts[0]})
		assert_true(r.learned.has(arts[0]), "顿悟领悟该功夫")

func test_learn_excluded_when_no_self_learnable():
	# run==null → 顿悟不入池(避免崩)
	var rw := RunRewards.roll_basic(_rng(3), null)
	for r in rw:
		assert_ne(r["type"], "learn", "无 run 时不出顿悟")

func test_hone_targets_learned_family():
	# 磨练定向:学了截拳[拳+掌] → 磨练优先拳/掌基础招(不撒到腿/肘)
	var r := RunState.new(&"shaolin", &"", [&"jiequan"])
	for s in range(1, 30):
		var rw := RunRewards._make_reward("hone", _rng(s), r)
		var m := Deck.by_id(rw["id"])
		var fam_ok := false
		for t in m.tags:
			if str(t) in ["拳法", "掌法"]: fam_ok = true
		assert_true(fam_ok, "磨练落在专精家族(拳/掌)")

func test_learn_prefers_specialized_family():
	var r := RunState.new(&"shaolin", &"", [&"jiequan", &"luohan"])  # 拳掌方向
	var arts := r.self_learnable_arts()
	if arts.size() >= 2:
		var rw := RunRewards._make_reward("learn", _rng(4), r)
		assert_true(rw["id"] in arts, "领悟从可悟池里选")

func test_qinggong_reward_grants_and_excludes_when_all_known():
	var r := RunState.new(&"shaolin")
	var rw := RunRewards._make_reward("qinggong", _rng(2), r)
	r.apply_reward(rw)
	assert_eq(r.qinggong.size(), 1, "身法奖励习得轻功")
	# 全习得后不再入池
	for id in Passives.by_category(&"轻功"): r.learn_qinggong(id)
	var seen_qg := false
	for s in range(1, 20):
		for rr in RunRewards.roll_basic(_rng(s), r):
			if rr["type"] == "qinggong": seen_qg = true
	assert_false(seen_qg, "轻功全习得后不再出身法选项")

extends GutTest

func test_starter_deck_has_each_role():
	var deck := Deck.starter()
	var kinds := {}
	for m in deck:
		kinds[m.kind] = true
	assert_true(kinds.has(Move.Kind.ATTACK))
	assert_true(kinds.has(Move.Kind.BLOCK))
	assert_true(kinds.has(Move.Kind.DODGE))
	assert_true(kinds.has(Move.Kind.THROW))
	assert_true(deck.any(func(m): return m.can_interrupt), "has an interrupt move")
	assert_true(deck.any(func(m): return m.super_armor), "has an armored move")

func test_three_kicks_fuse_into_chain_kick_and_deal_more():
	var rules := ComboLibrary.build()
	var find := func(id):
		for m in Deck.starter():
			if m.id == id: return m
		return null
	var k = find.call(&"sweep_kick")
	var p := Plan.new()
	p.add(PlacedMove.new(k, 0))
	p.add(PlacedMove.new(k, k.total_duration()))
	p.add(PlacedMove.new(k, 2 * k.total_duration()))
	var fused := rules.apply(p)
	assert_eq(fused.moves.size(), 1)
	assert_eq(fused.moves[0].move.id, &"chain_kick")

func test_starter_combos_fit_in_game_tick_budget():
	# Regression: when 拍 was 10, basic moves' footprints made 连环踢 nearly impossible
	# and 乾坤 (攻+防+投) flat-out didn't fit. Combos the player is meant to pull off
	# MUST fit (start at 0, back-to-back, end_tick <= n_ticks) in the real game budget.
	var budget := CombatState.new().n_ticks  # the canonical game tick count
	var rules := ComboLibrary.build()
	var find := func(id):
		for m in Deck.starter():
			if m.id == id: return m
		return null
	# 连环踢: three legs back-to-back from tick 0
	var leg = find.call(&"sweep_kick")
	var chain := Plan.new()
	var t := 0
	for i in 3:
		chain.add(PlacedMove.new(leg, t)); t += leg.total_duration()
	assert_true(chain.sorted()[-1].end_tick() <= budget, "三连腿法须装进 %d 拍" % budget)
	assert_eq(rules.apply(chain).moves[0].move.id, &"chain_kick")
	# 乾坤: 攻+防+投 back-to-back from tick 0
	var atk = find.call(&"sweep_kick"); var blk = find.call(&"guard"); var thr = find.call(&"grab")
	var qk := Plan.new()
	qk.add(PlacedMove.new(atk, 0))
	qk.add(PlacedMove.new(blk, atk.total_duration()))
	qk.add(PlacedMove.new(thr, atk.total_duration() + blk.total_duration()))
	assert_true(qk.sorted()[-1].end_tick() <= budget, "攻防投须装进 %d 拍" % budget)
	assert_eq(rules.apply(qk).moves[0].move.id, &"qiankun")

func test_full_fight_runs_to_a_death():
	var s := CombatState.new()
	s.hp=[30,30]; s.max_hp=[30,30]; s.stamina=[12,12]; s.sta_max=[12,12]; s.n_ticks=10
	var find := func(id):
		for m in Deck.starter():
			if m.id == id: return m
		return null
	var hk = find.call(&"side_kick")
	var p0 := Plan.new(); p0.add(PlacedMove.new(hk, 0)); p0.add(PlacedMove.new(hk, hk.total_duration()))
	var ev := CombatSim.simulate(s, [p0, Plan.new()])
	assert_true(s.hp[1] < 30, "enemy took damage")

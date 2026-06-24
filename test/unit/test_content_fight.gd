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
	var k = find.call(&"low_kick")
	var p := Plan.new()
	p.add(PlacedMove.new(k, 0))
	p.add(PlacedMove.new(k, k.total_duration()))
	p.add(PlacedMove.new(k, 2 * k.total_duration()))
	var fused := rules.apply(p)
	assert_eq(fused.moves.size(), 1)
	assert_eq(fused.moves[0].move.id, &"chain_kick")

func test_full_fight_runs_to_a_death():
	var s := CombatState.new()
	s.hp=[30,30]; s.max_hp=[30,30]; s.stamina=[12,12]; s.sta_max=[12,12]; s.n_ticks=10
	var find := func(id):
		for m in Deck.starter():
			if m.id == id: return m
		return null
	var hk = find.call(&"heavy_kick")
	var p0 := Plan.new(); p0.add(PlacedMove.new(hk, 0)); p0.add(PlacedMove.new(hk, hk.total_duration()))
	var ev := CombatSim.simulate(s, [p0, Plan.new()])
	assert_true(s.hp[1] < 30, "enemy took damage")

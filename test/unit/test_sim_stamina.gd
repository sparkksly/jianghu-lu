extends GutTest

func _state(sta := 10) -> CombatState:
	var s := CombatState.new()
	s.hp=[50,50]; s.max_hp=[50,50]; s.stamina=[sta,sta]; s.sta_max=[sta,sta]; s.n_ticks=12; s.gasp_len=3
	return s

func _atk(dmg, su, cost, heavy := false) -> Move:
	var m := Move.new(); m.id=&"a"; m.kind=Move.Kind.ATTACK
	m.startup=su; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=dmg; m.stamina_cost=cost; m.is_heavy=heavy
	return m

func _dodge(su, window) -> Move:
	var m := Move.new(); m.id=&"d"; m.kind=Move.Kind.DODGE; m.startup=su; m.active=window; m.recovery=1; m.stamina_cost=2
	return m

func test_hit_rewards_stamina():
	var s := _state(10)
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(6,1,2), 0)) # cost2, +1 on hit
	var ev := CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.stamina[0], 9, "10 -2 cost +1 reward = 9")

func test_heavy_whiff_penalty():
	var s := _state(10)
	var atk := Plan.new(); atk.add(PlacedMove.new(_atk(10,2,2,true), 0)) # heavy hits t2
	var dfn := Plan.new(); dfn.add(PlacedMove.new(_dodge(1,3), 0))
	CombatSim.simulate(s, [atk, dfn])
	assert_eq(s.stamina[0], 4, "10 -2 cost -4 heavy whiff = 4")

func test_exhaustion_then_gasp_bonus_damage():
	# player has only 2 stamina, plans two 2-cost moves: 2nd can't pay -> gasp.
	var s := _state(2); s.gasp_len = 3
	var p0 := Plan.new()
	p0.add(PlacedMove.new(_atk(0,1,2), 0))   # pays (2->0), hit deals 0, reward->1
	p0.add(PlacedMove.new(_atk(0,1,2), 3))   # needs 2, only has 1 -> gasp
	# enemy lands a hit during the player's gasp window to verify bonus
	var p1 := Plan.new(); p1.add(PlacedMove.new(_atk(5,1,2), 3)) # hits t4
	var ev := CombatSim.simulate(s, [p0, p1])
	var exhausts := ev.filter(func(e): return e.type == &"exhaust")
	assert_true(exhausts.size() >= 1, "player exhausted on 2nd move")
	# Enemy hits at t4 while player is gasping (gasp_until=6); bonus must apply.
	var expected_hp := 50 - (5 + CombatSim.GASP_DAMAGE_BONUS)  # = 42
	assert_eq(s.hp[0], expected_hp, "gasp bonus applied: player hp should be %d" % expected_hp)

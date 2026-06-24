extends GutTest

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [50, 50]; s.max_hp = [50, 50]
	s.stamina = [10, 10]; s.sta_max = [10, 10]
	s.n_ticks = 10
	return s

func _atk(dmg := 6, cost := 2) -> Move:
	var m := Move.new()
	m.id = &"kick"; m.kind = Move.Kind.ATTACK
	m.startup = 1; m.active = 1; m.recovery = 1
	m.hit_offsets = [0]; m.damage = dmg; m.stamina_cost = cost
	return m

func test_single_attack_deals_damage():
	var s := _state()
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(6), 0))
	var p1 := Plan.new()
	var ev := CombatSim.simulate(s, [p0, p1])
	assert_eq(s.hp[1], 44, "enemy took 6")
	assert_eq(s.stamina[0], 9, "player spent 2 stamina, gained 1 hit reward")
	var hits := ev.filter(func(e): return e.type == &"hit")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].tick, 1, "hit lands after 1 tick startup")

func test_both_attack_both_take_damage():
	var s := _state()
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(6), 0))
	var p1 := Plan.new(); p1.add(PlacedMove.new(_atk(4), 0))
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.hp[1], 44)
	assert_eq(s.hp[0], 46)

func test_deterministic():
	var s1 := _state(); var s2 := _state()
	var a := Plan.new(); a.add(PlacedMove.new(_atk(6), 0)); a.add(PlacedMove.new(_atk(6), 3))
	var b := Plan.new(); b.add(PlacedMove.new(_atk(4), 1))
	var e1 := CombatSim.simulate(s1, [a, b])
	# rebuild identical plans for second run
	var a2 := Plan.new(); a2.add(PlacedMove.new(_atk(6), 0)); a2.add(PlacedMove.new(_atk(6), 3))
	var b2 := Plan.new(); b2.add(PlacedMove.new(_atk(4), 1))
	var e2 := CombatSim.simulate(s2, [a2, b2])
	assert_eq(e1.map(func(e): return str(e)), e2.map(func(e): return str(e)))

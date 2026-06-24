extends GutTest

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [50, 50]; s.max_hp=[50,50]; s.stamina=[30,30]; s.sta_max=[30,30]; s.n_ticks=12
	return s

func _atk(dmg, su, heavy := false) -> Move:
	var m := Move.new(); m.id=&"atk"; m.kind=Move.Kind.ATTACK
	m.startup=su; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=dmg; m.stamina_cost=2; m.is_heavy=heavy
	return m

func _defense(kind, su, window) -> Move:
	var m := Move.new(); m.id=&"def"; m.kind=kind
	m.startup=su; m.active=window; m.recovery=1; m.stamina_cost=2
	return m

func _throw(dmg, su) -> Move:
	var m := Move.new(); m.id=&"throw"; m.kind=Move.Kind.THROW
	m.startup=su; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=dmg; m.stamina_cost=2
	return m

func test_block_negates_attack():
	var s := _state()
	# attacker hits at t2 (startup2). defender blocks with active window covering t2.
	var atk := Plan.new(); atk.add(PlacedMove.new(_atk(10, 2), 0))
	var dfn := Plan.new(); dfn.add(PlacedMove.new(_defense(Move.Kind.BLOCK, 1, 3), 0)) # active t1..t3
	CombatSim.simulate(s, [atk, dfn])
	assert_eq(s.hp[1], 50, "blocked, no damage")

func test_dodge_makes_attack_whiff():
	var s := _state()
	var atk := Plan.new(); atk.add(PlacedMove.new(_atk(10, 2, true), 0)) # heavy, hits t2
	var dfn := Plan.new(); dfn.add(PlacedMove.new(_defense(Move.Kind.DODGE, 1, 3), 0)) # dodge t1..t3
	var ev := CombatSim.simulate(s, [atk, dfn])
	assert_eq(s.hp[1], 50, "dodged, no damage")
	assert_eq(ev.filter(func(e): return e.type == &"whiff").size(), 1)

func test_throw_breaks_block():
	var s := _state()
	var thr := Plan.new(); thr.add(PlacedMove.new(_throw(6, 2), 0)) # hits t2
	var dfn := Plan.new(); dfn.add(PlacedMove.new(_defense(Move.Kind.BLOCK, 1, 3), 0))
	CombatSim.simulate(s, [thr, dfn])
	assert_eq(s.hp[1], 40, "throw break: 6 + 4 bonus = 10")

func test_blind_throw_is_weak():
	var s := _state()
	var thr := Plan.new(); thr.add(PlacedMove.new(_throw(6, 2), 0))
	var idle := Plan.new() # defender does nothing
	var ev := CombatSim.simulate(s, [thr, idle])
	assert_eq(s.hp[1], 50, "throw on non-blocker deals 0")
	assert_eq(ev.filter(func(e): return e.type == &"whiff").size(), 1)

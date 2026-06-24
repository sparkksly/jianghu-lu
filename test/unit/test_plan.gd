extends GutTest

func _atk(cost := 2, dur_startup := 1, dur_active := 1, dur_recovery := 1) -> Move:
	var m := Move.new()
	m.startup = dur_startup; m.active = dur_active; m.recovery = dur_recovery
	m.stamina_cost = cost
	return m

func test_placed_end_tick():
	var pm := PlacedMove.new(_atk(2, 2, 1, 2), 3) # duration 5
	assert_eq(pm.end_tick(), 8)

func test_total_cost_and_sorted():
	var p := Plan.new()
	p.add(PlacedMove.new(_atk(2), 4))
	p.add(PlacedMove.new(_atk(3), 0))
	assert_eq(p.total_cost(), 5)
	assert_eq(p.sorted()[0].start, 0)

func test_overcommit_allowed_up_to_1_5x():
	var p := Plan.new()
	p.add(PlacedMove.new(_atk(15), 0)) # 15 == floor(1.5*10)
	assert_true(p.is_valid(10, 10))
	var p2 := Plan.new()
	p2.add(PlacedMove.new(_atk(16), 0))
	assert_false(p2.is_valid(10, 10)) # over 1.5x

func test_no_overlap():
	var p := Plan.new()
	p.add(PlacedMove.new(_atk(1, 1, 1, 1), 0)) # occupies ticks 0..2
	p.add(PlacedMove.new(_atk(1, 1, 1, 1), 2)) # starts at 2 -> overlaps end_tick 3
	assert_false(p.is_valid(10, 10))

func test_state_clone_is_deep():
	var s := CombatState.new()
	s.hp = [50, 50]
	var c := s.clone()
	c.hp[0] = 1
	assert_eq(s.hp[0], 50, "clone must not alias arrays")

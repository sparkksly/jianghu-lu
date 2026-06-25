extends GutTest

func _atk(cost := 2, su := 1, act := 1, rec := 1) -> Move:
	var m := Move.new()
	m.startup = su; m.active = act; m.recovery = rec; m.stamina_cost = cost
	return m

func test_snap_tick_clamps():
	assert_eq(TimelineLogic.snap_tick(0.0, 40.0, 14), 0)
	assert_eq(TimelineLogic.snap_tick(95.0, 40.0, 14), 2)   # floor(95/40)=2
	assert_eq(TimelineLogic.snap_tick(9999.0, 40.0, 14), 13) # clamp to n-1
	assert_eq(TimelineLogic.snap_tick(-5.0, 40.0, 14), 0)

func test_with_and_without():
	var p := Plan.new()
	var p2 := TimelineLogic.with_move(p, _atk(), 0)
	assert_eq(p2.moves.size(), 1)
	assert_eq(p.moves.size(), 0, "original untouched")
	var p3 := TimelineLogic.without_index(p2, 0)
	assert_eq(p3.moves.size(), 0)

func test_can_place_rejects_overlap():
	var p := TimelineLogic.with_move(Plan.new(), _atk(2,1,1,1), 0) # occupies 0..2
	assert_false(TimelineLogic.can_place(p, _atk(2,1,1,1), 1, 10, 14), "overlaps")
	assert_true(TimelineLogic.can_place(p, _atk(2,1,1,1), 3, 10, 14), "fits after")

func test_can_place_respects_overcommit():
	# stamina_now=10 -> cap 13
	var p := TimelineLogic.with_move(Plan.new(), _atk(11,1,1,1), 0) # cost 11
	assert_true(TimelineLogic.can_place(p, _atk(2,1,1,1), 3, 10, 14), "13 total == cap")
	assert_false(TimelineLogic.can_place(p, _atk(3,1,1,1), 3, 10, 14), "14 total over cap")

func test_can_place_ignore_index_allows_self_move():
	var p := TimelineLogic.with_move(Plan.new(), _atk(2,1,1,1), 0) # index 0 at tick 0
	# moving that same move to tick 1 must ignore its own old footprint
	assert_true(TimelineLogic.can_place(p, p.moves[0].move, 1, 10, 14, 0))

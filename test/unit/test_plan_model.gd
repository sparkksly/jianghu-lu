extends GutTest

func _find(id) -> Move:
	for m in Deck.starter():
		if m.id == id:
			return m
	return null

func _model() -> PlanModel:
	return PlanModel.new(ComboLibrary.build(), 12)

func test_three_legs_offer_a_fuse_opportunity():
	var m := _model()
	var k = _find(&"low_kick")   # dur 2
	assert_true(m.place(k, 0)); assert_true(m.place(k, 2)); assert_true(m.place(k, 4))
	var ops := m.fuse_opportunities()
	assert_eq(ops.size(), 1, "a 连环踢 fuse hint is offered")
	assert_eq(ops[0]["result"].id, &"chain_kick")
	assert_eq(ops[0]["indices"].size(), 3)

func test_fuse_compresses_and_frees_reusable_space():
	var m := _model()
	var k = _find(&"low_kick")
	m.place(k, 0); m.place(k, 2); m.place(k, 4)   # occupy ticks 0..6
	assert_false(m.can_place(k, 4), "before fusing, tick 4 is occupied")
	m.fuse(m.fuse_opportunities()[0]["indices"])
	assert_eq(m.units.size(), 1, "three legs collapse into one compressed combo")
	# 连环踢 is 3 ticks (0..3); ticks 3..6 are now free and reusable
	assert_true(m.can_place(k, 3), "compression frees space for another move")
	assert_true(m.place(k, 3))
	var p := m.to_plan()
	assert_eq(p.moves.size(), 2, "combat runs the combo AND the extra move")

func test_remove_component_breaks_combo_and_pushes_later_units_right():
	var m := _model()
	var k = _find(&"low_kick")
	m.place(k, 0); m.place(k, 2); m.place(k, 4)
	m.fuse(m.fuse_opportunities()[0]["indices"])   # combo at 0..3
	var thr = _find(&"throw")                       # dur 2, distinguishable
	m.place(thr, 3)                                 # in the freed space, 3..5
	# break the combo (remove one component): 2 legs no longer fuse -> 0..4,
	# which collides with the throw at 3 -> throw pushed right to 4
	var combo_idx := 0
	for i in m.units.size():
		if m.units[i]["fused"]:
			combo_idx = i
	m.remove_component(combo_idx, 0)
	var thr_start := -1
	for u in m.units:
		if u["moves"][0].id == &"throw":
			thr_start = u["start"]
	assert_eq(thr_start, 4, "later unit pushed right to avoid overlap")

func test_move_unit_relocates_single():
	var m := _model()
	var k = _find(&"low_kick")
	assert_true(m.place(k, 0))
	assert_true(m.move_unit(0, 5), "a single can be dragged to a new tick")
	assert_eq(m.units[0]["start"], 5)

func test_move_unit_relocates_combo():
	var m := _model()
	var k = _find(&"low_kick")
	m.place(k, 0); m.place(k, 2); m.place(k, 4)
	m.fuse(m.fuse_opportunities()[0]["indices"])
	assert_eq(m.units.size(), 1)
	assert_true(m.move_unit(0, 6), "a fused combo can be dragged too")
	assert_eq(m.units[0]["start"], 6)

func test_overflow_flagged_and_excluded_from_commit():
	var m := _model()
	var k = _find(&"low_kick")   # dur 2
	assert_true(m.place(k, 0))
	assert_true(m.place(k, 11), "soft limit: start 11 (end 13) allowed")
	var entries := m.entries()
	var overflow_count := 0
	for e in entries:
		if e["overflow"]:
			overflow_count += 1
	assert_eq(overflow_count, 1, "the start-11 move overflows the 12-grid")
	assert_eq(m.to_plan().moves.size(), 1, "overflow move excluded from committed plan")
	assert_eq(m.effective_cost(), k.stamina_cost, "overflow move not counted toward 气")

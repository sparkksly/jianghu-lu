extends GutTest

func _load() -> Control:
	var w = load("res://src/scenes/plan_phase.tscn").instantiate()
	add_child_autofree(w)
	return w

func _kick(deck) -> Move:
	for m in deck:
		if m.id == &"snap_kick": return m
	return null

func _setup(w) -> void:
	w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 12, ["？"])

func test_timeline_node_is_the_drop_target():
	var w = _load()
	await get_tree().process_frame
	_setup(w)
	var tl = w.get_node("Timeline")
	var k = _kick(Deck.starter())
	var data = {"kind": "new", "move": k}
	assert_true(tl._can_drop_data(Vector2(120, 10), data), "Timeline must accept drops")
	tl._drop_data(Vector2(3 * 40 + 5, 10), data)  # x=125 → tick 3
	assert_eq(w._model.units.size(), 1, "drop placed a move")
	assert_eq(w._model.units[0]["start"], 3, "placed at the dropped tick")

func test_nodes_wired():
	var w = _load()
	await get_tree().process_frame
	for n in ["DeckRow", "Timeline", "StaminaLabel", "ComboPreview", "EnemyIntent", "CommitButton"]:
		assert_not_null(w.get_node(n), "missing node " + n)

func test_setup_builds_hand_and_intent_is_chinese():
	var w = _load()
	await get_tree().process_frame
	w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 12, ["扫腿", "？"])
	assert_eq(w.get_node("DeckRow").get_child_count(), Deck.starter().size())
	assert_string_contains(w.get_node("EnemyIntent").text, "扫腿")

func test_no_auto_fuse_offers_a_hint_then_explicit_fuse_on_commit():
	var w = _load()
	await get_tree().process_frame
	_setup(w)
	var k = _kick(Deck.starter())
	var dur = k.total_duration()
	assert_true(w.try_drop_new(k, 0.0))
	assert_true(w.try_drop_new(k, dur * 40.0))
	assert_true(w.try_drop_new(k, 2 * dur * 40.0))
	assert_eq(w._model.units.size(), 3, "no auto-fuse — still three singles")
	var ops = w._model.fuse_opportunities()
	assert_eq(ops.size(), 1, "a fuse hint is offered")
	w._do_fuse(ops[0]["indices"])   # the player clicks the hint
	assert_eq(w._model.units.size(), 1, "now one fused combo")
	var captured := {"plan": null}
	w.plan_committed.connect(func(p): captured["plan"] = p)
	w._on_commit()
	assert_eq(captured["plan"].moves.size(), 1)
	assert_eq(captured["plan"].moves[0].move.id, &"chain_kick")

func test_fuse_frees_space_for_an_extra_move():
	var w = _load()
	await get_tree().process_frame
	_setup(w)
	var k = _kick(Deck.starter())
	var dur = k.total_duration()
	w.try_drop_new(k, 0.0); w.try_drop_new(k, dur * 40.0); w.try_drop_new(k, 2 * dur * 40.0)
	w._do_fuse(w._model.fuse_opportunities()[0]["indices"])   # compress -> frees ticks 3..6
	assert_true(w.try_drop_new(k, 3 * 40.0), "freed space is reusable")
	var captured := {"plan": null}
	w.plan_committed.connect(func(p): captured["plan"] = p)
	w._on_commit()
	assert_eq(captured["plan"].moves.size(), 2, "combat runs the combo AND the extra move")

func test_overlap_drop_rejected():
	var w = _load()
	await get_tree().process_frame
	_setup(w)
	var k = _kick(Deck.starter())
	assert_true(w.try_drop_new(k, 0.0))
	assert_false(w.try_drop_new(k, 40.0), "overlaps the first kick")
	assert_eq(w._model.units.size(), 1)

func test_soft_overflow_allowed_then_excluded_on_commit():
	var w = _load()
	await get_tree().process_frame
	_setup(w)
	var k = _kick(Deck.starter())   # dur 2
	assert_true(w.try_drop_new(k, 11 * 40.0), "soft limit allows overflow placement (start 11 -> end 13)")
	assert_true(w.try_drop_new(k, 0.0), "and a valid one at tick 0")
	var captured := {"plan": null}
	w.plan_committed.connect(func(p): captured["plan"] = p)
	w._on_commit()
	assert_eq(captured["plan"].moves.size(), 1, "overflow (red) move excluded from committed plan")
	assert_eq(captured["plan"].moves[0].start, 0)
	assert_eq(w._model.effective_cost(), k.stamina_cost, "overflow not counted toward 气")

func test_remove_one_combo_component_breaks_combo():
	var w = _load()
	await get_tree().process_frame
	_setup(w)
	var k = _kick(Deck.starter())
	var dur = k.total_duration()
	w.try_drop_new(k, 0.0); w.try_drop_new(k, dur * 40.0); w.try_drop_new(k, 2 * dur * 40.0)
	w._do_fuse(w._model.fuse_opportunities()[0]["indices"])
	assert_true(w._model.units[0]["fused"])
	w._on_remove_component(0, 1)   # remove the middle component
	assert_eq(w._model.units.size(), 2, "two legs no longer fuse (no 2-leg recipe)")
	assert_false(w._model.units[0]["fused"])

func test_remove_whole_combo():
	var w = _load()
	await get_tree().process_frame
	_setup(w)
	var k = _kick(Deck.starter())
	var dur = k.total_duration()
	w.try_drop_new(k, 0.0); w.try_drop_new(k, dur * 40.0); w.try_drop_new(k, 2 * dur * 40.0)
	w._do_fuse(w._model.fuse_opportunities()[0]["indices"])
	assert_eq(w._model.units.size(), 1)
	w.remove_at(0)
	assert_eq(w._model.units.size(), 0, "removing the combo clears it")

func test_remove_frees_slot():
	var w = _load()
	await get_tree().process_frame
	_setup(w)
	var k = _kick(Deck.starter())
	assert_true(w.try_drop_new(k, 0.0))
	w.remove_at(0)
	assert_eq(w._model.units.size(), 0)

func test_move_existing_repositions():
	var w = _load()
	await get_tree().process_frame
	_setup(w)
	var k = _kick(Deck.starter())
	assert_true(w.try_drop_new(k, 0.0))      # placed at tick 0
	assert_true(w.try_move_existing(0, 6 * 40.0))
	assert_eq(w._model.units.size(), 1, "still exactly one move")
	assert_true(w._model.units[0]["start"] >= 6, "move relocated later on the timeline")

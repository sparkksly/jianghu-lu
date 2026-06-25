extends GutTest

func _load() -> Control:
	var w = load("res://src/scenes/plan_phase.tscn").instantiate()
	add_child_autofree(w)
	return w

func _kick(deck) -> Move:
	for m in deck:
		if m.id == &"low_kick": return m
	return null

func test_timeline_node_is_the_drop_target():
	# Reproduces the 🚫 bug: Godot calls _can_drop_data/_drop_data on the node
	# under the cursor (the Timeline), not the PlanPhase root. The Timeline must
	# accept the drop itself and place at the dropped tick (at_position is
	# Timeline-local, so x / TICK_W = tick).
	var w = _load()
	await get_tree().process_frame
	w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 12, ["？"])
	var tl = w.get_node("Timeline")
	var k = _kick(Deck.starter())
	var data = {"kind": "new", "move": k}
	assert_true(tl._can_drop_data(Vector2(120, 10), data), "Timeline must accept drops")
	tl._drop_data(Vector2(3 * 40 + 5, 10), data)  # x=125 → tick 3
	assert_eq(w._plan.moves.size(), 1, "drop placed a move")
	assert_eq(w._plan.sorted()[0].start, 3, "placed at the dropped tick")

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
	assert_false(w.get_node("EnemyIntent").text.contains("jab"))

func test_drop_places_and_combo_fuses_on_commit():
	var w = _load()
	await get_tree().process_frame
	w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 12, ["？"])
	var k = _kick(Deck.starter())
	var dur = k.total_duration()
	# drop three kicks back-to-back via the testable entry point (local_x in pixels)
	assert_true(w.try_drop_new(k, 0.0))
	assert_true(w.try_drop_new(k, dur * 40.0))
	assert_true(w.try_drop_new(k, 2 * dur * 40.0))
	assert_eq(w._plan.moves.size(), 3)
	var captured := {"plan": null}
	w.plan_committed.connect(func(p): captured["plan"] = p)
	w._on_commit()
	assert_eq(captured["plan"].moves.size(), 1)
	assert_eq(captured["plan"].moves[0].move.id, &"chain_kick")

func test_overlap_drop_rejected():
	var w = _load()
	await get_tree().process_frame
	w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 12, ["？"])
	var k = _kick(Deck.starter())
	assert_true(w.try_drop_new(k, 0.0))
	assert_false(w.try_drop_new(k, 40.0), "overlaps the first kick")
	assert_eq(w._plan.moves.size(), 1)

func test_remove_frees_slot():
	var w = _load()
	await get_tree().process_frame
	w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 12, ["？"])
	var k = _kick(Deck.starter())
	assert_true(w.try_drop_new(k, 0.0))
	w.remove_at(0)
	assert_eq(w._plan.moves.size(), 0)

func test_move_existing_repositions():
	var w = _load()
	await get_tree().process_frame
	w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 12, ["？"])
	var k = _kick(Deck.starter())
	assert_true(w.try_drop_new(k, 0.0))      # placed at tick 0
	# move it later on the timeline (sorted index 0 → a free tick well past its duration)
	var far_x = 6 * 40.0
	assert_true(w.try_move_existing(0, far_x))
	assert_eq(w._plan.moves.size(), 1, "still exactly one move")
	assert_true(w._plan.sorted()[0].start >= 6, "move relocated later on the timeline")

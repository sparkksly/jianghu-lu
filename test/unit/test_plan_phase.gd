extends GutTest

func test_child_nodes_exist():
	var w = load("res://src/scenes/plan_phase.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_not_null(w.get_node("DeckRow"), "DeckRow exists")
	assert_not_null(w.get_node("Timeline"), "Timeline exists")
	assert_not_null(w.get_node("StaminaLabel"), "StaminaLabel exists")
	assert_not_null(w.get_node("ComboPreview"), "ComboPreview exists")
	assert_not_null(w.get_node("EnemyIntent"), "EnemyIntent exists")
	assert_not_null(w.get_node("CommitButton"), "CommitButton exists")

func test_setup_populates_deck_and_timeline():
	var w = load("res://src/scenes/plan_phase.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame

	var deck := Deck.starter()
	var rules := ComboLibrary.build()
	var intent: Array[StringName] = [&"jab_kick", &"?"]
	w.setup(deck, rules, 10, 10, intent)

	var deck_row = w.get_node("DeckRow")
	var timeline = w.get_node("Timeline")
	assert_eq(deck_row.get_child_count(), deck.size(), "DeckRow has one button per deck move")
	assert_eq(timeline.get_child_count(), 10, "Timeline has 10 slot buttons")

func test_placement_and_commit_fuses_chain_kick():
	var w = load("res://src/scenes/plan_phase.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame

	var deck := Deck.starter()
	var rules := ComboLibrary.build()
	var intent: Array[StringName] = [&"jab_kick", &"?"]
	w.setup(deck, rules, 10, 10, intent)

	# Find low_kick from the deck
	var low_kick: Move = null
	for m in deck:
		if m.id == &"low_kick":
			low_kick = m
			break
	assert_not_null(low_kick, "low_kick found in deck")

	# low_kick total_duration = startup(1) + active(1) + recovery(1) = 3
	var dur := low_kick.total_duration()
	assert_eq(dur, 3, "low_kick duration is 3")

	# Place three back-to-back low_kicks at ticks 0, 3, 6
	w._selected = low_kick
	w._on_slot(0)
	w._selected = low_kick
	w._on_slot(dur)
	w._selected = low_kick
	w._on_slot(2 * dur)

	# Verify three moves placed
	assert_eq(w._plan.moves.size(), 3, "three low_kicks placed")

	# Capture plan_committed signal via array container (GDScript lambdas capture arrays by ref)
	var captured: Array = []
	w.plan_committed.connect(func(p): captured.append(p))
	watch_signals(w)

	w._on_commit()

	assert_signal_emitted(w, "plan_committed", "plan_committed was emitted")
	assert_eq(captured.size(), 1, "plan was received")
	var emitted_plan: Plan = captured[0] as Plan
	assert_not_null(emitted_plan, "emitted plan is not null")
	assert_eq(emitted_plan.moves.size(), 1, "three kicks fused into one move")
	assert_eq(emitted_plan.moves[0].move.id, &"chain_kick", "fused move is chain_kick")

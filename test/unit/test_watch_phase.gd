extends GutTest

func test_child_nodes_wired():
	var w = load("res://src/scenes/watch_phase.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_not_null(w.get_node("P0Health"), "P0Health exists")
	assert_not_null(w.get_node("P1Health"), "P1Health exists")
	assert_not_null(w.get_node("P0Stamina"), "P0Stamina exists")
	assert_not_null(w.get_node("P1Stamina"), "P1Stamina exists")
	assert_not_null(w.get_node("TickLabel"), "TickLabel exists")
	assert_not_null(w.get_node("EventLog"), "EventLog exists")

func test_play_applies_hit_event():
	var w = load("res://src/scenes/watch_phase.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame

	var state := CombatState.new()
	state.hp = [30, 30]; state.max_hp = [30, 30]
	state.stamina = [10, 10]; state.sta_max = [10, 10]

	var ev := CombatEvent.new(0, &"hit", 0, 1, 6, &"x")
	w.play(state, [null, null], [ev])

	# Drive enough accumulated time to process tick 0 and tick 1 (two STEP intervals)
	w._process(w.STEP)  # accum reaches STEP -> processes tick 0, advances to t=1
	w._process(w.STEP)  # processes tick 1 (no events), advances to t=2 -> t > max_t+1 -> finished

	assert_eq(w.get_node("P1Health").value, 24.0, "enemy HP dropped by 6 after hit event")

func test_finished_signal_fires():
	var w = load("res://src/scenes/watch_phase.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame

	var state := CombatState.new()
	state.hp = [30, 30]; state.max_hp = [30, 30]
	state.stamina = [10, 10]; state.sta_max = [10, 10]

	# No events -> max_t stays 0, so _t > _max_t+1 fires after two ticks
	w.play(state, [null, null], [])
	watch_signals(w)

	# Drive two ticks manually with large delta (1.0 >> STEP=0.35).
	# After play: _t=0, _max_t=0, _accum=0.0
	# _process(1.0): accum=1.0 >= 0.35 -> tick 0, _t=1, 1>1 false
	# _process(1.0): accum=1.0 >= 0.35 -> tick 1, _t=2, 2>1 -> finished
	w._process(1.0)
	w._process(1.0)
	assert_signal_emitted(w, "finished", "finished signal emitted")
	assert_false(w.is_processing(), "process disabled after finish")

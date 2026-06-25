extends GutTest

func _load() -> Control:
	var w = load("res://src/scenes/watch_phase.tscn").instantiate()
	add_child_autofree(w)
	return w

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [30, 30]; s.max_hp = [30, 30]; s.stamina = [10, 10]; s.sta_max = [10, 10]; s.n_ticks = 14
	return s

func test_nodes_wired():
	var w = _load(); await get_tree().process_frame
	for n in ["P0Health", "P1Health", "P0Stamina", "P1Stamina", "TickLabel", "EventLog",
			  "P0HealthRed", "P1HealthRed", "P0HPLabel", "P1HPLabel", "P0StaLabel", "P1StaLabel", "FloatingLayer"]:
		assert_not_null(w.get_node(n), "missing " + n)

func test_hit_reduces_green_and_shows_chinese_number():
	var w = _load(); await get_tree().process_frame
	w.play(_state(), [null, null], [CombatEvent.new(0, &"hit", 0, 1, 6, &"low_kick")])
	w._process(1.0)
	assert_eq(w.get_node("P1Health").value, 24.0)
	assert_string_contains(w.get_node("P1HPLabel").text, "24")
	# a Chinese floating label was spawned
	assert_true(w.get_node("FloatingLayer").get_child_count() >= 1)

func test_tick_label_chinese():
	var w = _load(); await get_tree().process_frame
	w.play(_state(), [null, null], [CombatEvent.new(0, &"hit", 0, 1, 6, &"low_kick")])
	w._process(1.0)
	assert_string_contains(w.get_node("TickLabel").text, "第")
	assert_false(w.get_node("TickLabel").text.contains("tick"))

func test_log_is_chinese():
	var w = _load(); await get_tree().process_frame
	w.play(_state(), [null, null], [CombatEvent.new(0, &"interrupt", 0, 1, 5, &"jab_kick")])
	w._process(1.0)
	var log = w.get_node("EventLog")
	assert_true(log.get_child_count() >= 1)
	assert_string_contains(log.get_child(0).text, "打断")

func test_finished_emits():
	var w = _load(); await get_tree().process_frame
	watch_signals(w)
	w.play(_state(), [null, null], [CombatEvent.new(0, &"hit", 0, 1, 6, &"low_kick")])
	for i in 6: w._process(1.0)
	assert_signal_emitted(w, "finished")

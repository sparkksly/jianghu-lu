extends GutTest

func _load() -> Control:
	var w = load("res://src/scenes/watch_phase.tscn").instantiate()
	add_child_autofree(w)
	return w

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [30, 30]; s.max_hp = [30, 30]; s.stamina = [10, 10]; s.sta_max = [10, 10]; s.n_ticks = 12
	return s

func test_nodes_wired():
	var w = _load(); await get_tree().process_frame
	for n in ["P0Health", "P1Health", "P0Stamina", "P1Stamina", "TickLabel", "CombatTimeline",
			  "P0HealthRed", "P1HealthRed", "P0HPLabel", "P1HPLabel", "P0StaLabel", "P1StaLabel",
			  "FloatingLayer", "LogButton", "LogPanel/Scroll/EventLog"]:
		assert_not_null(w.get_node(n), "missing " + n)

func test_hit_reduces_green_and_shows_number_at_character():
	var w = _load(); await get_tree().process_frame
	w.play(_state(), [null, null], [CombatEvent.new(0, &"hit", 0, 1, 6, &"low_kick")])
	w._process(1.0)
	assert_eq(w.get_node("P1Health").value, 24.0)
	assert_string_contains(w.get_node("P1HPLabel").text, "24")
	# a floating damage number was spawned (over the character, in the FloatingLayer)
	assert_true(w.get_node("FloatingLayer").get_child_count() >= 1)

func test_tick_label_chinese():
	var w = _load(); await get_tree().process_frame
	w.play(_state(), [null, null], [CombatEvent.new(0, &"hit", 0, 1, 6, &"low_kick")])
	w._process(1.0)
	assert_string_contains(w.get_node("TickLabel").text, "第")

func test_log_is_chinese_and_tucked_away():
	var w = _load(); await get_tree().process_frame
	# log panel hidden until the player opens it
	assert_false(w.get_node("LogPanel").visible, "战报 starts collapsed")
	w.play(_state(), [null, null], [CombatEvent.new(0, &"interrupt", 0, 1, 5, &"jab_kick")])
	w._process(1.0)
	var log = w.get_node("LogPanel/Scroll/EventLog")
	assert_true(log.get_child_count() >= 1)
	assert_string_contains(log.get_child(0).text, "打断")

func test_log_button_toggles_panel():
	var w = _load(); await get_tree().process_frame
	assert_false(w.get_node("LogPanel").visible)
	w._toggle_log()
	assert_true(w.get_node("LogPanel").visible, "clicking 战报 opens the log")

func test_finished_emits():
	var w = _load(); await get_tree().process_frame
	watch_signals(w)
	w.play(_state(), [null, null], [CombatEvent.new(0, &"hit", 0, 1, 6, &"low_kick")])
	for i in 6: w._process(1.0)
	assert_signal_emitted(w, "finished")

func test_block_adds_marker_and_no_number():
	var w = _load(); await get_tree().process_frame
	w.play(_state(), [null, null], [CombatEvent.new(0, &"block", 0, 1, 0, &"guard")])
	w._process(1.0)
	var tl = w.get_node("CombatTimeline")
	var has_marker := false
	for c in tl.get_children():
		if c is Label and c.text.replace("\n", "") == "格挡":
			has_marker = true
	assert_true(has_marker, "block drops a 格挡 marker on the timeline")
	assert_eq(w.get_node("FloatingLayer").get_child_count(), 0, "block shows no damage number")

func test_combo_hit_spawns_big_number_and_move_name_marker():
	var w = _load(); await get_tree().process_frame
	w.play(_state(), [null, null], [CombatEvent.new(0, &"hit", 0, 1, 14, &"chain_kick")])
	w._process(1.0)
	assert_true(w.get_node("FloatingLayer").get_child_count() >= 1, "大招命中浮大数字")
	var tl = w.get_node("CombatTimeline")
	var marker_text := ""
	for c in tl.get_children():
		if c is Label and c.text.replace("\n", "") == "连环踢":
			marker_text = "连环踢"
	assert_eq(marker_text, "连环踢", "timeline marker shows the move name (vertical), not a category")

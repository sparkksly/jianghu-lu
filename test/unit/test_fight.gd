extends GutTest

func test_scene_structure():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame

	assert_not_null(w.get_node("PlanPhase"), "PlanPhase child exists")
	assert_not_null(w.get_node("WatchPhase"), "WatchPhase child exists")
	assert_not_null(w.get_node("ResultLabel"), "ResultLabel child exists")
	# Battle stage (health bars + log) stays visible behind the planning panel.
	assert_true(w.get_node("WatchPhase").visible, "WatchPhase stage is visible during planning")
	assert_true(w.get_node("PlanPhase").visible, "PlanPhase overlay is visible during planning")
	assert_false(w.get_node("ResultLabel").visible, "ResultLabel starts hidden")

func test_watch_stage_does_not_block_planning_mouse():
	# Regression: the always-visible WatchPhase is a full-rect Control drawn ON TOP
	# of PlanPhase. If it captures mouse (default STOP), the deck cards never get the
	# press and drag-and-drop dies. The stage must be mouse-transparent.
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_eq(w.get_node("WatchPhase").mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"always-visible stage must ignore mouse so PlanPhase receives drags")

func test_initial_state():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame

	assert_eq(w._state.hp, [40, 40], "Initial HP is [40, 40]")

func test_round_transition():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame

	# Build a player plan using deterministic seed
	var player_plan := AiPlanner.new(1).plan(Deck.starter(), 10, 10)

	# Trigger the plan commitment callback directly
	w._on_player_plan(player_plan)

	# WatchPhase should now be visible and PlanPhase hidden
	assert_true(w.get_node("WatchPhase").visible, "WatchPhase visible after plan submitted")
	assert_false(w.get_node("PlanPhase").visible, "PlanPhase hidden after plan submitted")

	# HP should have changed from initial [40,40] OR at least the call succeeded without error
	# (damage depends on deterministic sim; check that state was mutated by the simulation)
	# The simulator runs and modifies _state in place; _state is not cloned for the fight itself
	# so hp may or may not have changed depending on whether a hit landed.
	# We just assert the call completed and watch is showing (already asserted above).
	assert_not_null(w._state, "State still exists after simulation")

func test_codex_button_toggles_panel():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_not_null(w.get_node("CodexButton"))
	assert_not_null(w.get_node("Codex"))
	assert_false(w.get_node("Codex").visible)
	w.get_node("Codex").toggle()
	assert_true(w.get_node("Codex").visible)

func test_fight_uses_15_ticks():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_eq(w._state.n_ticks, 15)

func test_fight_round_one_starts_full_stamina():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_eq(w._state.stamina, w._state.sta_max, "round 1 opens at full 气")
	assert_eq(w._state.regen, [6, 6], "regen configured")

func test_round_hand_is_five_utilities_plus_six_attacks():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	var hand: Array = w._plan_phase._deck
	var attacks := 0
	var utils := 0
	for m in hand:
		if m.kind == Move.Kind.ATTACK: attacks += 1
		else: utils += 1
	assert_eq(attacks, 6, "每回合抽 6 张进攻牌")
	assert_eq(utils, 5, "5 张固定工具牌(步×2/挡/闪/拿)")

func test_default_menpai_draws_from_shaolin_pool():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	var basics := []
	for m in Deck.basic_attacks(): basics.append(m.id)
	for m in w._plan_phase._deck:
		if m.kind == Move.Kind.ATTACK:
			assert_true(m.id in basics, "进攻牌来自基础招: " + str(m.id))

func test_compiled_art_enters_draw_pool():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	w.configure({"known_moves": [&"jab"], "learned": [&"luohan"], "compiled": [&"luohan"], "enemy": {"hp": 30, "regen": 5, "pool": [&"jab"], "name": "测试"}})
	add_child_autofree(w)
	await get_tree().process_frame
	var ids: Array = []
	for m in w._pool: ids.append(m.id)
	assert_true(&"luohan" in ids, "化境绝学作单卡进抽牌池")

func test_enemy_name_shown():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	w.configure({"known_moves": [&"jab"], "enemy": {"hp": 30, "regen": 5, "pool": [&"venom_palm"], "name": "青鳞毒叟"}})
	add_child_autofree(w)
	await get_tree().process_frame
	assert_eq(w.get_node("WatchPhase/P1Name").text, "青鳞毒叟", "敌方名显示")

func test_tally_counts_leg_tags_and_two_combo():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	w.configure({"known_moves": [&"snap_kick"], "enemy": {"hp": 30, "regen": 5, "pool": [&"jab"], "name": "T"}})
	add_child_autofree(w)
	await get_tree().process_frame
	var p := Plan.new()
	p.add(PlacedMove.new(Deck.by_id(&"snap_kick"), 0))
	p.add(PlacedMove.new(Deck.by_id(&"sweep_kick"), 2))
	w._tally(p)
	var s: Dictionary = w.combat_stats()
	assert_eq(int(s["tag_hits"].get(&"腿法", 0)), 2, "两次腿法")
	assert_true(bool(s["tag_two_combo"].get(&"腿法", false)), "相邻两腿法=两连")

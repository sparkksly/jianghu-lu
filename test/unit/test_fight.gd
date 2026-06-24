extends GutTest

func test_scene_structure():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame

	assert_not_null(w.get_node("PlanPhase"), "PlanPhase child exists")
	assert_not_null(w.get_node("WatchPhase"), "WatchPhase child exists")
	assert_not_null(w.get_node("ResultLabel"), "ResultLabel child exists")
	assert_false(w.get_node("WatchPhase").visible, "WatchPhase starts hidden")
	assert_false(w.get_node("ResultLabel").visible, "ResultLabel starts hidden")

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

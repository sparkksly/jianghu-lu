extends GutTest

func test_setup_select_builds_choices():
	var s = load("res://src/scenes/setup_select.tscn").instantiate()
	add_child_autofree(s)
	await get_tree().process_frame
	assert_eq(s.get_node("VBox/MenpaiRow").get_child_count(), 2)
	assert_eq(s.get_node("VBox/NeigongRow").get_child_count(), 3, "内功三选一")
	assert_eq(s.get_node("VBox/MovesGrid").get_child_count(), 4, "本派4门初级功夫可选")

func test_encounter_renders():
	var e = load("res://src/scenes/encounter.tscn").instantiate()
	add_child_autofree(e)
	await get_tree().process_frame
	e.setup(Encounters.all()[0])
	await get_tree().process_frame
	assert_string_contains(e.get_node("Panel/VBox/Title").text, "幽洞")
	assert_gt(e.get_node("Panel/VBox/Options").get_child_count(), 0)

func test_run_scene_starts():
	var r = load("res://src/scenes/run.tscn").instantiate()
	add_child_autofree(r)
	await wait_frames(3)
	assert_not_null(r._run)
	assert_false(r._run.is_complete())

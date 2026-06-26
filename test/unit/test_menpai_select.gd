extends GutTest

func test_select_scene_structure():
	var w = load("res://src/scenes/menpai_select.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_not_null(w.get_node("VBox/ShaolinButton"))
	assert_not_null(w.get_node("VBox/WudangButton"))

func test_buttons_are_wired():
	# 不实际触发 _pick(会切场景、干扰测试树),只验证按钮已接信号 + pending 静态可设。
	var w = load("res://src/scenes/menpai_select.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_gt(w.get_node("VBox/ShaolinButton").pressed.get_connections().size(), 0, "少林按钮已接")
	assert_gt(w.get_node("VBox/WudangButton").pressed.get_connections().size(), 0, "武当按钮已接")
	RunState.pending_menpai = &"wudang"
	assert_eq(RunState.pending_menpai, &"wudang", "pending 静态可传递")
	RunState.pending_menpai = &"shaolin"   # 还原,避免影响其他测试

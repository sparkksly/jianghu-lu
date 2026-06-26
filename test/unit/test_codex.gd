extends GutTest

func test_codex_lists_moves_and_recipes():
	var w = load("res://src/scenes/codex.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	w.build()
	var list = w.get_node("ScrollContainer/List")
	# at least 6 base moves + 3 combo results + 3 recipes
	assert_true(list.get_child_count() >= 12, "codex has move + recipe rows")
	var all_text := ""
	for c in list.get_children():
		all_text += c.text + "\n"
	assert_string_contains(all_text, "扫堂腿")       # a base move
	assert_string_contains(all_text, "连环踢")      # a combo result
	assert_string_contains(all_text, "乾坤大挪移")  # a recipe result
	assert_false(all_text.contains("low_kick"), "no English ids")

func test_codex_toggle_changes_visible():
	var w = load("res://src/scenes/codex.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_false(w.visible, "codex starts hidden")
	w.toggle()
	assert_true(w.visible, "codex visible after first toggle")
	w.toggle()
	assert_false(w.visible, "codex hidden after second toggle")

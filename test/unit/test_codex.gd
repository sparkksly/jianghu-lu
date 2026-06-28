extends GutTest

func test_codex_lists_moves_and_recipes():
	var w = load("res://src/scenes/codex.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	w.set_learned([&"chain_kick", &"qiankun"])   # 已悟功夫才进图鉴配方段
	w.build()
	var list = w.get_node("ScrollContainer/List")
	assert_true(list.get_child_count() >= 12, "codex has move + recipe rows")
	var all_text := ""
	for c in list.get_children():
		all_text += c.text + "\n"
	assert_string_contains(all_text, "扫堂腿")       # 基础招
	assert_string_contains(all_text, "连环踢")      # 已悟功夫配方
	assert_string_contains(all_text, "乾坤大挪移")  # 已悟功夫配方
	assert_string_contains(all_text, "▸")           # 功夫实战效果行(伤害/词缀)
	assert_false(all_text.contains("low_kick"), "no English ids")

func test_codex_base_section_has_no_combos():
	# 基础招式段不该混入功夫(连环踢/乾坤等);未领悟时配方段为空
	var w = load("res://src/scenes/codex.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	w.set_learned([])
	w.build()
	var all_text := ""
	for c in w.get_node("ScrollContainer/List").get_children():
		all_text += c.text + "\n"
	assert_false(all_text.contains("连环踢"), "未领悟时不显示连环踢")
	assert_string_contains(all_text, "尚未领悟")

func test_codex_toggle_changes_visible():
	var w = load("res://src/scenes/codex.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_false(w.visible, "codex starts hidden")
	w.toggle()
	assert_true(w.visible, "codex visible after first toggle")
	w.toggle()
	assert_false(w.visible, "codex hidden after second toggle")

extends GutTest

func _run_with_gear() -> RunState:
	var r := RunState.new(&"shaolin")
	r.obtain_equipment(&"jinggang_jian")  # 武器→自动穿(槽空)
	r.obtain_equipment(&"suozijia")        # 防具→自动穿
	r.obtain_equipment(&"hanyue")          # 武器→进行囊(武器槽已满)
	return r

func test_obtain_auto_equips_when_slot_empty():
	var r := RunState.new(&"shaolin")
	r.obtain_equipment(&"jinggang_jian")
	assert_eq(r.equipped(&"武器"), &"jinggang_jian", "槽空自动穿")
	assert_true(r.owned_equipment.has(&"jinggang_jian"))

func test_second_same_slot_goes_to_bag():
	var r := _run_with_gear()
	assert_eq(r.equipped(&"武器"), &"jinggang_jian", "第一件武器穿着")
	assert_true(r.owned_unequipped().has(&"hanyue"), "第二件武器进行囊")
	assert_false(r.owned_unequipped().has(&"jinggang_jian"), "穿着的不在行囊")

func test_panel_builds_slot_and_bag_rows():
	var p = load("res://src/scenes/equip_panel.tscn").instantiate()
	add_child_autofree(p)
	await get_tree().process_frame
	p.set_run(_run_with_gear())
	await get_tree().process_frame
	assert_eq(p.get_node("Panel/Margin/VBox/SlotsBox").get_child_count(), 3, "三个槽位行")
	assert_gt(p.get_node("Panel/Margin/VBox/BagBox").get_child_count(), 0, "行囊有未装备项")

func test_panel_equip_from_bag_swaps():
	var r := _run_with_gear()
	var p = load("res://src/scenes/equip_panel.tscn").instantiate()
	add_child_autofree(p)
	await get_tree().process_frame
	p.set_run(r)
	p._on_equip(&"hanyue")   # 从行囊装上软剑(换下精钢剑)
	assert_eq(r.equipped(&"武器"), &"hanyue", "换上软剑")
	assert_true(r.owned_unequipped().has(&"jinggang_jian"), "换下的精钢剑回行囊")

func test_panel_unequip_to_bag():
	var r := _run_with_gear()
	var p = load("res://src/scenes/equip_panel.tscn").instantiate()
	add_child_autofree(p)
	await get_tree().process_frame
	p.set_run(r)
	p._on_unequip(&"防具")
	assert_eq(r.equipped(&"防具"), &"", "卸下后槽空")
	assert_true(r.owned_unequipped().has(&"suozijia"), "卸下的回行囊")

func test_done_signal():
	var p = load("res://src/scenes/equip_panel.tscn").instantiate()
	add_child_autofree(p)
	await get_tree().process_frame
	watch_signals(p)
	p.get_node("Panel/Margin/VBox/DoneButton").pressed.emit()
	assert_signal_emitted(p, "done")

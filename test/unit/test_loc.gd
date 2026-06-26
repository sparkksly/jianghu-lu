extends GutTest

func test_kind_names():
	assert_eq(Loc.kind_name(Move.Kind.ATTACK), "攻")
	assert_eq(Loc.kind_name(Move.Kind.BLOCK), "格挡")
	assert_eq(Loc.kind_name(Move.Kind.DODGE), "闪避")
	assert_eq(Loc.kind_name(Move.Kind.THROW), "投")

func test_move_name_lookup():
	assert_eq(Loc.move_name(&"sweep_kick"), "扫堂腿")
	assert_eq(Loc.move_name(&"chain_kick"), "连环踢")
	assert_eq(Loc.move_name(&"unknown_xyz"), "unknown_xyz") # fallback

func test_is_combo_result():
	assert_true(Loc.is_combo_result(&"chain_kick"))
	assert_false(Loc.is_combo_result(&"sweep_kick"))

func test_floating_text_for_events():
	assert_eq(Loc.floating_text(CombatEvent.new(2, &"interrupt", 0, 1, 5, &"jab")), "打断! -5")
	assert_eq(Loc.floating_text(CombatEvent.new(2, &"throw_break", 0, 1, 9, &"grab")), "投破防! -9")
	assert_eq(Loc.floating_text(CombatEvent.new(2, &"exhaust", 1, 1, 3, &"")), "气力不继!")
	assert_eq(Loc.floating_text(CombatEvent.new(2, &"hit", 0, 1, 6, &"sweep_kick")), "命中 -6")
	assert_eq(Loc.floating_text(CombatEvent.new(2, &"stamina", 0, 0, -2, &"")), "") # no floating

func test_log_line_is_chinese():
	var line := Loc.log_line(CombatEvent.new(3, &"hit", 0, 1, 6, &"sweep_kick"))
	assert_string_contains(line, "第3拍")
	assert_string_contains(line, "扫堂腿")
	assert_false(line.contains("hit"))

func test_affixes():
	var m := Move.new(); m.can_interrupt = true; m.is_heavy = true
	var a := Loc.affixes(m)
	assert_string_contains(a, "打断")
	assert_string_contains(a, "重击")

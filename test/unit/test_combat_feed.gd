extends GutTest

func _ev(type, actor, target, amount, move_id := &"") -> CombatEvent:
	return CombatEvent.new(0, type, actor, target, amount, move_id)

# ---- floating numbers (shown at the character's position) ----

func test_normal_hit_floats_red_minus_on_target():
	var f := CombatFeed.float_number(_ev(&"hit", 0, 1, 6, &"sweep_kick"))
	assert_eq(f["side"], 1, "number floats over the one taking damage")
	assert_eq(f["text"], "-6")
	assert_eq(f["color"], CombatFeed.RED)
	assert_false(f["big"], "small hit is not a crit")

func test_combo_hit_is_big():
	var f := CombatFeed.float_number(_ev(&"hit", 0, 1, 14, &"chain_kick"))
	assert_true(f["big"], "大招 命中用更夸张字号")

func test_heavy_hit_is_big_by_amount():
	var f := CombatFeed.float_number(_ev(&"hit", 0, 1, 12, &"side_kick"))
	assert_true(f["big"], "12+ 伤害算重击, 用大字号")

func test_interrupt_and_throwbreak_are_big_red():
	assert_true(CombatFeed.float_number(_ev(&"interrupt", 0, 1, 5, &"jab"))["big"])
	assert_true(CombatFeed.float_number(_ev(&"throw_break", 0, 1, 9, &"grab"))["big"])

func test_heal_floats_green_plus():
	var f := CombatFeed.float_number(_ev(&"heal", 0, 0, 8))
	assert_eq(f["text"], "+8")
	assert_eq(f["color"], CombatFeed.GREEN)

func test_block_and_stamina_have_no_number():
	assert_true(CombatFeed.float_number(_ev(&"block", 0, 1, 0)).is_empty())
	assert_true(CombatFeed.float_number(_ev(&"stamina", 0, 0, -2)).is_empty())

# ---- timeline markers (per-tick, in a player's lane) ----

func test_combo_marks_move_name_big_in_attacker_lane():
	var m := CombatFeed.marker(_ev(&"hit", 0, 1, 14, &"chain_kick"))
	assert_eq(m["lane"], 0, "attacker's lane")
	assert_eq(m["text"], "连环踢", "shows the move name, not a category")
	assert_eq(m["tone"], "big")

func test_interrupt_marks_move_name_in_attacker_lane():
	var m := CombatFeed.marker(_ev(&"interrupt", 0, 1, 5, &"jab"))
	assert_eq(m["lane"], 0)
	assert_eq(m["text"], "直拳")

func test_block_marks_defender_lane_good():
	var m := CombatFeed.marker(_ev(&"block", 0, 1, 0, &"guard"))
	assert_eq(m["lane"], 1, "the blocker is the target/defender")
	assert_eq(m["text"], "格挡")
	assert_eq(m["tone"], "good")

func test_whiff_marks_dodger_lane():
	var m := CombatFeed.marker(_ev(&"whiff", 0, 1, 0, &"side_kick"))
	assert_eq(m["lane"], 1, "the dodger is 1-actor")
	assert_eq(m["text"], "闪避")

func test_normal_hit_marks_move_name():
	var m := CombatFeed.marker(_ev(&"hit", 0, 1, 5, &"sweep_kick"))
	assert_eq(m["text"], "扫堂腿", "every landed move names itself on the timeline")
	assert_eq(m["tone"], "hit")

func test_stamina_has_no_marker():
	assert_true(CombatFeed.marker(_ev(&"stamina", 0, 0, -2)).is_empty())

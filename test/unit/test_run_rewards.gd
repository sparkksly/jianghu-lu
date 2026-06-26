extends GutTest

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func test_roll_returns_three():
	var out := RunRewards.roll([&"luohan", &"qiankun", &"chain_kick"], _rng(1))
	assert_eq(out.size(), 3)

func test_combo_options_come_from_unlearned():
	var out := RunRewards.roll([&"luohan"], _rng(2))
	for r in out:
		if r["type"] == "combo":
			assert_eq(r["id"], &"luohan")

func test_deterministic_same_seed():
	var a := RunRewards.roll([&"luohan", &"qiankun"], _rng(5))
	var b := RunRewards.roll([&"luohan", &"qiankun"], _rng(5))
	assert_eq(str(a), str(b))

func test_empty_unlearned_all_attributes():
	var out := RunRewards.roll([], _rng(9))
	assert_eq(out.size(), 3)
	for r in out:
		assert_ne(r["type"], "combo", "没绝学可领悟时全是属性")

func test_label_text():
	assert_string_contains(RunRewards.label({"type": "combo", "id": &"luohan"}), "罗汉拳")
	assert_string_contains(RunRewards.label({"type": "qi"}), "气")
	assert_string_contains(RunRewards.label({"type": "hp"}), "气血")

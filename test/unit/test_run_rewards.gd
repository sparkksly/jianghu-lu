extends GutTest

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func test_basic_three_options():
	var out := RunRewards.roll_basic([&"jab", &"push_palm"], _rng(1))
	assert_eq(out.size(), 3)
	var types: Array = []
	for r in out: types.append(r["type"])
	assert_true("hp" in types and "meditate" in types and "hone" in types)

func test_hone_targets_a_known_move():
	var known := [&"jab", &"snap_kick"]
	var out := RunRewards.roll_basic(known, _rng(2))
	for r in out:
		if r["type"] == "hone":
			assert_true(r["id"] in known)

func test_evolution_first_time_no_compiled():
	var out := RunRewards.roll_evolution(&"luohan", 0, true)
	for r in out:
		assert_ne(r["choice"], "compiled", "首次进化不出单卡")

func test_evolution_second_time_art_offers_compiled():
	var out := RunRewards.roll_evolution(&"luohan", 1, true)
	var choices: Array = []
	for r in out: choices.append(r["choice"])
	assert_true("compiled" in choices, "绝学第2次进化可化境")

func test_non_art_never_compiles():
	var out := RunRewards.roll_evolution(&"jab", 1, false)
	for r in out:
		assert_ne(r["choice"], "compiled", "基础招不化境")

func test_labels():
	assert_string_contains(RunRewards.label({"type": "meditate"}), "打坐")
	assert_string_contains(RunRewards.label({"type": "hone", "id": &"jab"}), "磨练")
	assert_string_contains(RunRewards.label({"type": "evo", "id": &"jab", "choice": "spd"}), "迅捷")
	assert_string_contains(RunRewards.label({"type": "evo", "id": &"luohan", "choice": "compiled"}), "化境")

extends GutTest

func test_neigong_category():
	var ng := Passives.by_category(&"内功")
	assert_eq(ng.size(), 10, "10 门内功都是 category=内功 的被动")
	assert_true(&"yijinjing" in ng)

func test_stat_per_level():
	assert_eq(Passives.stat_per_level(&"yijinjing", "max_hp"), 3)
	assert_eq(Passives.stat_per_level(&"yijinjing", "max_qi"), 1)
	assert_eq(Passives.stat_per_level(&"taiqing", "max_hp"), 0)

func test_modifiers_for_scales_by_level():
	# 持有易筋经3级 → max_hp+9, max_qi+3(per-level × 等级)
	var mods := Passives.modifiers_for({&"yijinjing": 3})
	var hp := 0; var qi := 0
	for m in mods:
		if m["stat"] == "max_hp": hp += m["value"]
		if m["stat"] == "max_qi": qi += m["value"]
	assert_eq(hp, 9)
	assert_eq(qi, 3)

func test_def_lookup():
	assert_eq(Passives.def(&"liangyi").passive_name, "两仪心法")
	assert_eq(Passives.def(&"liangyi").category, &"内功")

func test_neigong_facade_unchanged():
	# Neigong API 不变(RunState/UI 不用改)
	assert_eq(Neigong.all().size(), 10)
	assert_eq(Neigong.display_name(&"ximui"), "洗髓经")
	assert_eq(Neigong.hp_per_level(&"ximui"), 4)
	assert_eq(Neigong.qi_per_level(&"taiqing"), 3)

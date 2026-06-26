extends GutTest

func test_starter_by_menpai():
	assert_eq(Neigong.starter(&"shaolin"), &"yijinjing")
	assert_eq(Neigong.starter(&"wudang"), &"liangyi")

func test_yijinjing_favors_hp():
	assert_eq(Neigong.hp_per_level(&"yijinjing"), 3)
	assert_eq(Neigong.qi_per_level(&"yijinjing"), 1)

func test_liangyi_favors_qi():
	assert_eq(Neigong.hp_per_level(&"liangyi"), 1)
	assert_eq(Neigong.qi_per_level(&"liangyi"), 2)

func test_display_name():
	assert_eq(Neigong.display_name(&"yijinjing"), "易筋经")
	assert_eq(Neigong.display_name(&"liangyi"), "两仪心法")

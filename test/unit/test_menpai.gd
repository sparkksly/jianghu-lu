extends GutTest

func test_starter_pool_is_four_arts():
	assert_eq(Menpai.starter_pool(&"shaolin").size(), 4, "少林4门初级功夫")
	assert_true(&"luohan" in Menpai.starter_pool(&"shaolin"))
	assert_eq(Menpai.starter_pool(&"wudang").size(), 4)
	assert_true(&"taiji_yunshou" in Menpai.starter_pool(&"wudang"))

func test_learnable_own_advanced_not_others():
	var sh := Menpai.learnable(&"shaolin")
	assert_true(&"prajna" in sh and &"wuying" in sh, "少林高级功夫可学")
	assert_false(&"da_yunshou" in sh, "学不了武当高级功夫")
	assert_true(&"qiankun" in sh, "通用乾坤可学")
	assert_false(&"prajna" in Menpai.learnable(&"wudang"))

func test_display_name():
	assert_eq(Menpai.display_name(&"shaolin"), "少林")
	assert_eq(Menpai.display_name(&"wudang"), "武当")

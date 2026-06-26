extends GutTest

# 门派 = 开局起手绝学 + 可领悟池;进攻抽牌池两派共享基础动作。

func test_pool_shared_base_attacks():
	var sh := Menpai.pool(&"shaolin")
	assert_eq(sh.size(), Menpai.pool(&"wudang").size(), "两派抽牌池相同")
	for m in sh:
		assert_eq(m.kind, Move.Kind.ATTACK)

func test_starter_learned():
	assert_eq(Menpai.starter_learned(&"shaolin"), [&"luohan"])
	assert_eq(Menpai.starter_learned(&"wudang"), [&"taiji_yunshou"])
	assert_eq(Menpai.starter_learned(&"???"), [&"luohan"], "未知默认少林")

func test_learnable_pool():
	var sh := Menpai.learnable(&"shaolin")
	assert_true(&"luohan" in sh and &"jingang_fumo" in sh, "含本门绝学")
	assert_true(&"chain_kick" in sh and &"qiankun" in sh, "含通用绝学")
	assert_false(&"taiji_yunshou" in sh, "少林学不了武当云手")
	var wu := Menpai.learnable(&"wudang")
	assert_true(&"taiji_yunshou" in wu)
	assert_false(&"luohan" in wu, "武当学不了少林罗汉拳")

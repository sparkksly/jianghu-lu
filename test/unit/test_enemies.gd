extends GutTest

func test_boss_per_chapter():
	assert_eq(Enemies.spawn(0, "boss")["name"], "青鳞毒叟")
	assert_eq(Enemies.spawn(1, "boss")["name"], "血河老魔")
	assert_eq(Enemies.spawn(2, "boss")["name"], "无影魔君")
	assert_true(Enemies.spawn(0, "boss")["is_boss"])

func test_boss_pool_has_special_moves():
	assert_true(&"venom_palm" in Enemies.spawn(0, "boss")["pool"])
	assert_true(&"phantom_needle" in Enemies.spawn(2, "boss")["pool"])

func test_grunt_weaker_than_boss():
	assert_lt(Enemies.spawn(0, "grunt")["hp"], Enemies.spawn(0, "boss")["hp"])

func test_hp_scales_by_chapter():
	assert_gt(Enemies.spawn(2, "grunt")["hp"], Enemies.spawn(0, "grunt")["hp"])

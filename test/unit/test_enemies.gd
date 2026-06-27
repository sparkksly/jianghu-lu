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

func test_roster_has_multiple_variants():
	# 每章 ≥3 小怪 + ≥2 精英,撑起一轮的多样性
	for ch in 3:
		assert_gte(Enemies.ROSTER[ch]["grunt"].size(), 3, "章%d 小怪≥3" % ch)
		assert_gte(Enemies.ROSTER[ch]["elite"].size(), 2, "章%d 精英≥2" % ch)

func test_variant_selects_different_grunts():
	var a: String = Enemies.spawn(0, "grunt", 0)["name"]
	var b: String = Enemies.spawn(0, "grunt", 1)["name"]
	assert_ne(a, b, "不同 variant 给不同小怪")

func test_all_enemy_moves_resolve():
	# 每条 pool 的招式 id 都能被 Deck.by_id 解析(防拼写错)
	for ch in 3:
		for kind in ["grunt", "elite", "boss"]:
			var variants := 4 if kind != "boss" else 1
			for v in variants:
				for mid in Enemies.spawn(ch, kind, v)["pool"]:
					assert_not_null(Deck.by_id(mid), "招式 %s 应存在" % mid)

extends GutTest

func test_intent_reveals_full_sequence():
	# 敌人整套意图可见(含撤步),无隐藏问号 → 玩家能预判
	var p := Plan.new()
	p.add(PlacedMove.new(Deck.by_id(&"step_back"), 0))
	p.add(PlacedMove.new(Deck.by_id(&"venom_palm"), 2))
	var ai := AiPlanner.new(1)
	var it := ai.intent(p, 999)
	assert_eq(it.size(), 2)
	assert_false("？" in it, "全显示无问号")
	assert_true("撤步" in it, "看得到撤步(原痛点)")

func test_defense_moves_exist():
	# 防御池来源:格挡(BLOCK)/闪身(DODGE)
	assert_eq(Deck.by_id(&"guard").kind, Move.Kind.BLOCK)
	assert_eq(Deck.by_id(&"dodge").kind, Move.Kind.DODGE)

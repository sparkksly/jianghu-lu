extends GutTest

func test_plan_is_valid_and_deterministic():
	var a := AiPlanner.new(42)
	var p1 := a.plan(Deck.starter(), 10, 10)
	assert_true(p1.is_valid(10, 10))
	var b := AiPlanner.new(42)
	var p2 := b.plan(Deck.starter(), 10, 10)
	assert_eq(p1.sorted().map(func(pm): return pm.move.id), p2.sorted().map(func(pm): return pm.move.id))

func test_intent_partial_reveal():
	var a := AiPlanner.new(7)
	var p := a.plan(Deck.starter(), 10, 10)
	var shown := a.intent(p, 1)
	assert_eq(shown.size(), p.sorted().size())
	assert_ne(shown[0]["name"], "？", "first move revealed as a Chinese name")
	assert_false(String(shown[0]["name"]).is_empty())
	assert_true(shown[0].has("start"), "意图绑拍号")
	if shown.size() > 1:
		assert_eq(shown[1]["name"], "？", "later moves hidden with fullwidth question mark")

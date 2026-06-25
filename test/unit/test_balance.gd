extends GutTest

func test_ai_vs_ai_fights_terminate_and_deal_damage():
	var wins := [0, 0]
	for seed in range(20):
		var s := CombatState.new()
		s.hp=[40,40]; s.max_hp=[40,40]; s.sta_max=[10,10]; s.stamina=[10,10]; s.regen=[6,6]; s.n_ticks=10
		var a := AiPlanner.new(seed)
		var b := AiPlanner.new(seed + 1000)
		var rules := ComboLibrary.build()
		var rounds := 0
		while s.hp[0] > 0 and s.hp[1] > 0 and rounds < 60:
			if rounds > 0:
				s.regen_round()
			var pa := rules.apply(a.plan(Deck.starter(), s.stamina[0], s.n_ticks))
			var pb := rules.apply(b.plan(Deck.starter(), s.stamina[1], s.n_ticks))
			CombatSim.simulate(s, [pa, pb])
			rounds += 1
		assert_true(rounds < 60, "fight %d terminated under regen economy" % seed)
		if s.hp[0] <= 0: wins[1] += 1
		elif s.hp[1] <= 0: wins[0] += 1
	gut.p("AI win split: %s" % str(wins))
	assert_true(wins[0] + wins[1] > 0, "at least some fights resolved")

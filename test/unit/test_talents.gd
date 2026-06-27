extends GutTest

func test_talent_category_and_defs():
	var ts := Passives.by_category(&"天赋")
	assert_eq(ts.size(), 2, "2 门触发被动")
	assert_true(&"xianfa" in ts and &"jianbi" in ts)

func test_combat_triggers_collects_effects():
	var r := RunState.new(&"shaolin")
	r.learn_talent(&"xianfa")
	var trigs := r.combat_triggers()
	assert_eq(trigs.size(), 1)
	assert_eq(trigs[0]["when"], "fight_start")
	assert_eq(trigs[0]["do"]["buff"], &"vigor")

func test_fight_start_trigger_adds_buff():
	# 先发制人:开战(第0拍)即触发,emit buff(vigor) 事件
	var s := _mk_state()
	s.triggers = [[{"when": "fight_start", "do": {"buff": &"vigor"}}], []]
	var events := CombatSim.simulate(s, [Plan.new(), Plan.new()])
	var fired := false
	for e in events:
		if e.type == &"buff" and e.move_id == &"vigor" and e.actor == 0 and e.tick == 0:
			fired = true
	assert_true(fired, "开战第0拍触发 vigor")

func test_block_trigger_grants_qi():
	var r := RunState.new(&"shaolin")
	r.learn_talent(&"jianbi")
	var trigs := r.combat_triggers()
	assert_eq(trigs[0]["when"], "block")
	assert_eq(trigs[0]["do"]["qi"], 3)

func test_encounter_grants_talent():
	var r := RunState.new(&"shaolin")
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	r.apply_encounter({"talent": true}, rng)
	assert_eq(r.talents.size(), 1)
	assert_true(r.talents[0] in Passives.by_category(&"天赋"))

func _mk_state() -> CombatState:
	var s := CombatState.new()
	s.hp = [40, 40]; s.max_hp = [40, 40]
	s.stamina = [10, 10]; s.sta_max = [10, 10]
	s.n_ticks = 4
	return s

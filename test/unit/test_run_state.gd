extends GutTest

func test_new_run_starts_at_first_fight():
	var r := RunState.new(3, 40)
	assert_eq(r.fights_total, 3)
	assert_eq(r.fight_index, 0)
	assert_eq(r.player_hp, 40)
	assert_eq(r.max_hp, 40)
	assert_false(r.is_complete())

func test_label_is_one_based():
	var r := RunState.new(3, 40)
	assert_eq(r.label(), "第1战 / 共3战")
	r.advance()
	assert_eq(r.label(), "第2战 / 共3战")

func test_advance_until_complete():
	var r := RunState.new(3, 40)
	r.advance(); assert_false(r.is_complete())
	r.advance(); assert_false(r.is_complete())
	r.advance(); assert_true(r.is_complete(), "after 3 advances the run is done")

func test_enemy_scaling_grows_each_fight():
	var r := RunState.new(3, 40)
	assert_eq(r.enemy_hp(), 30, "fight 1 enemy hp")
	assert_eq(r.enemy_regen(), 5, "fight 1 enemy regen")
	r.advance()
	assert_true(r.enemy_hp() > 30, "fight 2 enemy is tougher")
	assert_true(r.enemy_regen() >= 5)

func test_run_state_carries_menpai():
	var r := RunState.new(3, 40, &"wudang")
	assert_eq(r.menpai_id, &"wudang")

func test_run_state_defaults_shaolin():
	assert_eq(RunState.new().menpai_id, &"shaolin")

func test_starter_learned_on_init():
	assert_eq(RunState.new(3, 40, &"shaolin").learned, [&"luohan"])
	assert_eq(RunState.new(3, 40, &"wudang").learned, [&"taiji_yunshou"])

func test_starter_neigong():
	assert_eq(RunState.new(3, 40, &"shaolin").neigong_id, &"yijinjing")
	assert_eq(RunState.new(3, 40, &"wudang").neigong_id, &"liangyi")

func test_apply_reward_hp():
	var r := RunState.new(3, 40, &"shaolin")
	var hp0 := r.player_hp
	r.apply_reward({"type": "hp"})
	assert_eq(r.max_hp, 46)
	assert_eq(r.player_hp, hp0 + 6)

func test_meditate_levels_neigong_and_heals():
	var r := RunState.new(3, 40, &"shaolin")   # 易筋经 +3血+1气/级
	r.player_hp = 30
	r.apply_reward({"type": "meditate"})
	assert_eq(r.neigong_level, 1)
	assert_eq(r.qi_bonus(), 1, "易筋经每级+1气")
	assert_eq(r.max_hp, 43, "内功长血 +3")
	assert_eq(r.player_hp, mini(43, 30 + 12 + 3), "疗伤+内功长血")

func test_wudang_neigong_more_qi():
	var r := RunState.new(3, 40, &"wudang")   # 两仪 +1血+2气/级
	r.apply_reward({"type": "meditate"})
	assert_eq(r.qi_bonus(), 2)
	assert_eq(r.max_hp, 41)

func test_hone_adds_mastery_and_weight():
	var r := RunState.new(3, 40, &"shaolin")
	r.apply_reward({"type": "hone", "id": &"jab"})
	assert_eq(r.mastery.get(&"jab", 0), 2)
	assert_eq(r.weight.get(&"jab", 0), 1)

func test_gain_mastery_then_pending_evolution():
	var r := RunState.new(3, 40, &"shaolin")
	assert_eq(r.pending_evolutions().size(), 0)
	r.gain_mastery([&"jab", &"jab", &"jab"])   # 累计3 → 达进化阈值
	assert_true(&"jab" in r.pending_evolutions())

func test_apply_evolution_raises_level():
	var r := RunState.new(3, 40, &"shaolin")
	r.gain_mastery([&"jab", &"jab", &"jab"])
	r.apply_evolution(&"jab", "spd")
	assert_eq(r.evo_level(&"jab"), 1)
	assert_eq(int(r.evo[&"jab"]["spd"]), 1)
	assert_false(&"jab" in r.pending_evolutions(), "3<6,升级后暂不再待进化")

func test_compiled_arts():
	var r := RunState.new(3, 40, &"shaolin")
	r.evo[&"luohan"] = {"level": 2, "spd": 0, "qi": 0, "dmg": 0, "compiled": true}
	assert_true(&"luohan" in r.compiled_arts())

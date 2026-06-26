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

func test_apply_reward_combo_adds_to_learned():
	var r := RunState.new(3, 40, &"shaolin")
	r.apply_reward({"type": "combo", "id": &"jingang_fumo"})
	assert_true(r.learned.has(&"jingang_fumo"))
	r.apply_reward({"type": "combo", "id": &"jingang_fumo"})   # 重复不叠
	assert_eq(r.learned.count(&"jingang_fumo"), 1)

func test_apply_reward_qi_and_hp():
	var r := RunState.new(3, 40, &"shaolin")
	r.apply_reward({"type": "qi"})
	assert_eq(r.bonus_qi, 2)
	var hp0 := r.player_hp
	r.apply_reward({"type": "hp"})
	assert_eq(r.max_hp, 46)
	assert_eq(r.player_hp, hp0 + 6)

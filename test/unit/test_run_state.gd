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

extends GutTest

func test_starts_at_sanliu():
	var r := RunState.new(&"shaolin")
	assert_eq(r.level, 1)
	assert_eq(r.level_name(), "三流")
	assert_eq(r.hand_size(), 6)
	assert_eq(r.xp_to_next(), 30)

func test_gain_xp_levels_up_and_boosts_stats():
	var r := RunState.new(&"shaolin")
	var atk0 := r.combat_attack()
	var hp0 := r.max_hp
	var qi0 := r.base_max_qi
	var ups := r.gain_xp(30)   # 升到二流
	assert_eq(ups, 1)
	assert_eq(r.level, 2)
	assert_eq(r.level_name(), "二流")
	assert_eq(r.combat_attack(), atk0 + 1, "境界涨攻击")
	assert_eq(r.max_hp, hp0 + 6, "境界涨气血上限")
	assert_eq(r.base_max_qi, qi0 + 1, "境界涨气海")

func test_levelup_heals():
	var r := RunState.new(&"shaolin")
	r.player_hp = 20
	r.gain_xp(30)
	assert_eq(r.player_hp, 26, "升境界回血(+上限增量)")

func test_hand_size_grows_with_level():
	var r := RunState.new(&"shaolin")
	r.gain_xp(75)   # 升到一流(lv3,hand+1)
	assert_eq(r.level, 3)
	assert_eq(r.hand_size(), 7, "一流境界多抽一张")

func test_can_multi_level_and_caps():
	var r := RunState.new(&"shaolin")
	var ups := r.gain_xp(999)   # 一次性到顶
	assert_eq(r.level, RunState.MAX_LEVEL)
	assert_eq(r.level_name(), "先天")
	assert_eq(r.xp_to_next(), 0, "满级无下一阶")
	assert_eq(ups, 4, "三流→先天连升4级")

func test_xp_to_next_decreases():
	var r := RunState.new(&"shaolin")
	r.gain_xp(10)
	assert_eq(r.xp_to_next(), 20, "再20经验晋二流")

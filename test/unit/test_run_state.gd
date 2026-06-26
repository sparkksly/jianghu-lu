extends GutTest

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s; return r

# --- 开局构筑 ---
func test_init_from_choices():
	var r := RunState.new(&"wudang", &"liangyi", [&"taiji_yunshou", &"mianli"])
	assert_eq(r.menpai_id, &"wudang")
	assert_eq(r.neigong_id, &"liangyi")
	assert_eq(r.learned, [&"taiji_yunshou", &"mianli"], "起手=选的2门初级功夫")

func test_default_neigong_follows_menpai():
	assert_eq(RunState.new(&"shaolin").neigong_id, &"yijinjing")

# --- 节点 / 章节 ---
func test_node_sequence_and_chapters():
	var r := RunState.new(&"shaolin")
	assert_eq(r.current_node()["type"], "grunt")
	assert_string_contains(r.chapter_title(), "毒蛛潭")
	r.advance_node(); assert_eq(r.current_node()["type"], "encounter")
	r.advance_node(); assert_eq(r.current_node()["type"], "elite")
	r.advance_node(); assert_eq(r.current_node()["type"], "boss")
	r.advance_node()
	assert_string_contains(r.chapter_title(), "断魂崖", "第5节点进第二章")

func test_run_completes_after_twelve_nodes():
	var r := RunState.new(&"shaolin")
	for i in 12: r.advance_node()
	assert_true(r.is_complete())

func test_current_enemy_boss_is_named():
	var r := RunState.new(&"shaolin")
	for i in 3: r.advance_node()   # 到 boss
	var e := r.current_enemy()
	assert_eq(e["name"], "青鳞毒叟")
	assert_true(e["is_boss"])

# --- 基础提升 ---
func test_meditate_levels_neigong():
	var r := RunState.new(&"shaolin")   # 易筋经 +3血+1气
	r.player_hp = 30
	r.apply_reward({"type": "meditate"})
	assert_eq(r.neigong_level, 1)
	assert_eq(r.qi_bonus(), 1)
	assert_eq(r.max_hp, 43)

func test_hone_adds_mastery_and_weight():
	var r := RunState.new(&"shaolin")
	r.apply_reward({"type": "hone", "id": &"jab"})
	assert_eq(r.mastery.get(&"jab", 0), 2)
	assert_eq(r.weight.get(&"jab", 0), 1)

# --- 熟练 / 进化 ---
func test_pending_evolution_after_mastery():
	var r := RunState.new(&"shaolin")
	r.gain_mastery([&"jab", &"jab", &"jab"])
	assert_true(&"jab" in r.pending_evolutions())
	r.apply_evolution(&"jab", "spd")
	assert_eq(r.evo_level(&"jab"), 1)

func test_compiled_arts():
	var r := RunState.new(&"shaolin")
	r.evo[&"luohan"] = {"level": 2, "compiled": true}
	assert_true(&"luohan" in r.compiled_arts())

# --- 奇遇 ---
func test_encounter_fruit_boosts_hp_and_neigong():
	var r := RunState.new(&"shaolin")
	var hp0 := r.max_hp
	r.apply_encounter({"hp": 12, "neigong": 2}, _rng(1))
	assert_eq(r.max_hp, hp0 + 12 + 2 * 3, "+12血 +内功2级×易筋经3血")
	assert_eq(r.neigong_level, 2)

func test_encounter_learn_art():
	var r := RunState.new(&"shaolin")   # 开局 2 门初级功夫
	var n0 := r.learned.size()
	r.apply_encounter({"learn_art": true}, _rng(2))
	assert_gt(r.learned.size(), n0, "领悟了一门新功夫")

func test_encounter_weapon_and_master_move():
	var r := RunState.new(&"shaolin")
	r.apply_encounter({"weapon_dmg": 2}, _rng(3))
	assert_eq(r.weapon_bonus, 2)
	var n0 := r.learned.size()
	r.apply_encounter({"master_move": true}, _rng(3))
	assert_gt(r.learned.size(), n0, "领悟一门功夫")

func test_advanced_art_only_learnable_after_prereq():
	var r := RunState.new(&"shaolin")
	assert_false(&"prajna" in r.unlearned_arts(), "般若未达熟练,不可领悟")
	r.gain_mastery([&"jingang_fumo", &"jingang_fumo", &"jingang_fumo"])
	assert_true(&"prajna" in r.unlearned_arts(), "金刚伏魔熟练≥3后般若可领悟")

func test_encounter_heal_full():
	var r := RunState.new(&"shaolin")
	r.player_hp = 5
	r.apply_encounter({"heal_full": true}, _rng(4))
	assert_eq(r.player_hp, r.max_hp)

func test_discovery_art_not_in_normal_pool():
	var r := RunState.new(&"shaolin")
	assert_false(&"wuying" in r.unlearned_arts(), "无影脚靠实战顿悟,不在磨练/奇遇领悟池")

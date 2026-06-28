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

# --- 分支地图 / 章节 ---
func test_map_has_layers_and_chapter_bosses():
	var r := RunState.new(&"shaolin")
	assert_eq(r.layers.size(), 18, "3章 × 6层")
	assert_string_contains(r.chapter_title(), "毒蛛潭")
	# 每章最后一层是单候选 boss
	for boss_layer in [5, 11, 17]:
		assert_eq(r.layers[boss_layer].size(), 1, "boss 层单候选")
		assert_eq(r.layers[boss_layer][0]["type"], "boss")

func test_choice_layers_have_2to3_with_combat():
	var r := RunState.new(&"shaolin")
	for i in [0, 1, 2]:
		var layer: Array = r.layers[i]
		assert_between(layer.size(), 2, 3, "选择层 2-3 候选")
		var has_combat := false
		for c in layer:
			if c["type"] in ["grunt", "elite"]:
				has_combat = true
		assert_true(has_combat, "每选择层至少一个战斗")

func test_at_most_one_shop_per_chapter():
	# 每章(3 选择层)集市候选最多一个,不会一章刷三次商店
	var r := RunState.new(&"shaolin")
	for ch in RunState.CHAPTERS:
		var shops := 0
		for l in (RunState.LAYERS_PER_CHAPTER - 1):
			for c in r.layers[ch * RunState.LAYERS_PER_CHAPTER + l]:
				if c["type"] == "shop":
					shops += 1
		assert_lte(shops, 1, "第%d章集市候选 ≤1" % ch)

func test_select_sets_current_type():
	var r := RunState.new(&"shaolin")
	r.select(0)
	assert_eq(r.current_type(), r.layers[0][0]["type"], "选第0候选 → 当前类型")

func test_advance_resets_choice_and_completes():
	var r := RunState.new(&"shaolin")
	r.select(0)
	r.advance_node()
	assert_eq(r.choice_index, -1, "进层重置选择")
	for i in 17: r.advance_node()
	assert_true(r.is_complete(), "18 层走完通关")

func test_boss_layer_auto_and_named():
	var r := RunState.new(&"shaolin")
	for i in 5: r.advance_node()   # 第 5 层 = 第一章 boss
	assert_true(r.is_boss_layer())
	assert_eq(r.current_type(), "boss", "boss 层无需 select")
	var e := r.current_enemy()
	assert_eq(e["name"], "青鳞毒叟")
	assert_true(e["is_boss"])

func test_chapter_advances_by_layer():
	var r := RunState.new(&"shaolin")
	assert_string_contains(r.chapter_title(), "毒蛛潭")
	for i in 6: r.advance_node()   # 第 6 层 → 第二章
	assert_string_contains(r.chapter_title(), "断魂崖")

# --- 连线拓扑 ---
func test_edges_no_dead_ends_or_islands():
	var r := RunState.new(&"shaolin")
	for i in range(r.layers.size() - 1):
		var lower_incoming := {}
		for node in r.layers[i]:
			assert_gt(node["edges"].size(), 0, "层%d 每节点≥1出边(无死路)" % i)
			for e in node["edges"]:
				assert_between(e, 0, r.layers[i + 1].size() - 1, "出边指向合法 slot")
				lower_incoming[e] = true
		for v in r.layers[i + 1].size():
			assert_true(lower_incoming.has(v), "层%d slot%d 有入边(无孤岛)" % [i + 1, v])

func test_available_slots_follow_chosen_edges():
	var r := RunState.new(&"shaolin")
	assert_eq(r.available_slots().size(), r.layers[0].size(), "第0层全开")
	r.select(0)
	r.advance_node()   # 进第1层
	assert_eq(r.available_slots(), r.layers[0][0]["edges"], "本程受上层所选连线约束")

func test_map_choices_and_preview():
	var r := RunState.new(&"shaolin")
	var choices := r.map_choices()
	assert_gt(choices.size(), 0, "本程有候选")
	assert_true(choices[0].has("slot") and choices[0].has("type") and choices[0].has("edges"))
	var nxt := r.map_next_nodes()
	assert_gt(nxt.size(), 0, "下程有可达节点")
	assert_true(nxt[0].has("slot") and nxt[0].has("type"))

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

func test_discovery_and_exotic_pools():
	var r := RunState.new(&"shaolin")   # 开局会 罗汉拳 + 连环踢
	# 无影脚(连环踢升级·顿悟):奇遇能学(已会连环踢满足门槛),磨练自悟不出
	assert_true(&"wuying" in r.unlearned_arts(), "奇遇能学无影脚")
	assert_false(&"wuying" in r.self_learnable_arts(), "磨练不出无影脚(实战顿悟)")
	# 乾坤(稀缺绝世神功):奇遇能学,磨练不出
	assert_true(&"qiankun" in r.unlearned_arts(), "奇遇能学乾坤")
	assert_false(&"qiankun" in r.self_learnable_arts(), "磨练不出乾坤(稀缺)")

func test_wuying_needs_chain_kick_first():
	var r := RunState.new(&"shaolin", &"", [&"luohan", &"fuhu"])   # 不会连环踢
	assert_false(&"wuying" in r.unlearned_arts(), "没会连环踢→无影脚学不了")
	r.learn(&"chain_kick")
	assert_true(&"wuying" in r.unlearned_arts(), "会连环踢后无影脚可由奇遇学")

func test_combat_attributes_aggregate():
	var r := RunState.new(&"shaolin")
	assert_eq(r.combat_attack(), 10, "默认攻击力10(基准,招式默认伤害不变)")
	assert_eq(r.combat_max_qi(), 10, "默认气10")
	r.weapon_bonus = 2
	assert_eq(r.combat_attack(), 12, "神兵并入攻击力 10+2")

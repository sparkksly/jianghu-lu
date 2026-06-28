extends GutTest

func test_family_demand_raises_component_moves():
	# 学截拳[拳+掌] → 拳/掌基础招权重提高,没学的腿招不提
	var r := RunState.new(&"shaolin", &"", [&"jiequan"])
	var w := r.draw_weights()
	assert_gt(int(w.get(&"jab", 0)), 0, "学拳掌功夫→拳招更易抽")
	assert_gt(int(w.get(&"push_palm", 0)), 0, "→掌招更易抽")
	assert_eq(int(w.get(&"snap_kick", 0)), 0, "没学腿功→腿招不加权")

func test_demand_stacks_across_arts():
	# 截拳[拳,掌] + 罗汉拳[拳,拳,拳] → 拳法需求 4,掌法 1 → 拳招权重 > 掌招
	var r := RunState.new(&"shaolin", &"", [&"jiequan", &"luohan"])
	var w := r.draw_weights()
	assert_gt(int(w.get(&"jab", 0)), int(w.get(&"push_palm", 0)), "拳法需求更高→拳招权重更高")

func test_compiled_card_weight_and_investment_transfer():
	var r := RunState.new(&"shaolin", &"", [&"jiequan"])
	r.apply_evolution(&"jiequan", "compiled")   # 化境
	var w := r.draw_weights()
	assert_gte(int(w.get(&"jiequan", 0)), RunState.COMPILED_DRAW_BASE, "化境单卡有抽取权重")
	assert_eq(int(w.get(&"jab", 0)), 0, "投资转移:化境后不再抬基础招概率")

func test_mastery_raises_compiled_weight():
	var r := RunState.new(&"shaolin", &"", [&"jiequan"])
	r.apply_evolution(&"jiequan", "compiled")
	var w0 := int(r.draw_weights().get(&"jiequan", 0))
	r.mastery[&"jiequan"] = 8   # 高熟练
	var w1 := int(r.draw_weights().get(&"jiequan", 0))
	assert_gt(w1, w0, "熟练度涨→化境单卡更常抽到")

func test_compiled_card_shares_mastery_key():
	# 化境单卡 id == 功夫 id → 手拼/单卡命中累积同一 mastery,熟练度贯通继承
	var res = Arts.recipe(&"jiequan").get("result", null)
	assert_not_null(res, "功夫有 result(化境单卡来源)")
	assert_eq(res.id, &"jiequan", "化境单卡 id = 功夫 id,gain_mastery 记同一本账")

func test_mastery_carries_into_compiled_weight():
	# 手拼期攒的熟练度,化境后被单卡权重继承
	var r := RunState.new(&"shaolin", &"", [&"jiequan"])
	r.gain_mastery([&"jiequan", &"jiequan", &"jiequan", &"jiequan"])  # 手拼期攒 4 熟练
	r.apply_evolution(&"jiequan", "compiled")
	assert_gt(int(r.draw_weights().get(&"jiequan", 0)), RunState.COMPILED_DRAW_BASE, "化境单卡继承手拼期熟练度")

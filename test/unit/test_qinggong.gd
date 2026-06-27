extends GutTest

func test_qinggong_category():
	var qg := Passives.by_category(&"轻功")
	assert_eq(qg.size(), 3, "3 门轻功")
	assert_true(&"lingbo" in qg)
	assert_eq(Passives.display_name(&"lingbo"), "凌波微步")

func test_learn_qinggong_boosts_combat_stats():
	var r := RunState.new(&"shaolin")
	var qi0 := r.combat_max_qi()
	var arm0 := r.combat_armor()
	r.learn_qinggong(&"lingbo")   # max_qi+2, armor+10
	assert_eq(r.combat_max_qi(), qi0 + 2, "轻功进气海聚合")
	assert_eq(r.combat_armor(), arm0 + 10, "轻功进防御聚合")

func test_qinggong_stacks():
	var r := RunState.new(&"shaolin")
	var arm0 := r.combat_armor()
	r.learn_qinggong(&"lingbo")   # armor+10
	r.learn_qinggong(&"yanzi")    # armor+15
	assert_eq(r.combat_armor(), arm0 + 25, "轻功叠加")
	r.learn_qinggong(&"lingbo")   # 重复不叠
	assert_eq(r.qinggong.size(), 2)

func test_encounter_grants_qinggong():
	var r := RunState.new(&"shaolin")
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	r.apply_encounter({"qinggong": true}, rng)
	assert_eq(r.qinggong.size(), 1, "奇遇授一门轻功")
	assert_true(r.qinggong[0] in Passives.by_category(&"轻功"))

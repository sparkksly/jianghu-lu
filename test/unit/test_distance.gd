extends GutTest

func test_distance_defaults_to_mid_and_clones():
	var s := CombatState.new()
	assert_eq(s.distance, 1, "开局中距")
	s.distance = 0
	var c := s.clone()
	assert_eq(c.distance, 0)
	c.distance = 2
	assert_eq(s.distance, 0, "clone is independent")

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp=[40,40]; s.max_hp=[40,40]; s.stamina=[10,10]; s.sta_max=[10,10]; s.regen=[6,6]; s.n_ticks=12
	s.distance = 1
	return s

func _step(delta) -> Move:
	var m := Move.new(); m.id = &"step"; m.kind = Move.Kind.STEP
	m.startup=0; m.active=1; m.recovery=(0 if delta < 0 else 1)  # 上步1拍/撤步2拍
	m.distance_delta = delta; m.stamina_cost = 1
	return m

func test_step_in_reduces_distance():
	var s := _state()
	var p0 := Plan.new(); p0.add(PlacedMove.new(_step(-1), 0))   # 上步 at tick0
	CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.distance, 0, "上步 → 贴身")

func test_same_tick_steps_cancel():
	var s := _state()
	var p0 := Plan.new(); p0.add(PlacedMove.new(_step(-1), 0))   # 进
	var p1 := Plan.new(); p1.add(PlacedMove.new(_step(1), 0))    # 退,同拍
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.distance, 1, "一进一退抵消")

func test_both_step_in_sums_and_applies():
	var s := _state()   # distance = 1
	var p0 := Plan.new(); p0.add(PlacedMove.new(_step(-1), 0))   # 双方同拍都上步
	var p1 := Plan.new(); p1.add(PlacedMove.new(_step(-1), 0))
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.distance, 0, "1 + (-1) + (-1) = -1 → clamp 0(求和后应用)")

func test_distance_clamps():
	var s := _state(); s.distance = 2   # 远
	var p0 := Plan.new(); p0.add(PlacedMove.new(_step(1), 0))   # 再退也不能 > 2
	CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.distance, 2, "+1 at 远(2) clamps to 2, not 3")

func _atk(dmg, rmin, rmax) -> Move:
	var m := Move.new(); m.id=&"a"; m.kind=Move.Kind.ATTACK
	m.startup=0; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=dmg
	m.stamina_cost=2; m.range_min=rmin; m.range_max=rmax
	return m

func test_attack_out_of_range_whiffs():
	var s := _state()   # distance = 1 (中)
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(8, 0, 0), 0))  # 贴身-only
	var ev := CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.hp[1], 40, "够不着，无伤")
	assert_true(ev.any(func(e): return e.type == &"reach"), "发了 reach 事件")

func test_attack_in_range_hits():
	var s := _state()   # distance = 1
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(8, 0, 1), 0))  # 贴身~中
	CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.hp[1], 32, "距离对，命中 -8")

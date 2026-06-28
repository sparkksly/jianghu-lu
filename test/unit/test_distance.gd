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
	var s := _state(); s.distance = 2   # 撤够远(差两格,追身也补不上)
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(8, 0, 0), 0))  # 贴身-only
	var ev := CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.hp[1], 40, "够不着，无伤")
	assert_true(ev.any(func(e): return e.type == &"reach"), "发了 reach 事件")

func test_attack_in_range_hits():
	var s := _state()   # distance = 1
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(8, 0, 1), 0))  # 贴身~中
	CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.hp[1], 32, "距离对，命中 -8")

func test_knockback_pushes_distance():
	var s := _state(); s.distance = 0   # 贴身
	var m := _atk(6, 0, 1); m.knockback = true
	var p0 := Plan.new(); p0.add(PlacedMove.new(m, 0))
	CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.distance, 1, "击退把对手推到中距")

func test_stun_makes_target_skip_next_move():
	var s := _state(); s.distance = 0
	var m := _atk(2, 0, 1); m.stun = 3   # 撞肘式踉跄
	var p0 := Plan.new(); p0.add(PlacedMove.new(m, 0))     # 命中 t0, 令对手 gasp_until=3
	# 对手本想在 t1 出一记攻击, 但被踉跄跳过
	var p1 := Plan.new(); p1.add(PlacedMove.new(_atk(9, 0, 2), 1))
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.hp[0], 40, "我方未被对手的招命中(对手踉跄跳招)")

func test_ai_only_plans_reachable_attacks():
	var checked := 0
	for seed in range(8):
		var a := AiPlanner.new(seed)
		var p := a.plan(Deck.starter(), 12, 12, 1)   # 中距开局
		var dist := 1
		for pm in p.sorted():
			var m: Move = pm.move
			if m.kind == Move.Kind.STEP:
				dist = clampi(dist + m.distance_delta, 0, 2)
			elif m.kind == Move.Kind.ATTACK or m.kind == Move.Kind.THROW:
				assert_true(m.in_range(dist), "AI 排的攻击在其假定距离内可达: %s@%d" % [m.move_name, dist])
				checked += 1
	assert_gt(checked, 0, "至少检查了若干攻击(非空测试)")

# 追身:贴身招够不着「一格」→ 自动逼近一步打到(反制撤步)。
func test_attack_pursues_one_step():
	var s := CombatState.new()
	s.hp = [100, 100]; s.max_hp = [100, 100]
	s.stamina = [50, 50]; s.sta_max = [50, 50]; s.regen = [0, 0]
	s.n_ticks = 6; s.distance = 1   # 贴身招(range[0,0])差一格
	var hook := Move.new()
	hook.id = "hook"; hook.kind = Move.Kind.ATTACK; hook.startup = 0; hook.active = 1; hook.recovery = 1
	hook.damage = 6; hook.stamina_cost = 2; hook.range_min = 0; hook.range_max = 0
	var p0 := Plan.new(); p0.add(PlacedMove.new(hook, 0))
	var ev := CombatSim.simulate(s, [p0, Plan.new()])
	var hit := false
	for e in ev:
		if e.type == &"hit" and e.actor == 0: hit = true
	assert_true(hit, "差一格追身打到")
	assert_eq(s.distance, 0, "追身后贴身")

# 控距:推掌(打断+击退)命中敌人前摇 → 打断其攻击 + 击退拉开,真正创造距离。
func test_interrupt_with_knockback_creates_distance():
	var s := CombatState.new()
	s.hp = [100, 100]; s.max_hp = [100, 100]
	s.stamina = [50, 50]; s.sta_max = [50, 50]; s.regen = [0, 0]
	s.n_ticks = 8; s.distance = 0
	var push := Deck.by_id(&"push_palm")              # 打断+击退,贴身~中
	var foe := _atk(9, 0, 0); foe.startup = 2; foe.id = &"foe"   # 前摇2拍,可被打断
	# 敌人攻击@0(前摇 t0-1);玩家推掌@1 命中敌人前摇 → 打断+击退
	var p0 := Plan.new(); p0.add(PlacedMove.new(push, 1))
	var p1 := Plan.new(); p1.add(PlacedMove.new(foe, 0))
	var ev := CombatSim.simulate(s, [p0, p1])
	var interrupted := false
	for e in ev:
		if e.type == &"interrupt": interrupted = true
	assert_true(interrupted, "推掌打断敌人前摇")
	assert_eq(s.distance, 1, "打断同时击退,距离被拉开")
	assert_eq(s.hp[0], 100, "敌人攻击被打断,我方未受伤")

func test_push_palm_is_a_control_move():
	var p := Deck.by_id(&"push_palm")
	assert_true(p.can_interrupt and p.knockback, "推掌=打断+击退的控距招")

# 破闪:扫击/范围招(pierce)能命中正在闪避的目标;普通招仍被闪掉。
func test_pierce_dodge_hits_through_dodge():
	var s := CombatState.new()
	s.hp = [100, 100]; s.max_hp = [100, 100]
	s.stamina = [50, 50]; s.sta_max = [50, 50]; s.regen = [0, 0]
	s.n_ticks = 6; s.distance = 0
	var dodge := Move.new()
	dodge.id = "dodge"; dodge.kind = Move.Kind.DODGE; dodge.startup = 0; dodge.active = 2; dodge.recovery = 1
	dodge.stamina_cost = 2; dodge.range_min = 0; dodge.range_max = 2
	var sweep := _atk(8, 0, 1); sweep.id = &"sweep"; sweep.pierces_dodge = true
	var normal := _atk(8, 0, 1); normal.id = &"normal"
	# 破闪招打中闪避者
	CombatSim.simulate(s, [_mkplan(sweep), _mkplan(dodge)])
	assert_eq(s.hp[1], 92, "破闪招穿透闪避命中 -8")
	# 普通招被闪
	var s2 := CombatState.new()
	s2.hp = [100, 100]; s2.max_hp = [100, 100]; s2.stamina = [50, 50]; s2.sta_max = [50, 50]; s2.regen = [0, 0]
	s2.n_ticks = 6; s2.distance = 0
	CombatSim.simulate(s2, [_mkplan(normal), _mkplan(dodge)])
	assert_eq(s2.hp[1], 100, "普通招被闪掉")

func _mkplan(m) -> Plan:
	var p := Plan.new(); p.add(PlacedMove.new(m, 0)); return p

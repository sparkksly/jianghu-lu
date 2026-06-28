extends GutTest

# 状态系统(回合内):借力(成功格挡/闪避→下一击增伤)、护体(grants_guard→受伤减免)。

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [100, 100]; s.max_hp = [100, 100]
	s.stamina = [50, 50]; s.sta_max = [50, 50]
	s.regen = [6, 6]; s.n_ticks = 12; s.distance = 0   # 贴身,拳够得着
	return s

func _move(id: String, kind, su: int, act: int, rec: int, dmg: int, opts := {}) -> Move:
	var m := Move.new()
	m.id = id; m.move_name = id; m.kind = kind
	m.startup = su; m.active = act; m.recovery = rec
	m.damage = dmg; m.stamina_cost = 2
	m.range_min = 0; m.range_max = 2
	m.grants_guard = opts.get("guard", 0)
	return m

func _plan(pairs: Array) -> Plan:
	var p := Plan.new()
	for pr in pairs:
		p.add(PlacedMove.new(pr[0], pr[1]))
	return p

func _has_event(events: Array, type: StringName) -> bool:
	for e in events:
		if e.type == type: return true
	return false

# 格挡成功 → 借力,下一拳 4 → ceil(4*1.6)=7。
func test_leverage_after_successful_block_boosts_next_hit():
	var s := _state()
	var guard := _move("guard", Move.Kind.BLOCK, 0, 3, 1, 0)
	var jab := _move("jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	var foe_jab := _move("foe_jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	# P0 格挡@0(占0-3),反击拳@4;P1 拳@2 撞在格挡上(被挡)
	var p0 := _plan([[guard, 0], [jab, 4]])
	var p1 := _plan([[foe_jab, 2]])
	var ev := CombatSim.simulate(s, [p0, p1])
	assert_true(_has_event(ev, &"leverage"), "格挡成功开借力窗口")
	assert_eq(s.hp[1], 94, "借力 4×1.6=6.4→round6,对手 100-6")

# 闪避成功 → 借力。
func test_leverage_after_successful_dodge_boosts_next_hit():
	var s := _state()
	var dodge := _move("dodge", Move.Kind.DODGE, 0, 3, 1, 0)
	var jab := _move("jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	var foe_jab := _move("foe_jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	var p0 := _plan([[dodge, 0], [jab, 4]])
	var p1 := _plan([[foe_jab, 2]])
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.hp[1], 94, "闪避后借力反击 100-6")

# 没有成功防守 → 不增伤(基线 4)。
func test_no_leverage_without_defense():
	var s := _state()
	var jab := _move("jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	var p0 := _plan([[jab, 4]])
	var p1 := _plan([])
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.hp[1], 96, "无借力,普通一拳 100-4")

# 护体:grants_guard 招命中后,几拍内自己受伤减半。
func test_guard_halves_incoming_damage():
	var s := _state()
	var stance := _move("stance", Move.Kind.ATTACK, 0, 1, 0, 5, {"guard": 4})  # 命中→自挂护体4拍
	var foe_jab := _move("foe_jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	# P0 护体招@0(命中P1,自挂护体到t=4);P1 拳@1 砸P0 → 4→ceil(2)=2
	var p0 := _plan([[stance, 0]])
	var p1 := _plan([[foe_jab, 1]])
	var ev := CombatSim.simulate(s, [p0, p1])
	assert_true(_has_event(ev, &"guard"), "命中赋予护体")
	assert_eq(s.hp[1], 95, "P1 吃护体招 5 点")
	assert_eq(s.hp[0], 98, "护体中,P0 只受 4 的一半=2")

# 护体过期后恢复全额。
func test_guard_expires():
	var s := _state()
	var stance := _move("stance", Move.Kind.ATTACK, 0, 1, 0, 5, {"guard": 2})  # 护体到 t=2
	var foe_jab := _move("foe_jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	var p0 := _plan([[stance, 0]])
	var p1 := _plan([[foe_jab, 3]])   # t=3 > guard_until 2 → 全额
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.hp[0], 96, "护体已过期,P0 受全额 4")

func test_attack_scales_damage():
	var s := _state()
	s.attack = [20, 10]   # 攻击力翻倍(基准10→20)
	var jab := _move("jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	CombatSim.simulate(s, [_plan([[jab, 0]]), _plan([])])
	assert_eq(s.hp[1], 100 - 8, "攻20/基准10 → ×2 = 8")

func test_dmg_inc_percent():
	var s := _state()
	s.dmg_inc = [50, 0]   # +50% 基础增伤
	var jab := _move("jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	CombatSim.simulate(s, [_plan([[jab, 0]]), _plan([])])
	assert_eq(s.hp[1], 100 - 6, "4×1.5=6")

func test_extra_dmg_is_separate_multiplier():
	var s := _state()
	s.dmg_inc = [100, 0]; s.extra_dmg = [100, 0]   # ×2 × ×2 = ×4(独立乘区)
	var jab := _move("jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	CombatSim.simulate(s, [_plan([[jab, 0]]), _plan([])])
	assert_eq(s.hp[1], 100 - 16, "4×(1+1)×(1+1)=16,额外是独立乘区")

func test_armor_diminishing_mitigation():
	var s := _state()
	s.armor = [0, 100]   # 100/(100+100)=50%减伤
	var jab := _move("jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	CombatSim.simulate(s, [_plan([[jab, 0]]), _plan([])])
	assert_eq(s.hp[1], 100 - 2, "armor100→50%,4→2")

func test_armor_caps_at_85():
	var s := _state()
	s.armor = [0, 100000]   # 极高 → 封顶85%
	var heavy := _move("heavy", Move.Kind.ATTACK, 0, 1, 1, 40)
	CombatSim.simulate(s, [_plan([[heavy, 0]]), _plan([])])
	assert_eq(s.hp[1], 100 - 6, "封顶85%:40×0.15=6")

func test_status_tick_drains_hp():
	var s := _state()
	s.status[1] = [{"tick": {"hp": -2}, "duration": 3, "modifiers": []}]
	CombatSim.simulate(s, [_plan([]), _plan([])])
	assert_eq(s.hp[1], 100 - 6, "中毒3拍掉6血")

# 格挡=用气硬扛:挡重招耗气多(block 事件 amount=耗气),不再回气。
func test_block_cost_scales_with_attack_power():
	var s := _state()
	var guard := _move("guard", Move.Kind.BLOCK, 0, 2, 0, 0)
	var heavy := _move("heavy", Move.Kind.ATTACK, 0, 1, 1, 12)
	var ev := CombatSim.simulate(s, [_plan([[guard, 2]]), _plan([[heavy, 2]])])
	var bc := -1
	for e in ev:
		if e.type == &"block": bc = e.amount
	assert_eq(bc, 3, "挡 damage12 → 耗 ceil(12/4)=3 气")

func test_block_light_attack_cheaper():
	var s := _state()
	var guard := _move("guard", Move.Kind.BLOCK, 0, 2, 0, 0)
	var jab := _move("jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	var ev := CombatSim.simulate(s, [_plan([[guard, 2]]), _plan([[jab, 2]])])
	for e in ev:
		if e.type == &"block": assert_eq(e.amount, 1, "挡 damage4 → 耗 1 气(净消耗,不回气)")

func test_guard_card_is_short():
	assert_eq(Deck.by_id(&"guard").total_duration(), 2, "格挡缩到 2 拍")

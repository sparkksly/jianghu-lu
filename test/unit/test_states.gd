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
	assert_eq(s.hp[1], 93, "借力反击 4→7,对手 100-7")

# 闪避成功 → 借力。
func test_leverage_after_successful_dodge_boosts_next_hit():
	var s := _state()
	var dodge := _move("dodge", Move.Kind.DODGE, 0, 3, 1, 0)
	var jab := _move("jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	var foe_jab := _move("foe_jab", Move.Kind.ATTACK, 0, 1, 1, 4)
	var p0 := _plan([[dodge, 0], [jab, 4]])
	var p1 := _plan([[foe_jab, 2]])
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.hp[1], 93, "闪避后借力反击 100-7")

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

extends GutTest

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [50, 50]; s.max_hp = [50, 50]
	s.stamina = [20, 20]; s.sta_max = [20, 20]; s.n_ticks = 12
	return s

func _atk(id, dmg, su, interrupt := false, armor := false) -> Move:
	var m := Move.new()
	m.id = id; m.kind = Move.Kind.ATTACK
	m.startup = su; m.active = 1; m.recovery = 1
	m.hit_offsets = [0]; m.damage = dmg; m.stamina_cost = 2
	m.can_interrupt = interrupt; m.super_armor = armor
	return m

# fast interrupter hits at tick1 while slow attacker still in startup (su=3)
func test_interrupt_cancels_slow_move():
	var s := _state()
	var fast := Plan.new(); fast.add(PlacedMove.new(_atk(&"jab", 5, 1, true), 0)) # hits t1
	var slow := Plan.new(); slow.add(PlacedMove.new(_atk(&"heavy", 20, 3), 0))     # would hit t3
	var ev := CombatSim.simulate(s, [fast, slow])
	assert_eq(s.hp[1], 45, "interrupted target took the jab")
	assert_eq(s.hp[0], 50, "heavy never landed (cancelled)")
	assert_eq(ev.filter(func(e): return e.type == &"interrupt").size(), 1)

func test_non_interrupt_hit_does_not_cancel():
	var s := _state()
	var fast := Plan.new(); fast.add(PlacedMove.new(_atk(&"jab", 5, 1, false), 0)) # no interrupt
	var slow := Plan.new(); slow.add(PlacedMove.new(_atk(&"heavy", 20, 3), 0))
	CombatSim.simulate(s, [fast, slow])
	assert_eq(s.hp[1], 45, "jab still deals damage")
	assert_eq(s.hp[0], 30, "heavy STILL lands because jab can't interrupt")

func test_super_armor_immune_to_interrupt():
	var s := _state()
	var fast := Plan.new(); fast.add(PlacedMove.new(_atk(&"jab", 5, 1, true), 0))
	var slow := Plan.new(); slow.add(PlacedMove.new(_atk(&"heavy", 20, 3, false, true), 0)) # 霸体
	CombatSim.simulate(s, [fast, slow])
	assert_eq(s.hp[1], 45, "jab damage applies")
	assert_eq(s.hp[0], 30, "armored heavy not cancelled, still lands")

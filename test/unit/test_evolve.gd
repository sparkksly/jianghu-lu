extends GutTest

func _move() -> Move:
	var m := Move.new()
	m.id = &"jab"; m.recovery = 2; m.stamina_cost = 3; m.damage = 4
	return m

func test_empty_evo_returns_same():
	var m := _move()
	assert_same(Evolve.apply(m, {}), m, "无进化原样返回")

func test_spd_reduces_recovery():
	var r := Evolve.apply(_move(), {"spd": 1})
	assert_eq(r.recovery, 1)

func test_qi_reduces_cost():
	var r := Evolve.apply(_move(), {"qi": 2})
	assert_eq(r.stamina_cost, 1)

func test_dmg_adds_two_per_level():
	var r := Evolve.apply(_move(), {"dmg": 2})
	assert_eq(r.damage, 4 + 4, "每级+2伤")

func test_does_not_mutate_original():
	var m := _move()
	Evolve.apply(m, {"spd": 5, "qi": 5, "dmg": 5})
	assert_eq(m.recovery, 2)
	assert_eq(m.damage, 4)

func test_clamps_at_zero():
	var r := Evolve.apply(_move(), {"spd": 9, "qi": 9})
	assert_eq(r.recovery, 0)
	assert_eq(r.stamina_cost, 0)

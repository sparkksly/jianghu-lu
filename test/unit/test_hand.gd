extends GutTest

func _move(id: String, kind) -> Move:
	var m := Move.new()
	m.id = id; m.move_name = id; m.kind = kind
	m.startup = 0; m.active = 1; m.recovery = 0
	return m

func _deck() -> Array[Move]:
	return [
		_move("jab", Move.Kind.ATTACK),
		_move("hook", Move.Kind.ATTACK),
		_move("guard", Move.Kind.BLOCK),
		_move("dodge", Move.Kind.DODGE),
		_move("step", Move.Kind.STEP),
		_move("grab", Move.Kind.THROW),
	]

func test_attack_pool_only_attacks() -> void:
	var pool := Hand.attack_pool(_deck())
	assert_eq(pool.size(), 2)
	for m in pool:
		assert_eq(m.kind, Move.Kind.ATTACK)

func test_utilities_excludes_attacks() -> void:
	var u := Hand.utilities(_deck())
	assert_eq(u.size(), 4)
	for m in u:
		assert_ne(m.kind, Move.Kind.ATTACK)

func test_draw_count_and_membership() -> void:
	var pool := Hand.attack_pool(_deck())
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var drawn := Hand.draw(pool, 6, rng)
	assert_eq(drawn.size(), 6)
	for m in drawn:
		assert_true(pool.has(m))

func test_draw_is_deterministic_for_same_seed() -> void:
	var pool := Hand.attack_pool(_deck())
	var a := RandomNumberGenerator.new(); a.seed = 7
	var b := RandomNumberGenerator.new(); b.seed = 7
	var da := Hand.draw(pool, 6, a)
	var db := Hand.draw(pool, 6, b)
	for i in 6:
		assert_eq(da[i].id, db[i].id)

func test_draw_can_repeat_from_single_pool() -> void:
	var pool: Array[Move] = [_move("jab", Move.Kind.ATTACK)]
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var drawn := Hand.draw(pool, 4, rng)
	assert_eq(drawn.size(), 4)
	for m in drawn:
		assert_eq(m.id, &"jab")

func test_weighted_draw_favors_high_weight():
	var pool: Array[Move] = [_move("a", Move.Kind.ATTACK), _move("b", Move.Kind.ATTACK)]
	var rng := RandomNumberGenerator.new(); rng.seed = 4
	var drawn := Hand.draw(pool, 60, rng, {&"b": 100})
	var bn := 0
	for m in drawn:
		if m.id == &"b": bn += 1
	assert_gt(bn, 50, "高权重招更常被抽到")

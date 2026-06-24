extends GutTest

func _make() -> Move:
	var m := Move.new()
	m.startup = 2
	m.active = 1
	m.recovery = 2
	m.hit_offsets = [0]
	return m

func test_total_duration():
	assert_eq(_make().total_duration(), 5)

func test_phase_boundaries():
	var m := _make()
	assert_eq(m.phase_at(0), &"startup")
	assert_eq(m.phase_at(1), &"startup")
	assert_eq(m.phase_at(2), &"active")
	assert_eq(m.phase_at(3), &"recovery")
	assert_eq(m.phase_at(4), &"recovery")
	assert_eq(m.phase_at(5), &"done")

func test_hit_tick():
	var m := _make()
	assert_false(m.is_hit_tick(1)) # startup
	assert_true(m.is_hit_tick(2))  # active offset 0
	assert_false(m.is_hit_tick(3)) # recovery

func test_multi_hit_combo():
	var m := Move.new()
	m.startup = 1
	m.active = 3
	m.recovery = 1
	m.hit_offsets = [0, 1, 2]
	assert_eq(m.active_count(), 3)
	assert_true(m.is_hit_tick(1))
	assert_true(m.is_hit_tick(2))
	assert_true(m.is_hit_tick(3))
	assert_false(m.is_hit_tick(4)) # recovery

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

func test_step_kind_and_distance_fields():
	var m := Move.new()
	m.kind = Move.Kind.STEP
	m.distance_delta = -1
	assert_eq(m.kind, Move.Kind.STEP)
	assert_eq(m.distance_delta, -1)

func test_in_range_band():
	var m := Move.new()
	m.range_min = 0; m.range_max = 1   # 贴身~中
	assert_true(m.in_range(0))
	assert_true(m.in_range(1))
	assert_false(m.in_range(2), "中~远 band excludes 远")

func test_range_defaults_any():
	var m := Move.new()
	assert_true(m.in_range(0) and m.in_range(1) and m.in_range(2), "default band = 任意距离")

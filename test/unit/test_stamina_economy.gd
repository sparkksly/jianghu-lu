extends GutTest

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [40, 40]; s.max_hp = [40, 40]
	s.sta_max = [10, 10]; s.stamina = [10, 10]; s.regen = [6, 6]
	s.n_ticks = 10
	return s

func test_regen_round_adds_regen_capped_at_max():
	var s := _state()
	s.stamina = [3, 4]
	s.regen_round()
	assert_eq(s.stamina, [9, 10], "3+6=9, 4+6=10")

func test_regen_round_never_exceeds_sta_max():
	var s := _state()
	s.stamina = [8, 9]
	s.regen_round()
	assert_eq(s.stamina, [10, 10], "capped at sta_max, NOT 14/15")

func test_regen_is_not_full_refill():
	var s := _state()
	s.stamina = [0, 0]
	s.regen_round()
	assert_eq(s.stamina, [6, 6], "partial regen, not a full reset to 10")

func test_anti_starvation_regen_covers_two_basics():
	# Design invariant: regen must afford at least 2 basic moves (cost 2 each).
	var s := _state()
	assert_true(s.regen[0] >= 4, "regen >= 2 basic-move costs so you can always act")

func test_clone_copies_regen():
	var s := _state()
	var c := s.clone()
	c.regen[0] = 99
	assert_eq(s.regen[0], 6, "clone must deep-copy regen, not alias")

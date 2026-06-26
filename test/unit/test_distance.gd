extends GutTest

func test_distance_defaults_to_mid_and_clones():
	var s := CombatState.new()
	assert_eq(s.distance, 1, "开局中距")
	s.distance = 0
	var c := s.clone()
	assert_eq(c.distance, 0)
	c.distance = 2
	assert_eq(s.distance, 0, "clone is independent")

extends GutTest

func test_add():
	assert_eq(Stats.aggregate(5, [{"stat": "attack", "op": "add", "value": 3}], "attack"), 8)

func test_mul():
	assert_eq(Stats.aggregate(10, [{"stat": "attack", "op": "mul", "value": 1.5}], "attack"), 15)

func test_only_matching_stat():
	assert_eq(Stats.aggregate(5, [{"stat": "defense", "op": "add", "value": 3}], "attack"), 5)

func test_add_then_mul():
	var mods := [{"stat": "a", "op": "add", "value": 3}, {"stat": "a", "op": "mul", "value": 2.0}]
	assert_eq(Stats.aggregate(2, mods, "a"), 10)   # (2+3)*2

extends GutTest

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func _disc() -> Dictionary:
	return {"triggers": [{"type": "tag_hits", "tag": &"腿法", "need": 5}, {"type": "tag_two_combo", "tag": &"腿法"}], "chance": 1.0}

func test_empty_never():
	assert_false(Discovery.check({}, {}, _rng(1)))

func test_needs_all_triggers():
	var d := _disc()
	assert_false(Discovery.check(d, {"tag_hits": {&"腿法": 3}, "tag_two_combo": {&"腿法": true}}, _rng(1)), "次数不足")
	assert_false(Discovery.check(d, {"tag_hits": {&"腿法": 5}, "tag_two_combo": {}}, _rng(1)), "没两连")
	assert_true(Discovery.check(d, {"tag_hits": {&"腿法": 5}, "tag_two_combo": {&"腿法": true}}, _rng(1)), "都满足+chance1")

func test_chance_zero():
	var d := _disc(); d["chance"] = 0.0
	assert_false(Discovery.check(d, {"tag_hits": {&"腿法": 9}, "tag_two_combo": {&"腿法": true}}, _rng(1)))

extends GutTest

func test_empty_always_true():
	assert_true(Requirements.met([], {"learned": [], "mastery": {}}))

func test_art_mastery():
	var req := [{"type": "art_mastery", "art": &"a", "need": 3}]
	assert_true(Requirements.met(req, {"learned": [], "mastery": {&"a": 3}}))
	assert_false(Requirements.met(req, {"learned": [], "mastery": {&"a": 2}}))

func test_art_known():
	var req := [{"type": "art_known", "art": &"a"}]
	assert_true(Requirements.met(req, {"learned": [&"a"], "mastery": {}}))
	assert_false(Requirements.met(req, {"learned": [], "mastery": {}}))

func test_arts_count_by_family():
	# 罗汉拳/伏虎拳 都属拳法 → 已学2门拳法功夫
	var ctx := {"learned": [&"luohan", &"fuhu"], "mastery": {}}
	assert_true(Requirements.met([{"type": "arts_count", "family": &"拳法", "need": 2}], ctx))
	assert_false(Requirements.met([{"type": "arts_count", "family": &"拳法", "need": 3}], ctx))

func test_and_multiple_conditions():
	var req := [{"type": "art_known", "art": &"a"}, {"type": "art_mastery", "art": &"b", "need": 2}]
	assert_true(Requirements.met(req, {"learned": [&"a"], "mastery": {&"b": 2}}))
	assert_false(Requirements.met(req, {"learned": [&"a"], "mastery": {&"b": 1}}))

func test_or():
	var req := [{"type": "or", "any": [{"type": "art_known", "art": &"a"}, {"type": "art_known", "art": &"b"}]}]
	assert_true(Requirements.met(req, {"learned": [&"b"], "mastery": {}}))
	assert_false(Requirements.met(req, {"learned": [&"c"], "mastery": {}}))

func test_unknown_type_is_false():
	assert_false(Requirements.met([{"type": "nope"}], {"learned": [], "mastery": {}}), "未知条件→false,不误解锁")

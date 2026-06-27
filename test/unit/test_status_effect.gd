extends GutTest

func test_mods_for_filters_by_stat():
	var list := [{"modifiers": [{"stat": "attack", "op": "add", "value": 5}]}, {"modifiers": [{"stat": "defense", "op": "add", "value": 2}]}]
	assert_eq(StatusEffect.mods_for(list, "attack").size(), 1)
	assert_eq(StatusEffect.mods_for(list, "defense").size(), 1)

func test_advance_ticks_and_expires():
	var list := [{"tick": {"hp": -2}, "duration": 2}, {"tick": {"hp": -1}, "duration": 1}]
	var d := StatusEffect.advance(list)
	assert_eq(int(d["hp"]), -3, "本格两条掉血合计")
	assert_eq(list.size(), 1, "duration 1 的到期移除")
	assert_eq(int(list[0]["duration"]), 1)

func test_advance_empty():
	var list := []
	assert_eq(int(StatusEffect.advance(list)["hp"]), 0)

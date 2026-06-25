extends GutTest

func _kick(id := &"kick") -> Move:
	var m := Move.new(); m.id=id; m.kind=Move.Kind.ATTACK; m.tags=[&"腿法"]
	m.startup=1; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=4; m.stamina_cost=2
	return m

func _block() -> Move:
	var m := Move.new(); m.id=&"guard"; m.kind=Move.Kind.BLOCK; m.startup=1; m.active=2; m.recovery=1; m.stamina_cost=2
	return m

func _throw() -> Move:
	var m := Move.new(); m.id=&"qin"; m.kind=Move.Kind.THROW; m.startup=1; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=5; m.stamina_cost=2
	return m

func _combo_result(id) -> Move:
	var m := Move.new(); m.id=id; m.kind=Move.Kind.ATTACK; m.startup=1; m.active=2; m.recovery=1
	m.hit_offsets=[0,1]; m.damage=8; m.stamina_cost=0  # paid via originals already
	return m

func test_homogeneous_three_kicks_fuse():
	var rules := ComboRules.new()
	rules.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"},{"tag":&"腿法"}], _combo_result(&"chain_kick"))
	var p := Plan.new()
	# back-to-back: each dur=3
	p.add(PlacedMove.new(_kick(), 0))
	p.add(PlacedMove.new(_kick(), 3))
	p.add(PlacedMove.new(_kick(), 6))
	var fused := rules.apply(p)
	assert_eq(fused.moves.size(), 1)
	assert_eq(fused.moves[0].move.id, &"chain_kick")
	assert_eq(fused.moves[0].start, 0)

func test_heterogeneous_by_kind():
	var rules := ComboRules.new()
	rules.add_recipe([{"kind":Move.Kind.ATTACK},{"kind":Move.Kind.BLOCK},{"kind":Move.Kind.THROW}], _combo_result(&"qiankun"))
	var p := Plan.new()
	p.add(PlacedMove.new(_kick(), 0))   # dur3
	p.add(PlacedMove.new(_block(), 3))  # dur4 -> end 7
	p.add(PlacedMove.new(_throw(), 7))  # dur3
	var fused := rules.apply(p)
	assert_eq(fused.moves.size(), 1)
	assert_eq(fused.moves[0].move.id, &"qiankun")

func test_gap_breaks_combo():
	var rules := ComboRules.new()
	rules.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"},{"tag":&"腿法"}], _combo_result(&"chain_kick"))
	var p := Plan.new()
	p.add(PlacedMove.new(_kick(), 0))
	p.add(PlacedMove.new(_kick(), 3))
	p.add(PlacedMove.new(_kick(), 7)) # gap (prev ends at 6)
	var fused := rules.apply(p)
	assert_eq(fused.moves.size(), 3, "gap prevents fusion")

func test_longest_match_first():
	var rules := ComboRules.new()
	rules.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"}], _combo_result(&"double_kick"))
	rules.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"},{"tag":&"腿法"}], _combo_result(&"chain_kick"))
	var p := Plan.new()
	p.add(PlacedMove.new(_kick(), 0)); p.add(PlacedMove.new(_kick(), 3)); p.add(PlacedMove.new(_kick(), 6))
	var fused := rules.apply(p)
	assert_eq(fused.moves[0].move.id, &"chain_kick", "3-match beats 2-match")

func test_equal_length_registration_order_wins():
	# Two 2-slot recipes both match two back-to-back kicks (ATTACK + tag 腿法).
	# Recipe A (registered first): matches by tag → result &"A_first"
	# Recipe B (registered second): matches by kind → result &"B_second"
	# apply() must yield A_first proving registration order is the tie-break.
	var rules := ComboRules.new()
	rules.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"}], _combo_result(&"A_first"))
	rules.add_recipe([{"kind":Move.Kind.ATTACK},{"kind":Move.Kind.ATTACK}], _combo_result(&"B_second"))
	var p := Plan.new()
	p.add(PlacedMove.new(_kick(), 0))  # dur=3, ATTACK + 腿法
	p.add(PlacedMove.new(_kick(), 3))  # dur=3, ATTACK + 腿法
	var fused := rules.apply(p)
	assert_eq(fused.moves.size(), 1, "both recipes match; one fusion expected")
	assert_eq(fused.moves[0].move.id, &"A_first", "first-registered recipe wins among equal-length recipes")

func test_describe_recipes_is_chinese():
	var rules := ComboLibrary.build()
	var desc := rules.describe_recipes()
	assert_true(desc.size() >= 3)
	# find the qiankun (攻+防+投) recipe
	var found := false
	for d in desc:
		if d["result"] == "乾坤大挪移":
			assert_eq(d["slots"], ["攻", "格挡", "投"])
			found = true
	assert_true(found, "qiankun recipe described in Chinese")

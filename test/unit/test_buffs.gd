extends GutTest

func test_catalog_and_spec():
	assert_true(Buffs.has(&"vigor"))
	var sp := Buffs.spec(&"focus")
	assert_eq(sp["id"], &"focus")
	assert_eq(sp["tick"]["qi"], 2)
	assert_eq(Buffs.spec(&"nope"), {})

func test_describe():
	assert_string_contains(Buffs.describe(&"vigor"), "伤害 +20%")
	assert_string_contains(Buffs.describe(&"focus"), "气")

func test_vigor_modifier_boosts_dmg_inc():
	var list: Array = []
	StatusEffect.add(list, Buffs.spec(&"vigor"))
	assert_eq(StatusEffect.mods_for(list, "dmg_inc")[0]["value"], 20)

func test_focus_ticks_qi():
	var list: Array = []
	StatusEffect.add(list, Buffs.spec(&"focus"))
	var sd := StatusEffect.advance(list)
	assert_eq(sd["qi"], 2, "凝气每拍回 2 气")

func test_move_empower_field():
	assert_true(&"vigor" in Deck.fuhu().empower, "伏虎运劲")
	assert_true(&"focus" in Deck.taiji_yunshou().empower, "云手凝气")
	assert_true(&"mend" in Deck.jinzhong().empower)
	assert_true(&"ironbody" in Deck.weituo().empower)

func test_balance_counts_empower():
	assert_gt(Balance._empower_power(Deck.fuhu()), 0.0)
	assert_eq(Balance._empower_power(Deck.by_id(&"jab")), 0.0)

func test_loc_log_line_buff():
	var e := CombatEvent.new(2, &"buff", 0, 0, 0, &"vigor")
	assert_string_contains(Loc.log_line(e), "运劲")

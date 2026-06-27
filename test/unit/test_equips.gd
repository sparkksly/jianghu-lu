extends GutTest

func test_slots_and_defs():
	assert_eq(Equips.by_slot(&"武器").size(), 3)
	assert_eq(Equips.by_slot(&"防具").size(), 3)
	assert_eq(Equips.by_slot(&"饰品").size(), 3)
	assert_eq(Equips.def(&"xuantie_dao").equip_name, "玄铁重刀")

func test_modifiers_aggregate():
	# 装备一武器一防具 → modifier 汇总
	var eq := {&"武器": &"jinggang_jian", &"防具": &"suozijia"}
	var mods := Equips.modifiers_for(eq)
	var atk := 0; var arm := 0
	for m in mods:
		if m["stat"] == "attack": atk += m["value"]
		if m["stat"] == "armor": arm += m["value"]
	assert_eq(atk, 5)
	assert_eq(arm, 25)

func test_runstate_equip_affects_combat_stats():
	var r := RunState.new(&"shaolin")
	var base_atk := r.combat_attack()
	var base_arm := r.combat_armor()
	r.equip(&"jinggang_jian")   # attack+5
	r.equip(&"suozijia")        # armor+25
	assert_eq(r.combat_attack(), base_atk + 5, "武器 +5 攻击")
	assert_eq(r.combat_armor(), base_arm + 25, "防具 +25 防御")

func test_same_slot_replaces():
	var r := RunState.new(&"shaolin")
	r.equip(&"jinggang_jian")   # 武器
	r.equip(&"xuantie_dao")     # 武器(替换)
	assert_eq(r.equipped(&"武器"), &"xuantie_dao", "同槽替换")
	assert_eq(r.combat_attack(), 10 + 6, "只算后装的重刀")

func test_extra_dmg_equip():
	var r := RunState.new(&"shaolin")
	r.equip(&"xuantie_jie")     # 饰品 extra+12 attack+3
	assert_eq(r.combat_extra(), 12, "戒指给独立乘区额外伤害")
	assert_eq(r.combat_attack(), 13, "戒指也带 +3 攻击")

func test_qi_equip():
	var r := RunState.new(&"shaolin")
	r.equip(&"juqi")            # 饰品 max_qi+8 max_hp+5
	assert_eq(r.combat_max_qi(), r.base_max_qi + r.qi_bonus() + 8)
	assert_eq(r.combat_max_hp(), r.max_hp + 5)

func test_encounter_grants_equip():
	var r := RunState.new(&"shaolin")
	var rng := RandomNumberGenerator.new()
	r.apply_encounter({"equip": &"hanyue"}, rng)
	assert_eq(r.equipped(&"武器"), &"hanyue")
	assert_eq(r.combat_dmg_inc(), r.base_dmg_inc + 16)

func test_balance_equip_in_budget():
	var off: Array = []
	for e in Equips.all():
		if not Balance.equip_in_tolerance(e):
			off.append("%s(t%d p%d b%d)" % [e.id, e.tier, Balance.equip_power(e), Balance.equip_budget(e.tier)])
	if off.size() > 0:
		gut.p("⚠ 装备超预算: " + str(off))
	assert_lte(off.size(), 1, "装备 power 应落 tier 预算")

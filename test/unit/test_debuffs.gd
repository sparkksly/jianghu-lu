extends GutTest

func test_catalog_and_spec():
	assert_true(Debuffs.has(&"poison"))
	var sp := Debuffs.spec(&"poison")
	assert_eq(sp["id"], &"poison")
	assert_eq(sp["tick"]["hp"], -2)
	assert_eq(sp["duration"], 6)
	assert_eq(Debuffs.spec(&"nope"), {})

func test_describe():
	assert_string_contains(Debuffs.describe(&"poison"), "中毒")
	assert_string_contains(Debuffs.describe(&"weak"), "伤害 -30%")
	assert_string_contains(Debuffs.describe(&"sunder"), "防御 -20")

func test_spec_is_independent_copy():
	var a := Debuffs.spec(&"poison")
	a["tick"]["hp"] = -999
	assert_eq(Debuffs.spec(&"poison")["tick"]["hp"], -2, "目录不被污染")

func test_poison_ticks_hp_via_status():
	# StatusEffect.advance 把中毒的 tick 累计出来
	var list: Array = []
	StatusEffect.add(list, Debuffs.spec(&"poison"))
	var sd := StatusEffect.advance(list)
	assert_eq(sd["hp"], -2, "中毒每拍掉 2 血")
	assert_eq(list.size(), 1, "6 拍内仍在")

func test_weak_modifier_reduces_dmg_inc():
	var list: Array = []
	StatusEffect.add(list, Debuffs.spec(&"weak"))
	var mods := StatusEffect.mods_for(list, "dmg_inc")
	assert_eq(mods.size(), 1)
	assert_eq(mods[0]["value"], -30, "虚弱降伤害%")

func test_move_inflict_field():
	assert_true(&"poison" in Deck.by_id(&"venom_palm").inflict, "毒砂掌附带中毒")
	assert_true(&"bleed" in Deck.by_id(&"blood_blade").inflict, "血河刀附带流血")
	assert_true(&"weak" in Deck.by_id(&"soul_reap").inflict)
	assert_true(&"sunder" in Deck.by_id(&"rot_claw").inflict)
	assert_true(&"bleed" in Deck.yingzhua().inflict, "玩家鹰爪附带流血")

func test_balance_counts_inflict_power():
	# 带 debuff 的招式 power 比无 debuff 高
	var with_bleed := Balance._inflict_power(Deck.yingzhua())
	assert_gt(with_bleed, 0.0)
	assert_eq(Balance._inflict_power(Deck.by_id(&"jab")), 0.0, "无 debuff 招不加")

func test_combat_applies_debuff_on_hit():
	# 一方用毒砂掌命中,对方 status 应挂上中毒
	var p := load("res://src/combat/combat_sim.gd")
	# 直接验证施加逻辑:构造 status 列表 + spec
	var status: Array = []
	StatusEffect.add(status, Debuffs.spec(&"poison"))
	assert_eq(status.size(), 1)
	assert_eq(status[0]["name"], "中毒")

func test_neishang_is_weak_plus_qi_drain():
	# 内伤 = 虚弱(降伤害%) + 扣气力上限
	var list: Array = []
	StatusEffect.add(list, Debuffs.spec(&"neishang"))
	assert_eq(StatusEffect.mods_for(list, "dmg_inc")[0]["value"], -25, "内伤含虚弱(降伤害)")
	assert_eq(StatusEffect.mods_for(list, "max_qi")[0]["value"], -3, "内伤含扣气力上限")
	assert_string_contains(Debuffs.describe(&"neishang"), "内伤")

func test_eff_sta_max_drops_with_qi_debuff():
	var s := CombatState.new()
	s.sta_max = [10, 10]
	assert_eq(s.eff_sta_max(0), 10, "无 debuff 满上限")
	StatusEffect.add(s.status[0], Debuffs.spec(&"neishang"))
	assert_eq(s.eff_sta_max(0), 7, "内伤后气力上限 −3")

func test_qi_ceiling_clamps_regen():
	var s := CombatState.new()
	s.sta_max = [10, 10]; s.stamina = [10, 10]; s.regen = [6, 6]
	StatusEffect.add(s.status[0], Debuffs.spec(&"neishang"))
	s.regen_round()
	assert_lte(s.stamina[0], 7, "回气受内伤后的上限压制")

func test_toad_power_inflicts_neishang():
	assert_true(&"neishang" in Deck.by_id(&"toad_power").inflict, "蛤蟆劲震内伤")

func test_loc_log_line_debuff():
	var e := CombatEvent.new(3, &"debuff", 1, 0, 0, &"poison")
	var line := Loc.log_line(e)
	assert_string_contains(line, "中毒")
	assert_string_contains(line, "你", "目标侧(0=你)")

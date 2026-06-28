extends GutTest

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = 7; return r

func test_roll_has_equip_heal_art():
	var run := RunState.new(&"shaolin")
	var items := Shop.roll(run, 0, _rng())
	var kinds := {}
	for it in items: kinds[it["kind"]] = true
	assert_true(kinds.has("equip"), "卖装备")
	assert_true(kinds.has("heal"), "卖疗伤")

func test_buy_equip_spends_and_grants():
	var run := RunState.new(&"shaolin")
	run.add_money(200)
	var items := Shop.roll(run, 0, _rng())
	var equip_item: Dictionary = {}
	for it in items:
		if it["kind"] == "equip": equip_item = it; break
	var before := run.money
	assert_true(Shop.buy(run, equip_item), "买得起")
	assert_eq(run.money, before - int(equip_item["price"]))
	assert_true(run.owned_equipment.has(equip_item["id"]), "得到装备")
	assert_true(equip_item.get("sold", false), "标记售出")
	assert_false(Shop.buy(run, equip_item), "售出不能再买")

func test_buy_too_poor_fails():
	var run := RunState.new(&"shaolin")
	run.money = 0   # 清空银两
	var items := Shop.roll(run, 0, _rng())
	assert_false(Shop.buy(run, items[0]), "没钱买不了")

func test_starting_money():
	assert_eq(RunState.new(&"shaolin").money, 50, "开局 50 银两")

func test_buy_heal_restores_hp():
	var run := RunState.new(&"shaolin")
	run.add_money(100); run.player_hp = 10
	var heal: Dictionary = {}
	for it in Shop.roll(run, 0, _rng()):
		if it["kind"] == "heal": heal = it; break
	Shop.buy(run, heal)
	assert_eq(run.player_hp, mini(run.max_hp, 10 + int(heal["amount"])))

func test_money_and_risk_encounter():
	var run := RunState.new(&"shaolin")
	run.money = 0
	run.apply_encounter({"money": 40}, _rng())
	assert_eq(run.money, 40)
	run.apply_encounter({"reputation": 2}, _rng())
	assert_eq(run.reputation, 2)
	# 负向治疗保命:不致死
	run.player_hp = 5
	run.apply_encounter({"heal": -99}, _rng())
	assert_eq(run.player_hp, 1, "受创留 1 血")

func test_shop_scene_lists_items():
	var run := RunState.new(&"shaolin"); run.money = 200
	var s = load("res://src/scenes/shop.tscn").instantiate()
	add_child_autofree(s)
	await get_tree().process_frame
	s.setup(run, 0, _rng())
	await get_tree().process_frame
	assert_gt(s.get_node("Panel/Margin/VBox/ItemsBox").get_child_count(), 0, "货架有商品")
	assert_string_contains(s.get_node("Panel/Margin/VBox/MoneyLabel").text, "200")

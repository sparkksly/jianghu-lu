class_name Shop
extends RefCounted

# 商店:每章商队卖几件货。商品 {kind, id?/amount?, price, label, sold?}。
# kind: equip(装备) / heal(疗伤) / art(秘籍)。买卖逻辑见 buy()。

const PRICE := {"equip": {1: 30, 2: 55, 3: 80}, "heal": 25, "art": 50}
const HEAL_AMOUNT := 22

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]; a[i] = a[j]; a[j] = t

# 生成本章货架(2 装备 + 疗伤 + 1 秘籍)。run 用于过滤已拥有/可学。
static func roll(run, chapter: int, rng: RandomNumberGenerator) -> Array:
	var items: Array = []
	var tier := 1 if chapter == 0 else 2
	var pool: Array = []
	for e in Equips.all():
		if e.tier == tier and not run.owned_equipment.has(e.id):
			pool.append(e.id)
	_shuffle(pool, rng)
	for i in mini(2, pool.size()):
		var id: StringName = pool[i]
		items.append({"kind": "equip", "id": id, "price": PRICE["equip"][tier],
			"label": "%s  (%s)" % [Equips.display_name(id), Lexicon.describe_mods(Equips.def(id).modifiers)]})
	items.append({"kind": "heal", "amount": HEAL_AMOUNT, "price": PRICE["heal"],
		"label": "疗伤丹  ( 回 %d 气血 )" % HEAL_AMOUNT})
	var arts: Array = run.acquirable_arts("encounter")
	_shuffle(arts, rng)
	for i in mini(2, arts.size()):   # 上架 2 门不同秘籍,玩家挑
		var aid: StringName = arts[i]
		items.append({"kind": "art", "id": aid, "price": PRICE["art"],
			"label": "秘籍·%s  ( 领悟 )" % Arts.display_name(aid)})
	return items

# 买一件:扣银两后应用效果。买不起返回 false。
static func buy(run, item: Dictionary) -> bool:
	if item.get("sold", false):
		return false
	if not run.spend_money(int(item["price"])):
		return false
	match item["kind"]:
		"equip": run.obtain_equipment(item["id"])
		"heal": run.player_hp = mini(run.max_hp, run.player_hp + int(item["amount"]))
		"art": run.learn(item["id"])
	item["sold"] = true
	return true

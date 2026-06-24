class_name Deck
extends RefCounted

static func _m(id, name, kind, su, act, rec, dmg, cost, opts := {}) -> Move:
	var m := Move.new()
	m.id = id; m.move_name = name; m.kind = kind
	m.startup = su; m.active = act; m.recovery = rec
	m.damage = dmg; m.stamina_cost = cost
	# Typed arrays must be assigned carefully
	var hits: Array[int] = []
	for v in opts.get("hits", [0]):
		hits.append(v as int)
	m.hit_offsets = hits
	var tags: Array[StringName] = []
	for t in opts.get("tags", []):
		tags.append(t as StringName)
	m.tags = tags
	m.can_interrupt = opts.get("interrupt", false)
	m.super_armor = opts.get("armor", false)
	m.is_heavy = opts.get("heavy", false)
	m.priority = opts.get("priority", 0)
	return m

static func starter() -> Array[Move]:
	return [
		_m(&"jab_kick", "轻踢", Move.Kind.ATTACK, 1, 1, 1, 4, 2, {"tags":[&"腿法"], "interrupt":true, "priority":5}),
		_m(&"low_kick", "扫腿", Move.Kind.ATTACK, 1, 1, 1, 5, 2, {"tags":[&"腿法"]}),
		_m(&"heavy_kick", "重踢", Move.Kind.ATTACK, 3, 1, 2, 12, 4, {"tags":[&"腿法"], "heavy":true, "armor":true}),
		_m(&"guard", "格挡", Move.Kind.BLOCK, 1, 3, 1, 0, 2, {}),
		_m(&"dodge", "身法", Move.Kind.DODGE, 1, 2, 1, 0, 2, {"tags":[&"轻功"]}),
		_m(&"throw", "擒拿", Move.Kind.THROW, 1, 1, 1, 5, 3, {}),
	]

# combo result moves (not in hand; produced by fusion)
static func chain_kick() -> Move:
	return _m(&"chain_kick", "连环踢", Move.Kind.ATTACK, 1, 2, 1, 14, 0, {"tags":[&"腿法"], "hits":[0,1]})
static func wuying() -> Move:
	return _m(&"wuying", "佛山无影脚", Move.Kind.ATTACK, 1, 3, 1, 22, 0, {"tags":[&"腿法"], "hits":[0,1,2], "armor":true})
static func qiankun() -> Move:
	return _m(&"qiankun", "乾坤大挪移", Move.Kind.THROW, 1, 1, 1, 18, 0, {})

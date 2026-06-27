class_name Passives
extends RefCounted

# 被动注册表。内功是第一类(category=内功);轻功/天赋以后加 category。
# 属性被动的效果用 modifier 格式 → 直接进 Stats 聚合(和装备/buff/果子同乘区)。

static func _stat(stat: String, v: int) -> Dictionary:
	return {"kind": "stat", "stat": stat, "op": "add", "value": v, "per_level": true}

static func _defs() -> Array:
	return [
		PassiveDef.make(&"yijinjing", "易筋经", &"内功", [_stat("max_hp", 3), _stat("max_qi", 1)]),
		PassiveDef.make(&"liangyi", "两仪心法", &"内功", [_stat("max_hp", 1), _stat("max_qi", 2)]),
		PassiveDef.make(&"luohanqi", "罗汉伏气", &"内功", [_stat("max_hp", 2), _stat("max_qi", 2)]),
		PassiveDef.make(&"ximui", "洗髓经", &"内功", [_stat("max_hp", 4), _stat("max_qi", 0)]),
		PassiveDef.make(&"taiqing", "太清真气", &"内功", [_stat("max_hp", 0), _stat("max_qi", 3)]),
		PassiveDef.make(&"xiantian", "先天功", &"内功", [_stat("max_hp", 3), _stat("max_qi", 2)]),
		PassiveDef.make(&"guixi", "龟息功", &"内功", [_stat("max_hp", 2), _stat("max_qi", 1)]),
		PassiveDef.make(&"chunyang", "纯阳功", &"内功", [_stat("max_hp", 2), _stat("max_qi", 3)]),
		PassiveDef.make(&"xuanpin", "玄牝功", &"内功", [_stat("max_hp", 1), _stat("max_qi", 3)]),
		PassiveDef.make(&"taiji_xin", "太极心法", &"内功", [_stat("max_hp", 1), _stat("max_qi", 1)]),
	]

static func def(id: StringName) -> PassiveDef:
	for d in _defs():
		if d.id == id:
			return d
	return null

static func by_category(cat: StringName) -> Array:
	var out: Array = []
	for d in _defs():
		if d.category == cat:
			out.append(d.id)
	return out

# 某被动某属性的 per-level 加成(内功 hp/qi facade 用)。
static func stat_per_level(id: StringName, stat: String) -> int:
	var d := def(id)
	if d == null:
		return 0
	for e in d.effects:
		if e.get("kind", "") == "stat" and e.get("stat", "") == stat and bool(e.get("per_level", false)):
			return int(e.get("value", 0))
	return 0

# 持有被动(id→level) → modifier 列表(供 Stats 聚合)。未来攻击/防御/增伤型被动直接进。
static func modifiers_for(held: Dictionary) -> Array:
	var mods: Array = []
	for id in held:
		var d := def(id)
		if d == null:
			continue
		var lv := int(held[id])
		for e in d.effects:
			if e.get("kind", "") == "stat":
				var v := int(e.get("value", 0)) * (lv if bool(e.get("per_level", false)) else 1)
				mods.append({"stat": e["stat"], "op": e.get("op", "add"), "value": v})
	return mods

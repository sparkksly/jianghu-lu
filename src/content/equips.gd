class_name Equips
extends RefCounted

# 装备注册表。三槽:武器/防具/饰品,各槽一件。属性走 modifier 聚合(和内功/buff 同乘区)。
# 加装备 = 加一条 EquipDef。武器可 grants 专属功夫。

const SLOTS := [&"武器", &"防具", &"饰品"]

static func _mod(stat: String, v: int) -> Dictionary:
	return {"stat": stat, "op": "add", "value": v}

static func _defs() -> Array:
	return [
		# 武器:并入攻击力/基础增伤(加法区)
		EquipDef.make(&"jinggang_jian", "精钢剑", &"武器", [_mod("attack", 5)], 1),
		EquipDef.make(&"hanyue", "寒月软剑", &"武器", [_mod("dmg_inc", 16)], 1),
		EquipDef.make(&"xuantie_dao", "玄铁重刀", &"武器", [_mod("attack", 6), _mod("dmg_inc", 10)], 2),
		# 防具:防御(递减减伤)/气血
		EquipDef.make(&"suozijia", "锁子甲", &"防具", [_mod("armor", 25)], 1),
		EquipDef.make(&"ruanwei", "软猬甲", &"防具", [_mod("armor", 20), _mod("max_hp", 8)], 1),
		EquipDef.make(&"wujin", "乌金铠", &"防具", [_mod("armor", 40), _mod("max_hp", 12)], 2),
		# 饰品:气血/气海/稀有额外伤害(独立乘区)
		EquipDef.make(&"yupei", "护身玉佩", &"饰品", [_mod("max_hp", 16)], 1),
		EquipDef.make(&"juqi", "聚气环", &"饰品", [_mod("max_qi", 8), _mod("max_hp", 5)], 1),
		EquipDef.make(&"xuantie_jie", "玄铁指环", &"饰品", [_mod("extra_dmg", 12), _mod("attack", 3)], 2),
	]

static func def(id: StringName) -> EquipDef:
	for d in _defs():
		if d.id == id:
			return d
	return null

static func all() -> Array:
	return _defs()

static func by_slot(slot: StringName) -> Array:
	var out: Array = []
	for d in _defs():
		if d.slot == slot:
			out.append(d.id)
	return out

static func display_name(id: StringName) -> String:
	var d := def(id)
	return d.equip_name if d != null else String(id)

# 已装备(slot→id) → 汇总所有 modifier(供 Stats 聚合)。
static func modifiers_for(equipment: Dictionary) -> Array:
	var mods: Array = []
	for slot in equipment:
		var d := def(equipment[slot])
		if d != null:
			mods.append_array(d.modifiers)
	return mods

# 已装备的武器等 grants 的功夫(装备时领悟)。
static func grants_for(equipment: Dictionary) -> Array:
	var out: Array = []
	for slot in equipment:
		var d := def(equipment[slot])
		if d != null:
			out.append_array(d.grants)
	return out

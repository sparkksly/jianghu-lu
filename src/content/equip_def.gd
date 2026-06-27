class_name EquipDef
extends Resource

# 装备定义。武器/防具/饰品都是 EquipDef,区别只在 slot。
# modifiers: 属性加成 [{stat,op,value}] → 进 Stats 聚合(和内功/buff/果子同乘区)。
# grants: 武器可解锁的专属功夫 [art_id](装备时领悟)。

@export var id: StringName = &""
@export var equip_name: String = "装备"
@export var slot: StringName = &"武器"   # 武器 / 防具 / 饰品
@export var modifiers: Array = []
@export var grants: Array = []
@export var tier: int = 1

static func make(p_id: StringName, p_name: String, p_slot: StringName, p_mods: Array, p_tier: int = 1, p_grants: Array = []) -> EquipDef:
	var d := EquipDef.new()
	d.id = p_id
	d.equip_name = p_name
	d.slot = p_slot
	d.modifiers = p_mods
	d.tier = p_tier
	d.grants = p_grants
	return d

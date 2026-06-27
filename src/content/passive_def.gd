class_name PassiveDef
extends Resource

# 常驻被动定义。内功/轻功/护符/天赋都是 Passive,区别只在 category。
# effects: 提供的效果(数据驱动):
#   {kind:"stat", stat, op, value, per_level}  属性被动→走 modifier 聚合(和装备/buff 同乘区)
#   {kind:"trigger", when, do}                 触发型被动(格挡回气/受击反震…,留接口)

@export var id: StringName = &""
@export var passive_name: String = "被动"
@export var category: StringName = &"内功"   # 内功 / 轻功 / ...
@export var effects: Array = []

static func make(p_id: StringName, p_name: String, p_category: StringName, p_effects: Array) -> PassiveDef:
	var d := PassiveDef.new()
	d.id = p_id
	d.passive_name = p_name
	d.category = p_category
	d.effects = p_effects
	return d

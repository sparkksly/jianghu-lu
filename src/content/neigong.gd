class_name Neigong
extends RefCounted

# 内功 = 被动系统(Passives)里 category=内功 的一类。本类是薄 facade,
# 数据/结构都在 Passives(PassiveDef);内功效果是 per-level 的属性 modifier。
# 轻功/天赋等以后是 Passives 的其它 category。

static func all() -> Array:
	return Passives.by_category(&"内功")

static func starter(menpai_id: StringName) -> StringName:
	return &"liangyi" if menpai_id == &"wudang" else &"yijinjing"

static func display_name(id: StringName) -> String:
	var d := Passives.def(id)
	return d.passive_name if d != null else "易筋经"

static func hp_per_level(id: StringName) -> int:
	return Passives.stat_per_level(id, "max_hp")

static func qi_per_level(id: StringName) -> int:
	return Passives.stat_per_level(id, "max_qi")

class_name Debuffs
extends RefCounted

# debuff(减益)目录。每条是一个 StatusEffect spec(去掉 id,spec() 时补上)。
# 两类:tick 持续伤害(中毒/流血) 与 modifier 属性削弱(虚弱降攻/破甲降防)。
# 都复用现有 StatusEffect 载体:tick → 每拍掉血;modifier → 进属性聚合(eff_dmg_inc/eff_armor)。
# 招式 Move.inflict 列 debuff id,命中时 combat_sim 施加。

const DEFS := {
	&"poison": {"name": "中毒", "tick": {"hp": -2}, "duration": 6},
	&"bleed": {"name": "流血", "tick": {"hp": -3}, "duration": 4},
	&"weak": {"name": "虚弱", "modifiers": [{"stat": "dmg_inc", "op": "add", "value": -30}], "duration": 6},
	&"sunder": {"name": "破甲", "modifiers": [{"stat": "armor", "op": "add", "value": -20}], "duration": 6},
}

const _LABEL := {"dmg_inc": "伤害", "extra_dmg": "额外伤害", "attack": "攻击力", "armor": "防御"}

static func has(id: StringName) -> bool:
	return DEFS.has(id)

static func display_name(id: StringName) -> String:
	return DEFS.get(id, {}).get("name", String(id))

# 生成可加入 status 列表的 buff dict(带 id)。
static func spec(id: StringName) -> Dictionary:
	if not DEFS.has(id):
		return {}
	var d: Dictionary = DEFS[id].duplicate(true)
	d["id"] = id
	return d

# 文案:中毒(每拍 −2 血, 6 拍) / 虚弱(伤害 −30%, 6 拍)。
static func describe(id: StringName) -> String:
	if not DEFS.has(id):
		return ""
	var d: Dictionary = DEFS[id]
	var dur := int(d.get("duration", 0))
	if d.has("tick"):
		return "%s(每拍 %d 血, %d 拍)" % [d["name"], int(d["tick"].get("hp", 0)), dur]
	if d.has("modifiers"):
		var parts: Array = []
		for m in d["modifiers"]:
			var unit := "%" if m["stat"] in ["dmg_inc", "extra_dmg"] else ""
			parts.append("%s %d%s" % [_LABEL.get(m["stat"], m["stat"]), int(m["value"]), unit])
		return "%s(%s, %d 拍)" % [d["name"], "、".join(parts), dur]
	return d["name"]

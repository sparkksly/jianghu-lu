class_name Buffs
extends RefCounted

# buff(增益)目录,对称 Debuffs。正向 StatusEffect:tick 回血/回气,或 modifier 临时强化。
# 招式 Move.empower 列 buff id,干净命中时 combat_sim 给「自己」挂上(越打越强/养气)。

const DEFS := {
	&"vigor": {"name": "运劲", "modifiers": [{"stat": "dmg_inc", "op": "add", "value": 20}], "duration": 3},
	&"ironbody": {"name": "铁布", "modifiers": [{"stat": "armor", "op": "add", "value": 20}], "duration": 4},
	&"focus": {"name": "凝气", "tick": {"qi": 2}, "duration": 4},
	&"mend": {"name": "疗息", "tick": {"hp": 2}, "duration": 5},
}

const _LABEL := {"dmg_inc": "伤害", "extra_dmg": "额外伤害", "attack": "攻击力", "armor": "防御", "max_qi": "气海上限"}

static func has(id: StringName) -> bool:
	return DEFS.has(id)

static func display_name(id: StringName) -> String:
	return DEFS.get(id, {}).get("name", String(id))

static func spec(id: StringName) -> Dictionary:
	if not DEFS.has(id):
		return {}
	var d: Dictionary = DEFS[id].duplicate(true)
	d["id"] = id
	return d

# 文案:运劲(伤害 +30%, 4 拍) / 凝气(每拍 +2 气, 4 拍)。
static func describe(id: StringName) -> String:
	if not DEFS.has(id):
		return ""
	var d: Dictionary = DEFS[id]
	var dur := int(d.get("duration", 0))
	if d.has("tick"):
		var t: Dictionary = d["tick"]
		var what := "气" if t.has("qi") else "血"
		var v := int(t.get("qi", t.get("hp", 0)))
		return "%s(每拍 +%d %s, %d 拍)" % [d["name"], v, what, dur]
	if d.has("modifiers"):
		var parts: Array = []
		for m in d["modifiers"]:
			var unit := "%" if m["stat"] in ["dmg_inc", "extra_dmg"] else ""
			parts.append("%s +%d%s" % [_LABEL.get(m["stat"], m["stat"]), int(m["value"]), unit])
		return "%s(%s, %d 拍)" % [d["name"], "、".join(parts), dur]
	return d["name"]

class_name StatusEffect
extends RefCounted

# buff/debuff = 数据 Dictionary:
#   {id, name, modifiers:[{stat,op,value}], tick:{hp,qi}, duration:int, scope:"tick"|"round"|"fight", stacks:int, source}
# 本 helper 操作一侧(combatant)的 buff 列表(Array of 上述 dict)。数据驱动:加新状态=加一条数据。

# 收集本侧所有 buff 对某属性的修正(给 Stats.aggregate)。
static func mods_for(list: Array, stat: String) -> Array:
	var out: Array = []
	for s in list:
		for m in s.get("modifiers", []):
			if m.get("stat", "") == stat:
				out.append(m)
	return out

# 推进一格时间:累计本格 tick 持续效果(中毒掉血等),duration−1,移除到期项(就地改 list)。
# 返回 {hp, qi}(本格 tick 合计,负=损耗),由 combat_sim 应用到 combatant。
static func advance(list: Array) -> Dictionary:
	var hp := 0
	var qi := 0
	var keep: Array = []
	for s in list:
		var t: Dictionary = s.get("tick", {})
		hp += int(t.get("hp", 0))
		qi += int(t.get("qi", 0))
		s["duration"] = int(s.get("duration", 0)) - 1
		if int(s["duration"]) > 0:
			keep.append(s)
	list.clear()
	list.append_array(keep)
	return {"hp": hp, "qi": qi}

# 加一个 buff(同 id 刷新时长/叠层,简单版:直接 append)。
static func add(list: Array, effect: Dictionary) -> void:
	list.append(effect.duplicate(true))

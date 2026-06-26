class_name Evolve
extends RefCounted

# 把招式进化加成应用到一个 Move(返回副本,不改原招)。
# e = {spd,qi,dmg,compiled};迅捷→后摇-1/级,凝气→气-1/级,沉重→伤+2/级。

static func apply(m: Move, e: Dictionary) -> Move:
	if e.is_empty():
		return m
	var r: Move = m.duplicate()
	r.recovery = maxi(0, r.recovery - int(e.get("spd", 0)))
	r.stamina_cost = maxi(0, r.stamina_cost - int(e.get("qi", 0)))
	r.damage += int(e.get("dmg", 0)) * 2
	return r

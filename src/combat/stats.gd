class_name Stats
extends RefCounted

# 属性聚合:有效值 = (base + Σadd) × Πmul。
# mods = [{stat, op:"add"|"mul", value, source?}];内功/装备/奇遇/buff 全统一成 modifier。

static func aggregate(base: int, mods: Array, stat: String) -> int:
	var add := 0
	var mul := 1.0
	for m in mods:
		if m.get("stat", "") != stat:
			continue
		match m.get("op", "add"):
			"add": add += int(m.get("value", 0))
			"mul": mul *= float(m.get("value", 1.0))
	return int(round((base + add) * mul))

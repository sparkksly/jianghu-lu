class_name Discovery
extends RefCounted

# 实战顿悟:战斗中的行为满足 triggers(全部) → chance 概率领悟该功夫。
# triggers 用本场战斗统计(fight.combat_stats):
#   tag_hits      {tag, need}  本场施展该 tag 招 ≥ need 次
#   tag_two_combo {tag}        本场用过该 tag 的两连(连招或相邻两招)
# 新触发类型只加一支 _met,不动调用方。

static func check(disc: Dictionary, stats: Dictionary, rng: RandomNumberGenerator) -> bool:
	if disc.is_empty():
		return false
	for t in disc.get("triggers", []):
		if not _met(t, stats):
			return false
	return rng.randf() < float(disc.get("chance", 0.0))

static func _met(t: Dictionary, stats: Dictionary) -> bool:
	match t.get("type", ""):
		"tag_hits":
			return int(stats.get("tag_hits", {}).get(t["tag"], 0)) >= int(t["need"])
		"tag_two_combo":
			return bool(stats.get("tag_two_combo", {}).get(t["tag"], false))
	return false

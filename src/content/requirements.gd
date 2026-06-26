class_name Requirements
extends RefCounted

# 通用领悟依赖。requires = Condition 列表(默认全部满足=AND)。
# Condition = {type, ...};新增依赖类型只需在 _eval 加一支,不动调用方。
#   art_mastery {art, need}      某门功夫熟练度 ≥ need
#   art_known   {art}            已领悟某门功夫
#   arts_count  {family, need}   已领悟该 family 的功夫 ≥ need 门(降龙"领悟多少掌")
#   mastery_sum {family, need}   该 family 已学功夫的熟练度总和 ≥ need
#   or          {any:[Condition]} 其中之一满足
# ctx = {learned: Array, mastery: Dictionary}。未知类型 → false(不误解锁)。

static func met(requires: Array, ctx: Dictionary) -> bool:
	for cond in requires:
		if not _eval(cond, ctx):
			return false
	return true

static func _eval(cond: Dictionary, ctx: Dictionary) -> bool:
	match cond.get("type", ""):
		"art_mastery":
			return int(ctx["mastery"].get(cond["art"], 0)) >= int(cond["need"])
		"art_known":
			return ctx["learned"].has(cond["art"])
		"arts_count":
			var n := 0
			for id in ctx["learned"]:
				if cond["family"] in Arts.family(id):
					n += 1
			return n >= int(cond["need"])
		"mastery_sum":
			var s := 0
			for id in ctx["learned"]:
				if cond["family"] in Arts.family(id):
					s += int(ctx["mastery"].get(id, 0))
			return s >= int(cond["need"])
		"or":
			for c in cond["any"]:
				if _eval(c, ctx):
					return true
			return false
	return false

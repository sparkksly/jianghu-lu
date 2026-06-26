class_name RunRewards
extends RefCounted

# 战后机缘:从「未领悟绝学 + 属性」里随机 3 个不重复选项。
# 返回 [{type:"combo", id}|{type:"qi"}|{type:"hp"}]。

static func roll(unlearned: Array, rng: RandomNumberGenerator) -> Array:
	var cand: Array = []
	for id in unlearned:
		cand.append({"type": "combo", "id": id})
	cand.append({"type": "qi"})
	cand.append({"type": "hp"})
	# 部分 Fisher-Yates:把前 3 个洗成随机
	var n := cand.size()
	for i in mini(3, n):
		var j := rng.randi_range(i, n - 1)
		var t = cand[i]; cand[i] = cand[j]; cand[j] = t
	var out := cand.slice(0, mini(3, n))
	# 候选不足 3(绝学学完时)用属性补满
	while out.size() < 3:
		out.append({"type": "hp"} if out.size() % 2 == 0 else {"type": "qi"})
	return out

static func label(r: Dictionary) -> String:
	match r.get("type", ""):
		"combo": return "领悟绝学 · " + Arts.display_name(r["id"])
		"qi": return "气海精进   ( +2 最大气 )"
		"hp": return "强身   ( +6 气血上限 )"
	return "?"

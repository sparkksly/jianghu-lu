class_name RunRewards
extends RefCounted

# 两种战后三选一:
#  基础提升:强身 / 打坐修炼 / 磨练招式(随机一门基础攻击招)
#  招式进化:某招熟练满 → 迅捷/凝气/沉重(绝学第2次进化可出化境单卡)

# 基础提升三选一(磨练目标 = 你已学的某招,随机)。
static func roll_basic(known_ids: Array, rng: RandomNumberGenerator) -> Array:
	var hone_id: StringName = known_ids[rng.randi_range(0, known_ids.size() - 1)] if known_ids.size() > 0 else &"jab"
	return [
		{"type": "hp"},
		{"type": "meditate"},
		{"type": "hone", "id": hone_id},
	]

# 招式进化三选一。is_art=该 id 是绝学;evo_level=已进化次数(首次=0)。
static func roll_evolution(id: StringName, evo_level: int, is_art: bool) -> Array:
	if is_art and evo_level >= 1:   # 绝学第2次进化:可化境为单卡
		return [
			{"type": "evo", "id": id, "choice": "compiled"},
			{"type": "evo", "id": id, "choice": "spd"},
			{"type": "evo", "id": id, "choice": "dmg"},
		]
	return [
		{"type": "evo", "id": id, "choice": "spd"},
		{"type": "evo", "id": id, "choice": "qi"},
		{"type": "evo", "id": id, "choice": "dmg"},
	]

static func label(r: Dictionary) -> String:
	var nm := func(id): return Loc.move_name(id)
	match r.get("type", ""):
		"hp": return "强身   ( +6 气血上限 )"
		"meditate": return "打坐修炼   ( 疗伤 + 内功+1 )"
		"hone": return "磨练招式 · " + nm.call(r["id"]) + "   ( 熟练 + 抽率↑ )"
		"evo":
			var n: String = nm.call(r["id"])
			match r["choice"]:
				"spd": return "迅捷 · " + n + "   ( 出招更快 )"
				"qi": return "凝气 · " + n + "   ( 更省气 )"
				"dmg": return "沉重 · " + n + "   ( 伤害 +2 )"
				"compiled": return "化境 · " + n + "   ( 化作一张单卡! )"
	return "?"

class_name Enemies
extends RefCounted

# 每章敌人花名册:小怪(grunt)若干 + 精英(elite)若干 + boss 一名。
# 主题化:章0 毒/野、章1 刀/血、章2 魔/影;招式池混用基础招与本章 boss 专属招(by_id 均可解析)。
# spawn 按 variant(取 node_index)选小怪/精英变体 → 一轮里每章遇到的敌人各不相同。
# 每条 {name, pool, hp?(额外血)}。hp/regen 主体按 kind+chapter 缩放。

const ROSTER := {
	0: {  # 毒蛛潭
		"grunt": [
			{"name": "山贼", "pool": [&"jab", &"hook", &"push_palm", &"snap_kick"]},
			{"name": "毒潭水鬼", "pool": [&"jab", &"rot_claw", &"snap_kick"]},
			{"name": "采花蟊贼", "pool": [&"jab", &"snap_kick", &"sweep_kick", &"dodge"]},
		],
		"elite": [
			{"name": "黑风寨主", "pool": [&"hook", &"chop_palm", &"side_kick", &"knee_strike"], "hp": 6},
			{"name": "五毒教徒", "pool": [&"venom_palm", &"rot_claw", &"push_palm"]},
		],
		"boss": {"name": "青鳞毒叟", "pool": [&"toad_power", &"venom_palm", &"rot_claw"]},
	},
	1: {  # 断魂崖
		"grunt": [
			{"name": "黑道刀客", "pool": [&"hook", &"chop_palm", &"snap_kick"]},
			{"name": "断魂崖喽啰", "pool": [&"jab", &"hook", &"side_kick"]},
			{"name": "江洋大盗", "pool": [&"push_palm", &"snap_kick", &"sweep_kick", &"grab"]},
		],
		"elite": [
			{"name": "断魂刀客", "pool": [&"blood_blade", &"chop_palm", &"side_kick"]},
			{"name": "崖匪头领", "pool": [&"hook", &"knee_strike", &"side_kick", &"chop_palm"], "hp": 8},
		],
		"boss": {"name": "血河老魔", "pool": [&"blood_blade", &"soul_reap", &"massacre"]},
	},
	2: {  # 华山之巅
		"grunt": [
			{"name": "魔教死士", "pool": [&"jab", &"knee_strike", &"snap_kick"]},
			{"name": "影卫", "pool": [&"phantom_needle", &"snap_kick", &"step_in"]},
			{"name": "魔教刀手", "pool": [&"hook", &"chop_palm", &"side_kick"]},
		],
		"elite": [
			{"name": "影卫统领", "pool": [&"phantom_needle", &"reaper_stab", &"ghost_step"]},
			{"name": "护法尊者", "pool": [&"soul_reap", &"chop_palm", &"side_kick", &"knee_strike"], "hp": 10},
		],
		"boss": {"name": "无影魔君", "pool": [&"phantom_needle", &"ghost_step", &"reaper_stab"]},
	},
}

# chapter 0-2;kind ∈ {grunt, elite, boss};variant 选小怪/精英变体(默认 0)。
# 返回 {name, hp, regen, pool, is_boss}。
static func spawn(chapter: int, kind: String, variant: int = 0) -> Dictionary:
	var ch := clampi(chapter, 0, 2)
	var base_hp := 28 + ch * 12
	var roster: Dictionary = ROSTER[ch]
	match kind:
		"boss":
			var b: Dictionary = roster["boss"]
			return {"name": b["name"], "hp": base_hp + 30, "regen": 7 + ch, "pool": b["pool"], "is_boss": true}
		"elite":
			var list: Array = roster["elite"]
			var e: Dictionary = list[variant % list.size()]
			return {"name": e["name"], "hp": base_hp + 12 + int(e.get("hp", 0)), "regen": 6 + ch,
				"pool": e["pool"], "is_boss": false}
		_:
			var list2: Array = roster["grunt"]
			var g: Dictionary = list2[variant % list2.size()]
			return {"name": g["name"], "hp": base_hp + int(g.get("hp", 0)), "regen": 5 + ch,
				"pool": g["pool"], "is_boss": false}

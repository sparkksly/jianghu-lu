class_name Enemies
extends RefCounted

# 每章的小怪/精英/boss 配置。boss 三章各一,专属招池。

static func _boss(chapter: int) -> Dictionary:
	match chapter:
		0: return {"name": "青鳞毒叟", "pool": [&"toad_power", &"venom_palm", &"rot_claw"]}
		1: return {"name": "血河老魔", "pool": [&"blood_blade", &"soul_reap", &"massacre"]}
		_: return {"name": "无影魔君", "pool": [&"phantom_needle", &"ghost_step", &"reaper_stab"]}

static func _grunt_name(ch: int) -> String:
	return ["山贼", "黑道刀客", "魔教死士"][clampi(ch, 0, 2)]

static func _elite_name(ch: int) -> String:
	return ["黑风寨主", "断魂刀客", "影卫统领"][clampi(ch, 0, 2)]

# chapter 0-2;kind ∈ {grunt, elite, boss}。返回 {name, hp, regen, pool, is_boss}。
static func spawn(chapter: int, kind: String) -> Dictionary:
	var base_hp := 28 + chapter * 12
	match kind:
		"boss":
			var b := _boss(chapter)
			return {"name": b["name"], "hp": base_hp + 30, "regen": 7 + chapter, "pool": b["pool"], "is_boss": true}
		"elite":
			return {"name": "精英·" + _elite_name(chapter), "hp": base_hp + 12, "regen": 6 + chapter,
				"pool": [&"jab", &"hook", &"push_palm", &"chop_palm", &"snap_kick", &"side_kick"], "is_boss": false}
		_:
			return {"name": _grunt_name(chapter), "hp": base_hp, "regen": 5 + chapter,
				"pool": [&"jab", &"hook", &"push_palm", &"snap_kick"], "is_boss": false}

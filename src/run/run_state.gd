class_name RunState
extends RefCounted

# A "基础 run": a fixed linear sequence of fights, player HP carried across them.
# Map / events / rewards / reputation are later slices — this is the minimal loop.

var fights_total: int
var fight_index: int   # 0-based index of the current fight
var player_hp: int
var max_hp: int

func _init(total: int = 3, hp: int = 40) -> void:
	fights_total = total
	fight_index = 0
	player_hp = hp
	max_hp = hp

func advance() -> void:
	fight_index += 1

func is_complete() -> bool:
	return fight_index >= fights_total

func label() -> String:
	return "第%d战 / 共%d战" % [min(fight_index + 1, fights_total), fights_total]

# Enemy gets tougher each fight (basic escalation 小渔村→…).
func enemy_hp() -> int:
	return 30 + fight_index * 10

func enemy_regen() -> int:
	return 5 + fight_index

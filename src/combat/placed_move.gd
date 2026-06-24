class_name PlacedMove
extends RefCounted

var move: Move
var start: int

func _init(p_move: Move = null, p_start: int = 0) -> void:
	move = p_move
	start = p_start

func end_tick() -> int:
	return start + move.total_duration()

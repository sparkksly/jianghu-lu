class_name CombatEvent
extends RefCounted

var tick: int
var type: StringName
var actor: int
var target: int
var amount: int
var move_id: StringName

func _init(p_tick := 0, p_type := &"", p_actor := 0, p_target := 0, p_amount := 0, p_move_id := &"") -> void:
	tick = p_tick
	type = p_type
	actor = p_actor
	target = p_target
	amount = p_amount
	move_id = p_move_id

func _to_string() -> String:
	return "[t%d %s a%d->t%d %d %s]" % [tick, type, actor, target, amount, move_id]

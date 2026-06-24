class_name Strike
extends Card

func apply_effect(user: Node, target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(6)

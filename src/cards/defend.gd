class_name Defend
extends Card

func apply_effect(user: Node, target: Node) -> void:
	if user.has_method("add_block"):
		user.add_block(5)

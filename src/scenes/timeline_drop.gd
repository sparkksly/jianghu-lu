extends Control
# Drop target for the plan-phase timeline. Godot calls _can_drop_data /
# _drop_data on the control under the cursor — which is THIS node (the
# Timeline), not the PlanPhase root. `at_position` here is already in this
# node's local space, so x / TICK_W is the dropped tick. We forward to the
# parent PlanPhase, which owns the Plan and the placement logic.

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("kind")

func _drop_data(at_position: Vector2, data) -> void:
	var plan := get_parent()
	if data["kind"] == "new":
		plan.try_drop_new(data["move"], at_position.x)
	elif data["kind"] == "move":
		plan.try_move_existing(data["index"], at_position.x)

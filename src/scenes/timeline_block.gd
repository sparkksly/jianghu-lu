class_name TimelineBlock
extends Button

# A timeline block is grabbed on left-press; PlanPhase then drives a live drag
# (the block follows the cursor, others slide aside). A press without movement
# is treated as a click (remove single / expand combo) by PlanPhase.
signal grabbed(unit_index)

var unit_index := -1
var is_combo := false
var move: Move

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grabbed.emit(unit_index)

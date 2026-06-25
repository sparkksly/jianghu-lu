class_name DraggableCard
extends Button

# A deck card is a PALETTE entry — it never leaves the list. Pressing it starts a
# new-move drag that PlanPhase drives with the same live animation as moving a
# block (the new block follows the cursor, others slide aside).
signal new_grabbed(move)

var move: Move

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		new_grabbed.emit(move)

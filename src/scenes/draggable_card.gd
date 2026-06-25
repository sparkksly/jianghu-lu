class_name DraggableCard
extends Button

var move: Move

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = move.move_name
	set_drag_preview(preview)
	return {"kind": "new", "move": move}

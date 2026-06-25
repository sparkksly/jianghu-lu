class_name TimelineBlock
extends Button

signal remove_requested(index: int)

var index: int
var move: Move

func _ready() -> void:
	pressed.connect(func(): remove_requested.emit(index))

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = move.move_name
	set_drag_preview(preview)
	return {"kind": "move", "index": index}

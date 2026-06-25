class_name TimelineBlock
extends Button

signal remove_requested(unit_index: int)
signal expand_requested(block)   # combo blocks expand to edit components

var unit_index := -1   # index into PlanModel.units (kept sorted)
var is_combo := false
var move: Move

func _ready() -> void:
	pressed.connect(func():
		if is_combo:
			expand_requested.emit(self)   # combo: open the component editor
		else:
			remove_requested.emit(unit_index))   # single: remove

func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_combo:
		return null  # combos are removed/expanded, not dragged
	var preview := Label.new()
	preview.text = move.move_name
	set_drag_preview(preview)
	return {"kind": "move", "index": unit_index}

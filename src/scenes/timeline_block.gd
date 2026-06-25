class_name TimelineBlock
extends Button

signal remove_requested(sorted_indices: Array)

var sorted_indices: Array = []   # which plan.sorted() entries this block covers
var is_combo := false
var move: Move

func _ready() -> void:
	pressed.connect(func(): remove_requested.emit(sorted_indices))

func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_combo:
		return null  # Step 1: combos are removed & re-placed, not dragged
	var preview := Label.new()
	preview.text = move.move_name
	set_drag_preview(preview)
	return {"kind": "move", "index": sorted_indices[0]}

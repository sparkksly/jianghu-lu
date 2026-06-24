class_name ComboRules
extends RefCounted

class Recipe:
	var slots: Array
	var result: Move
	func _init(p_slots: Array, p_result: Move) -> void:
		slots = p_slots
		result = p_result

var _recipes: Array[Recipe] = []

func add_recipe(slots: Array, result: Move) -> void:
	_recipes.append(Recipe.new(slots, result))

func _slot_matches(slot: Dictionary, move: Move) -> bool:
	if slot.has("any"):
		return true
	if slot.has("id"):
		return move.id == slot["id"]
	if slot.has("kind"):
		return move.kind == slot["kind"]
	if slot.has("tag"):
		return (slot["tag"] as StringName) in move.tags
	return false

func _matches_run(seq: Array, start_idx: int, recipe: Recipe) -> bool:
	if start_idx + recipe.slots.size() > seq.size():
		return false
	for k in recipe.slots.size():
		var pm: PlacedMove = seq[start_idx + k]
		if not _slot_matches(recipe.slots[k], pm.move):
			return false
		if k > 0:
			var prev: PlacedMove = seq[start_idx + k - 1]
			if pm.start != prev.end_tick():
				return false # must be back-to-back
	return true

func apply(plan: Plan) -> Plan:
	var seq := plan.sorted()
	var by_len := _recipes.duplicate()
	by_len.sort_custom(func(a, b): return a.slots.size() > b.slots.size())
	var out := Plan.new()
	var i := 0
	while i < seq.size():
		var fused := false
		for recipe in by_len:
			if _matches_run(seq, i, recipe):
				out.add(PlacedMove.new(recipe.result, seq[i].start))
				i += recipe.slots.size()
				fused = true
				break
		if not fused:
			out.add(seq[i])
			i += 1
	return out

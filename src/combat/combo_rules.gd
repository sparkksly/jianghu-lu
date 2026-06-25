class_name ComboRules
extends RefCounted

class Recipe:
	var slots: Array
	var result: Move
	var reg_idx: int = 0
	func _init(p_slots: Array, p_result: Move) -> void:
		slots = p_slots
		result = p_result

const COMBO_BONUS := 1.25  # synergy multiplier on the components' combined power

var _recipes: Array[Recipe] = []

# The fused move inherits its STRENGTH (damage + affixes) from the components used,
# so a 连环踢 built from 重踢 hits harder / gains 霸体 than one from 轻踢 — while the
# combo's SHAPE (duration / hit pattern) stays the recipe's template.
func _fuse_result(template: Move, seq: Array, start_idx: int, n_slots: int) -> Move:
	var r: Move = template.duplicate()
	var dmg_sum := 0
	var heavy := false
	var armor := false
	var interrupt := false
	for k in n_slots:
		var m: Move = seq[start_idx + k].move
		dmg_sum += m.damage
		heavy = heavy or m.is_heavy
		armor = armor or m.super_armor
		interrupt = interrupt or m.can_interrupt
	var hits: int = max(1, r.hit_offsets.size())
	r.damage = int(round(dmg_sum * COMBO_BONUS / hits))  # per-hit; total ≈ sum × bonus
	r.is_heavy = heavy
	r.super_armor = armor
	r.can_interrupt = interrupt
	return r

func add_recipe(slots: Array, result: Move) -> void:
	var r := Recipe.new(slots, result)
	r.reg_idx = _recipes.size()
	_recipes.append(r)

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

func recipes() -> Array:
	return _recipes

func _slot_desc(slot: Dictionary) -> String:
	if slot.has("any"): return "任意"
	if slot.has("id"): return Loc.move_name(slot["id"])
	if slot.has("kind"): return Loc.kind_name(slot["kind"])
	if slot.has("tag"): return str(slot["tag"])
	return "?"

func describe_recipes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in _recipes:
		var slots: Array[String] = []
		for s in r.slots:
			slots.append(_slot_desc(s))
		out.append({"slots": slots, "result": r.result.move_name})
	return out

func apply(plan: Plan) -> Plan:
	var out := Plan.new()
	for e in fuse_detailed(plan):
		out.add(PlacedMove.new(e["move"], e["start"]))
	return out

# Like apply(), but returns rich entries for the planning UI:
# [{move, start, sorted_indices:Array[int], is_combo:bool}], where sorted_indices
# point into plan.sorted() (the raw moves the entry consumed).
func fuse_detailed(plan: Plan) -> Array:
	var seq := plan.sorted()
	var by_len := _recipes.duplicate()
	by_len.sort_custom(func(a, b):
		if a.slots.size() != b.slots.size():
			return a.slots.size() > b.slots.size()
		return a.reg_idx < b.reg_idx)
	var out: Array = []
	var i := 0
	while i < seq.size():
		var fused := false
		for recipe in by_len:
			if _matches_run(seq, i, recipe):
				var n: int = recipe.slots.size()
				var fused_move := _fuse_result(recipe.result, seq, i, n)
				out.append({
					"move": fused_move, "start": seq[i].start,
					"sorted_indices": range(i, i + n), "is_combo": true,
				})
				i += n
				fused = true
				break
		if not fused:
			out.append({
				"move": seq[i].move, "start": seq[i].start,
				"sorted_indices": [i], "is_combo": false,
			})
			i += 1
	return out

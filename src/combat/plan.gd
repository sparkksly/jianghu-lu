class_name Plan
extends RefCounted

var moves: Array[PlacedMove] = []

func add(pm: PlacedMove) -> void:
	moves.append(pm)

func sorted() -> Array[PlacedMove]:
	var out := moves.duplicate()
	out.sort_custom(func(a, b): return a.start < b.start)
	return out

func total_cost() -> int:
	var c := 0
	for pm in moves:
		c += pm.move.stamina_cost
	return c

func is_valid(sta_max: int, n_ticks: int) -> bool:
	if total_cost() > int(floor(1.5 * sta_max)):
		return false
	var s := sorted()
	var last_end := -1
	for pm in s:
		if pm.start < 0 or pm.start >= n_ticks:
			return false
		if pm.end_tick() > n_ticks:
			return false # move would spill past the timeline grid
		if pm.start < last_end:
			return false # overlap
		last_end = pm.end_tick()
	return true

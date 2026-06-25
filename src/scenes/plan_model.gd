class_name PlanModel
extends RefCounted

# A planning timeline of UNITS. Each unit is a single move or a user-fused combo.
# Fusion is explicit (the player clicks a hint). A fused combo occupies the
# COMPRESSED (result) footprint, freeing ticks so more moves fit — that freed
# space is genuinely usable. Expanding/breaking a combo reclaims the full
# footprint and pushes later units right; anything past n_ticks is "overflow"
# (won't take effect).
#
# unit = { "moves": Array[Move], "fused": bool, "start": int }
#   single  -> moves.size()==1, fused=false
#   combo   -> moves.size()>1,  fused=true

var rules: ComboRules
var n_ticks: int
var units: Array = []

func _init(p_rules: ComboRules = null, p_n_ticks := 12) -> void:
	rules = p_rules
	n_ticks = p_n_ticks

func footprint(u: Dictionary) -> int:
	if u["fused"]:
		return rules.recipe_result(u["moves"]).total_duration()
	return (u["moves"][0] as Move).total_duration()

func display_move(u: Dictionary) -> Move:
	return rules.recipe_result(u["moves"]) if u["fused"] else u["moves"][0]

func _sort() -> void:
	units.sort_custom(func(a, b): return a["start"] < b["start"])

func _overlaps(start: int, end: int, ignore: int) -> bool:
	for i in units.size():
		if i == ignore:
			continue
		var s: int = units[i]["start"]
		var e: int = s + footprint(units[i])
		if start < e and s < end:
			return true
	return false

# --- placement (soft overflow: end may exceed n_ticks) ---
func can_place(move: Move, start: int) -> bool:
	if start < 0 or start >= n_ticks:
		return false
	return not _overlaps(start, start + move.total_duration(), -1)

func place(move: Move, start: int) -> bool:
	if not can_place(move, start):
		return false
	units.append({"moves": [move], "fused": false, "start": start})
	_sort()
	return true

func remove_at(idx: int) -> void:
	if idx >= 0 and idx < units.size():
		units.remove_at(idx)

# --- fusion (explicit) ---
# Contiguous runs of single units whose moves match a recipe -> a fuse hint.
# Returns [{ "indices": Array[int], "start": int, "result": Move }] (indices into units, which is kept sorted).
func fuse_opportunities() -> Array:
	_sort()
	var out: Array = []
	var i := 0
	while i < units.size():
		if units[i]["fused"]:
			i += 1
			continue
		# gather a maximal contiguous run of singles starting at i
		var run := [i]
		var cursor: int = units[i]["start"] + footprint(units[i])
		var j := i + 1
		while j < units.size() and not units[j]["fused"] and units[j]["start"] == cursor:
			run.append(j)
			cursor += footprint(units[j])
			j += 1
		# try the longest recipe-matching prefix of this run
		var moves: Array = []
		for k in run:
			moves.append(units[k]["moves"][0])
		for n in range(run.size(), 1, -1):
			if rules.recipe_result(moves.slice(0, n)) != null:
				out.append({
					"indices": run.slice(0, n),
					"start": units[run[0]]["start"],
					"result": rules.recipe_result(moves.slice(0, n)),
				})
				break
		i = run[-1] + 1
	return out

func fuse(indices: Array) -> bool:
	if indices.size() < 2:
		return false
	var moves: Array = []
	var start: int = units[indices[0]]["start"]
	for idx in indices:
		if units[idx]["fused"]:
			return false
		moves.append(units[idx]["moves"][0])
	if rules.recipe_result(moves) == null:
		return false
	# remove the consumed singles (descending so indices stay valid), add the combo
	var sorted_idx := indices.duplicate()
	sorted_idx.sort()
	sorted_idx.reverse()
	for idx in sorted_idx:
		units.remove_at(idx)
	units.append({"moves": moves, "fused": true, "start": start})
	_sort()
	# compression only frees space; no overlap can be created
	return true

# Remove one component from the combo at unit index `idx`. The combo re-fuses if
# the rest still match a recipe, else it breaks into singles laid out at full
# footprint, pushing later units right (overflow past n_ticks renders red).
func remove_component(idx: int, comp_index: int) -> void:
	if idx < 0 or idx >= units.size() or not units[idx]["fused"]:
		return
	var u: Dictionary = units[idx]
	var rest: Array = u["moves"].duplicate()
	if comp_index < 0 or comp_index >= rest.size():
		return
	rest.remove_at(comp_index)
	var start: int = u["start"]
	units.remove_at(idx)
	if rest.size() >= 2 and rules.recipe_result(rest) != null:
		units.append({"moves": rest, "fused": true, "start": start})
	else:
		var t := start
		for m in rest:
			units.append({"moves": [m], "fused": false, "start": t})
			t += (m as Move).total_duration()
	_sort()
	_resolve_overlaps()

# Sweep left->right; push any overlapping unit right, but never pull left (gaps kept).
func _resolve_overlaps() -> void:
	_sort()
	var cursor := -1
	for u in units:
		if u["start"] < cursor:
			u["start"] = cursor
		cursor = u["start"] + footprint(u)

# --- rendering / commit ---
func entries() -> Array:
	_sort()
	var out: Array = []
	for i in units.size():
		var u: Dictionary = units[i]
		var mv := display_move(u)
		var start: int = u["start"]
		out.append({
			"index": i,
			"move": mv,
			"start": start,
			"fused": u["fused"],
			"components": u["moves"],
			"overflow": start + mv.total_duration() > n_ticks,
		})
	return out

func effective_cost() -> int:
	var c := 0
	for u in units:
		var mv := display_move(u)
		if u["start"] + mv.total_duration() <= n_ticks:
			for m in u["moves"]:
				c += (m as Move).stamina_cost
	return c

func to_plan() -> Plan:
	_sort()
	var p := Plan.new()
	for u in units:
		var mv := display_move(u)
		if u["start"] + mv.total_duration() <= n_ticks:
			p.add(PlacedMove.new(mv, u["start"]))
	return p

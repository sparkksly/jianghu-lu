class_name CombatSim
extends RefCounted

# Stamina tuning (Task 8 references these constants).
const REWARD_HIT := 1
const REWARD_INTERRUPT := 2
const REWARD_BLOCK := 1
const PENALTY_WHIFF := 2
const PENALTY_WHIFF_HEAVY := 4
const PENALTY_STAGGER := 2

class _Actor:
	var queue: Array[PlacedMove]
	var qi := 0
	var cur: PlacedMove = null
	var elapsed := 0
	var gasp_until := -1

static func simulate(state: CombatState, plans: Array) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	var actors := [_Actor.new(), _Actor.new()]
	for i in 2:
		actors[i].queue = (plans[i] as Plan).sorted()

	var max_tick := state.n_ticks + 30  # let trailing moves finish
	var t := 0
	while t < max_tick:
		# 1. start moves due this tick
		for i in 2:
			_try_start(state, actors[i], i, t, events)
		# 2. snapshot phases for symmetric resolution
		var snap := []
		for i in 2:
			snap.append(_snapshot(actors[i]))
		# 3. resolve hits using snapshot (process by priority for tie-break)
		var order := [0, 1]
		if _hit_priority(snap[1]) > _hit_priority(snap[0]):
			order = [1, 0]
		for i in order:
			_maybe_hit(state, snap, i, t, events)
			if state.hp[0] <= 0 or state.hp[1] <= 0:
				break
		# 4. deaths
		if state.hp[0] <= 0 or state.hp[1] <= 0:
			var dead := 0 if state.hp[0] <= 0 else 1
			events.append(CombatEvent.new(t, &"death", dead, dead, 0, &""))
			break
		# 5. advance
		for i in 2:
			_advance(actors[i])
		# 6. stop early if nothing left to do
		if t >= state.n_ticks and _all_idle(actors):
			break
		t += 1
	return events

static func _try_start(state: CombatState, a: _Actor, idx: int, t: int, events) -> void:
	if a.cur != null:
		return
	if t < a.gasp_until:
		# gasping: skip any move due now (wasted)
		while a.qi < a.queue.size() and a.queue[a.qi].start <= t:
			a.qi += 1
		return
	if a.qi >= a.queue.size():
		return
	if a.queue[a.qi].start != t:
		return
	var pm: PlacedMove = a.queue[a.qi]
	if state.stamina[idx] < pm.move.stamina_cost:
		# exhaustion -> 喘息
		a.gasp_until = t + state.gasp_len
		a.qi += 1
		events.append(CombatEvent.new(t, &"exhaust", idx, idx, state.gasp_len, pm.move.id))
		return
	state.stamina[idx] -= pm.move.stamina_cost
	a.cur = pm
	a.elapsed = 0
	a.qi += 1

# snapshot = {move, phase, hitting:bool, gasping:bool}
static func _snapshot(a: _Actor) -> Dictionary:
	if a.cur == null:
		return {"move": null, "phase": &"idle", "hitting": false}
	var ph: StringName = a.cur.move.phase_at(a.elapsed)
	return {
		"move": a.cur.move,
		"phase": ph,
		"hitting": a.cur.move.is_hit_tick(a.elapsed),
	}

static func _hit_priority(snap: Dictionary) -> int:
	if snap["hitting"]:
		return (snap["move"] as Move).priority
	return -9999

static func _maybe_hit(state: CombatState, snap: Array, attacker: int, t: int, events) -> void:
	var a: Dictionary = snap[attacker]
	if not a["hitting"]:
		return
	var defender := 1 - attacker
	var d: Dictionary = snap[defender]
	_resolve_hit(state, attacker, a["move"], d["phase"], d["move"], t, events)

# Extended by later tasks (interrupt, block, dodge, throw, stamina).
static func _resolve_hit(state: CombatState, attacker: int, atk: Move, def_phase: StringName, def_move: Move, t: int, events) -> void:
	var defender := 1 - attacker
	state.hp[defender] = max(0, state.hp[defender] - atk.damage)
	events.append(CombatEvent.new(t, &"hit", attacker, defender, atk.damage, atk.id))

static func _advance(a: _Actor) -> void:
	if a.cur != null:
		a.elapsed += 1
		if a.elapsed >= a.cur.move.total_duration():
			a.cur = null
			a.elapsed = 0

static func _all_idle(actors: Array) -> bool:
	for a in actors:
		if a.cur != null or a.qi < a.queue.size():
			return false
	return true

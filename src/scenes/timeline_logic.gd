class_name TimelineLogic
extends RefCounted

static func clone_plan(plan: Plan) -> Plan:
	var p := Plan.new()
	for pm in plan.moves:
		p.add(PlacedMove.new(pm.move, pm.start))
	return p

static func without_index(plan: Plan, idx: int) -> Plan:
	var p := Plan.new()
	for i in plan.moves.size():
		if i != idx:
			p.add(PlacedMove.new(plan.moves[i].move, plan.moves[i].start))
	return p

static func with_move(plan: Plan, move: Move, start: int) -> Plan:
	var p := clone_plan(plan)
	p.add(PlacedMove.new(move, start))
	return p

static func can_place(plan: Plan, move: Move, start: int, stamina_now: int, n_ticks: int, ignore_index: int = -1, allow_overflow := false) -> bool:
	var base := plan if ignore_index < 0 else without_index(plan, ignore_index)
	var trial := with_move(base, move, start)
	return trial.is_valid(stamina_now, n_ticks, allow_overflow)

static func snap_tick(local_x: float, tick_w: float, n_ticks: int) -> int:
	return clampi(int(floor(local_x / tick_w)), 0, n_ticks - 1)

class_name CombatSim
extends RefCounted

# Stamina tuning (Task 8 references these constants).
const REWARD_HIT := 1
const REWARD_INTERRUPT := 2
const REWARD_BLOCK := 1
const PENALTY_WHIFF := 2
const PENALTY_WHIFF_HEAVY := 4
const PENALTY_STAGGER := 2
const THROW_BREAK_BONUS := 4
const GASP_DAMAGE_BONUS := 3
# 状态系统(回合内)
const LEVERAGE_WINDOW := 3      # 借力:成功格挡/闪避后的窗口拍数
const LEVERAGE_PCT := 60        # 借力:窗口内下一击增伤 %
const GUARD_REDUCTION_PCT := 50 # 护体:受伤减免 %

class _Actor:
	var queue: Array[PlacedMove]
	var qi := 0
	var cur: PlacedMove = null
	var elapsed := 0
	var gasp_until := -1
	var guard_until := -1      # 护体生效到(不含)此拍
	var leverage_until := -1   # 借力窗口到(含)此拍

static func simulate(state: CombatState, plans: Array) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	var actors := [_Actor.new(), _Actor.new()]
	for i in 2:
		actors[i].queue = (plans[i] as Plan).sorted()

	var tail := 0
	for i in 2:
		for pm in (plans[i] as Plan).sorted():
			tail = max(tail, (pm as PlacedMove).end_tick())
	var max_tick: int = max(state.n_ticks, tail) + 2
	var t := 0
	while t < max_tick:
		# 1. start moves due this tick
		for i in 2:
			_try_start(state, actors[i], i, t, events)
		# 1.5 STEP: resolve distance changes this tick (sum both, apply once)
		var ddelta := 0
		for i in 2:
			var a: _Actor = actors[i]
			if a.cur != null and a.cur.move.kind == Move.Kind.STEP and a.elapsed == a.cur.move.startup:
				ddelta += a.cur.move.distance_delta
		if ddelta != 0:
			state.distance = clampi(state.distance + ddelta, 0, 2)
			events.append(CombatEvent.new(t, &"distance", -1, -1, state.distance, &""))
		# 2. snapshot phases for symmetric resolution
		var snap := []
		for i in 2:
			snap.append(_snapshot(actors[i]))
		# 3. resolve hits using snapshot (process by priority for tie-break)
		var order := [0, 1]
		if _hit_priority(snap[1]) > _hit_priority(snap[0]):
			order = [1, 0]
		# resolve BOTH committed hits — double-KO is legitimate
		for i in order:
			_maybe_hit(state, actors, snap, i, t, events)
		# 4. deaths — check both actors; actor 0 first for determinism
		if state.hp[0] <= 0 or state.hp[1] <= 0:
			if state.hp[0] <= 0:
				events.append(CombatEvent.new(t, &"death", 0, 0, 0, &""))
			if state.hp[1] <= 0:
				events.append(CombatEvent.new(t, &"death", 1, 1, 0, &""))
			break
		# 5. advance
		for i in 2:
			_advance(actors[i])
		# 5.5 战斗内状态:持续效果(中毒掉血等) + 计时到期
		for i in 2:
			var sd := StatusEffect.advance(state.status[i])
			if int(sd["hp"]) != 0:
				state.hp[i] = clampi(state.hp[i] + int(sd["hp"]), 0, state.max_hp[i])
			if int(sd["qi"]) != 0:
				state.stamina[i] = clampi(state.stamina[i] + int(sd["qi"]), 0, state.sta_max[i])
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
	events.append(CombatEvent.new(t, &"stamina", idx, idx, -pm.move.stamina_cost, pm.move.id))
	a.cur = pm
	a.elapsed = 0
	a.qi += 1

# snapshot = {move, phase, hitting:bool}
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

static func _maybe_hit(state: CombatState, actors: Array, snap: Array, attacker: int, t: int, events) -> void:
	var a: Dictionary = snap[attacker]
	if not a["hitting"]:
		return
	if (a["move"] as Move).kind == Move.Kind.STEP:
		return  # 步法不打人
	var defender := 1 - attacker
	var d: Dictionary = snap[defender]
	_resolve_hit(state, actors, attacker, a["move"], d, t, events)

static func _add_stamina(state: CombatState, idx: int, delta: int, t: int, events) -> void:
	if delta == 0:
		return
	state.stamina[idx] = clampi(state.stamina[idx] + delta, 0, state.sta_max[idx])
	events.append(CombatEvent.new(t, &"stamina", idx, idx, delta, &""))

static func _is_gasping(actors: Array, idx: int, t: int) -> bool:
	return t < actors[idx].gasp_until

static func _apply_damage(state: CombatState, actors: Array, defender: int, base: int, t: int) -> int:
	var dmg := base
	if _is_gasping(actors, defender, t) and base > 0:
		dmg += GASP_DAMAGE_BONUS
	if t < actors[defender].guard_until and dmg > 0:   # 护体:受伤减半
		dmg = int(ceil(dmg * (100 - GUARD_REDUCTION_PCT) / 100.0))
	if dmg > 0:   # 防御力减伤(至少留 1)
		dmg = maxi(1, dmg - state.eff_defense(defender))
	state.hp[defender] = max(0, state.hp[defender] - dmg)
	return dmg

static func _resolve_hit(state: CombatState, actors: Array, attacker: int, atk: Move, d: Dictionary, t: int, events) -> void:
	if (atk.kind == Move.Kind.ATTACK or atk.kind == Move.Kind.THROW) and not atk.in_range(state.distance):
		var pen := PENALTY_WHIFF_HEAVY if atk.is_heavy else PENALTY_WHIFF
		_add_stamina(state, attacker, -pen, t, events)
		events.append(CombatEvent.new(t, &"reach", attacker, 1 - attacker, 0, atk.id))
		return
	var defender := 1 - attacker
	var def_phase: StringName = d["phase"]
	var def_move: Move = d["move"]
	var def_active_defense := def_phase == &"active" and def_move != null \
		and (def_move.kind == Move.Kind.BLOCK or def_move.kind == Move.Kind.DODGE)

	if def_active_defense and def_move.kind == Move.Kind.DODGE:
		actors[defender].leverage_until = t + LEVERAGE_WINDOW   # 闪避成功 → 借力窗口
		events.append(CombatEvent.new(t, &"leverage", defender, attacker, LEVERAGE_WINDOW, def_move.id))
		_whiff(state, attacker, atk, t, events)
		return

	if atk.kind == Move.Kind.THROW:
		if def_active_defense and def_move.kind == Move.Kind.BLOCK:
			var dmg := _apply_damage(state, actors, defender, atk.damage + THROW_BREAK_BONUS, t)
			events.append(CombatEvent.new(t, &"throw_break", attacker, defender, dmg, atk.id))
			_add_stamina(state, attacker, REWARD_HIT, t, events)
		else:
			_whiff(state, attacker, atk, t, events)
		return

	if def_active_defense and def_move.kind == Move.Kind.BLOCK:
		events.append(CombatEvent.new(t, &"block", attacker, defender, 0, atk.id))
		_add_stamina(state, defender, REWARD_BLOCK, t, events)
		actors[defender].leverage_until = t + LEVERAGE_WINDOW   # 格挡成功 → 借力窗口
		events.append(CombatEvent.new(t, &"leverage", defender, attacker, LEVERAGE_WINDOW, atk.id))
		return
	if def_phase == &"startup" and atk.can_interrupt and def_move != null and not def_move.super_armor:
		actors[defender].cur = null
		actors[defender].elapsed = 0
		var dmg := _apply_damage(state, actors, defender, atk.damage, t)
		events.append(CombatEvent.new(t, &"interrupt", attacker, defender, dmg, atk.id))
		_add_stamina(state, attacker, REWARD_INTERRUPT, t, events)
		_add_stamina(state, defender, -PENALTY_STAGGER, t, events)
		return
	var base := atk.damage
	if t <= actors[attacker].leverage_until and base > 0:   # 借力:反打增伤,消耗窗口
		base = int(ceil(base * (100 + LEVERAGE_PCT) / 100.0))
		actors[attacker].leverage_until = -1
		events.append(CombatEvent.new(t, &"leverage", attacker, defender, base, atk.id))
	if base > 0:
		base += state.eff_attack(attacker)   # 攻击力加成
	var hd := _apply_damage(state, actors, defender, base, t)
	events.append(CombatEvent.new(t, &"hit", attacker, defender, hd, atk.id))
	_add_stamina(state, attacker, REWARD_HIT, t, events)
	if atk.grants_guard > 0:                                # 护体:命中给自己挂减伤
		actors[attacker].guard_until = t + atk.grants_guard
		events.append(CombatEvent.new(t, &"guard", attacker, attacker, atk.grants_guard, atk.id))
	if atk.knockback:
		state.distance = mini(2, state.distance + 1)
		events.append(CombatEvent.new(t, &"distance", -1, -1, state.distance, &""))
	if atk.stun > 0:
		actors[defender].gasp_until = t + atk.stun
		events.append(CombatEvent.new(t, &"stun", attacker, defender, atk.stun, atk.id))

static func _whiff(state: CombatState, attacker: int, atk: Move, t: int, events) -> void:
	events.append(CombatEvent.new(t, &"whiff", attacker, 1 - attacker, 0, atk.id))
	var pen := PENALTY_WHIFF_HEAVY if atk.is_heavy else PENALTY_WHIFF
	_add_stamina(state, attacker, -pen, t, events)

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

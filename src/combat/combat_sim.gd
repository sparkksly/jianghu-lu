class_name CombatSim
extends RefCounted

# Stamina tuning (Task 8 references these constants).
const REWARD_HIT := 1
const REWARD_INTERRUPT := 2
const REWARD_BLOCK := 1
const BLOCK_COST_PER := 4   # 格挡硬扛:每 4 点招式伤害耗 1 气(重招更费气)
const PENALTY_WHIFF := 2
const PENALTY_WHIFF_HEAVY := 4
const PENALTY_STAGGER := 2
const THROW_BREAK_BONUS := 4
const GASP_DAMAGE_BONUS := 3
# 状态系统(回合内)
const LEVERAGE_WINDOW := 3      # 借力:成功格挡/闪避后的窗口拍数
const LEVERAGE_PCT := 60        # 借力:窗口内下一击增伤 %(作临时增伤)
const GUARD_REDUCTION_PCT := 50 # 护体:受伤减免 %
const ARMOR_K := 100           # 防御递减:减伤% = armor/(armor+K)
const ARMOR_CAP := 0.85        # 减伤硬上限(防无敌)
const ATTACK_REF := 10         # 攻击力基准(默认攻击10 → 招式 damage 即默认伤害,不改现有平衡)

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
	# 开战触发被动(先发制人等):战斗开始即响应
	for side in 2:
		for trig in state.triggers[side]:
			if trig.get("when", "") == "fight_start":
				_fire_trigger(state, side, trig, 0, events)
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
				state.stamina[i] = clampi(state.stamina[i] + int(sd["qi"]), 0, state.eff_sta_max(i))
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
	state.stamina[idx] = clampi(state.stamina[idx] + delta, 0, state.eff_sta_max(idx))
	events.append(CombatEvent.new(t, &"stamina", idx, idx, delta, &""))

static func _is_gasping(actors: Array, idx: int, t: int) -> bool:
	return t < actors[idx].gasp_until

# 攻击侧 outgoing:基础攻击力 × 招式% × (1+基础增伤%) × (1+额外增伤%),含借力。
# move_dmg = 招式 damage(基准攻击10 时即默认伤害)。
static func _outgoing(state: CombatState, attacker: int, move_dmg: int, leverage: bool) -> float:
	if move_dmg <= 0:
		return 0.0
	var r := float(move_dmg) * float(state.eff_attack(attacker)) / float(ATTACK_REF)
	r *= 1.0 + state.eff_dmg_inc(attacker) / 100.0
	r *= 1.0 + state.eff_extra(attacker) / 100.0
	if leverage:
		r *= 1.0 + float(LEVERAGE_PCT) / 100.0
	return r

# 防守侧:气力不继加成 → 防御递减减伤 → 护体减半。raw 来自 _outgoing。
static func _apply_damage(state: CombatState, actors: Array, defender: int, raw: float, t: int) -> int:
	var dmg := raw
	if _is_gasping(actors, defender, t) and raw > 0:
		dmg += GASP_DAMAGE_BONUS
	var arm := state.eff_armor(defender)
	var mit := minf(ARMOR_CAP, float(arm) / float(arm + ARMOR_K))
	dmg *= 1.0 - mit
	if t < actors[defender].guard_until and dmg > 0:   # 护体:受伤减半
		dmg *= float(100 - GUARD_REDUCTION_PCT) / 100.0
	var dealt := 0
	if raw > 0:
		dealt = maxi(1, int(round(dmg)))
	state.hp[defender] = max(0, state.hp[defender] - dealt)
	return dealt

static func _resolve_hit(state: CombatState, actors: Array, attacker: int, atk: Move, d: Dictionary, t: int, events) -> void:
	if (atk.kind == Move.Kind.ATTACK or atk.kind == Move.Kind.THROW) and not atk.in_range(state.distance):
		# 追身:仅「太远一格」时自动逼近一步再打(反制无脑撤步;撤够远或太近仍打不到)
		if state.distance == atk.range_max + 1:
			state.distance -= 1
			events.append(CombatEvent.new(t, &"distance", -1, -1, state.distance, &"pursue"))
		else:
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
		if not atk.pierces_dodge:
			actors[defender].leverage_until = t + LEVERAGE_WINDOW   # 闪避成功 → 借力窗口
			events.append(CombatEvent.new(t, &"leverage", defender, attacker, LEVERAGE_WINDOW, def_move.id))
			_whiff(state, attacker, atk, t, events)
			return
		# 破闪招(扫击/范围):穿透闪避照常命中 → 落到下方命中结算
		events.append(CombatEvent.new(t, &"pierce", attacker, defender, 0, atk.id))

	if atk.kind == Move.Kind.THROW:
		if def_active_defense and def_move.kind == Move.Kind.BLOCK:
			var dmg := _apply_damage(state, actors, defender, _outgoing(state, attacker, atk.damage + THROW_BREAK_BONUS, false), t)
			events.append(CombatEvent.new(t, &"throw_break", attacker, defender, dmg, atk.id))
			_add_stamina(state, attacker, REWARD_HIT, t, events)
		else:
			_whiff(state, attacker, atk, t, events)
		return

	if def_active_defense and def_move.kind == Move.Kind.BLOCK:
		# 格挡=用气硬扛:消耗气按被挡招强度(重招更费气),不再回气
		var bc := maxi(1, int(ceil(float(atk.damage) / BLOCK_COST_PER)))
		_add_stamina(state, defender, -bc, t, events)
		events.append(CombatEvent.new(t, &"block", attacker, defender, bc, atk.id))
		actors[defender].leverage_until = t + LEVERAGE_WINDOW   # 格挡成功 → 借力窗口
		events.append(CombatEvent.new(t, &"leverage", defender, attacker, LEVERAGE_WINDOW, atk.id))
		for trig in state.triggers[defender]:   # 格挡触发被动(坚壁等)
			if trig.get("when", "") == "block":
				_fire_trigger(state, defender, trig, t, events)
		return
	if def_phase == &"startup" and atk.can_interrupt and def_move != null and not def_move.super_armor:
		actors[defender].cur = null
		actors[defender].elapsed = 0
		var dmg := _apply_damage(state, actors, defender, _outgoing(state, attacker, atk.damage, false), t)
		events.append(CombatEvent.new(t, &"interrupt", attacker, defender, dmg, atk.id))
		_inflict(state, attacker, defender, atk, t, events)
		if atk.knockback:   # 打断+击退:敌人攻击作废 + 被推开 → 真正拉开距离(追身也来不及)
			state.distance = mini(2, state.distance + 1)
			events.append(CombatEvent.new(t, &"distance", -1, -1, state.distance, &""))
		_add_stamina(state, attacker, REWARD_INTERRUPT, t, events)
		_add_stamina(state, defender, -PENALTY_STAGGER, t, events)
		return
	var lev: bool = t <= actors[attacker].leverage_until and atk.damage > 0
	if lev:   # 借力:反打增伤,消耗窗口
		actors[attacker].leverage_until = -1
		events.append(CombatEvent.new(t, &"leverage", attacker, defender, atk.damage, atk.id))
	var hd := _apply_damage(state, actors, defender, _outgoing(state, attacker, atk.damage, lev), t)
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
	_inflict(state, attacker, defender, atk, t, events)
	_empower(state, attacker, atk, t, events)

# 干净命中/打断后,把招式 inflict 的 debuff 加到防守方状态(中毒/流血/虚弱/破甲)。
static func _inflict(state: CombatState, attacker: int, defender: int, atk: Move, t: int, events) -> void:
	for did in atk.inflict:
		var sp := Debuffs.spec(did)
		if sp.is_empty():
			continue
		StatusEffect.add(state.status[defender], sp)
		events.append(CombatEvent.new(t, &"debuff", attacker, defender, 0, did))

# 触发型被动响应:执行 trigger 的 do(挂 buff / 回气)。
static func _fire_trigger(state: CombatState, side: int, trig: Dictionary, t: int, events) -> void:
	var do: Dictionary = trig.get("do", {})
	if do.has("buff"):
		var sp := Buffs.spec(do["buff"])
		if not sp.is_empty():
			StatusEffect.add(state.status[side], sp)
			events.append(CombatEvent.new(t, &"buff", side, side, 0, do["buff"]))
	if do.has("qi"):
		state.stamina[side] = clampi(state.stamina[side] + int(do["qi"]), 0, state.eff_sta_max(side))
		events.append(CombatEvent.new(t, &"stamina", side, side, int(do["qi"]), &""))

# 干净命中后,把招式 empower 的 buff 加到「自己」(运劲/铁布/凝气/疗息)。
static func _empower(state: CombatState, attacker: int, atk: Move, t: int, events) -> void:
	for bid in atk.empower:
		var sp := Buffs.spec(bid)
		if sp.is_empty():
			continue
		StatusEffect.add(state.status[attacker], sp)
		events.append(CombatEvent.new(t, &"buff", attacker, attacker, 0, bid))

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

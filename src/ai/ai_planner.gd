class_name AiPlanner
extends RefCounted

var _rng := RandomNumberGenerator.new()

func _init(seed: int) -> void:
	_rng.seed = seed

func plan(deck: Array[Move], stamina_now: int, n_ticks: int, start_distance := 1) -> Plan:
	var p := Plan.new()
	var budget := stamina_now  # plan within what you actually have; no self-gasp
	var spent := 0
	var t := 0
	var dist := start_distance
	var guard := 0
	# 攻击招子集:AI 大概率选攻击(避免一直走位/防御不打人)
	var attacks: Array[Move] = []
	for dm in deck:
		if dm.kind == Move.Kind.ATTACK or dm.kind == Move.Kind.THROW:
			attacks.append(dm)
	while t < n_ticks and guard < 60:
		guard += 1
		var m: Move
		if not attacks.is_empty() and _rng.randf() < 0.85:
			m = attacks[_rng.randi_range(0, attacks.size() - 1)]   # 85% 攻击
		else:
			m = deck[_rng.randi_range(0, deck.size() - 1)]
		if spent + m.stamina_cost > budget:
			break
		if t + m.total_duration() > n_ticks:
			t += 1
			continue
		# 攻击若够不着 → 不空挥,改成「逼近/拉开」的步法,把距离调到能打
		if (m.kind == Move.Kind.ATTACK or m.kind == Move.Kind.THROW) and not m.in_range(dist):
			var step := _closer_step(deck, m, dist)
			if step != null and spent + step.stamina_cost <= budget and t + step.total_duration() <= n_ticks:
				dist = clampi(dist + step.distance_delta, 0, 2)
				p.add(PlacedMove.new(step, t))
				spent += step.stamina_cost
				t += step.total_duration()
			continue
		if m.kind == Move.Kind.STEP:
			dist = clampi(dist + m.distance_delta, 0, 2)
		p.add(PlacedMove.new(m, t))
		spent += m.stamina_cost
		t += m.total_duration()
	return p

# 找一个能把当前距离推向「打得到」的步法:太远→上步(delta<0),太近→撤步(delta>0)。
func _closer_step(deck: Array[Move], m: Move, dist: int) -> Move:
	var want := 0
	if dist > m.range_max:
		want = -1
	elif dist < m.range_min:
		want = 1
	if want == 0:
		return null
	for s in deck:
		if s.kind == Move.Kind.STEP and signi(s.distance_delta) == want:
			return s
	return null

# 敌人意图(绑拍号):[{name, start, dur}],让玩家能算时机对位。reveal_count 外显示"？"。
func intent(plan: Plan, reveal_count: int) -> Array:
	var out: Array = []
	var s := plan.sorted()
	for i in s.size():
		var pm: PlacedMove = s[i]
		var hits: Array = []   # 实际命中拍(绝对):前摇后的命中拍才打人
		if pm.move.kind == Move.Kind.ATTACK or pm.move.kind == Move.Kind.THROW:
			for off in pm.move.hit_offsets:
				hits.append(pm.start + pm.move.startup + off)
		out.append({
			"name": pm.move.move_name if i < reveal_count else "？",
			"start": pm.start,
			"dur": pm.move.total_duration(),
			"hits": hits,
		})
	return out

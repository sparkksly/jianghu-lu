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
	while t < n_ticks and guard < 60:
		guard += 1
		var m: Move = deck[_rng.randi_range(0, deck.size() - 1)]
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

func intent(plan: Plan, reveal_count: int) -> Array[String]:
	var out: Array[String] = []
	var s := plan.sorted()
	for i in s.size():
		out.append(s[i].move.move_name if i < reveal_count else "？")
	return out

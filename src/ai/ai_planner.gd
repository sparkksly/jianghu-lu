class_name AiPlanner
extends RefCounted

var _rng := RandomNumberGenerator.new()

func _init(seed: int) -> void:
	_rng.seed = seed

func plan(deck: Array[Move], stamina_now: int, n_ticks: int) -> Plan:
	var p := Plan.new()
	var budget := stamina_now  # plan within what you actually have; no self-gasp
	var spent := 0
	var t := 0
	var guard := 0
	while t < n_ticks and guard < 50:
		guard += 1
		var m: Move = deck[_rng.randi_range(0, deck.size() - 1)]
		if spent + m.stamina_cost > budget:
			break
		if t + m.total_duration() > n_ticks:
			t += 1
			continue
		p.add(PlacedMove.new(m, t))
		spent += m.stamina_cost
		t += m.total_duration()
	return p

func intent(plan: Plan, reveal_count: int) -> Array[String]:
	var out: Array[String] = []
	var s := plan.sorted()
	for i in s.size():
		out.append(s[i].move.move_name if i < reveal_count else "？")
	return out

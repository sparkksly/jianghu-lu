extends Control

signal finished

@onready var _p0h: ProgressBar = $P0Health
@onready var _p1h: ProgressBar = $P1Health
@onready var _p0s: ProgressBar = $P0Stamina
@onready var _p1s: ProgressBar = $P1Stamina
@onready var _tick: Label = $TickLabel
@onready var _log: VBoxContainer = $EventLog

var _events: Array = []
var _state: CombatState
var _t := 0
var _max_t := 0
var _accum := 0.0
const STEP := 0.35  # seconds per tick

func play(state_before: CombatState, _plans: Array, events: Array) -> void:
	_state = state_before.clone()
	_events = events
	_p0h.max_value = _state.max_hp[0]; _p0h.value = _state.hp[0]
	_p1h.max_value = _state.max_hp[1]; _p1h.value = _state.hp[1]
	_p0s.max_value = _state.sta_max[0]; _p0s.value = _state.stamina[0]
	_p1s.max_value = _state.sta_max[1]; _p1s.value = _state.stamina[1]
	_t = 0
	_accum = 0.0
	_max_t = 0
	for e in _events:
		_max_t = max(_max_t, e.tick)
	set_process(true)

func _process(delta: float) -> void:
	_accum += delta
	if _accum < STEP:
		return
	_accum -= STEP
	_tick.text = "tick %d" % _t
	for e in _events:
		if e.tick == _t:
			_apply_event(e)
	_t += 1
	if _t > _max_t + 1:
		set_process(false)
		finished.emit()

func _apply_event(e) -> void:
	match e.type:
		&"hit", &"interrupt", &"throw_break":
			if e.target == 0: _p0h.value = max(0, _p0h.value - e.amount)
			else: _p1h.value = max(0, _p1h.value - e.amount)
		&"stamina":
			if e.actor == 0: _p0s.value = clampf(_p0s.value + e.amount, 0, _p0s.max_value)
			else: _p1s.value = clampf(_p1s.value + e.amount, 0, _p1s.max_value)
	var line := Label.new()
	line.text = "t%d P%d %s %s" % [e.tick, e.actor, str(e.type), str(e.move_id)]
	_log.add_child(line)
	if _log.get_child_count() > 8:
		_log.get_child(0).queue_free()

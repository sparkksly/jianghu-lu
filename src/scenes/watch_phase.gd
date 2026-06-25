extends Control

signal finished

@onready var _p0h: ProgressBar = $P0Health
@onready var _p1h: ProgressBar = $P1Health
@onready var _p0hr: ProgressBar = $P0HealthRed
@onready var _p1hr: ProgressBar = $P1HealthRed
@onready var _p0s: ProgressBar = $P0Stamina
@onready var _p1s: ProgressBar = $P1Stamina
@onready var _p0hl: Label = $P0HPLabel
@onready var _p1hl: Label = $P1HPLabel
@onready var _p0sl: Label = $P0StaLabel
@onready var _p1sl: Label = $P1StaLabel
@onready var _tick: Label = $TickLabel
@onready var _log: VBoxContainer = $EventLog
@onready var _float: Control = $FloatingLayer

var _events: Array = []
var _state: CombatState
var _t := 0
var _max_t := 0
var _accum := 0.0
const STEP := 0.35
const RED_DRAIN := 6.0  # red bar units drained per second

func play(state_before: CombatState, _plans: Array, events: Array) -> void:
	_state = state_before.clone()
	_events = events
	# Mixed array: [green_bar, red_bar, hp_label, player_idx]
	var bars: Array = [[_p0h, _p0hr, _p0hl, 0], [_p1h, _p1hr, _p1hl, 1]]
	for bar in bars:
		var idx: int = bar[3]
		bar[0].max_value = _state.max_hp[idx]; bar[0].value = _state.hp[idx]
		bar[1].max_value = _state.max_hp[idx]; bar[1].value = _state.hp[idx]
	_p0s.max_value = _state.sta_max[0]; _p0s.value = _state.stamina[0]
	_p1s.max_value = _state.sta_max[1]; _p1s.value = _state.stamina[1]
	_update_labels()
	_t = 0; _accum = 0.0; _max_t = 0
	for e in _events:
		_max_t = max(_max_t, e.tick)
	set_process(true)

func _update_labels() -> void:
	_p0hl.text = "%d/%d" % [int(_p0h.value), int(_p0h.max_value)]
	_p1hl.text = "%d/%d" % [int(_p1h.value), int(_p1h.max_value)]
	_p0sl.text = "体力 %d/%d" % [int(_p0s.value), int(_p0s.max_value)]
	_p1sl.text = "体力 %d/%d" % [int(_p1s.value), int(_p1s.max_value)]

func _process(delta: float) -> void:
	# red bars drain toward the green value (chip-damage effect)
	var pairs: Array = [[_p0hr, _p0h], [_p1hr, _p1h]]
	for pair in pairs:
		if pair[0].value > pair[1].value:
			pair[0].value = max(pair[1].value, pair[0].value - RED_DRAIN * delta)
	_accum += delta
	if _accum < STEP:
		return
	_accum -= STEP
	_tick.text = "第%d拍" % _t
	for e in _events:
		if e.tick == _t:
			_apply_event(e)
	_update_labels()
	_t += 1
	if _t > _max_t + 1:
		set_process(false)
		finished.emit()

func _apply_event(e) -> void:
	match e.type:
		&"hit", &"interrupt", &"throw_break":
			var gh: ProgressBar = _p0h if e.target == 0 else _p1h
			gh.value = max(0, gh.value - e.amount)  # green drops instantly; red trails
			_spawn_float(e.target, Loc.floating_text(e))
			if Loc.is_combo_result(e.move_id):
				_spawn_float(e.actor, Loc.move_name(e.move_id) + "!")
		&"stamina":
			var sb: ProgressBar = _p0s if e.actor == 0 else _p1s
			sb.value = clampf(sb.value + e.amount, 0, sb.max_value)
		&"block":
			_spawn_float(e.actor, "格挡 回体力")
		&"whiff":
			_spawn_float(e.actor, "用力过猛")     # attacker
			_spawn_float(1 - e.actor, "闪避!")     # defender dodged
		&"exhaust":
			_spawn_float(e.actor, "气力不继!")
	var line := Label.new()
	line.text = Loc.log_line(e)
	_log.add_child(line)
	if _log.get_child_count() > 8:
		_log.get_child(0).queue_free()

func _spawn_float(side: int, text: String) -> void:
	if text == "":
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(80 if side == 0 else 360, 120)
	_float.add_child(lbl)
	var tw := create_tween()
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - 40, 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

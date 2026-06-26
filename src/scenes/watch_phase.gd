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
@onready var _dist: Label = $DistanceLabel
@onready var _timeline: Control = $CombatTimeline
@onready var _float: Control = $FloatingLayer
@onready var _log: VBoxContainer = $LogPanel/Scroll/EventLog
@onready var _log_panel: Panel = $LogPanel
@onready var _log_button: Button = $LogButton

const N_CELLS := 12
const CELL_W := 40.0
const BAR_W := N_CELLS * CELL_W      # 480
const LANE0_Y := 0.0                 # 我方 marker lane (top, vertical names)
const BAR_Y := 50.0
const BAR_H := 18.0
const LANE1_Y := 70.0                # 对手 marker lane (bottom, vertical names)
const TL_H := 116.0
# Damage/heal numbers float at where each fighter roughly stands.
const CHAR_X := [300.0, 840.0]       # 我方 偏左 / 对手 偏右
const CHAR_Y := 300.0

var _events: Array = []
var _state: CombatState
var _t := 0
var _max_t := 0
var _accum := 0.0
var _playhead: ColorRect
const STEP := 0.6     # seconds per tick (slower so the fight is readable)
const RED_DRAIN := 6.0  # red bar units drained per second

func _ready() -> void:
	if not _log_button.pressed.is_connected(_toggle_log):
		_log_button.pressed.connect(_toggle_log)

func _toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible
	_log_button.text = "战报 ▾" if _log_panel.visible else "战报 ▸"

# Sync the bars to a state WITHOUT animating (used between rounds so the
# health bars are always visible while the player is planning).
func show_state(state: CombatState) -> void:
	set_process(false)
	var bars: Array = [[_p0h, _p0hr, _p0hl, 0], [_p1h, _p1hr, _p1hl, 1]]
	for bar in bars:
		var idx: int = bar[3]
		bar[0].max_value = state.max_hp[idx]; bar[0].value = state.hp[idx]
		bar[1].max_value = state.max_hp[idx]; bar[1].value = state.hp[idx]
	_p0s.max_value = state.sta_max[0]; _p0s.value = state.stamina[0]
	_p1s.max_value = state.sta_max[1]; _p1s.value = state.stamina[1]
	_dist.text = "距离 " + CombatFeed.distance_label(state.distance)
	_update_labels()

func play(state_before: CombatState, _plans: Array, events: Array) -> void:
	_state = state_before.clone()
	_events = events
	var bars: Array = [[_p0h, _p0hr, _p0hl, 0], [_p1h, _p1hr, _p1hl, 1]]
	for bar in bars:
		var idx: int = bar[3]
		bar[0].max_value = _state.max_hp[idx]; bar[0].value = _state.hp[idx]
		bar[1].max_value = _state.max_hp[idx]; bar[1].value = _state.hp[idx]
	_p0s.max_value = _state.sta_max[0]; _p0s.value = _state.stamina[0]
	_p1s.max_value = _state.sta_max[1]; _p1s.value = _state.stamina[1]
	_dist.text = "距离 " + CombatFeed.distance_label(_state.distance)
	_update_labels()
	_build_timeline()
	_t = 0; _accum = 0.0; _max_t = 0
	for e in _events:
		_max_t = max(_max_t, e.tick)
	set_process(true)

func _build_timeline() -> void:
	for c in _timeline.get_children():
		c.queue_free()
	# grid cells for the bar row
	for i in N_CELLS:
		var cell := ColorRect.new()
		cell.color = Color(0.15, 0.15, 0.18)
		cell.position = Vector2(i * CELL_W + 1, BAR_Y)
		cell.size = Vector2(CELL_W - 2, BAR_H)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_timeline.add_child(cell)
	# playhead sweeps left -> right across the whole height
	_playhead = ColorRect.new()
	_playhead.color = Color(1, 1, 0.4, 0.9)
	_playhead.position = Vector2(0, 0)
	_playhead.size = Vector2(3, TL_H)
	_playhead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timeline.add_child(_playhead)

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
	# sweep the playhead smoothly across the bar
	if _playhead:
		var prog := clampf((float(_t) + _accum / STEP) / float(N_CELLS), 0.0, 1.0)
		_playhead.position.x = prog * BAR_W
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
		&"distance":
			_dist.text = "距离 " + CombatFeed.distance_label(e.amount)
		&"reach":
			_spawn_number(e.actor, "够不着", Color(0.8, 0.8, 0.85), false)
		&"hit", &"interrupt", &"throw_break":
			var gh: ProgressBar = _p0h if e.target == 0 else _p1h
			gh.value = max(0, gh.value - e.amount)  # green drops instantly; red trails
		&"stamina":
			var sb: ProgressBar = _p0s if e.actor == 0 else _p1s
			sb.value = clampf(sb.value + e.amount, 0, sb.max_value)
	# floating number at the character's position (red dmg / green heal, crit bigger)
	var num := CombatFeed.float_number(e)
	if not num.is_empty():
		_spawn_number(num["side"], num["text"], num["color"], num["big"])
	# per-tick marker in the actor's lane on the timeline
	var mk := CombatFeed.marker(e)
	if not mk.is_empty():
		_spawn_marker(e.tick, mk["lane"], mk["text"], mk["tone"])
	# full text goes to the tucked-away 战报 log
	var line := Label.new()
	line.text = Loc.log_line(e)
	_log.add_child(line)
	if _log.get_child_count() > 40:
		_log.get_child(0).queue_free()

func _spawn_number(side: int, text: String, color: Color, big: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 60 if big else 30)
	var base_x: float = CHAR_X[side]
	lbl.position = Vector2(base_x + randf_range(-18, 18), CHAR_Y + randf_range(-12, 12))
	_float.add_child(lbl)
	var tw := create_tween()
	if big:
		# 爆击：夸张地弹一下再回落
		lbl.scale = Vector2(1.6, 1.6)
		tw.parallel().tween_property(lbl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var rise := 60.0 if big else 40.0
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - rise, 1.3)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.6)
	tw.tween_callback(lbl.queue_free)

func _spawn_marker(tick: int, lane: int, text: String, tone: String) -> void:
	var lbl := Label.new()
	lbl.text = _vertical(text)   # 招式名竖排，适配窄格
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", CombatFeed.tone_color(tone))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(tick * CELL_W + 2, LANE0_Y if lane == 0 else LANE1_Y)
	lbl.size = Vector2(CELL_W - 4, 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timeline.add_child(lbl)

func _vertical(text: String) -> String:
	var out := ""
	for i in text.length():
		out += text[i]
		if i < text.length() - 1:
			out += "\n"
	return out

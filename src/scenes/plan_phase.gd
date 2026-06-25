extends Control

signal plan_committed(plan)

@onready var _deck_row: HBoxContainer = $DeckRow
@onready var _timeline: HBoxContainer = $Timeline
@onready var _stamina: Label = $StaminaLabel
@onready var _combo: Label = $ComboPreview
@onready var _intent: Label = $EnemyIntent
@onready var _commit: Button = $CommitButton

var _deck: Array[Move] = []
var _rules: ComboRules
var _sta_max := 10
var _n_ticks := 10
var _selected: Move = null
var _plan := Plan.new()

func setup(deck: Array[Move], rules: ComboRules, sta_max: int, n_ticks: int, enemy_intent: Array) -> void:
	_deck = deck; _rules = rules; _sta_max = sta_max; _n_ticks = n_ticks
	_plan = Plan.new()
	_intent.text = "对手意图: " + ", ".join(enemy_intent.map(func(x): return str(x)))
	_build_deck()
	_build_timeline()
	_refresh()
	if not _commit.pressed.is_connected(_on_commit):
		_commit.pressed.connect(_on_commit)

func _build_deck() -> void:
	for c in _deck_row.get_children(): c.queue_free()
	for m in _deck:
		var b := Button.new()
		b.text = "%s(%d)" % [m.move_name, m.stamina_cost]
		b.pressed.connect(func(): _selected = m; _refresh())
		_deck_row.add_child(b)

func _build_timeline() -> void:
	for c in _timeline.get_children(): c.queue_free()
	for i in _n_ticks:
		var b := Button.new()
		b.text = str(i)
		b.custom_minimum_size = Vector2(34, 34)
		b.pressed.connect(_on_slot.bind(i))
		_timeline.add_child(b)

func _on_slot(tick: int) -> void:
	if _selected == null:
		return
	var trial := _clone_plan()
	trial.add(PlacedMove.new(_selected, tick))
	if trial.is_valid(_sta_max, _n_ticks):
		_plan = trial
	_refresh()

func _clone_plan() -> Plan:
	var p := Plan.new()
	for pm in _plan.moves:
		p.add(PlacedMove.new(pm.move, pm.start))
	return p

func _refresh() -> void:
	# reset all timeline button tints
	for b in _timeline.get_children():
		(b as Button).modulate = Color(1, 1, 1, 1)

	_stamina.text = "体力 %d / %d (可超额至 %d)" % [_plan.total_cost(), _sta_max, int(floor(1.5 * _sta_max))]
	var fused := _rules.apply(_plan)
	_combo.text = "连招预览: " + ", ".join(fused.moves.map(func(pm): return pm.move.move_name))
	# mark occupied ticks
	for pm in _plan.moves:
		for k in pm.move.total_duration():
			var idx := pm.start + k
			if idx < _timeline.get_child_count():
				(_timeline.get_child(idx) as Button).modulate = Color(1, 0.7, 0.4)

func _on_commit() -> void:
	plan_committed.emit(_rules.apply(_plan))

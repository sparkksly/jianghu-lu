extends Control

signal plan_committed(plan)

const TICK_W := 40.0

@onready var _deck_row: HBoxContainer = $DeckRow
@onready var _timeline: Control = $Timeline
@onready var _stamina: Label = $StaminaLabel
@onready var _combo: Label = $ComboPreview
@onready var _intent: Label = $EnemyIntent
@onready var _commit: Button = $CommitButton

var _deck: Array[Move] = []
var _rules: ComboRules
var _sta_max := 10
var _n_ticks := 14
var _plan := Plan.new()

func setup(deck: Array[Move], rules: ComboRules, sta_max: int, n_ticks: int, enemy_intent: Array) -> void:
	_deck = deck; _rules = rules; _sta_max = sta_max; _n_ticks = n_ticks
	_plan = Plan.new()
	_intent.text = "对手意图: " + ", ".join(enemy_intent)
	_build_deck()
	_redraw_timeline()
	_refresh_labels()
	if not _commit.pressed.is_connected(_on_commit):
		_commit.pressed.connect(_on_commit)

func _build_deck() -> void:
	for c in _deck_row.get_children(): c.queue_free()
	for m in _deck:
		var b := DraggableCard.new()
		b.move = m
		b.text = "%s(%d)" % [m.move_name, m.stamina_cost]
		_deck_row.add_child(b)

func _redraw_timeline() -> void:
	for c in _timeline.get_children(): c.queue_free()
	_timeline.custom_minimum_size = Vector2(_n_ticks * TICK_W, 44)
	# grid cells (visual only)
	for i in _n_ticks:
		var cell := ColorRect.new()
		cell.color = Color(0.15, 0.15, 0.18)
		cell.position = Vector2(i * TICK_W + 1, 1)
		cell.size = Vector2(TICK_W - 2, 42)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_timeline.add_child(cell)
	# placed move blocks
	var s := _plan.sorted()
	for i in s.size():
		var pm: PlacedMove = s[i]
		var blk := TimelineBlock.new()
		blk.index = i
		blk.move = pm.move
		blk.text = pm.move.move_name
		blk.position = Vector2(pm.start * TICK_W, 2)
		blk.custom_minimum_size = Vector2(pm.move.total_duration() * TICK_W - 2, 40)
		blk.size = blk.custom_minimum_size
		blk.modulate = Color(1, 0.7, 0.4)
		blk.remove_requested.connect(remove_at)
		_timeline.add_child(blk)

func _refresh_labels() -> void:
	_stamina.text = "体力 %d / %d (可超额至 %d)" % [_plan.total_cost(), _sta_max, int(floor(1.5 * _sta_max))]
	var fused := _rules.apply(_plan)
	_combo.text = "连招预览: " + ", ".join(fused.moves.map(func(pm): return pm.move.move_name))

# ---- testable drop entry points ----
func try_drop_new(move: Move, local_x: float) -> bool:
	var tick := TimelineLogic.snap_tick(local_x, TICK_W, _n_ticks)
	if TimelineLogic.can_place(_plan, move, tick, _sta_max, _n_ticks):
		_plan = TimelineLogic.with_move(_plan, move, tick)
		_redraw_timeline(); _refresh_labels()
		return true
	return false

func try_move_existing(index: int, local_x: float) -> bool:
	var s := _plan.sorted()
	if index < 0 or index >= s.size(): return false
	var pm: PlacedMove = s[index]
	var tick := TimelineLogic.snap_tick(local_x, TICK_W, _n_ticks)
	var raw := _raw_index(pm)
	if TimelineLogic.can_place(_plan, pm.move, tick, _sta_max, _n_ticks, raw):
		var without := TimelineLogic.without_index(_plan, raw)
		_plan = TimelineLogic.with_move(without, pm.move, tick)
		_redraw_timeline(); _refresh_labels()
		return true
	return false

func _raw_index(pm: PlacedMove) -> int:
	for i in _plan.moves.size():
		if _plan.moves[i] == pm:
			return i
	return -1

func remove_at(sorted_index: int) -> void:
	var s := _plan.sorted()
	if sorted_index < 0 or sorted_index >= s.size(): return
	var raw := _raw_index(s[sorted_index])
	_plan = TimelineLogic.without_index(_plan, raw)
	_redraw_timeline(); _refresh_labels()

# ---- Godot drag-and-drop: root is the drop target ----
func _can_drop_data(_at: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("kind")

func _drop_data(_at: Vector2, data) -> void:
	var local_x: float = _timeline.get_local_mouse_position().x
	if data["kind"] == "new":
		try_drop_new(data["move"], local_x)
	elif data["kind"] == "move":
		try_move_existing(data["index"], local_x)

func _on_commit() -> void:
	plan_committed.emit(_rules.apply(_plan))

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
var _stamina_now := 10
var _sta_max := 10
var _n_ticks := 12
var _model: PlanModel
var _popup: Control = null

func setup(deck: Array[Move], rules: ComboRules, stamina_now: int, sta_max: int, n_ticks: int, enemy_intent: Array) -> void:
	_deck = deck; _rules = rules; _stamina_now = stamina_now; _sta_max = sta_max; _n_ticks = n_ticks
	_model = PlanModel.new(rules, n_ticks)
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
		b.text = "%s\n%d拍 · %d气" % [m.move_name, m.total_duration(), m.stamina_cost]
		_deck_row.add_child(b)

func _redraw_timeline() -> void:
	_close_popup()
	for c in _timeline.get_children(): c.queue_free()
	_timeline.custom_minimum_size = Vector2(_n_ticks * TICK_W, 44)
	for i in _n_ticks:
		var cell := ColorRect.new()
		cell.color = Color(0.15, 0.15, 0.18)
		cell.position = Vector2(i * TICK_W + 1, 1)
		cell.size = Vector2(TICK_W - 2, 42)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_timeline.add_child(cell)
	for e in _model.entries():
		var mv: Move = e["move"]
		var start: int = e["start"]
		var dur := mv.total_duration()
		var blk := TimelineBlock.new()
		blk.unit_index = e["index"]
		blk.is_combo = e["fused"]
		blk.move = mv
		blk.text = ("✦" + mv.move_name) if e["fused"] else mv.move_name
		blk.position = Vector2(start * TICK_W, 2)
		blk.custom_minimum_size = Vector2(dur * TICK_W - 2, 40)
		blk.size = blk.custom_minimum_size
		if e["overflow"]:
			blk.modulate = Color(1, 0.3, 0.3)     # 红：超出上限，不生效
		elif e["fused"]:
			blk.modulate = Color(1, 0.85, 0.3)     # 金：连招
		else:
			blk.modulate = Color(1, 0.7, 0.4)
		blk.remove_requested.connect(remove_at)
		blk.expand_requested.connect(_on_block_expand)
		_timeline.add_child(blk)
	_draw_fuse_hints()

# A clickable hint floats above any contiguous run of singles that can fuse.
func _draw_fuse_hints() -> void:
	for op in _model.fuse_opportunities():
		var hint := Button.new()
		hint.text = "✦融合：%s" % op["result"].move_name
		hint.modulate = Color(1, 0.9, 0.4)
		hint.position = Vector2(op["start"] * TICK_W, -26)
		hint.pressed.connect(_do_fuse.bind(op["indices"]))
		_timeline.add_child(hint)

func _do_fuse(indices: Array) -> void:
	_model.fuse(indices)
	_redraw_timeline(); _refresh_labels()

func _refresh_labels() -> void:
	_stamina.text = "气 %d/%d  已排%d (可超至%d)" % [_stamina_now, _sta_max, _model.effective_cost(), _stamina_now + Plan.OVERCOMMIT_BUFFER]
	var names: Array = []
	for e in _model.entries():
		if not e["overflow"]:
			names.append(e["move"].move_name)
	_combo.text = "连招预览: " + ", ".join(names)

# ---- testable drop entry points ----
func try_drop_new(move: Move, local_x: float) -> bool:
	var tick := TimelineLogic.snap_tick(local_x, TICK_W, _n_ticks)
	if _model.place(move, tick):
		_redraw_timeline(); _refresh_labels()
		return true
	return false

func try_move_existing(unit_index: int, local_x: float) -> bool:
	var tick := TimelineLogic.snap_tick(local_x, TICK_W, _n_ticks)
	if _model.move_unit(unit_index, tick):   # works for singles AND combos
		_redraw_timeline(); _refresh_labels()
		return true
	return false

func remove_at(unit_index: int) -> void:
	_model.remove_at(unit_index)
	_redraw_timeline(); _refresh_labels()

# Click a combo block -> popup listing its components, each removable.
func _on_block_expand(block) -> void:
	_close_popup()
	var ui: int = block.unit_index
	if ui < 0 or ui >= _model.units.size(): return
	var comps: Array = _model.units[ui]["moves"]
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "连招组件（点×移除）"
	vbox.add_child(title)
	for ci in comps.size():
		var b := Button.new()
		b.text = "✕ " + (comps[ci] as Move).move_name
		b.pressed.connect(_on_remove_component.bind(ui, ci))
		vbox.add_child(b)
	add_child(panel)
	panel.position = block.global_position - global_position + Vector2(0, -8.0 - comps.size() * 36.0)
	_popup = panel

func _on_remove_component(unit_index: int, comp_index: int) -> void:
	_model.remove_component(unit_index, comp_index)
	_redraw_timeline(); _refresh_labels()

func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null

func _on_commit() -> void:
	plan_committed.emit(_model.to_plan())

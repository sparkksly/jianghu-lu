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
var _n_ticks := 10
var _plan := Plan.new()
var _popup: Control = null

func setup(deck: Array[Move], rules: ComboRules, stamina_now: int, sta_max: int, n_ticks: int, enemy_intent: Array) -> void:
	_deck = deck; _rules = rules; _stamina_now = stamina_now; _sta_max = sta_max; _n_ticks = n_ticks
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
		# Show the move's full footprint in 拍 (startup+active+recovery) AND its 气 cost,
		# so players can plan combos. The 拍 number is the timeline length it occupies.
		b.text = "%s\n%d拍 · %d气" % [m.move_name, m.total_duration(), m.stamina_cost]
		_deck_row.add_child(b)

func _redraw_timeline() -> void:
	_close_popup()
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
	# Show the FUSED view: combos appear as one compressed block (matching what
	# combat actually runs). Overflow past the grid is allowed but marked red.
	for e in _rules.fuse_detailed(_plan):
		var mv: Move = e["move"]
		var start: int = e["start"]
		var dur := mv.total_duration()
		var overflow := start + dur > _n_ticks
		var blk := TimelineBlock.new()
		blk.sorted_indices = e["sorted_indices"]
		blk.is_combo = e["is_combo"]
		blk.move = mv
		blk.text = ("✦" + mv.move_name) if e["is_combo"] else mv.move_name
		blk.position = Vector2(start * TICK_W, 2)
		blk.custom_minimum_size = Vector2(dur * TICK_W - 2, 40)
		blk.size = blk.custom_minimum_size
		if overflow:
			blk.modulate = Color(1, 0.3, 0.3)    # 红：超出上限，不生效
		elif e["is_combo"]:
			blk.modulate = Color(1, 0.85, 0.3)    # 金：连招
		else:
			blk.modulate = Color(1, 0.7, 0.4)
		blk.remove_requested.connect(_on_block_remove)
		blk.expand_requested.connect(_on_block_expand)
		_timeline.add_child(blk)

func _refresh_labels() -> void:
	_stamina.text = "气 %d/%d  已排%d (可超至%d)" % [_stamina_now, _sta_max, _effective_cost(), _stamina_now + Plan.OVERCOMMIT_BUFFER]
	var fused := _rules.apply(_plan)
	_combo.text = "连招预览: " + ", ".join(fused.moves.map(func(pm): return pm.move.move_name))

# ---- testable drop entry points ----
func try_drop_new(move: Move, local_x: float) -> bool:
	var tick := TimelineLogic.snap_tick(local_x, TICK_W, _n_ticks)
	# soft limit: allow placing past the grid (it renders red / won't take effect)
	if TimelineLogic.can_place(_plan, move, tick, _stamina_now, _n_ticks, -1, true):
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
	if TimelineLogic.can_place(_plan, pm.move, tick, _stamina_now, _n_ticks, raw, true):
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
	_on_block_remove([sorted_index])

# Remove every raw move a block covers (a combo block removes all its components).
func _on_block_remove(sorted_indices: Array) -> void:
	var s := _plan.sorted()
	var doomed: Array[PlacedMove] = []
	for si in sorted_indices:
		if si >= 0 and si < s.size():
			doomed.append(s[si])
	var p := Plan.new()
	for pm in _plan.moves:
		if pm not in doomed:
			p.add(PlacedMove.new(pm.move, pm.start))
	_plan = p
	_redraw_timeline(); _refresh_labels()

# 气 only counts moves that actually take effect — overflow (red) moves don't.
func _effective_cost() -> int:
	var s := _plan.sorted()
	var c := 0
	for e in _rules.fuse_detailed(_plan):
		var mv: Move = e["move"]
		if e["start"] + mv.total_duration() <= _n_ticks:
			for si in e["sorted_indices"]:
				c += s[si].move.stamina_cost
	return c

# Click a combo block -> popup listing its components, each removable.
func _on_block_expand(block) -> void:
	_close_popup()
	var s := _plan.sorted()
	var comps: Array[PlacedMove] = []
	for si in block.sorted_indices:
		if si >= 0 and si < s.size():
			comps.append(s[si])
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "连招组件（点×移除）"
	vbox.add_child(title)
	for pm in comps:
		var b := Button.new()
		b.text = "✕ " + pm.move.move_name
		b.pressed.connect(_remove_move.bind(pm))
		vbox.add_child(b)
	add_child(panel)
	# position the popup just above the clicked block
	panel.position = block.global_position - global_position + Vector2(0, -8.0 - comps.size() * 36.0)
	_popup = panel

func _remove_move(pm: PlacedMove) -> void:
	var p := Plan.new()
	for m in _plan.moves:
		if m != pm:
			p.add(PlacedMove.new(m.move, m.start))
	_plan = p
	_redraw_timeline(); _refresh_labels()

func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null

# Drag-and-drop is handled by the Timeline node itself (src/scenes/timeline_drop.gd),
# which is the control under the cursor when dropping; it forwards to
# try_drop_new / try_move_existing here.

func _on_commit() -> void:
	# Drop anything that spills past the grid — those red moves don't take effect.
	var fused := _rules.apply(_plan)
	var p := Plan.new()
	for pm in fused.moves:
		if pm.end_tick() <= _n_ticks:
			p.add(pm)
	plan_committed.emit(p)

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

# live-drag state
var _blocks := {}          # unit_index -> TimelineBlock
var _hints: Array = []
var _drag_idx := -1
var _dragging := false
var _moved := false
var _is_new := false       # dragging a brand-new move out of the deck
var _grab_off := 0.0       # cursor-to-block offset (timeline-local x)
var _origin_x := 0.0       # block x at grab (for click-vs-drag)
var _targets := {}         # unit_index -> target x
var _pending_move: Move = null   # deck card pressed, awaiting drag threshold
var _new_press := false

func setup(deck: Array[Move], rules: ComboRules, stamina_now: int, sta_max: int, n_ticks: int, enemy_intent: Array) -> void:
	_deck = deck; _rules = rules; _stamina_now = stamina_now; _sta_max = sta_max; _n_ticks = n_ticks
	_model = PlanModel.new(rules, n_ticks)
	_intent.text = "对手意图: " + ", ".join(enemy_intent)
	_build_deck()
	_redraw_timeline()
	_refresh_labels()
	if not _commit.pressed.is_connected(_on_commit):
		_commit.pressed.connect(_on_commit)

# 手牌区:工具牌(非 ATTACK)全渲染(无限);进攻牌(ATTACK)按「手牌张数 − 已排」渲染剩余。
func _build_deck() -> void:
	for c in _deck_row.get_children():
		_deck_row.remove_child(c)   # 立即脱离(queue_free 是延迟的,child_count 会失真)
		c.queue_free()
	var to_skip := _placed_attack_counts()   # id -> 还要隐藏的张数(已排)
	for m in _deck:
		if m.kind == Move.Kind.ATTACK and to_skip.get(m.id, 0) > 0:
			to_skip[m.id] -= 1
			continue
		_add_card(m)

func _add_card(m: Move) -> void:
	var b := DraggableCard.new()
	b.move = m
	var tail := ""
	if m.kind == Move.Kind.STEP:
		tail = "进" if m.distance_delta < 0 else "退"
	else:
		# 紧凑距离带(贴/中/远),让 11 张手牌挤进一行
		tail = "%s-%s" % [CombatFeed.distance_label(m.range_min).substr(0, 1), CombatFeed.distance_label(m.range_max).substr(0, 1)]
	b.text = "%s\n%d拍·%d气·%s" % [m.move_name, m.total_duration(), m.stamina_cost, tail]
	b.custom_minimum_size = Vector2(88, 52)   # 5 工具 + 6 进攻 = 11 张都落在屏内一行
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 13)
	b.new_grabbed.connect(_on_new_grabbed)
	_deck_row.add_child(b)

# 已放置的进攻招张数(含连招组件),按 id 计。
func _placed_attack_counts() -> Dictionary:
	var c := {}
	for u in _model.units:
		for mv in u["moves"]:
			if (mv as Move).kind == Move.Kind.ATTACK:
				c[mv.id] = c.get(mv.id, 0) + 1
	return c

# 手牌里该进攻招还剩几张可排(手牌张数 − 已排)。
func available_attack_count(id: StringName) -> int:
	var hand_n := 0
	for m in _deck:
		if m.id == id and m.kind == Move.Kind.ATTACK:
			hand_n += 1
	return hand_n - _placed_attack_counts().get(id, 0)

# 任何 model 改动后:重建手牌区(消耗/退回生效) + 重画时间轴 + 刷新标签。
func _refresh() -> void:
	_build_deck(); _redraw_timeline(); _refresh_labels()

func _redraw_timeline() -> void:
	_close_popup()
	_blocks = {}
	_hints = []
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
		blk.grabbed.connect(_on_block_grabbed)
		_timeline.add_child(blk)
		_blocks[e["index"]] = blk
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
		_hints.append(hint)

func _clear_hints() -> void:
	for h in _hints:
		if is_instance_valid(h): h.queue_free()
	_hints = []

# ---- live drag: block follows the cursor, others slide aside ----
func _on_block_grabbed(unit_index: int) -> void:
	if not _blocks.has(unit_index): return
	_drag_idx = unit_index
	_is_new = false
	_dragging = true
	_moved = false
	_close_popup()
	_clear_hints()
	var blk: Control = _blocks[unit_index]
	blk.z_index = 1
	_origin_x = blk.position.x
	_grab_off = _timeline.get_local_mouse_position().x - blk.position.x
	_targets.clear()
	set_process(true)

func _on_new_grabbed(move: Move) -> void:
	_pending_move = move
	_new_press = true

func _begin_new_drag() -> void:
	if _pending_move == null: return
	var tick := clampi(int(round(_timeline.get_local_mouse_position().x / TICK_W)), 0, _n_ticks - 1)
	_drag_idx = _model.add_unit(_pending_move, tick)
	_grab_off = _model.footprint(_model.units[_drag_idx]) * TICK_W / 2.0   # center under cursor
	_pending_move = null
	_new_press = false
	_is_new = true
	_dragging = true
	_moved = true
	_close_popup()
	_redraw_timeline()
	if _blocks.has(_drag_idx):
		_blocks[_drag_idx].z_index = 1
	set_process(true)
	_update_drag()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _dragging:
			_finish_drag()
		_new_press = false
		_pending_move = null
		return
	if event is InputEventMouseMotion:
		if _new_press and not _dragging and absf(event.relative.x) + absf(event.relative.y) > 4.0:
			_begin_new_drag()
		elif _dragging:
			_update_drag()

func _update_drag() -> void:
	var desired_x: float = _timeline.get_local_mouse_position().x - _grab_off
	if absf(desired_x - _origin_x) > 6.0:
		_moved = true
	var tick := clampi(int(round(desired_x / TICK_W)), 0, _n_ticks - 1)
	for it in _model.preview_layout(_drag_idx, tick):
		_targets[it["i"]] = desired_x if it["i"] == _drag_idx else float(it["start"]) * TICK_W

func _process(delta: float) -> void:
	if not _dragging: return
	var t := clampf(delta * 18.0, 0.0, 1.0)
	for ui in _blocks:
		var blk: Control = _blocks[ui]
		var tx: float = _targets.get(ui, blk.position.x)
		if ui == _drag_idx:
			blk.position.x = tx                         # 1:1 follow the cursor
		else:
			blk.position.x = lerpf(blk.position.x, tx, t)   # others ease into place

func _finish_drag() -> void:
	var dragged := _drag_idx
	var was_new := _is_new
	var moved := _moved
	_dragging = false
	_drag_idx = -1
	_is_new = false
	set_process(false)
	var over := _timeline.get_global_rect().grow(48.0).has_point(get_global_mouse_position())
	if was_new and not over:
		_model.remove_at(dragged)   # dropped outside the timeline -> cancel new move
		_refresh()
		return
	if moved:
		var tick := clampi(int(round((_timeline.get_local_mouse_position().x - _grab_off) / TICK_W)), 0, _n_ticks - 1)
		_model.apply_layout(_model.preview_layout(dragged, tick))
		_refresh()
	else:
		var blk = _blocks.get(dragged)   # press without movement == a click
		if blk and blk.is_combo:
			_on_block_expand(blk)
		else:
			remove_at(dragged)

func _do_fuse(indices: Array) -> void:
	_model.fuse(indices)
	_refresh()

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
		_refresh()
		return true
	return false

func try_move_existing(unit_index: int, local_x: float) -> bool:
	var tick := TimelineLogic.snap_tick(local_x, TICK_W, _n_ticks)
	if _model.move_unit(unit_index, tick):   # works for singles AND combos
		_refresh()
		return true
	return false

func remove_at(unit_index: int) -> void:
	_model.remove_at(unit_index)
	_refresh()

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
	_refresh()

func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null

func _on_commit() -> void:
	plan_committed.emit(_model.to_plan())

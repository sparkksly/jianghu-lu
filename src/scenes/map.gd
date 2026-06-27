extends Control

# 分支节点地图 + 连线拓扑可视化。视野受限:只显示本程(可走候选)与下程(可达节点),再之后迷雾。
# 节点绝对定位两行;_draw 画本程→下程的连线(选这条路能通向下程哪些)。点本程节点 → choose(slot)。

signal choose(slot)

const ICON := {"grunt": "⚔", "encounter": "※", "shop": "✦", "elite": "❖", "boss": "☠"}
const NAME := {"grunt": "小怪", "encounter": "奇遇", "shop": "集市", "elite": "精英", "boss": "首领"}

const NEAR_Y := 230.0
const FAR_Y := 400.0
const NODE := Vector2(150, 60)
const SPACING := 200.0
const MID_X := 576.0

var _run = null
var _choices: Array = []   # [{slot,type,edges}]
var _next: Array = []      # [{slot,type}]
var _near_pos: Dictionary = {}   # slot → center
var _far_pos: Dictionary = {}    # slot → center

func setup(run) -> void:
	_run = run
	_choices = run.map_choices()
	_next = run.map_next_nodes()
	$FarLabel.visible = not _next.is_empty()
	_build()
	queue_redraw()

func _centers(count: int, y: float) -> Array:
	var out: Array = []
	for i in count:
		out.append(Vector2(MID_X + (i - (count - 1) / 2.0) * SPACING, y))
	return out

func _build() -> void:
	$Title.text = _run.chapter_title()
	for c in get_children():
		if c is Button:
			c.queue_free()
	_near_pos.clear()
	_far_pos.clear()

	var nc := _centers(_choices.size(), NEAR_Y)
	for i in _choices.size():
		var ch: Dictionary = _choices[i]
		_near_pos[int(ch["slot"])] = nc[i]
		_add_node(nc[i], ch["type"], true, int(ch["slot"]))

	var fc := _centers(_next.size(), FAR_Y)
	for i in _next.size():
		var nx: Dictionary = _next[i]
		_far_pos[int(nx["slot"])] = fc[i]
		_add_node(fc[i], nx["type"], false, -1)

func _add_node(center: Vector2, typ: String, clickable: bool, slot: int) -> void:
	var b := Button.new()
	b.custom_minimum_size = NODE
	b.size = NODE
	b.position = center - NODE * 0.5
	b.text = "%s %s" % [ICON.get(typ, "·"), NAME.get(typ, typ)]
	if clickable:
		b.modulate = Color(1.0, 0.95, 0.5)
		b.pressed.connect(_on_pick.bind(slot))
	else:
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.35)
	add_child(b)

# 画本程→下程的连线:每个本程节点连到它出边指向的、且下程可见的节点。
func _draw() -> void:
	for ch in _choices:
		var from: Vector2 = _near_pos.get(int(ch["slot"]), Vector2.ZERO)
		for e in ch["edges"]:
			if _far_pos.has(int(e)):
				var to: Vector2 = _far_pos[int(e)]
				draw_line(from + Vector2(0, NODE.y * 0.5), to - Vector2(0, NODE.y * 0.5),
					Color(1, 0.9, 0.5, 0.35), 2.0)

func _on_pick(slot: int) -> void:
	choose.emit(slot)

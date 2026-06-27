extends Control

# 分支节点地图。视野受限:只显示「本程」(当前层候选,可点择路)与「下程」(下一层候选,预览淡显)。
# 再之后是迷雾,看不到。点本程某候选 → choose(idx) → 进入该节点。

signal choose(idx)

const ICON := {"grunt": "⚔", "encounter": "※", "shop": "✦", "elite": "❖", "boss": "☠"}
const NAME := {"grunt": "小怪", "encounter": "奇遇", "shop": "集市", "elite": "精英", "boss": "首领"}

var _run = null

func setup(run) -> void:
	_run = run
	_build()

func _build() -> void:
	$VBox/Title.text = _run.chapter_title()
	var rows := $VBox/Rows
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()

	rows.add_child(_label("本程 · 择路"))
	rows.add_child(_row(_run.current_layer(), true))

	var ni: int = _run.node_index
	if ni + 1 < _run.layers.size():
		rows.add_child(_label("下程 · 隐约可见"))
		rows.add_child(_row(_run.layers[ni + 1], false))
	else:
		rows.add_child(_label("下程 · 重雾锁路，前路未明"))

func _label(text: String) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = Color(1, 1, 1, 0.55)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = text
	return l

func _row(cands: Array, clickable: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in cands.size():
		var typ: String = cands[i]["type"]
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 70)
		b.text = "%s %s" % [ICON.get(typ, "·"), NAME.get(typ, typ)]
		if clickable:
			b.modulate = Color(1.0, 0.95, 0.5)
			b.pressed.connect(_on_pick.bind(i))
		else:
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.35)   # 下程:隐约
		row.add_child(b)
	return row

func _on_pick(idx: int) -> void:
	choose.emit(idx)

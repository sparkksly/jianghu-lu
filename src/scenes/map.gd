extends Control

# 节点地图:整局路径可视化(3章×5节点)。当前节点高亮可点→advance;已过打勾,未到淡显。
# 线性路径(无分支);点亮处=当前,点击进入该节点。

signal advance

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
	var per: int = RunState.NODE_SEQ.size()
	for ch in RunState.CHAPTERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		for i in per:
			row.add_child(_cell(ch * per + i, RunState.NODE_SEQ[i]))
		rows.add_child(row)

func _cell(idx: int, typ: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(132, 64)
	var done: bool = idx < _run.node_index
	var here: bool = idx == _run.node_index
	b.text = "%s%s %s" % ["✓ " if done else "", ICON.get(typ, "·"), NAME.get(typ, typ)]
	if here:
		b.modulate = Color(1.0, 0.95, 0.5)   # 高亮当前
		b.pressed.connect(func(): advance.emit())
	else:
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.8 if done else 0.4)
	return b

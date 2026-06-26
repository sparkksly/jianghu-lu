extends Control

const RUN_PATH := "res://src/scenes/run.tscn"

var _menpai: StringName = &"shaolin"
var _neigong: StringName = &"yijinjing"
var _picked: Array = []   # 选中的起手招(最多 2)

func _ready() -> void:
	_build_menpai()
	_build_neigong()
	_build_moves()
	$VBox/StartButton.pressed.connect(_start)
	_refresh_start()

func _build_menpai() -> void:
	var grp := ButtonGroup.new()
	for id in [&"shaolin", &"wudang"]:
		var b := Button.new()
		b.toggle_mode = true; b.button_group = grp
		b.custom_minimum_size = Vector2(150, 48)
		b.text = Menpai.display_name(id)
		b.toggled.connect(func(on): if on: _menpai = id)
		if id == _menpai: b.button_pressed = true
		$VBox/MenpaiRow.add_child(b)

func _build_neigong() -> void:
	var grp := ButtonGroup.new()
	var desc := {&"yijinjing": "易筋经·壮血", &"liangyi": "两仪心法·养气", &"luohanqi": "罗汉伏气·均衡"}
	for id in Neigong.all():
		var b := Button.new()
		b.toggle_mode = true; b.button_group = grp
		b.custom_minimum_size = Vector2(180, 48)
		b.text = desc[id]
		b.toggled.connect(func(on): if on: _neigong = id)
		if id == _neigong: b.button_pressed = true
		$VBox/NeigongRow.add_child(b)

func _build_moves() -> void:
	for m in Deck.basic_attacks():
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(120, 44)
		b.text = m.move_name
		b.toggled.connect(_on_move_toggled.bind(m.id, b))
		$VBox/MovesGrid.add_child(b)

func _on_move_toggled(on: bool, id: StringName, b: Button) -> void:
	if on:
		if _picked.size() >= 2:
			b.button_pressed = false   # 最多两门
			return
		_picked.append(id)
	else:
		_picked.erase(id)
	_refresh_start()

func _refresh_start() -> void:
	$VBox/StartButton.disabled = _picked.size() != 2
	$VBox/StartButton.text = "入江湖" if _picked.size() == 2 else "请选两门起手招 (%d/2)" % _picked.size()

func _start() -> void:
	RunState.pending_menpai = _menpai
	RunState.pending_neigong = _neigong
	RunState.pending_moves = _picked.duplicate()
	get_tree().change_scene_to_file(RUN_PATH)

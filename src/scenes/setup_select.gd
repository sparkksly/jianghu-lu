extends Control

const RUN_PATH := "res://src/scenes/run.tscn"

var _menpai: StringName = &"shaolin"
var _neigong: StringName = &"yijinjing"
var _picked: Array = []   # 选中的初级功夫(最多 2)

func _ready() -> void:
	_build_menpai()
	_build_neigong()
	$VBox/StartButton.pressed.connect(_start)
	_rebuild_arts()

func _build_menpai() -> void:
	var grp := ButtonGroup.new()
	for id in [&"shaolin", &"wudang"]:
		var b := Button.new()
		b.toggle_mode = true; b.button_group = grp
		b.custom_minimum_size = Vector2(150, 48)
		b.text = Menpai.display_name(id)
		b.toggled.connect(func(on): if on: _menpai = id; _rebuild_arts())
		if id == _menpai: b.button_pressed = true
		$VBox/MenpaiRow.add_child(b)

func _build_neigong() -> void:
	# 三选一:每局从 10 门内功随机抽 3 门(roguelike 随机性)。
	var grp := ButtonGroup.new()
	var pool: Array = Neigong.all().duplicate()
	pool.shuffle()
	var picks: Array = pool.slice(0, 3)
	_neigong = picks[0]
	for id in picks:
		var b := Button.new()
		b.toggle_mode = true; b.button_group = grp
		b.custom_minimum_size = Vector2(170, 48)
		b.text = "%s\n%d血 %d气" % [Neigong.display_name(id), Neigong.hp_per_level(id), Neigong.qi_per_level(id)]
		b.toggled.connect(func(on): if on: _neigong = id)
		if id == _neigong: b.button_pressed = true
		$VBox/NeigongRow.add_child(b)

# 按当前门派的 4 门初级功夫重建选项。
func _rebuild_arts() -> void:
	_picked.clear()
	for c in $VBox/MovesGrid.get_children():
		$VBox/MovesGrid.remove_child(c); c.queue_free()
	for id in Menpai.starter_pool(_menpai):
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(160, 48)
		b.text = Arts.display_name(id)
		b.toggled.connect(_on_art_toggled.bind(id, b))
		$VBox/MovesGrid.add_child(b)
	_refresh_start()

func _on_art_toggled(on: bool, id: StringName, b: Button) -> void:
	if on:
		if _picked.size() >= 2:
			b.button_pressed = false
			return
		_picked.append(id)
	else:
		_picked.erase(id)
	_refresh_start()

func _refresh_start() -> void:
	$VBox/StartButton.disabled = _picked.size() != 2
	$VBox/StartButton.text = "入江湖" if _picked.size() == 2 else "请选两门初级功夫 (%d/2)" % _picked.size()

func _start() -> void:
	RunState.pending_menpai = _menpai
	RunState.pending_neigong = _neigong
	RunState.pending_arts = _picked.duplicate()
	get_tree().change_scene_to_file(RUN_PATH)

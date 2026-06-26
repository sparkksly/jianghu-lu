extends Control

const RUN_PATH := "res://src/scenes/run.tscn"

@onready var _shaolin: Button = $VBox/ShaolinButton
@onready var _wudang: Button = $VBox/WudangButton

func _ready() -> void:
	_shaolin.pressed.connect(_pick.bind(&"shaolin"))
	_wudang.pressed.connect(_pick.bind(&"wudang"))

func _pick(id: StringName) -> void:
	RunState.pending_menpai = id
	get_tree().change_scene_to_file(RUN_PATH)

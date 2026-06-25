extends Control

const RUN_PATH := "res://src/scenes/run.tscn"

@onready var _start: Button = $VBox/StartButton
@onready var _load: Button = $VBox/LoadButton
@onready var _quit: Button = $VBox/QuitButton

func _ready() -> void:
	_load.disabled = true  # 存档系统待 run 进度成型后开放（后续切片）
	_start.pressed.connect(_on_start)
	_quit.pressed.connect(func(): get_tree().quit())

func _on_start() -> void:
	get_tree().change_scene_to_file(RUN_PATH)

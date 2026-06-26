extends Node

# Basic linear run: a sequence of fights, player HP carried across them.
# Map / events / rewards / reputation are later slices.

const FIGHT := preload("res://src/scenes/fight.tscn")
const MENU_PATH := "res://src/scenes/main_menu.tscn"

@onready var _banner: Control = $BannerLayer/Banner
@onready var _banner_label: Label = $BannerLayer/Banner/Label

var _run: RunState
var _fight: Node
var _ended := false

func _ready() -> void:
	_run = RunState.new(3, 40, RunState.pending_menpai)
	_start_fight()

func _start_fight() -> void:
	_show_banner(_run.label())
	await get_tree().create_timer(1.1).timeout
	if _fight:
		_fight.queue_free()
	_fight = FIGHT.instantiate()
	_fight.configure(_run.player_hp, _run.max_hp, _run.enemy_hp(), _run.enemy_regen(), 1000 + _run.fight_index, _run.menpai_id)
	_fight.fight_finished.connect(_on_fight_finished)
	add_child(_fight)
	_hide_banner()

func _on_fight_finished(player_won: bool) -> void:
	if not player_won:
		_end_run("败北... 江湖路断")
		return
	_run.player_hp = _fight.get_player_hp()
	_run.advance()
	if _run.is_complete():
		_end_run("通关! 华山扬名\n气血余 %d" % _run.player_hp)
	else:
		_start_fight()

func _end_run(text: String) -> void:
	_ended = true
	_show_banner(text + "\n\n按任意键返回主菜单")

func _unhandled_input(event: InputEvent) -> void:
	if not _ended:
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		get_tree().change_scene_to_file(MENU_PATH)

func _show_banner(text: String) -> void:
	_banner_label.text = text
	_banner.visible = true

func _hide_banner() -> void:
	_banner.visible = false

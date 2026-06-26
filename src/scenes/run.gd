extends Node

# Basic linear run: a sequence of fights, player HP carried across them.
# Map / events / rewards / reputation are later slices.

const FIGHT := preload("res://src/scenes/fight.tscn")
const REWARD := preload("res://src/scenes/reward_select.tscn")
const MENU_PATH := "res://src/scenes/main_menu.tscn"

@onready var _banner: Control = $BannerLayer/Banner
@onready var _banner_label: Label = $BannerLayer/Banner/Label

var _run: RunState
var _fight: Node
var _ended := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_run = RunState.new(3, 40, RunState.pending_menpai)
	_rng.seed = 2024
	_start_fight()

func _start_fight() -> void:
	_show_banner(_run.label())
	await get_tree().create_timer(1.1).timeout
	if _fight:
		_fight.queue_free()
	_fight = FIGHT.instantiate()
	_fight.configure(_run.player_hp, _run.max_hp, _run.enemy_hp(), _run.enemy_regen(), 1000 + _run.fight_index, _run.menpai_id, _run.learned, _run.qi_bonus(), _run.evo, _run.weight, _run.compiled_arts())
	_fight.fight_finished.connect(_on_fight_finished)
	add_child(_fight)
	_hide_banner()

func _on_fight_finished(player_won: bool) -> void:
	if not player_won:
		_end_run("败北... 江湖路断")
		return
	_run.player_hp = _fight.get_player_hp()
	_run.gain_mastery(_fight.moves_landed())   # 实战熟练
	_run.advance()
	if _run.is_complete():
		_end_run("通关! 华山扬名\n气血余 %d" % _run.player_hp)
	else:
		_post_fight()

# 战后:先逐个招式进化(若有),再基础提升三选一,再下一场。
func _post_fight() -> void:
	var pend: Array = _run.pending_evolutions()
	if pend.size() > 0:
		_show_evolution(pend[0])
	else:
		_show_basic()

func _show_evolution(id: StringName) -> void:
	var rs = REWARD.instantiate()
	add_child(rs)
	var is_art := not Arts.recipe(id).is_empty()
	rs.setup(RunRewards.roll_evolution(id, _run.evo_level(id), is_art), "招式进化 · " + Loc.move_name(id))
	rs.chosen.connect(func(r):
		_run.apply_evolution(r["id"], r["choice"])
		rs.queue_free()
		_post_fight())   # 可能还有下一个待进化

func _show_basic() -> void:
	var rs = REWARD.instantiate()
	add_child(rs)
	rs.setup(RunRewards.roll_basic(_rng))
	rs.chosen.connect(func(r):
		_apply_basic(r)
		rs.queue_free()
		_start_fight())

func _apply_basic(r: Dictionary) -> void:
	_run.apply_reward(r)
	# 磨练招式:几率"顿悟"领悟一个未学绝学
	if r.get("type", "") == "hone" and _rng.randf() < 0.35:
		var unlearned: Array = []
		for id in Menpai.learnable(_run.menpai_id):
			if not _run.learned.has(id):
				unlearned.append(id)
		if unlearned.size() > 0:
			_run.learn(unlearned[_rng.randi_range(0, unlearned.size() - 1)])

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

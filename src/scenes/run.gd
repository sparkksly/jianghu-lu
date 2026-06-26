extends Node

# 一局 run:三章节点序列(小怪→奇遇→精英→boss),按节点类型分发。

const FIGHT := preload("res://src/scenes/fight.tscn")
const REWARD := preload("res://src/scenes/reward_select.tscn")
const ENCOUNTER := preload("res://src/scenes/encounter.tscn")
const MENU_PATH := "res://src/scenes/main_menu.tscn"

@onready var _banner: Control = $BannerLayer/Banner
@onready var _banner_label: Label = $BannerLayer/Banner/Label

var _run: RunState
var _fight: Node
var _ended := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_run = RunState.new(RunState.pending_menpai, RunState.pending_neigong, RunState.pending_arts)
	_rng.seed = 2024
	_next_node()

func _next_node() -> void:
	if _run.is_complete():
		_end_run("通关! 华山论剑扬名立万\n气血余 %d" % _run.player_hp)
		return
	var n := _run.current_node()
	_show_banner(_run.chapter_title() + "\n" + _node_label(n))
	await get_tree().create_timer(1.2).timeout
	_hide_banner()
	if n["type"] == "encounter":
		_show_encounter()
	else:
		_start_fight()

func _node_label(n: Dictionary) -> String:
	match n["type"]:
		"encounter": return "※ 江湖奇遇"
		"elite": return "⚔ 精英"
		"boss": return "☠  B O S S"
		_: return "· 寻常对手"

# --- 战斗 ---
func _start_fight() -> void:
	if _fight:
		_fight.queue_free()
	_fight = FIGHT.instantiate()
	_fight.configure(_build_cfg())
	_fight.fight_finished.connect(_on_fight_finished)
	add_child(_fight)

func _build_cfg() -> Dictionary:
	return {
		"player_hp": _run.player_hp,
		"player_max_hp": _run.max_hp,
		"seed": 1000 + _run.node_index,
		"menpai": _run.menpai_id,
		"learned": _run.learned,
		"qi_bonus": _run.qi_bonus(),
		"evo": _run.evo,
		"weight": _run.weight,
		"compiled": _run.compiled_arts(),
		"weapon_bonus": _run.weapon_bonus,
		"enemy": _run.current_enemy(),
	}

func _on_fight_finished(player_won: bool) -> void:
	if not player_won:
		_end_run("败北... 江湖路断")
		return
	_run.player_hp = _fight.get_player_hp()
	_run.gain_mastery(_fight.moves_landed())   # 实战熟练
	var got := _discover()                     # 实战顿悟(无影脚等)
	_run.advance_node()
	if got.size() > 0:
		_show_banner("顿悟！\n习得 " + "、".join(got))
		await get_tree().create_timer(1.8).timeout
		_hide_banner()
	_post_fight()

# 实战顿悟:本场行为满足 discovery 条件 → 概率领悟(无影脚等)。
func _discover() -> Array:
	var stats: Dictionary = _fight.combat_stats()
	var got: Array = []
	for id in Menpai.learnable(_run.menpai_id):
		# 实战顿悟:有 insight 途径 + 满足门槛(无影脚需先会连环踢)
		if not _run.learned.has(id) and Arts.has_source(id, "insight") and Arts.can_learn(id, _run.learned, _run.mastery):
			if Discovery.check(Arts.source_via(id, "insight"), stats, _rng):
				_run.learn(id)
				got.append(Arts.display_name(id))
	return got

# 战后:逐个招式进化 → 基础提升三选一 → 下一节点。
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
		_post_fight())

func _show_basic() -> void:
	var rs = REWARD.instantiate()
	add_child(rs)
	rs.setup(RunRewards.roll_basic(_rng))
	rs.chosen.connect(func(r):
		_apply_basic(r)
		rs.queue_free()
		_next_node())

func _apply_basic(r: Dictionary) -> void:
	_run.apply_reward(r)
	# 磨练招式:几率"顿悟"领悟一门可自悟功夫(稀缺/实战顿悟功夫不在此池)
	if r.get("type", "") == "hone" and _rng.randf() < 0.35:
		var un := _run.self_learnable_arts()
		if un.size() > 0:
			_run.learn(un[_rng.randi_range(0, un.size() - 1)])

# --- 奇遇 ---
func _show_encounter() -> void:
	var enc := ENCOUNTER.instantiate()
	add_child(enc)
	enc.setup(Encounters.for_chapter(_run.current_node()["chapter"], _rng))
	enc.chosen.connect(func(effect):
		_run.apply_encounter(effect, _rng)
		enc.queue_free()
		_run.advance_node()
		_next_node())

# --- 结束 ---
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

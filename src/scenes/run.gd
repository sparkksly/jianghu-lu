extends Node

# 一局 run:三章节点序列(小怪→奇遇→精英→boss),按节点类型分发。

const FIGHT := preload("res://src/scenes/fight.tscn")
const REWARD := preload("res://src/scenes/reward_select.tscn")
const ENCOUNTER := preload("res://src/scenes/encounter.tscn")
const SHOP := preload("res://src/scenes/shop.tscn")
const MAP := preload("res://src/scenes/map.tscn")
const EQUIP_PANEL := preload("res://src/scenes/equip_panel.tscn")
const MENU_PATH := "res://src/scenes/main_menu.tscn"

@onready var _banner: Control = $BannerLayer/Banner
@onready var _banner_label: Label = $BannerLayer/Banner/Label
@onready var _inv_btn: Button = $InvLayer/InvButton
var _inv_panel: Node = null
var _map: Node = null

var _run: RunState
var _fight: Node
var _ended := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_run = RunState.new(RunState.pending_menpai, RunState.pending_neigong, RunState.pending_arts)
	_rng.seed = 2024
	_inv_btn.pressed.connect(_open_inventory)
	_next_node()

# 行囊面板:战斗中/已结束不开;打开时暂存为覆盖层,继续即关。
func _open_inventory() -> void:
	if _ended or _inv_panel != null:
		return
	_inv_panel = EQUIP_PANEL.instantiate()
	add_child(_inv_panel)
	_inv_panel.set_run(_run)
	_inv_panel.done.connect(_close_inventory)

func _close_inventory() -> void:
	if _inv_panel:
		_inv_panel.queue_free()
		_inv_panel = null

func _next_node() -> void:
	if _run.is_complete():
		_end_run("通关! 华山论剑扬名立万\n气血余 %d" % _run.player_hp)
		return
	_show_map()

# 分支地图:节点间的中枢。显示本程候选(择路)+下程预览;选一个 → 进入。
func _show_map() -> void:
	_hide_banner()   # 关键:藏开场遮罩,否则全屏 Dim 盖在地图上吃掉点击
	_inv_btn.show()
	if _map:
		_map.queue_free()
	_map = MAP.instantiate()
	add_child(_map)
	_map.setup(_run)
	_map.choose.connect(_on_map_choose)

func _on_map_choose(idx: int) -> void:
	_run.select(idx)
	if _map:
		_map.queue_free()
		_map = null
	_enter_node()

func _enter_node() -> void:
	var n := _run.current_node()
	match n["type"]:
		"encounter": _show_encounter()
		"shop": _show_shop()
		_: _start_fight()

func _node_label(n: Dictionary) -> String:
	match n["type"]:
		"encounter": return "※ 江湖奇遇"
		"shop": return "✦ 江湖集市"
		"elite": return "⚔ 精英"
		"boss": return "☠  B O S S"
		_: return "· 寻常对手"

# --- 战斗 ---
func _start_fight() -> void:
	_inv_btn.hide()   # 战斗盖屏,藏起行囊入口
	if _fight:
		_fight.queue_free()
	_fight = FIGHT.instantiate()
	_fight.configure(_build_cfg())
	_fight.fight_finished.connect(_on_fight_finished)
	add_child(_fight)

func _build_cfg() -> Dictionary:
	return {
		"player_hp": _run.player_hp,
		"player_max_hp": _run.combat_max_hp(),
		"seed": 1000 + _run.node_index,
		"menpai": _run.menpai_id,
		"learned": _run.learned,
		"max_qi": _run.combat_max_qi(),
		"triggers": _run.combat_triggers(),
		"evo": _run.evo,
		"weight": _run.draw_weights(),   # 家族需求抬基础招 + 化境单卡权重
		"compiled": _run.compiled_arts(),
		"attack": _run.combat_attack(),
		"dmg_inc": _run.combat_dmg_inc(),
		"extra_dmg": _run.combat_extra(),
		"armor": _run.combat_armor(),
		"enemy": _run.current_enemy(),
	}

func _on_fight_finished(player_won: bool) -> void:
	if not player_won:
		_end_run("败北... 江湖路断")
		return
	_inv_btn.show()
	_run.player_hp = _fight.get_player_hp()
	_run.add_money(_bounty(_run.current_node()))   # 战利银两
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

# 战斗银两:按节点类型 + 章节缩放。
func _bounty(n: Dictionary) -> int:
	var ch: int = n["chapter"]
	match n["type"]:
		"boss": return 60 + ch * 15
		"elite": return 30 + ch * 8
		_: return 15 + ch * 5

# --- 商店 ---
func _show_shop() -> void:
	_inv_btn.hide()   # 商店盖屏
	var s := SHOP.instantiate()
	add_child(s)
	s.setup(_run, _run.current_node()["chapter"], _rng)
	s.done.connect(func():
		s.queue_free()
		_inv_btn.show()
		_run.advance_node()
		_next_node())

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
	_inv_btn.hide()
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

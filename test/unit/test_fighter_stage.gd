extends GutTest

# 火柴人姿势映射(纯逻辑,不渲染):踢腿 vs 上身攻击要分得开。

var _stage

func before_each():
	_stage = load("res://src/scenes/fighter_stage.gd").new()

func after_each():
	if _stage:
		_stage.free()

func _info(move, phase) -> Dictionary:
	return {"move": move, "phase": phase}

func test_leg_attack_active_is_kick():
	var m := Deck.by_id(&"snap_kick")   # 腿法
	assert_eq(_stage._pose(_info(m, &"active")), "kick")

func test_fist_attack_active_is_punch():
	var m := Deck.by_id(&"jab")          # 拳法
	assert_eq(_stage._pose(_info(m, &"active")), "punch")

func test_attack_startup_is_windup_not_strike():
	var m := Deck.by_id(&"jab")
	assert_eq(_stage._pose(_info(m, &"startup")), "windup")

func test_block_dodge_step_poses():
	assert_eq(_stage._pose(_info(Deck.by_id(&"guard"), &"active")), "block")
	assert_eq(_stage._pose(_info(Deck.by_id(&"dodge"), &"active")), "dodge")
	assert_eq(_stage._pose(_info(Deck.by_id(&"step_in"), &"active")), "step")

func test_empty_is_idle():
	assert_eq(_stage._pose({}), "idle")

func test_gap_grows_with_distance():
	assert_lt(_stage._gap_for(0), _stage._gap_for(1))
	assert_lt(_stage._gap_for(1), _stage._gap_for(2))

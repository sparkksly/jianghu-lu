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

# 贴近度:蓄力微前 → 命中贴满 → 后摇保持 → 收手回落。连招靠"保持"不回弹。
func test_advance_target_ramps_with_phase():
	var p := Plan.new()
	p.add(PlacedMove.new(Deck.by_id(&"chop_palm"), 0))   # su2 act1 rec1
	_stage._tf = 0.0; assert_almost_eq(_stage._advance_target(p), 0.35, 0.01, "前摇蓄力微前")
	_stage._tf = 2.0; assert_eq(_stage._advance_target(p), 1.0, "命中贴满")
	_stage._tf = 3.0; assert_almost_eq(_stage._advance_target(p), 0.75, 0.01, "后摇保持")
	_stage._tf = 9.0; assert_eq(_stage._advance_target(p), 0.0, "收手回落")

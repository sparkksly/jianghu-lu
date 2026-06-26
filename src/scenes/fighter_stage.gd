extends Control

# 两个火柴人对打。两件事决定打击感:
# (1) 命中要「真的接触」—— 攻击者按状态平滑突进贴上去,攻击肢体端点延伸到对方躯干;
#     连招(招招紧邻)贴近度来不及回落就被下一招拉满 → 全程贴打、不回弹;打完才缓退。
# (2) 强调「那一下」—— 顿帧(由 watch_phase 触发 freeze)、受击闪白、加强击退。
# 纯表现:从两份 plan(已融合)+ 距离 + 命中事件驱动,不改战斗逻辑。

const COL0 := Color(0.55, 0.82, 1.0)    # 我方(左,面朝右)
const COL1 := Color(1.0, 0.62, 0.55)    # 对手(右,面朝左)
const WHITE := Color(1, 1, 1)
const HIP_Y := 0.52
const GAP_MIN := 150.0                   # 贴身
const GAP_STEP := 188.0                  # 每多一档距离
const CONTACT_GAP := 72.0                # 突进满时两人髋间距(肢体刚好够到)
const BODY_R := 9.0
const KNOCKBACK := 34.0                  # 受击后撤像素
const FLINCH_T := 0.34                   # 受击闪白/退缩时长

var _plan0: Plan
var _plan1: Plan
var _tf := 0.0
var _gap := 330.0
var _gap_target := 330.0
var _anim := 0.0
var _flinch: Array[float] = [0.0, 0.0]
var _advance: Array[float] = [0.0, 0.0]   # 每方贴近度 0..1(平滑;进快退慢)
var _freeze := 0.0           # 顿帧:期间整台静止

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func setup(plan0: Plan, plan1: Plan, distance: int) -> void:
	_plan0 = plan0; _plan1 = plan1
	_tf = 0.0
	_gap = _gap_for(distance); _gap_target = _gap
	_flinch.fill(0.0); _advance.fill(0.0); _freeze = 0.0
	queue_redraw()

func idle(distance: int) -> void:
	_plan0 = null; _plan1 = null
	_gap_target = _gap_for(distance)
	_advance.fill(0.0)
	queue_redraw()

func set_time(tf: float) -> void:
	_tf = tf

func set_distance(distance: int) -> void:
	_gap_target = _gap_for(distance)

func flinch(side: int) -> void:
	if side == 0 or side == 1:
		_flinch[side] = FLINCH_T

# 顿帧:命中瞬间冻结整台 dur 秒。
func freeze(dur: float) -> void:
	_freeze = maxf(_freeze, dur)

func _gap_for(distance: int) -> float:
	return GAP_MIN + clampi(distance, 0, 2) * GAP_STEP

func _process(delta: float) -> void:
	if _freeze > 0.0:
		_freeze -= delta            # 顿帧:画面静止,只数着时间
		queue_redraw()
		return
	_anim += delta
	_gap = lerpf(_gap, _gap_target, clampf(delta * 8.0, 0, 1))
	for i in 2:
		_flinch[i] = maxf(0.0, _flinch[i] - delta)
		var tgt: float = _advance_target(_plan0 if i == 0 else _plan1)
		var k := delta * (18.0 if tgt > _advance[i] else 6.0)   # 进快退慢 → 连招不回弹
		_advance[i] = lerpf(_advance[i], tgt, clampf(k, 0, 1))
	queue_redraw()

func _active(plan: Plan) -> Dictionary:
	if plan == null:
		return {}
	for pm in plan.sorted():
		var s: int = pm.start
		var e: int = s + pm.move.total_duration()
		if _tf >= float(s) and _tf < float(e):
			return {"move": pm.move, "phase": pm.move.phase_at(int(floor(_tf)) - s)}
	return {}

# 贴近度目标:蓄力微前 → 命中贴满 → 后摇保持 → 非攻击则回落。
func _advance_target(plan: Plan) -> float:
	var info := _active(plan)
	if info.is_empty():
		return 0.0
	var m: Move = info["move"]
	if m.kind == Move.Kind.ATTACK or m.kind == Move.Kind.THROW:
		match info["phase"]:
			&"startup": return 0.35
			&"active": return 1.0
			&"recovery": return 0.75
	return 0.0

func _pose(info: Dictionary) -> String:
	if info.is_empty():
		return "idle"
	var m: Move = info["move"]
	match m.kind:
		Move.Kind.BLOCK: return "block"
		Move.Kind.DODGE: return "dodge"
		Move.Kind.STEP: return "step"
		_:
			if info["phase"] == &"active":
				return "kick" if (&"腿法" in m.tags) else "punch"
			return "windup"

func _draw() -> void:
	var cx := size.x * 0.5
	var hip_y := size.y * HIP_Y
	# 基础位置(含受击后撤),再按贴近度插值到接触位
	var bx0: float = cx - _gap * 0.5 - _flinch[0] / FLINCH_T * KNOCKBACK   # 我方后方=左
	var bx1: float = cx + _gap * 0.5 + _flinch[1] / FLINCH_T * KNOCKBACK   # 对手后方=右
	var x0: float = lerpf(bx0, bx1 - CONTACT_GAP, _advance[0])
	var x1: float = lerpf(bx1, bx0 + CONTACT_GAP, _advance[1])
	draw_line(Vector2(minf(bx0, x0) - 40, hip_y + 52), Vector2(maxf(bx1, x1) + 40, hip_y + 52), Color(1, 1, 1, 0.08), 2.0)
	_draw_fighter(Vector2(x0, hip_y), 1, _pose(_active(_plan0)), COL0, _flinch[0], x1)
	_draw_fighter(Vector2(x1, hip_y), -1, _pose(_active(_plan1)), COL1, _flinch[1], x0)

# opp_x: 对方躯干绝对 x,用于命中帧让攻击肢体端点真正搭上去。
func _draw_fighter(hip: Vector2, facing: int, pose: String, base_col: Color, fl: float, opp_x: float) -> void:
	var bob := sin(_anim * 3.0) * 2.0
	var lean := 0.0
	var hand_f := Vector2(facing * 8, 16)
	var hand_b := Vector2(-facing * 6, 18)
	var foot_f := Vector2(facing * 14, 44)
	var foot_b := Vector2(-facing * 14, 44)
	# 命中帧攻击肢体伸到对方躯干外缘
	var reach := (opp_x - hip.x) - facing * BODY_R

	match pose:
		"punch":
			hand_f = Vector2(reach, -2); lean = facing * 6
		"kick":
			foot_f = Vector2(reach, -4); lean = -facing * 7; hand_b = Vector2(-facing * 18, 8)
		"windup":
			hand_f = Vector2(-facing * 14, 6); lean = -facing * 4
		"block":
			hand_f = Vector2(facing * 16, -6); hand_b = Vector2(facing * 12, 4)
		"dodge":
			lean = -facing * 9
		"step":
			lean = facing * 6

	var sink := 0.0
	if fl > 0.0:
		lean += -facing * 8 * (fl / FLINCH_T)      # 被打:后仰
		sink = (fl / FLINCH_T) * 4.0               # 蜷一下

	var shoulder := hip + Vector2(lean, -34 + bob + sink)
	var head := shoulder + Vector2(lean * 0.3, -14)
	# 受击闪白
	var col := base_col.lerp(WHITE, clampf(fl / FLINCH_T, 0, 1) * 0.85)
	var w := 4.0 if fl > 0.0 else 3.0
	draw_line(hip, shoulder, col, w)
	draw_circle(head, BODY_R, col)
	draw_line(shoulder, shoulder + hand_f, col, w)
	draw_line(shoulder, shoulder + hand_b, col, w)
	draw_line(hip, hip + foot_f, col, w)
	draw_line(hip, hip + foot_b, col, w)

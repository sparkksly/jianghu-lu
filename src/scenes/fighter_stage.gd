extends Control

# 两个火柴人对打。核心目的:把「距离」画出来(贴身/中/远 = 两人间距),
# 并按各自当前招式摆出姿势 —— 踢腿(腿法)和上身攻击(拳/掌/肘)看得出区别。
# 纯表现:从两份 plan(已融合)+ 距离 + 命中事件驱动,不改战斗逻辑。

const COL0 := Color(0.55, 0.82, 1.0)    # 我方(左,面朝右)
const COL1 := Color(1.0, 0.62, 0.55)    # 对手(右,面朝左)
const HIP_Y := 0.52                      # 髋部在 stage 高度的比例
const GAP_MIN := 150.0                   # 贴身
const GAP_STEP := 188.0                  # 每多一档距离拉开多少

var _plan0: Plan
var _plan1: Plan
var _tf := 0.0           # 当前连续拍
var _gap := 330.0        # 当前可视间距(向目标缓动)
var _gap_target := 330.0
var _anim := 0.0         # idle 呼吸/摆动用的时间
var _flinch := [0.0, 0.0]  # 受击退缩计时(每方)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func setup(plan0: Plan, plan1: Plan, distance: int) -> void:
	_plan0 = plan0; _plan1 = plan1
	_tf = 0.0
	_gap = _gap_for(distance); _gap_target = _gap
	_flinch = [0.0, 0.0]
	queue_redraw()

func idle(distance: int) -> void:
	_plan0 = null; _plan1 = null
	_gap_target = _gap_for(distance)
	queue_redraw()

func set_time(tf: float) -> void:
	_tf = tf

func set_distance(distance: int) -> void:
	_gap_target = _gap_for(distance)

func flinch(side: int) -> void:
	if side == 0 or side == 1:
		_flinch[side] = 0.32

func _gap_for(distance: int) -> float:
	return GAP_MIN + clampi(distance, 0, 2) * GAP_STEP

func _process(delta: float) -> void:
	_anim += delta
	_gap = lerpf(_gap, _gap_target, clampf(delta * 8.0, 0, 1))
	for i in 2:
		_flinch[i] = maxf(0.0, _flinch[i] - delta)
	queue_redraw()

# 找某方在连续拍 tf 时正在做的招(已融合的 plan)。
func _active(plan: Plan) -> Dictionary:
	if plan == null:
		return {}
	for pm in plan.sorted():
		var s: int = pm.start
		var e: int = s + pm.move.total_duration()
		if _tf >= float(s) and _tf < float(e):
			return {"move": pm.move, "phase": pm.move.phase_at(int(floor(_tf)) - s)}
	return {}

func _pose(info: Dictionary) -> String:
	if info.is_empty():
		return "idle"
	var m: Move = info["move"]
	var ph: StringName = info["phase"]
	match m.kind:
		Move.Kind.BLOCK:
			return "block"
		Move.Kind.DODGE:
			return "dodge"
		Move.Kind.STEP:
			return "step"
		_:  # ATTACK / THROW
			if ph == &"active":
				return "kick" if (&"腿法" in m.tags) else "punch"
			return "windup"

func _draw() -> void:
	var cx := size.x * 0.5
	var hip_y := size.y * HIP_Y
	var x0 := cx - _gap * 0.5
	var x1 := cx + _gap * 0.5
	# 地面阴影线
	draw_line(Vector2(cx - _gap * 0.5 - 40, hip_y + 52), Vector2(cx + _gap * 0.5 + 40, hip_y + 52), Color(1, 1, 1, 0.08), 2.0)
	_draw_fighter(Vector2(x0, hip_y), 1, _pose(_active(_plan0)), COL0, _flinch[0])
	_draw_fighter(Vector2(x1, hip_y), -1, _pose(_active(_plan1)), COL1, _flinch[1])

# facing: +1 面朝右 / -1 面朝左。f 是受击退缩量(0..0.32)。
func _draw_fighter(hip: Vector2, facing: int, pose: String, col: Color, fl: float) -> void:
	var bob := sin(_anim * 3.0) * 2.0
	var lean := 0.0          # 躯干前后倾(+ 朝 facing 方向)
	var back := 0.0          # 整体后撤(受击/闪避)
	var hand_f := Vector2(facing * 8, 16)    # 前手(朝对手一侧)
	var hand_b := Vector2(-facing * 6, 18)   # 后手
	var foot_f := Vector2(facing * 14, 44)   # 前脚
	var foot_b := Vector2(-facing * 14, 44)  # 后脚

	match pose:
		"punch":
			hand_f = Vector2(facing * 38, -2); lean = facing * 5
		"kick":
			foot_f = Vector2(facing * 42, -4); lean = -facing * 6; hand_b = Vector2(-facing * 18, 8)
		"windup":
			hand_f = Vector2(-facing * 14, 6); lean = -facing * 3   # 收招/蓄力
		"block":
			hand_f = Vector2(facing * 16, -6); hand_b = Vector2(facing * 12, 4)
		"dodge":
			back = -facing * 16; lean = -facing * 8
		"step":
			lean = facing * 6

	if fl > 0.0:
		back += -facing * (fl / 0.32) * 22.0   # 被打:朝后退
		lean += -facing * 6

	var base := hip + Vector2(back, 0)
	var shoulder := base + Vector2(lean, -34 + bob)
	var head := shoulder + Vector2(lean * 0.3, -14)
	# 躯干
	draw_line(base, shoulder, col, 3.0)
	# 头
	draw_circle(head, 9.0, col)
	# 手臂
	draw_line(shoulder, shoulder + hand_f, col, 3.0)
	draw_line(shoulder, shoulder + hand_b, col, 3.0)
	# 腿
	draw_line(base, base + foot_f, col, 3.0)
	draw_line(base, base + foot_b, col, 3.0)

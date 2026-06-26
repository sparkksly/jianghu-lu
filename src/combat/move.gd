class_name Move
extends Resource

enum Kind { ATTACK, BLOCK, DODGE, THROW, STEP }

@export var id: StringName = &""
@export var move_name: String = "招式"
@export var tags: Array[StringName] = []
@export var kind: Kind = Kind.ATTACK

@export var startup: int = 1      # 前摇 ticks
@export var active: int = 1       # 命中/有效 ticks
@export var recovery: int = 1     # 后摇 ticks
@export var hit_offsets: Array[int] = [0]  # which active ticks deal damage (ATTACK/THROW)

@export var stamina_cost: int = 1
@export var damage: int = 0
@export var priority: int = 0     # same-tick tie-break, higher wins

@export var can_interrupt: bool = false  # 打断 词缀
@export var super_armor: bool = false    # 霸体 词缀
@export var is_heavy: bool = false       # 重击 (extra whiff penalty)

@export var range_min: int = 0     # 适用距离带 [min,max]，默认任意
@export var range_max: int = 2
@export var distance_delta: int = 0  # STEP 用：上步-1 / 撤步+1
@export var knockback: bool = false  # 击退：命中后距离+1
@export var stun: int = 0            # 踉跄：命中令对手跳 N 拍
@export var grants_guard: int = 0    # 护体：干净命中后给自己挂 N 拍受伤减免

func active_count() -> int:
	return max(1, active)

func total_duration() -> int:
	return startup + active_count() + recovery

func phase_at(elapsed: int) -> StringName:
	if elapsed < 0 or elapsed >= total_duration():
		return &"done"
	if elapsed < startup:
		return &"startup"
	if elapsed < startup + active_count():
		return &"active"
	return &"recovery"

func is_hit_tick(elapsed: int) -> bool:
	if phase_at(elapsed) != &"active":
		return false
	return (elapsed - startup) in hit_offsets

func in_range(d: int) -> bool:
	return range_min <= d and d <= range_max

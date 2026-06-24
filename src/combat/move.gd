class_name Move
extends Resource

enum Kind { ATTACK, BLOCK, DODGE, THROW }

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

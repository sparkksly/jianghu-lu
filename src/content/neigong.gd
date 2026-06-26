class_name Neigong
extends RefCounted

# 内功:气/血的来源。门派给起手内功,打坐提升等级,按流派给不同属性。开局可三选一。
#   易筋经:外壮筋骨,偏血(+3血+1气/级)
#   两仪心法:养气为主,偏气(+1血+2气/级)
#   罗汉伏气:刚柔并济,均衡(+2血+2气/级)

const ALL := [&"yijinjing", &"liangyi", &"luohanqi"]

static func all() -> Array:
	return ALL

static func starter(menpai_id: StringName) -> StringName:
	return &"liangyi" if menpai_id == &"wudang" else &"yijinjing"

static func display_name(id: StringName) -> String:
	match id:
		&"liangyi": return "两仪心法"
		&"luohanqi": return "罗汉伏气"
		_: return "易筋经"

static func hp_per_level(id: StringName) -> int:
	match id:
		&"liangyi": return 1
		&"luohanqi": return 2
		_: return 3

static func qi_per_level(id: StringName) -> int:
	match id:
		&"liangyi": return 2
		&"luohanqi": return 2
		_: return 1

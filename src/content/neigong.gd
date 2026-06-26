class_name Neigong
extends RefCounted

# 内功:气/血的来源。门派给起手内功,打坐提升等级,按内功流派给不同属性。
#   少林·易筋经:外壮筋骨,偏血(每级 +3血 +1气)
#   武当·两仪心法:养气为主,偏气(每级 +1血 +2气)

static func starter(menpai_id: StringName) -> StringName:
	return &"liangyi" if menpai_id == &"wudang" else &"yijinjing"

static func display_name(id: StringName) -> String:
	return "两仪心法" if id == &"liangyi" else "易筋经"

static func hp_per_level(id: StringName) -> int:
	return 1 if id == &"liangyi" else 3

static func qi_per_level(id: StringName) -> int:
	return 2 if id == &"liangyi" else 1

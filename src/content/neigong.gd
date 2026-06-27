class_name Neigong
extends RefCounted

# 内功:气/血的来源。门派给起手内功,打坐提升等级,按流派给不同血/气配比。开局三选一(从 all)。
# 10 门内功,配比各异(血向/气向/均衡);强度由 playtest 调(总功率求大致相近)。

const ALL := [&"yijinjing", &"liangyi", &"luohanqi", &"ximui", &"taiqing", &"xiantian", &"guixi", &"chunyang", &"xuanpin", &"taiji_xin"]

# id → [血/级, 气/级]
const STATS := {
	&"yijinjing": [3, 1],    # 易筋经:外壮筋骨,偏血
	&"liangyi": [1, 2],      # 两仪心法:养气
	&"luohanqi": [2, 2],     # 罗汉伏气:均衡
	&"ximui": [4, 0],        # 洗髓经:纯血
	&"taiqing": [0, 3],      # 太清真气:纯气
	&"xiantian": [3, 2],     # 先天功:厚重
	&"guixi": [2, 1],        # 龟息功:稳血
	&"chunyang": [2, 3],     # 纯阳功:刚气
	&"xuanpin": [1, 3],      # 玄牝功:柔气
	&"taiji_xin": [1, 1],    # 太极心法:入门
}

const NAMES := {
	&"yijinjing": "易筋经", &"liangyi": "两仪心法", &"luohanqi": "罗汉伏气",
	&"ximui": "洗髓经", &"taiqing": "太清真气", &"xiantian": "先天功",
	&"guixi": "龟息功", &"chunyang": "纯阳功", &"xuanpin": "玄牝功", &"taiji_xin": "太极心法",
}

static func all() -> Array:
	return ALL

static func starter(menpai_id: StringName) -> StringName:
	return &"liangyi" if menpai_id == &"wudang" else &"yijinjing"

static func display_name(id: StringName) -> String:
	return NAMES.get(id, "易筋经")

static func hp_per_level(id: StringName) -> int:
	return int(STATS.get(id, [3, 1])[0])

static func qi_per_level(id: StringName) -> int:
	return int(STATS.get(id, [3, 1])[1])

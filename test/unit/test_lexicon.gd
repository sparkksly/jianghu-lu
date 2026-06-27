extends GutTest

func test_dmg_inc_phrase():
	assert_eq(Lexicon.describe_modifier({"stat": "dmg_inc", "value": 50}), "伤害 +50%")

func test_extra_distinct_wording():
	# 额外伤害(独立乘区)措辞和普通增伤不同,玩家能区分
	assert_eq(Lexicon.describe_modifier({"stat": "extra_dmg", "value": 30}), "额外伤害 +30%")

func test_attack_and_armor():
	assert_eq(Lexicon.describe_modifier({"stat": "attack", "value": 5}), "攻击力 +5")
	assert_eq(Lexicon.describe_modifier({"stat": "armor", "value": 8}), "防御 +8")

func test_hp_qi():
	assert_eq(Lexicon.describe_modifier({"stat": "max_hp", "value": 6}), "气血上限 +6")
	assert_eq(Lexicon.describe_modifier({"stat": "max_qi", "value": 2}), "气海上限 +2")

func test_unknown_stat_empty():
	assert_eq(Lexicon.describe_modifier({"stat": "nope", "value": 1}), "")

func test_describe_mods_joins():
	var s := Lexicon.describe_mods([{"stat": "attack", "value": 5}, {"stat": "dmg_inc", "value": 20}])
	assert_string_contains(s, "攻击力 +5")
	assert_string_contains(s, "伤害 +20%")

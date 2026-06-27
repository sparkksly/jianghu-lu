class_name Lexicon
extends RefCounted

# 统一描述层:所有增强/属性按 stat 查标准句式自动生成,全游戏措辞一致且精确。
# 每个乘区一种固定措辞,玩家从文字即可判断叠加方式:
#   "伤害 +X%"   = 普通增伤(加法区,同类相加)
#   "额外伤害 +X%" = 稀有(独立乘区,相乘) ←「额外」二字标出它独立更值钱
# 文案是 i18n key(中文原文即 key);英文填 translations.csv 的 en 列。

const STAT_PHRASE := {
	"attack": "攻击力 +%d",
	"dmg_inc": "伤害 +%d%%",
	"extra_dmg": "额外伤害 +%d%%",
	"armor": "防御 +%d",
	"max_hp": "气血上限 +%d",
	"max_qi": "气海上限 +%d",
}

# 一个 modifier {stat,op,value} → 标准描述。
static func describe_modifier(mod: Dictionary) -> String:
	var stat: String = mod.get("stat", "")
	if not STAT_PHRASE.has(stat):
		return ""
	return TranslationServer.translate(STAT_PHRASE[stat]) % int(mod.get("value", 0))

# 一串 modifier → 顿号连接。
static func describe_mods(mods: Array) -> String:
	var parts: Array = []
	for m in mods:
		var s := describe_modifier(m)
		if s != "":
			parts.append(s)
	return "、".join(parts)

# 翻译任意 key(中文原文即 key)。
static func t(key: String) -> String:
	return TranslationServer.translate(key)

# 语言切换。默认中文(不加载任何 translation → key 即中文);切英文时按需加载 csv 译文。
# 这样默认全游戏中文稳定,英文译文(translations.csv)就绪可一键启用。
static func set_language(lang: String) -> void:
	if lang == "en":
		TranslationServer.add_translation(load("res://translations.en.translation"))
		TranslationServer.set_locale("en")
	else:
		TranslationServer.set_locale("zh_CN")

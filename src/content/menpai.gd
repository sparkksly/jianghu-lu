class_name Menpai
extends RefCounted

# 门派 = 一套功夫(组合招/绝学)。9 门基础招两派通用(抽牌池);门派定能合成哪些功夫。
# 开局从本派 4 门初级功夫里选 2 门会的;高级功夫靠领悟(需初级功夫熟练)。
#   少林=刚猛:罗汉拳/连环踢/金刚伏魔/伏虎拳 → 般若神掌/佛山无影脚
#   武当=柔劲:太极云手/武当长拳/绵里藏针/柔云腿 → 大成云手/两仪连环

const SHAOLIN := &"shaolin"
const WUDANG := &"wudang"

# 4 门初级功夫(开局选 2)。
static func starter_pool(id: StringName) -> Array:
	match id:
		WUDANG: return [&"taiji_yunshou", &"wudang_changquan", &"mianli", &"rouyun"]
		_: return [&"luohan", &"chain_kick", &"jingang_fumo", &"fuhu"]

# 本派能领悟的全部功夫(初级 + 通用乾坤 + 高级)。
static func learnable(id: StringName) -> Array:
	match id:
		WUDANG: return [&"taiji_yunshou", &"wudang_changquan", &"mianli", &"rouyun", &"qiankun", &"da_yunshou", &"liangyi", &"lanque", &"tuishou", &"tiyun", &"sixiang", &"taixu",
			&"saotang", &"shuangfeng", &"jiequan", &"bajiquan", &"paiyun",
			&"liangyi_jian", &"wuji", &"taiji_quan", &"sanfeng", &"qingshen", &"yunlong",
			&"xianglong", &"liangyi_hua"]
		_: return [&"luohan", &"chain_kick", &"jingang_fumo", &"fuhu", &"qiankun", &"prajna", &"wuying", &"weituo", &"heihu", &"jinzhong", &"jingang_zhang", &"damo_quan",
			&"saotang", &"shuangfeng", &"jiequan", &"bajiquan", &"paiyun",
			&"luohan_da", &"weituo_xiang", &"jingang_bu", &"yingzhua", &"shibaluohan", &"damo_jian",
			&"xianglong", &"jingang_zhi"]

static func display_name(id: StringName) -> String:
	match id:
		WUDANG: return "武当"
		_: return "少林"

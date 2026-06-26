class_name Menpai
extends RefCounted

# 门派 = 开局风格:决定起手已会的绝学 + 这一脉能领悟哪些绝学。
# 进攻抽牌池是通用基础动作(两派相同);门派功夫靠把基础动作合成的连招(见 Arts)。
#   少林=刚猛:起手罗汉拳;武当=柔劲:起手太极云手。

const SHAOLIN := &"shaolin"
const WUDANG := &"wudang"

# 进攻池 = 通用基础动作(两派相同)。
static func pool(_id: StringName) -> Array[Move]:
	return Hand.attack_pool(Deck.starter())

# 开局已会的入门绝学。
static func starter_learned(id: StringName) -> Array:
	match id:
		WUDANG: return [&"taiji_yunshou"]
		_: return [&"luohan"]

# 这一脉能领悟的全部绝学(通用 + 本门),含起手那个。
static func learnable(id: StringName) -> Array:
	match id:
		WUDANG: return [&"chain_kick", &"qiankun", &"taiji_yunshou"]
		_: return [&"chain_kick", &"qiankun", &"luohan", &"jingang_fumo"]

static func display_name(id: StringName) -> String:
	match id:
		WUDANG: return "武当"
		_: return "少林"

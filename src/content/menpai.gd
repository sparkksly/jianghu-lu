class_name Menpai
extends RefCounted

# 门派 = 你能用基础动作合成出哪些「功夫/绝学」(连招配方),不是一套独立的基础招。
# 双方都从同一套基础动作里抽牌;门派只决定可合成的绝学 + 风格(少林护体 / 武当借力)。
#   少林=刚猛:拳法×3→罗汉拳;格挡+掌法→金刚伏魔(护体)。
#   武当=柔劲:掌法×2→太极云手(走位);借力(通用)是其反打核心。

const SHAOLIN := &"shaolin"
const WUDANG := &"wudang"

# 进攻池 = 通用基础动作(两派相同)。门派的差别在连招,不在抽牌池。
static func pool(_id: StringName) -> Array[Move]:
	return Hand.attack_pool(Deck.starter())

# 连招规则 = 通用 base + 门派绝学配方(都用基础动作做输入)。
static func rules(id: StringName) -> ComboRules:
	var r := ComboLibrary.build()
	match id:
		WUDANG:
			# 掌法×2 → 太极云手(柔掌连绵 + 贴近)
			r.add_recipe([{"tag":&"掌法"}, {"tag":&"掌法"}], Deck.taiji_yunshou())
		_:  # 少林(默认)
			# 拳法×3 → 罗汉拳(刚猛三连;有放回抽牌可凑同名拳)
			r.add_recipe([{"tag":&"拳法"}, {"tag":&"拳法"}, {"tag":&"拳法"}], Deck.luohan())
			# 格挡 + 掌法 → 金刚伏魔(重掌 + 自挂护体)
			r.add_recipe([{"kind":Move.Kind.BLOCK}, {"tag":&"掌法"}], Deck.jingang_fumo())
	return r

static func display_name(id: StringName) -> String:
	match id:
		WUDANG: return "武当"
		_: return "少林"

static func info(id: StringName) -> Dictionary:
	return {"id": id, "name": display_name(id), "pool": pool(id), "rules": rules(id)}

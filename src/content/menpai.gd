class_name Menpai
extends RefCounted

# 门派:决定起始进攻池 + 可用连招配方。工具牌(步/挡/闪/拿)是通用的,不在这里。
# 少林=刚猛贴身(护体),武当=柔劲中距(借力)。借力是通用机制(成功格挡/闪→增伤),
# 武当靠绵掌/中距更会用,所以"四两拨千斤"不需要单独配方。

const SHAOLIN := &"shaolin"
const WUDANG := &"wudang"

static func _pool_ids(id: StringName) -> Array:
	match id:
		WUDANG:
			return [&"mian_zhang", &"wudang_changquan", &"push_palm", &"snap_kick", &"sweep_kick"]
		_:  # 少林(默认)
			return [&"jab", &"hook", &"beng_quan", &"weituo", &"jingang_zhi", &"longzhua", &"shaolin_gun"]

# 进攻池(供抽卡)。
static func pool(id: StringName) -> Array[Move]:
	var out: Array[Move] = []
	for mid in _pool_ids(id):
		out.append(Deck.by_id(mid))
	return out

# 连招规则 = 通用 base + 门派专属配方。
static func rules(id: StringName) -> ComboRules:
	var r := ComboLibrary.build()
	match id:
		WUDANG:
			# 绵掌×2 → 太极云手(柔掌连绵 + 贴近 + 抢先手)
			r.add_recipe([{"id":&"mian_zhang"}, {"id":&"mian_zhang"}], Deck.taiji_yunshou())
		_:  # 少林
			# 拳法×3 → 罗汉拳(刚猛三连)
			r.add_recipe([{"tag":&"拳法"}, {"tag":&"拳法"}, {"tag":&"拳法"}], Deck.luohan())
			# 格挡 + 韦陀掌 → 金刚伏魔(重掌 + 自挂护体)
			r.add_recipe([{"kind":Move.Kind.BLOCK}, {"id":&"weituo"}], Deck.jingang_fumo())
	return r

static func display_name(id: StringName) -> String:
	match id:
		WUDANG: return "武当"
		_: return "少林"

static func info(id: StringName) -> Dictionary:
	return {"id": id, "name": display_name(id), "pool": pool(id), "rules": rules(id)}

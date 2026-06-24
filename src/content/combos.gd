class_name ComboLibrary
extends RefCounted

static func build() -> ComboRules:
	var r := ComboRules.new()
	# 三连腿法 -> 连环踢
	r.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"},{"tag":&"腿法"}], Deck.chain_kick())
	# 连环踢 + 两腿 -> 佛山无影脚
	r.add_recipe([{"id":&"chain_kick"},{"tag":&"腿法"},{"tag":&"腿法"}], Deck.wuying())
	# 攻 + 防 + 投 -> 乾坤大挪移
	r.add_recipe([{"kind":Move.Kind.ATTACK},{"kind":Move.Kind.BLOCK},{"kind":Move.Kind.THROW}], Deck.qiankun())
	return r

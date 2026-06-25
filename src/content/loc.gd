class_name Loc
extends RefCounted

const _COMBO_RESULTS := [&"chain_kick", &"wuying", &"qiankun"]

static func kind_name(kind: int) -> String:
	match kind:
		Move.Kind.ATTACK: return "攻"
		Move.Kind.BLOCK: return "格挡"
		Move.Kind.DODGE: return "闪避"
		Move.Kind.THROW: return "投"
	return "?"

static func _name_table() -> Dictionary:
	var t := {}
	for m in Deck.starter():
		t[m.id] = m.move_name
	for m in [Deck.chain_kick(), Deck.wuying(), Deck.qiankun()]:
		t[m.id] = m.move_name
	return t

static func move_name(id: StringName) -> String:
	var t := _name_table()
	return t.get(id, str(id))

static func is_combo_result(id: StringName) -> bool:
	return id in _COMBO_RESULTS

static func affixes(move: Move) -> String:
	var parts: Array[String] = []
	if move.can_interrupt: parts.append("打断")
	if move.super_armor: parts.append("霸体")
	if move.is_heavy: parts.append("重击")
	return " ".join(parts)

static func floating_text(e) -> String:
	match e.type:
		&"hit": return "命中 -%d" % e.amount
		&"interrupt": return "打断! -%d" % e.amount
		&"throw_break": return "投破防! -%d" % e.amount
		&"exhaust": return "气力不继!"
		&"death": return ""
		_: return ""

static func event_zh(type: StringName) -> String:
	match type:
		&"hit": return "命中"
		&"interrupt": return "打断"
		&"throw_break": return "投破防"
		&"block": return "格挡"
		&"whiff": return "落空"
		&"exhaust": return "气力不继"
		&"stamina": return "体力"
		&"death": return "倒下"
	return str(type)

static func log_line(e) -> String:
	var who := "你" if e.actor == 0 else "敌"
	var mv := ""
	if e.move_id != &"":
		mv = " " + move_name(e.move_id)
	var amt := ""
	if e.type == &"hit" or e.type == &"interrupt" or e.type == &"throw_break":
		amt = " -%d" % e.amount
	elif e.type == &"stamina":
		amt = " %+d" % e.amount
	return "第%d拍 %s%s%s%s" % [e.tick, who, event_zh(e.type), mv, amt]

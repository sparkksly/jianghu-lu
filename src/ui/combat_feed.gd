class_name CombatFeed
extends RefCounted

# Pure presentation mapping for the watch phase: turns a CombatEvent into
# (a) an optional floating number shown at the character's position, and
# (b) an optional timeline marker shown in a player's lane.
# No nodes here so it stays unit-testable.

const RED := Color(1, 0.32, 0.32)
const GREEN := Color(0.45, 1, 0.55)
const HEAVY_DMG := 12  # at/above this, a hit reads as 重击 (big)

# Returns {} or {side:int, text:String, color:Color, big:bool}.
# `side` is who the number appears over (the one affected).
static func float_number(e) -> Dictionary:
	match e.type:
		&"hit":
			var big: bool = Loc.is_combo_result(e.move_id) or e.amount >= HEAVY_DMG
			return {"side": e.target, "text": "-%d" % e.amount, "color": RED, "big": big}
		&"interrupt", &"throw_break":
			return {"side": e.target, "text": "-%d" % e.amount, "color": RED, "big": true}
		&"heal":
			return {"side": e.target, "text": "+%d" % e.amount, "color": GREEN, "big": e.amount >= HEAVY_DMG}
	return {}

# Returns {} or {lane:int, text:String, tone:String}. tone in {"big","hit","good","bad"}.
# `lane` is the player index whose lane the marker sits in. The text is the MOVE
# NAME (not a category) so the timeline reads as a play-by-play of 招式.
static func marker(e) -> Dictionary:
	match e.type:
		&"hit":
			var tone := "hit"
			if Loc.is_combo_result(e.move_id) or e.amount >= HEAVY_DMG:
				tone = "big"
			return {"lane": e.actor, "text": Loc.move_name(e.move_id), "tone": tone}
		&"interrupt", &"throw_break":
			return {"lane": e.actor, "text": Loc.move_name(e.move_id), "tone": "big"}
		&"block":
			return {"lane": e.target, "text": "格挡", "tone": "good"}
		&"whiff":
			return {"lane": 1 - e.actor, "text": "闪避", "tone": "good"}
		&"exhaust":
			return {"lane": e.actor, "text": "气力不继", "tone": "bad"}
	return {}

static func distance_label(d: int) -> String:
	match d:
		0: return "贴身"
		1: return "中"
		2: return "远"
	return "?"

static func tone_color(tone: String) -> Color:
	match tone:
		"big": return Color(1, 0.82, 0.2)
		"hit": return Color(1, 0.72, 0.42)
		"good": return Color(0.5, 1, 0.6)
		"bad": return Color(0.85, 0.85, 0.9)
	return Color(1, 1, 1)

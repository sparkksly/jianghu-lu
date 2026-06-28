extends Control

@onready var _list: VBoxContainer = $ScrollContainer/List
@onready var _close: Button = $CloseButton

var _learned: Array = []   # 已领悟功夫 id(由 fight 注入)

func _ready() -> void:
	if not _close.pressed.is_connected(toggle):
		_close.pressed.connect(toggle)

func set_learned(learned: Array) -> void:
	_learned = learned

func toggle() -> void:
	visible = not visible
	if visible:
		move_to_front()   # 盖在排招面板之上
		build()

func build() -> void:
	for c in _list.get_children():
		c.queue_free()
	_add("== 基础招式 ==")
	for m in Deck.starter():   # 仅基础招池(9 攻击 + 工具牌),才是真正的抽牌池
		var aff := Loc.affixes(m)
		var line := "%s | %s | 体力%d 伤害%d | 前%d命%d后%d" % [
			m.move_name, Loc.kind_name(m.kind), m.stamina_cost, m.damage,
			m.startup, m.active, m.recovery]
		if aff != "": line += " | " + aff
		if m.tags.size() > 0: line += " | " + " ".join(m.tags.map(func(t): return str(t)))
		_add(line)
	_add("== 已悟功夫 · 配方 ==")
	if _learned.is_empty():
		_add("(尚未领悟功夫)")
	for id in _learned:
		var tn: String = ["", "初级", "高级", "高深", "绝学", "绝世"][clampi(Arts.tier(id), 1, 5)]
		_add("【%s】%s" % [tn, Arts.recipe_text(id)])
		var a := Arts.def(id)
		if a != null and a.result != null:
			var eff := _move_effect(a.result)
			if eff != "":
				_add("        ▸ " + eff)

# 功夫 result 的实战效果:伤害 + 词缀 + 附带 debuff/buff。
func _move_effect(m: Move) -> String:
	var parts: Array = []
	if m.damage > 0:
		parts.append("伤害%d×%d" % [m.damage, max(1, m.hit_offsets.size())])
	var aff := Loc.affixes(m)
	if aff != "":
		parts.append(aff)
	for d in m.inflict:
		parts.append("附「%s」" % Debuffs.display_name(d))
	for b in m.empower:
		parts.append("运「%s」" % Buffs.display_name(b))
	return " | ".join(parts)

func _add(text: String) -> void:
	var l := Label.new()
	l.text = text
	_list.add_child(l)

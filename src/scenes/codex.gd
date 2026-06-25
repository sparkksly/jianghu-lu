extends Control

@onready var _list: VBoxContainer = $ScrollContainer/List
@onready var _close: Button = $CloseButton

func _ready() -> void:
	if not _close.pressed.is_connected(toggle):
		_close.pressed.connect(toggle)

func toggle() -> void:
	visible = not visible
	if visible:
		build()

func build() -> void:
	for c in _list.get_children():
		c.queue_free()
	_add("== 招式 ==")
	var moves: Array[Move] = Deck.starter()
	moves.append_array([Deck.chain_kick(), Deck.wuying(), Deck.qiankun()])
	for m in moves:
		var aff := Loc.affixes(m)
		var line := "%s | %s | 体力%d 伤害%d | 前%d命%d后%d" % [
			m.move_name, Loc.kind_name(m.kind), m.stamina_cost, m.damage,
			m.startup, m.active, m.recovery]
		if aff != "": line += " | " + aff
		if m.tags.size() > 0: line += " | " + " ".join(m.tags.map(func(t): return str(t)))
		_add(line)
	_add("== 出招表 ==")
	for r in ComboLibrary.build().describe_recipes():
		_add("%s → %s" % [" + ".join(r["slots"]), r["result"]])

func _add(text: String) -> void:
	var l := Label.new()
	l.text = text
	_list.add_child(l)

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
	_add("== 已悟功夫 · 配方 ==")
	if _learned.is_empty():
		_add("(尚未领悟功夫)")
	for id in _learned:
		var tier_mark := "【高】" if Arts.tier(id) == 2 else "【初】"
		_add("%s %s" % [tier_mark, Arts.recipe_text(id)])

func _add(text: String) -> void:
	var l := Label.new()
	l.text = text
	_list.add_child(l)

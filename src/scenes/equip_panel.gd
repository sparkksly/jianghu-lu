extends Control

# 行囊/装备管理覆盖面板。set_run(run) 后展示三槽 + 行囊,可穿/脱;done 信号通知关闭。

signal done

var _run = null

func _ready() -> void:
	$Panel/Margin/VBox/DoneButton.pressed.connect(func(): done.emit())

func set_run(r) -> void:
	_run = r
	_refresh()

func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _attr_text(id: StringName) -> String:
	var d := Equips.def(id)
	return Lexicon.describe_mods(d.modifiers) if d != null else ""

func _refresh() -> void:
	if _run == null:
		return
	# 轻功 / 天赋(只读):习得的被动
	var qnames: Array = []
	for id in _run.qinggong:
		qnames.append(Passives.display_name(id))
	var tnames: Array = []
	for id in _run.talents:
		tnames.append(Passives.display_name(id))
	var line := "轻功: " + ("无" if qnames.is_empty() else "、".join(qnames))
	line += "    天赋: " + ("无" if tnames.is_empty() else "、".join(tnames))
	$Panel/Margin/VBox/QinggongLabel.text = line
	var slots := $Panel/Margin/VBox/SlotsBox
	var bag := $Panel/Margin/VBox/BagBox
	_clear(slots)
	_clear(bag)

	# 三槽:武器/防具/饰品
	for slot in Equips.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_l := Label.new()
		name_l.custom_minimum_size = Vector2(64, 0)
		name_l.text = String(slot)
		row.add_child(name_l)
		var id: StringName = _run.equipped(slot)
		var info := Label.new()
		info.custom_minimum_size = Vector2(420, 0)
		if id != &"":
			info.text = "%s  (%s)" % [Equips.display_name(id), _attr_text(id)]
			row.add_child(info)
			var off := Button.new()
			off.text = "卸下"
			off.pressed.connect(_on_unequip.bind(slot))
			row.add_child(off)
		else:
			info.text = "— 空 —"
			info.modulate = Color(1, 1, 1, 0.45)
			row.add_child(info)
		slots.add_child(row)

	# 行囊:拥有但未穿戴
	var uneq: Array = _run.owned_unequipped()
	if uneq.is_empty():
		var empty := Label.new()
		empty.text = "(行囊空空)"
		empty.modulate = Color(1, 1, 1, 0.45)
		bag.add_child(empty)
	for id in uneq:
		var d := Equips.def(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := Label.new()
		info.custom_minimum_size = Vector2(484, 0)
		info.text = "[%s] %s  (%s)" % [String(d.slot), d.equip_name, _attr_text(id)]
		row.add_child(info)
		var on := Button.new()
		on.text = "装备"
		on.pressed.connect(_on_equip.bind(id))
		row.add_child(on)
		bag.add_child(row)

func _on_equip(id: StringName) -> void:
	_run.equip(id)
	_refresh()

func _on_unequip(slot: StringName) -> void:
	_run.unequip(slot)
	_refresh()

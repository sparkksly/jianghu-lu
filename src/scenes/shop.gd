extends Control

# 商店覆盖场景。setup(run, chapter, rng) 后列货架,买扣银两并即时刷新;done 信号离开。

signal done

var _run = null
var _items: Array = []

func _ready() -> void:
	$Panel/Margin/VBox/LeaveButton.pressed.connect(func(): done.emit())

func setup(run, chapter: int, rng: RandomNumberGenerator) -> void:
	_run = run
	_items = Shop.roll(run, chapter, rng)
	_refresh()

func _refresh() -> void:
	if _run == null:
		return
	$Panel/Margin/VBox/MoneyLabel.text = "银两:%d" % _run.money
	var box := $Panel/Margin/VBox/ItemsBox
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for it in _items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := Label.new()
		info.custom_minimum_size = Vector2(470, 0)
		info.text = it["label"]
		row.add_child(info)
		var price := Label.new()
		price.custom_minimum_size = Vector2(80, 0)
		price.text = "%d 两" % int(it["price"])
		row.add_child(price)
		var buy := Button.new()
		var sold: bool = it.get("sold", false)
		var afford: bool = _run.money >= int(it["price"])
		buy.text = "已售" if sold else "购买"
		buy.disabled = sold or not afford
		buy.pressed.connect(_on_buy.bind(it))
		row.add_child(buy)
		if sold:
			info.modulate = Color(1, 1, 1, 0.4)
		box.add_child(row)

func _on_buy(item: Dictionary) -> void:
	Shop.buy(_run, item)
	_refresh()

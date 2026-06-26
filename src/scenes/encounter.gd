extends Control

signal chosen(effect)

@onready var _title: Label = $Panel/VBox/Title
@onready var _body: Label = $Panel/VBox/Body
@onready var _opts: VBoxContainer = $Panel/VBox/Options

func setup(enc: Dictionary) -> void:
	_title.text = enc["title"]
	_body.text = enc["body"]
	for c in _opts.get_children():
		_opts.remove_child(c); c.queue_free()
	for opt in enc["options"]:
		var b := Button.new()
		b.text = opt["label"]
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func(): chosen.emit(opt["effect"]))
		_opts.add_child(b)

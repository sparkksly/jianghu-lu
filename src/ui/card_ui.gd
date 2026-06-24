class_name CardUI
extends Control

signal card_clicked(card_ui: CardUI)

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var cost_label: Label = $VBoxContainer/CostLabel
@onready var desc_label: Label = $VBoxContainer/DescLabel

var card_data: Card

func set_card(data: Card) -> void:
	card_data = data
	name_label.text = data.card_name
	cost_label.text = str(data.cost)
	desc_label.text = data.description

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)

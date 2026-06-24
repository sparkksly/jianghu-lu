class_name CombatantUI
extends Control

@onready var health_bar: ProgressBar = $HealthBar
@onready var block_label: Label = $BlockLabel

func setup(combatant: Combatant) -> void:
	health_bar.max_value = combatant.max_health
	health_bar.value = combatant.current_health
	combatant.health_changed.connect(_on_health_changed)
	combatant.block_changed.connect(_on_block_changed)
	_on_block_changed(combatant.block)

func _on_health_changed(new_health: int, max_health: int) -> void:
	health_bar.value = new_health

func _on_block_changed(new_block: int) -> void:
	block_label.text = "Block: " + str(new_block)
	block_label.visible = new_block > 0

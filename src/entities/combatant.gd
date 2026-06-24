class_name Combatant
extends Node2D

signal health_changed(new_health: int, max_health: int)
signal block_changed(new_block: int)
signal died

@export var max_health: int = 50
@onready var current_health: int = max_health
var block: int = 0

func take_damage(amount: int) -> void:
	if block > 0:
		if amount <= block:
			block -= amount
			amount = 0
		else:
			amount -= block
			block = 0
		block_changed.emit(block)
	
	if amount > 0:
		current_health -= amount
		current_health = max(0, current_health)
		health_changed.emit(current_health, max_health)
		
	if current_health <= 0:
		died.emit()

func add_block(amount: int) -> void:
	block += amount
	block_changed.emit(block)

func reset_block() -> void:
	block = 0
	block_changed.emit(block)

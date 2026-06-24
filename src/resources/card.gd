class_name Card
extends Resource

enum CardType { ATTACK, SKILL, POWER }

@export var card_name: String = "Card"
@export var cost: int = 1
@export var description: String = ""
@export var type: CardType = CardType.ATTACK
@export var icon: Texture2D

func apply_effect(user: Node, target: Node) -> void:
	# Override this in specific card scripts
	pass

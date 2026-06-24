class_name BattleManager
extends Node2D

@export var player: Combatant
@export var enemy: Combatant
@export var card_ui_scene: PackedScene
@export var hand_container: Control
@export var energy_label: Label

@export var initial_deck: Array[Card]

var deck: Array[Card] = []
var discard_pile: Array[Card] = []
var hand: Array[Card] = []

var max_energy: int = 3
var current_energy: int = 0

func _ready() -> void:
	deck = initial_deck.duplicate()
	deck.shuffle()
	
	# Connect combatant UIs
	var player_ui = player.get_node_or_null("PlayerUI")
	if player_ui:
		player_ui.setup(player)
	var enemy_ui = enemy.get_node_or_null("EnemyUI")
	if enemy_ui:
		enemy_ui.setup(enemy)
		
	player.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died)
	start_battle()

func _on_player_died() -> void:
	print("Defeat!")

func _on_enemy_died() -> void:
	print("Victory!")

func start_battle() -> void:
	start_player_turn()

func start_player_turn() -> void:
	current_energy = max_energy
	update_energy_ui()
	player.reset_block()
	draw_cards(5)

func draw_cards(count: int) -> void:
	for i in range(count):
		if deck.is_empty():
			reshuffle_discard_into_deck()
		if deck.is_empty():
			break
		
		var card = deck.pop_back()
		hand.append(card)
		create_card_ui(card)

func reshuffle_discard_into_deck() -> void:
	deck = discard_pile.duplicate()
	discard_pile.clear()
	deck.shuffle()

func create_card_ui(card: Card) -> void:
	var card_ui = card_ui_scene.instantiate()
	hand_container.add_child(card_ui)
	card_ui.set_card(card)
	card_ui.card_clicked.connect(_on_card_clicked)

func _on_card_clicked(card_ui: CardUI) -> void:
	var card = card_ui.card_data
	if current_energy >= card.cost:
		current_energy -= card.cost
		update_energy_ui()
		
		# For this basic framework, let's assume Strike hits enemy and Defend hits self
		if card.type == Card.CardType.ATTACK:
			card.apply_effect(player, enemy)
		else:
			card.apply_effect(player, player)
			
		discard_card(card_ui)
	else:
		print("Not enough energy!")

func discard_card(card_ui: CardUI) -> void:
	var card = card_ui.card_data
	hand.erase(card)
	discard_pile.append(card)
	card_ui.queue_free()

func end_turn() -> void:
	# Discard remaining hand
	for child in hand_container.get_children():
		if child is CardUI:
			discard_card(child)
	
	start_enemy_turn()

func start_enemy_turn() -> void:
	enemy.reset_block()
	# Simple enemy AI: deal 5 damage
	player.take_damage(5)
	
	start_player_turn()

func update_energy_ui() -> void:
	energy_label.text = "Energy: " + str(current_energy) + " / " + str(max_energy)

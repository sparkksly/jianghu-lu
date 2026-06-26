extends Control

signal chosen(reward)

@onready var _btns: Array = [$VBox/Btn0, $VBox/Btn1, $VBox/Btn2]

var _rewards: Array = []

func setup(rewards: Array) -> void:
	_rewards = rewards
	for i in _btns.size():
		var b: Button = _btns[i]
		if i < rewards.size():
			b.visible = true
			b.text = RunRewards.label(rewards[i])
			if not b.pressed.is_connected(_pick):
				b.pressed.connect(_pick.bind(i))
		else:
			b.visible = false

func _pick(i: int) -> void:
	chosen.emit(_rewards[i])

extends Node

@onready var _plan_phase = $PlanPhase
@onready var _watch_phase = $WatchPhase
@onready var _result: Label = $ResultLabel

var _state: CombatState
var _rules: ComboRules
var _deck: Array[Move]
var _ai := AiPlanner.new(12345)
var _round := 0

func _ready() -> void:
	_state = CombatState.new()
	_state.hp = [40, 40]; _state.max_hp = [40, 40]
	_state.sta_max = [10, 10]; _state.stamina = [10, 10]
	_state.n_ticks = 15
	_rules = ComboLibrary.build()
	_deck = Deck.starter()
	_plan_phase.plan_committed.connect(_on_player_plan)
	_watch_phase.finished.connect(_on_watch_done)
	$CodexButton.pressed.connect($Codex.toggle)
	_start_round()

func _start_round() -> void:
	_round += 1
	_state.stamina = _state.sta_max.duplicate()
	_result.visible = false
	# Battle stage (health bars, log) stays visible; only the planning panel toggles.
	_watch_phase.visible = true
	_watch_phase.show_state(_state)
	_plan_phase.visible = true
	_pending_ai_plan = _rules.apply(_ai.plan(_deck, _state.sta_max[1], _state.n_ticks))
	_plan_phase.setup(_deck, _rules, _state.sta_max[0], _state.n_ticks, _ai.intent(_pending_ai_plan, 1))

var _pending_ai_plan: Plan

func _on_player_plan(player_plan: Plan) -> void:
	var before := _state.clone()
	var events := CombatSim.simulate(_state, [player_plan, _pending_ai_plan])
	# Hide only the planning panel; the battle stage plays underneath.
	_plan_phase.visible = false
	_watch_phase.play(before, [player_plan, _pending_ai_plan], events)

func _on_watch_done() -> void:
	if _state.hp[0] <= 0 or _state.hp[1] <= 0:
		_result.visible = true
		_result.text = "胜利!" if _state.hp[1] <= 0 else "败北..."
		# Leave the stage up so the final health bars stay visible behind the result.
		return
	_start_round()

extends Node

signal fight_finished(player_won: bool)

@onready var _plan_phase = $PlanPhase
@onready var _watch_phase = $WatchPhase
@onready var _result: Label = $ResultLabel

var _state: CombatState
var _rules: ComboRules
var _deck: Array[Move]
var _ai: AiPlanner
var _round := 0

# Optional run configuration (set by run.gd before _ready via configure()).
# When empty, the scene runs standalone with default values (still playable on its own).
var _cfg := {}

func configure(player_hp: int, player_max_hp: int, enemy_hp: int, enemy_regen: int, seed: int) -> void:
	_cfg = {
		"hp": player_hp, "mhp": player_max_hp,
		"ehp": enemy_hp, "ereg": enemy_regen, "seed": seed,
	}

func _ready() -> void:
	var p_hp: int = _cfg.get("hp", 40)
	var p_mhp: int = _cfg.get("mhp", 40)
	var e_hp: int = _cfg.get("ehp", 40)
	var e_reg: int = _cfg.get("ereg", 6)
	var seed: int = _cfg.get("seed", 12345)
	_ai = AiPlanner.new(seed)
	_state = CombatState.new()
	_state.hp = [p_hp, e_hp]; _state.max_hp = [p_mhp, e_hp]
	_state.sta_max = [10, 10]; _state.stamina = [10, 10]
	_state.regen = [6, e_reg]
	_state.n_ticks = 12
	_rules = ComboLibrary.build()
	_deck = Deck.starter()
	_plan_phase.plan_committed.connect(_on_player_plan)
	_watch_phase.finished.connect(_on_watch_done)
	$CodexButton.pressed.connect($Codex.toggle)
	_start_round()

func get_player_hp() -> int:
	return _state.hp[0]

func _start_round() -> void:
	_round += 1
	if _round > 1:
		_state.regen_round()  # 跨回合部分回气（不满回）
	_result.visible = false
	# Battle stage (health bars, log) stays visible; only the planning panel toggles.
	_watch_phase.visible = true
	_watch_phase.show_state(_state)
	_plan_phase.visible = true
	_pending_ai_plan = _rules.apply(_ai.plan(_deck, _state.stamina[1], _state.n_ticks))
	_plan_phase.setup(_deck, _rules, _state.stamina[0], _state.sta_max[0], _state.n_ticks, _ai.intent(_pending_ai_plan, 1))

var _pending_ai_plan: Plan

func _on_player_plan(player_plan: Plan) -> void:
	var before := _state.clone()
	var events := CombatSim.simulate(_state, [player_plan, _pending_ai_plan])
	# Hide only the planning panel; the battle stage plays underneath.
	_plan_phase.visible = false
	_watch_phase.play(before, [player_plan, _pending_ai_plan], events)

func _on_watch_done() -> void:
	if _state.hp[0] <= 0 or _state.hp[1] <= 0:
		var player_won := _state.hp[1] <= 0 and _state.hp[0] > 0  # double-KO counts as a loss
		_result.visible = true
		_result.text = "胜利!" if player_won else "败北..."
		# Leave the stage up so the final health bars stay visible behind the result.
		fight_finished.emit(player_won)
		return
	_start_round()

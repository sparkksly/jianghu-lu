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
var _rng := RandomNumberGenerator.new()
var _pool: Array[Move] = []

# Optional run configuration (set by run.gd before _ready via configure()).
# When empty, the scene runs standalone with default values (still playable on its own).
var _cfg := {}

func configure(player_hp: int, player_max_hp: int, enemy_hp: int, enemy_regen: int, seed: int, menpai_id := &"shaolin", learned := [], bonus_qi := 0) -> void:
	_cfg = {
		"hp": player_hp, "mhp": player_max_hp,
		"ehp": enemy_hp, "ereg": enemy_regen, "seed": seed,
		"menpai": menpai_id, "learned": learned, "bonus_qi": bonus_qi,
	}

func _ready() -> void:
	var p_hp: int = _cfg.get("hp", 40)
	var p_mhp: int = _cfg.get("mhp", 40)
	var e_hp: int = _cfg.get("ehp", 40)
	var e_reg: int = _cfg.get("ereg", 6)
	var seed: int = _cfg.get("seed", 12345)
	var menpai_id: StringName = _cfg.get("menpai", &"shaolin")
	var learned: Array = _cfg.get("learned", [])
	if learned.is_empty():
		learned = Menpai.starter_learned(menpai_id)
	var bonus_qi: int = _cfg.get("bonus_qi", 0)
	_ai = AiPlanner.new(seed)
	_state = CombatState.new()
	_state.hp = [p_hp, e_hp]; _state.max_hp = [p_mhp, e_hp]
	_state.sta_max = [10 + bonus_qi, 10]; _state.stamina = [10 + bonus_qi, 10]
	_state.regen = [6, e_reg]
	_state.n_ticks = 15
	_rules = Arts.build_rules(learned)   # 连招规则 = 已领悟绝学
	_deck = Deck.starter()
	_rng.seed = seed
	_pool = Menpai.pool(menpai_id)   # 进攻牌共享基础动作池
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
	_pending_ai_plan = _rules.apply(_ai.plan(_deck, _state.stamina[1], _state.n_ticks, _state.distance))
	# 本回合手牌:固定工具牌 + 有放回抽 6 张进攻牌(可重复、一次性消耗)
	var hand: Array[Move] = Hand.utilities(_deck)
	hand.append_array(Hand.draw(_pool, 6, _rng))
	_plan_phase.setup(hand, _rules, _state.stamina[0], _state.sta_max[0], _state.n_ticks, _ai.intent(_pending_ai_plan, 1))

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

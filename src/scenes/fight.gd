extends Node

signal fight_finished(player_won: bool)

@onready var _plan_phase = $PlanPhase
@onready var _watch_phase = $WatchPhase
@onready var _result: Label = $ResultLabel

var _state: CombatState
var _rules: ComboRules
var _ai: AiPlanner
var _enemy_deck: Array[Move] = []
var _enemy_name := "对手"
var _round := 0
var _rng := RandomNumberGenerator.new()
var _pool: Array[Move] = []
var _defense_pool: Array[Move] = []   # 防御牌(格挡/闪身):每回合限量抽,不再无限免费
const DEFENSE_CARDS := 2              # 每回合给的防御牌数 → 防不住所有,逼出取舍
var _weight: Dictionary = {}
var _landed: Dictionary = {}   # 本场玩家命中过的招(去重)→ 战后加熟练
var _stats: Dictionary = {"tag_hits": {}, "tag_two_combo": {}}   # 本场行为→实战顿悟

# Optional run configuration (set by run.gd before _ready via configure()).
# When empty, the scene runs standalone with default values (still playable on its own).
var _cfg := {}

func configure(cfg: Dictionary) -> void:
	_cfg = cfg

func _ready() -> void:
	var p_hp: int = _cfg.get("player_hp", 40)
	var p_mhp: int = _cfg.get("player_max_hp", 40)
	var seed: int = _cfg.get("seed", 12345)
	var menpai_id: StringName = _cfg.get("menpai", &"shaolin")
	var learned: Array = _cfg.get("learned", [])
	if learned.is_empty():
		learned = Menpai.starter_pool(menpai_id).slice(0, 2)
	var max_qi: int = _cfg.get("max_qi", 10)
	var evo: Dictionary = _cfg.get("evo", {})
	_weight = _cfg.get("weight", {})
	var compiled: Array = _cfg.get("compiled", [])
	var attack: int = _cfg.get("attack", 10)
	var dmg_inc: int = _cfg.get("dmg_inc", 0)
	var extra: int = _cfg.get("extra_dmg", 0)
	var armor: int = _cfg.get("armor", 0)
	var enemy: Dictionary = _cfg.get("enemy", {})
	var e_hp: int = enemy.get("hp", 40)
	var e_reg: int = enemy.get("regen", 6)
	var e_pool: Array = enemy.get("pool", [])
	if e_pool.is_empty():
		e_pool = [&"jab", &"hook", &"push_palm", &"snap_kick"]
	_enemy_name = enemy.get("name", "对手")
	_ai = AiPlanner.new(seed)
	_state = CombatState.new()
	_state.hp = [p_hp, e_hp]; _state.max_hp = [p_mhp, e_hp]
	_state.sta_max = [max_qi, 10]; _state.stamina = [max_qi, 10]
	_state.triggers = [_cfg.get("triggers", []), []]
	_state.regen = [6, e_reg]
	_state.n_ticks = 11
	_state.attack = [attack, int(enemy.get("attack", 10))]
	_state.dmg_inc = [dmg_inc, int(enemy.get("dmg_inc", 0))]
	_state.extra_dmg = [extra, 0]
	_state.armor = [armor, int(enemy.get("armor", 0))]
	_rules = Arts.build_rules(learned, evo)
	_rng.seed = seed
	# 玩家抽牌池 = 全部 9 门基础招(应用进化) + 化境绝学单卡;攻击力走 state.attack
	_pool.clear()
	for m in Deck.basic_attacks():
		_pool.append(Evolve.apply(m, evo.get(m.id, {})))
	for cid in compiled:
		var res = Arts.recipe(cid).get("result", null)
		if res != null:
			_pool.append(Evolve.apply(res, evo.get(cid, {})))
	# 防御牌池(格挡/闪身):每回合限量抽,稀缺逼取舍
	_defense_pool.clear()
	for m in Hand.utilities(Deck.starter()):
		if m.kind == Move.Kind.BLOCK or m.kind == Move.Kind.DODGE:
			_defense_pool.append(m)
	# 敌人:专属招池 + 通用工具牌(步/挡/闪/拿)
	_enemy_deck.clear()
	for id in e_pool:
		var em = Deck.by_id(id)
		if em != null:
			_enemy_deck.append(em)
	_enemy_deck.append_array(Hand.utilities(Deck.starter()))
	_plan_phase.plan_committed.connect(_on_player_plan)
	_watch_phase.finished.connect(_on_watch_done)
	$CodexButton.pressed.connect($Codex.toggle)
	_watch_phase.get_node("P1Name").text = _enemy_name
	_stats = {"tag_hits": {}, "tag_two_combo": {}}
	$Codex.set_learned(learned)
	_start_round()

func get_player_hp() -> int:
	return _state.hp[0]

# 本场玩家命中过的招(去重)→ run 战后加熟练。
func moves_landed() -> Array:
	return _landed.keys()

func combat_stats() -> Dictionary:
	return _stats

# 统计本回合玩家施展的招(按 tag 计数 + 两连同 tag)→ 实战顿悟。
func _tally(plan: Plan) -> void:
	var th: Dictionary = _stats["tag_hits"]
	var tc: Dictionary = _stats["tag_two_combo"]
	var s := plan.sorted()
	for i in s.size():
		var mv: Move = s[i].move
		for tag in mv.tags:
			th[tag] = int(th.get(tag, 0)) + 1
		if Loc.is_combo_result(mv.id):   # 连招本身算"两连"
			for tag in mv.tags:
				tc[tag] = true
		if i > 0:                         # 相邻两招同 tag 也算两连
			for tag in mv.tags:
				if tag in (s[i - 1].move as Move).tags:
					tc[tag] = true

func _start_round() -> void:
	_round += 1
	if _round > 1:
		_state.regen_round()  # 跨回合部分回气（不满回）
	_result.visible = false
	# Battle stage (health bars, log) stays visible; only the planning panel toggles.
	_watch_phase.visible = true
	_watch_phase.show_state(_state)
	_plan_phase.visible = true
	_pending_ai_plan = _ai.plan(_enemy_deck, _state.stamina[1], _state.n_ticks, _state.distance)
	# 本回合手牌:走位/擒拿固定给 + 防御限量抽 + 进攻有放回抽(一次性消耗)
	var hand: Array[Move] = []
	for m in Hand.utilities(Deck.starter()):
		if m.kind == Move.Kind.STEP or m.kind == Move.Kind.THROW:
			hand.append(m)   # 走位+擒拿:基础操控,固定给
	if not _defense_pool.is_empty():
		hand.append_array(Hand.draw(_defense_pool, DEFENSE_CARDS, _rng))   # 防御:限量
	hand.append_array(Hand.draw(_pool, _cfg.get("hand_size", 6), _rng, _weight))
	# 意图全显示(动作可见、顺序可见;但 plan_phase 不绑拍号 → 时机仍需赌)
	_plan_phase.setup(hand, _rules, _state.stamina[0], _state.sta_max[0], _state.n_ticks, _ai.intent(_pending_ai_plan, 999))

var _pending_ai_plan: Plan

func _on_player_plan(player_plan: Plan) -> void:
	var before := _state.clone()
	var events := CombatSim.simulate(_state, [player_plan, _pending_ai_plan])
	for e in events:   # 收集本场玩家命中的招 → 战后加熟练
		if e.type == &"hit" and e.actor == 0 and e.move_id != &"":
			_landed[e.move_id] = true
	_tally(player_plan)
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

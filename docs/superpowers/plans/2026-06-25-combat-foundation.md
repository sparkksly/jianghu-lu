# 战斗地基 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让「拍」与「体力」各司其职——拍定死 10 拍为定时画布，体力改为跨回合部分回气的强度/续航资源，且永不把玩家逼到"只能挨打"。

**Architecture:** 纯数据层 `CombatState` 持有体力并新增 `regen` 与 `regen_round()`；规则层 `Plan.is_valid` 的超额上限从"绝对 1.5×上限"改为"相对当前气 + 固定缓冲"；`fight.gd` 删掉每回合满回、改为回合开始调用 `regen_round()`；AI 与排招 UI 都改用"当前气"而非"上限"。确定性战斗模拟器 `combat_sim.gd` **完全不动**（回合内手感保留）。

**Tech Stack:** Godot 4.6.1 / GDScript，GUT 单元测试（`bash run_tests.sh`）。

## Global Constraints

- **拍数 `n_ticks` = 10**，定死（生产配置；测试可传不同值以测函数）。
- **体力是"气"，不是血条**：跨回合部分回气、地板 0、无死亡螺旋。
- **反捉襟见肘硬约束**：`regen ≥ 2 × 基础招花费`（基础招=2，故 `regen ≥ 4`）；防守招净回气 ≥ 0；任何回合都出得起基础招。
- 起始数值：`sta_max=10`、`regen=6`、`OVERCOMMIT_BUFFER=3`、基础招花费=2。
- `combat_sim.gd` 的回合内逻辑（扣气/喘息/命中奖励/挥空惩罚）**不得修改**。
- 每个 Task 结束后 `bash run_tests.sh` 必须全绿再提交。
- 提交信息结尾附：`Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

---

### Task 1: CombatState 增加 regen 与跨回合回气

**Files:**
- Modify: `src/combat/combat_state.gd`
- Test: `test/unit/test_stamina_economy.gd` (create)

**Interfaces:**
- Produces:
  - `CombatState.regen: Array[int]`（默认 `[6, 6]`）
  - `CombatState.regen_round() -> void`：对双方 `stamina[i] = min(sta_max[i], stamina[i] + regen[i])`
  - `CombatState.clone()` 复制 `regen`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_stamina_economy.gd`:

```gdscript
extends GutTest

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [40, 40]; s.max_hp = [40, 40]
	s.sta_max = [10, 10]; s.stamina = [10, 10]; s.regen = [6, 6]
	s.n_ticks = 10
	return s

func test_regen_round_adds_regen_capped_at_max():
	var s := _state()
	s.stamina = [3, 4]
	s.regen_round()
	assert_eq(s.stamina, [9, 10], "3+6=9, 4+6=10")

func test_regen_round_never_exceeds_sta_max():
	var s := _state()
	s.stamina = [8, 9]
	s.regen_round()
	assert_eq(s.stamina, [10, 10], "capped at sta_max, NOT 14/15")

func test_regen_is_not_full_refill():
	var s := _state()
	s.stamina = [0, 0]
	s.regen_round()
	assert_eq(s.stamina, [6, 6], "partial regen, not a full reset to 10")

func test_anti_starvation_regen_covers_two_basics():
	# Design invariant: regen must afford at least 2 basic moves (cost 2 each).
	var s := _state()
	assert_true(s.regen[0] >= 4, "regen >= 2 basic-move costs so you can always act")

func test_clone_copies_regen():
	var s := _state()
	var c := s.clone()
	c.regen[0] = 99
	assert_eq(s.regen[0], 6, "clone must deep-copy regen, not alias")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash run_tests.sh -gselect=test_stamina_economy.gd`
Expected: FAIL — `Invalid set ... 'regen'` / `Nonexistent function 'regen_round'`.

- [ ] **Step 3: Write minimal implementation**

In `src/combat/combat_state.gd`, add the `regen` field after `sta_max` and the method + clone copy:

```gdscript
var sta_max: Array[int] = [10, 10]
var regen: Array[int] = [6, 6]  # 每回合开始回气量（内功流派更高）
var n_ticks: int = 10
```

Add method (anywhere in the class body):

```gdscript
func regen_round() -> void:
	for i in stamina.size():
		stamina[i] = min(sta_max[i], stamina[i] + regen[i])
```

In `clone()`, add the regen copy (alongside the other duplicates):

```gdscript
	c.regen = regen.duplicate()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash run_tests.sh -gselect=test_stamina_economy.gd`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add src/combat/combat_state.gd test/unit/test_stamina_economy.gd
git commit -m "feat(combat): CombatState.regen + 跨回合部分回气 regen_round()

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: 超额上限改为相对当前气 + 固定缓冲

**Files:**
- Modify: `src/combat/plan.gd`
- Modify: `src/scenes/timeline_logic.gd`
- Test: `test/unit/test_plan.gd:20-26` (rewrite overcommit test)
- Test: `test/unit/test_timeline_logic.gd:27-30` (rewrite overcommit test)

**Interfaces:**
- Consumes: `CombatState`（无新依赖）
- Produces:
  - `Plan.OVERCOMMIT_BUFFER := 3`
  - `Plan.is_valid(stamina_now: int, n_ticks: int) -> bool`（首参由 `sta_max` 改为 `stamina_now`；上限 = `stamina_now + OVERCOMMIT_BUFFER`）
  - `TimelineLogic.can_place(plan, move, start, stamina_now: int, n_ticks: int, ignore_index := -1) -> bool`（第 4 参语义由 sta_max 改为 stamina_now，透传给 `is_valid`）

- [ ] **Step 1: Rewrite the failing tests**

In `test/unit/test_plan.gd`, replace `test_overcommit_allowed_up_to_1_5x` with:

```gdscript
func test_overcommit_up_to_current_plus_buffer():
	# cap = stamina_now + OVERCOMMIT_BUFFER (10 + 3 = 13)
	var p := Plan.new()
	p.add(PlacedMove.new(_atk(13), 0))
	assert_true(p.is_valid(10, 10), "13 == current(10)+buffer(3)")
	var p2 := Plan.new()
	p2.add(PlacedMove.new(_atk(14), 0))
	assert_false(p2.is_valid(10, 10), "14 over current+buffer")

func test_overcommit_scales_with_current_stamina():
	# at low current stamina you can plan far less
	var p := Plan.new()
	p.add(PlacedMove.new(_atk(7), 0))
	assert_true(p.is_valid(4, 10), "7 == current(4)+buffer(3)")
	var p2 := Plan.new()
	p2.add(PlacedMove.new(_atk(8), 0))
	assert_false(p2.is_valid(4, 10), "8 over current(4)+buffer(3)")
```

In `test/unit/test_timeline_logic.gd`, replace `test_can_place_respects_overcommit` with:

```gdscript
func test_can_place_respects_overcommit():
	# stamina_now=10 -> cap 13
	var p := TimelineLogic.with_move(Plan.new(), _atk(11,1,1,1), 0) # cost 11
	assert_true(TimelineLogic.can_place(p, _atk(2,1,1,1), 3, 10, 14), "13 total == cap")
	assert_false(TimelineLogic.can_place(p, _atk(3,1,1,1), 3, 10, 14), "14 total over cap")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash run_tests.sh -gselect=test_plan.gd` then `bash run_tests.sh -gselect=test_timeline_logic.gd`
Expected: the new overcommit tests FAIL (old cap `floor(1.5*sta_max)` still active → `_atk(14)` wrongly valid; `_atk(3)`→14 wrongly... ) — confirm red.

- [ ] **Step 3: Implement the new rule**

In `src/combat/plan.gd`, add the constant near the top of the class and change `is_valid`:

```gdscript
const OVERCOMMIT_BUFFER := 3

func is_valid(stamina_now: int, n_ticks: int) -> bool:
	if total_cost() > stamina_now + OVERCOMMIT_BUFFER:
		return false
	var s := sorted()
	var last_end := -1
	for pm in s:
		if pm.start < 0 or pm.start >= n_ticks:
			return false
		if pm.end_tick() > n_ticks:
			return false # move would spill past the timeline grid
		if pm.start < last_end:
			return false # overlap
		last_end = pm.end_tick()
	return true
```

In `src/scenes/timeline_logic.gd`, rename the param for clarity and forward it:

```gdscript
static func can_place(plan: Plan, move: Move, start: int, stamina_now: int, n_ticks: int, ignore_index: int = -1) -> bool:
	var base := plan if ignore_index < 0 else without_index(plan, ignore_index)
	var trial := with_move(base, move, start)
	return trial.is_valid(stamina_now, n_ticks)
```

- [ ] **Step 4: Run the full suite to verify green**

Run: `bash run_tests.sh`
Expected: PASS. (`test_ai.gd` calls `is_valid(10,10)` — value-compatible: cap 13 ≥ AI plan cost ≤ 10. `test_plan_phase.gd` still passes `_sta_max=10` as the 3rd setup arg until Task 4; its drops total ≤ 6 ≤ 13.)

- [ ] **Step 5: Commit**

```bash
git add src/combat/plan.gd src/scenes/timeline_logic.gd test/unit/test_plan.gd test/unit/test_timeline_logic.gd
git commit -m "feat(combat): 超额上限改为相对当前气+OVERCOMMIT_BUFFER

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: AI 在「当前气」预算内排招

**Files:**
- Modify: `src/ai/ai_planner.gd:9-26`
- Test: `test/unit/test_balance.gd` (switch refill→regen, pass current stamina)

**Interfaces:**
- Consumes: `Plan.is_valid(stamina_now, n_ticks)`、`CombatState.regen_round()`
- Produces: `AiPlanner.plan(deck: Array[Move], stamina_now: int, n_ticks: int) -> Plan`（预算 = `stamina_now`，不超额、不自我喘息）

- [ ] **Step 1: Update the balance harness to the new economy (failing)**

In `test/unit/test_balance.gd`, replace the round loop so it uses regen instead of full refill and feeds current stamina to the AI:

```gdscript
func test_ai_vs_ai_fights_terminate_and_deal_damage():
	var wins := [0, 0]
	for seed in range(20):
		var s := CombatState.new()
		s.hp=[40,40]; s.max_hp=[40,40]; s.sta_max=[10,10]; s.stamina=[10,10]; s.regen=[6,6]; s.n_ticks=10
		var a := AiPlanner.new(seed)
		var b := AiPlanner.new(seed + 1000)
		var rules := ComboLibrary.build()
		var rounds := 0
		while s.hp[0] > 0 and s.hp[1] > 0 and rounds < 60:
			if rounds > 0:
				s.regen_round()
			var pa := rules.apply(a.plan(Deck.starter(), s.stamina[0], s.n_ticks))
			var pb := rules.apply(b.plan(Deck.starter(), s.stamina[1], s.n_ticks))
			CombatSim.simulate(s, [pa, pb])
			rounds += 1
		assert_true(rounds < 60, "fight %d terminated under regen economy" % seed)
		if s.hp[0] <= 0: wins[1] += 1
		elif s.hp[1] <= 0: wins[0] += 1
	gut.p("AI win split: %s" % str(wins))
	assert_true(wins[0] + wins[1] > 0, "at least some fights resolved")
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash run_tests.sh -gselect=test_balance.gd`
Expected: FAIL — `ai_planner.plan` still budgets `floor(1.5*sta_max)`; passing `s.stamina` works value-wise but the intent/budget is wrong; primarily this step locks the new call shape. (If it happens to pass, proceed — Step 3 still required to make budget intent correct.)

- [ ] **Step 3: Change the AI budget to current stamina**

In `src/ai/ai_planner.gd`, change the signature and budget line:

```gdscript
func plan(deck: Array[Move], stamina_now: int, n_ticks: int) -> Plan:
	var p := Plan.new()
	var budget := stamina_now  # plan within what you actually have; no self-gasp
	var spent := 0
	var t := 0
	var guard := 0
	while t < n_ticks and guard < 50:
		guard += 1
		var m: Move = deck[_rng.randi_range(0, deck.size() - 1)]
		if spent + m.stamina_cost > budget:
			break
		if t + m.total_duration() > n_ticks:
			t += 1
			continue
		p.add(PlacedMove.new(m, t))
		spent += m.stamina_cost
		t += m.total_duration()
	return p
```

- [ ] **Step 4: Run the full suite**

Run: `bash run_tests.sh`
Expected: PASS. (`test_ai.gd` `a.plan(Deck.starter(), 10, 10)` → budget 10, plan ≤ 10, `is_valid(10,10)` cap 13 ✓.)

- [ ] **Step 5: Commit**

```bash
git add src/ai/ai_planner.gd test/unit/test_balance.gd
git commit -m "feat(ai): AI 在当前气预算内排招 + balance 用跨回合回气

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: 实战循环——跨回合回气 + 10 格时间轴 + UI 显示当前气

**Files:**
- Modify: `src/scenes/fight.gd`
- Modify: `src/scenes/plan_phase.gd`
- Modify: `src/scenes/plan_phase.tscn`
- Test: `test/unit/test_fight.gd`
- Test: `test/unit/test_plan_phase.gd`

**Interfaces:**
- Consumes: `CombatState.regen_round()`、`Plan.OVERCOMMIT_BUFFER`、`TimelineLogic.can_place(...,stamina_now,...)`、`AiPlanner.plan(deck, stamina_now, n_ticks)`
- Produces: `PlanPhase.setup(deck, rules, stamina_now: int, sta_max: int, n_ticks: int, enemy_intent: Array)`

- [ ] **Step 1: Update tests to the new wiring (failing)**

In `test/unit/test_fight.gd`, replace `test_fight_uses_15_ticks` and add a stamina test:

```gdscript
func test_fight_uses_10_ticks():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_eq(w._state.n_ticks, 10)

func test_fight_round_one_starts_full_stamina():
	var w = load("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await get_tree().process_frame
	assert_eq(w._state.stamina, w._state.sta_max, "round 1 opens at full 气")
	assert_eq(w._state.regen, [6, 6], "regen configured")
```

In `test/unit/test_plan_phase.gd`, update EVERY `setup(...)` call to the 6-arg signature (insert `stamina_now` before `sta_max`, set `n_ticks=10`), and fix the one far placement. Concretely:
- `test_timeline_node_is_the_drop_target`: `w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 10, ["？"])`
- `test_setup_builds_hand_and_intent_is_chinese`: `w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 10, ["扫腿", "？"])`
- `test_drop_places_and_combo_fuses_on_commit`: `w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 10, ["？"])`
- `test_overlap_drop_rejected`: `w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 10, ["？"])`
- `test_remove_frees_slot`: `w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 10, ["？"])`
- `test_move_existing_repositions`: `w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 10, ["？"])` and change `var far_x = 8 * 40.0` to `var far_x = 6 * 40.0` and the assertion to `assert_true(w._plan.sorted()[0].start >= 6, ...)` (low_kick dur 3 → end 9 ≤ 10).

- [ ] **Step 2: Run to verify failure**

Run: `bash run_tests.sh -gselect=test_fight.gd` then `-gselect=test_plan_phase.gd`
Expected: FAIL — `n_ticks` is 15; `setup()` arity mismatch (`Too few arguments` once tests pass 6 args to the old 5-arg function).

- [ ] **Step 3: Update `plan_phase.gd` (current-气 wiring + label)**

In `src/scenes/plan_phase.gd`:

Add the field next to the others:

```gdscript
var _stamina_now := 10
```

Change `setup` signature + body head:

```gdscript
func setup(deck: Array[Move], rules: ComboRules, stamina_now: int, sta_max: int, n_ticks: int, enemy_intent: Array) -> void:
	_deck = deck; _rules = rules; _stamina_now = stamina_now; _sta_max = sta_max; _n_ticks = n_ticks
	_plan = Plan.new()
	_intent.text = "对手意图: " + ", ".join(enemy_intent)
	_build_deck()
	_redraw_timeline()
	_refresh_labels()
	if not _commit.pressed.is_connected(_on_commit):
		_commit.pressed.connect(_on_commit)
```

In `_refresh_labels`, replace the stamina line:

```gdscript
	_stamina.text = "气 %d/%d  已排%d (可超至%d)" % [_stamina_now, _sta_max, _plan.total_cost(), _stamina_now + Plan.OVERCOMMIT_BUFFER]
```

In `try_drop_new` and `try_move_existing`, replace `_sta_max` with `_stamina_now` in the `TimelineLogic.can_place(...)` calls (two call sites):

```gdscript
	if TimelineLogic.can_place(_plan, move, tick, _stamina_now, _n_ticks):
```
```gdscript
	if TimelineLogic.can_place(_plan, pm.move, tick, _stamina_now, _n_ticks, raw):
```

- [ ] **Step 4: Update `plan_phase.tscn` (10 cells + label reflow)**

In `src/scenes/plan_phase.tscn`, change the Timeline node to 10 cells (10×40=400 wide) and shift the right-hand label column left so it sits beside the narrower timeline:

```
[node name="Timeline" type="Control" parent="."]
offset_left = 56.0
offset_top = 442.0
offset_right = 456.0
offset_bottom = 486.0
custom_minimum_size = Vector2(400, 44)
script = ExtResource("2_tldrop")
```

Change `StaminaLabel`, `ComboPreview`, `EnemyIntent` `offset_left` from `700.0` to `480.0` (leave their `offset_right = 1096.0`).

- [ ] **Step 5: Update `fight.gd` (n_ticks=10, regen, wire current stamina)**

In `src/scenes/fight.gd` `_ready`, set the tick count to 10 and configure regen:

```gdscript
	_state.sta_max = [10, 10]; _state.stamina = [10, 10]
	_state.regen = [6, 6]
	_state.n_ticks = 10
```

Replace `_start_round` body (drop full refill, add cross-round regen, pass current stamina):

```gdscript
func _start_round() -> void:
	_round += 1
	if _round > 1:
		_state.regen_round()  # 跨回合部分回气（不满回）
	_result.visible = false
	_watch_phase.visible = true
	_watch_phase.show_state(_state)
	_plan_phase.visible = true
	_pending_ai_plan = _rules.apply(_ai.plan(_deck, _state.stamina[1], _state.n_ticks))
	_plan_phase.setup(_deck, _rules, _state.stamina[0], _state.sta_max[0], _state.n_ticks, _ai.intent(_pending_ai_plan, 1))
```

- [ ] **Step 6: Run the full suite**

Run: `bash run_tests.sh`
Expected: PASS — all scripts green.

- [ ] **Step 7: Visual smoke-check**

Create `_shot.gd` at repo root:

```gdscript
extends SceneTree
func _initialize() -> void:
	var scn = load("res://src/scenes/fight.tscn").instantiate()
	root.add_child(scn)
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png("res://_shot.png")
	quit()
```

Run: `"/c/Users/Tianyu/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --path . -s _shot.gd`
Open `_shot.png`; confirm the timeline shows **10** cells and the 气 label reads `气 10/10  已排0 (可超至13)`. Then delete the temp files:

```bash
rm _shot.gd _shot.png
```

- [ ] **Step 8: Commit**

```bash
git add src/scenes/fight.gd src/scenes/plan_phase.gd src/scenes/plan_phase.tscn test/unit/test_fight.gd test/unit/test_plan_phase.gd
git commit -m "feat(combat): 实战循环跨回合回气 + 10 格时间轴 + UI 显示当前气

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## 验收对照（实现完成后人工核对）

- [ ] 拍 = 10，时间轴正好 10 格，招式不溢出（`end_tick ≤ 10`）。
- [ ] 体力跨回合**不满回**：上一轮花掉的气，下一轮只回 `regen`（≈6），`min(sta_max)` 封顶。
- [ ] 首回合开局气满。
- [ ] 超额可至「当前气 + 3」；低气回合可排量自动变少。
- [ ] 排招面板体力标签显示**当前气**而非上限。
- [ ] 反捉襟见肘：`regen ≥ 4`（=2 个基础招），防守招（格挡 +1）净回气 ≥ 0。
- [ ] AI 在当前气预算内排招；self-play 在 60 回合内终结。
- [ ] `combat_sim.gd` 未改动。

# 切片1：距离轴 + 技法家族基础招 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给战斗加一条共享"距离"轴(贴身/中/远),把基础招重做成有画面感的技法家族(拳/掌/肘膝/腿/防/闪/拿/步),攻击命中按距离 gate。

**Architecture:** 距离是 `CombatState.distance`。新招式类型 `STEP` 带 `distance_delta`,在确定性模拟器 `combat_sim` 的 tick 循环里**先结算步法改距离、再用新距离判攻击命中**;攻击带 `range_min/max`,够不着→挥空;两个轻量词缀 `knockback`(击退)/`stun`(踉跄)。模拟器是纯逻辑、GUT 单测;表现层只读事件。

**Tech Stack:** Godot 4.6.1 / GDScript,GUT(`bash run_tests.sh`)。

## Global Constraints

- 距离 `D ∈ {贴身=0, 中=1, 远=2}`,**开局 D=1**,`clamp(0,2)`。
- **本拍内顺序**:先结算 STEP 改距离,再用更新后的距离判攻击命中。
- **上步=1拍、撤步=2拍**(进快退慢);STEP 气耗=1。
- 攻击(ATTACK/THROW)命中前查 `range_min ≤ D ≤ range_max`;否则**挥空**(`_whiff` 的体力惩罚 + 发 `&"reach"` 事件)。BLOCK/DODGE/STEP 不查距离。
- **击退**:命中成功后 `D=min(2,D+1)`。**踉跄**:命中后 `defender.gasp_until = t + stun`(复用喘息=跳招)。
- 距离不影响闪避。`combat_sim` 的回合内既有手感(扣气/喘息/格挡/打断/优先)不变。
- 起始数值见 spec `2026-06-25-slice1-distance-base-moves-design.md`,以那为准。
- 每个 Task 结束 `bash run_tests.sh` 必须全绿再提交。
- 提交信息结尾:`Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

---

### Task 1: Move 结构 — STEP 类型 + 距离/词缀字段

**Files:**
- Modify: `src/combat/move.gd`
- Test: `test/unit/test_move.gd`

**Interfaces:**
- Produces:
  - `Move.Kind.STEP`(枚举新增)
  - `Move.range_min:int=0`、`Move.range_max:int=2`、`Move.distance_delta:int=0`、`Move.knockback:bool=false`、`Move.stun:int=0`
  - `Move.in_range(d:int) -> bool`

- [ ] **Step 1: Write the failing test** — append to `test/unit/test_move.gd`:

```gdscript
func test_step_kind_and_distance_fields():
	var m := Move.new()
	m.kind = Move.Kind.STEP
	m.distance_delta = -1
	assert_eq(m.kind, Move.Kind.STEP)
	assert_eq(m.distance_delta, -1)

func test_in_range_band():
	var m := Move.new()
	m.range_min = 0; m.range_max = 1   # 贴身~中
	assert_true(m.in_range(0))
	assert_true(m.in_range(1))
	assert_false(m.in_range(2), "中~远 band excludes 远")

func test_range_defaults_any():
	var m := Move.new()
	assert_true(m.in_range(0) and m.in_range(1) and m.in_range(2), "default band = 任意距离")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash run_tests.sh -gselect=test_move.gd`
Expected: FAIL — `Invalid ... 'STEP'` / `Nonexistent function 'in_range'`.

- [ ] **Step 3: Implement** — in `src/combat/move.gd`:

Change the enum:
```gdscript
enum Kind { ATTACK, BLOCK, DODGE, THROW, STEP }
```
Add the fields after `is_heavy`:
```gdscript
@export var range_min: int = 0     # 适用距离带 [min,max]，默认任意
@export var range_max: int = 2
@export var distance_delta: int = 0  # STEP 用：上步-1 / 撤步+1
@export var knockback: bool = false  # 击退：命中后距离+1
@export var stun: int = 0            # 踉跄：命中令对手跳 N 拍
```
Add the helper (anywhere in the class):
```gdscript
func in_range(d: int) -> bool:
	return range_min <= d and d <= range_max
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash run_tests.sh -gselect=test_move.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/combat/move.gd test/unit/test_move.gd
git commit -m "feat(combat): Move 加 STEP 类型 + 距离带/击退/踉跄字段

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: CombatState.distance

**Files:**
- Modify: `src/combat/combat_state.gd`
- Test: `test/unit/test_distance.gd` (create)

**Interfaces:**
- Produces: `CombatState.distance: int = 1`(`clone()` 复制)

- [ ] **Step 1: Write the failing test** — create `test/unit/test_distance.gd`:

```gdscript
extends GutTest

func test_distance_defaults_to_mid_and_clones():
	var s := CombatState.new()
	assert_eq(s.distance, 1, "开局中距")
	s.distance = 0
	var c := s.clone()
	assert_eq(c.distance, 0)
	c.distance = 2
	assert_eq(s.distance, 0, "clone is independent")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash run_tests.sh -gselect=test_distance.gd`
Expected: FAIL — `Invalid get ... 'distance'`.

- [ ] **Step 3: Implement** — in `src/combat/combat_state.gd`:

Add the field after `gasp_len`:
```gdscript
var distance: int = 1  # 共享距离 0贴身/1中/2远
```
In `clone()`, add before `return c`:
```gdscript
	c.distance = distance
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash run_tests.sh -gselect=test_distance.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/combat/combat_state.gd test/unit/test_distance.gd
git commit -m "feat(combat): CombatState.distance(开局中距) + clone

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: 模拟器 — STEP 改距离(同拍求和 + clamp + 事件)

**Files:**
- Modify: `src/combat/combat_sim.gd`
- Test: `test/unit/test_distance.gd`

**Interfaces:**
- Consumes: `Move.Kind.STEP`、`Move.distance_delta`、`CombatState.distance`
- Produces: `CombatSim.simulate` 在 STEP 命中拍改 `state.distance`;发 `CombatEvent(t, &"distance", -1, -1, new_distance, &"")`

- [ ] **Step 1: Write the failing test** — append to `test/unit/test_distance.gd`:

```gdscript
func _state() -> CombatState:
	var s := CombatState.new()
	s.hp=[40,40]; s.max_hp=[40,40]; s.stamina=[10,10]; s.sta_max=[10,10]; s.regen=[6,6]; s.n_ticks=12
	s.distance = 1
	return s

func _step(delta) -> Move:
	var m := Move.new(); m.id = &"step"; m.kind = Move.Kind.STEP
	m.startup=0; m.active=1; m.recovery=(0 if delta < 0 else 1)  # 上步1拍/撤步2拍
	m.distance_delta = delta; m.stamina_cost = 1
	return m

func test_step_in_reduces_distance():
	var s := _state()
	var p0 := Plan.new(); p0.add(PlacedMove.new(_step(-1), 0))   # 上步 at tick0
	CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.distance, 0, "上步 → 贴身")

func test_same_tick_steps_cancel():
	var s := _state()
	var p0 := Plan.new(); p0.add(PlacedMove.new(_step(-1), 0))   # 进
	var p1 := Plan.new(); p1.add(PlacedMove.new(_step(1), 0))    # 退,同拍
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.distance, 1, "一进一退抵消")

func test_distance_clamps():
	var s := _state(); s.distance = 0
	var p0 := Plan.new(); p0.add(PlacedMove.new(_step(-1), 0))   # 再进也不能 < 0
	CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.distance, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash run_tests.sh -gselect=test_distance.gd`
Expected: FAIL — distance unchanged (sim ignores STEP) / 或 STEP 被当攻击.

- [ ] **Step 3: Implement** — in `src/combat/combat_sim.gd`, inside `simulate`'s `while` loop, **after** the "1. start moves" block and **before** "2. snapshot", insert a STEP-resolution phase:

```gdscript
		# 1.5 STEP: resolve distance changes this tick (sum both, apply once)
		var ddelta := 0
		for i in 2:
			var a: _Actor = actors[i]
			if a.cur != null and a.cur.move.kind == Move.Kind.STEP and a.elapsed == a.cur.move.startup:
				ddelta += a.cur.move.distance_delta
		if ddelta != 0:
			state.distance = clampi(state.distance + ddelta, 0, 2)
			events.append(CombatEvent.new(t, &"distance", -1, -1, state.distance, &""))
```

Then in `_maybe_hit`, guard STEP from being treated as an attack — change its body to:
```gdscript
static func _maybe_hit(state: CombatState, actors: Array, snap: Array, attacker: int, t: int, events) -> void:
	var a: Dictionary = snap[attacker]
	if not a["hitting"]:
		return
	if (a["move"] as Move).kind == Move.Kind.STEP:
		return  # 步法不打人
	var defender := 1 - attacker
	var d: Dictionary = snap[defender]
	_resolve_hit(state, actors, attacker, a["move"], d, t, events)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash run_tests.sh -gselect=test_distance.gd`
Expected: PASS (step tests). Then `bash run_tests.sh` — all green.

- [ ] **Step 5: Commit**

```bash
git add src/combat/combat_sim.gd test/unit/test_distance.gd
git commit -m "feat(combat): STEP 改距离(同拍求和+clamp+事件), 步法不打人

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: 模拟器 — 攻击查距离(够不着→挥空)

**Files:**
- Modify: `src/combat/combat_sim.gd`
- Test: `test/unit/test_distance.gd`

**Interfaces:**
- Consumes: `Move.in_range`、`state.distance`
- Produces: `_resolve_hit` 在距离不对时不造成伤害,发 `CombatEvent(t, &"reach", attacker, defender, 0, atk.id)` + 体力惩罚

- [ ] **Step 1: Write the failing test** — append to `test/unit/test_distance.gd`:

```gdscript
func _atk(dmg, rmin, rmax) -> Move:
	var m := Move.new(); m.id=&"a"; m.kind=Move.Kind.ATTACK
	m.startup=0; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=dmg
	m.stamina_cost=2; m.range_min=rmin; m.range_max=rmax
	return m

func test_attack_out_of_range_whiffs():
	var s := _state()   # distance = 1 (中)
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(8, 0, 0), 0))  # 贴身-only
	var ev := CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.hp[1], 40, "够不着，无伤")
	assert_true(ev.any(func(e): return e.type == &"reach"), "发了 reach 事件")

func test_attack_in_range_hits():
	var s := _state()   # distance = 1
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(8, 0, 1), 0))  # 贴身~中
	CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.hp[1], 32, "距离对，命中 -8")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash run_tests.sh -gselect=test_distance.gd`
Expected: FAIL — out-of-range attack still deals damage (no gating yet).

- [ ] **Step 3: Implement** — in `src/combat/combat_sim.gd`, at the **top of** `_resolve_hit` (before the existing `var def_phase` lines), add the range gate:

```gdscript
	if (atk.kind == Move.Kind.ATTACK or atk.kind == Move.Kind.THROW) and not atk.in_range(state.distance):
		var pen := PENALTY_WHIFF_HEAVY if atk.is_heavy else PENALTY_WHIFF
		_add_stamina(state, attacker, -pen, t, events)
		events.append(CombatEvent.new(t, &"reach", attacker, 1 - attacker, 0, atk.id))
		return
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash run_tests.sh -gselect=test_distance.gd` then `bash run_tests.sh`
Expected: PASS. (Existing sim tests use default range 0..2 = 任意, so they're unaffected.)

- [ ] **Step 5: Commit**

```bash
git add src/combat/combat_sim.gd test/unit/test_distance.gd
git commit -m "feat(combat): 攻击命中查距离, 够不着→挥空(reach)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: 模拟器 — 击退 + 踉跄词缀

**Files:**
- Modify: `src/combat/combat_sim.gd`
- Test: `test/unit/test_distance.gd`

**Interfaces:**
- Consumes: `Move.knockback`、`Move.stun`
- Produces: 命中成功后:`knockback`→`distance+1`(发 `&"distance"`);`stun`→`defender.gasp_until=t+stun`(发 `&"stun"`)

- [ ] **Step 1: Write the failing test** — append to `test/unit/test_distance.gd`:

```gdscript
func test_knockback_pushes_distance():
	var s := _state(); s.distance = 0   # 贴身
	var m := _atk(6, 0, 1); m.knockback = true
	var p0 := Plan.new(); p0.add(PlacedMove.new(m, 0))
	CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.distance, 1, "击退把对手推到中距")

func test_stun_makes_target_skip_next_move():
	var s := _state(); s.distance = 0
	var m := _atk(2, 0, 1); m.stun = 3   # 撞肘式踉跄
	var p0 := Plan.new(); p0.add(PlacedMove.new(m, 0))     # 命中 t0, 令对手 gasp_until=3
	# 对手本想在 t1 出一记攻击, 但被踉跄跳过
	var p1 := Plan.new(); p1.add(PlacedMove.new(_atk(9, 0, 2), 1))
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.hp[0], 40, "我方未被对手的招命中(对手踉跄跳招)")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash run_tests.sh -gselect=test_distance.gd`
Expected: FAIL — knockback/stun not applied.

- [ ] **Step 3: Implement** — in `src/combat/combat_sim.gd`, in `_resolve_hit`, at the **normal-hit branch** (the final block that emits `&"hit"`), after `_add_stamina(state, attacker, REWARD_HIT, t, events)`, add:

```gdscript
	if atk.knockback:
		state.distance = mini(2, state.distance + 1)
		events.append(CombatEvent.new(t, &"distance", -1, -1, state.distance, &""))
	if atk.stun > 0:
		actors[defender].gasp_until = t + atk.stun
		events.append(CombatEvent.new(t, &"stun", attacker, defender, atk.stun, atk.id))
```

> Note: `mini` is GDScript's int-min. Apply only on the clean `hit` path (not interrupt/throw_break) — that's where 撞肘/侧踢 land.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash run_tests.sh -gselect=test_distance.gd` then `bash run_tests.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/combat/combat_sim.gd test/unit/test_distance.gd
git commit -m "feat(combat): 击退(命中推距离) + 踉跄(命中令对手跳招)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: 新基础招(技法家族)+ 适配 deck 依赖测试

**Files:**
- Modify: `src/content/deck.gd`
- Modify: `test/unit/test_content_fight.gd`
- Modify: `test/unit/test_plan_phase.gd`(`_kick` 改用新腿法 id)
- Modify: `test/unit/test_loc.gd`(如引用旧招名/ id)

**Interfaces:**
- Produces: `Deck.starter()` 返回 14 张新招(见下);新 id:`jab, hook, push_palm, chop_palm, elbow_strike, knee_strike, snap_kick, sweep_kick, side_kick, guard, dodge, grab, step_in, step_back`。腿法标签 `&"腿法"` 仍在 `snap_kick/sweep_kick/side_kick` 上(连环踢配方不变)。

- [ ] **Step 1: Update deck-dependent tests first (will fail)**

In `test/unit/test_content_fight.gd`:
- `test_three_kicks_fuse_into_chain_kick_and_deal_more` 和 `test_starter_combos_fit_in_game_tick_budget`:把 `find.call(&"low_kick")` 改为 `find.call(&"sweep_kick")`(扫堂腿,腿法,2拍... 见数值表;此处 dur 用 `total_duration()` 动态,无需改其它)。
- `test_full_fight_runs_to_a_death`:把 `find.call(&"heavy_kick")` 改为 `find.call(&"side_kick")`。其断言"enemy took damage"——注意 side_kick range 0-1,而 `test_full_fight` 的 state 没设 distance(默认... 该测试直接 new CombatState,distance 默认 1=中,side_kick 0-1 含 1 → 能命中)。**保留**。

In `test/unit/test_plan_phase.gd`:把 `_kick(deck)` 里 `if m.id == &"low_kick"` 改为 `if m.id == &"snap_kick"`(弹腿,腿法,2拍,贴身~中——与旧 low_kick 同 2 拍,既有放置/连招测试照常)。

In `test/unit/test_loc.gd`:若有断言旧招名(如"轻踢/扫腿/重踢"),改为新名(直拳/扫堂腿/侧踢)或改成断言某新 id→新名。先运行看它报哪条。

- [ ] **Step 2: Run to confirm red**

Run: `bash run_tests.sh`
Expected: FAIL — 旧 id `low_kick/heavy_kick` 不存在 / 招名变了。

- [ ] **Step 3: Implement deck** — replace `src/content/deck.gd` `_m` and `starter()`:

Extend `_m` to read the new opts (add before `return m`):
```gdscript
	m.range_min = opts.get("range", [0, 2])[0]
	m.range_max = opts.get("range", [0, 2])[1]
	m.knockback = opts.get("knockback", false)
	m.stun = opts.get("stun", 0)
	m.distance_delta = opts.get("delta", 0)
```
Replace `starter()` entirely:
```gdscript
static func starter() -> Array[Move]:
	return [
		# 拳(贴身)
		_m(&"jab", "直拳", Move.Kind.ATTACK, 0, 1, 1, 4, 2, {"tags":[&"拳法"], "range":[0,0], "interrupt":true, "priority":5}),
		_m(&"hook", "摆拳", Move.Kind.ATTACK, 1, 1, 1, 6, 2, {"tags":[&"拳法"], "range":[0,0]}),
		# 掌(贴身~中)
		_m(&"push_palm", "推掌", Move.Kind.ATTACK, 0, 1, 2, 5, 2, {"tags":[&"掌法"], "range":[0,1], "knockback":true}),
		_m(&"chop_palm", "下劈掌", Move.Kind.ATTACK, 2, 1, 1, 9, 3, {"tags":[&"掌法"], "range":[0,1], "heavy":true, "armor":true}),
		# 肘膝(贴身)
		_m(&"elbow_strike", "撞肘", Move.Kind.ATTACK, 1, 1, 1, 6, 2, {"tags":[&"肘膝"], "range":[0,0], "stun":2}),
		_m(&"knee_strike", "膝顶", Move.Kind.ATTACK, 1, 1, 2, 9, 3, {"tags":[&"肘膝"], "range":[0,0], "heavy":true}),
		# 腿(贴身~中)
		_m(&"snap_kick", "弹腿", Move.Kind.ATTACK, 0, 1, 1, 5, 2, {"tags":[&"腿法"], "range":[0,1]}),
		_m(&"sweep_kick", "扫堂腿", Move.Kind.ATTACK, 0, 1, 2, 6, 2, {"tags":[&"腿法"], "range":[0,1]}),
		_m(&"side_kick", "侧踢", Move.Kind.ATTACK, 3, 1, 2, 12, 4, {"tags":[&"腿法"], "range":[0,1], "heavy":true, "armor":true, "knockback":true}),
		# 防/闪/拿
		_m(&"guard", "格挡", Move.Kind.BLOCK, 0, 3, 1, 0, 2, {}),
		_m(&"dodge", "闪身", Move.Kind.DODGE, 0, 2, 1, 0, 2, {"tags":[&"轻功"]}),
		_m(&"grab", "擒拿", Move.Kind.THROW, 0, 1, 1, 5, 3, {"range":[0,0]}),
		# 步法(进快退慢)
		_m(&"step_in", "上步", Move.Kind.STEP, 0, 1, 0, 0, 1, {"tags":[&"身法"], "delta":-1}),
		_m(&"step_back", "撤步", Move.Kind.STEP, 0, 1, 1, 0, 1, {"tags":[&"身法"], "delta":1}),
	]
```
Give combo results a 腿法-system range (edit the three combo functions to pass `"range":[0,1]`):
```gdscript
static func chain_kick() -> Move:
	return _m(&"chain_kick", "连环踢", Move.Kind.ATTACK, 0, 2, 1, 14, 0, {"tags":[&"腿法"], "hits":[0,1], "range":[0,1]})
static func wuying() -> Move:
	return _m(&"wuying", "佛山无影脚", Move.Kind.ATTACK, 0, 3, 1, 22, 0, {"tags":[&"腿法"], "hits":[0,1,2], "armor":true, "range":[0,1]})
static func qiankun() -> Move:
	return _m(&"qiankun", "乾坤大挪移", Move.Kind.THROW, 0, 1, 1, 18, 0, {"range":[0,1]})
```

- [ ] **Step 4: Run the full suite**

Run: `bash run_tests.sh`
Expected: PASS。连环踢配方 = 腿法×3(snap/sweep/side 都是腿法)仍成立;乾坤 = 攻+防+投 仍成立。开局 D=1(中),掌/腿 range 0-1 在中距能命中 → self-play 照常出伤、终结;`test_ai` 的 `is_valid` 不涉及距离。(AI 仍会偶尔排"贴身-only"招在中距落空,Task 7 再让它懂距离——但本 Task 必须全绿。)

- [ ] **Step 5: Commit**

```bash
git add src/content/deck.gd test/unit/test_content_fight.gd test/unit/test_plan_phase.gd test/unit/test_loc.gd
git commit -m "feat(content): 新基础招(拳/掌/肘膝/腿/防/闪/拿/步) + 距离/词缀; 适配测试

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: AI 最低限度懂距离

**Files:**
- Modify: `src/ai/ai_planner.gd`
- Modify: `test/unit/test_balance.gd`(loop 里跟踪距离)
- Test: `test/unit/test_distance.gd`(AI 不排够不着的攻击)

**Interfaces:**
- Consumes: `Move.kind`、`Move.in_range`、`Move.distance_delta`
- Produces: `AiPlanner.plan(deck, stamina_now, n_ticks, start_distance := 1)`(多一个可选参数;AI 跟踪假定距离,只排在范围内的攻击,需要时先上步)

- [ ] **Step 1: Write the failing test** — append to `test/unit/test_distance.gd`:

```gdscript
func test_ai_does_not_plan_unreachable_attacks():
	var a := AiPlanner.new(3)
	var p := a.plan(Deck.starter(), 10, 12, 2)  # 远距开局
	# 远(2)时徒手都够不着;AI 不应排"在远距必落空"的招——要么先上步拉近,要么只排能到的
	# 断言:计划里若有攻击,其前面必有把距离拉到范围内的上步(简化:计划非空且不全是必空招)
	var sorted := p.sorted()
	var dist := 2
	for pm in sorted:
		var m: Move = pm.move
		if m.kind == Move.Kind.STEP:
			dist = clampi(dist + m.distance_delta, 0, 2)
		elif m.kind == Move.Kind.ATTACK or m.kind == Move.Kind.THROW:
			assert_true(m.in_range(dist), "AI 排的攻击在其假定距离内可达: %s@%d" % [m.move_name, dist])
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash run_tests.sh -gselect=test_distance.gd`
Expected: FAIL — current AI ignores distance, plans unreachable attacks.

- [ ] **Step 3: Implement** — replace `plan` in `src/ai/ai_planner.gd`:

```gdscript
func plan(deck: Array[Move], stamina_now: int, n_ticks: int, start_distance := 1) -> Plan:
	var p := Plan.new()
	var budget := stamina_now
	var spent := 0
	var t := 0
	var dist := start_distance
	var guard := 0
	while t < n_ticks and guard < 60:
		guard += 1
		var m: Move = deck[_rng.randi_range(0, deck.size() - 1)]
		if spent + m.stamina_cost > budget:
			break
		if t + m.total_duration() > n_ticks:
			t += 1
			continue
		# 攻击若够不着，跳过这次抽取（让 AI 倾向能命中的招/步法）
		if (m.kind == Move.Kind.ATTACK or m.kind == Move.Kind.THROW) and not m.in_range(dist):
			continue
		if m.kind == Move.Kind.STEP:
			dist = clampi(dist + m.distance_delta, 0, 2)
		p.add(PlacedMove.new(m, t))
		spent += m.stamina_cost
		t += m.total_duration()
	return p
```

- [ ] **Step 4: Update the balance harness to track distance** — in `test/unit/test_balance.gd`, set a start distance and pass it; the per-round loop already calls `a.plan(...)`. Change both plan calls to pass distance `1`:
```gdscript
			var pa := rules.apply(a.plan(Deck.starter(), s.stamina[0], s.n_ticks, 1))
			var pb := rules.apply(b.plan(Deck.starter(), s.stamina[1], s.n_ticks, 1))
```
(also ensure `s.distance` resets sensibly — for the harness, leave default; this test just checks termination.)

- [ ] **Step 5: Run the full suite**

Run: `bash run_tests.sh`
Expected: PASS. (`test_ai.gd` calls `a.plan(Deck.starter(), 10, 10)` — the new 4th arg defaults to 1, so it still compiles and plans in-range attacks.)

- [ ] **Step 6: Commit**

```bash
git add src/ai/ai_planner.gd test/unit/test_balance.gd test/unit/test_distance.gd
git commit -m "feat(ai): AI 跟踪假定距离, 只排够得着的攻击(需要先上步)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: UI — 排招卡牌标距离 + 观战显示距离/够不着

**Files:**
- Modify: `src/scenes/plan_phase.gd`(卡牌文案加距离)
- Modify: `src/ui/combat_feed.gd`(`&"reach"` 标记)
- Modify: `src/scenes/watch_phase.gd` + `src/scenes/watch_phase.tscn`(当前距离常显 + 距离变化)
- Test: `test/unit/test_combat_feed.gd`

**Interfaces:**
- Consumes: `Move.range_min/max`、事件 `&"distance"`/`&"reach"`
- Produces: 卡牌显示距离;观战有距离标签 `DistanceLabel`,随 `&"distance"` 更新;`&"reach"` 在攻击方浮"够不着"

- [ ] **Step 1: Write the failing test** — append to `test/unit/test_combat_feed.gd`:

```gdscript
func test_reach_floats_no_number_but_marks_attacker():
	# 够不着：不浮伤害数字
	assert_true(CombatFeed.float_number(_ev(&"reach", 0, 1, 0, &"jab")).is_empty())

func test_distance_label_text():
	assert_eq(CombatFeed.distance_label(0), "贴身")
	assert_eq(CombatFeed.distance_label(1), "中")
	assert_eq(CombatFeed.distance_label(2), "远")
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash run_tests.sh -gselect=test_combat_feed.gd`
Expected: FAIL — `Nonexistent function 'distance_label'`.

- [ ] **Step 3: Implement CombatFeed** — in `src/ui/combat_feed.gd`:

Add a helper:
```gdscript
static func distance_label(d: int) -> String:
	match d:
		0: return "贴身"
		1: return "中"
		2: return "远"
	return "?"
```
`float_number` already returns `{}` for unknown types (`&"reach"` falls through the match) — no change needed; the test asserts that.

- [ ] **Step 4: Card distance + watch label**

In `src/scenes/plan_phase.gd` `_build_deck`, change the card text to include distance (STEP shows 进/退):
```gdscript
		var tail := ""
		if m.kind == Move.Kind.STEP:
			tail = "进" if m.distance_delta < 0 else "退"
		else:
			tail = "%s-%s" % [CombatFeed.distance_label(m.range_min), CombatFeed.distance_label(m.range_max)]
		b.text = "%s\n%d拍·%d气·%s" % [m.move_name, m.total_duration(), m.stamina_cost, tail]
```

In `src/scenes/watch_phase.tscn`, add a label node (sibling of TickLabel):
```
[node name="DistanceLabel" type="Label" parent="."]
offset_left = 556.0
offset_top = 498.0
offset_right = 760.0
offset_bottom = 522.0
text = "距离 中"
```
In `src/scenes/watch_phase.gd`:
- add `@onready var _dist: Label = $DistanceLabel`
- in `show_state(state)` add: `_dist.text = "距离 " + CombatFeed.distance_label(state.distance)`
- in `play(...)` after setting bars add the same line using `_state.distance`
- in `_apply_event(e)`, handle the new types: at the top of the `match e.type` add cases:
```gdscript
		&"distance":
			_dist.text = "距离 " + CombatFeed.distance_label(e.amount)
		&"reach":
			_spawn_number(e.actor, "够不着", Color(0.8, 0.8, 0.85), false)
```
(`_spawn_number(side, text, color, big)` already exists.)

- [ ] **Step 5: Run the full suite + visual smoke**

Run: `bash run_tests.sh`
Expected: PASS.

Create `_shot.gd` at repo root, render the plan phase, confirm cards show distance (e.g. `直拳 / 2拍·2气·贴身-贴身`, `上步 / 1拍·1气·进`):
```gdscript
extends SceneTree
func _initialize() -> void:
	var w = load("res://src/scenes/plan_phase.tscn").instantiate()
	root.add_child(w)
	await process_frame
	w.setup(Deck.starter(), ComboLibrary.build(), 10, 10, 12, ["？"])
	await process_frame
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png("res://build/_s1.png")
	quit()
```
Run: `"/c/Users/Tianyu/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --path . -s _shot.gd` then open `build/_s1.png`. Delete temp: `rm _shot.gd _shot.gd.uid build/_s1.png`.

- [ ] **Step 6: Commit**

```bash
git add src/scenes/plan_phase.gd src/ui/combat_feed.gd src/scenes/watch_phase.gd src/scenes/watch_phase.tscn test/unit/test_combat_feed.gd
git commit -m "feat(ui): 排招卡牌标距离 + 观战距离标签/够不着反馈

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## 验收对照（实现完成后人工核对）

- [ ] 距离开局中(1);上步 D−1(1拍)、撤步 D+1(2拍);同拍一进一退抵消;clamp 0..2。
- [ ] 攻击命中拍查 `range_min≤D≤range_max`,够不着→挥空(reach 事件,体力惩罚)。
- [ ] 击退命中→D+1;踉跄命中→对手跳招。
- [ ] 14 张新基础招(直拳/摆拳/推掌/下劈掌/撞肘/膝顶/弹腿/扫堂腿/侧踢/格挡/闪身/擒拿/上步/撤步)替换旧 6 招;连环踢(腿法×3)、乾坤(攻防投)配方仍成立。
- [ ] AI 不排够不着的攻击;self-play 终结。
- [ ] 排招卡牌显示距离;观战有距离标签 + 够不着反馈。
- [ ] `combat_sim` 回合内既有手感未变;全套 GUT 绿。

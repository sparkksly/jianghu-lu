# 武侠卡牌战斗垂直切片 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable single-fight combat vertical slice (one 腿法 style) proving the "plan moves onto a tick timeline, then watch both sides resolve" loop is fun.

**Architecture:** A pure, node-free, deterministic combat **simulator** (`CombatSim.simulate(plans) -> events`) is built first and unit-tested with GUT; the presentation layer (plan UI + watch replay) is a thin consumer of that simulator. All combat rules — frames (前摇/命中/后摇), affix-based interrupt + super-armor, attack/block/dodge/throw, stamina gamble + exhaustion, and plan-time combo fusion — live in the simulator as small, testable functions.

**Tech Stack:** Godot 4.6.1 (GDScript), GUT 9.x (Godot Unit Test) for headless tests, git.

## Global Constraints

- Engine: **Godot 4.6.1 stable**. GDScript only.
- Simulator code under `src/combat/` and `src/ai/` MUST be **node-free** (extend `Resource` or `RefCounted` only) and **deterministic** (same inputs → identical event list). No `randf`, no engine singletons, no `Node`.
- Player index convention everywhere: **`0` = player, `1` = enemy**. Arrays are 2-element `[p0, p1]`.
- Time is **discrete integer ticks**. Default timeline length `N_TICKS = 10`.
- Tags and ids are `StringName` (`&"腿法"`). Move `Kind` enum order is fixed: `ATTACK, BLOCK, DODGE, THROW`.
- Tests live under `res://test/`, files named `test_*.gd`, test funcs named `test_*`.
- Godot binary (for headless test runs): `C:\Users\Tianyu\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe`.
- Commit after every task. Keep the existing `src/cards/*`, `src/resources/card.gd`, `src/entities/combatant.gd` untouched (superseded later, out of scope).

---

## File Structure

Logic (node-free, tested):
- `src/combat/move.gd` — `class_name Move extends Resource`. One move's static data + frame helpers.
- `src/combat/placed_move.gd` — `class_name PlacedMove extends RefCounted`. A move placed at a start tick.
- `src/combat/plan.gd` — `class_name Plan extends RefCounted`. An ordered set of PlacedMoves + validation + total cost.
- `src/combat/combat_state.gd` — `class_name CombatState extends RefCounted`. HP / stamina / config for both actors.
- `src/combat/combat_event.gd` — `class_name CombatEvent extends RefCounted`. One thing that happened at a tick.
- `src/combat/combo_rules.gd` — `class_name ComboRules extends RefCounted`. Recipe table + plan-time fusion.
- `src/combat/combat_sim.gd` — `class_name CombatSim extends RefCounted`. The deterministic tick engine.
- `src/ai/ai_planner.gd` — `class_name AiPlanner extends RefCounted`. Builds an enemy Plan + exposes partial intent.

Content (data):
- `src/content/moves/*.tres` — the 腿法 style moves.
- `src/content/combos.gd` — `class_name ComboLibrary`. Builds the slice's ComboRules.

Presentation (nodes/scenes):
- `src/scenes/plan_phase.tscn` + `src/scenes/plan_phase.gd` — drag moves onto the timeline.
- `src/scenes/watch_phase.tscn` + `src/scenes/watch_phase.gd` — replay the event log.
- `src/scenes/fight.tscn` + `src/scenes/fight.gd` — orchestrates rounds: plan → sim → watch → repeat until a death.

Tests: `test/unit/test_*.gd`.

---

## Task 1: Project setup — install GUT, test harness, smoke test

**Files:**
- Create: `addons/gut/` (vendored), `test/unit/test_smoke.gd`, `.gutconfig.json`, `run_tests.sh`
- Modify: `project.godot` (enable gut plugin autoloads not required for cmdln)

**Interfaces:**
- Produces: a working `bash run_tests.sh` command that runs all `test/unit/test_*.gd` headless and exits non-zero on failure.

- [ ] **Step 1: Vendor GUT**

```bash
cd "C:/Users/Tianyu/RogueLike/new-game-project"
git clone --depth 1 https://github.com/bitwes/Gut.git /tmp/gut
mkdir -p addons
cp -r /tmp/gut/addons/gut addons/gut
rm -rf /tmp/gut
```

- [ ] **Step 2: Create test dir + GUT config**

Create `.gutconfig.json`:
```json
{
  "dirs": ["res://test/unit"],
  "include_subdirs": true,
  "prefix": "test_",
  "suffix": ".gd",
  "log_level": 1,
  "should_exit": true
}
```

- [ ] **Step 3: Create the test runner script**

Create `run_tests.sh`:
```bash
#!/usr/bin/env bash
# Headless GUT runner. Usage: bash run_tests.sh [extra gut args]
GODOT="/c/Users/Tianyu/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe"
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json "$@"
```

- [ ] **Step 4: Write a smoke test**

Create `test/unit/test_smoke.gd`:
```gdscript
extends GutTest

func test_harness_runs():
	assert_eq(1 + 1, 2, "math works")
```

- [ ] **Step 5: Run and verify it passes**

Run: `bash run_tests.sh`
Expected: output shows `1 passing` (or `Passed`), process exits 0.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: vendor GUT and add headless test harness"
```

---

## Task 2: Move resource + frame helpers

**Files:**
- Create: `src/combat/move.gd`, `test/unit/test_move.gd`

**Interfaces:**
- Produces: `Move` with fields below and:
  - `func active_count() -> int` (number of active ticks)
  - `func total_duration() -> int` = `startup + active_count() + recovery`
  - `func phase_at(elapsed:int) -> StringName` → one of `&"startup"`, `&"active"`, `&"recovery"`, `&"done"`
  - `func is_hit_tick(elapsed:int) -> bool` (true when elapsed is an active tick listed in `hit_offsets`)

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_move.gd`:
```gdscript
extends GutTest

func _make() -> Move:
	var m := Move.new()
	m.startup = 2
	m.active = 1
	m.recovery = 2
	m.hit_offsets = [0]
	return m

func test_total_duration():
	assert_eq(_make().total_duration(), 5)

func test_phase_boundaries():
	var m := _make()
	assert_eq(m.phase_at(0), &"startup")
	assert_eq(m.phase_at(1), &"startup")
	assert_eq(m.phase_at(2), &"active")
	assert_eq(m.phase_at(3), &"recovery")
	assert_eq(m.phase_at(4), &"recovery")
	assert_eq(m.phase_at(5), &"done")

func test_hit_tick():
	var m := _make()
	assert_false(m.is_hit_tick(1)) # startup
	assert_true(m.is_hit_tick(2))  # active offset 0
	assert_false(m.is_hit_tick(3)) # recovery

func test_multi_hit_combo():
	var m := Move.new()
	m.startup = 1
	m.active = 3
	m.recovery = 1
	m.hit_offsets = [0, 1, 2]
	assert_eq(m.active_count(), 3)
	assert_true(m.is_hit_tick(1))
	assert_true(m.is_hit_tick(2))
	assert_true(m.is_hit_tick(3))
	assert_false(m.is_hit_tick(4)) # recovery
```

- [ ] **Step 2: Run to verify failure**

Run: `bash run_tests.sh -gtest=res://test/unit/test_move.gd`
Expected: FAIL — `Move` not found / parse error.

- [ ] **Step 3: Implement Move**

Create `src/combat/move.gd`:
```gdscript
class_name Move
extends Resource

enum Kind { ATTACK, BLOCK, DODGE, THROW }

@export var id: StringName = &""
@export var move_name: String = "招式"
@export var tags: Array[StringName] = []
@export var kind: Kind = Kind.ATTACK

@export var startup: int = 1      # 前摇 ticks
@export var active: int = 1       # 命中/有效 ticks
@export var recovery: int = 1     # 后摇 ticks
@export var hit_offsets: Array[int] = [0]  # which active ticks deal damage (ATTACK/THROW)

@export var stamina_cost: int = 1
@export var damage: int = 0
@export var priority: int = 0     # same-tick tie-break, higher wins

@export var can_interrupt: bool = false  # 打断 词缀
@export var super_armor: bool = false    # 霸体 词缀
@export var is_heavy: bool = false       # 重击 (extra whiff penalty)

func active_count() -> int:
	return max(1, active)

func total_duration() -> int:
	return startup + active_count() + recovery

func phase_at(elapsed: int) -> StringName:
	if elapsed < 0 or elapsed >= total_duration():
		return &"done"
	if elapsed < startup:
		return &"startup"
	if elapsed < startup + active_count():
		return &"active"
	return &"recovery"

func is_hit_tick(elapsed: int) -> bool:
	if phase_at(elapsed) != &"active":
		return false
	return (elapsed - startup) in hit_offsets
```

- [ ] **Step 4: Run to verify pass**

Run: `bash run_tests.sh -gtest=res://test/unit/test_move.gd`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add src/combat/move.gd test/unit/test_move.gd
git commit -m "feat(combat): Move resource with frame helpers"
```

---

## Task 3: PlacedMove, Plan, CombatState, CombatEvent (data models)

**Files:**
- Create: `src/combat/placed_move.gd`, `src/combat/plan.gd`, `src/combat/combat_state.gd`, `src/combat/combat_event.gd`, `test/unit/test_plan.gd`

**Interfaces:**
- Produces:
  - `PlacedMove.new(move: Move, start: int)`; props `.move`, `.start`; `func end_tick() -> int` = `start + move.total_duration()`.
  - `Plan` with `var moves: Array[PlacedMove]`; `func add(pm)`; `func sorted() -> Array[PlacedMove]` (by start asc); `func total_cost() -> int`; `func is_valid(sta_max:int, n_ticks:int) -> bool` (no overlap, all within `[0, n_ticks)` start, total_cost ≤ `floori(1.5*sta_max)`).
  - `CombatState` props: `hp: Array[int]`, `max_hp: Array[int]`, `stamina: Array[int]`, `sta_max: Array[int]`, `n_ticks: int`, `gasp_len: int`; `func clone() -> CombatState`.
  - `CombatEvent.new(tick, type, actor, target, amount, move_id)`; props of same names. Types are `StringName`: `&"hit" &"interrupt" &"block" &"throw_break" &"whiff" &"exhaust" &"stamina" &"death"`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_plan.gd`:
```gdscript
extends GutTest

func _atk(cost := 2, dur_startup := 1, dur_active := 1, dur_recovery := 1) -> Move:
	var m := Move.new()
	m.startup = dur_startup; m.active = dur_active; m.recovery = dur_recovery
	m.stamina_cost = cost
	return m

func test_placed_end_tick():
	var pm := PlacedMove.new(_atk(2, 2, 1, 2), 3) # duration 5
	assert_eq(pm.end_tick(), 8)

func test_total_cost_and_sorted():
	var p := Plan.new()
	p.add(PlacedMove.new(_atk(2), 4))
	p.add(PlacedMove.new(_atk(3), 0))
	assert_eq(p.total_cost(), 5)
	assert_eq(p.sorted()[0].start, 0)

func test_overcommit_allowed_up_to_1_5x():
	var p := Plan.new()
	p.add(PlacedMove.new(_atk(15), 0)) # 15 == floor(1.5*10)
	assert_true(p.is_valid(10, 10))
	var p2 := Plan.new()
	p2.add(PlacedMove.new(_atk(16), 0))
	assert_false(p2.is_valid(10, 10)) # over 1.5x

func test_no_overlap():
	var p := Plan.new()
	p.add(PlacedMove.new(_atk(1, 1, 1, 1), 0)) # occupies ticks 0..2
	p.add(PlacedMove.new(_atk(1, 1, 1, 1), 2)) # starts at 2 -> overlaps end_tick 3
	assert_false(p.is_valid(10, 10))

func test_state_clone_is_deep():
	var s := CombatState.new()
	s.hp = [50, 50]
	var c := s.clone()
	c.hp[0] = 1
	assert_eq(s.hp[0], 50, "clone must not alias arrays")
```

- [ ] **Step 2: Run to verify failure**

Run: `bash run_tests.sh -gtest=res://test/unit/test_plan.gd`
Expected: FAIL — classes not found.

- [ ] **Step 3: Implement the data models**

Create `src/combat/placed_move.gd`:
```gdscript
class_name PlacedMove
extends RefCounted

var move: Move
var start: int

func _init(p_move: Move = null, p_start: int = 0) -> void:
	move = p_move
	start = p_start

func end_tick() -> int:
	return start + move.total_duration()
```

Create `src/combat/plan.gd`:
```gdscript
class_name Plan
extends RefCounted

var moves: Array[PlacedMove] = []

func add(pm: PlacedMove) -> void:
	moves.append(pm)

func sorted() -> Array[PlacedMove]:
	var out := moves.duplicate()
	out.sort_custom(func(a, b): return a.start < b.start)
	return out

func total_cost() -> int:
	var c := 0
	for pm in moves:
		c += pm.move.stamina_cost
	return c

func is_valid(sta_max: int, n_ticks: int) -> bool:
	if total_cost() > int(floor(1.5 * sta_max)):
		return false
	var s := sorted()
	var last_end := -1
	for pm in s:
		if pm.start < 0 or pm.start >= n_ticks:
			return false
		if pm.start < last_end:
			return false # overlap
		last_end = pm.end_tick()
	return true
```

Create `src/combat/combat_state.gd`:
```gdscript
class_name CombatState
extends RefCounted

var hp: Array[int] = [50, 50]
var max_hp: Array[int] = [50, 50]
var stamina: Array[int] = [10, 10]
var sta_max: Array[int] = [10, 10]
var n_ticks: int = 10
var gasp_len: int = 3  # K ticks of 喘息 when exhausted

func clone() -> CombatState:
	var c := CombatState.new()
	c.hp = hp.duplicate()
	c.max_hp = max_hp.duplicate()
	c.stamina = stamina.duplicate()
	c.sta_max = sta_max.duplicate()
	c.n_ticks = n_ticks
	c.gasp_len = gasp_len
	return c
```

Create `src/combat/combat_event.gd`:
```gdscript
class_name CombatEvent
extends RefCounted

var tick: int
var type: StringName
var actor: int
var target: int
var amount: int
var move_id: StringName

func _init(p_tick := 0, p_type := &"", p_actor := 0, p_target := 0, p_amount := 0, p_move_id := &"") -> void:
	tick = p_tick
	type = p_type
	actor = p_actor
	target = p_target
	amount = p_amount
	move_id = p_move_id

func _to_string() -> String:
	return "[t%d %s a%d->t%d %d %s]" % [tick, type, actor, target, amount, move_id]
```

- [ ] **Step 4: Run to verify pass**

Run: `bash run_tests.sh -gtest=res://test/unit/test_plan.gd`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add src/combat/placed_move.gd src/combat/plan.gd src/combat/combat_state.gd src/combat/combat_event.gd test/unit/test_plan.gd
git commit -m "feat(combat): plan/state/event data models"
```

---

## Task 4: CombatSim core — two attacks, damage, determinism

This task builds the tick engine skeleton with a per-actor cursor. Later tasks extend the single resolution function `_resolve_hit`. Keep the loop structure stable.

**Files:**
- Create: `src/combat/combat_sim.gd`, `test/unit/test_sim_basic.gd`

**Interfaces:**
- Produces: `static func simulate(state: CombatState, plans: Array) -> Array[CombatEvent]`.
  `plans` is `[Plan, Plan]` (index 0 player, 1 enemy). Mutates `state.hp`/`state.stamina` in place AND returns the event list. Deterministic.
- Internal (extended by later tasks): `static func _resolve_hit(state, attacker:int, atk_move:Move, def_phase:StringName, def_move:Move, tick:int, events) -> void` — applies the outcome of `attacker` landing a hit this tick against the defender's snapshot phase/move.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_sim_basic.gd`:
```gdscript
extends GutTest

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [50, 50]; s.max_hp = [50, 50]
	s.stamina = [10, 10]; s.sta_max = [10, 10]
	s.n_ticks = 10
	return s

func _atk(dmg := 6, cost := 2) -> Move:
	var m := Move.new()
	m.id = &"kick"; m.kind = Move.Kind.ATTACK
	m.startup = 1; m.active = 1; m.recovery = 1
	m.hit_offsets = [0]; m.damage = dmg; m.stamina_cost = cost
	return m

func test_single_attack_deals_damage():
	var s := _state()
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(6), 0))
	var p1 := Plan.new()
	var ev := CombatSim.simulate(s, [p0, p1])
	assert_eq(s.hp[1], 44, "enemy took 6")
	assert_eq(s.stamina[0], 8, "player spent 2 stamina")
	var hits := ev.filter(func(e): return e.type == &"hit")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].tick, 1, "hit lands after 1 tick startup")

func test_both_attack_both_take_damage():
	var s := _state()
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(6), 0))
	var p1 := Plan.new(); p1.add(PlacedMove.new(_atk(4), 0))
	CombatSim.simulate(s, [p0, p1])
	assert_eq(s.hp[1], 44)
	assert_eq(s.hp[0], 46)

func test_deterministic():
	var s1 := _state(); var s2 := _state()
	var a := Plan.new(); a.add(PlacedMove.new(_atk(6), 0)); a.add(PlacedMove.new(_atk(6), 3))
	var b := Plan.new(); b.add(PlacedMove.new(_atk(4), 1))
	var e1 := CombatSim.simulate(s1, [a, b])
	# rebuild identical plans for second run
	var a2 := Plan.new(); a2.add(PlacedMove.new(_atk(6), 0)); a2.add(PlacedMove.new(_atk(6), 3))
	var b2 := Plan.new(); b2.add(PlacedMove.new(_atk(4), 1))
	var e2 := CombatSim.simulate(s2, [a2, b2])
	assert_eq(e1.map(func(e): return str(e)), e2.map(func(e): return str(e)))
```

- [ ] **Step 2: Run to verify failure**

Run: `bash run_tests.sh -gtest=res://test/unit/test_sim_basic.gd`
Expected: FAIL — `CombatSim` not found.

- [ ] **Step 3: Implement the tick engine (basic)**

Create `src/combat/combat_sim.gd`:
```gdscript
class_name CombatSim
extends RefCounted

# Stamina tuning (Task 8 references these constants).
const REWARD_HIT := 1
const REWARD_INTERRUPT := 2
const REWARD_BLOCK := 1
const PENALTY_WHIFF := 2
const PENALTY_WHIFF_HEAVY := 4
const PENALTY_STAGGER := 2

class _Actor:
	var queue: Array[PlacedMove]
	var qi := 0
	var cur: PlacedMove = null
	var elapsed := 0
	var gasp_until := -1

static func simulate(state: CombatState, plans: Array) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	var actors := [_Actor.new(), _Actor.new()]
	for i in 2:
		actors[i].queue = (plans[i] as Plan).sorted()

	var max_tick := state.n_ticks + 30  # let trailing moves finish
	var t := 0
	while t < max_tick:
		# 1. start moves due this tick
		for i in 2:
			_try_start(state, actors[i], i, t, events)
		# 2. snapshot phases for symmetric resolution
		var snap := []
		for i in 2:
			snap.append(_snapshot(actors[i]))
		# 3. resolve hits using snapshot (process by priority for tie-break)
		var order := [0, 1]
		if _hit_priority(snap[1]) > _hit_priority(snap[0]):
			order = [1, 0]
		for i in order:
			_maybe_hit(state, snap, i, t, events)
			if state.hp[0] <= 0 or state.hp[1] <= 0:
				break
		# 4. deaths
		if state.hp[0] <= 0 or state.hp[1] <= 0:
			var dead := 0 if state.hp[0] <= 0 else 1
			events.append(CombatEvent.new(t, &"death", dead, dead, 0, &""))
			break
		# 5. advance
		for i in 2:
			_advance(actors[i])
		# 6. stop early if nothing left to do
		if t >= state.n_ticks and _all_idle(actors):
			break
		t += 1
	return events

static func _try_start(state: CombatState, a: _Actor, idx: int, t: int, events) -> void:
	if a.cur != null:
		return
	if t < a.gasp_until:
		# gasping: skip any move due now (wasted)
		while a.qi < a.queue.size() and a.queue[a.qi].start <= t:
			a.qi += 1
		return
	if a.qi >= a.queue.size():
		return
	if a.queue[a.qi].start != t:
		return
	var pm: PlacedMove = a.queue[a.qi]
	if state.stamina[idx] < pm.move.stamina_cost:
		# exhaustion -> 喘息
		a.gasp_until = t + state.gasp_len
		a.qi += 1
		events.append(CombatEvent.new(t, &"exhaust", idx, idx, state.gasp_len, pm.move.id))
		return
	state.stamina[idx] -= pm.move.stamina_cost
	a.cur = pm
	a.elapsed = 0
	a.qi += 1

# snapshot = {move, phase, hitting:bool, gasping:bool}
static func _snapshot(a: _Actor) -> Dictionary:
	if a.cur == null:
		return {"move": null, "phase": &"idle", "hitting": false}
	var ph: StringName = a.cur.move.phase_at(a.elapsed)
	return {
		"move": a.cur.move,
		"phase": ph,
		"hitting": a.cur.move.is_hit_tick(a.elapsed),
	}

static func _hit_priority(snap: Dictionary) -> int:
	if snap["hitting"]:
		return (snap["move"] as Move).priority
	return -9999

static func _maybe_hit(state: CombatState, snap: Array, attacker: int, t: int, events) -> void:
	var a: Dictionary = snap[attacker]
	if not a["hitting"]:
		return
	var defender := 1 - attacker
	var d: Dictionary = snap[defender]
	_resolve_hit(state, attacker, a["move"], d["phase"], d["move"], t, events)

# Extended by later tasks (interrupt, block, dodge, throw, stamina).
static func _resolve_hit(state: CombatState, attacker: int, atk: Move, def_phase: StringName, def_move: Move, t: int, events) -> void:
	var defender := 1 - attacker
	state.hp[defender] = max(0, state.hp[defender] - atk.damage)
	events.append(CombatEvent.new(t, &"hit", attacker, defender, atk.damage, atk.id))

static func _advance(a: _Actor) -> void:
	if a.cur != null:
		a.elapsed += 1
		if a.elapsed >= a.cur.move.total_duration():
			a.cur = null
			a.elapsed = 0

static func _all_idle(actors: Array) -> bool:
	for a in actors:
		if a.cur != null or a.qi < a.queue.size():
			return false
	return true
```

- [ ] **Step 4: Run to verify pass**

Run: `bash run_tests.sh -gtest=res://test/unit/test_sim_basic.gd`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add src/combat/combat_sim.gd test/unit/test_sim_basic.gd
git commit -m "feat(combat): deterministic tick engine with basic attacks"
```

---

## Task 5: Interrupt (打断 affix) + super-armor (霸体)

Extend `_resolve_hit` so an attacker hitting a defender who is in **startup** behaves per affixes.

**Files:**
- Modify: `src/combat/combat_sim.gd` (`_resolve_hit`, and cancel logic needs access to the defender actor — see step 3)
- Create: `test/unit/test_sim_interrupt.gd`

**Interfaces:**
- Consumes: Task 4 engine. Produces: interrupt cancels the defender's current move.
- Note: cancelling requires mutating the defender `_Actor`. Pass `actors` into resolution. Update `_maybe_hit`/`_resolve_hit` signatures to take `actors`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_sim_interrupt.gd`:
```gdscript
extends GutTest

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [50, 50]; s.max_hp = [50, 50]
	s.stamina = [20, 20]; s.sta_max = [20, 20]; s.n_ticks = 12
	return s

func _atk(id, dmg, su, interrupt := false, armor := false) -> Move:
	var m := Move.new()
	m.id = id; m.kind = Move.Kind.ATTACK
	m.startup = su; m.active = 1; m.recovery = 1
	m.hit_offsets = [0]; m.damage = dmg; m.stamina_cost = 2
	m.can_interrupt = interrupt; m.super_armor = armor
	return m

# fast interrupter hits at tick1 while slow attacker still in startup (su=3)
func test_interrupt_cancels_slow_move():
	var s := _state()
	var fast := Plan.new(); fast.add(PlacedMove.new(_atk(&"jab", 5, 1, true), 0)) # hits t1
	var slow := Plan.new(); slow.add(PlacedMove.new(_atk(&"heavy", 20, 3), 0))     # would hit t3
	var ev := CombatSim.simulate(s, [fast, slow])
	assert_eq(s.hp[1], 45, "interrupted target took the jab")
	assert_eq(s.hp[0], 50, "heavy never landed (cancelled)")
	assert_eq(ev.filter(func(e): return e.type == &"interrupt").size(), 1)

func test_non_interrupt_hit_does_not_cancel():
	var s := _state()
	var fast := Plan.new(); fast.add(PlacedMove.new(_atk(&"jab", 5, 1, false), 0)) # no interrupt
	var slow := Plan.new(); slow.add(PlacedMove.new(_atk(&"heavy", 20, 3), 0))
	CombatSim.simulate(s, [fast, slow])
	assert_eq(s.hp[1], 45, "jab still deals damage")
	assert_eq(s.hp[0], 30, "heavy STILL lands because jab can't interrupt")

func test_super_armor_immune_to_interrupt():
	var s := _state()
	var fast := Plan.new(); fast.add(PlacedMove.new(_atk(&"jab", 5, 1, true), 0))
	var slow := Plan.new(); slow.add(PlacedMove.new(_atk(&"heavy", 20, 3, false, true), 0)) # 霸体
	CombatSim.simulate(s, [fast, slow])
	assert_eq(s.hp[1], 45, "jab damage applies")
	assert_eq(s.hp[0], 30, "armored heavy not cancelled, still lands")
```

- [ ] **Step 2: Run to verify failure**

Run: `bash run_tests.sh -gtest=res://test/unit/test_sim_interrupt.gd`
Expected: FAIL — heavy gets cancelled incorrectly / no interrupt event.

- [ ] **Step 3: Thread `actors` through resolution and implement interrupt**

In `src/combat/combat_sim.gd`, change the resolution call chain to pass `actors`. Replace the `_maybe_hit` and `_resolve_hit` functions with:

```gdscript
static func _maybe_hit(state: CombatState, actors: Array, snap: Array, attacker: int, t: int, events) -> void:
	var a: Dictionary = snap[attacker]
	if not a["hitting"]:
		return
	var defender := 1 - attacker
	var d: Dictionary = snap[defender]
	_resolve_hit(state, actors, attacker, a["move"], d, t, events)

static func _resolve_hit(state: CombatState, actors: Array, attacker: int, atk: Move, d: Dictionary, t: int, events) -> void:
	var defender := 1 - attacker
	var def_phase: StringName = d["phase"]
	var def_move: Move = d["move"]
	# Interrupt: hitting a defender mid-startup
	if def_phase == &"startup" and atk.can_interrupt and def_move != null and not def_move.super_armor:
		actors[defender].cur = null  # cancel
		actors[defender].elapsed = 0
		state.hp[defender] = max(0, state.hp[defender] - atk.damage)
		events.append(CombatEvent.new(t, &"interrupt", attacker, defender, atk.damage, atk.id))
		return
	# default: damage applies, defender move (if any) continues
	state.hp[defender] = max(0, state.hp[defender] - atk.damage)
	events.append(CombatEvent.new(t, &"hit", attacker, defender, atk.damage, atk.id))
```

And update the loop's resolution call (in `simulate`, step where `_maybe_hit` is called) to:
```gdscript
		for i in order:
			_maybe_hit(state, actors, snap, i, t, events)
			if state.hp[0] <= 0 or state.hp[1] <= 0:
				break
```

- [ ] **Step 4: Run to verify pass**

Run: `bash run_tests.sh -gtest=res://test/unit/test_sim_interrupt.gd`
Then full: `bash run_tests.sh`
Expected: interrupt tests PASS (3) and Task 4 tests still PASS.

- [ ] **Step 5: Commit**

```bash
git add src/combat/combat_sim.gd test/unit/test_sim_interrupt.gd
git commit -m "feat(combat): affix-based interrupt and super-armor"
```

---

## Task 6: Block, Dodge (whiff / 用力过猛), Throw (break / 盲投)

Extend `_resolve_hit` to branch on defender's defensive move when the defender is in its **active** window, and on the attacker's `kind`.

**Files:**
- Modify: `src/combat/combat_sim.gd` (`_resolve_hit`)
- Create: `test/unit/test_sim_triangle.gd`

**Interfaces:**
- Consumes: Task 5. Produces final `_resolve_hit` branching:
  - defender active & `kind==DODGE` → attacker WHIFF (no damage; whiff penalty deferred to Task 8 hook `_whiff(...)`).
  - else if attacker `kind==THROW`: defender active & `kind==BLOCK` → THROW_BREAK (damage + bonus); else weak/whiff.
  - else attacker `kind==ATTACK`: defender active & `kind==BLOCK` → BLOCK (negated); else interrupt/hit per Task 5.
- New constant: `const THROW_BREAK_BONUS := 4`. Throw base damage uses `atk.damage`; weak throw deals 0.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_sim_triangle.gd`:
```gdscript
extends GutTest

func _state() -> CombatState:
	var s := CombatState.new()
	s.hp = [50, 50]; s.max_hp=[50,50]; s.stamina=[30,30]; s.sta_max=[30,30]; s.n_ticks=12
	return s

func _atk(dmg, su, heavy := false) -> Move:
	var m := Move.new(); m.id=&"atk"; m.kind=Move.Kind.ATTACK
	m.startup=su; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=dmg; m.stamina_cost=2; m.is_heavy=heavy
	return m

func _defense(kind, su, window) -> Move:
	var m := Move.new(); m.id=&"def"; m.kind=kind
	m.startup=su; m.active=window; m.recovery=1; m.stamina_cost=2
	return m

func _throw(dmg, su) -> Move:
	var m := Move.new(); m.id=&"throw"; m.kind=Move.Kind.THROW
	m.startup=su; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=dmg; m.stamina_cost=2
	return m

func test_block_negates_attack():
	var s := _state()
	# attacker hits at t2 (startup2). defender blocks with active window covering t2.
	var atk := Plan.new(); atk.add(PlacedMove.new(_atk(10, 2), 0))
	var dfn := Plan.new(); dfn.add(PlacedMove.new(_defense(Move.Kind.BLOCK, 1, 3), 0)) # active t1..t3
	CombatSim.simulate(s, [atk, dfn])
	assert_eq(s.hp[1], 50, "blocked, no damage")

func test_dodge_makes_attack_whiff():
	var s := _state()
	var atk := Plan.new(); atk.add(PlacedMove.new(_atk(10, 2, true), 0)) # heavy, hits t2
	var dfn := Plan.new(); dfn.add(PlacedMove.new(_defense(Move.Kind.DODGE, 1, 3), 0)) # dodge t1..t3
	var ev := CombatSim.simulate(s, [atk, dfn])
	assert_eq(s.hp[1], 50, "dodged, no damage")
	assert_eq(ev.filter(func(e): return e.type == &"whiff").size(), 1)

func test_throw_breaks_block():
	var s := _state()
	var thr := Plan.new(); thr.add(PlacedMove.new(_throw(6, 2), 0)) # hits t2
	var dfn := Plan.new(); dfn.add(PlacedMove.new(_defense(Move.Kind.BLOCK, 1, 3), 0))
	CombatSim.simulate(s, [thr, dfn])
	assert_eq(s.hp[1], 40, "throw break: 6 + 4 bonus = 10")

func test_blind_throw_is_weak():
	var s := _state()
	var thr := Plan.new(); thr.add(PlacedMove.new(_throw(6, 2), 0))
	var idle := Plan.new() # defender does nothing
	var ev := CombatSim.simulate(s, [thr, idle])
	assert_eq(s.hp[1], 50, "throw on non-blocker deals 0")
	assert_eq(ev.filter(func(e): return e.type == &"whiff").size(), 1)
```

- [ ] **Step 2: Run to verify failure**

Run: `bash run_tests.sh -gtest=res://test/unit/test_sim_triangle.gd`
Expected: FAIL.

- [ ] **Step 3: Implement full `_resolve_hit`**

Add constant near the others: `const THROW_BREAK_BONUS := 4`.
Replace `_resolve_hit` with:

```gdscript
static func _resolve_hit(state: CombatState, actors: Array, attacker: int, atk: Move, d: Dictionary, t: int, events) -> void:
	var defender := 1 - attacker
	var def_phase: StringName = d["phase"]
	var def_move: Move = d["move"]
	var def_active_defense := def_phase == &"active" and def_move != null \
		and (def_move.kind == Move.Kind.BLOCK or def_move.kind == Move.Kind.DODGE)

	# DODGE beats everything that targets it: attack/throw whiffs.
	if def_active_defense and def_move.kind == Move.Kind.DODGE:
		_whiff(state, attacker, atk, t, events)
		return

	if atk.kind == Move.Kind.THROW:
		if def_active_defense and def_move.kind == Move.Kind.BLOCK:
			var dmg := atk.damage + THROW_BREAK_BONUS
			state.hp[defender] = max(0, state.hp[defender] - dmg)
			events.append(CombatEvent.new(t, &"throw_break", attacker, defender, dmg, atk.id))
		else:
			# blind throw: weak
			_whiff(state, attacker, atk, t, events)
		return

	# atk.kind == ATTACK
	if def_active_defense and def_move.kind == Move.Kind.BLOCK:
		events.append(CombatEvent.new(t, &"block", attacker, defender, 0, atk.id))
		return
	if def_phase == &"startup" and atk.can_interrupt and def_move != null and not def_move.super_armor:
		actors[defender].cur = null
		actors[defender].elapsed = 0
		state.hp[defender] = max(0, state.hp[defender] - atk.damage)
		events.append(CombatEvent.new(t, &"interrupt", attacker, defender, atk.damage, atk.id))
		return
	state.hp[defender] = max(0, state.hp[defender] - atk.damage)
	events.append(CombatEvent.new(t, &"hit", attacker, defender, atk.damage, atk.id))

static func _whiff(state: CombatState, attacker: int, atk: Move, t: int, events) -> void:
	# Damage handling only; stamina penalty added in Task 8.
	events.append(CombatEvent.new(t, &"whiff", attacker, 1 - attacker, 0, atk.id))
```

- [ ] **Step 4: Run to verify pass**

Run: `bash run_tests.sh -gtest=res://test/unit/test_sim_triangle.gd` then `bash run_tests.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add src/combat/combat_sim.gd test/unit/test_sim_triangle.gd
git commit -m "feat(combat): attack/block/dodge/throw resolution triangle"
```

---

## Task 7: Stamina rewards/penalties + exhaustion damage bonus

Wire stamina deltas into the resolution outcomes and apply bonus damage while a defender is gasping.

**Files:**
- Modify: `src/combat/combat_sim.gd`
- Create: `test/unit/test_sim_stamina.gd`

**Interfaces:**
- Consumes: Task 6. Produces: stamina changes emitted as `&"stamina"` events with signed `amount`; gasping defender takes `+GASP_DAMAGE_BONUS` extra on any hit.
- New constant: `const GASP_DAMAGE_BONUS := 3`. Add helper `_add_stamina(state, idx, delta, t, events)` clamping to `[0, sta_max]`.
- Resolution rewards/penalties: hit/interrupt/throw_break → attacker `+REWARD_*`; block → defender `+REWARD_BLOCK`; whiff → attacker `-(PENALTY_WHIFF_HEAVY if is_heavy else PENALTY_WHIFF)`; interrupt → defender `-PENALTY_STAGGER`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_sim_stamina.gd`:
```gdscript
extends GutTest

func _state(sta := 10) -> CombatState:
	var s := CombatState.new()
	s.hp=[50,50]; s.max_hp=[50,50]; s.stamina=[sta,sta]; s.sta_max=[sta,sta]; s.n_ticks=12; s.gasp_len=3
	return s

func _atk(dmg, su, cost, heavy := false) -> Move:
	var m := Move.new(); m.id=&"a"; m.kind=Move.Kind.ATTACK
	m.startup=su; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=dmg; m.stamina_cost=cost; m.is_heavy=heavy
	return m

func _dodge(su, window) -> Move:
	var m := Move.new(); m.id=&"d"; m.kind=Move.Kind.DODGE; m.startup=su; m.active=window; m.recovery=1; m.stamina_cost=2
	return m

func test_hit_rewards_stamina():
	var s := _state(10)
	var p0 := Plan.new(); p0.add(PlacedMove.new(_atk(6,1,2), 0)) # cost2, +1 on hit
	var ev := CombatSim.simulate(s, [p0, Plan.new()])
	assert_eq(s.stamina[0], 9, "10 -2 cost +1 reward = 9")

func test_heavy_whiff_penalty():
	var s := _state(10)
	var atk := Plan.new(); atk.add(PlacedMove.new(_atk(10,2,2,true), 0)) # heavy hits t2
	var dfn := Plan.new(); dfn.add(PlacedMove.new(_dodge(1,3), 0))
	CombatSim.simulate(s, [atk, dfn])
	assert_eq(s.stamina[0], 4, "10 -2 cost -4 heavy whiff = 4")

func test_exhaustion_then_gasp_bonus_damage():
	# player has only 3 stamina, plans two 2-cost moves: 2nd can't pay -> gasp.
	var s := _state(3); s.gasp_len = 3
	var p0 := Plan.new()
	p0.add(PlacedMove.new(_atk(0,1,2), 0))   # pays (3->1), hit deals 0
	p0.add(PlacedMove.new(_atk(0,1,2), 3))   # needs 2, only has (1 + reward). will it gasp?
	# enemy lands a hit during the player's gasp window to verify bonus
	var p1 := Plan.new(); p1.add(PlacedMove.new(_atk(5,1,2), 3)) # hits t4
	var ev := CombatSim.simulate(s, [p0, p1])
	var exhausts := ev.filter(func(e): return e.type == &"exhaust")
	assert_true(exhausts.size() >= 1, "player exhausted on 2nd move")
```

- [ ] **Step 2: Run to verify failure**

Run: `bash run_tests.sh -gtest=res://test/unit/test_sim_stamina.gd`
Expected: FAIL on stamina assertions.

- [ ] **Step 3: Implement stamina wiring**

Add constant: `const GASP_DAMAGE_BONUS := 3`.

Add helper:
```gdscript
static func _add_stamina(state: CombatState, idx: int, delta: int, t: int, events) -> void:
	if delta == 0:
		return
	state.stamina[idx] = clampi(state.stamina[idx] + delta, 0, state.sta_max[idx])
	events.append(CombatEvent.new(t, &"stamina", idx, idx, delta, &""))
```

Add a gasp helper to apply bonus damage:
```gdscript
static func _is_gasping(actors: Array, idx: int, t: int) -> bool:
	return t < actors[idx].gasp_until

static func _apply_damage(state: CombatState, actors: Array, defender: int, base: int, t: int) -> int:
	var dmg := base
	if _is_gasping(actors, defender, t) and base > 0:
		dmg += GASP_DAMAGE_BONUS
	state.hp[defender] = max(0, state.hp[defender] - dmg)
	return dmg
```

Update `_resolve_hit` damage applications to use `_apply_damage` and add rewards/penalties. Replace `_resolve_hit` and `_whiff` with:
```gdscript
static func _resolve_hit(state: CombatState, actors: Array, attacker: int, atk: Move, d: Dictionary, t: int, events) -> void:
	var defender := 1 - attacker
	var def_phase: StringName = d["phase"]
	var def_move: Move = d["move"]
	var def_active_defense := def_phase == &"active" and def_move != null \
		and (def_move.kind == Move.Kind.BLOCK or def_move.kind == Move.Kind.DODGE)

	if def_active_defense and def_move.kind == Move.Kind.DODGE:
		_whiff(state, attacker, atk, t, events)
		return

	if atk.kind == Move.Kind.THROW:
		if def_active_defense and def_move.kind == Move.Kind.BLOCK:
			var dmg := _apply_damage(state, actors, defender, atk.damage + THROW_BREAK_BONUS, t)
			events.append(CombatEvent.new(t, &"throw_break", attacker, defender, dmg, atk.id))
			_add_stamina(state, attacker, REWARD_HIT, t, events)
		else:
			_whiff(state, attacker, atk, t, events)
		return

	if def_active_defense and def_move.kind == Move.Kind.BLOCK:
		events.append(CombatEvent.new(t, &"block", attacker, defender, 0, atk.id))
		_add_stamina(state, defender, REWARD_BLOCK, t, events)
		return
	if def_phase == &"startup" and atk.can_interrupt and def_move != null and not def_move.super_armor:
		actors[defender].cur = null
		actors[defender].elapsed = 0
		var dmg := _apply_damage(state, actors, defender, atk.damage, t)
		events.append(CombatEvent.new(t, &"interrupt", attacker, defender, dmg, atk.id))
		_add_stamina(state, attacker, REWARD_INTERRUPT, t, events)
		_add_stamina(state, defender, -PENALTY_STAGGER, t, events)
		return
	var hd := _apply_damage(state, actors, defender, atk.damage, t)
	events.append(CombatEvent.new(t, &"hit", attacker, defender, hd, atk.id))
	_add_stamina(state, attacker, REWARD_HIT, t, events)

static func _whiff(state: CombatState, attacker: int, atk: Move, t: int, events) -> void:
	events.append(CombatEvent.new(t, &"whiff", attacker, 1 - attacker, 0, atk.id))
	var pen := PENALTY_WHIFF_HEAVY if atk.is_heavy else PENALTY_WHIFF
	_add_stamina(state, attacker, -pen, t, events)
```

Update `_maybe_hit` signature already passes `actors` (from Task 5). Ensure `_apply_damage` callers pass `actors`.

- [ ] **Step 4: Run to verify pass**

Run: `bash run_tests.sh`
Expected: all PASS (stamina + prior tasks).

- [ ] **Step 5: Commit**

```bash
git add src/combat/combat_sim.gd test/unit/test_sim_stamina.gd
git commit -m "feat(combat): stamina rewards/penalties and gasp damage bonus"
```

---

## Task 8: Combo rules — plan-time fusion (homogeneous + heterogeneous, multi-tick)

**Files:**
- Create: `src/combat/combo_rules.gd`, `test/unit/test_combo.gd`

**Interfaces:**
- Produces: `ComboRules` with:
  - `func add_recipe(slots: Array, result: Move) -> void` — `slots` is an `Array` of `Dictionary` predicates, each one of: `{"tag": &"腿法"}`, `{"kind": Move.Kind.ATTACK}`, `{"id": &"kick"}`, or `{"any": true}`.
  - `func apply(plan: Plan) -> Plan` — returns a NEW plan where any **back-to-back, in-order** run of placed moves matching a recipe's slots (each next move starts exactly at previous `end_tick()`) is replaced by the recipe's `result` placed at the run's first start. Longest recipes matched first; scan left to right; a fused move is not re-fused in the same pass.
- Determinism: recipes tried in registration order within a length tier; tiers from longest to shortest.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_combo.gd`:
```gdscript
extends GutTest

func _kick(id := &"kick") -> Move:
	var m := Move.new(); m.id=id; m.kind=Move.Kind.ATTACK; m.tags=[&"腿法"]
	m.startup=1; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=4; m.stamina_cost=2
	return m

func _block() -> Move:
	var m := Move.new(); m.id=&"guard"; m.kind=Move.Kind.BLOCK; m.startup=1; m.active=2; m.recovery=1; m.stamina_cost=2
	return m

func _throw() -> Move:
	var m := Move.new(); m.id=&"qin"; m.kind=Move.Kind.THROW; m.startup=1; m.active=1; m.recovery=1; m.hit_offsets=[0]; m.damage=5; m.stamina_cost=2
	return m

func _combo_result(id) -> Move:
	var m := Move.new(); m.id=id; m.kind=Move.Kind.ATTACK; m.startup=1; m.active=2; m.recovery=1
	m.hit_offsets=[0,1]; m.damage=8; m.stamina_cost=0  # paid via originals already
	return m

func test_homogeneous_three_kicks_fuse():
	var rules := ComboRules.new()
	rules.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"},{"tag":&"腿法"}], _combo_result(&"chain_kick"))
	var p := Plan.new()
	# back-to-back: each dur=3
	p.add(PlacedMove.new(_kick(), 0))
	p.add(PlacedMove.new(_kick(), 3))
	p.add(PlacedMove.new(_kick(), 6))
	var fused := rules.apply(p)
	assert_eq(fused.moves.size(), 1)
	assert_eq(fused.moves[0].move.id, &"chain_kick")
	assert_eq(fused.moves[0].start, 0)

func test_heterogeneous_by_kind():
	var rules := ComboRules.new()
	rules.add_recipe([{"kind":Move.Kind.ATTACK},{"kind":Move.Kind.BLOCK},{"kind":Move.Kind.THROW}], _combo_result(&"qiankun"))
	var p := Plan.new()
	p.add(PlacedMove.new(_kick(), 0))   # dur3
	p.add(PlacedMove.new(_block(), 3))  # dur4 -> end 7
	p.add(PlacedMove.new(_throw(), 7))  # dur3
	var fused := rules.apply(p)
	assert_eq(fused.moves.size(), 1)
	assert_eq(fused.moves[0].move.id, &"qiankun")

func test_gap_breaks_combo():
	var rules := ComboRules.new()
	rules.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"},{"tag":&"腿法"}], _combo_result(&"chain_kick"))
	var p := Plan.new()
	p.add(PlacedMove.new(_kick(), 0))
	p.add(PlacedMove.new(_kick(), 3))
	p.add(PlacedMove.new(_kick(), 7)) # gap (prev ends at 6)
	var fused := rules.apply(p)
	assert_eq(fused.moves.size(), 3, "gap prevents fusion")

func test_longest_match_first():
	var rules := ComboRules.new()
	rules.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"}], _combo_result(&"double_kick"))
	rules.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"},{"tag":&"腿法"}], _combo_result(&"chain_kick"))
	var p := Plan.new()
	p.add(PlacedMove.new(_kick(), 0)); p.add(PlacedMove.new(_kick(), 3)); p.add(PlacedMove.new(_kick(), 6))
	var fused := rules.apply(p)
	assert_eq(fused.moves[0].move.id, &"chain_kick", "3-match beats 2-match")
```

- [ ] **Step 2: Run to verify failure**

Run: `bash run_tests.sh -gtest=res://test/unit/test_combo.gd`
Expected: FAIL — `ComboRules` not found.

- [ ] **Step 3: Implement ComboRules**

Create `src/combat/combo_rules.gd`:
```gdscript
class_name ComboRules
extends RefCounted

class Recipe:
	var slots: Array
	var result: Move
	func _init(p_slots: Array, p_result: Move) -> void:
		slots = p_slots
		result = p_result

var _recipes: Array[Recipe] = []

func add_recipe(slots: Array, result: Move) -> void:
	_recipes.append(Recipe.new(slots, result))

func _slot_matches(slot: Dictionary, move: Move) -> bool:
	if slot.has("any"):
		return true
	if slot.has("id"):
		return move.id == slot["id"]
	if slot.has("kind"):
		return move.kind == slot["kind"]
	if slot.has("tag"):
		return (slot["tag"] as StringName) in move.tags
	return false

func _matches_run(seq: Array, start_idx: int, recipe: Recipe) -> bool:
	if start_idx + recipe.slots.size() > seq.size():
		return false
	for k in recipe.slots.size():
		var pm: PlacedMove = seq[start_idx + k]
		if not _slot_matches(recipe.slots[k], pm.move):
			return false
		if k > 0:
			var prev: PlacedMove = seq[start_idx + k - 1]
			if pm.start != prev.end_tick():
				return false # must be back-to-back
	return true

func apply(plan: Plan) -> Plan:
	var seq := plan.sorted()
	var by_len := _recipes.duplicate()
	by_len.sort_custom(func(a, b): return a.slots.size() > b.slots.size())
	var out := Plan.new()
	var i := 0
	while i < seq.size():
		var fused := false
		for recipe in by_len:
			if _matches_run(seq, i, recipe):
				out.add(PlacedMove.new(recipe.result, seq[i].start))
				i += recipe.slots.size()
				fused = true
				break
		if not fused:
			out.add(seq[i])
			i += 1
	return out
```

- [ ] **Step 4: Run to verify pass**

Run: `bash run_tests.sh -gtest=res://test/unit/test_combo.gd` then `bash run_tests.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add src/combat/combo_rules.gd test/unit/test_combo.gd
git commit -m "feat(combat): plan-time combo fusion (tag/kind/id/wildcard recipes)"
```

---

## Task 9: 腿法 content — moves + combo library + a sanity fight test

**Files:**
- Create: `src/content/moves/` (`.tres` resources), `src/content/combos.gd`, `src/content/deck.gd`, `test/unit/test_content_fight.gd`

**Interfaces:**
- Produces:
  - `ComboLibrary.build() -> ComboRules` (static) — registers: `[腿法,腿法,腿法] → 连环踢` and `[连环踢-as-id, 腿法, 腿法] → 佛山无影脚` and `[攻,防,投] → 乾坤大挪移`.
  - `Deck.starter() -> Array[Move]` (static) — the ~10 base moves below.
- Moves (create each as both a `.tres` and via `Deck.starter()` returning new instances; the slice can rely on `Deck.starter()` and `.tres` are for the editor). Define ids: `&"jab_kick"`(轻踢,攻,startup1,dmg4,cost2,can_interrupt), `&"low_kick"`(扫腿,攻,dmg5,cost2,tags腿法), `&"heavy_kick"`(重踢,攻,heavy,startup3,dmg12,cost4,super_armor,tags腿法), `&"guard"`(格挡,BLOCK,active3,cost2), `&"dodge"`(身法,DODGE,active2,cost2,tags轻功), `&"throw"`(擒拿,THROW,dmg5,cost3), plus combo results `&"chain_kick"`(连环踢,active2,hits[0,1],dmg14,cost0,tags腿法), `&"wuying"`(佛山无影脚,active3,hits[0,1,2],dmg22,super_armor,cost0,tags腿法), `&"qiankun"`(乾坤大挪移,THROW-like break, dmg18,cost0).

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_content_fight.gd`:
```gdscript
extends GutTest

func test_starter_deck_has_each_role():
	var deck := Deck.starter()
	var kinds := {}
	for m in deck:
		kinds[m.kind] = true
	assert_true(kinds.has(Move.Kind.ATTACK))
	assert_true(kinds.has(Move.Kind.BLOCK))
	assert_true(kinds.has(Move.Kind.DODGE))
	assert_true(kinds.has(Move.Kind.THROW))
	assert_true(deck.any(func(m): return m.can_interrupt), "has an interrupt move")
	assert_true(deck.any(func(m): return m.super_armor), "has an armored move")

func test_three_kicks_fuse_into_chain_kick_and_deal_more():
	var rules := ComboLibrary.build()
	var find := func(id):
		for m in Deck.starter():
			if m.id == id: return m
		return null
	var k = find.call(&"low_kick")
	var p := Plan.new()
	p.add(PlacedMove.new(k, 0))
	p.add(PlacedMove.new(k, k.total_duration()))
	p.add(PlacedMove.new(k, 2 * k.total_duration()))
	var fused := rules.apply(p)
	assert_eq(fused.moves.size(), 1)
	assert_eq(fused.moves[0].move.id, &"chain_kick")

func test_full_fight_runs_to_a_death():
	var s := CombatState.new()
	s.hp=[30,30]; s.max_hp=[30,30]; s.stamina=[12,12]; s.sta_max=[12,12]; s.n_ticks=10
	var find := func(id):
		for m in Deck.starter():
			if m.id == id: return m
		return null
	var hk = find.call(&"heavy_kick")
	var p0 := Plan.new(); p0.add(PlacedMove.new(hk, 0)); p0.add(PlacedMove.new(hk, hk.total_duration()))
	var ev := CombatSim.simulate(s, [p0, Plan.new()])
	assert_true(s.hp[1] < 30, "enemy took damage")
```

- [ ] **Step 2: Run to verify failure**

Run: `bash run_tests.sh -gtest=res://test/unit/test_content_fight.gd`
Expected: FAIL — `Deck` / `ComboLibrary` not found.

- [ ] **Step 3: Implement content**

Create `src/content/deck.gd`:
```gdscript
class_name Deck
extends RefCounted

static func _m(id, name, kind, su, act, rec, dmg, cost, opts := {}) -> Move:
	var m := Move.new()
	m.id = id; m.move_name = name; m.kind = kind
	m.startup = su; m.active = act; m.recovery = rec
	m.damage = dmg; m.stamina_cost = cost
	m.hit_offsets = opts.get("hits", [0])
	m.tags = opts.get("tags", [] as Array[StringName])
	m.can_interrupt = opts.get("interrupt", false)
	m.super_armor = opts.get("armor", false)
	m.is_heavy = opts.get("heavy", false)
	m.priority = opts.get("priority", 0)
	return m

static func starter() -> Array[Move]:
	return [
		_m(&"jab_kick", "轻踢", Move.Kind.ATTACK, 1, 1, 1, 4, 2, {"tags":[&"腿法"], "interrupt":true, "priority":5}),
		_m(&"low_kick", "扫腿", Move.Kind.ATTACK, 1, 1, 1, 5, 2, {"tags":[&"腿法"]}),
		_m(&"heavy_kick", "重踢", Move.Kind.ATTACK, 3, 1, 2, 12, 4, {"tags":[&"腿法"], "heavy":true, "armor":true}),
		_m(&"guard", "格挡", Move.Kind.BLOCK, 1, 3, 1, 0, 2, {}),
		_m(&"dodge", "身法", Move.Kind.DODGE, 1, 2, 1, 0, 2, {"tags":[&"轻功"]}),
		_m(&"throw", "擒拿", Move.Kind.THROW, 1, 1, 1, 5, 3, {}),
	]

# combo result moves (not in hand; produced by fusion)
static func chain_kick() -> Move:
	return _m(&"chain_kick", "连环踢", Move.Kind.ATTACK, 1, 2, 1, 14, 0, {"tags":[&"腿法"], "hits":[0,1]})
static func wuying() -> Move:
	return _m(&"wuying", "佛山无影脚", Move.Kind.ATTACK, 1, 3, 1, 22, 0, {"tags":[&"腿法"], "hits":[0,1,2], "armor":true})
static func qiankun() -> Move:
	return _m(&"qiankun", "乾坤大挪移", Move.Kind.THROW, 1, 1, 1, 18, 0, {})
```

Create `src/content/combos.gd`:
```gdscript
class_name ComboLibrary
extends RefCounted

static func build() -> ComboRules:
	var r := ComboRules.new()
	# 三连腿法 -> 连环踢
	r.add_recipe([{"tag":&"腿法"},{"tag":&"腿法"},{"tag":&"腿法"}], Deck.chain_kick())
	# 连环踢 + 两腿 -> 佛山无影脚
	r.add_recipe([{"id":&"chain_kick"},{"tag":&"腿法"},{"tag":&"腿法"}], Deck.wuying())
	# 攻 + 防 + 投 -> 乾坤大挪移
	r.add_recipe([{"kind":Move.Kind.ATTACK},{"kind":Move.Kind.BLOCK},{"kind":Move.Kind.THROW}], Deck.qiankun())
	return r
```

- [ ] **Step 4: Run to verify pass**

Run: `bash run_tests.sh -gtest=res://test/unit/test_content_fight.gd` then `bash run_tests.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add src/content/ test/unit/test_content_fight.gd
git commit -m "feat(content): 腿法 starter deck and combo library"
```

---

## Task 10: AI planner + partial intent

**Files:**
- Create: `src/ai/ai_planner.gd`, `test/unit/test_ai.gd`

**Interfaces:**
- Produces:
  - `AiPlanner.new(seed: int)`; `func plan(deck: Array[Move], sta_max: int, n_ticks: int) -> Plan` — deterministic for a given seed; produces a valid plan (passes `Plan.is_valid`).
  - `func intent(plan: Plan, reveal_count: int) -> Array[StringName]` — returns the move ids of the first `reveal_count` placed moves (partial info shown to player); remaining are hidden (`&"?"`).
- Determinism: uses a local `RandomNumberGenerator` seeded in `_init`; never the global RNG.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_ai.gd`:
```gdscript
extends GutTest

func test_plan_is_valid_and_deterministic():
	var a := AiPlanner.new(42)
	var p1 := a.plan(Deck.starter(), 10, 10)
	assert_true(p1.is_valid(10, 10))
	var b := AiPlanner.new(42)
	var p2 := b.plan(Deck.starter(), 10, 10)
	assert_eq(p1.sorted().map(func(pm): return pm.move.id), p2.sorted().map(func(pm): return pm.move.id))

func test_intent_partial_reveal():
	var a := AiPlanner.new(7)
	var p := a.plan(Deck.starter(), 10, 10)
	var shown := a.intent(p, 1)
	assert_eq(shown.size(), p.sorted().size())
	assert_ne(shown[0], &"?", "first move revealed")
	if shown.size() > 1:
		assert_eq(shown[1], &"?", "later moves hidden")
```

- [ ] **Step 2: Run to verify failure**

Run: `bash run_tests.sh -gtest=res://test/unit/test_ai.gd`
Expected: FAIL — `AiPlanner` not found.

- [ ] **Step 3: Implement AiPlanner**

Create `src/ai/ai_planner.gd`:
```gdscript
class_name AiPlanner
extends RefCounted

var _rng := RandomNumberGenerator.new()

func _init(seed: int) -> void:
	_rng.seed = seed

func plan(deck: Array[Move], sta_max: int, n_ticks: int) -> Plan:
	var p := Plan.new()
	var budget := int(floor(1.5 * sta_max))
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

func intent(plan: Plan, reveal_count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var s := plan.sorted()
	for i in s.size():
		out.append(s[i].move.id if i < reveal_count else &"?")
	return out
```

- [ ] **Step 4: Run to verify pass**

Run: `bash run_tests.sh -gtest=res://test/unit/test_ai.gd` then `bash run_tests.sh`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add src/ai/ai_planner.gd test/unit/test_ai.gd
git commit -m "feat(ai): deterministic enemy planner with partial intent"
```

---

## Task 11: Watch-phase replay scene (programmer art)

This is presentation; verify manually by running the scene. No unit test (rendering).

**Files:**
- Create: `src/scenes/watch_phase.gd`, `src/scenes/watch_phase.tscn`

**Interfaces:**
- Produces: `WatchPhase` node with `func play(state_before: CombatState, plans: Array, events: Array[CombatEvent]) -> void` that steps a timer and emits `signal finished`. Renders two HP bars + two stamina bars + a scrolling tick cursor + floating labels for events (`hit/-N`, `block`, `interrupt!`, `whiff`, `投破防`, `喘息`).

- [ ] **Step 1: Build the scene**

Create `src/scenes/watch_phase.tscn` with this node tree (set via editor or by writing the `.tscn`):
```
WatchPhase (Control, script=watch_phase.gd)
├── P0Health (ProgressBar)   anchors top-left
├── P0Stamina (ProgressBar)  below P0Health
├── P1Health (ProgressBar)   anchors top-right
├── P1Stamina (ProgressBar)  below P1Health
├── TickLabel (Label)        center-top, shows "tick N"
└── EventLog (VBoxContainer) center, floating event lines
```

- [ ] **Step 2: Implement the script**

Create `src/scenes/watch_phase.gd`:
```gdscript
extends Control

signal finished

@onready var _p0h: ProgressBar = $P0Health
@onready var _p1h: ProgressBar = $P1Health
@onready var _p0s: ProgressBar = $P0Stamina
@onready var _p1s: ProgressBar = $P1Stamina
@onready var _tick: Label = $TickLabel
@onready var _log: VBoxContainer = $EventLog

var _events: Array = []
var _state: CombatState
var _t := 0
var _max_t := 0
var _accum := 0.0
const STEP := 0.35  # seconds per tick

func play(state_before: CombatState, _plans: Array, events: Array) -> void:
	_state = state_before.clone()
	_events = events
	_p0h.max_value = _state.max_hp[0]; _p0h.value = _state.hp[0]
	_p1h.max_value = _state.max_hp[1]; _p1h.value = _state.hp[1]
	_p0s.max_value = _state.sta_max[0]; _p0s.value = _state.stamina[0]
	_p1s.max_value = _state.sta_max[1]; _p1s.value = _state.stamina[1]
	_t = 0
	_max_t = 0
	for e in _events:
		_max_t = max(_max_t, e.tick)
	set_process(true)

func _process(delta: float) -> void:
	_accum += delta
	if _accum < STEP:
		return
	_accum = 0.0
	_tick.text = "tick %d" % _t
	for e in _events:
		if e.tick == _t:
			_apply_event(e)
	_t += 1
	if _t > _max_t + 1:
		set_process(false)
		finished.emit()

func _apply_event(e) -> void:
	match e.type:
		&"hit", &"interrupt", &"throw_break":
			if e.target == 0: _p0h.value = max(0, _p0h.value - e.amount)
			else: _p1h.value = max(0, _p1h.value - e.amount)
		&"stamina":
			if e.actor == 0: _p0s.value = clampf(_p0s.value + e.amount, 0, _p0s.max_value)
			else: _p1s.value = clampf(_p1s.value + e.amount, 0, _p1s.max_value)
	var line := Label.new()
	line.text = "t%d P%d %s %s" % [e.tick, e.actor, str(e.type), str(e.move_id)]
	_log.add_child(line)
	if _log.get_child_count() > 8:
		_log.get_child(0).queue_free()
```

- [ ] **Step 3: Manual smoke check**

Temporarily set `watch_phase.tscn` as main scene OR add a small `_ready()` that builds a fake fight. Run:
`"/c/Users/Tianyu/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --path . src/scenes/watch_phase.tscn`
Expected: bars render; no script errors in console. (Full data comes from Task 13.)

- [ ] **Step 4: Commit**

```bash
git add src/scenes/watch_phase.gd src/scenes/watch_phase.tscn
git commit -m "feat(ui): watch-phase event replay (programmer art)"
```

---

## Task 12: Plan-phase scene — place moves on the timeline

**Files:**
- Create: `src/scenes/plan_phase.gd`, `src/scenes/plan_phase.tscn`

**Interfaces:**
- Produces: `PlanPhase` node with:
  - `func setup(deck: Array[Move], rules: ComboRules, sta_max: int, n_ticks: int, enemy_intent: Array[StringName]) -> void`
  - `signal plan_committed(plan: Plan)` emitted (with combos already fused via `rules.apply`) when the player presses Commit.
  - Live UI: a row of deck buttons; a timeline of `n_ticks` slot buttons; clicking a deck move then a slot places it (if valid via `Plan.is_valid` after add); a stamina label showing `used / sta_max (max 1.5x)`; a combo preview line (`rules.apply(current).moves` ids); the enemy intent shown read-only.

- [ ] **Step 1: Build the scene**

Create `src/scenes/plan_phase.tscn`:
```
PlanPhase (Control, script=plan_phase.gd)
├── DeckRow (HBoxContainer)        # filled at runtime with one Button per move
├── Timeline (HBoxContainer)       # filled at runtime with n_ticks Buttons
├── StaminaLabel (Label)
├── ComboPreview (Label)
├── EnemyIntent (Label)
└── CommitButton (Button, text="出招")
```

- [ ] **Step 2: Implement the script**

Create `src/scenes/plan_phase.gd`:
```gdscript
extends Control

signal plan_committed(plan)

@onready var _deck_row: HBoxContainer = $DeckRow
@onready var _timeline: HBoxContainer = $Timeline
@onready var _stamina: Label = $StaminaLabel
@onready var _combo: Label = $ComboPreview
@onready var _intent: Label = $EnemyIntent
@onready var _commit: Button = $CommitButton

var _deck: Array[Move] = []
var _rules: ComboRules
var _sta_max := 10
var _n_ticks := 10
var _selected: Move = null
var _plan := Plan.new()

func setup(deck: Array[Move], rules: ComboRules, sta_max: int, n_ticks: int, enemy_intent: Array[StringName]) -> void:
	_deck = deck; _rules = rules; _sta_max = sta_max; _n_ticks = n_ticks
	_plan = Plan.new()
	_intent.text = "对手意图: " + ", ".join(enemy_intent.map(func(x): return str(x)))
	_build_deck()
	_build_timeline()
	_refresh()
	if not _commit.pressed.is_connected(_on_commit):
		_commit.pressed.connect(_on_commit)

func _build_deck() -> void:
	for c in _deck_row.get_children(): c.queue_free()
	for m in _deck:
		var b := Button.new()
		b.text = "%s(%d)" % [m.move_name, m.stamina_cost]
		b.pressed.connect(func(): _selected = m; _refresh())
		_deck_row.add_child(b)

func _build_timeline() -> void:
	for c in _timeline.get_children(): c.queue_free()
	for i in _n_ticks:
		var b := Button.new()
		b.text = str(i)
		b.custom_minimum_size = Vector2(34, 34)
		b.pressed.connect(_on_slot.bind(i))
		_timeline.add_child(b)

func _on_slot(tick: int) -> void:
	if _selected == null:
		return
	var trial := _clone_plan()
	trial.add(PlacedMove.new(_selected, tick))
	if trial.is_valid(_sta_max, _n_ticks):
		_plan = trial
	_refresh()

func _clone_plan() -> Plan:
	var p := Plan.new()
	for pm in _plan.moves:
		p.add(PlacedMove.new(pm.move, pm.start))
	return p

func _refresh() -> void:
	_stamina.text = "体力 %d / %d (可超额至 %d)" % [_plan.total_cost(), _sta_max, int(floor(1.5 * _sta_max))]
	var fused := _rules.apply(_plan)
	_combo.text = "连招预览: " + ", ".join(fused.moves.map(func(pm): return pm.move.move_name))
	# mark occupied ticks
	for pm in _plan.moves:
		for k in pm.move.total_duration():
			var idx := pm.start + k
			if idx < _timeline.get_child_count():
				(_timeline.get_child(idx) as Button).modulate = Color(1, 0.7, 0.4)

func _on_commit() -> void:
	plan_committed.emit(_rules.apply(_plan))
```

- [ ] **Step 3: Manual smoke check**

Run the scene directly:
`"/c/Users/Tianyu/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --path . src/scenes/plan_phase.tscn`
(It will error on empty deck until wired in Task 13; just confirm no parse errors by checking `--check-only`:)
`"/c/Users/Tianyu/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --headless --check-only --script src/scenes/plan_phase.gd`
Expected: no parse errors.

- [ ] **Step 4: Commit**

```bash
git add src/scenes/plan_phase.gd src/scenes/plan_phase.tscn
git commit -m "feat(ui): plan-phase timeline placement with combo preview"
```

---

## Task 13: Fight orchestrator — full round loop (plan → sim → watch → repeat)

**Files:**
- Create: `src/scenes/fight.gd`, `src/scenes/fight.tscn`
- Modify: `project.godot` (set `run/main_scene` to `res://src/scenes/fight.tscn`)

**Interfaces:**
- Consumes everything. Produces a playable loop: shows PlanPhase, on commit runs `CombatSim.simulate` (player plan vs AI plan), plays WatchPhase, then starts a new round with refreshed stamina, until a `&"death"` event — then shows a win/lose label.
- Persistent across rounds: `CombatState.hp` and `max_hp`. Reset `stamina = sta_max` each round.

- [ ] **Step 1: Build the scene**

Create `src/scenes/fight.tscn`:
```
Fight (Node, script=fight.gd)
├── PlanPhase (instance of src/scenes/plan_phase.tscn)
├── WatchPhase (instance of src/scenes/watch_phase.tscn, visible=false)
└── ResultLabel (Label, visible=false)
```

- [ ] **Step 2: Implement the orchestrator**

Create `src/scenes/fight.gd`:
```gdscript
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
	_state.n_ticks = 10
	_rules = ComboLibrary.build()
	_deck = Deck.starter()
	_plan_phase.plan_committed.connect(_on_player_plan)
	_watch_phase.finished.connect(_on_watch_done)
	_start_round()

func _start_round() -> void:
	_round += 1
	_state.stamina = _state.sta_max.duplicate()
	_result.visible = false
	_watch_phase.visible = false
	_plan_phase.visible = true
	var ai_plan := _ai.plan(_deck, _state.sta_max[1], _state.n_ticks)
	_pending_ai_plan = ai_plan
	_plan_phase.setup(_deck, _rules, _state.sta_max[0], _state.n_ticks, _ai.intent(ai_plan, 1))

var _pending_ai_plan: Plan

func _on_player_plan(player_plan: Plan) -> void:
	var before := _state.clone()
	var events := CombatSim.simulate(_state, [player_plan, _pending_ai_plan])
	_plan_phase.visible = false
	_watch_phase.visible = true
	_watch_phase.play(before, [player_plan, _pending_ai_plan], events)

func _on_watch_done() -> void:
	if _state.hp[0] <= 0 or _state.hp[1] <= 0:
		_result.visible = true
		_result.text = "胜利!" if _state.hp[1] <= 0 else "败北..."
		_watch_phase.visible = false
		return
	_start_round()
```

- [ ] **Step 3: Set main scene**

In `project.godot`, set:
```
[application]
run/main_scene="res://src/scenes/fight.tscn"
```

- [ ] **Step 4: Manual end-to-end check**

Run the game:
`"/c/Users/Tianyu/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --path .`
Verify: deck buttons appear; select a move, click timeline slots; combo preview updates when placing 3 腿法 back-to-back; press 出招; watch bars animate; rounds repeat; a win/lose label eventually shows.

- [ ] **Step 5: Run full test suite**

Run: `bash run_tests.sh`
Expected: all unit tests still PASS.

- [ ] **Step 6: Commit**

```bash
git add src/scenes/fight.gd src/scenes/fight.tscn project.godot
git commit -m "feat: playable fight orchestrator (plan -> sim -> watch loop)"
```

---

## Task 14: Slice polish pass — README + balance self-play harness

**Files:**
- Create: `test/unit/test_balance.gd`, `docs/superpowers/slice-notes.md`

**Interfaces:**
- Produces: a headless self-play test that runs N AI-vs-AI fights and asserts fights end (no infinite loops, both sides deal damage) — a guardrail + a place to eyeball balance. Plus a short README on how to run the game and tests.

- [ ] **Step 1: Write the self-play test**

Create `test/unit/test_balance.gd`:
```gdscript
extends GutTest

func test_ai_vs_ai_fights_terminate_and_deal_damage():
	var wins := [0, 0]
	for seed in range(20):
		var s := CombatState.new()
		s.hp=[40,40]; s.max_hp=[40,40]; s.sta_max=[10,10]; s.stamina=[10,10]; s.n_ticks=10
		var a := AiPlanner.new(seed)
		var b := AiPlanner.new(seed + 1000)
		var rules := ComboLibrary.build()
		var rounds := 0
		while s.hp[0] > 0 and s.hp[1] > 0 and rounds < 40:
			s.stamina = s.sta_max.duplicate()
			var pa := rules.apply(a.plan(Deck.starter(), s.sta_max[0], s.n_ticks))
			var pb := rules.apply(b.plan(Deck.starter(), s.sta_max[1], s.n_ticks))
			CombatSim.simulate(s, [pa, pb])
			rounds += 1
		assert_true(rounds < 40, "fight %d terminated" % seed)
		if s.hp[0] <= 0: wins[1] += 1
		elif s.hp[1] <= 0: wins[0] += 1
	gut.p("AI win split: %s" % str(wins))
	assert_true(wins[0] + wins[1] > 0, "at least some fights resolved")
```

- [ ] **Step 2: Run to verify pass**

Run: `bash run_tests.sh -gtest=res://test/unit/test_balance.gd`
Expected: PASS; note the printed win split (tuning signal).

- [ ] **Step 3: Write the slice notes**

Create `docs/superpowers/slice-notes.md`:
```markdown
# Combat Slice — how to run

- Play: `"/c/Users/Tianyu/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe" --path .`
- Tests: `bash run_tests.sh`
- Single test file: `bash run_tests.sh -gtest=res://test/unit/test_sim_basic.gd`

## Tuning knobs
- Frames/damage/cost per move: `src/content/deck.gd`
- Combo recipes: `src/content/combos.gd`
- Stamina rewards/penalties + gasp: constants atop `src/combat/combat_sim.gd`
- Timeline length / gasp length: `CombatState` defaults
- Overcommit factor (1.5x): `Plan.is_valid`

## Next (post-slice)
Map/shop/relics/meta, more styles, art/audio, GodotSteam export.
```

- [ ] **Step 4: Commit**

```bash
git add test/unit/test_balance.gd docs/superpowers/slice-notes.md
git commit -m "test+docs: AI self-play balance guardrail and slice notes"
```

---

## Self-Review notes (resolved)

- **Spec coverage:** timeline+frames (T2/T4), interrupt affix + 霸体 (T5), 攻防投 + 格挡/闪避/用力过猛 + 投破防/盲投 (T6), 体力赌注 1.5x + 奖惩 + 喘息 (T3 validation, T7), 部分信息 (T10 intent), 标签连招升格 含同类/异类/多拍 (T8/T9), 模拟器与表现分离 + 确定性 + 批量对打 (T4/T14), TDD+GUT (all). 腿法 8–12 卡 with each role + interrupt + armor card (T9). UI plan→watch loop (T11–13). All covered.
- **Placeholders:** none — every code step has full code.
- **Type consistency:** `Move` fields, `Plan.is_valid(sta_max, n_ticks)`, `CombatSim.simulate(state, plans)`, `_resolve_hit(state, actors, attacker, atk, d, t, events)`, `ComboRules.apply(plan)`, `AiPlanner.plan/intent` names are consistent across tasks. Note: Task 4 introduces `_resolve_hit` without `actors`; Task 5 explicitly changes the signature to add `actors` and updates the caller — intentional evolution, called out in-task.

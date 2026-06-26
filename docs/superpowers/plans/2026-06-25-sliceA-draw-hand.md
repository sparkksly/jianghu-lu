# 子切片 A：抽卡手牌系统 实现计划

> **For agentic workers:** 本计划在当前会话内联执行(用户已批准跳过 review)。步骤用 `- [ ]`。

**Goal:** 排招从「调色板(任意招无限拖)」改为「手牌」:固定工具牌无限,进攻牌每回合有放回抽 6 张、一次性消耗(移除退回)。

**Architecture:** 新增纯逻辑 `Hand`(二分 + 有放回抽牌)。`fight.gd` 每回合组「工具牌 + 抽6进攻」当 deck 传给 `plan_phase.setup`(签名不变)。`plan_phase` 把 ATTACK 类视为一次性——从已放置 `_model.units` **派生**已用张数,`_build_deck` 只渲染「工具牌(全部) + 剩余进攻牌(手牌实例 − 已排)」,任何 model 改动后重建手牌区。

**Tech Stack:** Godot 4.6.1, GDScript, GUT。测试:`bash run_tests.sh`。

## Global Constraints
- 进攻牌 = `Move.Kind.ATTACK`;工具牌 = 非 ATTACK(STEP/BLOCK/DODGE/THROW)。
- 每回合有放回抽 **6** 张进攻牌(可重复)。进攻牌一次性消耗,移除退回。工具牌无限。
- `Move.id` 是 `StringName`,作消耗计数的 key。
- `plan_phase.setup` 签名**不变**:`setup(deck, rules, stamina_now, sta_max, n_ticks, enemy_intent)`;传入的 `deck` 即「本回合手牌」。
- 本切片**不做**:门派进攻池(暂用现有 9 个 ATTACK)、状态、选派、AI 抽牌。

---

### Task 1: Hand 纯逻辑(二分 + 有放回抽牌)

**Files:**
- Create: `src/content/hand.gd`
- Test: `test/unit/test_hand.gd`

**Interfaces:**
- Produces:
  - `Hand.attack_pool(deck: Array[Move]) -> Array[Move]`(仅 ATTACK)
  - `Hand.utilities(deck: Array[Move]) -> Array[Move]`(非 ATTACK)
  - `Hand.draw(pool: Array[Move], n: int, rng: RandomNumberGenerator) -> Array[Move]`(有放回,可重复)

- [ ] **Step 1: 写失败测试** `test/unit/test_hand.gd`
```gdscript
extends GutTest

func _move(id: String, kind) -> Move:
	var m := Move.new()
	m.id = id; m.move_name = id; m.kind = kind
	m.startup = 0; m.active = 1; m.recovery = 0
	return m

func _deck() -> Array[Move]:
	return [
		_move("jab", Move.Kind.ATTACK),
		_move("hook", Move.Kind.ATTACK),
		_move("guard", Move.Kind.BLOCK),
		_move("dodge", Move.Kind.DODGE),
		_move("step", Move.Kind.STEP),
		_move("grab", Move.Kind.THROW),
	]

func test_attack_pool_only_attacks() -> void:
	var pool := Hand.attack_pool(_deck())
	assert_eq(pool.size(), 2)
	for m in pool:
		assert_eq(m.kind, Move.Kind.ATTACK)

func test_utilities_excludes_attacks() -> void:
	var u := Hand.utilities(_deck())
	assert_eq(u.size(), 4)
	for m in u:
		assert_ne(m.kind, Move.Kind.ATTACK)

func test_draw_count_and_membership() -> void:
	var pool := Hand.attack_pool(_deck())
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	var drawn := Hand.draw(pool, 6, rng)
	assert_eq(drawn.size(), 6)
	for m in drawn:
		assert_true(pool.has(m))

func test_draw_is_deterministic_for_same_seed() -> void:
	var pool := Hand.attack_pool(_deck())
	var a := RandomNumberGenerator.new(); a.seed = 7
	var b := RandomNumberGenerator.new(); b.seed = 7
	var da := Hand.draw(pool, 6, a)
	var db := Hand.draw(pool, 6, b)
	for i in 6:
		assert_eq(da[i].id, db[i].id)

func test_draw_can_repeat_from_single_pool() -> void:
	var pool: Array[Move] = [_move("jab", Move.Kind.ATTACK)]
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var drawn := Hand.draw(pool, 4, rng)
	assert_eq(drawn.size(), 4)
	for m in drawn:
		assert_eq(m.id, &"jab")   # 有放回:同一招重复抽出
```

- [ ] **Step 2: 跑测试确认失败**
Run: `bash run_tests.sh -gselect=test_hand.gd`
Expected: FAIL（`Hand` 未定义）

- [ ] **Step 3: 实现** `src/content/hand.gd`
```gdscript
class_name Hand
extends RefCounted

# 进攻牌池 = ATTACK 类。
static func attack_pool(deck: Array[Move]) -> Array[Move]:
	var out: Array[Move] = []
	for m in deck:
		if m.kind == Move.Kind.ATTACK:
			out.append(m)
	return out

# 工具牌 = 非 ATTACK(步法/格挡/闪身/擒拿)。
static func utilities(deck: Array[Move]) -> Array[Move]:
	var out: Array[Move] = []
	for m in deck:
		if m.kind != Move.Kind.ATTACK:
			out.append(m)
	return out

# 有放回抽 n 张(可能重复)。pool 必须非空。
static func draw(pool: Array[Move], n: int, rng: RandomNumberGenerator) -> Array[Move]:
	var out: Array[Move] = []
	for i in n:
		out.append(pool[rng.randi_range(0, pool.size() - 1)])
	return out
```

- [ ] **Step 4: 跑测试确认通过**
Run: `bash run_tests.sh -gselect=test_hand.gd`
Expected: PASS（5/5）

- [ ] **Step 5: 提交**
```bash
git add src/content/hand.gd test/unit/test_hand.gd
git commit -m "feat(hand): 进攻/工具二分 + 有放回抽牌纯逻辑"
```

---

### Task 2: fight.gd 每回合发手牌

**Files:**
- Modify: `src/scenes/fight.gd`
- Test: `test/unit/test_fight.gd`

**Interfaces:**
- Consumes: `Hand.utilities`, `Hand.attack_pool`, `Hand.draw`(Task 1)
- Produces: `_start_round` 传给 `plan_phase.setup` 的 deck = `Hand.utilities(_deck)` + 抽到的 6 张进攻牌(共 11 张:5 工具 + 6 进攻)。

- [ ] **Step 1: 写失败测试**（加到 `test/unit/test_fight.gd`)
```gdscript
func test_round_hand_is_five_utilities_plus_six_attacks() -> void:
	var w = preload("res://src/scenes/fight.tscn").instantiate()
	add_child_autofree(w)
	await wait_frames(2)
	var hand: Array = w._plan_phase._deck
	var attacks := 0
	var utils := 0
	for m in hand:
		if m.kind == Move.Kind.ATTACK: attacks += 1
		else: utils += 1
	assert_eq(attacks, 6, "每回合抽 6 张进攻牌")
	assert_eq(utils, 5, "5 张固定工具牌(步×2/挡/闪/拿)")
```

- [ ] **Step 2: 跑测试确认失败**
Run: `bash run_tests.sh -gselect=test_fight.gd`
Expected: FAIL（hand 目前是全 14 张)

- [ ] **Step 3: 实现** —— 在 `src/scenes/fight.gd`:
新增成员(在 `var _ai` 附近):
```gdscript
var _rng := RandomNumberGenerator.new()
var _pool: Array[Move] = []
```
在 `_ready` 里(`_ai = AiPlanner.new(seed)` 之后、`_deck = Deck.starter()` 之后)加:
```gdscript
	_rng.seed = seed
	_pool = Hand.attack_pool(_deck)
```
把 `_start_round` 里那行 `_plan_phase.setup(_deck, ...)` 改为先组手牌:
```gdscript
	var hand: Array[Move] = Hand.utilities(_deck)
	hand.append_array(Hand.draw(_pool, 6, _rng))
	_plan_phase.setup(hand, _rules, _state.stamina[0], _state.sta_max[0], _state.n_ticks, _ai.intent(_pending_ai_plan, 1))
```
(`_ai.plan(_deck, ...)` 那行**不动**——AI 仍用全集排招。)

- [ ] **Step 4: 跑测试确认通过**
Run: `bash run_tests.sh -gselect=test_fight.gd`
Expected: PASS

- [ ] **Step 5: 提交**
```bash
git add src/scenes/fight.gd test/unit/test_fight.gd
git commit -m "feat(fight): 每回合发手牌=工具牌+有放回抽6进攻"
```

---

### Task 3: plan_phase 消耗式手牌

**Files:**
- Modify: `src/scenes/plan_phase.gd`
- Test: `test/unit/test_plan_phase.gd`

**Interfaces:**
- Consumes: `_model.units`(每个 `u["moves"]: Array[Move]`),`Move.id: StringName`,`Move.Kind.ATTACK`。
- Produces:
  - `_placed_attack_counts() -> Dictionary`(id→已排张数,含连招组件)
  - `available_attack_count(id: StringName) -> int`(手牌该 id 张数 − 已排)
  - `_build_deck` 只渲染「工具牌(全部) + 剩余进攻牌」;任何 model 改动后重建手牌区。

- [ ] **Step 1: 写失败测试**（加到 `test/unit/test_plan_phase.gd`;现有连招测试若依赖"同一进攻招无限拖",改为 setup 传含足够份数的手牌)

先看现有 helper:本文件已有构造 plan_phase + setup 的方式。新增用例(用 `Deck.starter()` 里的真实招;`snap_kick`=弹腿 ATTACK,`guard`=格挡工具):
```gdscript
# 取 starter 里某 id 的 Move
func _m(id: String) -> Move:
	for m in Deck.starter():
		if m.id == StringName(id): return m
	return null

func _phase_with_hand(hand: Array[Move]):
	var p = preload("res://src/scenes/plan_phase.tscn").instantiate()
	add_child_autofree(p)
	p.setup(hand, ComboLibrary.build(), 99, 99, 15, ["?"])
	return p

func test_attack_card_consumed_on_place_and_returned_on_remove() -> void:
	var hand: Array[Move] = [_m("guard"), _m("snap_kick")]
	var p = _phase_with_hand(hand)
	assert_eq(p.available_attack_count(&"snap_kick"), 1)
	assert_true(p.try_drop_new(_m("snap_kick"), 0.0))   # 排在第0拍
	assert_eq(p.available_attack_count(&"snap_kick"), 0, "排出后手牌减少")
	# 手牌区:剩格挡(工具,无限) — 无剩余弹腿
	assert_eq(p._deck_row.get_child_count(), 1)
	p.remove_at(0)
	assert_eq(p.available_attack_count(&"snap_kick"), 1, "移除后退回手牌")
	assert_eq(p._deck_row.get_child_count(), 2)

func test_utility_card_is_unlimited() -> void:
	var hand: Array[Move] = [_m("guard")]
	var p = _phase_with_hand(hand)
	assert_true(p.try_drop_new(_m("guard"), 0.0))
	assert_true(p.try_drop_new(_m("guard"), 80.0))      # 同一工具牌可重复排
	assert_eq(p._deck_row.get_child_count(), 1, "工具牌始终在手牌区")

func test_duplicate_attack_cards_each_consumable() -> void:
	var hand: Array[Move] = [_m("snap_kick"), _m("snap_kick")]
	var p = _phase_with_hand(hand)
	assert_eq(p.available_attack_count(&"snap_kick"), 2)
	assert_eq(p._deck_row.get_child_count(), 2)
	assert_true(p.try_drop_new(_m("snap_kick"), 0.0))
	assert_eq(p.available_attack_count(&"snap_kick"), 1)
	assert_eq(p._deck_row.get_child_count(), 1)
```

- [ ] **Step 2: 跑测试确认失败**
Run: `bash run_tests.sh -gselect=test_plan_phase.gd`
Expected: FAIL（`available_attack_count` 未定义 / 手牌区张数不对)

- [ ] **Step 3: 实现** —— 改 `src/scenes/plan_phase.gd`:

(a) 把 `_build_deck` 的卡面构造抽成 `_add_card`,并改 `_build_deck` 为「工具全渲染 + 剩余进攻」:
```gdscript
func _build_deck() -> void:
	for c in _deck_row.get_children(): c.queue_free()
	var to_skip := _placed_attack_counts()   # id -> 还要隐藏的张数(已排)
	for m in _deck:
		if m.kind == Move.Kind.ATTACK and to_skip.get(m.id, 0) > 0:
			to_skip[m.id] -= 1
			continue
		_add_card(m)

func _add_card(m: Move) -> void:
	var b := DraggableCard.new()
	b.move = m
	var tail := ""
	if m.kind == Move.Kind.STEP:
		tail = "进" if m.distance_delta < 0 else "退"
	else:
		tail = "%s-%s" % [CombatFeed.distance_label(m.range_min), CombatFeed.distance_label(m.range_max)]
	b.text = "%s\n%d拍·%d气·%s" % [m.move_name, m.total_duration(), m.stamina_cost, tail]
	b.new_grabbed.connect(_on_new_grabbed)
	_deck_row.add_child(b)

func _placed_attack_counts() -> Dictionary:
	var c := {}
	for u in _model.units:
		for mv in u["moves"]:
			if (mv as Move).kind == Move.Kind.ATTACK:
				c[mv.id] = c.get(mv.id, 0) + 1
	return c

func available_attack_count(id: StringName) -> int:
	var hand_n := 0
	for m in _deck:
		if m.id == id and m.kind == Move.Kind.ATTACK:
			hand_n += 1
	return hand_n - _placed_attack_counts().get(id, 0)
```

(b) 任何 model 改动后**重建手牌区**。在这些方法里,凡是 `_redraw_timeline(); _refresh_labels()` 之处,前面加 `_build_deck()`:`try_drop_new`(成功分支)、`try_move_existing`、`remove_at`、`_do_fuse`、`_on_remove_component`、`_finish_drag`(`was_new and not over` 取消分支、`moved` 分支)。
最稳妥:把这三连封成一个 helper 并替换:
```gdscript
func _refresh() -> void:
	_build_deck(); _redraw_timeline(); _refresh_labels()
```
然后把上述各处的 `_redraw_timeline(); _refresh_labels()` 替换为 `_refresh()`。
**注意**:`_begin_new_drag()` 内的单独 `_redraw_timeline()`(拖拽中)**不要**换成 `_refresh()`——拖拽过程中保持手牌区不动,拖拽落下时 `_finish_drag` 再 `_refresh()` 让消耗/退回生效。

- [ ] **Step 4: 跑测试确认通过**
Run: `bash run_tests.sh -gselect=test_plan_phase.gd`
Expected: PASS（新增 3 + 原有用例;原有若因"无限拖同一进攻招"失败,改其 setup 传足量手牌)

- [ ] **Step 5: 跑全量测试**
Run: `bash run_tests.sh`
Expected: 全绿

- [ ] **Step 6: 提交**
```bash
git add src/scenes/plan_phase.gd test/unit/test_plan_phase.gd
git commit -m "feat(plan): 消耗式手牌—进攻牌一次性、工具牌无限"
```

---

## Self-Review
- **覆盖**:二分+抽牌(T1)、每回合发手牌(T2)、消耗式手牌渲染+gate(T3)。spec 的「有放回/可重复/一次性/工具无限/连招靠抽」均落到任务。
- **类型一致**:`Hand.*` 签名 T1 定义、T2/T3 消费一致;`_placed_attack_counts`/`available_attack_count` 在 T3 内自洽;`Move.id: StringName` 全程作 key。
- **占位符**:无 TODO/TBD;每步含完整代码或确切命令。
- **风险**:现有 `test_plan_phase` 里依赖"同一进攻招多次 try_drop_new"的用例会因消耗而失败 → T3 Step 4 已指明改为传足量手牌(把这类用例的 setup 手牌含足够份数)。

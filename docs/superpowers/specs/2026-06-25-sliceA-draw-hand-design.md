# 设计文档 · 子切片 A：抽卡手牌系统

- **日期**：2026-06-25
- **状态**：待用户审定 → writing-plans → 实现
- **属于**：门派/抽卡设计的第一个子切片(北极星见 `2026-06-25-menpai-and-draw-design.md`)
- **范围**：把排招从「调色板(任意招无限拖)」改成「**手牌**」:**固定工具牌无限**,**进攻牌每回合有放回抽 6 张、一次性消耗**。门派进攻池、状态、学招扩池**不在本切片**(进攻池暂用现有 9 个 ATTACK 招)。

---

## 一、模型

- **工具/进攻二分(按 `Move.kind`)**:
  - **工具牌(固定 · 无限可排)** = 非 ATTACK 类:上步/撤步(STEP)、格挡(BLOCK)、闪身(DODGE)、擒拿(THROW)。
  - **进攻牌(抽取 · 一次性)** = ATTACK 类:直拳/摆拳/推掌/下劈掌/撞肘/膝顶/弹腿/扫堂腿/侧踢。
- **抽牌**:每回合从**进攻池**(本切片 = 上面 9 个 ATTACK)「**有放回**」随机抽 **6** 张(**可能重复**)。每张**排一次消耗**;从 timeline 移除则**退回手牌**。下回合**重抽**。
- **连招靠抽**:罗汉连拳/连环踢(拳法/腿法×3)要本回合手里**真有 3 张对应进攻牌**才拼得出。

**最小改动关键**:`fight.gd` 每回合把「工具牌 + 抽到的6张进攻」组成**本回合的 deck**传给 `plan_phase.setup(...)`(**签名不变**)。排招把 **ATTACK 类视为一次性(消耗)、其余无限**。"手牌" = 传入的 deck。

---

## 二、抽牌纯逻辑(`src/content/hand.gd`,新建,可单测)

```gdscript
class_name Hand
extends RefCounted

static func attack_pool(deck: Array[Move]) -> Array[Move]:
	return deck.filter(func(m): return m.kind == Move.Kind.ATTACK)

static func utilities(deck: Array[Move]) -> Array[Move]:
	return deck.filter(func(m): return m.kind != Move.Kind.ATTACK)

# 有放回抽 n 张(可能重复)。pool 非空。
static func draw(pool: Array[Move], n: int, rng: RandomNumberGenerator) -> Array[Move]:
	var out: Array[Move] = []
	for i in n:
		out.append(pool[rng.randi_range(0, pool.size() - 1)])
	return out
```
测试:`draw` 返回 n 张、都来自 pool、同 seed 确定、能出重复(用小 pool 验证)。`attack_pool`/`utilities` 正确二分。

---

## 三、fight.gd:每回合发手牌

- 新增 `var _rng := RandomNumberGenerator.new()`(`_ready` 里 `_rng.seed = seed` 复用 AI 的 seed,保证一局可复现)。
- `var _pool: Array[Move]`(= `Hand.attack_pool(Deck.starter())`,在 `_ready` 算一次)。
- `_start_round()` 里,组本回合手牌并传入:
```gdscript
	var hand: Array[Move] = Hand.utilities(_deck)
	hand.append_array(Hand.draw(_pool, 6, _rng))
	...
	_plan_phase.setup(hand, _rules, _state.stamina[0], _state.sta_max[0], _state.n_ticks, _ai.intent(_pending_ai_plan, 1))
```
(`_deck = Deck.starter()` 仍是全集,只用来抽工具/进攻池。)

> AI 暂不抽牌(它用 `_ai.plan(_deck, …)` 全集排招)——本切片只做玩家手牌;AI 抽牌留到平衡时再说。

---

## 四、plan_phase:消耗式手牌

排招把传入的 `_deck` 当**手牌**;**ATTACK 类一次性、其余无限**。

- **可用进攻数 = 手牌里该 id 的张数 − 已排该 id 的张数**(已排含连招的组件):
```gdscript
func _placed_attack_counts() -> Dictionary:
	var c := {}
	for u in _model.units:
		for mv in u["moves"]:
			if (mv as Move).kind == Move.Kind.ATTACK:
				c[mv.id] = c.get(mv.id, 0) + 1
	return c
```
- **`_build_deck` 改为**:渲染所有**工具牌**(无限,各一张),再渲染**剩余进攻牌**(手牌里 ATTACK 实例 − 已排,逐张):
  - 即:对手牌里每个 ATTACK 实例,若"该 id 已渲染张数 < 手牌该 id 张数 − 已排该 id 张数"则渲染。简单做法:`remaining = hand_attacks(列表) 按 id 逐个扣除 placed_counts`,剩下的逐张渲染。
- **拖放即消耗(派生,不改 PlanModel)**:放一张进攻牌 = `_model.add_unit` 加一个 unit → 重绘时该 id 已排+1 → 剩余−1 → 该牌从手牌区少一张。移除 unit → 退回。**连招消耗其组件张数**(融合不改变 units 里的组件 move,所以计数照算)。
- **拖不到没有的牌**:手牌区只渲染"剩余>0"的进攻牌,所以排不出手里没有的招(天然 gate)。工具牌永远在。

> `PlanModel` 不变(units 仍是放置的招);消耗是 plan_phase 从 units **派生**出来的视图,放置/移除照常触发重绘即可。

---

## 五、UI

- 手牌区(现 `DeckRow`)分两段视觉:**「常用」(工具牌)** + **「进攻·本回合(N)」(剩余进攻牌)**。可加个小分隔标签;卡面沿用现有 `招名/拍·气·距离`。
- (可选)显示本回合还剩几张进攻牌。

---

## 六、测试影响

- **新增** `test_hand.gd`:`attack_pool`/`utilities` 二分;`draw` 数量/来源/确定性/可重复。
- `test_plan_phase.gd`:**受影响**——现有连招/重复放置测试依赖"同一招无限拖"。改为给 `setup` 传**带足够份数的手牌**(如手牌含 3 张 `snap_kick`)以测连招;新增"进攻牌放置后从手牌减少、移除后退回、工具牌无限"用例。
- `fight` 相关:确认 `_start_round` 发的手牌 = 工具 + 6 抽;可加一条"手牌含 5 工具 + 6 进攻"。
- 其余(combat_sim/combo/distance…)不受影响。

---

## 七、本切片不做
- 门派进攻池(暂用现有 9 ATTACK)、开局选派 —— 子切片 C。
- 状态(护体/借力) —— B+C。
- 学招扩池、AI 抽牌、压牌/弃牌堆(我们是有放回独立抽,无牌堆)。

## 八、起始数值
| 参数 | 值 |
|--|--|
| 每回合抽进攻牌 | 6 |
| 抽取方式 | 有放回(可重复) |
| 进攻牌 | 一次性消耗(移除退回) |
| 工具牌 | 无限(步/挡/闪/拿) |

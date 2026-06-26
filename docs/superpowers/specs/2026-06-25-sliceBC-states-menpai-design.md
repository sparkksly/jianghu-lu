# 设计文档 · 子切片 B+C：最小状态系统 + 门派(少林/武当)

- **日期**：2026-06-25 ・ 状态:已定(用户授权直接实现,跳过 review)
- **属于**:门派/抽卡北极星 `2026-06-25-menpai-and-draw-design.md` 的 B+C(合并)。接 Slice A(抽卡手牌)。
- **范围**:(B) combat_sim 内最小状态 **护体** + **借力**;(C) 少林/武当**招式池 + 连招 + 开局选派**,把抽卡进攻池接成门派池。

---

## B. 最小状态系统(combat_sim 内,**回合内**生效,`_Actor` 跟踪)

不动 CombatState;状态是 sim 局部(每次 `simulate()` 重置)。

### 借力(通用机制)
- **成功格挡 或 成功闪避** → 防守方开 **借力窗口**(`_Actor.leverage_until = t + LEVERAGE_WINDOW`)。
- 该方**下一记干净命中(hit)** 若 `t <= leverage_until` → 伤害 **×(1+LEVERAGE_PCT%)**,**消耗窗口**,发 `&"leverage"` 事件。
- 常数:`LEVERAGE_WINDOW = 3`,`LEVERAGE_PCT = 60`。
- 这就是**四两拨千斤**:格挡/闪身 接 绵掌(或任何攻),借力反打。通用(双方可用),武当靠绵掌/中距更会用。

### 护体(招式赋予)
- 新 Move 字段 `grants_guard: int = 0`(命中时给**自己**挂护体的拍数)。
- 带 `grants_guard>0` 的招**干净命中**时 → `_Actor.guard_until = t + grants_guard`,发 `&"guard"` 事件。
- 护体期间(`t < guard_until[defender]`)受到的伤害 **×(100−GUARD_REDUCTION_PCT)/100 向上取整**。
- 常数:`GUARD_REDUCTION_PCT = 50`。来源:连招 **金刚伏魔**(`grants_guard=4`)。

### combat_sim 改点
- `_Actor` 加 `var guard_until := -1`、`var leverage_until := -1`。
- 成功 BLOCK 分支(现 `&"block"`)→ 设 defender 借力窗口 + `&"leverage"`。
- 成功 DODGE 分支(现 DODGE→`_whiff`)→ 设 defender(=1−attacker)借力窗口 + `&"leverage"`。
- 干净命中分支(现 `&"hit"`):命中前若 attacker 借力窗口有效 → 伤害提升并消耗、发 `&"leverage"`;命中后若 `atk.grants_guard>0` → 设 attacker 护体 + `&"guard"`。
- `_apply_damage`:气力不继加成后,若 defender 护体有效 → 伤害减半(ceil)。
- `Loc.event_zh` + `log_line` + `CombatFeed`:`&"leverage"`(借力·亮黄)、`&"guard"`(护体·金)。

---

## C. 门派(少林 / 武当)

### 新招式(`Deck`,`_m`)
| id | 名 | 类 | tag | 帧(su/act/rec) | dmg | 气 | range | 其他 |
|--|--|--|--|--|--|--|--|--|
| beng_quan | 崩拳 | ATTACK | 拳法 | 0/1/1 | 7 | 2 | [0,1] | |
| weituo | 韦陀掌 | ATTACK | 掌法 | 1/1/1 | 8 | 3 | [0,1] | armor(霸体) |
| jingang_zhi | 金刚指 | ATTACK | 指法 | 0/1/1 | 6 | 2 | [0,1] | interrupt(破防) |
| longzhua | 龙爪手 | ATTACK | 擒拿 | 1/1/1 | 7 | 2 | [0,0] | |
| shaolin_gun | 少林棍 | ATTACK | 棍法 | 1/1/1 | 7 | 3 | [1,2] | knockback(长兵中远) |
| mian_zhang | 绵掌 | ATTACK | 掌法 | 0/1/1 | 5 | 2 | [1,1] | (借力反打主力) |
| wudang_changquan | 武当长拳 | ATTACK | 拳法 | 0/1/1 | 6 | 2 | [0,1] | |

### 连招(模板;融合时伤害按 `_fuse_result` 重算,模板的 hits/range/delta/priority/**grants_guard** 保留)
- **罗汉拳** `luohan()`:ATTACK 拳法 0/3/1 hits[0,1,2] range[0,1] —— 配方 **拳法×3**。刚猛三连。
- **金刚伏魔** `jingang_fumo()`:ATTACK 掌法 0/1/2 hits[0] range[0,1] armor **grants_guard=4** —— 配方 **[格挡, 韦陀掌]**。重掌 + 给自己护体。
- **太极云手** `taiji_yunshou()`:ATTACK 掌法 0/2/1 hits[0,1] range[0,2] **delta=-1** priority=6 —— 配方 **[绵掌, 绵掌]**。连绵柔掌 + 贴近一步 + 抢先手(用 priority 近似;"下回合先手"不做)。
- **四两拨千斤** = **借力机制**(格挡/闪 接 绵掌),不是融合配方。

### 门派数据(`src/content/menpai.gd`)
```gdscript
# 返回 {id, name, pool:Array[Move](进攻池), rules:ComboRules}
Menpai.get(id)        # id ∈ {&"shaolin", &"wudang"};未知→shaolin
Menpai.pool(id)       # 少林7招 / 武当5招(见下)
Menpai.rules(id)      # ComboLibrary.build()(base) + 门派配方
```
- 少林池:jab, hook, beng_quan, weituo, jingang_zhi, longzhua, shaolin_gun(刚猛贴身 + 棍中距)。
- 武当池:mian_zhang, wudang_changquan, push_palm, snap_kick, sweep_kick(柔掌 + 腿,中距游走)。
- 少林 rules:base + [拳法×3→罗汉拳] + [格挡,韦陀掌→金刚伏魔]。
- 武当 rules:base + [绵掌×2→太极云手]。
- **base(`ComboLibrary.build()`)不加门派配方**,现有 combo 测试不受影响。

### 集成
- `fight.configure(...)` 增 `menpai_id := &"shaolin"`;`_ready` 里 `_pool = Menpai.pool(menpai_id)`,`_rules = Menpai.rules(menpai_id)`(工具牌仍取 `Hand.utilities(Deck.starter())`)。standalone 默认少林。AI 暂仍用通用全集(敌方不分门派)。
- **开局选派**:`main_menu` 开始游戏 → `menpai_select.tscn`(少林/武当两按钮)→ `run.tscn`。
  - 传参用静态变量:`RunState.pending_menpai: StringName`(select 设,run 读)。`RunState` 加 `menpai_id`;`run.gd` 把它传给 `fight.configure`。

---

## 数值一览(可调)
| 参数 | 值 |
|--|--|
| 借力窗口 | 3 拍 |
| 借力增伤 | +60% |
| 护体减伤 | 50% |
| 金刚伏魔 护体 | 4 拍 |

## 本切片不做
- 内伤、攻防属性完整化、AI 门派化、太极剑/梯云纵、学招扩池/跨派、存档。

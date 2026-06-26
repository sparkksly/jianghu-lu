# 设计文档 · 「武学精进」成长系统(两轴)

- **日期**：2026-06-25 ・ 状态:已定(用户授权直接实现)
- **目标**:一局 run 里沿「化繁为简」越打越强。两条成长轴咬合;实现分两段(A→B),每段可玩。

---

## 零、两轴总览(化繁为简弧线)

| 阶段 | 状态 |
|--|--|
| 起手 | 只有基础动作,一张张手排 |
| **领悟绝学**(轴A) | "会拼"某连招了 —— 仍要手排 N 张基础动作凑出 |
| 反复用 + 打硬仗 | 这套连招**熟练度涨**(轴B) |
| **顿悟·Lv1** | 连招整体**变快/省气** |
| **顿悟·Lv2** | 连招**固化成一张单卡** —— 进抽牌池、一拍释放,不用再手拼。萧峰式大巧不工 |

- **轴 A 机缘(显式)**:战后三选一,你来选。
- **轴 B 熟练(隐式)**:绝学为载体,硬仗自然练成,不显进度条,顿悟事件呈现,质变=压成单卡。
- 领悟让你"会拼",熟练把它"练成单卡"。

---

## 一、绝学注册表 + 领悟(轴A 地基,已建)

`src/content/arts.gd`:`id → {slots, result}`。一级配方:连环踢(腿×3)/乾坤(攻+挡+投)[通用]、罗汉拳(拳×3)/金刚伏魔(挡+掌)[少林]、太极云手(掌×2)[武当]。
- `Arts.recipe(id)`、`Arts.display_name(id)`、`Arts.build_rules(learned, mastery:={})`(按已学构建;Lv1 让 result 变快)。
- `Menpai.starter_learned(id)`:少林`[luohan]`/武当`[taiji_yunshou]`。`Menpai.learnable(id)`:本脉可学全部(通用+本门)。
- 进攻抽牌池仍是共享基础动作。**fight 用 `Arts.build_rules(learned, mastery)`**(不再 Menpai.rules)。
- 绝学**模板的 damage 兼作「固化单卡」的 stats**(融合时被 `_fuse_result` 重算,不冲突);故模板 damage 调成单卡合理值:luohan 6/chain_kick 7/taiji_yunshou 6/qiankun 14/jingang_fumo 10。

## 二、熟练度(轴B,绝学为载体)

- `RunState.mastery: Dictionary` 绝学id→施展计数。`mastery_level(id)`:计数<2→Lv0,2-3→Lv1,≥4→Lv2(封顶)。
- **涨**:每场战斗后,对**本场成功施展并命中过的绝学**各 +1。第一版"硬仗 gated"简化为「施展即涨 + 低上限」(精英/boss 精确 gate 待节点地图)。
- **不显进度条**;升级时战后弹**顿悟叙事事件**。
- **Lv1 熟**:`build_rules` 时该 result `recovery-1`(变快)。
- **Lv2 精·固化单卡**:该绝学作为一张卡进**进攻抽牌池**(用 `Arts.recipe(id).result` 模板的 stats),可直接抽到、一次释放。手拼配方仍保留(无所谓)。
- **本场施展收集**:fight 扫 events,玩家(actor==0)的 hit 且 `Arts.recipe(move_id)` 非空 → 记入 `_arts_used`;`fight.arts_used()` 给 run。

## 三、RunState 扩展

新增:`learned: Array`(开局=`Menpai.starter_learned`)、`mastery: Dictionary`、`bonus_qi:int`。
- `apply_reward(r)`:combo→learned.append;qi→bonus_qi+=2;hp→max_hp+=6 且 player_hp+=6。
- `gain_mastery(ids) -> Array`:对 ids +1,返回刚升级项 `[{id, level}]`(供顿悟事件)。
- `compiled_arts() -> Array`:`mastery_level>=2` 的绝学 id(进抽牌池)。

`fight.configure(... , menpai_id, learned:=[], mastery:={}, bonus_qi:=0)`:
- learned 空则用 `Menpai.starter_learned(menpai_id)`;`_rules=Arts.build_rules(learned, mastery)`。
- `_pool = Menpai.pool(id)` + 每个 `compiled_arts` 的卡。
- `sta_max=[10+bonus_qi,10]`;bonus_hp 走 max_hp(run 已累加,configure 不另加)。

## 四、奖励生成(纯逻辑)

`src/run/run_rewards.gd`:`roll(unlearned: Array, rng) -> Array`(3 个不重复 `{type:"combo",id}|{qi}|{hp}`;绝学不足用属性补)。`unlearned = learnable(id) − learned`。

## 五、战后流程 + UI

`run.gd` 胜利后(未通关):
1. `var ups = _run.gain_mastery(_fight.arts_used())` → 有则依次/合并弹**顿悟事件**(`awaken_event.tscn`:叙事文案 + 确认)。
2. **机缘三选一**(`reward_select.tscn`:标题+3 按钮)→ `_run.apply_reward(r)`。
3. 下一场。通关不给。
run 持 RNG(reward + 可复现)。

## 六、实现分段
- **A 段(先做,可玩)**:arts/menpai 地基 + RunState(learned/bonus_qi) + 奖励生成 + reward_select UI + run 流程 + fight 集成(领悟+属性)。**先不做熟练度**。
- **B 段**:mastery + 本场施展收集 + Lv1变快/Lv2单卡入池 + 顿悟事件 UI + 战后熟练结算。

## 七、本切片不做
取舍/稀有度/装备奖励、节点地图、二级绝学(无影脚)、跨派门槛、攻防属性、硬仗精确 gate(待节点地图)、真存档。

## 八、数值(旧A段)
| 项 | 值 |
|--|--|
| 强身 | +6 HP |
| 每场后 | 三选一(通关不给) |

---

# 修订 v2(用户 2026-06-25):成长分三层

旧「机缘三选一」里**领悟绝学不该和加血/加气同维度**。重构:

## R1 · 基础提升(战后三选一,无领悟绝学)
1. **强身**:max_hp+6, player_hp+6。
2. **打坐修炼**:疗伤(player_hp += MEDITATE_HEAL=12,不超上限) + **内功等级+1**(→属性按内功涨)。
3. **磨练招式**:随机一门基础进攻招 → 该招 **mastery+2 + 抽取权重+1**;**几率(HONE_INSIGHT=35%)领悟**一个未学绝学。
- 基础提升「更多随机性」(武器/道具相关) **延后**。三选一目前固定这三类(磨练目标招随机)。

## R2 · 内功(气的来源)
- `src/content/neigong.gd`:门派起手内功 `starter(menpai)`(少林 yijinjing 易筋经 / 武当 liangyi 两仪心法);`hp_per_level/qi_per_level/display_name`。
- 易筋经:+3HP+1气/级;两仪心法:+1HP+2气/级。
- RunState:`neigong_id`、`neigong_level`(0起);`max_hp` 含强身;`qi_bonus()=neigong_level*qi_per_level`。打坐 +级。
- **气不再是裸选项**;sta_max = 10 + qi_bonus()。

## R3 · 熟练度 + 招式进化
- `RunState.mastery: Dict[id]→int`:磨练+2,**实战命中+1**(基础招&绝学都算)。
- 阈值 EVOLVE_AT=[3,6]:达标且该招进化级 < 应得 → 触发**招式进化三选一**(战后,可多招排队)。
- 进化选项(`evo[id]={spd,qi,dmg,compiled}`):**迅捷**(spd+1→后摇-1)/**凝气**(qi+1→气-1)/**沉重**(dmg+1→+2伤);**绝学**且进化级≥2 可出**化境·压缩单卡**(compiled=true→该绝学作单卡进抽牌池;**首次进化不出单卡**)。
- fight 建招时应用 evo;compiled 绝学 result 进 `_pool`。

## R4 · 抽取权重(卡组构建)
- `RunState.weight: Dict[id]→int`(磨练+1)。`Hand.draw(pool,n,rng,weights)` 改为**加权**抽(权重 = 1+weight[id])。

## R5 · 领悟绝学(改为磨练副产物)
- 不在三选一直接给。磨练招式时 35% 从「未学绝学」随机领悟一个(第一版简化;家族关联待调)。

## R6 · 战后流程(run.gd)
胜利未通关:1)实战熟练结算 `gain_mastery(本场命中招)` → 有招达进化阈值则逐个弹**招式进化三选一**;2)**基础提升三选一**;3)下一场。

## 今晚落地 vs 待调
- 落地:R1–R6 核心。
- 最小/待调:内功只做属性(流派细节后补)、领悟用磨练几率给(家族关联待调)、抽权重简单加权、进化选项三种+单卡。
- 不做:基础提升更多随机(武器/道具)、二级绝学、攻防属性、节点地图、真存档。

## 数值 v2
| 项 | 值 |
|--|--|
| 强身 | +6 HP |
| 打坐疗伤 | +12 HP |
| 内功/级 | 易筋经+3血+1气 / 两仪+1血+2气 |
| 磨练 | mastery+2, weight+1, 35%领悟 |
| 实战命中 | mastery+1 |
| 进化阈值 | 3 / 6 |
| 进化 | 迅捷-1拍 / 凝气-1气 / 沉重+2伤 / 化境单卡(≥2级) |

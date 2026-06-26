# 设计文档 · 完整 run(开局构筑 + 三章节点 + 奇遇 + 三 boss)

- **日期**：2026-06-26 ・ 状态:用户睡前大委托,授权直接实现端到端可玩流程
- **目标**:主菜单 → 开局构筑 → 三章(每章 小怪→奇遇→精英→boss) → 通关。覆盖开局选择/招式分级/奇遇/boss。
- **范围裁剪**:线性章节-节点序列(无可视化分叉地图);内容第一版。

---

## 一、招式分级 + 已学招池

- `Deck` 招式标 tier:初级 `LV1=[jab,hook,push_palm,snap_kick,elbow_strike]`,高级 `LV2=[chop_palm,side_kick,knee_strike,sweep_kick]`。
- `Move.tier:int`(1/2);`Deck.tier1_attacks()/tier2_attacks()`。
- **抽牌池 = 玩家已学攻击招** `RunState.known_moves`(开局选 2 门初级);不再是全部基础动作。途中奇遇/磨练学高级招扩池。
- fight.configure 接 `known_moves`(攻击招 id 列表)→ `_pool`(应用 evo)+ compiled 单卡。

## 二、内功(开局 3 选 1)

`Neigong` 扩为 3 门:易筋经(+3血+1气)、两仪心法(+1血+2气)、**罗汉伏气**(+2血+2气均衡)。`Neigong.all()` 列表。开局选。

## 三、敌人/boss(`src/content/enemies.gd`)

`Enemies.spawn(chapter, kind) -> Dictionary`:`{name, hp, regen, pool:Array(攻击招id), seed}`。kind ∈ {grunt,elite,boss}。
- 小怪/精英:用基础招池,hp/regen 按章递增。
- 三 boss 专属招(新 Move,`Deck.boss_moves()`):
  - 青鳞毒叟:`toad_power`(蛤蟆劲 霸体+借力)、`venom_palm`(毒砂掌 高伤)、`rot_claw`(腐骨爪 stun)
  - 血河老魔:`blood_blade`(血河刀 重击knockback)、`soul_reap`(噬魂斩 打断高伤)、`massacre`(狂屠 多hit)
  - 无影魔君:`phantom_needle`(千幻针 多hit快)、`ghost_step`(鬼魅步 step贴身高优先)、`reaper_stab`(夺命刺 高优先打断)
- fight.configure 接 `enemy_pool`(敌人招池)+ `enemy_name`;AI 用 enemy_pool 排招;敌方名显示。

## 四、奇遇(`src/content/encounters.gd` + UI)

`Encounters.all()` → 列表 `{id, title, body, options:[{label, effect}]}`。effect 字典由 RunState 应用:
- 幽洞遗篇:`{learn_art:random_high}` 领悟一门未学绝学
- 隐世高人:两选项 `{master_move:学一门高级招}` / `{master_master:一招+5熟练}`
- 古冢神兵:`{weapon_dmg:2}`(全攻击+2伤,存 RunState.weapon_bonus)
- 空谷灵果:`{hp:12, neigong:2}`
- 荒野客栈:`{heal_full:true, neigong:1}`
- `encounter.tscn/.gd`:标题+正文+选项按钮,emit chosen(effect)。

`RunState.apply_encounter(effect, rng)`:按 key 应用(learn_art/master_move/master_master/weapon_dmg/hp/neigong/heal_full)。`weapon_bonus` 进 fight(全攻击招+伤)。

## 五、run 重构(章节-节点序列)

`RunState` 重构为节点驱动:
- `chapters = 3`;每章节点序列 `["grunt","encounter","elite","boss"]`;`node_index`(全局)。
- `current_node() -> {chapter, type}`;`advance_node()`;`is_complete()`。
- `chapter_title()`:第一章·毒蛛潭 / 第二章·断魂崖 / 第三章·华山之巅。
- 成长字段:known_moves, learned, neigong_id/level, mastery, weight, evo, weapon_bonus, player_hp, max_hp。

`run.gd` 按 `current_node().type` 分发:
- grunt/elite/boss → `_start_fight(kind)`(Enemies.spawn);战斗胜利 → 战后成长(熟练/进化/基础提升三选一,**boss 后给更多**?先统一)→ advance_node。
- encounter → 奇遇 UI → 应用 → advance_node。
- 节点切换显示章节/节点 banner。

## 六、开局构筑 UI

`setup_select.tscn/.gd`(替换 menpai_select):分步 门派 → 内功(3) → 2 初级招。完成设 `RunState.pending_*`(static) → run.tscn。
(简化:一屏分三组按钮 + 招式多选 2 + 确认。)

## 七、本切片不做
可视化分叉地图、武器系统完整、新状态(毒/血)、跨派、存档、奇遇风险/赌、boss 多阶段。

## 八、实现顺序(端到端优先)
1. 招式分级 + boss/敌人招(Deck/Enemies) + 内功3门
2. RunState 重构(known_moves/节点/章节/weapon + apply_encounter)
3. fight 敌人池/名 集成 + known_moves 池
4. 奇遇数据 + UI;开局构筑 UI
5. run.gd 节点分发
6. 全绿 + 截图 + 部署

# 设计文档 · 角色数据架构(属性 / 状态 / 聚合)

- **日期**：2026-06-27 ・ 状态:用户认可"地基全做"
- **目标**:把散落的角色数据规整成可扩展架构,为大量填技能做地基。属性聚合 + StatusEffect + 攻防进伤害公式;装备/暗器/银两/声望先留字段。

---

## 一、三层数据(按生命周期)

| 层 | 存哪 | 内容 |
|--|--|--|
| **永久(run)** | RunState | 基础属性(攻/防/最大血/最大气)、当前血、牌库池(weight)/抽卡数、已领悟功夫/熟练/进化、内功、**(留)** 装备/暗器/物品/银两/声望 |
| **持续(跨场)** | RunState.conditions | 内伤/中毒/流血(到痊愈才消) —— 先留结构 |
| **瞬时(战斗内)** | CombatState | 当前气、距离、StatusEffect(护体/借力/踉跄/拍级buff) |

## 二、属性聚合(核心):基础 + modifiers → 有效值

属性不是裸数字,而是 **基础值 + 各来源修正器**:
- modifier = `{stat, op:"add"|"mul", value, source}`。来源:内功(等级)、装备、奇遇永久加成、StatusEffect。
- **有效值** 按需聚合: `effective(stat) = (base + Σadd) × Πmul`。
- `Stats.aggregate(base, mods, stat)`(纯逻辑,可测)。
- **RunState 进战斗时算"该场属性"**(base + 内功 + 装备 + 永久),传给 fight → CombatState 的基础 attack/defense/max_hp/max_qi。
- **CombatState 战斗内**再叠加 StatusEffect 的 modifier → 有效 attack/defense。

属性集:`attack`(加伤)、`defense`(减伤)、`max_hp`、`max_qi`。其余(闪避/格挡/速度)**不做**——由招式判定。

## 三、StatusEffect(数据驱动的 buff/debuff)

```
{
  id, name,
  modifiers: [{stat, op, value}],   # 改属性(临时攻防±等)
  tick: {hp:int, qi:int},           # 每 tick 持续效果(中毒掉血)
  duration: int, scope: "tick"|"round"|"fight",  # 剩余 + 时间单位
  stacks: int,                       # 层数(可选)
  source: StringName,
}
```
- `StatusEffect` helper:`mods_for(list, stat)` 聚合本侧所有 buff 对某属性的修正;`advance(list)` 递减 duration、应用 tick、移除到期。
- 现有 护体/借力/踉跄 暂保留 combat_sim 内现有特殊处理(下一步可统一进 StatusEffect);本切片先把**框架 + 数据结构 + 攻防型 buff** 跑通。

## 四、攻防进伤害公式

`combat_sim` 命中结算:`final = max(1, move.damage(经借力) + atk_eff_attack - def_eff_defense)`,再经 护体减伤% / 气力不继加成(顺序见实现)。**基础攻防默认 0 → 不破坏现有平衡**;装备/buff/内功给加成才生效。
- CombatState 加 `attack:Array[int]`、`defense:Array[int]`、`status:Array`(每侧 buff 列表,`[[],[]]`)。
- `eff_attack(side)=attack[side]+StatusEffect.mods_for(status[side],"attack")`,defense 同理。

## 五、RunState 预留字段(不实现机制,留挂点)

- `equipment: Dictionary`(weapon 槽等)、`hidden_weapons: Dictionary`(暗器id→数量)、`inventory: Array`(丹药/物品)、`money: int`、`reputation: int`(善恶侠名)、`conditions: Array`(持续debuff)。
- `base_attack/base_defense:int`(默认0)、`base_max_qi:int`(默认10)。
- 永久加成聚合:`combat_attack()/combat_defense()/combat_max_hp()/combat_max_qi()` = base + 内功 + 装备 + (果子等永久 modifier)。`weapon_bonus`(已有)并入 attack modifier。

## 六、本切片做 / 留
- **做**:Stats 聚合、StatusEffect 数据结构 + helper(聚合/tick/expire)、CombatState attack/defense/status + 有效值、combat_sim 攻防进公式、RunState 基础属性 + combat_xxx 聚合 + 预留字段、fight 传攻防、测试。
- **留**(字段在,机制后续):装备/暗器/物品/银两/声望机制、持续(跨场)debuff、护体/借力统一进 StatusEffect、触发型被动。

## 七、数值
| 项 | 值 |
|--|--|
| 基础攻击/防御 | 0(默认,不改现有平衡) |
| 伤害公式 | max(1, dmg + atk攻 − def防) 再过护体% |
| StatusEffect 时间单位 | tick/round/fight |

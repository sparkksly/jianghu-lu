class_name CombatState
extends RefCounted

var hp: Array[int] = [50, 50]
var max_hp: Array[int] = [50, 50]
var stamina: Array[int] = [10, 10]
var sta_max: Array[int] = [10, 10]
var regen: Array[int] = [6, 6]  # 每回合开始回气量（内功流派更高）
var n_ticks: int = 15
var gasp_len: int = 3  # K ticks of 喘息 when exhausted
var distance: int = 1  # 共享距离 0贴身/1中/2远
var attack: Array[int] = [10, 10]    # 基础攻击力(基准10 → 招式 damage 即默认伤害)
var dmg_inc: Array[int] = [0, 0]     # 基础伤害增加%(武器/普通强化,之和)
var extra_dmg: Array[int] = [0, 0]   # 额外伤害增加%(稀有,独立乘区,之和)
var armor: Array[int] = [0, 0]       # 防御数值(递减减伤,见 combat_sim)
var status: Array = [[], []]         # 每侧战斗内 buff/debuff(StatusEffect)

func regen_round() -> void:
	for i in stamina.size():
		stamina[i] = min(eff_sta_max(i), stamina[i] + regen[i])

# 有效气力上限 = 基础 − 内伤等 max_qi debuff(扣气力上限)。
func eff_sta_max(side: int) -> int:
	return maxi(1, Stats.aggregate(sta_max[side], StatusEffect.mods_for(status[side], "max_qi"), "max_qi"))

# 有效属性 = 基础 + 本侧 buff 修正(同类 modifier 求和)。
func eff_attack(side: int) -> int:
	return Stats.aggregate(attack[side], StatusEffect.mods_for(status[side], "attack"), "attack")
func eff_dmg_inc(side: int) -> int:
	return Stats.aggregate(dmg_inc[side], StatusEffect.mods_for(status[side], "dmg_inc"), "dmg_inc")
func eff_extra(side: int) -> int:
	return Stats.aggregate(extra_dmg[side], StatusEffect.mods_for(status[side], "extra_dmg"), "extra_dmg")
func eff_armor(side: int) -> int:
	return Stats.aggregate(armor[side], StatusEffect.mods_for(status[side], "armor"), "armor")

func clone() -> CombatState:
	var c := CombatState.new()
	c.hp = hp.duplicate()
	c.max_hp = max_hp.duplicate()
	c.stamina = stamina.duplicate()
	c.sta_max = sta_max.duplicate()
	c.regen = regen.duplicate()
	c.n_ticks = n_ticks
	c.gasp_len = gasp_len
	c.distance = distance
	c.attack = attack.duplicate()
	c.dmg_inc = dmg_inc.duplicate()
	c.extra_dmg = extra_dmg.duplicate()
	c.armor = armor.duplicate()
	c.status = [status[0].duplicate(true), status[1].duplicate(true)]
	return c

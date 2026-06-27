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
var attack: Array[int] = [0, 0]   # 该场基础攻击(来自 run;默认0不改平衡)
var defense: Array[int] = [0, 0]  # 该场基础防御
var status: Array = [[], []]      # 每侧战斗内 buff/debuff 列表(StatusEffect)

func regen_round() -> void:
	for i in stamina.size():
		stamina[i] = min(sta_max[i], stamina[i] + regen[i])

# 有效攻击/防御 = 基础 + 本侧 buff 修正。
func eff_attack(side: int) -> int:
	return Stats.aggregate(attack[side], StatusEffect.mods_for(status[side], "attack"), "attack")

func eff_defense(side: int) -> int:
	return Stats.aggregate(defense[side], StatusEffect.mods_for(status[side], "defense"), "defense")

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
	c.defense = defense.duplicate()
	c.status = [status[0].duplicate(true), status[1].duplicate(true)]
	return c

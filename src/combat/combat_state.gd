class_name CombatState
extends RefCounted

var hp: Array[int] = [50, 50]
var max_hp: Array[int] = [50, 50]
var stamina: Array[int] = [10, 10]
var sta_max: Array[int] = [10, 10]
var regen: Array[int] = [6, 6]  # 每回合开始回气量（内功流派更高）
var n_ticks: int = 12
var gasp_len: int = 3  # K ticks of 喘息 when exhausted

func regen_round() -> void:
	for i in stamina.size():
		stamina[i] = min(sta_max[i], stamina[i] + regen[i])

func clone() -> CombatState:
	var c := CombatState.new()
	c.hp = hp.duplicate()
	c.max_hp = max_hp.duplicate()
	c.stamina = stamina.duplicate()
	c.sta_max = sta_max.duplicate()
	c.regen = regen.duplicate()
	c.n_ticks = n_ticks
	c.gasp_len = gasp_len
	return c

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

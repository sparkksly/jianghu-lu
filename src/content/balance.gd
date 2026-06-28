class_name Balance
extends RefCounted

# 功率预算:每 tier 一个预算,武功属性折算成 power,同 tier power 应≈预算 → 同级平衡。
# 武功不手填 power,从 ArtDef.result + slots + requires + conditional 自动折算。
# 平衡测试遍历所有武功对比预算,偏离超容差报红(见 test_balance)。

# 每级功率预算(曲线一行改全局;先 1/2 级有武功,3-5 留给以后)。
const TIER_BUDGET := {1: 18, 2: 30, 3: 44, 4: 60, 5: 78}   # 递增曲线,一行改全局
const TOLERANCE := 0.45   # 容差(±45%):早期内容宽松,特色武功可偏,超出才报红

# 词缀/属性 power 单价(经验值,靠 playtest 调)。
const AFFIX := {
	"super_armor": 8, "interrupt": 6, "heavy": 4, "knockback": 5,
	"stun_per": 6, "guard_per": 2, "delta_per": 6, "priority_per": 0.5, "pierce": 4,
}
const COST_PER_TICK := 2.0   # 每拍 −power(慢=便宜)
const REQUIRES_DISCOUNT := 0.85
const SLOT_DISCOUNT := 0.08  # 每多拼1张组件的折扣
const STD_COMPONENT := 7.0   # 标准基础招伤害(估手拼威力,不依赖 result 的化境单卡值)
const COMBO_BONUS := 1.25

# 条件加成的可控性系数:越可控,系数越高(满额价值打折越少)。靠 playtest 调。
const CONDITION_FACTOR := {
	"leverage": 0.9, "distance": 0.85, "target_status": 0.5, "hp_below": 0.3,
}

# 一门武功的折算 power。手拼威力(配方长度估) + 词缀 − 帧成本,再过条件/折扣。
static func power(a: ArtDef) -> int:
	var m: Move = a.result
	var p := float(a.slots.size()) * STD_COMPONENT * COMBO_BONUS   # 手拼标准威力
	if m != null:
		p += maxi(0, m.hit_offsets.size() - 1) * 2.0   # 多段节奏小加成
		p += _affix_power(m)
		p += _inflict_power(m)
		p += _empower_power(m)
		p -= m.total_duration() * COST_PER_TICK
	# 条件加成:满额 power × 可控性系数(越可控折扣越少)
	for c in a.conditional:
		var factor: float = CONDITION_FACTOR.get(_cond_kind(c.get("when", {})), 0.4)
		p += _mods_power(c.get("bonus", [])) * factor
	# 折扣:有门槛 / 要手拼多张 → 难得,可更强(预算内放更高)
	if not a.requires.is_empty():
		p *= REQUIRES_DISCOUNT
	if a.slots.size() > 1:
		p *= 1.0 - SLOT_DISCOUNT * (a.slots.size() - 1)
	return maxi(0, int(round(p)))

# Move 的词缀 power(不含伤害,伤害由配方长度估)。
static func _affix_power(m: Move) -> float:
	var p := 0.0
	if m.super_armor: p += AFFIX["super_armor"]
	if m.pierces_dodge: p += AFFIX["pierce"]
	if m.can_interrupt: p += AFFIX["interrupt"]
	if m.is_heavy: p += AFFIX["heavy"]
	if m.knockback: p += AFFIX["knockback"]
	p += m.stun * AFFIX["stun_per"]
	p += m.grants_guard * AFFIX["guard_per"]
	p += absi(m.distance_delta) * AFFIX["delta_per"]
	p += m.priority * AFFIX["priority_per"]
	return p

# 招式附加 debuff 的 power(持续伤害×延迟折扣;属性削弱×单价×时长×折扣)。
const DEBUFF_DELAY := 0.7   # 持续伤害延迟折扣(不即时,可被治疗/击杀打断)
static func _inflict_power(m: Move) -> float:
	var p := 0.0
	for did in m.inflict:
		var d: Dictionary = Debuffs.DEFS.get(did, {})
		if d.is_empty():
			continue
		var dur := int(d.get("duration", 0))
		if d.has("tick"):
			p += absi(int(d["tick"].get("hp", 0))) * dur * DEBUFF_DELAY
		for mod in d.get("modifiers", []):
			p += absf(float(mod.get("value", 0))) * 0.3 * dur * 0.4
	return p

# 招式给自己加 buff 的 power(可控收益:tick 回血/气 + modifier 强化 × 时长)。
const BUFF_FACTOR := 0.5
static func _empower_power(m: Move) -> float:
	var p := 0.0
	for bid in m.empower:
		var d: Dictionary = Buffs.DEFS.get(bid, {})
		if d.is_empty():
			continue
		var dur := int(d.get("duration", 0))
		if d.has("tick"):
			var t: Dictionary = d["tick"]
			p += (absi(int(t.get("hp", 0))) + absi(int(t.get("qi", 0))) * 0.8) * dur * 0.7
		p += _mods_power(d.get("modifiers", [])) * dur * BUFF_FACTOR
	return p

# 一串 modifier(条件加成)的满额 power(增伤%/额外%/攻击/防御各折算)。
static func _mods_power(mods: Array) -> float:
	var p := 0.0
	for mod in mods:
		match mod.get("stat", ""):
			"dmg_inc", "extra_dmg": p += float(mod.get("value", 0)) * 0.3   # 每1%增伤≈0.3power
			"attack": p += float(mod.get("value", 0))
			"armor": p += float(mod.get("value", 0)) * 0.2
			"max_hp": p += float(mod.get("value", 0)) * 0.3
			"max_qi": p += float(mod.get("value", 0)) * 0.3
	return p

static func _cond_kind(when: Dictionary) -> String:
	return when.get("type", "")

static func budget(tier: int) -> int:
	return int(TIER_BUDGET.get(tier, 22))

# power 是否落在该 tier 预算 ± 容差内。
static func in_tolerance(a: ArtDef) -> bool:
	var b := budget(a.tier)
	var p := power(a)
	return absf(float(p - b)) <= float(b) * TOLERANCE

# --- 装备审查(同一套 _mods_power 折算属性) ---
const EQUIP_BUDGET := {1: 5, 2: 9, 3: 14}

static func equip_power(e: EquipDef) -> int:
	return maxi(0, int(round(_mods_power(e.modifiers))))

static func equip_budget(tier: int) -> int:
	return int(EQUIP_BUDGET.get(tier, 5))

static func equip_in_tolerance(e: EquipDef) -> bool:
	var b := equip_budget(e.tier)
	var p := equip_power(e)
	return absf(float(p - b)) <= float(b) * TOLERANCE

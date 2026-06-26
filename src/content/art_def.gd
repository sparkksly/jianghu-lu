class_name ArtDef
extends Resource

# 一门功夫(组合招/绝学)的定义。数据驱动:几百门功夫 = 几百条 ArtDef(可演进为 .tres)。
#   slots    : 配方(基础招序列;可 tag/id/kind/wildcard)。多门功夫可共享同一 slots(撞配方靠多候选消歧)。
#   result   : 融合结果(内联 Move,不指向函数)。
#   requires : 领悟条件(Condition 列表,默认 AND;空=无门槛)。见 Requirements。
#   family   : 功夫分类(掌法/降龙系列…),供 arts_count 类依赖统计。
#   series   : 系列(如降龙十八掌),series_index 渐进。

@export var id: StringName = &""
@export var art_name: String = "功夫"
@export var tier: int = 1
@export var family: Array[StringName] = []
@export var slots: Array = []
@export var requires: Array = []
@export var series: StringName = &""
@export var series_index: int = 0
@export var result: Move
# 实战顿悟:{triggers:[Condition], chance:float}。有 discovery 的功夫不进普通磨练池,
# 只能在战斗中满足行为条件后概率顿悟(如无影脚:腿法≥5+两连腿法→30%)。
@export var discovery: Dictionary = {}
# 稀缺:复杂稀有的招(绝世神功),只能靠奇遇获得,自己磨练/顿悟不出来。
@export var exotic: bool = false

static func make(p_id: StringName, p_name: String, p_tier: int, p_family: Array, p_slots: Array, p_result: Move, p_requires := [], p_series := &"", p_index := 0, p_discovery := {}, p_exotic := false) -> ArtDef:
	var d := ArtDef.new()
	d.id = p_id
	d.art_name = p_name
	d.tier = p_tier
	var fam: Array[StringName] = []
	for f in p_family: fam.append(f)
	d.family = fam
	d.slots = p_slots
	d.result = p_result
	d.requires = p_requires
	d.series = p_series
	d.series_index = p_index
	d.discovery = p_discovery
	d.exotic = p_exotic
	return d

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
# 获得途径(数据驱动):[{via, ...}]。
#   via="encounter" 奇遇 / "practice" 磨练自悟 / "insight" 实战顿悟(带 triggers+chance)。
# 独立组合即各种规则:只 [encounter]=稀缺仅奇遇; [encounter,insight]=可奇遇可顿悟但不可磨练;
# 默认 [encounter,practice]。加新途径(boss奖励/购买…)只加个 via,不动核心。
@export var sources: Array = []
# 条件加成:[{when:Condition, bonus:[modifier]}]。满足 when 则得 bonus(combat 用);
# Balance 按可控性系数折算 power。现在留接口,以后填借力/中毒/残血斩之类条件卡。
@export var conditional: Array = []

static func make(p_id: StringName, p_name: String, p_tier: int, p_family: Array, p_slots: Array, p_result: Move, p_requires := [], p_series := &"", p_index := 0, p_sources = null) -> ArtDef:
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
	d.sources = p_sources if p_sources != null else [{"via": "encounter"}, {"via": "practice"}]
	d.conditional = []
	return d

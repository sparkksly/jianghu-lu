class_name Encounters
extends RefCounted

# 江湖奇遇:经典武侠场面。每个 {id,title,body,options:[{label,effect}]}。
# effect 由 RunState.apply_encounter 应用。

static func all() -> Array:
	return [
		{
			"id": &"cave", "title": "幽洞遗篇",
			"body": "你失足跌落幽深山洞,本以为必死,却见石壁暗格里藏着一卷泛黄秘籍。",
			"options": [{"label": "潜心研读   ( 领悟一门绝学 )", "effect": {"learn_art": true}}],
		},
		{
			"id": &"hermit", "title": "隐世高人",
			"body": "林间茅屋,一位须发皆白的老者见你根骨不凡,捋须一笑:「后生,可愿听老朽一言?」",
			"options": [
				{"label": "求授新招   ( 学一门大成招 )", "effect": {"master_move": true}},
				{"label": "请教精要   ( 一招大进·+5熟练 )", "effect": {"master_master": true}},
			],
		},
		{
			"id": &"weapon", "title": "古冢神兵",
			"body": "荒冢崩裂,一柄寒光凛冽的古剑斜插在石中,剑气逼人。",
			"options": [
				{"label": "拔取重刀   ( 装备·攻击 +6 伤害 +10% )", "effect": {"equip": &"xuantie_dao"}},
				{"label": "取那软剑   ( 装备·伤害 +16% )", "effect": {"equip": &"hanyue"}},
			],
		},
		{
			"id": &"fruit", "title": "空谷灵果",
			"body": "幽谷深处,一株虬结古树结着莹润如玉的灵果,异香扑鼻,似有大造化。",
			"options": [{"label": "食此灵果   ( +12 气血,内功 +2 级 )", "effect": {"hp": 12, "neigong": 2}}],
		},
		{
			"id": &"inn", "title": "荒野客栈",
			"body": "风雪交加的夜里,一间破败客栈透出暖光,正好歇脚疗伤、运功调息。",
			"options": [{"label": "歇脚疗伤   ( 回满气血,内功 +1 )", "effect": {"heal_full": true, "neigong": 1}}],
		},
		{
			"id": &"silver", "title": "镖银散落",
			"body": "山道旁一辆翻覆的镖车,几锭散银滚落草丛,四下无人。",
			"options": [{"label": "拾取散银   ( +40 银两 )", "effect": {"money": 40}}],
		},
		{
			"id": &"gamble", "title": "黑市赌坊",
			"body": "镇外一处隐秘赌坊,庄家堆着白花花的银锭,似笑非笑地看着你。",
			"options": [
				{"label": "押上盘缠   ( 五五开:赢 +80 / 输 −40 )", "effect": {"risk": {"chance": 0.5, "win": {"money": 80}, "lose": {"money": -40}}}},
				{"label": "不赌,离去", "effect": {}},
			],
		},
		{
			"id": &"justice", "title": "仗义疏财",
			"body": "市集上恶霸强抢民女的卖身银,众人敢怒不敢言。你手按刀柄。",
			"options": [
				{"label": "出手相助   ( 侠名 +2,百姓酬谢 +20 银两 )", "effect": {"reputation": 2, "money": 20}},
				{"label": "夺银自取   ( +50 银两,侠名 −2 )", "effect": {"money": 50, "reputation": -2}},
			],
		},
		{
			"id": &"cliff", "title": "绝壁灵药",
			"body": "万丈绝壁上一株血红灵芝迎风摇曳,采之凶险,得之大补。",
			"options": [
				{"label": "攀崖采药   ( 六成:+18 气血·内功+1 / 失手 −12 气血 )", "effect": {"risk": {"chance": 0.6, "win": {"heal": 18, "neigong": 1}, "lose": {"heal": -12}}}},
				{"label": "量力而退", "effect": {}},
			],
		},
		{
			"id": &"scroll", "title": "武学残卷",
			"body": "破庙残碑之后,藏着半卷被虫蛀的武学秘要,字迹依稀可辨。",
			"options": [{"label": "参研残卷   ( 领悟一门绝学 )", "effect": {"learn_art": true}}],
		},
	]

# 按章给不同奇遇;用 rng 在该章候选池里选(每章 4 候选,跨类型)。
static func for_chapter(chapter: int, rng: RandomNumberGenerator) -> Dictionary:
	var pool := all()
	var buckets := [[0, 1, 5, 7], [2, 3, 6, 8], [4, 9, 6, 7]]
	var idxs: Array = buckets[clampi(chapter, 0, 2)]
	return pool[idxs[rng.randi_range(0, idxs.size() - 1)]]

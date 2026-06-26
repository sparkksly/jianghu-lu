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
			"options": [{"label": "拔取神兵   ( 全攻击 +2 伤 )", "effect": {"weapon_dmg": 2}}],
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
	]

# 按章给不同奇遇(章0 山洞/高人, 章1 神兵/灵果, 章2 客栈/...);用 rng 在该章候选里选。
static func for_chapter(chapter: int, rng: RandomNumberGenerator) -> Dictionary:
	var pool := all()
	var buckets := [[0, 1], [2, 3], [4, 0]]
	var idxs: Array = buckets[clampi(chapter, 0, 2)]
	return pool[idxs[rng.randi_range(0, idxs.size() - 1)]]

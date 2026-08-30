class_name DiceCatalog
extends RefCounted

const DEFAULT_ID := "default"
const MAX_DICE := 6

const DEFINITIONS := [
	{
		"id": DEFAULT_ID,
		"name": "默认骰",
		"weights": [1, 1, 1, 1, 1, 1],
		"odds": "1–6点：各16.7%",
		"advantage": "优势：分布均衡，顺子与各种组合都较稳定。",
		"tradeoff": "代价：没有特别容易出现的得分点数。",
		"body_color": Color("ead7aa"),
		"pip_color": Color("3b2118"),
		"rim_color": Color("fff1bd"),
	},
	{
		"id": "lucky",
		"name": "幸运骰",
		"weights": [18, 16, 16, 16, 18, 16],
		"odds": "1:18%  2:16%  3:16%  4:16%  5:18%  6:16%",
		"advantage": "优势：1和5更常见，容易取得可保留的得分骰。",
		"tradeoff": "代价：顺子及2、3、4、6的多骰组合更难形成。",
		"body_color": Color("d6a83f"),
		"pip_color": Color("5a2d12"),
		"rim_color": Color("ffe39a"),
	},
	{
		"id": "iron",
		"name": "铁卫骰",
		"weights": [8, 12, 30, 30, 12, 8],
		"odds": "1:8%  2:12%  3:30%  4:30%  5:12%  6:8%",
		"advantage": "优势：3和4集中，较容易凑出三连。",
		"tradeoff": "代价：单独得分的1和5较少，爆骰风险更高。",
		"body_color": Color("9e4d3c"),
		"pip_color": Color("f2dfbf"),
		"rim_color": Color("d98668"),
	},
	{
		"id": "royal",
		"name": "王权骰",
		"weights": [6, 18, 18, 18, 10, 30],
		"odds": "1:6%  2:18%  3:18%  4:18%  5:10%  6:30%",
		"advantage": "优势：极易累积6，六点多连拥有很高上限。",
		"tradeoff": "代价：单个6不得分，未成三连时容易爆骰。",
		"body_color": Color("354f82"),
		"pip_color": Color("f4c95d"),
		"rim_color": Color("718dc3"),
	},
	{
		"id": "reckless",
		"name": "孤注骰",
		"weights": [18, 17, 17, 17, 8, 23],
		"odds": "1:18%  2:17%  3:17%  4:17%  5:8%  6:23%",
		"advantage": "优势：1和6略多，兼顾稳定单分与高分六点多连。",
		"tradeoff": "代价：5很少，未形成六点多连时爆骰风险更高。",
		"body_color": Color("31483a"),
		"pip_color": Color("e86b4f"),
		"rim_color": Color("738a74"),
	},
]


static func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition in DEFINITIONS:
		ids.append(String(definition["id"]))
	return ids


static func get_definition(type_id: String) -> Dictionary:
	for definition in DEFINITIONS:
		if String(definition["id"]) == type_id:
			return definition.duplicate(true)
	return DEFINITIONS[0].duplicate(true)


static func is_valid_type(type_id: String) -> bool:
	return get_ids().has(type_id)


static func normalize_loadout(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if result.size() >= MAX_DICE:
			break
		var type_id := String(value)
		if is_valid_type(type_id):
			result.append(type_id)
	while result.size() < MAX_DICE:
		result.append(DEFAULT_ID)
	return result


static func default_loadout() -> Array[String]:
	return normalize_loadout([])


static func roll_value(type_id: String, rng: RandomNumberGenerator) -> int:
	var definition := get_definition(type_id)
	var weights: Array = definition["weights"]
	var total := 0
	for weight in weights:
		total += int(weight)
	var result := rng.randi_range(1, total)
	var accumulated := 0
	for index in range(weights.size()):
		accumulated += int(weights[index])
		if result <= accumulated:
			return index + 1
	return 6

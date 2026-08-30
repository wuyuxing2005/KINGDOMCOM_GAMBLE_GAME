class_name DiceCatalog
extends RefCounted

const DEFAULT_ID := "default"
const MAX_DICE := 6

const WILD_FACE := 7
const BLANK_FACE := 8
const GREED_FACE := 9
const DEBT_FACE := 10

const DEFAULT_DEFINITION := {
	"id": DEFAULT_ID,
	"name": "普通骰",
	"faces": [1, 2, 3, 4, 5, 6],
	"body_color": Color("ead7aa"),
	"pip_color": Color("3b2118"),
	"rim_color": Color("fff1bd"),
}

# Only special dice belong here. The selection screen iterates this list, while
# unfilled loadout slots are still normalized to the hidden ordinary die.
const DEFINITIONS := [
	{
		"id": "wild",
		"name": "万能骰",
		"faces": [2, 3, 4, 5, 6, WILD_FACE],
		"odds": "六面：2 / 3 / 4 / 5 / 6 / ★",
		"advantage": "优势：★可补三条、多连或顺子，修正差一个点数的组合。",
		"tradeoff": "代价：没有1面，★不能单独作为1或5计分。",
		"body_color": Color("7657a6"),
		"pip_color": Color("f8e9ff"),
		"rim_color": Color("c4a6f0"),
	},
	{
		"id": "gambler",
		"name": "赌徒骰",
		"faces": [1, 1, 5, 5, BLANK_FACE, BLANK_FACE],
		"odds": "六面：1 / 1 / 5 / 5 / X / X",
		"advantage": "优势：66.7%出现可单独得分的1或5，单骰保命能力强。",
		"tradeoff": "代价：X没有任何价值，大型组合与顺子能力较弱。",
		"body_color": Color("b5453d"),
		"pip_color": Color("fff0d2"),
		"rim_color": Color("ef8b70"),
	},
	{
		"id": "sequence",
		"name": "连号骰",
		"faces": [2, 3, 3, 4, 4, 5],
		"odds": "六面：2 / 3 / 3 / 4 / 4 / 5",
		"advantage": "优势：容易累积3和4，也适合补齐两种小顺子。",
		"tradeoff": "代价：没有1和6，仅一个5可单独计分，少骰时危险。",
		"body_color": Color("3f7892"),
		"pip_color": Color("e7f7f5"),
		"rim_color": Color("7fc5cc"),
	},
	{
		"id": "greed",
		"name": "贪婪骰",
		"faces": [1, 3, 4, 5, 6, GREED_FACE],
		"odds": "六面：1 / 3 / 4 / 5 / 6 / 💰",
		"advantage": "优势：💰令本次选中组合得分提高50%。",
		"tradeoff": "代价：出现💰后不能停手，必须至少继续投掷一次。",
		"body_color": Color("b88a25"),
		"pip_color": Color("3e2910"),
		"rim_color": Color("f3cf61"),
	},
	{
		"id": "debt",
		"name": "债务骰",
		"faces": [1, 1, 5, 5, 6, DEBT_FACE],
		"odds": "六面：1 / 1 / 5 / 5 / 6 / 💀",
		"advantage": "优势：四个面可单独得分，前期稳定取得小分。",
		"tradeoff": "代价：每个💀令本轮已累计分数减少200，最低降至0。",
		"body_color": Color("34383c"),
		"pip_color": Color("e8dfd0"),
		"rim_color": Color("747b80"),
	},
]


static func get_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition in DEFINITIONS:
		ids.append(String(definition["id"]))
	return ids


static func get_definition(type_id: String) -> Dictionary:
	if type_id == DEFAULT_ID:
		return DEFAULT_DEFINITION.duplicate(true)
	for definition in DEFINITIONS:
		if String(definition["id"]) == type_id:
			return definition.duplicate(true)
	return DEFAULT_DEFINITION.duplicate(true)


static func is_valid_type(type_id: String) -> bool:
	return type_id == DEFAULT_ID or get_ids().has(type_id)


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


static func random_loadout(rng: RandomNumberGenerator) -> Array[String]:
	var ids := get_ids()
	var result: Array[String] = []
	for index in range(MAX_DICE):
		result.append(ids[rng.randi_range(0, ids.size() - 1)])
	return result


static func roll_value(type_id: String, rng: RandomNumberGenerator) -> int:
	var faces: Array = get_definition(type_id)["faces"]
	return int(faces[rng.randi_range(0, faces.size() - 1)])


static func face_slot_for_value(type_id: String, value: int) -> int:
	var faces: Array = get_definition(type_id)["faces"]
	var index := faces.find(value)
	return index + 1 if index >= 0 else 1


static func face_label(value: int) -> String:
	match value:
		WILD_FACE:
			return "★"
		BLANK_FACE:
			return "X"
		GREED_FACE:
			return "$"
		DEBT_FACE:
			return "☠"
	return str(value)

class_name DiceCatalog
extends RefCounted

const DEFAULT_ID := "default"
const MAX_DICE := 6
const MAX_SPECIAL_DICE_PER_TYPE := 2

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
		"description": "★可补三条、多连或顺子，但不能单独计分。",
		"body_color": Color("7657a6"),
		"pip_color": Color("f8e9ff"),
		"rim_color": Color("c4a6f0"),
	},
	{
		"id": "gambler",
		"name": "赌徒骰",
		"faces": [1, 5, 5, BLANK_FACE, BLANK_FACE, BLANK_FACE],
		"odds": "六面：1 / 5 / 5 / X / X / X",
		"description": "一半骰面可直接得分；X为完全无效面。",
		"body_color": Color("b5453d"),
		"pip_color": Color("fff0d2"),
		"rim_color": Color("ef8b70"),
	},
	{
		"id": "sequence",
		"name": "连号骰",
		"faces": [2, 3, 3, 4, 4, 5],
		"odds": "六面：2 / 3 / 3 / 4 / 4 / 5",
		"description": "点数集中在2至5，适合累积3、4和组成顺子。",
		"body_color": Color("3f7892"),
		"pip_color": Color("e7f7f5"),
		"rim_color": Color("7fc5cc"),
	},
	{
		"id": "greed",
		"name": "贪婪骰",
		"faces": [1, 3, 4, 5, 6, GREED_FACE],
		"odds": "六面：1 / 3 / 4 / 5 / 6 / 💰",
		"description": "💰使本次得分翻倍，并强制继续投掷一次。",
		"body_color": Color("b88a25"),
		"pip_color": Color("3e2910"),
		"rim_color": Color("f3cf61"),
	},
	{
		"id": "debt",
		"name": "债务骰",
		"faces": [1, 5, 5, 6, 6, DEBT_FACE],
		"odds": "六面：1 / 5 / 5 / 6 / 6 / 💀",
		"description": "有效骰面质量较高；每个💀使本轮分数减少200。",
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
	var special_counts: Dictionary = {}
	for value in values:
		if result.size() >= MAX_DICE:
			break
		var type_id := String(value)
		if not is_valid_type(type_id):
			continue
		if type_id != DEFAULT_ID:
			var count := int(special_counts.get(type_id, 0))
			if count >= MAX_SPECIAL_DICE_PER_TYPE:
				continue
			special_counts[type_id] = count + 1
		result.append(type_id)
	while result.size() < MAX_DICE:
		result.append(DEFAULT_ID)
	return result


static func default_loadout() -> Array[String]:
	return normalize_loadout([])


static func random_loadout(rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = []
	for type_id in get_ids():
		for count in range(MAX_SPECIAL_DICE_PER_TYPE):
			pool.append(type_id)
	var result: Array[String] = []
	for index in range(MAX_DICE):
		var pool_index := rng.randi_range(0, pool.size() - 1)
		result.append(pool[pool_index])
		pool.remove_at(pool_index)
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

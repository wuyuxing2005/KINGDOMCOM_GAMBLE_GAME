class_name NetworkSessionProxy
extends RefCounted

var target_score := 4000
var scores: Array[int] = [0, 0]
var current_player := 0
var turn_score := 0
var current_roll: Array[int] = []
var current_roll_types: Array[String] = []
var held_dice: Array[int] = []
var held_dice_types: Array[String] = []
var player_dice_loadouts: Array = [DiceCatalog.default_loadout(), DiceCatalog.default_loadout()]
var selected_indices: Array[int] = []
var dice_to_roll := 6
var must_roll_again := false
var phase := GameSession.Phase.AWAITING_ROLL
var winner := -1

func apply_snapshot(snapshot: GameSnapshot) -> void:
	target_score = snapshot.target_score
	scores = snapshot.scores.duplicate()
	current_player = snapshot.current_player
	turn_score = snapshot.turn_score
	current_roll = snapshot.current_roll.duplicate()
	current_roll_types = snapshot.current_roll_types.duplicate()
	if current_roll_types.size() != current_roll.size():
		current_roll_types.assign(_default_types(current_roll.size()))
	held_dice = snapshot.held_dice.duplicate()
	held_dice_types = snapshot.held_dice_types.duplicate()
	if held_dice_types.size() != held_dice.size():
		held_dice_types.assign(_default_types(held_dice.size()))
	player_dice_loadouts = [
		DiceCatalog.normalize_loadout(snapshot.player_dice_loadouts[0] if snapshot.player_dice_loadouts.size() > 0 else []),
		DiceCatalog.normalize_loadout(snapshot.player_dice_loadouts[1] if snapshot.player_dice_loadouts.size() > 1 else []),
	]
	selected_indices = snapshot.selected_indices.duplicate()
	dice_to_roll = snapshot.dice_to_roll
	must_roll_again = snapshot.must_roll_again
	phase = snapshot.phase
	winner = snapshot.winner

func get_selected_score() -> int:
	var values: Array[int] = []
	for index in selected_indices:
		if index >= 0 and index < current_roll.size():
			values.append(current_roll[index])
	var base_score := ScoringRules.score_selection(values)
	if base_score > 0 and current_roll.has(DiceCatalog.GREED_FACE):
		return base_score * 2
	return base_score

func _default_types(count: int) -> Array[String]:
	var result: Array[String] = []
	for index in range(count):
		result.append(DiceCatalog.DEFAULT_ID)
	return result

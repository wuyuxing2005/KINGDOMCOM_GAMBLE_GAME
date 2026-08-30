class_name GameSession
extends RefCounted

signal state_changed(snapshot: GameSnapshot)
signal rolled(values: Array[int], dice_types: Array[String])
signal busted(player_index: int)
signal hot_dice(player_index: int)
signal game_finished(winner_index: int)

enum Phase {
	AWAITING_ROLL,
	AWAITING_SELECTION,
	BUSTED,
	GAME_OVER,
}

var target_score: int
var scores: Array[int] = [0, 0]
var current_player := 0
var turn_score := 0
var current_roll: Array[int] = []
var current_roll_types: Array[String] = []
var held_dice: Array[int] = []
var held_dice_types: Array[String] = []
var player_dice_loadouts: Array = [DiceCatalog.default_loadout(), DiceCatalog.default_loadout()]
var next_roll_types: Array[String] = []
var selected_indices: Array[int] = []
var dice_to_roll := 6
var must_roll_again := false
var phase := Phase.AWAITING_ROLL
var winner := -1
var rng := RandomNumberGenerator.new()

func _init(game_target_score: int = 4000, random_seed: int = -1, loadouts: Array = []) -> void:
	target_score = game_target_score
	if loadouts.size() > 0:
		player_dice_loadouts[0] = DiceCatalog.normalize_loadout(loadouts[0] if loadouts[0] is Array else [])
	if loadouts.size() > 1:
		player_dice_loadouts[1] = DiceCatalog.normalize_loadout(loadouts[1] if loadouts[1] is Array else [])
	if random_seed >= 0:
		rng.seed = random_seed
	else:
		rng.randomize()

func set_player_loadout(player_index: int, loadout: Array) -> bool:
	if player_index < 0 or player_index > 1 or phase != Phase.AWAITING_ROLL or not current_roll.is_empty():
		return false
	player_dice_loadouts[player_index] = DiceCatalog.normalize_loadout(loadout)
	return true

func apply_action(action: GameAction) -> bool:
	match action.type:
		GameAction.Type.ROLL:
			return _apply_roll()
		GameAction.Type.SET_SELECTION:
			return _apply_selection(action.indices)
		GameAction.Type.ROLL_AGAIN:
			return _apply_roll_again()
		GameAction.Type.BANK:
			return _apply_bank()
	return false

func resolve_bust() -> void:
	if phase != Phase.BUSTED:
		return
	_end_turn()

func get_selected_values() -> Array[int]:
	var values: Array[int] = []
	for index in selected_indices:
		if index >= 0 and index < current_roll.size():
			values.append(current_roll[index])
	return values

func get_selected_score() -> int:
	var base_score := ScoringRules.score_selection(get_selected_values())
	if base_score > 0 and current_roll.has(DiceCatalog.GREED_FACE):
		return base_score * 3 / 2
	return base_score

func get_snapshot() -> GameSnapshot:
	var snapshot := GameSnapshot.new()
	snapshot.target_score = target_score
	snapshot.scores = scores.duplicate()
	snapshot.current_player = current_player
	snapshot.turn_score = turn_score
	snapshot.selected_score = maxi(0, get_selected_score())
	snapshot.current_roll = current_roll.duplicate()
	snapshot.current_roll_types = current_roll_types.duplicate()
	snapshot.held_dice = held_dice.duplicate()
	snapshot.held_dice_types = held_dice_types.duplicate()
	snapshot.player_dice_loadouts = [player_dice_loadouts[0].duplicate(), player_dice_loadouts[1].duplicate()]
	snapshot.selected_indices = selected_indices.duplicate()
	snapshot.dice_to_roll = dice_to_roll
	snapshot.must_roll_again = must_roll_again
	snapshot.phase = phase
	snapshot.winner = winner
	return snapshot

func _apply_roll() -> bool:
	if phase != Phase.AWAITING_ROLL:
		return false
	current_roll.clear()
	current_roll_types.clear()
	selected_indices.clear()
	if next_roll_types.is_empty():
		var full_loadout: Array = player_dice_loadouts[current_player]
		for index in range(dice_to_roll):
			current_roll_types.append(String(full_loadout[index]))
	else:
		current_roll_types.assign(next_roll_types)
		next_roll_types.clear()
	for type_id in current_roll_types:
		current_roll.append(DiceCatalog.roll_value(type_id, rng))
	var debt_faces := current_roll.count(DiceCatalog.DEBT_FACE)
	if debt_faces > 0:
		scores[current_player] = maxi(0, scores[current_player] - debt_faces * 300)
	must_roll_again = current_roll.has(DiceCatalog.GREED_FACE)
	phase = Phase.AWAITING_SELECTION
	rolled.emit(current_roll.duplicate(), current_roll_types.duplicate())
	if not ScoringRules.has_score(current_roll):
		turn_score = 0
		must_roll_again = false
		phase = Phase.BUSTED
		busted.emit(current_player)
	_emit_state()
	return true

func _apply_selection(indices: Array[int]) -> bool:
	if phase != Phase.AWAITING_SELECTION:
		return false
	var normalized: Array[int] = []
	for index in indices:
		if index < 0 or index >= current_roll.size() or normalized.has(index):
			return false
		normalized.append(index)
	normalized.sort()
	selected_indices = normalized
	_emit_state()
	return true

func _apply_roll_again() -> bool:
	if phase != Phase.AWAITING_SELECTION:
		return false
	var selection_score := get_selected_score()
	if selection_score <= 0:
		return false
	turn_score += selection_score
	var selected_values := get_selected_values()
	held_dice.append_array(selected_values)
	var remaining_types: Array[String] = []
	for index in range(current_roll_types.size()):
		if selected_indices.has(index):
			held_dice_types.append(current_roll_types[index])
		else:
			remaining_types.append(current_roll_types[index])
	var remaining := current_roll.size() - selected_indices.size()
	if remaining == 0:
		dice_to_roll = 6
		held_dice.clear()
		held_dice_types.clear()
		next_roll_types.clear()
		hot_dice.emit(current_player)
	else:
		dice_to_roll = remaining
		next_roll_types.assign(remaining_types)
	current_roll.clear()
	current_roll_types.clear()
	selected_indices.clear()
	phase = Phase.AWAITING_ROLL
	_emit_state()
	return _apply_roll()

func _apply_bank() -> bool:
	if phase != Phase.AWAITING_SELECTION or must_roll_again:
		return false
	var selection_score := get_selected_score()
	if selection_score <= 0:
		return false
	turn_score += selection_score
	scores[current_player] += turn_score
	if scores[current_player] >= target_score:
		winner = current_player
		phase = Phase.GAME_OVER
		current_roll.clear()
		current_roll_types.clear()
		next_roll_types.clear()
		selected_indices.clear()
		game_finished.emit(winner)
		_emit_state()
		return true
	_end_turn()
	return true

func _end_turn() -> void:
	current_player = 1 - current_player
	turn_score = 0
	current_roll.clear()
	current_roll_types.clear()
	held_dice.clear()
	held_dice_types.clear()
	next_roll_types.clear()
	selected_indices.clear()
	dice_to_roll = 6
	must_roll_again = false
	phase = Phase.AWAITING_ROLL
	_emit_state()

func _emit_state() -> void:
	state_changed.emit(get_snapshot())

class_name GameSession
extends RefCounted

signal state_changed(snapshot: GameSnapshot)
signal rolled(values: Array[int])
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
var held_dice: Array[int] = []
var selected_indices: Array[int] = []
var dice_to_roll := 6
var phase := Phase.AWAITING_ROLL
var winner := -1
var rng := RandomNumberGenerator.new()

func _init(game_target_score: int = 4000, random_seed: int = -1) -> void:
	target_score = game_target_score
	if random_seed >= 0:
		rng.seed = random_seed
	else:
		rng.randomize()

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
	return ScoringRules.score_selection(get_selected_values())

func get_snapshot() -> GameSnapshot:
	var snapshot := GameSnapshot.new()
	snapshot.target_score = target_score
	snapshot.scores = scores.duplicate()
	snapshot.current_player = current_player
	snapshot.turn_score = turn_score
	snapshot.selected_score = maxi(0, get_selected_score())
	snapshot.current_roll = current_roll.duplicate()
	snapshot.held_dice = held_dice.duplicate()
	snapshot.selected_indices = selected_indices.duplicate()
	snapshot.dice_to_roll = dice_to_roll
	snapshot.phase = phase
	snapshot.winner = winner
	return snapshot

func _apply_roll() -> bool:
	if phase != Phase.AWAITING_ROLL:
		return false
	current_roll.clear()
	selected_indices.clear()
	for die in range(dice_to_roll):
		current_roll.append(rng.randi_range(1, 6))
	phase = Phase.AWAITING_SELECTION
	rolled.emit(current_roll.duplicate())
	if not ScoringRules.has_score(current_roll):
		turn_score = 0
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
	var remaining := current_roll.size() - selected_indices.size()
	if remaining == 0:
		dice_to_roll = 6
		held_dice.clear()
		hot_dice.emit(current_player)
	else:
		dice_to_roll = remaining
	current_roll.clear()
	selected_indices.clear()
	phase = Phase.AWAITING_ROLL
	_emit_state()
	return _apply_roll()

func _apply_bank() -> bool:
	if phase != Phase.AWAITING_SELECTION:
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
	held_dice.clear()
	selected_indices.clear()
	dice_to_roll = 6
	phase = Phase.AWAITING_ROLL
	_emit_state()

func _emit_state() -> void:
	state_changed.emit(get_snapshot())


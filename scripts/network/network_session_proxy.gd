class_name NetworkSessionProxy
extends RefCounted

var target_score := 4000
var scores: Array[int] = [0, 0]
var current_player := 0
var turn_score := 0
var current_roll: Array[int] = []
var held_dice: Array[int] = []
var selected_indices: Array[int] = []
var dice_to_roll := 6
var phase := GameSession.Phase.AWAITING_ROLL
var winner := -1

func apply_snapshot(snapshot: GameSnapshot) -> void:
	target_score = snapshot.target_score
	scores = snapshot.scores.duplicate()
	current_player = snapshot.current_player
	turn_score = snapshot.turn_score
	current_roll = snapshot.current_roll.duplicate()
	held_dice = snapshot.held_dice.duplicate()
	selected_indices = snapshot.selected_indices.duplicate()
	dice_to_roll = snapshot.dice_to_roll
	phase = snapshot.phase
	winner = snapshot.winner

func get_selected_score() -> int:
	var values: Array[int] = []
	for index in selected_indices:
		if index >= 0 and index < current_roll.size():
			values.append(current_roll[index])
	return ScoringRules.score_selection(values)

class_name GameAction
extends RefCounted

enum Type {
	ROLL,
	SET_SELECTION,
	ROLL_AGAIN,
	BANK,
}

var type: Type
var indices: Array[int] = []

func _init(action_type: Type, selected_indices: Array[int] = []) -> void:
	type = action_type
	indices = selected_indices.duplicate()

static func roll() -> GameAction:
	return GameAction.new(Type.ROLL)

static func set_selection(selected_indices: Array[int]) -> GameAction:
	return GameAction.new(Type.SET_SELECTION, selected_indices)

static func roll_again() -> GameAction:
	return GameAction.new(Type.ROLL_AGAIN)

static func bank() -> GameAction:
	return GameAction.new(Type.BANK)


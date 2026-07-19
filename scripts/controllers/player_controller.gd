class_name PlayerController
extends RefCounted

signal action_requested(action: GameAction)

func submit(action: GameAction) -> void:
	action_requested.emit(action)


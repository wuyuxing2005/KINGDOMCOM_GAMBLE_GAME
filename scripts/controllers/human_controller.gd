class_name HumanController
extends PlayerController

func choose_indices(indices: Array[int]) -> void:
	submit(GameAction.set_selection(indices))

func roll_again() -> void:
	submit(GameAction.roll_again())

func bank() -> void:
	submit(GameAction.bank())


class_name GameSnapshot
extends RefCounted

var target_score: int = 4000
var scores: Array[int] = [0, 0]
var current_player: int = 0
var turn_score: int = 0
var selected_score: int = 0
var current_roll: Array[int] = []
var held_dice: Array[int] = []
var selected_indices: Array[int] = []
var dice_to_roll: int = 6
var phase: int = 0
var winner: int = -1


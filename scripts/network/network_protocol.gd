class_name NetworkProtocol
extends RefCounted

const CREATE_ROOM := "create_room"
const JOIN_ROOM := "join_room"
const ACTION := "action"
const CHAT_SEND := "chat_send"
const REMATCH_REQUEST := "rematch_request"
const REMATCH_CONFIRM := "rematch_confirm"
const ROOM_CREATED := "room_created"
const ROOM_JOINED := "room_joined"
const ROOM_READY := "room_ready"
const REMATCH_WAITING := "rematch_waiting"
const REMATCH_CHOOSE_TARGET := "rematch_choose_target"
const REMATCH_STARTED := "rematch_started"
const SNAPSHOT := "snapshot"
const ROLLED := "rolled"
const BUSTED := "busted"
const HOT_DICE := "hot_dice"
const CHAT_MESSAGE := "chat_message"
const GAME_FINISHED := "game_finished"
const OPPONENT_LEFT := "opponent_left"
const ERROR := "error"

const CHAT_KIND_TEXT := "text"
const CHAT_KIND_STICKER := "sticker"
const CHAT_STICKER_IDS := ["smile", "heart_eyes", "crying", "side_eye", "black_grin", "excited"]

static func action_to_dictionary(action: GameAction) -> Dictionary:
	return {
		"type": action.type,
		"indices": action.indices.duplicate(),
	}

static func action_from_dictionary(data: Dictionary) -> GameAction:
	var indices: Array[int] = []
	for value in data.get("indices", []):
		indices.append(int(value))
	return GameAction.new(int(data.get("type", -1)), indices)

static func snapshot_to_dictionary(snapshot: GameSnapshot) -> Dictionary:
	return {
		"target_score": snapshot.target_score,
		"scores": snapshot.scores.duplicate(),
		"current_player": snapshot.current_player,
		"turn_score": snapshot.turn_score,
		"selected_score": snapshot.selected_score,
		"current_roll": snapshot.current_roll.duplicate(),
		"held_dice": snapshot.held_dice.duplicate(),
		"selected_indices": snapshot.selected_indices.duplicate(),
		"dice_to_roll": snapshot.dice_to_roll,
		"phase": snapshot.phase,
		"winner": snapshot.winner,
	}

static func snapshot_from_dictionary(data: Dictionary) -> GameSnapshot:
	var snapshot := GameSnapshot.new()
	snapshot.target_score = int(data.get("target_score", 4000))
	snapshot.scores = _int_array(data.get("scores", [0, 0]))
	snapshot.current_player = int(data.get("current_player", 0))
	snapshot.turn_score = int(data.get("turn_score", 0))
	snapshot.selected_score = int(data.get("selected_score", 0))
	snapshot.current_roll = _int_array(data.get("current_roll", []))
	snapshot.held_dice = _int_array(data.get("held_dice", []))
	snapshot.selected_indices = _int_array(data.get("selected_indices", []))
	snapshot.dice_to_roll = int(data.get("dice_to_roll", 6))
	snapshot.phase = int(data.get("phase", 0))
	snapshot.winner = int(data.get("winner", -1))
	return snapshot

static func _int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	return result

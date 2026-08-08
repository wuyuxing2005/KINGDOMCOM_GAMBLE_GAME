class_name MedievalDiceServer
extends Node

const Protocol = preload("res://scripts/network/network_protocol.gd")
const Session = preload("res://scripts/core/game_session.gd")
const Action = preload("res://scripts/core/game_action.gd")

var peer: WebSocketMultiplayerPeer
var rooms: Dictionary = {}
var peer_rooms: Dictionary = {}
var rng := RandomNumberGenerator.new()
var session_seed := -1

func start(port: int = 9080, bind_address: String = "*") -> Error:
	peer = WebSocketMultiplayerPeer.new()
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.peer_disconnected.connect(_on_peer_disconnected)
	var error := peer.create_server(port, bind_address)
	if error == OK:
		rng.randomize()
		print("中世纪骰局服务器已监听 %s:%d" % [bind_address, port])
	return error

func stop() -> void:
	if peer != null:
		peer.close()
	peer = null
	rooms.clear()
	peer_rooms.clear()

func _process(_delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	while peer != null and peer.get_available_packet_count() > 0:
		var sender := peer.get_packet_peer()
		var text := peer.get_packet().get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			_handle_message(sender, parsed)

func _handle_message(sender: int, message: Dictionary) -> void:
	match String(message.get("type", "")):
		Protocol.CREATE_ROOM:
			_create_room(sender, int(message.get("target_score", 4000)))
		Protocol.JOIN_ROOM:
			_join_room(sender, String(message.get("room_code", "")).strip_edges().to_upper())
		Protocol.ACTION:
			_handle_action(sender, message.get("action", {}))
		Protocol.CHAT_SEND:
			_handle_chat(sender, message)
		Protocol.REMATCH_REQUEST:
			_handle_rematch_request(sender)
		Protocol.REMATCH_CONFIRM:
			_handle_rematch_confirm(sender, int(message.get("target_score", 0)))
		_:
			_send_error(sender, "未知请求")

func _create_room(sender: int, target_score: int) -> void:
	if peer_rooms.has(sender):
		_send_error(sender, "你已经在房间中")
		return
	if not target_score in [1500, 2500, 4000, 6000]:
		_send_error(sender, "目标分数无效")
		return
	var code := _new_room_code()
	var session: GameSession = Session.new(target_score, session_seed)
	rooms[code] = {"players": [sender], "session": session, "rematch_players": []}
	peer_rooms[sender] = code
	_bind_session(code, session)
	_send(sender, {"type": Protocol.ROOM_CREATED, "room_code": code, "player_index": 0})

func _join_room(sender: int, code: String) -> void:
	if peer_rooms.has(sender):
		_send_error(sender, "你已经在房间中")
		return
	if not rooms.has(code):
		_send_error(sender, "房间不存在")
		return
	var room: Dictionary = rooms[code]
	var players: Array = room["players"]
	if players.size() >= 2:
		_send_error(sender, "房间已满")
		return
	players.append(sender)
	peer_rooms[sender] = code
	_send(sender, {"type": Protocol.ROOM_JOINED, "room_code": code, "player_index": 1})
	var session: GameSession = room["session"]
	session.current_player = rng.randi_range(0, 1)
	_broadcast(code, {"type": Protocol.ROOM_READY, "snapshot": Protocol.snapshot_to_dictionary(session.get_snapshot())})
	call_deferred("_roll_room", code)

func _handle_action(sender: int, action_data: Dictionary) -> void:
	if not peer_rooms.has(sender):
		_send_error(sender, "你不在对局房间中")
		return
	var code: String = peer_rooms[sender]
	if not rooms.has(code):
		_send_error(sender, "房间已关闭")
		return
	var room: Dictionary = rooms[code]
	var players: Array = room["players"]
	var player_index := players.find(sender)
	var session: GameSession = room["session"]
	if player_index != session.current_player:
		_send_error(sender, "现在不是你的回合")
		return
	var action := Protocol.action_from_dictionary(action_data)
	if action.type == GameAction.Type.ROLL:
		_send_error(sender, "掷骰由服务器控制")
		return
	if not session.apply_action(action):
		_send_error(sender, "当前操作无效")
		return
	if action.type == GameAction.Type.BANK and session.phase != GameSession.Phase.GAME_OVER:
		_roll_room_after_delay(code, session, 0.65)

func _handle_chat(sender: int, message: Dictionary) -> void:
	if not peer_rooms.has(sender):
		_send_error(sender, "你不在对局房间中")
		return
	var code: String = peer_rooms[sender]
	if not rooms.has(code):
		_send_error(sender, "房间已关闭")
		return
	var room: Dictionary = rooms[code]
	var players: Array = room["players"]
	var player_index := players.find(sender)
	if players.size() != 2 or player_index < 0:
		_send_error(sender, "对手尚未加入")
		return
	var session: GameSession = room["session"]
	if session.phase == GameSession.Phase.GAME_OVER:
		_send_error(sender, "对局已经结束")
		return
	var kind := String(message.get("kind", ""))
	var outgoing := {
		"type": Protocol.CHAT_MESSAGE,
		"player_index": player_index,
		"kind": kind,
		"text": "",
		"sticker_id": "",
	}
	if kind == Protocol.CHAT_KIND_TEXT:
		var text := String(message.get("text", "")).strip_edges()
		if text.is_empty() or text.length() > 40:
			_send_error(sender, "聊天文字必须为1至40个字符")
			return
		outgoing["text"] = text
	elif kind == Protocol.CHAT_KIND_STICKER:
		var sticker_id := String(message.get("sticker_id", ""))
		if not sticker_id in Protocol.CHAT_STICKER_IDS:
			_send_error(sender, "表情不存在")
			return
		outgoing["sticker_id"] = sticker_id
	else:
		_send_error(sender, "聊天消息类型无效")
		return
	_broadcast(code, outgoing)

func _handle_rematch_request(sender: int) -> void:
	if not peer_rooms.has(sender):
		_send_error(sender, "你不在对局房间中")
		return
	var code: String = peer_rooms[sender]
	if not rooms.has(code):
		_send_error(sender, "房间已关闭")
		return
	var room: Dictionary = rooms[code]
	var players: Array = room["players"]
	var player_index := players.find(sender)
	var session: GameSession = room["session"]
	if players.size() != 2 or player_index < 0:
		_send_error(sender, "对方已退出")
		return
	if session.phase != GameSession.Phase.GAME_OVER:
		_send_error(sender, "当前对局尚未结束")
		return
	var rematch_players: Array = room["rematch_players"]
	if not rematch_players.has(player_index):
		rematch_players.append(player_index)
	if rematch_players.size() < 2:
		_send(sender, {"type": Protocol.REMATCH_WAITING})
	else:
		_broadcast(code, {"type": Protocol.REMATCH_CHOOSE_TARGET})

func _handle_rematch_confirm(sender: int, target_score: int) -> void:
	if not peer_rooms.has(sender):
		_send_error(sender, "你不在对局房间中")
		return
	var code: String = peer_rooms[sender]
	if not rooms.has(code):
		_send_error(sender, "房间已关闭")
		return
	var room: Dictionary = rooms[code]
	var players: Array = room["players"]
	if players.find(sender) != 0:
		_send_error(sender, "只有房主可以选择目标分数")
		return
	var session: GameSession = room["session"]
	if session.phase != GameSession.Phase.GAME_OVER or room["rematch_players"].size() != 2:
		_send_error(sender, "双方尚未确认再来一局")
		return
	if not target_score in [1500, 2500, 4000, 6000]:
		_send_error(sender, "目标分数无效")
		return
	var new_session: GameSession = Session.new(target_score, session_seed)
	new_session.current_player = rng.randi_range(0, 1)
	room["session"] = new_session
	room["rematch_players"] = []
	_bind_session(code, new_session)
	_broadcast(code, {"type": Protocol.REMATCH_STARTED, "snapshot": Protocol.snapshot_to_dictionary(new_session.get_snapshot())})
	call_deferred("_roll_room", code)

func _bind_session(code: String, session: GameSession) -> void:
	session.state_changed.connect(_on_session_state.bind(code))
	session.rolled.connect(_on_session_rolled.bind(code))
	session.busted.connect(_on_session_busted.bind(code))
	session.hot_dice.connect(_on_session_hot_dice.bind(code))
	session.game_finished.connect(_on_session_finished.bind(code))

func _on_session_state(snapshot: GameSnapshot, code: String) -> void:
	_broadcast(code, {"type": Protocol.SNAPSHOT, "snapshot": Protocol.snapshot_to_dictionary(snapshot)})

func _on_session_rolled(values: Array[int], code: String) -> void:
	_broadcast(code, {"type": Protocol.ROLLED, "values": values})

func _on_session_busted(player_index: int, code: String) -> void:
	_broadcast(code, {"type": Protocol.BUSTED, "player_index": player_index})
	if rooms.has(code):
		var session: GameSession = rooms[code]["session"]
		_resolve_bust_after_delay(code, session)

func _on_session_hot_dice(player_index: int, code: String) -> void:
	_broadcast(code, {"type": Protocol.HOT_DICE, "player_index": player_index})

func _on_session_finished(winner_index: int, code: String) -> void:
	if rooms.has(code):
		rooms[code]["rematch_players"] = []
	_broadcast(code, {"type": Protocol.GAME_FINISHED, "winner_index": winner_index})

func _resolve_bust_after_delay(code: String, expected_session: GameSession) -> void:
	await get_tree().create_timer(3.0).timeout
	if not _room_has_session(code, expected_session):
		return
	expected_session.resolve_bust()
	await get_tree().create_timer(0.55).timeout
	if _room_has_session(code, expected_session):
		_roll_room(code)

func _roll_room_after_delay(code: String, expected_session: GameSession, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if _room_has_session(code, expected_session):
		_roll_room(code)

func _roll_room(code: String) -> void:
	if not rooms.has(code):
		return
	var room: Dictionary = rooms[code]
	if room["players"].size() != 2:
		return
	var session: GameSession = room["session"]
	if session.phase == GameSession.Phase.AWAITING_ROLL:
		session.apply_action(Action.roll())

func _room_has_session(code: String, expected_session: GameSession) -> bool:
	return rooms.has(code) and rooms[code]["session"] == expected_session

func _on_peer_disconnected(id: int) -> void:
	if not peer_rooms.has(id):
		return
	var code: String = peer_rooms[id]
	peer_rooms.erase(id)
	if not rooms.has(code):
		return
	var players: Array = rooms[code]["players"]
	for other_id in players:
		peer_rooms.erase(other_id)
		if other_id != id:
			_send(other_id, {"type": Protocol.OPPONENT_LEFT})
	rooms.erase(code)

func _new_room_code() -> String:
	const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	while true:
		var code := ""
		for index in range(6):
			code += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
		if not rooms.has(code):
			return code
	return ""

func _broadcast(code: String, message: Dictionary) -> void:
	if not rooms.has(code):
		return
	for id in rooms[code]["players"]:
		_send(id, message)

func _send_error(id: int, message: String) -> void:
	_send(id, {"type": Protocol.ERROR, "message": message})

func _send(id: int, message: Dictionary) -> void:
	if peer == null:
		return
	peer.set_target_peer(id)
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())

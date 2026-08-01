class_name NetworkClient
extends Node

const DEFAULT_SERVER_URL := "ws://121.196.201.193:9080"

signal connected
signal disconnected
signal room_assigned(room_code: String, player_index: int)
signal room_ready(snapshot: GameSnapshot)
signal snapshot_received(snapshot: GameSnapshot)
signal rolled(values: Array[int])
signal busted(player_index: int)
signal hot_dice(player_index: int)
signal game_finished(winner_index: int)
signal opponent_left
signal server_error(message: String)

const Protocol = preload("res://scripts/network/network_protocol.gd")

var peer: WebSocketMultiplayerPeer
var is_connected := false

func connect_to_server(url: String) -> Error:
	disconnect_from_server()
	peer = WebSocketMultiplayerPeer.new()
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	var error := peer.create_client(url)
	if error != OK:
		peer = null
	return error

func disconnect_from_server() -> void:
	if peer != null:
		peer.close()
	peer = null
	is_connected = false

func create_room(target_score: int) -> void:
	_send({"type": Protocol.CREATE_ROOM, "target_score": target_score})

func join_room(room_code: String) -> void:
	_send({"type": Protocol.JOIN_ROOM, "room_code": room_code.strip_edges().to_upper()})

func send_action(action: GameAction) -> void:
	_send({"type": Protocol.ACTION, "action": Protocol.action_to_dictionary(action)})

func _process(_delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	while peer != null and peer.get_available_packet_count() > 0:
		var text := peer.get_packet().get_string_from_utf8()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			_handle_message(parsed)

func _send(message: Dictionary) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		server_error.emit("尚未连接服务器")
		return
	peer.set_target_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())

func _handle_message(message: Dictionary) -> void:
	match String(message.get("type", "")):
		Protocol.ROOM_CREATED, Protocol.ROOM_JOINED:
			room_assigned.emit(String(message.get("room_code", "")), int(message.get("player_index", 0)))
		Protocol.ROOM_READY:
			room_ready.emit(Protocol.snapshot_from_dictionary(message.get("snapshot", {})))
		Protocol.SNAPSHOT:
			snapshot_received.emit(Protocol.snapshot_from_dictionary(message.get("snapshot", {})))
		Protocol.ROLLED:
			rolled.emit(Protocol._int_array(message.get("values", [])))
		Protocol.BUSTED:
			busted.emit(int(message.get("player_index", -1)))
		Protocol.HOT_DICE:
			hot_dice.emit(int(message.get("player_index", -1)))
		Protocol.GAME_FINISHED:
			game_finished.emit(int(message.get("winner_index", -1)))
		Protocol.OPPONENT_LEFT:
			opponent_left.emit()
		Protocol.ERROR:
			server_error.emit(String(message.get("message", "服务器返回错误")))

func _on_peer_connected(id: int) -> void:
	if id == MultiplayerPeer.TARGET_PEER_SERVER and not is_connected:
		is_connected = true
		connected.emit()

func _on_peer_disconnected(id: int) -> void:
	if id == MultiplayerPeer.TARGET_PEER_SERVER:
		is_connected = false
		disconnected.emit()

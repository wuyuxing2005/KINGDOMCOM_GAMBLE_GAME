extends SceneTree

const Server = preload("res://scripts/network/multiplayer_server.gd")
const Client = preload("res://scripts/network/network_client.gd")
const Protocol = preload("res://scripts/network/network_protocol.gd")

var host: NetworkClient
var guest: NetworkClient
var room_code := ""
var ready_count := 0
var host_messages: Array[Dictionary] = []
var guest_messages: Array[Dictionary] = []
var host_errors: Array[String] = []
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var server: MedievalDiceServer
	var server_url := _get_remote_url()
	if server_url.is_empty():
		server_url = "ws://127.0.0.1:19082"
		server = Server.new()
		root.add_child(server)
		server.session_seed = 24680
		if server.start(19082, "127.0.0.1") != OK:
			_fail("聊天测试服务器启动失败")
			_finish(server)
			return
	host = Client.new()
	guest = Client.new()
	root.add_child(host)
	root.add_child(guest)
	host.room_assigned.connect(func(code: String, _index: int) -> void: room_code = code)
	host.room_ready.connect(func(_snapshot: GameSnapshot) -> void: ready_count += 1)
	guest.room_ready.connect(func(_snapshot: GameSnapshot) -> void: ready_count += 1)
	host.chat_received.connect(func(player_index: int, kind: String, text: String, sticker_id: String) -> void:
		host_messages.append({"player_index": player_index, "kind": kind, "text": text, "sticker_id": sticker_id})
	)
	guest.chat_received.connect(func(player_index: int, kind: String, text: String, sticker_id: String) -> void:
		guest_messages.append({"player_index": player_index, "kind": kind, "text": text, "sticker_id": sticker_id})
	)
	host.server_error.connect(func(message: String) -> void: host_errors.append(message))

	host.connect_to_server(server_url)
	if not await _wait_until(func() -> bool: return host.is_connected):
		_fail("房主连接超时")
		_finish(server)
		return
	host.create_room(1500)
	if not await _wait_until(func() -> bool: return not room_code.is_empty()):
		_fail("创建聊天测试房间超时")
		_finish(server)
		return
	guest.connect_to_server(server_url)
	if not await _wait_until(func() -> bool: return guest.is_connected):
		_fail("客方连接超时")
		_finish(server)
		return
	guest.join_room(room_code)
	if not await _wait_until(func() -> bool: return ready_count == 2):
		_fail("双端未进入对局")
		_finish(server)
		return

	host.send_chat_text("  你好，对手！  ")
	if not await _wait_until(func() -> bool: return host_messages.size() == 1 and guest_messages.size() == 1):
		_fail("文字消息未广播到双方")
	else:
		_assert_message(host_messages[0], 0, Protocol.CHAT_KIND_TEXT, "你好，对手！", "")
		_assert_message(guest_messages[0], 0, Protocol.CHAT_KIND_TEXT, "你好，对手！", "")

	for sticker_id in Protocol.CHAT_STICKER_IDS:
		guest.send_chat_sticker(sticker_id)
		var expected_count := host_messages.size() + 1
		if not await _wait_until(func() -> bool: return host_messages.size() == expected_count and guest_messages.size() == expected_count):
			_fail("表情未广播：%s" % sticker_id)
			break
		_assert_message(host_messages[-1], 1, Protocol.CHAT_KIND_STICKER, "", sticker_id)

	host.send_chat_text("")
	host.send_chat_text("这是一条超过四十个字符的聊天消息，用来确认服务器能够拒绝过长内容而不是继续广播出去。")
	host.send_chat_sticker("missing_sticker")
	if not await _wait_until(func() -> bool: return host_errors.size() == 3):
		_fail("无效聊天消息未被服务器拒绝")
	if host_messages.size() != 7 or guest_messages.size() != 7:
		_fail("无效聊天消息被错误广播")

	if failures == 0:
		print("PASS: 联机文字、六个表情、发送方标记和输入校验测试通过")
	_finish(server)

func _assert_message(message: Dictionary, player_index: int, kind: String, text: String, sticker_id: String) -> void:
	if message.get("player_index") != player_index or message.get("kind") != kind or message.get("text") != text or message.get("sticker_id") != sticker_id:
		_fail("聊天消息内容不一致：%s" % message)

func _wait_until(predicate: Callable, seconds: float = 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return false

func _fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)

func _get_remote_url() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--remote-url="):
			return argument.trim_prefix("--remote-url=")
	return ""

func _finish(server: MedievalDiceServer) -> void:
	if host != null:
		host.disconnect_from_server()
	if guest != null:
		guest.disconnect_from_server()
	if server != null:
		server.stop()
	quit(1 if failures > 0 else 0)

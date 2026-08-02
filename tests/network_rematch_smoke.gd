extends SceneTree

const Server = preload("res://scripts/network/multiplayer_server.gd")
const Client = preload("res://scripts/network/network_client.gd")

var server: MedievalDiceServer
var host: NetworkClient
var guest: NetworkClient
var room_code := ""
var ready_count := 0
var choose_target_count := 0
var rematch_started_count := 0
var host_waiting_count := 0
var host_snapshot: GameSnapshot
var guest_snapshot: GameSnapshot
var host_rematch_snapshot: GameSnapshot
var guest_rematch_snapshot: GameSnapshot
var guest_error := ""
var host_opponent_left := false
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	server = Server.new()
	root.add_child(server)
	server.session_seed = 24680
	if server.start(19081, "127.0.0.1") != OK:
		_fail("服务器未能监听重赛测试端口")
		_finish()
		return
	host = Client.new()
	guest = Client.new()
	root.add_child(host)
	root.add_child(guest)
	host.room_assigned.connect(func(code: String, _index: int) -> void: room_code = code)
	host.room_ready.connect(func(_snapshot: GameSnapshot) -> void: ready_count += 1)
	guest.room_ready.connect(func(_snapshot: GameSnapshot) -> void: ready_count += 1)
	host.snapshot_received.connect(func(snapshot: GameSnapshot) -> void: host_snapshot = snapshot)
	guest.snapshot_received.connect(func(snapshot: GameSnapshot) -> void: guest_snapshot = snapshot)
	host.rematch_waiting.connect(func() -> void: host_waiting_count += 1)
	host.rematch_choose_target.connect(func() -> void: choose_target_count += 1)
	guest.rematch_choose_target.connect(func() -> void: choose_target_count += 1)
	host.rematch_started.connect(func(snapshot: GameSnapshot) -> void:
		host_rematch_snapshot = snapshot
		rematch_started_count += 1
	)
	guest.rematch_started.connect(func(snapshot: GameSnapshot) -> void:
		guest_rematch_snapshot = snapshot
		rematch_started_count += 1
	)
	guest.server_error.connect(func(message: String) -> void: guest_error = message)
	host.opponent_left.connect(func() -> void: host_opponent_left = true)

	host.connect_to_server("ws://127.0.0.1:19081")
	if not await _wait_until(func() -> bool: return host.is_connected):
		_fail("房主连接超时")
		_finish()
		return
	host.create_room(1500)
	if not await _wait_until(func() -> bool: return not room_code.is_empty()):
		_fail("创建房间超时")
		_finish()
		return
	guest.connect_to_server("ws://127.0.0.1:19081")
	if not await _wait_until(func() -> bool: return guest.is_connected):
		_fail("客方连接超时")
		_finish()
		return
	guest.join_room(room_code)
	if not await _wait_until(func() -> bool: return ready_count == 2 and host_snapshot != null and guest_snapshot != null):
		_fail("初始对局未同步")
		_finish()
		return

	_force_game_over()
	if not await _wait_until(func() -> bool: return host_snapshot.phase == GameSession.Phase.GAME_OVER and guest_snapshot.phase == GameSession.Phase.GAME_OVER):
		_fail("结束状态未同步")
		_finish()
		return
	guest.confirm_rematch(6000)
	if not await _wait_until(func() -> bool: return guest_error == "只有房主可以选择目标分数"):
		_fail("客方提交目标分数未被拒绝")
	host.request_rematch()
	if not await _wait_until(func() -> bool: return host_waiting_count == 1):
		_fail("首位确认者未进入等待状态")
	if choose_target_count != 0:
		_fail("单方确认时提前进入了选分阶段")
	var old_session: GameSession = server.rooms[room_code]["session"]
	guest.request_rematch()
	if not await _wait_until(func() -> bool: return choose_target_count == 2):
		_fail("双方确认后未进入房主选分阶段")
	if server.rooms[room_code]["session"] != old_session:
		_fail("房主确认目标前服务器提前开始了新局")
	host.confirm_rematch(2500)
	if not await _wait_until(func() -> bool: return rematch_started_count == 2):
		_fail("房主确认后双方未收到重赛开始消息")
	if host_rematch_snapshot.target_score != 2500 or guest_rematch_snapshot.target_score != 2500:
		_fail("新目标分数未同步")
	if host_rematch_snapshot.scores != [0, 0] or guest_rematch_snapshot.scores != [0, 0]:
		_fail("新局比分未清零")
	if host_rematch_snapshot.current_player not in [0, 1] or host_rematch_snapshot.current_player != guest_rematch_snapshot.current_player:
		_fail("新局随机先手未同步")
	if server.rooms[room_code]["session"] == old_session:
		_fail("服务器未替换为新的对局状态")

	_force_game_over()
	host.request_rematch()
	guest.request_rematch()
	if not await _wait_until(func() -> bool: return choose_target_count == 4):
		_fail("第二次重赛未进入选分阶段")
	host.confirm_rematch(6000)
	if not await _wait_until(func() -> bool: return rematch_started_count == 4 and host_rematch_snapshot.target_score == 6000):
		_fail("连续重赛未使用新的目标分数")

	_force_game_over()
	guest.disconnect_from_server()
	if not await _wait_until(func() -> bool: return host_opponent_left):
		_fail("结束界面退出未通知另一方")
	if failures == 0:
		print("PASS: 双方确认、房主选分、连续重赛与结束后退出通知测试通过")
	_finish()

func _force_game_over() -> void:
	var active_session: GameSession = server.rooms[room_code]["session"]
	active_session.scores.assign([active_session.target_score, 0])
	active_session.winner = 0
	active_session.phase = GameSession.Phase.GAME_OVER
	active_session._emit_state()
	server._on_session_finished(0, room_code)

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

func _finish() -> void:
	if host != null:
		host.disconnect_from_server()
	if guest != null:
		guest.disconnect_from_server()
	if server != null:
		server.stop()
	quit(1 if failures > 0 else 0)

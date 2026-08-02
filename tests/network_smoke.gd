extends SceneTree

const Server = preload("res://scripts/network/multiplayer_server.gd")
const Client = preload("res://scripts/network/network_client.gd")
const Action = preload("res://scripts/core/game_action.gd")

var host: NetworkClient
var guest: NetworkClient
var room_code := ""
var ready_count := 0
var host_snapshot: GameSnapshot
var guest_snapshot: GameSnapshot
var failures := 0
var expected_starting_player := -1
var actual_starting_player := -1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var server: MedievalDiceServer
	var server_url := _get_remote_url()
	if server_url.is_empty():
		server_url = "ws://127.0.0.1:19080"
		server = Server.new()
		root.add_child(server)
		server.session_seed = 12345
		if server.start(19080, "127.0.0.1") != OK:
			_fail("服务器未能监听测试端口")
			_finish(server)
			return
		server.rng.seed = 12345
		var expected_rng := RandomNumberGenerator.new()
		expected_rng.seed = 12345
		for index in range(6):
			expected_rng.randi_range(0, 31)
		expected_starting_player = expected_rng.randi_range(0, 1)
	host = Client.new()
	guest = Client.new()
	root.add_child(host)
	root.add_child(guest)
	host.room_assigned.connect(func(code: String, _index: int) -> void: room_code = code)
	host.room_ready.connect(func(_snapshot: GameSnapshot) -> void: ready_count += 1)
	guest.room_ready.connect(func(_snapshot: GameSnapshot) -> void: ready_count += 1)
	host.snapshot_received.connect(func(snapshot: GameSnapshot) -> void: host_snapshot = snapshot)
	guest.snapshot_received.connect(func(snapshot: GameSnapshot) -> void: guest_snapshot = snapshot)

	host.connect_to_server(server_url)
	if not await _wait_until(func() -> bool: return host.is_connected):
		_fail("创建者连接超时")
		_finish(server)
		return
	host.create_room(1500)
	if not await _wait_until(func() -> bool: return not room_code.is_empty()):
		_fail("创建房间超时")
		_finish(server)
		return
	guest.connect_to_server(server_url)
	if not await _wait_until(func() -> bool: return guest.is_connected):
		_fail("加入者连接超时")
		_finish(server)
		return
	guest.join_room(room_code)
	if not await _wait_until(func() -> bool: return ready_count == 2):
		_fail("双端未收到房间开始消息")
		_finish(server)
		return
	if not await _wait_until(func() -> bool: return host_snapshot != null and guest_snapshot != null and host_snapshot.phase == GameSession.Phase.AWAITING_SELECTION):
		_fail("服务器未生成首轮骰子")
		_finish(server)
		return
	if host_snapshot.target_score != 1500 or guest_snapshot.target_score != 1500:
		_fail("房主选择的目标分数未同步到双方")
	if expected_starting_player >= 0 and host_snapshot.current_player != expected_starting_player:
		_fail("服务器未按随机结果设置先手玩家")
	actual_starting_player = host_snapshot.current_player
	if host_snapshot.current_roll != guest_snapshot.current_roll:
		_fail("双端骰子点数不一致")
	var subsets := ScoringRules.get_scoring_subsets(host_snapshot.current_roll)
	if subsets.is_empty():
		_fail("首轮快照意外为爆骰状态")
		_finish(server)
		return
	var acting_client: NetworkClient = host if host_snapshot.current_player == 0 else guest
	var indices: Array[int] = subsets[0]["indices"]
	acting_client.send_action(Action.set_selection(indices))
	if not await _wait_until(func() -> bool: return host_snapshot.selected_score > 0 and guest_snapshot.selected_score == host_snapshot.selected_score):
		_fail("选择未在双端同步")
		_finish(server)
		return
	acting_client.send_action(Action.bank())
	if not await _wait_until(func() -> bool: return host_snapshot.scores[0] + host_snapshot.scores[1] > 0 and host_snapshot.scores == guest_snapshot.scores):
		_fail("停手得分未在双端同步")
	else:
		print("PASS: 房间创建、加入、随机先手、权威掷骰、选择和结算已通过双客户端测试（先手玩家 %d）" % actual_starting_player)
	_finish(server)

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
	host.disconnect_from_server()
	guest.disconnect_from_server()
	if server != null:
		server.stop()
	quit(1 if failures > 0 else 0)

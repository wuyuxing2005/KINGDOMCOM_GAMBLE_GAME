extends SceneTree

const Server = preload("res://scripts/network/multiplayer_server.gd")
const Client = preload("res://scripts/network/network_client.gd")
const Action = preload("res://scripts/core/game_action.gd")

var server: MedievalDiceServer
var host: NetworkClient
var guest: NetworkClient
var room_code := ""
var ready_count := 0
var snapshot_version := 0
var host_snapshot: GameSnapshot
var guest_snapshot: GameSnapshot
var winner := -1
var choose_target_count := 0
var rematch_started_count := 0
var host_rematch_snapshot: GameSnapshot
var guest_rematch_snapshot: GameSnapshot
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var server_url := _get_remote_url()
	if server_url.is_empty():
		server_url = "ws://127.0.0.1:19082"
		server = Server.new()
		root.add_child(server)
		if server.start(19082, "127.0.0.1") != OK:
			_fail("服务器未能监听完整重赛测试端口")
			_finish()
			return
	host = Client.new()
	guest = Client.new()
	root.add_child(host)
	root.add_child(guest)
	host.room_assigned.connect(func(code: String, _index: int) -> void: room_code = code)
	host.room_ready.connect(func(snapshot: GameSnapshot) -> void:
		host_snapshot = snapshot
		ready_count += 1
	)
	guest.room_ready.connect(func(snapshot: GameSnapshot) -> void:
		guest_snapshot = snapshot
		ready_count += 1
	)
	host.snapshot_received.connect(func(snapshot: GameSnapshot) -> void:
		host_snapshot = snapshot
		snapshot_version += 1
	)
	guest.snapshot_received.connect(func(snapshot: GameSnapshot) -> void: guest_snapshot = snapshot)
	host.game_finished.connect(func(player_index: int) -> void: winner = player_index)
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

	host.connect_to_server(server_url)
	if not await _wait_until(func() -> bool: return host.is_connected):
		_fail("房主连接超时")
		_finish()
		return
	host.create_room(1500)
	if not await _wait_until(func() -> bool: return not room_code.is_empty()):
		_fail("创建房间超时")
		_finish()
		return
	guest.connect_to_server(server_url)
	if not await _wait_until(func() -> bool: return guest.is_connected):
		_fail("客方连接超时")
		_finish()
		return
	guest.join_room(room_code)
	if not await _wait_until(func() -> bool: return ready_count == 2 and host_snapshot != null and guest_snapshot != null):
		_fail("初始房间未开始")
		_finish()
		return
	if not await _play_until_game_over():
		_finish()
		return
	host.request_rematch()
	guest.request_rematch()
	if not await _wait_until(func() -> bool: return choose_target_count == 2):
		_fail("公网双方确认后未进入房主选分阶段")
		_finish()
		return
	host.confirm_rematch(2500)
	if not await _wait_until(func() -> bool: return rematch_started_count == 2):
		_fail("公网重赛未在双端开始")
		_finish()
		return
	if host_rematch_snapshot.target_score != 2500 or guest_rematch_snapshot.target_score != 2500:
		_fail("公网重赛目标分数不同步")
	if host_rematch_snapshot.scores != [0, 0] or guest_rematch_snapshot.scores != [0, 0]:
		_fail("公网重赛比分未清零")
	if failures == 0:
		print("PASS: 公网完整对局、双方确认、房主选分和重赛开始测试通过")
	_finish()

func _play_until_game_over() -> bool:
	var deadline := Time.get_ticks_msec() + 180000
	while winner < 0 and Time.get_ticks_msec() < deadline:
		if host_snapshot == null or guest_snapshot == null or host_snapshot.phase != guest_snapshot.phase:
			await process_frame
			continue
		if host_snapshot.phase != GameSession.Phase.AWAITING_SELECTION:
			await process_frame
			continue
		var subsets := ScoringRules.get_scoring_subsets(host_snapshot.current_roll)
		if subsets.is_empty():
			await process_frame
			continue
		var best_score := -1
		var best_indices: Array[int] = []
		for subset in subsets:
			if int(subset["score"]) > best_score:
				best_score = int(subset["score"])
				best_indices.assign(subset["indices"])
		var acting_client: NetworkClient = host if host_snapshot.current_player == 0 else guest
		var before_selection := snapshot_version
		acting_client.send_action(Action.set_selection(best_indices))
		if not await _wait_until(func() -> bool: return winner >= 0 or (snapshot_version > before_selection and host_snapshot.selected_score > 0 and guest_snapshot.selected_score == host_snapshot.selected_score), 10.0):
			_fail("自动对局选择同步超时")
			return false
		if winner >= 0:
			break
		var before_bank := snapshot_version
		acting_client.send_action(Action.bank())
		if not await _wait_until(func() -> bool: return winner >= 0 or (snapshot_version > before_bank and host_snapshot.phase != GameSession.Phase.AWAITING_SELECTION), 10.0):
			_fail("自动对局结算同步超时")
			return false
	if winner < 0:
		_fail("自动对局未在时限内结束")
		return false
	return true

func _wait_until(predicate: Callable, seconds: float = 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return false

func _get_remote_url() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--remote-url="):
			return argument.trim_prefix("--remote-url=")
	return ""

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

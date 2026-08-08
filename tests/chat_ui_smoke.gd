extends SceneTree

const Protocol = preload("res://scripts/network/network_protocol.gd")

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var scene = current_scene
	var snapshot := GameSnapshot.new()
	snapshot.target_score = 4000
	snapshot.scores.assign([350, 500])
	snapshot.current_player = 0
	snapshot.phase = GameSession.Phase.AWAITING_SELECTION
	snapshot.current_roll.assign([1, 2, 3, 4, 5, 6])
	scene.local_player_index = 0
	scene._start_network_game(snapshot)
	await process_frame
	if not scene.chat_button.visible or scene.chat_button.disabled:
		_fail("联机对局未显示聊天按钮")
	scene._open_chat()
	if not scene.chat_overlay.visible or scene.chat_input.max_length != 40:
		_fail("聊天面板或40字符限制不正确")
	if scene._can_human_act():
		_fail("聊天面板打开时仍可操作骰子")
	await process_frame
	_capture("res://build/chat-panel-smoke.png")
	scene._close_chat()

	scene._on_chat_received(0, Protocol.CHAT_KIND_TEXT, "你好，对手！", "")
	if not scene.local_chat_bubble.visible or scene.local_chat_text.text != "你好，对手！" or scene.local_chat_sticker.visible:
		_fail("本地文字气泡显示错误")
	var first_time_left: float = scene.local_chat_timer.time_left
	scene._on_chat_received(0, Protocol.CHAT_KIND_STICKER, "", "heart_eyes")
	if not scene.local_chat_sticker.visible or scene.local_chat_text.visible or scene.local_chat_sticker.texture == null:
		_fail("新表情没有替换本地文字")
	if scene.local_chat_timer.time_left < first_time_left:
		_fail("替换消息后计时器没有重置")
	scene._on_chat_received(1, Protocol.CHAT_KIND_STICKER, "", "crying")
	if not scene.opponent_chat_bubble.visible or not scene.local_chat_bubble.visible:
		_fail("双方聊天气泡不能同时显示")
	if not root.get_visible_rect().encloses(scene.opponent_chat_bubble.get_global_rect()):
		_fail("对手聊天气泡不在可见区域内")
	await process_frame
	_capture("res://build/chat-bubbles-smoke.png")

	scene._layout_chat_bubbles(960.0)
	if scene.local_chat_bubble.position.y < 150 or scene.opponent_chat_bubble.position.y < 150:
		_fail("窄屏聊天气泡未移动到分数面板下方")

	await create_timer(6.1).timeout
	if scene.local_chat_bubble.visible or scene.opponent_chat_bubble.visible:
		_fail("聊天气泡未在6秒后消失")

	scene._start_selected_game()
	if scene.chat_button.visible:
		_fail("单人模式错误显示聊天按钮")
	if failures == 0:
		print("PASS: 聊天面板、左右气泡、替换计时、窄屏布局和单人隐藏测试通过")
	quit(1 if failures > 0 else 0)

func _fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)

func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		return
	var image := viewport_texture.get_image()
	if image == null:
		return
	var error := image.save_png(path)
	if error != OK:
		_fail("聊天界面截图失败：%s" % error_string(error))

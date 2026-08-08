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
	var snapshot := _make_snapshot()
	scene.local_player_index = 0
	scene._start_network_game(snapshot)
	await process_frame
	scene.input_locked = false
	if not scene.chat_entry.visible or scene.chat_preview_button.text != "暂无消息，点击查看":
		_fail("联机对局未显示空状态缩略聊天框")
	if scene.chat_preview_button.disabled or scene.quick_sticker_button.disabled:
		_fail("联机聊天入口被错误禁用")

	scene._toggle_sticker_popup()
	if not scene.sticker_popup.visible:
		_fail("快捷表情浮层未打开")
	if not scene._can_human_act():
		_fail("快捷表情浮层错误阻止骰子操作")
	if scene.sticker_popup.get_node("StickerMargin/StickerGrid").get_child_count() != 6:
		_fail("快捷表情浮层不是六项3×2网格")
	await process_frame
	_capture("res://build/chat-sticker-popup-smoke.png")
	scene._send_chat_sticker("smile")
	if scene.sticker_popup.visible:
		_fail("发送快捷表情后浮层未关闭")

	scene._open_chat()
	if not scene.chat_overlay.visible or scene.chat_input.max_length != 40:
		_fail("历史抽屉或40字符限制不正确")
	if scene._can_human_act():
		_fail("历史抽屉打开时仍可操作骰子")
	await process_frame
	_capture("res://build/chat-history-drawer-smoke.png")
	scene.chat_input.text = "抽屉发送测试"
	scene.chat_input.text_submitted.emit(scene.chat_input.text)
	if not scene.chat_input.text.is_empty() or not scene.chat_overlay.visible:
		_fail("Enter发送后输入框未清空或历史抽屉被错误关闭")

	scene._on_chat_received(0, Protocol.CHAT_KIND_TEXT, "你好", "")
	var short_size: Vector2 = scene.local_chat_bubble.size
	if scene.chat_history.size() != 1 or scene.chat_preview_button.text != "你：你好":
		_fail("本地文字未写入历史或缩略框")
	if not _is_white_bubble(scene.local_chat_bubble):
		_fail("即时文字未使用白色圆角气泡")
	scene._on_chat_received(0, Protocol.CHAT_KIND_TEXT, "这是一条用于检查自动换行以及气泡宽高变化的较长聊天消息", "")
	var long_size: Vector2 = scene.local_chat_bubble.size
	if long_size.x <= short_size.x or long_size.x > 308.1 or long_size.y <= short_size.y:
		_fail("长文字气泡未按内容扩展或超过最大宽度")
	scene._on_chat_received(0, Protocol.CHAT_KIND_TEXT, "好", "")
	if scene.local_chat_bubble.size.x >= long_size.x or scene.local_chat_bubble.size.y >= long_size.y:
		_fail("长文字切换为短文字后气泡没有随字体内容缩小")
	scene._on_chat_received(0, Protocol.CHAT_KIND_STICKER, "", "heart_eyes")
	if scene.local_chat_bubble.size != Vector2(120, 120):
		_fail("本地表情气泡尺寸错误")
	scene._on_chat_received(0, Protocol.CHAT_KIND_TEXT, "你好", "")
	if scene.local_chat_bubble.size.x >= 120.0 or scene.local_chat_bubble.size.y >= 120.0:
		_fail("表情切换为短文字后仍保留表情气泡尺寸")
	scene._on_chat_received(1, Protocol.CHAT_KIND_STICKER, "", "crying")
	if scene.chat_preview_button.text != "对手：" or scene.chat_preview_button.icon == null:
		_fail("对手表情未显示在缩略聊天框")
	if scene.opponent_chat_bubble.size != Vector2(120, 120) or not scene.opponent_chat_sticker.visible:
		_fail("表情未使用贴合图片的120×120白色气泡")
	if scene.chat_history.size() != 6 or scene.chat_history_list.get_child_count() != 7:
		_fail("完整历史未按接收顺序保留六条消息")
	if not scene.local_chat_bubble.visible or not scene.opponent_chat_bubble.visible:
		_fail("双方即时气泡不能同时显示")
	if scene.local_chat_timer.time_left < 5.8 or scene.opponent_chat_timer.time_left < 5.8:
		_fail("即时消息没有使用6秒独立计时")
	await process_frame
	_capture("res://build/chat-history-messages-smoke.png")

	scene._close_chat()
	await process_frame
	_capture("res://build/chat-wechat-bubbles-smoke.png")
	scene._layout_chat_bubbles(960.0)
	if scene.local_chat_bubble.position.y < 330.0 or scene.opponent_chat_bubble.position.y < 260.0:
		_fail("4:3窄屏气泡未避开计分板和缩略聊天框")
	root.size = Vector2i(960, 720)
	await process_frame
	_capture("res://build/chat-layout-4x3-smoke.png")
	root.size = Vector2i(1600, 720)
	scene._layout_chat_bubbles(1600.0)
	await process_frame
	_capture("res://build/chat-layout-20x9-smoke.png")

	scene._start_network_game(_make_snapshot())
	await process_frame
	if not scene.chat_history.is_empty() or scene.chat_preview_button.text != "暂无消息，点击查看":
		_fail("重赛开始后未清空当前局聊天历史")
	scene._start_selected_game()
	if scene.chat_entry.visible:
		_fail("单人模式错误显示聊天入口")
	if failures == 0:
		print("PASS: 缩略历史、侧边抽屉、非模态表情、动态白色气泡和当前局清理测试通过")
	quit(1 if failures > 0 else 0)

func _make_snapshot() -> GameSnapshot:
	var snapshot := GameSnapshot.new()
	snapshot.target_score = 4000
	snapshot.scores.assign([350, 500])
	snapshot.current_player = 0
	snapshot.phase = GameSession.Phase.AWAITING_SELECTION
	snapshot.current_roll.assign([1, 2, 3, 4, 5, 6])
	return snapshot

func _is_white_bubble(bubble: Panel) -> bool:
	var style := bubble.get_theme_stylebox("panel") as StyleBoxFlat
	return style != null and style.bg_color.r > 0.95 and style.bg_color.g > 0.95 and style.bg_color.b > 0.95 and style.corner_radius_top_left >= 12

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

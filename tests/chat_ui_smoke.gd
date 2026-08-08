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
	if not scene.chat_entry.visible or scene.chat_preview_label.text != "暂无消息，点击查看":
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
	if not scene.chat_overlay.visible or not (scene.chat_input is TextEdit):
		_fail("历史抽屉或动态多行输入框未正确创建")
	if scene._can_human_act():
		_fail("历史抽屉打开时仍可操作骰子")
	await process_frame
	var empty_input_width: float = scene.chat_input.size.x
	_capture("res://build/chat-history-drawer-smoke.png")
	scene.chat_input.text = "短"
	scene._on_chat_input_changed()
	var short_input_size: Vector2 = scene.chat_input.size
	scene.chat_input.text = "测".repeat(40)
	scene._on_chat_input_changed()
	var full_input_size: Vector2 = scene.chat_input.size
	if scene.chat_input.text.length() != 40 or not is_equal_approx(empty_input_width, 300.0):
		_fail("输入框没有从空状态开始保持满宽")
	if not is_equal_approx(short_input_size.x, empty_input_width) or not is_equal_approx(full_input_size.x, empty_input_width) or full_input_size.y <= short_input_size.y:
		_fail("输入框宽度发生变化或高度没有随40字内容增加")
	await process_frame
	if scene.chat_input.get_v_scroll_bar().visible:
		_fail("输入框仍显示上下滚动条")
	_capture("res://build/chat-input-40-smoke.png")
	scene.chat_input.text = "字".repeat(45)
	scene._on_chat_input_changed()
	if scene.chat_input.text.length() != 40:
		_fail("输入框没有在40字符处截断")
	scene.chat_input.text = "抽屉发送测试"
	var enter_event := InputEventKey.new()
	enter_event.pressed = true
	enter_event.keycode = KEY_ENTER
	scene.chat_input.gui_input.emit(enter_event)
	if not scene.chat_input.text.is_empty() or not scene.chat_overlay.visible:
		_fail("Enter发送后输入框未清空或历史抽屉被错误关闭")

	scene._on_chat_received(0, Protocol.CHAT_KIND_TEXT, "你好", "")
	var short_size: Vector2 = scene.local_chat_bubble.size
	if scene.chat_history.size() != 1 or scene.chat_preview_label.text != "你：你好":
		_fail("本地文字未写入历史或缩略框")
	if not _is_white_bubble(scene.local_chat_bubble):
		_fail("即时文字未使用白色圆角气泡")
	var full_text := "聊".repeat(40)
	scene._on_chat_received(0, Protocol.CHAT_KIND_TEXT, full_text, "")
	var long_size: Vector2 = scene.local_chat_bubble.size
	if scene.local_chat_text.text != full_text or long_size.x <= short_size.x or long_size.x > 508.1 or long_size.y <= short_size.y:
		_fail("40字气泡未完整显示、未按内容扩展或超过最大宽度")
	if scene.local_chat_text.autowrap_mode != TextServer.AUTOWRAP_ARBITRARY:
		_fail("40字气泡未使用逐字符换行")
	await process_frame
	if scene.local_chat_text.get_line_count() < 2 or scene.local_chat_text.get_visible_line_count() < 2:
		_fail("40字气泡没有完整渲染为多行")
	scene._on_chat_received(0, Protocol.CHAT_KIND_TEXT, "好", "")
	if scene.local_chat_bubble.size.x >= long_size.x or scene.local_chat_bubble.size.y >= long_size.y:
		_fail("长文字切换为短文字后气泡没有随字体内容缩小")
	scene._on_chat_received(0, Protocol.CHAT_KIND_STICKER, "", "heart_eyes")
	if scene.local_chat_bubble.size != Vector2(120, 120):
		_fail("本地表情气泡尺寸错误")
	scene._on_chat_received(0, Protocol.CHAT_KIND_TEXT, "你好", "")
	if scene.local_chat_bubble.size.x >= 120.0 or scene.local_chat_bubble.size.y >= 120.0:
		_fail("表情切换为短文字后仍保留表情气泡尺寸")
	scene._on_chat_received(0, Protocol.CHAT_KIND_TEXT, full_text, "")
	scene._on_chat_received(1, Protocol.CHAT_KIND_TEXT, full_text, "")
	var local_rect := Rect2(scene.local_chat_bubble.position, scene.local_chat_bubble.size)
	var opponent_rect := Rect2(scene.opponent_chat_bubble.position, scene.opponent_chat_bubble.size)
	if local_rect.intersects(opponent_rect):
		_fail("双方40字即时气泡发生重叠")
	scene._on_chat_received(1, Protocol.CHAT_KIND_STICKER, "", "crying")
	if scene.chat_preview_label.text != "对手：" or not scene.chat_preview_sticker.visible:
		_fail("对手表情未显示在缩略聊天框")
	if scene.chat_preview_sticker.position.x <= scene.chat_preview_label.position.x + scene.chat_preview_label.size.x:
		_fail("缩略聊天框的表情仍显示在发送者前面")
	if scene.opponent_chat_bubble.size != Vector2(120, 120) or not scene.opponent_chat_sticker.visible:
		_fail("表情未使用贴合图片的120×120白色气泡")
	if scene.chat_history.size() != 8 or scene.chat_history_list.get_child_count() != 9:
		_fail("完整历史未按接收顺序保留八条消息")
	if not scene.local_chat_bubble.visible or not scene.opponent_chat_bubble.visible:
		_fail("双方即时气泡不能同时显示")
	if scene.local_chat_timer.time_left < 5.8 or scene.opponent_chat_timer.time_left < 5.8:
		_fail("即时消息没有使用6秒独立计时")
	await process_frame
	var history_right: float = scene.chat_history_scroll.global_position.x + scene.chat_history_scroll.size.x
	var history_scrollbar: VScrollBar = scene.chat_history_scroll.get_v_scroll_bar()
	if history_scrollbar.visible:
		history_right = history_scrollbar.global_position.x
	for row in scene.chat_history_list.get_children():
		if row == scene.chat_empty_label:
			continue
		for child in row.get_children():
			if child is Panel and child.global_position.x + child.size.x + 6.0 > history_right:
				_fail("历史气泡圆角或阴影仍被右侧滚动条裁剪")
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
	if not scene.chat_history.is_empty() or scene.chat_preview_label.text != "暂无消息，点击查看" or scene.chat_preview_sticker.visible:
		_fail("重赛开始后未清空当前局聊天历史")
	scene._start_selected_game()
	if scene.chat_entry.visible:
		_fail("单人模式错误显示聊天入口")
	if failures == 0:
		print("PASS: 满宽输入框、无内部滚动条、历史气泡安全边距和40字聊天测试通过")
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

extends Node

const Session = preload("res://scripts/core/game_session.gd")
const Action = preload("res://scripts/core/game_action.gd")
const Human = preload("res://scripts/controllers/human_controller.gd")
const AI = preload("res://scripts/controllers/ai_controller.gd")
const Die = preload("res://scripts/ui/die_view.gd")
const Server = preload("res://scripts/network/multiplayer_server.gd")
const Client = preload("res://scripts/network/network_client.gd")
const NetworkProxy = preload("res://scripts/network/network_session_proxy.gd")
const NetworkControl = preload("res://scripts/controllers/network_controller.gd")

const PLAYER_COLOR := Color("2b7898")
const AI_COLOR := Color("a13e2d")
const INK := Color("37271b")
const GOLD := Color("d9ad37")
const DIE_POSITIONS: Array[Vector3] = [
	Vector3(-2.2, 0.62, -0.85),
	Vector3(-0.7, 0.62, -1.15),
	Vector3(0.85, 0.62, -0.82),
	Vector3(2.15, 0.62, -0.22),
	Vector3(-1.25, 0.62, 0.55),
	Vector3(0.55, 0.62, 0.72),
]

var session
var human_controller := Human.new()
var ai_controller := AI.new()
var network_client: NetworkClient
var network_controller: NetworkController
var local_mode := true
var local_player_index := 0
var latest_snapshot: GameSnapshot
var dice_root: Node3D
var held_root: Node3D
var table_camera: Camera3D
var die_views: Array[DieView] = []
var held_views: Array[DieView] = []
var rolling_count := 0
var input_locked := true
var pending_bust := false
var focused_die := 0
var game_generation := 0

var ui_root: Control
var menu_screen: Control
var game_hud: Control
var target_option: OptionButton
var player_title_label: Label
var opponent_title_label: Label
var player_score_label: Label
var ai_score_label: Label
var target_label: Label
var turn_label: Label
var selected_label: Label
var status_label: Label
var roll_again_button: Button
var bank_button: Button
var rules_overlay: Control
var win_overlay: Control
var win_title: Label
var rematch_button: Button
var online_overlay: Control
var online_choice_view: Control
var online_join_view: Control
var online_create_view: Control
var room_code_edit: LineEdit
var online_target_option: OptionButton
var create_room_button: Button
var join_room_button: Button
var created_room_code_button: Button
var created_room_code := ""
var online_status_label: Label
var pending_online_request := ""
var settings_overlay: Control
var settings_notice: Label
var settings_return_button: Button
var settings_menu_button: Button
var music_volume_slider: HSlider
var music_volume_label: Label
var fullscreen_toggle: Button
var background_music: AudioStreamPlayer

var parchment_texture: Texture2D
var main_font: Font

func _ready() -> void:
	if OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_user_args():
		var server := Server.new()
		add_child(server)
		var error := server.start(_get_server_port())
		if error != OK:
			printerr("服务器启动失败：%s" % error_string(error))
			get_tree().quit(1)
		return
	parchment_texture = load("res://assets/ui/parchment_panel.png")
	main_font = load("res://assets/fonts/LXGWWenKai-Regular.ttf")
	_build_audio()
	_build_world()
	_build_ui()
	network_client = Client.new()
	network_client.name = "NetworkClient"
	add_child(network_client)
	network_controller = NetworkControl.new(network_client)
	_bind_network_client()
	human_controller.action_requested.connect(_on_controller_action)
	_show_menu()

func _get_server_port() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			return int(argument.trim_prefix("--port="))
	return 9080

func _input(event: InputEvent) -> void:
	var pointer_position := Vector2.ZERO
	var should_select := false
	if event is InputEventScreenTouch and event.pressed:
		pointer_position = event.position
		should_select = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		pointer_position = event.position
		should_select = true
	if should_select and _can_human_act():
		var touched_die := _pick_die_at_screen(pointer_position)
		if touched_die >= 0:
			focused_die = touched_die
			_toggle_die(touched_die)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("show_rules"):
		_toggle_rules()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("back_to_menu"):
		if settings_overlay.visible:
			_show_menu()
		elif rules_overlay.visible:
			rules_overlay.visible = false
		elif game_hud.visible:
			_show_menu()
		get_viewport().set_input_as_handled()
		return
	if not _can_human_act():
		return
	if event.is_action_pressed("focus_left"):
		_move_focus(-1)
	elif event.is_action_pressed("focus_right"):
		_move_focus(1)
	elif event.is_action_pressed("toggle_die"):
		_toggle_die(focused_die)
	elif event.is_action_pressed("roll_again"):
		_request_roll_again()
	elif event.is_action_pressed("bank_score"):
		_request_bank()
	else:
		return
	get_viewport().set_input_as_handled()

func _build_audio() -> void:
	background_music = AudioStreamPlayer.new()
	background_music.name = "BackgroundMusic"
	background_music.process_mode = Node.PROCESS_MODE_ALWAYS
	var music_stream: AudioStreamMP3 = load("res://assets/music/music.mp3")
	music_stream.loop = true
	background_music.stream = music_stream
	add_child(background_music)
	background_music.play()

func _build_world() -> void:
	var world := Node3D.new()
	world.name = "TableWorld"
	add_child(world)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("160d08")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c38b5c")
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	world.add_child(environment)

	var table := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(34.0, 24.0)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	table.mesh = plane
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/textures/wood_table.png")
	wood.roughness = 0.82
	table.material_override = wood
	world.add_child(table)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -28, 0)
	light.light_color = Color("ffd7a2")
	light.light_energy = 0.72
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 18.0
	world.add_child(light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-3.5, 5.0, 2.5)
	fill.light_color = Color("d18850")
	fill.light_energy = 0.85
	fill.omni_range = 10.0
	fill.shadow_enabled = false
	world.add_child(fill)

	table_camera = Camera3D.new()
	table_camera.name = "TableCamera"
	table_camera.position = Vector3(0, 9.7, 6.4)
	table_camera.fov = 46.0
	table_camera.look_at_from_position(table_camera.position, Vector3(0, 0, -0.15), Vector3.UP)
	table_camera.current = true
	world.add_child(table_camera)

	dice_root = Node3D.new()
	dice_root.name = "ActiveDice"
	world.add_child(dice_root)
	held_root = Node3D.new()
	held_root.name = "HeldDice"
	world.add_child(held_root)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_root)

	_build_menu()
	_build_game_hud()
	_build_rules_overlay()
	_build_online_overlay()
	_build_settings_overlay()
	_build_win_overlay()

func _build_menu() -> void:
	menu_screen = Control.new()
	menu_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(menu_screen)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.0, 0.46)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_screen.add_child(shade)

	var panel := _make_parchment_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-285, -300)
	panel.size = Vector2(570, 600)
	menu_screen.add_child(panel)

	var content := VBoxContainer.new()
	content.position = Vector2(76, 48)
	content.size = Vector2(418, 505)
	content.add_theme_constant_override("separation", 11)
	panel.add_child(content)

	var title := _make_label("中世纪骰局", 48, INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.custom_minimum_size.y = 78
	content.add_child(title)
	var subtitle := _make_label("六骰 · 冒险 · 适时收手", 20, Color("725037"), HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(subtitle)
	content.add_child(_make_label("目标分数", 24, INK, HORIZONTAL_ALIGNMENT_CENTER))
	target_option = OptionButton.new()
	for score in [1500, 2500, 4000, 6000]:
		target_option.add_item(str(score), score)
	target_option.select(2)
	_style_button(target_option, 24)
	target_option.custom_minimum_size = Vector2(0, 58)
	content.add_child(target_option)
	var start_button := Button.new()
	start_button.text = "单人对电脑"
	start_button.custom_minimum_size.y = 62
	_style_button(start_button, 28)
	start_button.pressed.connect(_start_selected_game)
	content.add_child(start_button)
	var online_button := Button.new()
	online_button.text = "联机对战"
	online_button.custom_minimum_size.y = 56
	_style_button(online_button, 25)
	online_button.pressed.connect(_open_online_lobby)
	content.add_child(online_button)
	var settings_button := Button.new()
	settings_button.text = "设置"
	settings_button.custom_minimum_size.y = 48
	_style_button(settings_button, 22)
	settings_button.pressed.connect(_open_menu_settings)
	content.add_child(settings_button)
	var exit_button := Button.new()
	exit_button.text = "退出"
	exit_button.custom_minimum_size.y = 48
	_style_button(exit_button, 22)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	content.add_child(exit_button)

func _build_game_hud() -> void:
	game_hud = Control.new()
	game_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(game_hud)

	var player_panel := _make_parchment_panel()
	player_panel.position = Vector2(20, 18)
	player_panel.size = Vector2(300, 132)
	game_hud.add_child(player_panel)
	player_title_label = _make_label("玩家", 24, PLAYER_COLOR)
	player_title_label.position = Vector2(48, 26)
	player_title_label.size = Vector2(190, 34)
	player_panel.add_child(player_title_label)
	player_score_label = _make_label("0", 42, PLAYER_COLOR)
	player_score_label.position = Vector2(48, 59)
	player_score_label.size = Vector2(200, 50)
	player_panel.add_child(player_score_label)

	var ai_panel := _make_parchment_panel()
	ai_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ai_panel.position = Vector2(-320, 18)
	ai_panel.size = Vector2(300, 132)
	game_hud.add_child(ai_panel)
	opponent_title_label = _make_label("电脑", 24, AI_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	opponent_title_label.position = Vector2(58, 26)
	opponent_title_label.size = Vector2(190, 34)
	ai_panel.add_child(opponent_title_label)
	ai_score_label = _make_label("0", 42, AI_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	ai_score_label.position = Vector2(48, 59)
	ai_score_label.size = Vector2(200, 50)
	ai_panel.add_child(ai_score_label)

	var info_panel := _make_parchment_panel()
	info_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info_panel.position = Vector2(20, -178)
	info_panel.size = Vector2(350, 158)
	game_hud.add_child(info_panel)
	var info := VBoxContainer.new()
	info.position = Vector2(48, 25)
	info.size = Vector2(254, 112)
	info.add_theme_constant_override("separation", 2)
	info_panel.add_child(info)
	target_label = _make_label("目标：4000", 21, INK)
	turn_label = _make_label("本轮：0", 26, INK)
	selected_label = _make_label("选定：0", 23, Color("8e2d22"))
	info.add_child(target_label)
	info.add_child(turn_label)
	info.add_child(selected_label)

	var actions := VBoxContainer.new()
	actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.position = Vector2(-328, -282)
	actions.size = Vector2(300, 262)
	actions.add_theme_constant_override("separation", 10)
	game_hud.add_child(actions)
	roll_again_button = Button.new()
	roll_again_button.text = "计分并再掷" if OS.has_feature("mobile") else "计分并再掷  [F]"
	roll_again_button.custom_minimum_size.y = 58
	_style_button(roll_again_button, 22)
	roll_again_button.pressed.connect(_request_roll_again)
	actions.add_child(roll_again_button)
	bank_button = Button.new()
	bank_button.text = "停手得分" if OS.has_feature("mobile") else "停手得分  [Q]"
	bank_button.custom_minimum_size.y = 58
	_style_button(bank_button, 22)
	bank_button.pressed.connect(_request_bank)
	actions.add_child(bank_button)
	var rules_button := Button.new()
	rules_button.text = "规则" if OS.has_feature("mobile") else "规则  [T]"
	rules_button.custom_minimum_size.y = 48
	_style_button(rules_button, 20)
	rules_button.pressed.connect(_toggle_rules)
	actions.add_child(rules_button)
	var settings_button := Button.new()
	settings_button.text = "设置"
	settings_button.custom_minimum_size.y = 48
	_style_button(settings_button, 20)
	settings_button.pressed.connect(_open_settings)
	actions.add_child(settings_button)

	status_label = _make_label("", 28, Color("fff0c8"), HORIZONTAL_ALIGNMENT_CENTER)
	status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_left = 330
	status_label.offset_top = 26
	status_label.offset_right = -330
	status_label.offset_bottom = 78
	status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	game_hud.add_child(status_label)

func _build_rules_overlay() -> void:
	rules_overlay = Control.new()
	rules_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rules_overlay.visible = false

	ui_root.add_child(rules_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rules_overlay.add_child(shade)
	var panel := _make_parchment_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-430, -305)
	panel.size = Vector2(860, 610)
	rules_overlay.add_child(panel)
	var title := _make_label("骰局规则", 38, INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(80, 45)
	title.size = Vector2(700, 55)
	panel.add_child(title)
	var rules := RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.fit_content = false
	rules.scroll_active = true
	rules.position = Vector2(92, 108)
	rules.size = Vector2(676, 410)
	rules.add_theme_font_override("normal_font", main_font)
	rules.add_theme_font_size_override("normal_font_size", 22)
	rules.add_theme_color_override("default_color", INK)
	rules.text = "[b]计分[/b]\n1. 单个 1：100 分；单个 5：50 分。\n2. 三个相同：点数 × 100；三个 1 为 1000 分。\n3. 四、五、六个相同：三连基础分 × 2、× 4、× 8。\n4. 顺子 1–6：1500 分。\n5. 小顺子 1–5：500 分；2–6：750 分。\n\n[b]回合[/b]\n选择本次投掷中的合法得分骰后，可以继续冒险或停手收分。若下一掷没有任何得分骰，本轮累计全部清零。若一次收起所有骰子，继续投掷时会获得六枚新骰子。"
	panel.add_child(rules)
	var close := Button.new()
	close.text = "关闭" if OS.has_feature("mobile") else "关闭  [T]"
	close.position = Vector2(310, 526)
	close.size = Vector2(240, 50)
	_style_button(close, 21)
	close.pressed.connect(_toggle_rules)
	panel.add_child(close)

func _build_online_overlay() -> void:
	online_overlay = Control.new()
	online_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	online_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(online_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	online_overlay.add_child(shade)
	var panel := _make_parchment_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -300)
	panel.size = Vector2(660, 600)
	online_overlay.add_child(panel)
	var title := _make_label("联机对战", 40, INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(80, 64)
	title.size = Vector2(500, 58)
	panel.add_child(title)

	online_choice_view = Control.new()
	online_choice_view.position = Vector2(80, 145)
	online_choice_view.size = Vector2(500, 385)
	panel.add_child(online_choice_view)
	var create_choice := Button.new()
	create_choice.text = "创建房间"
	create_choice.position = Vector2(65, 48)
	create_choice.size = Vector2(370, 72)
	_style_button(create_choice, 27)
	create_choice.pressed.connect(_show_online_create)
	online_choice_view.add_child(create_choice)
	var join_choice := Button.new()
	join_choice.text = "加入房间"
	join_choice.position = Vector2(65, 148)
	join_choice.size = Vector2(370, 72)
	_style_button(join_choice, 27)
	join_choice.pressed.connect(_show_online_join)
	online_choice_view.add_child(join_choice)
	var lobby_back := Button.new()
	lobby_back.text = "返回主菜单"
	lobby_back.position = Vector2(100, 294)
	lobby_back.size = Vector2(300, 52)
	_style_button(lobby_back, 21)
	lobby_back.pressed.connect(_close_online_lobby)
	online_choice_view.add_child(lobby_back)

	online_join_view = Control.new()
	online_join_view.position = Vector2(80, 145)
	online_join_view.size = Vector2(500, 385)
	panel.add_child(online_join_view)
	var join_title := _make_label("输入房主分享的六位房间码", 23, INK, HORIZONTAL_ALIGNMENT_CENTER)
	join_title.position = Vector2(0, 20)
	join_title.size = Vector2(500, 42)
	online_join_view.add_child(join_title)
	room_code_edit = LineEdit.new()
	room_code_edit.placeholder_text = "六位房间码"
	room_code_edit.max_length = 6
	room_code_edit.position = Vector2(45, 82)
	room_code_edit.size = Vector2(410, 58)
	room_code_edit.add_theme_font_override("font", main_font)
	room_code_edit.add_theme_font_size_override("font_size", 24)
	online_join_view.add_child(room_code_edit)
	join_room_button = Button.new()
	join_room_button.text = "加入房间"
	join_room_button.position = Vector2(100, 162)
	join_room_button.size = Vector2(300, 62)
	_style_button(join_room_button, 25)
	join_room_button.pressed.connect(func() -> void: _begin_online_request("join"))
	online_join_view.add_child(join_room_button)
	var join_back := Button.new()
	join_back.text = "返回上一步"
	join_back.position = Vector2(100, 294)
	join_back.size = Vector2(300, 52)
	_style_button(join_back, 21)
	join_back.pressed.connect(_show_online_choice)
	online_join_view.add_child(join_back)

	online_create_view = Control.new()
	online_create_view.position = Vector2(80, 145)
	online_create_view.size = Vector2(500, 385)
	panel.add_child(online_create_view)
	var target_title := _make_label("选择本局目标分数", 23, INK, HORIZONTAL_ALIGNMENT_CENTER)
	target_title.position = Vector2(0, 8)
	target_title.size = Vector2(500, 40)
	online_create_view.add_child(target_title)
	online_target_option = OptionButton.new()
	for score in [1500, 2500, 4000, 6000]:
		online_target_option.add_item(str(score), score)
	online_target_option.select(2)
	online_target_option.position = Vector2(100, 58)
	online_target_option.size = Vector2(300, 56)
	_style_button(online_target_option, 24)
	online_create_view.add_child(online_target_option)
	create_room_button = Button.new()
	create_room_button.text = "创建并获取房间码"
	create_room_button.position = Vector2(80, 136)
	create_room_button.size = Vector2(340, 62)
	_style_button(create_room_button, 24)
	create_room_button.pressed.connect(func() -> void: _begin_online_request("create"))
	online_create_view.add_child(create_room_button)
	created_room_code_button = Button.new()
	created_room_code_button.position = Vector2(45, 218)
	created_room_code_button.size = Vector2(410, 58)
	_style_button(created_room_code_button, 24)
	created_room_code_button.pressed.connect(_copy_created_room_code)
	created_room_code_button.visible = false
	online_create_view.add_child(created_room_code_button)
	var create_back := Button.new()
	create_back.text = "返回上一步"
	create_back.position = Vector2(100, 294)
	create_back.size = Vector2(300, 52)
	_style_button(create_back, 21)
	create_back.pressed.connect(_show_online_choice)
	online_create_view.add_child(create_back)

	online_status_label = _make_label("", 20, Color("8e2d22"), HORIZONTAL_ALIGNMENT_CENTER)
	online_status_label.position = Vector2(80, 505)
	online_status_label.size = Vector2(500, 48)
	online_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(online_status_label)
	online_overlay.visible = false

func _build_settings_overlay() -> void:
	settings_overlay = Control.new()
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	settings_overlay.visible = false
	ui_root.add_child(settings_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.74)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(shade)
	var panel := _make_parchment_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-340, -250)
	panel.size = Vector2(680, 500)
	settings_overlay.add_child(panel)
	var title := _make_label("设置", 42, INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(80, 42)
	title.size = Vector2(520, 62)
	panel.add_child(title)
	settings_notice = _make_label("", 20, Color("725037"), HORIZONTAL_ALIGNMENT_CENTER)
	settings_notice.position = Vector2(70, 105)
	settings_notice.size = Vector2(540, 40)
	panel.add_child(settings_notice)
	var volume_title := _make_label("音乐音量", 25, INK)
	volume_title.position = Vector2(100, 166)
	volume_title.size = Vector2(300, 40)
	panel.add_child(volume_title)
	music_volume_label = _make_label("100%", 23, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	music_volume_label.position = Vector2(430, 166)
	music_volume_label.size = Vector2(150, 40)
	panel.add_child(music_volume_label)
	music_volume_slider = HSlider.new()
	music_volume_slider.position = Vector2(100, 212)
	music_volume_slider.size = Vector2(480, 42)
	music_volume_slider.min_value = 0.0
	music_volume_slider.max_value = 100.0
	music_volume_slider.step = 1.0
	music_volume_slider.value = 100.0
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	panel.add_child(music_volume_slider)
	if OS.has_feature("windows"):
		fullscreen_toggle = Button.new()
		fullscreen_toggle.toggle_mode = true
		fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		fullscreen_toggle.text = "无边框全屏：开" if fullscreen_toggle.button_pressed else "无边框全屏：关"
		fullscreen_toggle.position = Vector2(190, 292)
		fullscreen_toggle.size = Vector2(300, 56)
		_style_button(fullscreen_toggle, 22)
		fullscreen_toggle.toggled.connect(_on_borderless_fullscreen_toggled)
		panel.add_child(fullscreen_toggle)
	settings_return_button = Button.new()
	settings_return_button.position = Vector2(90, 393)
	settings_return_button.size = Vector2(235, 58)
	_style_button(settings_return_button, 24)
	settings_return_button.pressed.connect(_close_settings)
	panel.add_child(settings_return_button)
	settings_menu_button = Button.new()
	settings_menu_button.text = "返回主界面"
	settings_menu_button.position = Vector2(355, 393)
	settings_menu_button.size = Vector2(235, 58)
	_style_button(settings_menu_button, 24)
	settings_menu_button.pressed.connect(_show_menu)
	panel.add_child(settings_menu_button)

func _build_win_overlay() -> void:
	win_overlay = Control.new()
	win_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_overlay.visible = false
	ui_root.add_child(win_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.74)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_overlay.add_child(shade)
	var panel := _make_parchment_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -205)
	panel.size = Vector2(600, 410)
	win_overlay.add_child(panel)
	win_title = _make_label("你赢了", 48, INK, HORIZONTAL_ALIGNMENT_CENTER)
	win_title.position = Vector2(75, 78)
	win_title.size = Vector2(450, 72)
	panel.add_child(win_title)
	rematch_button = Button.new()
	rematch_button.text = "再来一局"
	rematch_button.position = Vector2(150, 192)
	rematch_button.size = Vector2(300, 62)
	_style_button(rematch_button, 26)
	rematch_button.pressed.connect(_on_rematch_pressed)
	panel.add_child(rematch_button)
	var menu := Button.new()
	menu.text = "返回菜单"
	menu.position = Vector2(150, 274)
	menu.size = Vector2(300, 54)
	_style_button(menu, 22)
	menu.pressed.connect(_show_menu)
	panel.add_child(menu)

func _start_selected_game() -> void:
	get_tree().paused = false
	local_mode = true
	local_player_index = 0
	player_title_label.text = "玩家"
	opponent_title_label.text = "电脑"
	var target := target_option.get_item_id(target_option.selected)
	game_generation += 1
	_clear_all_dice()
	menu_screen.visible = false
	game_hud.visible = true
	win_overlay.visible = false
	rules_overlay.visible = false
	settings_overlay.visible = false
	session = Session.new(target)
	session.state_changed.connect(_on_state_changed)
	session.rolled.connect(_on_rolled)
	session.busted.connect(_on_busted)
	session.hot_dice.connect(_on_hot_dice)
	session.game_finished.connect(_on_game_finished)
	latest_snapshot = session.get_snapshot()
	_on_state_changed(latest_snapshot)
	input_locked = true
	status_label.text = "玩家先手"
	_start_turn_after_delay(game_generation, 0.45)

func _bind_network_client() -> void:
	network_client.connected.connect(_on_network_connected)
	network_client.disconnected.connect(_on_network_disconnected)
	network_client.room_assigned.connect(_on_network_room_assigned)
	network_client.room_ready.connect(_on_network_room_ready)
	network_client.snapshot_received.connect(_on_network_snapshot)
	network_client.rolled.connect(_on_rolled)
	network_client.busted.connect(_on_busted)
	network_client.hot_dice.connect(_on_hot_dice)
	network_client.game_finished.connect(_on_game_finished)
	network_client.opponent_left.connect(_on_opponent_left)
	network_client.server_error.connect(_on_network_error)

func _open_online_lobby() -> void:
	online_overlay.visible = true
	_show_online_choice()

func _show_online_choice() -> void:
	pending_online_request = ""
	if network_client != null:
		network_client.disconnect_from_server()
	online_choice_view.visible = true
	online_join_view.visible = false
	online_create_view.visible = false
	room_code_edit.clear()
	created_room_code = ""
	created_room_code_button.visible = false
	online_target_option.disabled = false
	create_room_button.disabled = false
	join_room_button.disabled = false
	_set_online_status("")

func _show_online_join() -> void:
	online_choice_view.visible = false
	online_join_view.visible = true
	online_create_view.visible = false
	room_code_edit.clear()
	join_room_button.disabled = false
	_set_online_status("")
	room_code_edit.grab_focus()

func _show_online_create() -> void:
	online_choice_view.visible = false
	online_join_view.visible = false
	online_create_view.visible = true
	created_room_code = ""
	created_room_code_button.visible = false
	online_target_option.disabled = false
	create_room_button.disabled = false
	_set_online_status("")

func _set_online_status(message: String) -> void:
	online_status_label.text = message
	online_status_label.visible = not message.is_empty()

func _copy_created_room_code() -> void:
	DisplayServer.clipboard_set(created_room_code)
	_set_online_status("房间码已复制，正在等待另一位玩家加入…")

func _close_online_lobby() -> void:
	pending_online_request = ""
	if network_client != null:
		network_client.disconnect_from_server()
	online_overlay.visible = false

func _begin_online_request(kind: String) -> void:
	if kind == "join" and room_code_edit.text.strip_edges().length() != 6:
		_set_online_status("请输入六位房间码")
		return
	pending_online_request = kind
	create_room_button.disabled = kind == "create"
	join_room_button.disabled = kind == "join"
	_set_online_status("正在连接服务器…")
	var error := network_client.connect_to_server(Client.DEFAULT_SERVER_URL)
	if error != OK:
		pending_online_request = ""
		create_room_button.disabled = false
		join_room_button.disabled = false
		_set_online_status("连接失败：%s" % error_string(error))

func _on_network_connected() -> void:
	if pending_online_request == "create":
		network_client.create_room(online_target_option.get_item_id(online_target_option.selected))
	elif pending_online_request == "join":
		network_client.join_room(room_code_edit.text)

func _on_network_room_assigned(room_code: String, player_index: int) -> void:
	pending_online_request = ""
	local_player_index = player_index
	if player_index == 0:
		created_room_code = room_code
		created_room_code_button.text = "房间码：%s　点击复制" % room_code
		created_room_code_button.visible = true
		online_target_option.disabled = true
		create_room_button.disabled = true
		_set_online_status("请把房间码发给另一位玩家，正在等待加入…")
	else:
		_set_online_status("已加入房间 %s，正在开始…" % room_code)

func _on_network_room_ready(snapshot: GameSnapshot) -> void:
	get_tree().paused = false
	local_mode = false
	game_generation += 1
	_clear_all_dice()
	menu_screen.visible = false
	online_overlay.visible = false
	game_hud.visible = true
	win_overlay.visible = false
	rules_overlay.visible = false
	settings_overlay.visible = false
	session = NetworkProxy.new()
	session.apply_snapshot(snapshot)
	latest_snapshot = snapshot
	player_title_label.text = "你"
	opponent_title_label.text = "对手"
	input_locked = true
	_on_state_changed(snapshot)
	status_label.text = "你先手，等待服务器掷骰" if snapshot.current_player == local_player_index else "对手先手，等待服务器掷骰"

func _on_network_snapshot(snapshot: GameSnapshot) -> void:
	if local_mode or session == null:
		return
	session.apply_snapshot(snapshot)
	if snapshot.phase == Session.Phase.AWAITING_ROLL:
		input_locked = true
		_clear_all_dice()
	_on_state_changed(snapshot)

func _on_network_disconnected() -> void:
	if online_overlay != null and online_overlay.visible:
		create_room_button.disabled = false
		join_room_button.disabled = false
		_set_online_status("与服务器的连接已断开")
	elif not local_mode and game_hud.visible:
		_show_online_disconnect("与服务器的连接已断开")

func _on_network_error(message: String) -> void:
	if online_overlay.visible:
		create_room_button.disabled = false
		join_room_button.disabled = false
		_set_online_status(message)
	else:
		status_label.text = message
		input_locked = false
		_update_buttons()

func _on_opponent_left() -> void:
	_show_online_disconnect("对手已离开房间")

func _show_online_disconnect(message: String) -> void:
	game_generation += 1
	input_locked = true
	session = null
	latest_snapshot = null
	_clear_all_dice()
	game_hud.visible = false
	menu_screen.visible = true
	online_overlay.visible = true
	_show_online_choice()
	_set_online_status(message)

func _show_menu() -> void:
	get_tree().paused = false
	game_generation += 1
	input_locked = true
	session = null
	local_mode = true
	local_player_index = 0
	if network_client != null:
		network_client.disconnect_from_server()
	latest_snapshot = null
	_clear_all_dice()
	menu_screen.visible = true
	game_hud.visible = false
	rules_overlay.visible = false
	win_overlay.visible = false
	settings_overlay.visible = false
	if online_overlay != null:
		online_overlay.visible = false

func _open_settings() -> void:
	settings_notice.text = "当前对局已暂停，背景音乐将继续播放"
	settings_return_button.text = "返回游戏"
	settings_return_button.position = Vector2(90, 393)
	settings_return_button.size = Vector2(235, 58)
	settings_menu_button.visible = true
	settings_overlay.visible = true
	get_tree().paused = true

func _open_menu_settings() -> void:
	settings_notice.text = "背景音乐将继续播放"
	settings_return_button.text = "返回主界面"
	settings_return_button.position = Vector2(190, 393)
	settings_return_button.size = Vector2(300, 58)
	settings_menu_button.visible = false
	settings_overlay.visible = true
	get_tree().paused = true

func _close_settings() -> void:
	settings_overlay.visible = false
	get_tree().paused = false
	_update_buttons()

func _on_music_volume_changed(value: float) -> void:
	music_volume_label.text = "%d%%" % int(value)
	background_music.volume_db = linear_to_db(value / 100.0) if value > 0.0 else -80.0

func _on_borderless_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	fullscreen_toggle.text = "无边框全屏：开" if enabled else "无边框全屏：关"

func _start_turn_after_delay(generation: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if generation != game_generation or session == null or session.phase != Session.Phase.AWAITING_ROLL:
		return
	if not local_mode:
		status_label.text = "等待服务器掷骰"
		return
	input_locked = true
	status_label.text = "玩家掷骰" if session.current_player == 0 else "电脑掷骰"
	session.apply_action(Action.roll())

func _on_controller_action(action: GameAction) -> void:
	if session == null:
		return
	if not local_mode:
		network_controller.submit_to_server(action)
		return
	var succeeded: bool = session.apply_action(action)
	if succeeded and action.type == GameAction.Type.BANK and session.phase != Session.Phase.GAME_OVER:
		_clear_all_dice()
		_start_turn_after_delay(game_generation, 0.65)

func _on_state_changed(snapshot: GameSnapshot) -> void:
	latest_snapshot = snapshot
	var opponent_index := 1 - local_player_index
	player_score_label.text = str(snapshot.scores[local_player_index])
	ai_score_label.text = str(snapshot.scores[opponent_index])
	target_label.text = "目标：%d" % snapshot.target_score
	turn_label.text = "本轮：%d" % snapshot.turn_score
	selected_label.text = "选定：%d" % snapshot.selected_score
	_update_die_selection()
	_update_held_dice(snapshot.held_dice)
	_update_buttons()
	if snapshot.current_player == local_player_index and snapshot.phase == Session.Phase.AWAITING_SELECTION and not input_locked:
		if snapshot.selected_indices.is_empty():
			status_label.text = "选择得分骰"
		elif snapshot.selected_score > 0:
			status_label.text = "当前选择可得 %d 分" % snapshot.selected_score
		else:
			status_label.text = "当前组合暂不能计分，请继续选择"
	elif not local_mode and snapshot.phase == Session.Phase.AWAITING_SELECTION and rolling_count == 0:
		status_label.text = "等待对手选择" if snapshot.current_player != local_player_index else "选择得分骰"

func _on_rolled(values: Array[int]) -> void:
	input_locked = true
	pending_bust = false
	_clear_active_dice()
	rolling_count = values.size()
	for index in range(values.size()):
		var die: DieView = Die.new()
		dice_root.add_child(die)
		die.configure(index, true)
		die.roll_finished.connect(_on_die_roll_finished)
		die_views.append(die)
		die.animate_roll(values[index], DIE_POSITIONS[index], index * 0.035)
	status_label.text = "骰子滚动中…"

func _on_busted(_player_index: int) -> void:
	pending_bust = true

func _on_hot_dice(_player_index: int) -> void:
	status_label.text = "好运！六骰重掷"

func _on_die_roll_finished(_index: int) -> void:
	rolling_count -= 1
	if rolling_count > 0:
		return
	if pending_bust or (session != null and session.phase == Session.Phase.BUSTED):
		if local_mode:
			_resolve_bust_after_delay(game_generation)
		else:
			status_label.text = "爆骰！本轮得分清零"
	elif local_mode and session != null and session.current_player == 1:
		_run_ai_turn(game_generation)
	elif session != null and session.current_player == local_player_index:
		input_locked = false
		status_label.text = "选择得分骰"
		focused_die = clampi(focused_die, 0, maxi(0, die_views.size() - 1))
		_update_die_selection()
		_update_buttons()
	else:
		input_locked = true
		status_label.text = "等待对手选择"

func _resolve_bust_after_delay(generation: int) -> void:
	status_label.text = "爆骰！本轮得分清零"
	await get_tree().create_timer(2.0).timeout
	if generation != game_generation or session == null:
		return
	session.resolve_bust()
	_clear_all_dice()
	_start_turn_after_delay(generation, 0.55)

func _run_ai_turn(generation: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if not local_mode or generation != game_generation or session == null or session.current_player != 1 or session.phase != Session.Phase.AWAITING_SELECTION:
		return
	var indices := ai_controller.choose_selection(session.current_roll)
	session.apply_action(Action.set_selection(indices))
	status_label.text = "电脑选择了 %d 分" % session.get_selected_score()
	await get_tree().create_timer(0.7).timeout
	if generation != game_generation or session == null:
		return
	var projected: int = session.turn_score + session.get_selected_score()
	var remaining: int = session.current_roll.size() - session.selected_indices.size()
	if ai_controller.should_bank(projected, remaining, session.scores, session.target_score):
		status_label.text = "电脑停手得分"
		input_locked = true
		if session.apply_action(Action.bank()) and session.phase != Session.Phase.GAME_OVER:
			_clear_all_dice()
			_start_turn_after_delay(generation, 0.75)
	else:
		status_label.text = "电脑继续冒险"
		input_locked = true
		session.apply_action(Action.roll_again())

func _on_game_finished(winner_index: int) -> void:
	input_locked = true
	status_label.text = "对局结束"
	win_title.text = "你赢了！" if winner_index == local_player_index else ("电脑获胜" if local_mode else "对手获胜")
	rematch_button.text = "再来一局" if local_mode else "返回联机大厅"
	_show_win_after_delay(game_generation)

func _on_rematch_pressed() -> void:
	if local_mode:
		_start_selected_game()
	else:
		_show_menu()
		_open_online_lobby()

func _show_win_after_delay(generation: int) -> void:
	await get_tree().create_timer(0.7).timeout
	if generation == game_generation:
		win_overlay.visible = true

func _pick_die_at_screen(screen_position: Vector2) -> int:
	var nearest_die := -1
	var nearest_distance := INF
	var pick_radius := 72.0 * get_viewport().get_visible_rect().size.y / 720.0
	for index in range(die_views.size()):
		var die_position := table_camera.unproject_position(die_views[index].global_position)
		var distance := screen_position.distance_to(die_position)
		if distance <= pick_radius and distance < nearest_distance:
			nearest_die = index
			nearest_distance = distance
	return nearest_die

func _toggle_die(index: int) -> void:
	if session == null or index < 0 or index >= session.current_roll.size():
		return
	var indices: Array[int] = []
	indices.assign(session.selected_indices)
	if indices.has(index):
		indices.erase(index)
	else:
		indices.append(index)
	indices.sort()
	human_controller.choose_indices(indices)

func _move_focus(direction: int) -> void:
	if die_views.is_empty():
		return
	focused_die = posmod(focused_die + direction, die_views.size())
	_update_die_selection()

func _request_roll_again() -> void:
	if not _can_human_act() or latest_snapshot.selected_score <= 0:
		return
	input_locked = true
	human_controller.roll_again()

func _request_bank() -> void:
	if not _can_human_act() or latest_snapshot.selected_score <= 0:
		return
	input_locked = true
	human_controller.bank()

func _update_die_selection() -> void:
	if session == null:
		return
	for index in range(die_views.size()):
		die_views[index].set_selection(session.selected_indices.has(index), index == focused_die and _can_human_act())

func _update_held_dice(values: Array[int]) -> void:
	for child in held_root.get_children():
		child.queue_free()
	held_views.clear()
	for index in range(values.size()):
		var die: DieView = Die.new()
		held_root.add_child(die)
		die.configure(index, false)
		die.scale = Vector3.ONE * 0.48
		die.set_value(values[index])
		die.set_base_position(Vector3(-2.0 + index * 0.78, 0.32, 2.45))
		held_views.append(die)

func _update_buttons() -> void:
	var enabled := _can_human_act() and latest_snapshot != null and latest_snapshot.selected_score > 0
	roll_again_button.disabled = not enabled
	bank_button.disabled = not enabled

func _can_human_act() -> bool:
	return session != null and not input_locked and session.current_player == local_player_index and session.phase == Session.Phase.AWAITING_SELECTION and not rules_overlay.visible and not win_overlay.visible and not settings_overlay.visible

func _toggle_rules() -> void:
	if not game_hud.visible:
		return
	rules_overlay.visible = not rules_overlay.visible
	_update_buttons()

func _clear_active_dice() -> void:
	for child in dice_root.get_children():
		child.queue_free()
	die_views.clear()

func _clear_all_dice() -> void:
	_clear_active_dice()
	for child in held_root.get_children():
		child.queue_free()
	held_views.clear()

func _make_parchment_panel() -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.texture = parchment_texture
	panel.patch_margin_left = 145
	panel.patch_margin_top = 120
	panel.patch_margin_right = 145
	panel.patch_margin_bottom = 120
	panel.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	panel.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	return panel

func _make_label(text: String, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", main_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _style_button(button: BaseButton, font_size: int) -> void:
	button.add_theme_font_override("font", main_font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("f6e8c8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.66, 0.55, 0.55))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.09, 0.05, 0.88)
	normal.border_color = Color("8b672d")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.27, 0.15, 0.07, 0.94)
	hover.border_color = GOLD
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.08, 0.05, 0.03, 0.58)
	disabled.border_color = Color(0.34, 0.27, 0.18, 0.5)
	button.add_theme_stylebox_override("disabled", disabled)

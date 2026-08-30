extends SceneTree

const Die = preload("res://scripts/ui/die_view.gd")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var scene = current_scene
	if _collect_text(scene.menu_screen).contains("选择骰子"):
		_fail("主菜单不应直接显示骰子选择入口")
	if DisplayServer.get_name() != "headless":
		await process_frame
		root.get_texture().get_image().save_png("res://build/dice-menu-smoke.png")
	scene.selection_rng.seed = 314159
	var expected_ai_rng := RandomNumberGenerator.new()
	expected_ai_rng.seed = 314159
	var expected_ai_loadout := DiceCatalog.random_loadout(expected_ai_rng)
	scene._start_selected_game()
	await process_frame
	if not scene.dice_selector_overlay.visible:
		_fail("点击单人游戏后未在开局前打开骰子选择界面")
	if scene.session != null:
		_fail("玩家确认骰子之前单人对局提前开始")
	var all_text := _collect_text(scene.dice_selector_overlay)
	if _has_exact_text(scene.dice_selector_overlay, "普通骰") or _has_exact_text(scene.dice_selector_overlay, "默认骰"):
		_fail("选择列表不应展示普通骰子")
	for definition in DiceCatalog.DEFINITIONS:
		if not all_text.contains(String(definition["name"])):
			_fail("选择界面缺少骰子：%s" % definition["name"])
		if not all_text.contains(String(definition["odds"])):
			_fail("选择界面缺少概率：%s" % definition["name"])
		if not all_text.contains(String(definition["advantage"])) or not all_text.contains(String(definition["tradeoff"])):
			_fail("选择界面缺少利弊：%s" % definition["name"])
	scene._change_dice_count("wild", 1)
	scene._change_dice_count("wild", 1)
	scene._change_dice_count("greed", 1)
	if scene._selected_dice_count() != 3:
		_fail("选择计数不正确")
	var configured: Array[String] = scene._selected_dice_loadout()
	if configured.count("wild") != 2 or configured.count("greed") != 1 or configured.count("default") != 3:
		_fail("不足六枚时没有正确补普通骰")
	if not scene.dice_selection_summary.text.contains("已选择 3/6") or not scene.dice_selection_summary.text.contains("剩余 3 枚自动补为普通骰"):
		_fail("配置摘要未同步")
	for index in range(10):
		scene._change_dice_count("sequence", 1)
	if scene._selected_dice_count() != 6:
		_fail("骰子选择没有限制为六枚")
	# Restore the intended three selected dice for the game-start assertion.
	scene.dice_selection_counts["sequence"] = 0
	scene._update_dice_selector_summary()
	if DisplayServer.get_name() != "headless":
		await process_frame
		var image := root.get_texture().get_image()
		if image.save_png("res://build/dice-selector-smoke.png") != OK:
			_fail("无法保存骰子选择界面截图")
	scene._confirm_dice_selection()
	if scene.dice_selector_overlay.visible:
		_fail("确认配置后骰子选择界面未关闭")
	if scene.session == null:
		_fail("确认配置后单人对局未开始")
		quit(1)
		return
	if scene.session.player_dice_loadouts[0] != configured:
		_fail("单人游戏未使用玩家配置")
	if scene.session.player_dice_loadouts[1] != expected_ai_loadout:
		_fail("电脑没有按随机结果选择六枚骰子")
	if DisplayServer.get_name() != "headless":
		await create_timer(1.8).timeout
		root.get_texture().get_image().save_png("res://build/dice-types-game-smoke.png")
	_test_die_styles(scene)
	if failures == 0:
		print("PASS: 开局前选骰、六枚上限、默认补齐、电脑随机选骰和差异外观测试通过")
	quit(1 if failures > 0 else 0)


func _test_die_styles(scene: Node) -> void:
	var colors: Array[Color] = []
	for index in range(DiceCatalog.DEFINITIONS.size()):
		var definition: Dictionary = DiceCatalog.DEFINITIONS[index]
		var die: DieView = Die.new()
		scene.add_child(die)
		die.configure(index, false, String(definition["id"]))
		colors.append(die.body_material.albedo_color)
		if die.body_material.albedo_color != definition["body_color"] or die.pip_material.albedo_color != definition["pip_color"]:
			_fail("骰子外观颜色未应用：%s" % definition["name"])
		die.queue_free()
	var unique: Array[Color] = []
	for color in colors:
		if not unique.has(color):
			unique.append(color)
	if unique.size() != DiceCatalog.DEFINITIONS.size():
		_fail("骰子种类外观不够区分")


func _collect_text(node: Node) -> String:
	var text := ""
	if node is Label or node is Button:
		text += String(node.text) + "\n"
	for child in node.get_children():
		text += _collect_text(child)
	return text


func _has_exact_text(node: Node, expected: String) -> bool:
	if (node is Label or node is Button) and String(node.text) == expected:
		return true
	for child in node.get_children():
		if _has_exact_text(child, expected):
			return true
	return false


func _fail(message: String) -> void:
	failures += 1
	printerr("FAIL: " + message)

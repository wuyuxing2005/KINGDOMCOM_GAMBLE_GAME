extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	if not main.background_music.playing or not main.background_music.stream.loop:
		printerr("background music did not start in loop mode")
		quit(1)
		return
	main._start_selected_game()
	await create_timer(0.1).timeout
	var active_session = main.session
	main._open_settings()
	if main.session != active_session or not main.game_hud.visible or not main.settings_overlay.visible or not paused:
		printerr("opening settings did not pause and preserve the current game")
		quit(1)
		return
	if not main.background_music.playing:
		printerr("background music stopped when settings opened")
		quit(1)
		return
	main.music_volume_slider.value = 25.0
	await process_frame
	if main.music_volume_label.text != "25%" or absf(main.background_music.volume_db - linear_to_db(0.25)) > 0.01:
		printerr("music volume slider did not update playback volume")
		quit(1)
		return
	if OS.has_feature("windows") and main.fullscreen_toggle == null:
		printerr("Windows settings did not include the borderless fullscreen option")
		quit(1)
		return
	if OS.has_feature("windows") and DisplayServer.get_name() != "headless":
		main.fullscreen_toggle.button_pressed = true
		await process_frame
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			printerr("borderless fullscreen did not turn on")
			quit(1)
			return
		main.fullscreen_toggle.button_pressed = false
		await process_frame
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			printerr("borderless fullscreen did not turn off")
			quit(1)
			return
	if DisplayServer.get_name() != "headless":
		var image := root.get_texture().get_image()
		var error := image.save_png("res://build/settings-smoke.png")
		if error != OK:
			printerr("settings smoke capture failed: %s" % error)
			quit(1)
			return
	main._close_settings()
	if paused or main.settings_overlay.visible or main.session != active_session or not main.game_hud.visible or not main.background_music.playing:
		printerr("returning to the game did not resume the preserved session")
		quit(1)
		return
	main._open_settings()
	main._show_menu()
	if paused or main.session != null or not main.menu_screen.visible or main.settings_overlay.visible or not main.background_music.playing or absf(main.background_music.volume_db - linear_to_db(0.25)) > 0.01:
		printerr("returning to the main menu did not end the game and preserve music")
		quit(1)
		return
	main._open_menu_settings()
	if not paused or not main.menu_screen.visible or not main.settings_overlay.visible or main.settings_return_button.text != "返回主界面" or main.settings_menu_button.visible:
		printerr("main menu settings did not open in menu mode")
		quit(1)
		return
	await process_frame
	if DisplayServer.get_name() != "headless":
		var menu_image := root.get_texture().get_image()
		var menu_error := menu_image.save_png("res://build/menu-settings-smoke.png")
		if menu_error != OK:
			printerr("main menu settings smoke capture failed: %s" % menu_error)
			quit(1)
			return
	main._close_settings()
	if paused or not main.menu_screen.visible or main.settings_overlay.visible or not main.background_music.playing:
		printerr("closing main menu settings did not return to the main menu")
		quit(1)
		return
	await process_frame
	if DisplayServer.get_name() != "headless":
		var main_menu_image := root.get_texture().get_image()
		var main_menu_error := main_menu_image.save_png("res://build/menu-smoke.png")
		if main_menu_error != OK:
			printerr("main menu smoke capture failed: %s" % main_menu_error)
			quit(1)
			return
	print("music and settings smoke test passed")
	quit(0)

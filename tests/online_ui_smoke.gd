extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	current_scene._open_online_lobby()
	await process_frame
	if not await _capture("res://build/online-ui-smoke.png"):
		quit(1)
		return
	current_scene._show_online_join()
	await process_frame
	if not await _capture("res://build/online-join-smoke.png"):
		quit(1)
		return
	current_scene._show_online_create()
	await process_frame
	if not await _capture("res://build/online-create-smoke.png"):
		quit(1)
		return
	current_scene._on_network_room_assigned("ABC123", 0)
	await process_frame
	if not await _capture("res://build/online-created-smoke.png"):
		quit(1)
		return
	current_scene._copy_created_room_code()
	if DisplayServer.clipboard_get() != "ABC123":
		printerr("room code clipboard copy failed")
		quit(1)
		return
	current_scene.online_overlay.visible = false
	current_scene.menu_screen.visible = false
	current_scene.game_hud.visible = true
	current_scene.local_mode = false
	current_scene.local_player_index = 0
	var game_over := GameSnapshot.new()
	game_over.target_score = 4000
	game_over.scores.assign([4000, 1200])
	game_over.phase = GameSession.Phase.GAME_OVER
	game_over.winner = 0
	current_scene.session = NetworkSessionProxy.new()
	current_scene.session.apply_snapshot(game_over)
	current_scene.latest_snapshot = game_over
	current_scene._on_game_finished(0)
	await create_timer(0.8).timeout
	if not current_scene.win_overlay.visible or current_scene.rematch_button.text != "再来一局":
		printerr("online result did not show rematch action")
		quit(1)
		return
	current_scene._on_opponent_left()
	if not current_scene.rematch_status_label.text.is_empty():
		printerr("opponent exit was shown before the player requested a rematch")
		quit(1)
		return
	current_scene._on_rematch_pressed()
	if current_scene.rematch_status_label.text != "对方已退出":
		printerr("rematch did not report that the opponent exited")
		quit(1)
		return
	current_scene._on_game_finished(0)
	current_scene._on_network_rematch_waiting()
	if current_scene.rematch_status_label.text != "等待对方加入中…" or not current_scene.rematch_button.disabled:
		printerr("rematch waiting state is incorrect")
		quit(1)
		return
	current_scene._on_opponent_left()
	if current_scene.rematch_status_label.text != "对方已退出":
		printerr("waiting player did not see the opponent exit")
		quit(1)
		return
	current_scene._on_game_finished(0)
	current_scene._on_network_rematch_choose_target()
	if not current_scene.rematch_target_option.visible or not current_scene.rematch_confirm_button.visible:
		printerr("host rematch target controls are missing")
		quit(1)
		return
	await process_frame
	if not await _capture("res://build/online-rematch-host-smoke.png"):
		quit(1)
		return
	current_scene.local_player_index = 1
	current_scene._on_game_finished(0)
	current_scene._on_network_rematch_choose_target()
	if current_scene.rematch_target_option.visible or current_scene.rematch_status_label.text != "等待房主选择目标分数…":
		printerr("guest rematch target waiting state is incorrect")
		quit(1)
		return
	print("online lobby and rematch UI smoke tests passed")
	quit(0)

func _capture(path: String) -> bool:
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		printerr("online ui smoke capture failed: %s" % error)
		return false
	return true

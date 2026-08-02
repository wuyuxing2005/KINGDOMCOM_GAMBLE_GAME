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
	print("online lobby smoke captures saved")
	quit(0)

func _capture(path: String) -> bool:
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		printerr("online ui smoke capture failed: %s" % error)
		return false
	return true

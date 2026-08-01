extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	current_scene._open_online_lobby()
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("res://build/online-ui-smoke.png")
	if error != OK:
		printerr("online ui smoke capture failed: %s" % error)
		quit(1)
		return
	print("online ui smoke capture saved")
	quit(0)

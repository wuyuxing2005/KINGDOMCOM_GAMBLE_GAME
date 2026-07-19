extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	main._start_selected_game()
	await create_timer(2.4).timeout
	var image := root.get_texture().get_image()
	var error := image.save_png("res://build/visual-smoke.png")
	if error != OK:
		printerr("visual smoke capture failed: %s" % error)
		quit(1)
		return
	print("visual smoke capture saved")
	quit(0)

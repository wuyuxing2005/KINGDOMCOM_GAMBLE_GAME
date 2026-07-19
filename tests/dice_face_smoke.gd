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
	var camera: Camera3D = main.find_children("*", "Camera3D", true, false)[0]
	camera.look_at_from_position(Vector3(0, 12.0, 0.01), Vector3.ZERO, Vector3.BACK)
	var positions := [
		Vector3(-2.4, 0.62, -0.8),
		Vector3(-0.8, 0.62, -0.8),
		Vector3(0.8, 0.62, -0.8),
		Vector3(2.4, 0.62, -0.8),
		Vector3(-0.8, 0.62, 0.8),
		Vector3(0.8, 0.62, 0.8),
	]
	for index in range(6):
		main.die_views[index].set_value(index + 1)
		main.die_views[index].set_base_position(positions[index])
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png("res://build/dice-faces-1-to-6.png")
	if error != OK:
		printerr("dice face capture failed: %s" % error)
		quit(1)
		return
	print("dice face capture saved")
	quit(0)

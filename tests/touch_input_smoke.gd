extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	main._start_selected_game()
	main.session.rng.seed = 42
	await create_timer(2.4).timeout
	print("roll=%s phase=%s locked=%s" % [main.session.current_roll, main.session.phase, main.input_locked])
	var camera: Camera3D = main.find_children("*", "Camera3D", true, false)[0]
	var expected_scores := [50, 100]
	for touch_index in range(2):
		var die_index: int = [1, 4][touch_index]
		var screen_position := camera.unproject_position(main.die_views[die_index].global_position)
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = screen_position
		touch.pressed = true
		root.push_input(touch, true)
		await process_frame
		touch.pressed = false
		root.push_input(touch, true)
		await process_frame
		if main.latest_snapshot.selected_score != expected_scores[touch_index]:
			printerr("touch %d expected score %d, got %d" % [touch_index + 1, expected_scores[touch_index], main.latest_snapshot.selected_score])
			quit(1)
			return
		if main.roll_again_button.disabled or main.bank_button.disabled:
			printerr("scoring touch %d did not enable action buttons" % (touch_index + 1))
			quit(1)
			return
	print("selected=%s score=%d" % [main.session.selected_indices, main.latest_snapshot.selected_score])
	if main.session.selected_indices != [1, 4]:
		printerr("two touches did not preserve both selected dice")
		quit(1)
		return
	if main.latest_snapshot.selected_score != 100:
		printerr("two selected fives should score 100")
		quit(1)
		return
	if main.roll_again_button.disabled or main.bank_button.disabled:
		printerr("scoring selection did not enable action buttons")
		quit(1)
		return
	print("multi-touch selection and scoring buttons passed")
	quit(0)

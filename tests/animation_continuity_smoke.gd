extends SceneTree

const Die = preload("res://scripts/ui/die_view.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var die: DieView = Die.new()
	root.add_child(die)
	await process_frame
	die.configure(0, false)
	die.animate_roll(5, Vector3.ZERO)
	var started_at := Time.get_ticks_usec()
	var previous_at := started_at
	var previous_orientation := die.model_root.quaternion
	var early_peak := 0.0
	var landing_peak := 0.0
	while Time.get_ticks_usec() - started_at < 1000000:
		await process_frame
		var now := Time.get_ticks_usec()
		var elapsed := float(now - started_at) / 1000000.0
		var delta := float(now - previous_at) / 1000000.0
		var orientation := die.model_root.quaternion
		if delta > 0.0:
			var angular_speed := previous_orientation.angle_to(orientation) / delta
			if elapsed < 0.5:
				early_peak = maxf(early_peak, angular_speed)
			elif elapsed > 0.68:
				landing_peak = maxf(landing_peak, angular_speed)
		previous_at = now
		previous_orientation = orientation
	print("rotation early_peak=%.3f landing_peak=%.3f" % [early_peak, landing_peak])
	if landing_peak >= early_peak * 0.5:
		printerr("rotation accelerated again during landing")
		quit(1)
		return
	print("animation rotation decelerated continuously")
	quit(0)

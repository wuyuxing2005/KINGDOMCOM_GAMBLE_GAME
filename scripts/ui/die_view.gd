class_name DieView
extends Node3D

const ACTIVE_SCALE := 0.74

signal roll_finished(die_index: int)

static var shared_die_mesh: ArrayMesh
static var shared_ivory_material: StandardMaterial3D
static var shared_pip_material: StandardMaterial3D

var die_index := -1
var value := 1
var base_position := Vector3.ZERO
var is_selected := false
var is_focused := false
var model_root: Node3D
var selection_ring: MeshInstance3D
var ring_material: StandardMaterial3D

func _ready() -> void:
	_build_visuals()

func configure(index: int, _selectable: bool = true) -> void:
	die_index = index

func set_value(new_value: int) -> void:
	value = clampi(new_value, 1, 6)
	model_root.quaternion = _final_quaternion(value, 0.0)

func set_base_position(new_position: Vector3) -> void:
	base_position = new_position
	position = base_position + Vector3.UP * (0.17 if is_selected else 0.0)

func set_selection(selected: bool, focused: bool = false) -> void:
	is_selected = selected
	is_focused = focused
	if selection_ring:
		selection_ring.visible = is_selected or is_focused
		ring_material.albedo_color = Color("d9ad37") if is_selected else Color("f4df94")
		ring_material.emission = ring_material.albedo_color
		ring_material.emission_energy_multiplier = 1.25 if is_selected else 0.55
	var target_y := base_position.y + (0.17 if is_selected else 0.0)
	if is_inside_tree():
		create_tween().tween_property(self, "position:y", target_y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		position.y = target_y

func animate_roll(new_value: int, target: Vector3, delay: float = 0.0) -> void:
	value = clampi(new_value, 1, 6)
	base_position = target
	is_selected = false
	is_focused = false
	selection_ring.visible = false
	var yaw := randf_range(-PI, PI)
	var final_orientation := _final_quaternion(value, yaw)
	var spin_angles := Vector3(
		TAU * randf_range(1.7, 2.3),
		TAU * randf_range(2.1, 2.8),
		TAU * randf_range(1.4, 2.0)
	)
	position = target + Vector3(randf_range(-0.75, 0.75), 1.65, randf_range(-0.55, 0.55))
	_set_roll_rotation(0.0, final_orientation, spin_angles)
	scale = Vector3.ONE * 0.58

	var motion_tween := create_tween()
	if delay > 0.0:
		motion_tween.tween_interval(delay)
	motion_tween.tween_property(self, "position", target, 0.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion_tween.tween_property(self, "position", target + Vector3.UP * 0.13, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(self, "position", target, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion_tween.tween_callback(func() -> void: roll_finished.emit(die_index))

	var rotation_tween := create_tween()
	if delay > 0.0:
		rotation_tween.tween_interval(delay)
	rotation_tween.tween_method(_set_roll_rotation.bind(final_orientation, spin_angles), 0.0, 1.0, 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rotation_tween.tween_callback(func() -> void: model_root.quaternion = final_orientation)

	var scale_tween := create_tween()
	if delay > 0.0:
		scale_tween.tween_interval(delay)
	scale_tween.tween_property(self, "scale", Vector3.ONE * ACTIVE_SCALE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_visuals() -> void:
	if shared_die_mesh == null:
		shared_die_mesh = _create_rounded_cube_mesh()
		shared_ivory_material = StandardMaterial3D.new()
		shared_ivory_material.albedo_color = Color("f1ddb0")
		shared_ivory_material.roughness = 0.78
		shared_ivory_material.metallic = 0.0
		shared_pip_material = StandardMaterial3D.new()
		shared_pip_material.albedo_color = Color("24170e")
		shared_pip_material.roughness = 0.92

	model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)

	var body := MeshInstance3D.new()
	body.mesh = shared_die_mesh
	body.material_override = shared_ivory_material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model_root.add_child(body)

	_add_face_pips(1, Vector3.UP, Vector3.RIGHT, Vector3.BACK)
	_add_face_pips(6, Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD)
	_add_face_pips(2, Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	_add_face_pips(5, Vector3.FORWARD, Vector3.LEFT, Vector3.UP)
	_add_face_pips(3, Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	_add_face_pips(4, Vector3.LEFT, Vector3.BACK, Vector3.UP)

	selection_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.63
	torus.outer_radius = 0.69
	torus.rings = 24
	torus.ring_segments = 8
	selection_ring.mesh = torus
	selection_ring.position.y = -0.535
	ring_material = StandardMaterial3D.new()
	ring_material.albedo_color = Color("d9ad37")
	ring_material.emission_enabled = true
	ring_material.emission = Color("d9ad37")
	ring_material.emission_energy_multiplier = 1.1
	selection_ring.material_override = ring_material
	selection_ring.visible = false
	add_child(selection_ring)

func _add_face_pips(face_value: int, normal: Vector3, axis_u: Vector3, axis_v: Vector3) -> void:
	var patterns := {
		1: [Vector2(0, 0)],
		2: [Vector2(-1, -1), Vector2(1, 1)],
		3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
		4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
		5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
		6: [Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)],
	}
	for grid_position: Vector2 in patterns[face_value]:
		var pip := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.066
		cylinder.bottom_radius = 0.066
		cylinder.height = 0.012
		cylinder.radial_segments = 18
		pip.mesh = cylinder
		pip.material_override = shared_pip_material
		pip.position = normal * 0.555 + axis_u * grid_position.x * 0.225 + axis_v * grid_position.y * 0.225
		pip.quaternion = Quaternion(Vector3.UP, normal)
		model_root.add_child(pip)

func _create_rounded_cube_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	]
	var subdivisions := 8
	for face in faces:
		var normal: Vector3 = face[0]
		var axis_u: Vector3 = face[1]
		var axis_v: Vector3 = face[2]
		for y in range(subdivisions):
			for x in range(subdivisions):
				var uv00 := Vector2(float(x) / subdivisions, float(y) / subdivisions)
				var uv10 := Vector2(float(x + 1) / subdivisions, float(y) / subdivisions)
				var uv11 := Vector2(float(x + 1) / subdivisions, float(y + 1) / subdivisions)
				var uv01 := Vector2(float(x) / subdivisions, float(y + 1) / subdivisions)
				_add_cube_vertex(surface, normal, axis_u, axis_v, uv00)
				_add_cube_vertex(surface, normal, axis_u, axis_v, uv11)
				_add_cube_vertex(surface, normal, axis_u, axis_v, uv10)
				_add_cube_vertex(surface, normal, axis_u, axis_v, uv00)
				_add_cube_vertex(surface, normal, axis_u, axis_v, uv01)
				_add_cube_vertex(surface, normal, axis_u, axis_v, uv11)
	surface.index()
	return surface.commit()

func _add_cube_vertex(surface: SurfaceTool, face_normal: Vector3, axis_u: Vector3, axis_v: Vector3, uv: Vector2) -> void:
	var half_size := 0.55
	var radius := 0.105
	var planar := face_normal * half_size
	planar += axis_u * lerpf(-half_size, half_size, uv.x)
	planar += axis_v * lerpf(-half_size, half_size, uv.y)
	var inner := half_size - radius
	var clamped := Vector3(
		clampf(planar.x, -inner, inner),
		clampf(planar.y, -inner, inner),
		clampf(planar.z, -inner, inner)
	)
	var offset := planar - clamped
	var vertex_normal := face_normal if offset.is_zero_approx() else offset.normalized()
	var rounded := clamped + vertex_normal * radius
	surface.set_normal(vertex_normal)
	surface.set_uv(uv)
	surface.add_vertex(rounded)

func _set_roll_rotation(progress: float, final_orientation: Quaternion, spin_angles: Vector3) -> void:
	var remaining := 1.0 - progress
	var spin := Quaternion(Vector3.UP, spin_angles.y * remaining)
	spin *= Quaternion(Vector3.RIGHT, spin_angles.x * remaining)
	spin *= Quaternion(Vector3.BACK, spin_angles.z * remaining)
	model_root.quaternion = (spin * final_orientation).normalized()

func _final_quaternion(face_value: int, yaw: float) -> Quaternion:
	var tilt := Vector3.ZERO
	match face_value:
		1:
			tilt = Vector3.ZERO
		2:
			tilt = Vector3(-PI / 2.0, 0, 0)
		3:
			tilt = Vector3(0, 0, PI / 2.0)
		4:
			tilt = Vector3(0, 0, -PI / 2.0)
		5:
			tilt = Vector3(PI / 2.0, 0, 0)
		6:
			tilt = Vector3(PI, 0, 0)
	return (Quaternion(Vector3.UP, yaw) * Quaternion.from_euler(tilt)).normalized()

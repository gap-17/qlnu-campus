extends CharacterBody3D
## 第三人称角色：WASD 相对镜头移动、奔跑、跳跃、F 切换飞行、鼠标环绕镜头、镜头防穿墙。

signal flight_changed(flying: bool)

const StudentVisualScript = preload("res://game/scripts/student_visual.gd")

const WALK_SPEED := 4.4
const RUN_SPEED := 8.0
const FLY_SPEED := 12.0
const FLY_BOOST_SPEED := 24.0
const JUMP_VELOCITY := 7.0
const GRAVITY := 22.0
const CAMERA_DISTANCE := 5.2
const MOUSE_PITCH_MIN := -1.15
const MOUSE_PITCH_MAX := 0.32
const GLIDE_FALL_SPEED := 6.0

var active := false
var flying := false
var gliding := false
var current_speed := 0.0

var visual_root: Node3D
var visual: Node3D
var camera_pivot: Node3D
var camera_pitch: Node3D
var camera: Camera3D

var camera_yaw := 0.0
var camera_pitch_value := -0.22
var camera_distance := CAMERA_DISTANCE
var _spawn := Vector3(0.0, 0.12, 10.0)
var _spawn_yaw := PI
var _bob_phase := 0.0
var _bounds := {"minX": -440.0, "maxX": 440.0, "minZ": -30.0, "maxZ": 740.0}


func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.74
	var collider := CollisionShape3D.new()
	collider.name = "Body"
	collider.shape = capsule
	collider.position = Vector3(0.0, 0.87, 0.0)
	add_child(collider)

	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	visual = StudentVisualScript.new()
	visual.name = "Student"
	visual_root.add_child(visual)

	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 1.58, 0.0)
	add_child(camera_pivot)

	camera_pitch = Node3D.new()
	camera_pitch.name = "CameraPitch"
	camera_pivot.add_child(camera_pitch)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 70.0
	camera.near = 0.08
	camera.far = 1800.0
	camera.position = Vector3(0.0, 0.0, camera_distance)
	camera.current = false
	camera_pitch.add_child(camera)

	GameState.gender_changed.connect(_on_gender_changed)
	visual.set_gender(GameState.gender)
	_bounds = CampusData.bounds()


func spawn_at(position: Vector3, yaw: float) -> void:
	_spawn = position
	_spawn_yaw = yaw
	reset_to_spawn()


func reset_to_spawn() -> void:
	position = _spawn
	velocity = Vector3.ZERO
	camera_yaw = _spawn_yaw
	camera_pitch_value = -0.22
	camera_distance = CAMERA_DISTANCE
	flying = false
	gliding = false
	current_speed = 0.0
	visual_root.rotation.y = camera_yaw
	camera_pivot.rotation.y = camera_yaw
	camera_pitch.rotation.x = camera_pitch_value
	camera.position.z = camera_distance
	if visual.has_method("set_motion"):
		visual.set_motion(0.0, false, true)


func set_active(value: bool) -> void:
	active = value
	camera.current = value
	if value:
		visual_root.rotation.y = camera_yaw
	else:
		velocity = Vector3.ZERO
		current_speed = 0.0
		if visual.has_method("set_motion"):
			visual.set_motion(0.0, false, true)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity: float = GameState.mouse_sensitivity
		camera_yaw -= event.relative.x * sensitivity
		var invert := -1.0 if GameState.invert_y else 1.0
		camera_pitch_value -= event.relative.y * sensitivity * invert
		camera_pitch_value = clampf(camera_pitch_value, MOUSE_PITCH_MIN, MOUSE_PITCH_MAX)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = clampf(camera_distance - 0.45, 2.6, 8.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = clampf(camera_distance + 0.45, 2.6, 8.0)


func _physics_process(delta: float) -> void:
	if not active:
		return

	if Input.is_action_just_pressed("fly"):
		if flying:
			flying = false
			gliding = not is_on_floor()
		else:
			flying = true
			gliding = false
		velocity.y = 0.0
		flight_changed.emit(flying)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var wish := right * input.x + forward * (-input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()

	var sprint := Input.is_action_pressed("sprint")

	if flying:
		var fly_speed := FLY_BOOST_SPEED if sprint else FLY_SPEED
		var target_x := wish.x * fly_speed
		var target_z := wish.z * fly_speed
		velocity.x = move_toward(velocity.x, target_x, 42.0 * delta)
		velocity.z = move_toward(velocity.z, target_z, 42.0 * delta)
		var vertical := 0.0
		if Input.is_action_pressed("jump"):
			vertical += fly_speed * 0.8
		if Input.is_action_pressed("fly_down"):
			vertical -= fly_speed * 0.8
		velocity.y = move_toward(velocity.y, vertical, 42.0 * delta)
	else:
		if is_on_floor():
			gliding = false
			if Input.is_action_just_pressed("jump"):
				velocity.y = JUMP_VELOCITY
		else:
			velocity.y -= GRAVITY * delta
			if gliding:
				velocity.y = maxf(velocity.y, -GLIDE_FALL_SPEED)

		var speed := RUN_SPEED if sprint else WALK_SPEED
		var acceleration := 34.0 if is_on_floor() else 10.0
		velocity.x = move_toward(velocity.x, wish.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, wish.z * speed, acceleration * delta)

	move_and_slide()
	current_speed = Vector2(velocity.x, velocity.z).length()

	_update_facing(delta, wish)
	_clamp_to_bounds()
	_update_animation(delta)


func _process(delta: float) -> void:
	if not active:
		return
	camera_pivot.rotation.y = camera_yaw
	camera_pitch.rotation.x = camera_pitch_value
	_update_camera_collision(delta)

	if not flying and is_on_floor() and current_speed > 0.4:
		_bob_phase += delta * (6.0 + current_speed * 0.8)
		camera_pivot.position.y = 1.58 + sin(_bob_phase) * 0.018
	else:
		camera_pivot.position.y = lerpf(camera_pivot.position.y, 1.58, clampf(delta * 8.0, 0.0, 1.0))


func _update_facing(delta: float, wish: Vector3) -> void:
	if wish.length() < 0.05:
		return
	var target_yaw := atan2(-wish.x, -wish.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, clampf(delta * 11.0, 0.0, 1.0))


func _update_animation(delta: float) -> void:
	if visual.has_method("set_motion"):
		visual.set_motion(current_speed, flying, is_on_floor())


func _update_camera_collision(delta: float) -> void:
	var from := camera_pivot.global_position
	var desired := camera_pitch.to_global(Vector3(0.0, 0.0, camera_distance))
	var target_z := camera_distance

	var query := PhysicsRayQueryParameters3D.create(from, desired, 1, [get_rid()])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target_z = maxf(0.75, from.distance_to(hit["position"]) - 0.28)

	camera.position.z = lerpf(camera.position.z, target_z, clampf(delta * 14.0, 0.0, 1.0))
	visual_root.visible = camera.position.z > 1.15


func _clamp_to_bounds() -> void:
	var min_x := float(_bounds.get("minX", -440.0)) + 2.0
	var max_x := float(_bounds.get("maxX", 440.0)) - 2.0
	var min_z := float(_bounds.get("minZ", -30.0)) + 2.0
	var max_z := float(_bounds.get("maxZ", 740.0)) - 2.0
	position.x = clampf(position.x, min_x, max_x)
	position.z = clampf(position.z, min_z, max_z)
	position.y = minf(position.y, 240.0)
	if position.y < -8.0:
		reset_to_spawn()


func _on_gender_changed(value: String) -> void:
	if visual == null:
		return
	visual.set_gender(value)


func heading_yaw() -> float:
	if visual_root != null:
		return visual_root.rotation.y
	return camera_yaw


func mode_label() -> String:
	if flying:
		return "飞行 / FLY"
	if gliding:
		return "缓降 / LANDING"
	return "步行 / WALK"
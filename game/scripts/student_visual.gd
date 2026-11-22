extends Node3D
## 程序化半写实低模大学生：连帽衫 / 牛仔裤 / 双肩包，男女两套比例与发型。
## 模型朝向 -Z（与 Godot 相机前方一致），由 Player 负责整体转向。

const SKIN := Color("#e5c3a6")
const EYE := Color("#2a2320")

var gender := "female"
var _rig: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _head: Node3D
var _phase := 0.0
var _move_speed := 0.0
var _flying := false
var _on_floor := true
var _rig_base_y := 0.0
var _built_gender := ""


func _ready() -> void:
	_build()


func set_gender(value: String) -> void:
	gender = value if value == "male" else "female"
	if is_inside_tree() and _built_gender != gender:
		_build()


func set_motion(speed: float, flying: bool, on_floor: bool) -> void:
	_move_speed = speed
	_flying = flying
	_on_floor = on_floor


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_built_gender = gender

	var male := gender == "male"
	var jacket_color := Color("#3d5872") if male else Color("#c98f82")
	var pants_color := Color("#2f3a44") if male else Color("#3d4d5c")
	var hair_color := Color("#2b2320") if male else Color("#3a2924")
	var shoe_color := Color("#e7e3da") if male else Color("#f0ece4")
	var backpack_color := Color("#2f3a3e") if male else Color("#6b5560")

	var jacket := _mat(jacket_color, 0.86)
	var pants := _mat(pants_color, 0.92)
	var skin := _mat(SKIN, 0.78)
	var hair := _mat(hair_color, 0.72)
	var shoes := _mat(shoe_color, 0.6)
	var backpack := _mat(backpack_color, 0.82)
	var eye := _mat(EYE, 0.35)

	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	# 模型脚底在建模坐标里略高于 0，这里下移，避免人物悬浮。
	_rig_base_y = -0.045
	_rig.position.y = _rig_base_y

	var hip_width := 0.20 if male else 0.18
	var shoulder := 0.25 if male else 0.215
	var torso_w := 0.44 if male else 0.385

	# 骨盆与躯干
	_add_box(_rig, "Pelvis", Vector3(torso_w * 0.92, 0.18, 0.26), Vector3(0.0, 0.97, 0.0), pants)
	_add_box(_rig, "Hoodie", Vector3(torso_w, 0.60, 0.28), Vector3(0.0, 1.35, 0.0), jacket)
	_add_box(_rig, "Hood", Vector3(torso_w * 0.72, 0.16, 0.20), Vector3(0.0, 1.62, 0.07), jacket)
	_add_box(_rig, "Pocket", Vector3(torso_w * 0.52, 0.14, 0.06), Vector3(0.0, 1.20, -0.155), _mat(jacket_color.darkened(0.08), 0.88))
	_add_box(_rig, "DrawstringL", Vector3(0.025, 0.19, 0.025), Vector3(-0.055, 1.50, -0.15), _mat(Color("#f4efe6"), 0.8))
	_add_box(_rig, "DrawstringR", Vector3(0.025, 0.19, 0.025), Vector3(0.055, 1.50, -0.15), _mat(Color("#f4efe6"), 0.8))

	# 双肩包
	_add_box(_rig, "Backpack", Vector3(0.31, 0.38, 0.16), Vector3(0.0, 1.34, 0.21), backpack)
	_add_box(_rig, "BackpackPocket", Vector3(0.23, 0.16, 0.05), Vector3(0.0, 1.23, 0.30), _mat(backpack_color.lightened(0.08), 0.84))
	_add_box(_rig, "StrapL", Vector3(0.045, 0.42, 0.03), Vector3(-0.13, 1.37, -0.15), backpack)
	_add_box(_rig, "StrapR", Vector3(0.045, 0.42, 0.03), Vector3(0.13, 1.37, -0.15), backpack)

	# 脖子与头
	_add_box(_rig, "Neck", Vector3(0.11, 0.10, 0.11), Vector3(0.0, 1.68, 0.0), skin)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, 1.83, 0.0)
	_rig.add_child(_head)
	_add_sphere(_head, "Skull", Vector3(0.165, 0.19, 0.16), Vector3(0.0, 0.0, 0.0), skin)
	_add_sphere(_head, "HairCap", Vector3(0.176, 0.15, 0.172), Vector3(0.0, 0.055, 0.012), hair)
	if male:
		_add_sphere(_head, "HairFringe", Vector3(0.15, 0.06, 0.06), Vector3(0.0, 0.11, -0.12), hair)
	else:
		_add_sphere(_head, "Ponytail", Vector3(0.075, 0.20, 0.075), Vector3(0.0, -0.06, 0.16), hair)
		_add_sphere(_head, "HairSideL", Vector3(0.05, 0.16, 0.06), Vector3(-0.15, -0.03, 0.02), hair)
		_add_sphere(_head, "HairSideR", Vector3(0.05, 0.16, 0.06), Vector3(0.15, -0.03, 0.02), hair)
	_add_sphere(_head, "EyeL", Vector3(0.018, 0.022, 0.012), Vector3(-0.062, 0.01, -0.152), eye)
	_add_sphere(_head, "EyeR", Vector3(0.018, 0.022, 0.012), Vector3(0.062, 0.01, -0.152), eye)
	_add_box(_head, "Mouth", Vector3(0.045, 0.012, 0.01), Vector3(0.0, -0.065, -0.155), _mat(Color("#a0705f"), 0.8))
	_add_box(_head, "EarL", Vector3(0.03, 0.06, 0.05), Vector3(-0.165, -0.005, 0.015), skin)
	_add_box(_head, "EarR", Vector3(0.03, 0.06, 0.05), Vector3(0.165, -0.005, 0.015), skin)

	# 手臂：枢轴在肩部，向下摆动
	_arm_left = Node3D.new()
	_arm_left.name = "ArmLeft"
	_arm_left.position = Vector3(-shoulder, 1.55, 0.0)
	_rig.add_child(_arm_left)
	_add_capsule(_arm_left, "ArmL", 0.062, 0.50, Vector3(0.0, -0.27, 0.0), jacket)
	_add_sphere(_arm_left, "HandL", Vector3(0.055, 0.07, 0.05), Vector3(0.0, -0.55, 0.0), skin)

	_arm_right = Node3D.new()
	_arm_right.name = "ArmRight"
	_arm_right.position = Vector3(shoulder, 1.55, 0.0)
	_rig.add_child(_arm_right)
	_add_capsule(_arm_right, "ArmR", 0.062, 0.50, Vector3(0.0, -0.27, 0.0), jacket)
	_add_sphere(_arm_right, "HandR", Vector3(0.055, 0.07, 0.05), Vector3(0.0, -0.55, 0.0), skin)

	# 腿：枢轴在胯部
	_leg_left = Node3D.new()
	_leg_left.name = "LegLeft"
	_leg_left.position = Vector3(-hip_width * 0.5, 0.92, 0.0)
	_rig.add_child(_leg_left)
	_add_capsule(_leg_left, "LegL", 0.078, 0.76, Vector3(0.0, -0.40, 0.0), pants)
	_add_box(_leg_left, "ShoeL", Vector3(0.15, 0.11, 0.30), Vector3(0.0, -0.82, -0.055), shoes)

	_leg_right = Node3D.new()
	_leg_right.name = "LegRight"
	_leg_right.position = Vector3(hip_width * 0.5, 0.92, 0.0)
	_rig.add_child(_leg_right)
	_add_capsule(_leg_right, "LegR", 0.078, 0.76, Vector3(0.0, -0.40, 0.0), pants)
	_add_box(_leg_right, "ShoeR", Vector3(0.15, 0.11, 0.30), Vector3(0.0, -0.82, -0.055), shoes)

	# 身高微调
	var target_height := 1.78 if male else 1.72
	var current_height := 2.0
	scale = Vector3.ONE * (target_height / current_height) * 1.0


func _process(delta: float) -> void:
	if _rig == null:
		return
	var speed_ratio := clampf(_move_speed / 7.0, 0.0, 1.0)
	var moving := _move_speed > 0.15
	_phase += delta * (lerpf(5.0, 11.0, speed_ratio) if moving else 1.3)

	var target_leg_left := 0.0
	var target_leg_right := 0.0
	var target_arm_left := 0.0
	var target_arm_right := 0.0
	var target_arm_left_z := 0.0
	var target_arm_right_z := 0.0
	var target_rig_y := _rig_base_y
	var target_lean := 0.0

	if _flying:
		target_leg_left = 0.34
		target_leg_right = 0.22
		target_arm_left_z = -1.18
		target_arm_right_z = 1.18
		target_arm_left = -0.25
		target_arm_right = -0.25
		target_lean = -0.22
		target_rig_y = 0.06
	elif moving:
		var swing := sin(_phase) * (0.34 + speed_ratio * 0.34)
		target_leg_left = swing
		target_leg_right = -swing
		target_arm_left = -swing * 0.9
		target_arm_right = swing * 0.9
		target_arm_left_z = -0.06
		target_arm_right_z = 0.06
		target_rig_y = _rig_base_y + absf(sin(_phase * 2.0)) * 0.022 * (0.4 + speed_ratio)
		target_lean = -0.03 - speed_ratio * 0.08
	else:
		target_rig_y = _rig_base_y + sin(_phase) * 0.006
		target_arm_left_z = -0.04
		target_arm_right_z = 0.04

	var blend := clampf(delta * 12.0, 0.0, 1.0)
	_leg_left.rotation.x = lerpf(_leg_left.rotation.x, target_leg_left, blend)
	_leg_right.rotation.x = lerpf(_leg_right.rotation.x, target_leg_right, blend)
	_arm_left.rotation.x = lerpf(_arm_left.rotation.x, target_arm_left, blend)
	_arm_right.rotation.x = lerpf(_arm_right.rotation.x, target_arm_right, blend)
	_arm_left.rotation.z = lerpf(_arm_left.rotation.z, target_arm_left_z, blend)
	_arm_right.rotation.z = lerpf(_arm_right.rotation.z, target_arm_right_z, blend)
	_rig.position.y = lerpf(_rig.position.y, target_rig_y, blend)
	_rig.rotation.x = lerpf(_rig.rotation.x, target_lean, blend)

	if not _on_floor and not _flying:
		_leg_left.rotation.x = lerpf(_leg_left.rotation.x, -0.18, blend)
		_leg_right.rotation.x = lerpf(_leg_right.rotation.x, 0.22, blend)


func _mat(color: Color, roughness := 0.86) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.scale = size
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_capsule(parent: Node3D, node_name: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 4
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance
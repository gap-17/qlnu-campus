extends Node3D
## 由同一份校园 JSON 程序化生成 v0.2 校园场景。
## 几何全部使用 Godot 原生网格 + MultiMesh，避免依赖外部 GLB 也能跑通。

signal built(stats: Dictionary)

const CATEGORY_COLORS := {
	"gate": Color("#7c7f82"),
	"teaching": Color("#a9553f"),
	"lab": Color("#7e9aa6"),
	"library": Color("#8c3b2e"),
	"public": Color("#c9b79e"),
	"canteen": Color("#b5654a"),
	"dorm": Color("#d9d2c6"),
	"gym": Color("#6f8f8a"),
	"logistics": Color("#bfae94"),
}

const ROOF_COLORS := {
	"gate": Color("#4f5a60"),
	"teaching": Color("#6f6257"),
	"lab": Color("#5d747d"),
	"library": Color("#5e2a22"),
	"public": Color("#8b7c6b"),
	"canteen": Color("#6e3b2a"),
	"dorm": Color("#8a7f70"),
	"gym": Color("#4f6b67"),
	"logistics": Color("#847a6c"),
}

var _materials: Dictionary = {}
var _window_transforms: Array = []
var _window_colors: Array = []
var _dash_transforms: Array = []
var _tree_spots: Array = []
var stats: Dictionary = {}


func build_all() -> void:
	if not CampusData.ensure_loaded():
		push_error("[qlnu] 校园数据未加载，场景构建中止")
		return

	_materials.clear()
	_window_transforms.clear()
	_window_colors.clear()
	_dash_transforms.clear()
	_tree_spots.clear()
	stats = {"buildings": 0, "windows": 0, "trees": 0, "lamps": 0, "labels": 0, "colliders": 0}

	_build_environment()
	_build_ground()
	_build_roads()
	_build_plazas()
	_build_water()
	_build_tracks()
	_build_buildings()
	_build_window_mesh()
	_build_trees()
	_build_lamps()
	_build_labels()

	built.emit(stats)
	print("[qlnu] campus built: ", JSON.stringify(stats), " via ", CampusData.buildings_source)


## ---------------------------------------------------------------- materials

func _standard(key: String, color: Color, roughness := 0.9, metallic := 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_materials[key] = material
	return material


func _flat(key: String, color: Color, roughness := 0.95) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = material
	return material


func _water_material() -> StandardMaterial3D:
	if _materials.has("water"):
		return _materials["water"] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.42, 0.53, 0.92)
	material.roughness = 0.16
	material.metallic = 0.22
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["water"] = material
	return material


func _window_material() -> StandardMaterial3D:
	if _materials.has("windows"):
		return _materials["windows"] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.19, 0.27, 0.33)
	material.roughness = 0.22
	material.metallic = 0.45
	material.vertex_color_use_as_albedo = true
	_materials["windows"] = material
	return material


func _tree_canopy_material() -> StandardMaterial3D:
	if _materials.has("canopy"):
		return _materials["canopy"] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.roughness = 0.95
	material.vertex_color_use_as_albedo = true
	_materials["canopy"] = material
	return material


## ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.30, 0.52, 0.78)
	sky_material.sky_horizon_color = Color(0.74, 0.84, 0.91)
	sky_material.sky_curve = 0.18
	sky_material.ground_bottom_color = Color(0.20, 0.24, 0.21)
	sky_material.ground_horizon_color = Color(0.72, 0.79, 0.80)
	sky_material.sun_angle_max = 24.0
	sky_material.sun_curve = 0.06

	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.82
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.72, 0.80, 0.86)
	environment.fog_light_energy = 0.9
	environment.fog_density = 0.0011
	environment.fog_aerial_perspective = 0.3

	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.18
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 170.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = Color(0.70, 0.80, 0.95)
	fill.light_energy = 0.28
	fill.rotation_degrees = Vector3(-24.0, 138.0, 0.0)
	fill.shadow_enabled = false
	add_child(fill)


## ---------------------------------------------------------------- helpers

func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material, cast_shadow := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _flat_polygon(node_name: String, points: Array, y: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var count := points.size()
	if count < 3:
		return null
	var center := Vector2.ZERO
	for point in points:
		center += Vector2(float(point[0]), float(point[1]))
	center /= float(count)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(count):
		var a: Array = points[index]
		var b: Array = points[(index + 1) % count]
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(center.x, y, center.y))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(float(a[0]), y, float(a[1])))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(float(b[0]), y, float(b[1])))
	var mesh := surface.commit()

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent == null:
		add_child(instance)
	else:
		parent.add_child(instance)
	return instance


func _add_segment(parent: Node3D, node_name: String, a: Vector2, b: Vector2, width: float, y: float, material: Material) -> MeshInstance3D:
	var dx := b.x - a.x
	var dz := b.y - a.y
	var length := sqrt(dx * dx + dz * dz)
	if length < 0.01:
		return null
	var instance := _add_box(parent, node_name, Vector3(length, 0.04, width), Vector3((a.x + b.x) * 0.5, y, (a.y + b.y) * 0.5), material)
	instance.rotation.y = -atan2(dz, dx)
	return instance


func _distance_to_segment(px: float, pz: float, ax: float, az: float, bx: float, bz: float) -> float:
	var abx := bx - ax
	var abz := bz - az
	var length_sq := abx * abx + abz * abz
	if length_sq < 0.0001:
		return sqrt((px - ax) * (px - ax) + (pz - az) * (pz - az))
	var t := clampf(((px - ax) * abx + (pz - az) * abz) / length_sq, 0.0, 1.0)
	var cx := ax + abx * t
	var cz := az + abz * t
	return sqrt((px - cx) * (px - cx) + (pz - cz) * (pz - cz))


func _point_in_polygon(x: float, z: float, polygon: Array) -> bool:
	var inside := false
	var count := polygon.size()
	if count < 3:
		return false
	var j := count - 1
	for i in range(count):
		var xi := float(polygon[i][0])
		var zi := float(polygon[i][1])
		var xj := float(polygon[j][0])
		var zj := float(polygon[j][1])
		if ((zi > z) != (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi):
			inside = not inside
		j = i
	return inside


## ---------------------------------------------------------------- ground / roads

func _build_ground() -> void:
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_texture = _make_grass_texture()
	ground_material.uv1_scale = Vector3(58.0, 52.0, 1.0)
	ground_material.roughness = 1.0
	_materials["grass"] = ground_material

	var plane := PlaneMesh.new()
	plane.size = Vector2(1300.0, 1100.0)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = ground_material
	ground.position = Vector3(0.0, 0.0, 355.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	var far_plane := PlaneMesh.new()
	far_plane.size = Vector2(3600.0, 3600.0)
	var far_ground := MeshInstance3D.new()
	far_ground.name = "GroundFar"
	far_ground.mesh = far_plane
	far_ground.material_override = _flat("far-ground", Color(0.34, 0.42, 0.30), 1.0)
	far_ground.position = Vector3(0.0, -0.08, 355.0)
	far_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far_ground)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1500.0, 1.0, 1300.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 355.0)
	body.add_child(shape)
	add_child(body)
	stats["colliders"] = int(stats["colliders"]) + 1


func _make_grass_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	for y in range(size):
		for x in range(size):
			var tone := rng.randf_range(-0.045, 0.045)
			var blade := 1.0 if rng.randf() > 0.86 else 0.0
			var color := Color(
				clampf(0.415 + tone - blade * 0.035, 0.0, 1.0),
				clampf(0.505 + tone + blade * 0.03, 0.0, 1.0),
				clampf(0.345 + tone - blade * 0.02, 0.0, 1.0)
			)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _build_roads() -> void:
	var roads_root := Node3D.new()
	roads_root.name = "Roads"
	add_child(roads_root)

	var sidewalk := _standard("sidewalk", Color("#9aa1a0"), 0.96)
	var asphalt := _standard("asphalt", Color("#3f4950"), 0.97)

	var roads: Array = CampusData.campus.get("roads", [])
	for road in roads:
		var points: Array = road.get("points", [])
		var width := float(road.get("width", 12.0))
		for i in range(points.size() - 1):
			var a := Vector2(float(points[i][0]), float(points[i][1]))
			var b := Vector2(float(points[i + 1][0]), float(points[i + 1][1]))
			_add_segment(roads_root, "Sidewalk", a, b, width + 7.0, 0.018, sidewalk)
			_add_segment(roads_root, "Asphalt", a, b, width, 0.045, asphalt)
			_collect_dashes(a, b)

	if _dash_transforms.is_empty():
		return
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3.ONE
	var dash_material := _standard("dash", Color(0.92, 0.92, 0.86), 0.8)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = dash_mesh
	multi.instance_count = _dash_transforms.size()
	for i in range(_dash_transforms.size()):
		multi.set_instance_transform(i, _dash_transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "RoadDashes"
	instance.multimesh = multi
	instance.material_override = dash_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-600, -10, -100), Vector3(1200, 40, 900))
	roads_root.add_child(instance)


func _collect_dashes(a: Vector2, b: Vector2) -> void:
	var dx := b.x - a.x
	var dz := b.y - a.y
	var length := sqrt(dx * dx + dz * dz)
	if length < 14.0:
		return
	var direction := Vector2(dx, dz) / length
	var angle := -atan2(dz, dx)
	var distance := 8.0
	while distance < length - 8.0:
		var point := a + direction * distance
		var basis := Basis(Vector3.UP, angle).scaled(Vector3(3.4, 0.03, 0.24))
		_dash_transforms.append(Transform3D(basis, Vector3(point.x, 0.085, point.y)))
		distance += 12.0


func _build_plazas() -> void:
	var plazas_root := Node3D.new()
	plazas_root.name = "Plazas"
	add_child(plazas_root)
	var plaza_material := _flat("plaza", Color("#a79c8b"), 0.94)
	var plaza_line := _flat("plaza-line", Color("#cfc6b6"), 0.9)
	var plazas: Array = CampusData.campus.get("plazas", [])
	for plaza in plazas:
		var polygon: Array = plaza.get("polygon", [])
		_flat_polygon("Plaza", polygon, 0.045, plaza_material, plazas_root)
		# 内圈一条浅色铺装，增加广场层次。
		var center := Vector2.ZERO
		for point in polygon:
			center += Vector2(float(point[0]), float(point[1]))
		if polygon.is_empty():
			continue
		center /= float(polygon.size())
		var inner: Array = []
		for point in polygon:
			inner.append([
				center.x + (float(point[0]) - center.x) * 0.86,
				center.y + (float(point[1]) - center.y) * 0.86,
			])
		_flat_polygon("PlazaInner", inner, 0.052, plaza_line, plazas_root)


func _build_water() -> void:
	var water_root := Node3D.new()
	water_root.name = "Water"
	add_child(water_root)
	var stone := _flat("water-stone", Color("#c3b7a2"), 0.9)
	var polygons: Array = CampusData.campus.get("water", [])
	for polygon in polygons:
		if polygon.size() < 3:
			continue
		var center := Vector2.ZERO
		for point in polygon:
			center += Vector2(float(point[0]), float(point[1]))
		center /= float(polygon.size())
		var outer: Array = []
		var inner: Array = []
		for point in polygon:
			outer.append([center.x + (float(point[0]) - center.x) * 1.07, center.y + (float(point[1]) - center.y) * 1.07])
			inner.append([center.x + (float(point[0]) - center.x) * 0.95, center.y + (float(point[1]) - center.y) * 0.95])
		_flat_polygon("WaterRim", outer, 0.03, stone, water_root)
		_flat_polygon("WaterSurface", inner, 0.06, _water_material(), water_root)

	var island_grass := _flat("island-grass", Color("#6f8a5a"), 0.98)
	for polygon in CampusData.campus.get("waterIslands", []):
		if polygon.size() < 3:
			continue
		var center := Vector2.ZERO
		for point in polygon:
			center += Vector2(float(point[0]), float(point[1]))
		center /= float(polygon.size())
		var inner: Array = []
		for point in polygon:
			inner.append([
				center.x + (float(point[0]) - center.x) * 0.9,
				center.y + (float(point[1]) - center.y) * 0.9,
			])
		_flat_polygon("IslandRim", polygon, 0.075, stone, water_root)
		_flat_polygon("IslandGrass", inner, 0.09, island_grass, water_root)


func _build_tracks() -> void:
	var tracks_root := Node3D.new()
	tracks_root.name = "Tracks"
	add_child(tracks_root)

	var track_material := _flat("track-red", Color("#b0553f"), 0.96)
	var field_material := _flat("field-green", Color("#5d8553"), 0.98)
	var court_material := _flat("court", Color("#a75f3d"), 0.96)
	var line_material := _flat("field-line", Color("#f0eee4"), 0.85)

	var tracks: Array = CampusData.campus.get("tracks", [])
	for track in tracks:
		var node := Node3D.new()
		node.name = str(track.get("id", "track"))
		node.position = Vector3(float(track.get("x", 0.0)), 0.0, float(track.get("z", 0.0)))
		node.rotation.y = -deg_to_rad(float(track.get("rot", 0.0)))
		tracks_root.add_child(node)
		var w := float(track.get("w", 40.0))
		var d := float(track.get("d", 60.0))
		var kind := str(track.get("kind", "field"))

		if kind == "track":
			var rx := w * 0.5
			var rz := d * 0.5
			var track_width := 9.0
			var lane_width := 1.5
			_add_ellipse(node, "TrackSurface", rx, rz, 0.05, 0.045, track_material)
			_add_ellipse(node, "Infield", rx - track_width, rz - track_width, 0.05, 0.048, field_material)
			for lane in range(1, 6):
				_add_ellipse_ring(
					node,
					"LaneLine%d" % lane,
					rx - track_width + float(lane) * lane_width,
					rz - track_width + float(lane) * lane_width,
					0.12,
					0.074,
					line_material
				)
			_add_ellipse_ring(node, "TrackOuter", rx - 0.12, rz - 0.12, 0.24, 0.076, line_material)
			_add_ellipse_ring(node, "TrackInner", rx - track_width, rz - track_width, 0.24, 0.078, line_material)
			_add_box(node, "StartLine", Vector3(0.2, 0.012, track_width), Vector3(0.0, 0.08, -rz + track_width * 0.5), line_material)

			var fw := minf(63.5, (rx - track_width) * 1.55)
			var fd := minf(101.0, (rz - track_width) * 1.25)
			var pitch := _flat("pitch-grass", Color("#4f7a47"), 0.98)
			var pitch_alt := _flat("pitch-grass-alt", Color("#5b8a50"), 0.98)
			_add_box(node, "Pitch", Vector3(fw, 0.02, fd), Vector3(0.0, 0.07, 0.0), pitch)
			var stripes := 9
			var stripe_depth := fd / float(stripes)
			for i in range(stripes):
				if i % 2 == 0:
					_add_box(
						node,
						"PitchStripe",
						Vector3(fw - 0.4, 0.012, stripe_depth),
						Vector3(0.0, 0.079, -fd * 0.5 + stripe_depth * (float(i) + 0.5)),
						pitch_alt
					)
			_add_box(node, "PitchBorderN", Vector3(fw, 0.012, 0.2), Vector3(0.0, 0.088, -fd * 0.5), line_material)
			_add_box(node, "PitchBorderS", Vector3(fw, 0.012, 0.2), Vector3(0.0, 0.088, fd * 0.5), line_material)
			_add_box(node, "PitchBorderW", Vector3(0.2, 0.012, fd), Vector3(-fw * 0.5, 0.088, 0.0), line_material)
			_add_box(node, "PitchBorderE", Vector3(0.2, 0.012, fd), Vector3(fw * 0.5, 0.088, 0.0), line_material)
			_add_box(node, "PitchCenter", Vector3(fw, 0.012, 0.2), Vector3(0.0, 0.088, 0.0), line_material)
			_add_ring(node, "PitchCircle", 9.15, 0.09, line_material)
			for side in [-1.0, 1.0]:
				var area_front_z := float(side) * (fd * 0.5 - 16.5)
				var area_side_z := float(side) * (fd * 0.5 - 8.25)
				var goal_front_z := float(side) * (fd * 0.5 - 5.5)
				var goal_side_z := float(side) * (fd * 0.5 - 2.75)
				_add_box(node, "PenaltyFront", Vector3(40.3, 0.012, 0.2), Vector3(0.0, 0.089, area_front_z), line_material)
				_add_box(node, "PenaltySide", Vector3(0.2, 0.012, 16.5), Vector3(-20.15, 0.089, area_side_z), line_material)
				_add_box(node, "PenaltySide", Vector3(0.2, 0.012, 16.5), Vector3(20.15, 0.089, area_side_z), line_material)
				_add_box(node, "GoalAreaFront", Vector3(18.3, 0.012, 0.2), Vector3(0.0, 0.09, goal_front_z), line_material)
				_add_box(node, "GoalAreaSide", Vector3(0.2, 0.012, 5.5), Vector3(-9.15, 0.09, goal_side_z), line_material)
				_add_box(node, "GoalAreaSide", Vector3(0.2, 0.012, 5.5), Vector3(9.15, 0.09, goal_side_z), line_material)
				_add_box(node, "GoalPost", Vector3(0.18, 2.4, 0.18), Vector3(-3.66, 1.2, float(side) * fd * 0.5), line_material)
				_add_box(node, "GoalPost", Vector3(0.18, 2.4, 0.18), Vector3(3.66, 1.2, float(side) * fd * 0.5), line_material)
				_add_box(node, "GoalCrossbar", Vector3(7.5, 0.18, 0.18), Vector3(0.0, 2.4, float(side) * fd * 0.5), line_material)
		elif kind == "basketball":
			_add_box(node, "Court", Vector3(w, 0.05, d), Vector3(0.0, 0.05, 0.0), court_material)
			_add_box(node, "BorderN", Vector3(w - 3.0, 0.012, 0.22), Vector3(0.0, 0.08, -d * 0.5 + 1.5), line_material)
			_add_box(node, "BorderS", Vector3(w - 3.0, 0.012, 0.22), Vector3(0.0, 0.08, d * 0.5 - 1.5), line_material)
			_add_box(node, "BorderW", Vector3(0.22, 0.012, d - 3.0), Vector3(-w * 0.5 + 1.5, 0.08, 0.0), line_material)
			_add_box(node, "BorderE", Vector3(0.22, 0.012, d - 3.0), Vector3(w * 0.5 - 1.5, 0.08, 0.0), line_material)
			_add_box(node, "HalfLine", Vector3(0.22, 0.012, d - 3.0), Vector3(0.0, 0.08, 0.0), line_material)
			_add_ring(node, "CenterCircle", 5.6, 0.08, line_material)
		else:
			_add_box(node, "Field", Vector3(w, 0.05, d), Vector3(0.0, 0.05, 0.0), field_material)
			_add_box(node, "BorderN", Vector3(w - 4.0, 0.012, 0.22), Vector3(0.0, 0.08, -d * 0.5 + 2.0), line_material)
			_add_box(node, "BorderS", Vector3(w - 4.0, 0.012, 0.22), Vector3(0.0, 0.08, d * 0.5 - 2.0), line_material)
			_add_box(node, "BorderW", Vector3(0.22, 0.012, d - 4.0), Vector3(-w * 0.5 + 2.0, 0.08, 0.0), line_material)
			_add_box(node, "BorderE", Vector3(0.22, 0.012, d - 4.0), Vector3(w * 0.5 - 2.0, 0.08, 0.0), line_material)
			_add_box(node, "HalfLine", Vector3(0.22, 0.012, d - 4.0), Vector3(0.0, 0.08, 0.0), line_material)
			_add_ring(node, "CenterCircle", 6.0, 0.08, line_material)


func _add_ellipse(parent: Node3D, node_name: String, radius_x: float, radius_z: float, height: float, y: float, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = height
	cylinder.radial_segments = 64
	cylinder.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = cylinder
	instance.material_override = material
	instance.scale = Vector3(radius_x, 1.0, radius_z)
	instance.position = Vector3(0.0, y, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_ellipse_ring(parent: Node3D, node_name: String, radius_x: float, radius_z: float, thickness: float, y: float, material: Material) -> MeshInstance3D:
	var segments := 96
	var half := thickness * 0.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var ix0 := cos(a0) * (radius_x - half)
		var iz0 := sin(a0) * (radius_z - half)
		var ox0 := cos(a0) * (radius_x + half)
		var oz0 := sin(a0) * (radius_z + half)
		var ix1 := cos(a1) * (radius_x - half)
		var iz1 := sin(a1) * (radius_z - half)
		var ox1 := cos(a1) * (radius_x + half)
		var oz1 := sin(a1) * (radius_z + half)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(ix0, y, iz0))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(ox0, y, oz0))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(ox1, y, oz1))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(ix0, y, iz0))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(ox1, y, oz1))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(ix1, y, iz1))
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_ring(parent: Node3D, node_name: String, radius: float, y: float, material: Material) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.22
	torus.outer_radius = radius + 0.22
	torus.rings = 48
	torus.ring_segments = 6
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = torus
	instance.material_override = material
	instance.position = Vector3(0.0, y, 0.0)
	instance.scale = Vector3(1.0, 0.08, 1.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## ---------------------------------------------------------------- buildings

func _build_buildings() -> void:
	var buildings_root := Node3D.new()
	buildings_root.name = "Buildings"
	add_child(buildings_root)

	for building in CampusData.buildings:
		var rect: Dictionary = building.get("rect", {})
		if rect.is_empty():
			continue
		var category := str(building.get("category", "public"))
		var w := float(rect.get("w", 20.0))
		var d := float(rect.get("d", 20.0))
		var h := float(building.get("height_m", 12.0))
		var rot := deg_to_rad(float(rect.get("rot", 0.0)))

		var node := Node3D.new()
		node.name = str(building.get("id", "building"))
		node.position = Vector3(float(rect.get("x", 0.0)), 0.0, float(rect.get("z", 0.0)))
		node.rotation.y = -rot
		buildings_root.add_child(node)

		if category == "gate":
			_build_gate(node, building, w, h, d)
			stats["buildings"] = int(stats["buildings"]) + 1
			continue

		var wall := _standard("wall-" + category, CATEGORY_COLORS.get(category, Color("#d4c0ae")), 0.88)
		var roof := _standard("roof-" + category, ROOF_COLORS.get(category, Color("#8b7c6b")), 0.92)

		_add_box(node, "Body", Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), wall, true)
		_add_box(node, "RoofCap", Vector3(w + 1.0, 0.7, d + 1.0), Vector3(0.0, h + 0.35, 0.0), roof, true)

		_add_roof_units(node, building, w, h, d)
		_add_entrance(node, building, w, h, d, rot)
		_add_landmark_details(node, building, w, h, d, rot)
		_add_building_collider(node, w, h, d)
		_collect_windows(building, node, w, h, d)

		stats["buildings"] = int(stats["buildings"]) + 1


func _add_roof_units(node: Node3D, building: Dictionary, w: float, h: float, d: float) -> void:
	if h < 12.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(str(building.get("id", ""))))
	var unit_count := rng.randi_range(1, 3)
	var material := _standard("roof-unit", Color("#b9b3a6"), 0.9)
	for i in range(unit_count):
		var size := Vector3(rng.randf_range(3.0, 7.0), rng.randf_range(1.0, 2.2), rng.randf_range(2.5, 5.0))
		var pos := Vector3(
			rng.randf_range(-w * 0.5 + 5.0, w * 0.5 - 5.0),
			h + 0.7 + size.y * 0.5,
			rng.randf_range(-d * 0.5 + 4.0, d * 0.5 - 4.0)
		)
		_add_box(node, "RoofUnit", size, pos, material)


func _add_entrance(node: Node3D, building: Dictionary, w: float, h: float, d: float, rot: float) -> void:
	if not building.has("entrance"):
		return
	var rect: Dictionary = building.get("rect", {})
	var center := Vector3(float(rect.get("x", 0.0)), 0.0, float(rect.get("z", 0.0)))
	var entrance: Dictionary = building.get("entrance", {})
	var world_entrance := Vector3(float(entrance.get("x", 0.0)), 0.0, float(entrance.get("z", 0.0)))
	var local := Basis(Vector3.UP, rot) * (world_entrance - center)

	var opening := clampf(minf(w, d) * 0.3, 4.0, 8.5)
	var door_material := _standard("door", Color("#33424a"), 0.4, 0.25)
	var stone := _standard("entrance-stone", Color("#c6c0b3"), 0.9)
	var awning := _standard("awning", Color("#cfae86"), 0.85)

	if absf(local.x) > absf(local.z):
		var side := 1.0 if local.x >= 0.0 else -1.0
		_add_box(node, "Door", Vector3(0.22, 3.4, opening), Vector3(side * (w * 0.5 + 0.08), 1.7, 0.0), door_material)
		_add_box(node, "Step", Vector3(2.4, 0.24, opening + 4.0), Vector3(side * (w * 0.5 + 1.0), 0.12, 0.0), stone)
		var canopy := _add_box(node, "Canopy", Vector3(3.0, 0.3, opening + 4.0), Vector3(side * (w * 0.5 + 1.2), 4.1, 0.0), awning, true)
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		var side := 1.0 if local.z >= 0.0 else -1.0
		_add_box(node, "Door", Vector3(opening, 3.4, 0.22), Vector3(0.0, 1.7, side * (d * 0.5 + 0.08)), door_material)
		_add_box(node, "Step", Vector3(opening + 4.0, 0.24, 2.4), Vector3(0.0, 0.12, side * (d * 0.5 + 1.0)), stone)
		var canopy := _add_box(node, "Canopy", Vector3(opening + 4.0, 0.3, 3.0), Vector3(0.0, 4.1, side * (d * 0.5 + 1.2)), awning, true)
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _add_landmark_details(node: Node3D, building: Dictionary, w: float, h: float, d: float, rot: float) -> void:
	var building_id := str(building.get("id", ""))
	var glass := _standard("glass", Color("#597487"), 0.16, 0.55)
	var rail := _standard("column", Color("#c9c3b6"), 0.86)
	var stone := _standard("stone", Color("#c6c0b3"), 0.9)

	if building_id == "library":
		_add_box(node, "GlassCurtain", Vector3(w * 0.74, h * 0.74, 0.9), Vector3(0.0, h * 0.42, -d * 0.5 - 0.7), glass)
		for i in range(6):
			var x := -w * 0.4 + i * (w * 0.8 / 5.0)
			_add_box(node, "LibraryColumn", Vector3(1.9, h * 0.94, 1.9), Vector3(x, h * 0.47, -d * 0.5 - 2.4), rail, true)
		for i in range(3):
			_add_box(node, "LibraryStep", Vector3(w * 0.5 + i * 5.0, 0.3, 2.4), Vector3(0.0, 0.15, -d * 0.5 - 4.0 - i * 2.3), stone)
		_add_box(node, "Lantern", Vector3(24.0, 9.0, 22.0), Vector3(0.0, h + 4.6, 0.0), glass, true)
		_add_box(node, "LanternCap", Vector3(27.0, 0.7, 25.0), Vector3(0.0, h + 9.4, 0.0), _standard("roof-library", ROOF_COLORS["library"], 0.9), true)

	elif building_id == "gym":
		var dome_material := _standard("dome", Color("#93b7bd"), 0.42, 0.3)
		var dome := SphereMesh.new()
		dome.radius = 1.0
		dome.height = 1.0
		dome.is_hemisphere = true
		dome.radial_segments = 32
		dome.rings = 14
		var dome_instance := MeshInstance3D.new()
		dome_instance.name = "Dome"
		dome_instance.mesh = dome
		dome_instance.material_override = dome_material
		dome_instance.scale = Vector3(w * 0.52, 10.0, d * 0.62)
		dome_instance.position = Vector3(0.0, h - 1.4, 0.0)
		dome_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(dome_instance)

	elif building_id == "admin":
		_add_box(node, "AdminCanopy", Vector3(26.0, 0.8, 10.0), Vector3(0.0, 6.1, -d * 0.5 - 3.4), stone)
		for x in [-9.5, 9.5]:
			_add_box(node, "AdminColumn", Vector3(1.1, 6.1, 1.1), Vector3(float(x), 3.05, -d * 0.5 - 7.6), rail)

	elif building_id == "activity-center":
		_add_box(node, "ActivityStrip", Vector3(w * 0.64, 5.4, 0.55), Vector3(0.0, 6.2, -d * 0.5 - 0.4), glass)

	if str(building.get("category", "")) == "canteen":
		var awning_color := Color("#c9a07a") if building_id == "canteen-2" else Color("#d0b590")
		_add_box(node, "CanteenAwning", Vector3(w * 0.7, 0.5, 3.2), Vector3(0.0, 4.3, -d * 0.5 - 1.6), _standard("awning-canteen", awning_color, 0.85), true)


func _add_building_collider(node: Node3D, w: float, h: float, d: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Collider"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, d)
	shape.shape = box
	shape.position = Vector3(0.0, h * 0.5, 0.0)
	body.add_child(shape)
	node.add_child(body)
	stats["colliders"] = int(stats["colliders"]) + 1


func _collect_windows(building: Dictionary, node: Node3D, w: float, h: float, d: float) -> void:
	var category := str(building.get("category", "public"))
	if category == "gate":
		return
	var floors := maxi(1, int(building.get("floors", 1)))
	var floor_height := h / float(floors)
	var win_height := clampf(floor_height * 0.4, 1.0, 1.75)
	var rot := deg_to_rad(float(building.get("rect", {}).get("rot", 0.0)))
	var basis := Basis(Vector3.UP, -rot)
	var base_position := node.position

	var facades := [
		{"width": w, "axis": "z", "sign": -1.0, "offset": d * 0.5},
		{"width": w, "axis": "z", "sign": 1.0, "offset": d * 0.5},
		{"width": d, "axis": "x", "sign": -1.0, "offset": w * 0.5},
		{"width": d, "axis": "x", "sign": 1.0, "offset": w * 0.5},
	]

	var tint_index := 0
	for facade in facades:
		var facade_width := float(facade["width"])
		var usable := facade_width - 4.0
		if usable < 2.0:
			continue
		var slots := maxi(1, int(usable / 3.4))
		var spacing := usable / float(slots)
		for floor_index in range(floors):
			var y := floor_height * (float(floor_index) + 0.58)
			if y + win_height * 0.5 > h - 0.35:
				continue
			for slot in range(slots):
				var along := -usable * 0.5 + spacing * (float(slot) + 0.5)
				var local_pos: Vector3
				var scale: Vector3
				if str(facade["axis"]) == "z":
					local_pos = Vector3(along, y, float(facade["sign"]) * (float(facade["offset"]) + 0.07))
					scale = Vector3(1.5, win_height, 0.14)
				else:
					local_pos = Vector3(float(facade["sign"]) * (float(facade["offset"]) + 0.07), y, along)
					scale = Vector3(0.14, win_height, 1.5)
				var instance_basis := basis * Basis.from_scale(scale)
				var world_position := base_position + basis * local_pos
				_window_transforms.append(Transform3D(instance_basis, world_position))
				var variation := 0.78 + 0.3 * float((tint_index * 37 + floor_index * 11) % 10) / 10.0
				_window_colors.append(Color(variation, variation, variation, 1.0))
				tint_index += 1


func _build_window_mesh() -> void:
	stats["windows"] = _window_transforms.size()
	if _window_transforms.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = box
	multi.instance_count = _window_transforms.size()
	for i in range(_window_transforms.size()):
		multi.set_instance_transform(i, _window_transforms[i])
		multi.set_instance_color(i, _window_colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "Windows"
	instance.multimesh = multi
	instance.material_override = _window_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-500, 0, -80), Vector3(1000, 120, 860))
	add_child(instance)


## ---------------------------------------------------------------- gates

func _build_gate(node: Node3D, building: Dictionary, w: float, h: float, d: float) -> void:
	var building_id := str(building.get("id", "gate"))
	var stone := _standard("gate-stone", Color("#8d9199"), 0.82)
	var roof := _standard("gate-roof", Color("#4f5a60"), 0.86)
	var sign_material := _standard("gate-sign", Color("#5a1f1a"), 0.7)
	var gold := Color(0.96, 0.86, 0.62)

	var across_x := w >= d
	var pillar_size: Vector3
	var pillar_offset: float

	if across_x:
		pillar_size = Vector3(8.0, h, d)
		pillar_offset = w * 0.5 - 4.0
		for side in [-1.0, 1.0]:
			_add_box(node, "GatePillar", pillar_size, Vector3(float(side) * pillar_offset, h * 0.5, 0.0), stone, true)
		_add_box(node, "GateBeam", Vector3(w, 2.6, d * 0.9), Vector3(0.0, h - 1.3, 0.0), roof, true)
		_add_box(node, "GateSign", Vector3(30.0, 3.0, 0.5), Vector3(0.0, h - 1.7, d * 0.45 + 0.3), sign_material)
		if building_id == "gate-north":
			_add_sign_text("齐鲁师范学院", Vector3(0.0, h - 1.7, d * 0.45 + 0.58), 0.0, gold, 66, 0.052, node)
			_build_cultural_corridors(node)
		else:
			_add_sign_text(str(building.get("name", "校门")), Vector3(0.0, h - 1.7, d * 0.45 + 0.58), 0.0, gold, 62, 0.04, node)
		# 两侧门柱碰撞。
		for side in [-1.0, 1.0]:
			_add_gate_collider(node, pillar_size, Vector3(float(side) * pillar_offset, h * 0.5, 0.0))
	else:
		pillar_size = Vector3(w, h, 8.0)
		pillar_offset = d * 0.5 - 4.0
		for side in [-1.0, 1.0]:
			_add_box(node, "GatePillar", pillar_size, Vector3(0.0, h * 0.5, float(side) * pillar_offset), stone, true)
		_add_box(node, "GateBeam", Vector3(w * 0.9, 2.2, d), Vector3(0.0, h - 1.1, 0.0), roof, true)
		_add_box(node, "GateSign", Vector3(0.5, 2.4, 10.0), Vector3(-w * 0.45 - 0.25, h - 2.0, 0.0), sign_material)
		_add_sign_text(str(building.get("name", "校门")), Vector3(-w * 0.45 - 0.55, h - 2.0, 0.0), -PI * 0.5, gold, 62, 0.036, node)
		for side in [-1.0, 1.0]:
			_add_gate_collider(node, pillar_size, Vector3(0.0, h * 0.5, float(side) * pillar_offset))


func _build_cultural_corridors(node: Node3D) -> void:
	var stone := _standard("corridor-stone", Color("#c2bbad"), 0.9)
	var wood := _standard("corridor-wood", Color("#7a4a38"), 0.82)
	var roof_material := _standard("corridor-roof", Color("#46525a"), 0.86)
	var bench_material := _standard("corridor-bench", Color("#8a5a3f"), 0.8)
	var plaque_material := _standard("corridor-plaque", Color("#5a2a22"), 0.7)

	for corridor in CampusData.campus.get("corridors", []):
		var cx := float(corridor["x"])
		var cz := float(corridor["z"])
		var w := float(corridor["w"])
		var d := float(corridor["d"])
		var side := float(corridor["side"])

		_add_box(node, "CorridorBase", Vector3(w, 0.18, d), Vector3(cx, 0.09, cz), stone)
		_add_box(node, "CorridorStep", Vector3(w - 1.6, 0.12, d - 1.2), Vector3(cx, 0.22, cz), stone)

		var wall_x := cx + side * (w * 0.5 - 0.25)
		_add_box(node, "CorridorWall", Vector3(0.4, 1.5, d - 1.0), Vector3(wall_x, 0.93, cz), wood, true)

		var column_x_offsets := [-w * 0.5 + 1.15, w * 0.5 - 1.15]
		var column_count := 11
		var step := (d - 5.0) / float(column_count - 1)
		for row in column_x_offsets:
			for i in range(column_count):
				var z := cz - (d - 5.0) * 0.5 + step * float(i)
				_add_box(node, "CorridorColumn", Vector3(0.34, 3.3, 0.34), Vector3(cx + row, 1.83, z), wood, true)
			_add_box(node, "CorridorLintel", Vector3(0.32, 0.34, d - 2.0), Vector3(cx + row, 3.48, cz), wood, true)

		for i in range(column_count):
			var z := cz - (d - 5.0) * 0.5 + step * float(i)
			_add_box(node, "CorridorRafter", Vector3(w - 1.4, 0.16, 0.2), Vector3(cx, 3.3, z), wood)

		_add_box(node, "CorridorRoof", Vector3(w + 1.6, 0.32, d + 1.2), Vector3(cx, 3.78, cz), roof_material, true)
		_add_box(node, "CorridorRidge", Vector3(w * 0.42, 0.36, d + 1.4), Vector3(cx, 4.06, cz), roof_material, true)

		for z_offset in [-11.0, 11.0]:
			_add_box(node, "CorridorBench", Vector3(0.62, 0.44, 8.0), Vector3(wall_x - side * 0.55, 0.44, cz + float(z_offset)), bench_material, true)

		var plaque_x := wall_x - side * 0.24
		_add_box(node, "CorridorPlaque", Vector3(0.14, 1.25, 5.4), Vector3(plaque_x, 2.2, cz), plaque_material)
		var motto := str(corridor.get("motto", "崇德尚学" if side > 0.0 else "博学笃行"))
		_add_sign_text(motto, Vector3(plaque_x - side * 0.09, 2.2, cz), -side * PI * 0.5, Color(0.95, 0.88, 0.7), 36, 0.026, node)

		var body := StaticBody3D.new()
		body.name = "CorridorCollider"
		body.collision_layer = 1
		body.collision_mask = 0
		var wall_shape := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(0.4, 1.5, d - 1.0)
		wall_shape.shape = wall_box
		wall_shape.position = Vector3(wall_x, 0.93, cz)
		body.add_child(wall_shape)
		for row in column_x_offsets:
			for i in range(column_count):
				var z := cz - (d - 5.0) * 0.5 + step * float(i)
				var column_shape := CollisionShape3D.new()
				var column_box := BoxShape3D.new()
				column_box.size = Vector3(0.34, 3.3, 0.34)
				column_shape.shape = column_box
				column_shape.position = Vector3(cx + row, 1.83, z)
				body.add_child(column_shape)
		node.add_child(body)
		stats["colliders"] = int(stats["colliders"]) + 1 + column_count * column_x_offsets.size()


func _add_gate_collider(node: Node3D, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "GateCollider"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	body.add_child(shape)
	node.add_child(body)
	stats["colliders"] = int(stats["colliders"]) + 1


func _add_sign_text(text: String, position: Vector3, yaw: float, color: Color, font_size := 64, pixel_size := 0.045, parent: Node3D = null) -> void:
	var label := Label3D.new()
	label.name = "GateSignText"
	label.text = text
	label.font = GameState.ui_font
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.double_sided = true
	label.position = position
	label.rotation.y = yaw
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent == null:
		add_child(label)
	else:
		parent.add_child(label)


## ---------------------------------------------------------------- vegetation

func _build_trees() -> void:
	var zones: Array = CampusData.campus.get("treeZones", [])
	var spots: Array = []
	var buildings: Array = CampusData.buildings
	var roads: Array = CampusData.campus.get("roads", [])
	var tracks: Array = CampusData.campus.get("tracks", [])
	var plazas: Array = CampusData.campus.get("plazas", [])
	var corridors: Array = CampusData.campus.get("corridors", [])
	var waters: Array = CampusData.campus.get("water", [])
	var campus_bounds: Dictionary = CampusData.bounds()

	for zone in zones:
		var rect: Dictionary = zone.get("rect", {})
		var count := int(zone.get("count", 0))
		if count <= 0 or rect.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = int(zone.get("seed", 1))
		var placed := 0
		var attempts := 0
		while placed < count and attempts < count * 90:
			attempts += 1
			var x := float(rect.get("x", 0.0)) - float(rect.get("w", 0.0)) * 0.5 + rng.randf() * float(rect.get("w", 0.0))
			var z := float(rect.get("z", 0.0)) - float(rect.get("d", 0.0)) * 0.5 + rng.randf() * float(rect.get("d", 0.0))

			if x < float(campus_bounds.get("minX", -440.0)) + 6.0 or x > float(campus_bounds.get("maxX", 440.0)) - 6.0:
				continue
			if z < float(campus_bounds.get("minZ", -30.0)) + 6.0 or z > float(campus_bounds.get("maxZ", 740.0)) - 6.0:
				continue

			var blocked := false
			for building in buildings:
				if CampusData.distance_to_building(Vector3(x, 0.0, z), building) < 3.5:
					blocked = true
					break
			if blocked:
				continue

			for track in tracks:
				if absf(x - float(track.get("x", 0.0))) < float(track.get("w", 0.0)) * 0.5 + 4.0 and absf(z - float(track.get("z", 0.0))) < float(track.get("d", 0.0)) * 0.5 + 4.0:
					blocked = true
					break
			if blocked:
				continue

			for water in waters:
				if _point_in_polygon(x, z, water):
					blocked = true
					break
			if blocked:
				continue

			for plaza in plazas:
				if _point_in_polygon(x, z, plaza.get("polygon", [])):
					blocked = true
					break
			if blocked:
				continue

			for corridor in corridors:
				if absf(x - float(corridor["x"])) < float(corridor["w"]) * 0.5 + 3.0 and absf(z - float(corridor["z"])) < float(corridor["d"]) * 0.5 + 2.0:
					blocked = true
					break
			if blocked:
				continue

			for road in roads:
				var points: Array = road.get("points", [])
				var half_width := float(road.get("width", 12.0)) * 0.5 + 4.5
				for i in range(points.size() - 1):
					if _distance_to_segment(x, z, float(points[i][0]), float(points[i][1]), float(points[i + 1][0]), float(points[i + 1][1])) < half_width:
						blocked = true
						break
				if blocked:
					break
			if blocked:
				continue

			var too_close := false
			for spot in spots:
				if Vector2(spot["x"] - x, spot["z"] - z).length() < 3.4:
					too_close = true
					break
			if too_close:
				continue

			spots.append({
				"x": x,
				"z": z,
				"scale": rng.randf_range(0.78, 1.4),
				"rotation": rng.randf() * PI * 2.0,
				"hue": rng.randf(),
			})
			placed += 1

	_tree_spots = spots
	stats["trees"] = spots.size()
	if spots.is_empty():
		return

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var trunk_multi := MultiMesh.new()
	trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multi.mesh = trunk_mesh
	trunk_multi.instance_count = spots.size()

	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.0
	canopy_mesh.height = 1.0
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 5
	var canopy_multi := MultiMesh.new()
	canopy_multi.transform_format = MultiMesh.TRANSFORM_3D
	canopy_multi.use_colors = true
	canopy_multi.mesh = canopy_mesh
	canopy_multi.instance_count = spots.size()

	for i in range(spots.size()):
		var spot: Dictionary = spots[i]
		var scale := float(spot["scale"])
		var trunk_height := 3.0 * scale
		var canopy_radius := 2.15 * scale
		var rotation := float(spot["rotation"])
		var basis := Basis(Vector3.UP, rotation)

		var trunk_basis := basis.scaled(Vector3(scale, trunk_height, scale))
		trunk_multi.set_instance_transform(i, Transform3D(trunk_basis, Vector3(float(spot["x"]), trunk_height * 0.5, float(spot["z"]))))

		var canopy_basis := basis.scaled(Vector3(canopy_radius, canopy_radius * (0.9 + float(spot["hue"]) * 0.25), canopy_radius))
		var canopy_y := trunk_height + canopy_radius * 0.55
		canopy_multi.set_instance_transform(i, Transform3D(canopy_basis, Vector3(float(spot["x"]), canopy_y, float(spot["z"]))))
		var hue := float(spot["hue"])
		canopy_multi.set_instance_color(i, Color.from_hsv(0.255 + hue * 0.07, 0.34 + hue * 0.12, 0.28 + hue * 0.12))

	var trunks := MultiMeshInstance3D.new()
	trunks.name = "TreeTrunks"
	trunks.multimesh = trunk_multi
	trunks.material_override = _standard("trunk", Color("#6d5540"), 0.95)
	trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	trunks.custom_aabb = AABB(Vector3(-500, 0, -80), Vector3(1000, 40, 860))
	add_child(trunks)

	var canopies := MultiMeshInstance3D.new()
	canopies.name = "TreeCanopies"
	canopies.multimesh = canopy_multi
	canopies.material_override = _tree_canopy_material()
	canopies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	canopies.custom_aabb = AABB(Vector3(-500, 0, -80), Vector3(1000, 40, 860))
	add_child(canopies)


## ---------------------------------------------------------------- lamps / labels

func _build_lamps() -> void:
	var positions: Array = []
	var z := 56.0
	while z <= 344.0:
		positions.append(Vector3(-13.0, 0.0, z))
		positions.append(Vector3(13.0, 0.0, z))
		z += 48.0
	var x := -170.0
	while x <= 170.0:
		positions.append(Vector3(x, 0.0, 212.0))
		positions.append(Vector3(x, 0.0, 240.0))
		x += 68.0
	stats["lamps"] = positions.size()

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.09
	pole_mesh.bottom_radius = 0.16
	pole_mesh.height = 4.6
	pole_mesh.radial_segments = 6
	var pole_multi := MultiMesh.new()
	pole_multi.transform_format = MultiMesh.TRANSFORM_3D
	pole_multi.mesh = pole_mesh
	pole_multi.instance_count = positions.size()

	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.95, 0.22, 0.46)
	var head_multi := MultiMesh.new()
	head_multi.transform_format = MultiMesh.TRANSFORM_3D
	head_multi.mesh = head_mesh
	head_multi.instance_count = positions.size()

	for i in range(positions.size()):
		var position: Vector3 = positions[i]
		pole_multi.set_instance_transform(i, Transform3D(Basis(), position + Vector3(0.0, 2.3, 0.0)))
		head_multi.set_instance_transform(i, Transform3D(Basis(), position + Vector3(0.0, 4.62, 0.0)))

	var poles := MultiMeshInstance3D.new()
	poles.name = "LampPoles"
	poles.multimesh = pole_multi
	poles.material_override = _standard("lamp-pole", Color("#3a3f42"), 0.6, 0.4)
	poles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	poles.custom_aabb = AABB(Vector3(-300, 0, 0), Vector3(600, 10, 400))
	add_child(poles)

	var head_material := _standard("lamp-head", Color("#fff2cf"), 0.4, 0.0)
	head_material.emission_enabled = true
	head_material.emission = Color(1.0, 0.82, 0.55)
	head_material.emission_energy_multiplier = 1.1

	var heads := MultiMeshInstance3D.new()
	heads.name = "LampHeads"
	heads.multimesh = head_multi
	heads.material_override = head_material
	heads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heads.custom_aabb = AABB(Vector3(-300, 0, 0), Vector3(600, 10, 400))
	add_child(heads)


func _build_labels() -> void:
	for building in CampusData.landmark_buildings():
		var building_id := str(building.get("id", ""))
		if building_id == "gate-north":
			continue
		var rect: Dictionary = building.get("rect", {})
		var label := Label3D.new()
		label.name = "Label_" + building_id
		label.text = str(building.get("name", building_id))
		label.font = GameState.ui_font
		label.font_size = 76
		label.pixel_size = 0.026
		label.modulate = Color(0.98, 0.97, 0.92, 0.96)
		label.outline_size = 12
		label.outline_modulate = Color(0.05, 0.07, 0.09, 0.9)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		label.position = Vector3(
			float(rect.get("x", 0.0)),
			float(building.get("height_m", 12.0)) + 5.0,
			float(rect.get("z", 0.0))
		)
		label.visibility_range_end = 520.0
		add_child(label)
		stats["labels"] = int(stats["labels"]) + 1

	for area in CampusData.campus.get("areaLabels", []):
		var area_id := str(area.get("id", "area"))
		var label := Label3D.new()
		label.name = "AreaLabel_" + area_id
		label.text = str(area.get("name", area_id))
		label.font = GameState.ui_font
		label.font_size = 58
		label.pixel_size = 0.03
		label.modulate = Color(0.96, 0.93, 0.82, 0.92)
		label.outline_size = 10
		label.outline_modulate = Color(0.05, 0.07, 0.09, 0.85)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(
			float(area.get("x", 0.0)),
			float(area.get("y", 4.0)),
			float(area.get("z", 0.0))
		)
		label.visibility_range_end = 420.0
		add_child(label)
		stats["labels"] = int(stats["labels"]) + 1
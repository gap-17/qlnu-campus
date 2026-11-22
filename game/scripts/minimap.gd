extends Control
## 右上角圆形校园缩略图：北向上、整校固定范围、玩家箭头 + 视野扇形。

const MAP_SIZE := 210.0
const VIEW_SIZE := 256
const PADDING := 18.0

const CATEGORY_MAP_COLORS := {
	"gate": Color("#8b9096"),
	"teaching": Color("#b25b45"),
	"lab": Color("#85a3af"),
	"library": Color("#963f31"),
	"public": Color("#cfbda4"),
	"canteen": Color("#c06c50"),
	"dorm": Color("#ddd6ca"),
	"gym": Color("#789792"),
	"logistics": Color("#c7b69c"),
}

const COLOR_GRASS := Color("#33452f")
const COLOR_BOUNDS := Color("#3d5139")
const COLOR_ROAD := Color("#3b4147")
const COLOR_PLAZA := Color("#5c636b")
const COLOR_WATER := Color("#3a7f96")
const COLOR_ISLAND := Color("#6f8a5a")
const COLOR_TRACK := Color("#ad5540")
const COLOR_FIELD := Color("#5d8553")
const COLOR_CORRIDOR := Color("#9c7b58")
const COLOR_PLAYER := Color("#f6c46a")
const COLOR_CONE := Color(0.95, 0.77, 0.42, 0.28)

const MASK_SHADER := """
shader_type canvas_item;
void fragment() {
    vec2 p = UV - vec2(0.5);
    float d = length(p);
    if (d > 0.5) {
        discard;
    }
    vec4 col = texture(TEXTURE, UV);
    float ring = smoothstep(0.445, 0.472, d);
    col.rgb = mix(col.rgb, vec3(0.88, 0.91, 0.94), ring * 0.6);
    col.a = max(col.a, smoothstep(0.497, 0.5, d) * col.a);
    COLOR = col;
}
"""

var _player = null
var _viewport: SubViewport
var _canvas: Node2D
var _texture_rect: TextureRect
var _scale := 0.25
var _center := Vector2(VIEW_SIZE * 0.5, VIEW_SIZE * 0.5)
var _world_center := Vector2(0.0, 355.0)
var draw_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	size = Vector2(MAP_SIZE, MAP_SIZE)

	_viewport = SubViewport.new()
	_viewport.name = "MinimapViewport"
	_viewport.size = Vector2i(VIEW_SIZE, VIEW_SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_canvas = Node2D.new()
	_canvas.name = "MapCanvas"
	_viewport.add_child(_canvas)
	_canvas.draw.connect(_on_canvas_draw.bind(_canvas))

	_texture_rect = TextureRect.new()
	_texture_rect.name = "MinimapTexture"
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.texture = _viewport.get_texture()
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = MASK_SHADER
	material.shader = shader
	_texture_rect.material = material
	add_child(_texture_rect)

	_center = Vector2(VIEW_SIZE * 0.5, VIEW_SIZE * 0.5)
	var bounds := CampusData.bounds()
	var world_width := float(bounds.get("maxX", 440.0)) - float(bounds.get("minX", -440.0))
	var world_depth := float(bounds.get("maxZ", 740.0)) - float(bounds.get("minZ", -30.0))
	var usable := float(VIEW_SIZE) - PADDING * 2.0
	_scale = usable / maxf(world_width, world_depth)
	_world_center = Vector2(
		(float(bounds.get("minX", -440.0)) + float(bounds.get("maxX", 440.0))) * 0.5,
		(float(bounds.get("minZ", -30.0)) + float(bounds.get("maxZ", 740.0))) * 0.5
	)


func bind_player(player: Node) -> void:
	_player = player
	_canvas.queue_redraw()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_canvas.queue_redraw()


func _on_canvas_draw(canvas: Node2D) -> void:
	draw_count += 1
	canvas.draw_rect(Rect2(0.0, 0.0, VIEW_SIZE, VIEW_SIZE), COLOR_GRASS)
	_draw_campus_bounds(canvas)
	_draw_polygons(canvas, CampusData.campus.get("plazas", []), "polygon", COLOR_PLAZA)
	_draw_water(canvas)
	_draw_tracks(canvas)
	_draw_roads(canvas)
	_draw_corridors(canvas)
	_draw_buildings(canvas)
	_draw_player(canvas)
	_draw_compass(canvas)


func _to_map(x: float, z: float) -> Vector2:
	return _center + Vector2(x - _world_center.x, z - _world_center.y) * _scale


func _draw_campus_bounds(canvas: Node2D) -> void:
	var bounds := CampusData.bounds()
	var points := _rect_points(
		float(bounds.get("minX", -440.0)),
		float(bounds.get("minZ", -30.0)),
		float(bounds.get("maxX", 440.0)),
		float(bounds.get("maxZ", 740.0))
	)
	canvas.draw_colored_polygon(points, COLOR_BOUNDS)


func _rect_points(min_x: float, min_z: float, max_x: float, max_z: float) -> PackedVector2Array:
	return PackedVector2Array([
		_to_map(min_x, min_z),
		_to_map(max_x, min_z),
		_to_map(max_x, max_z),
		_to_map(min_x, max_z),
	])


func _draw_polygons(canvas: Node2D, items: Array, key: String, color: Color) -> void:
	for item in items:
		var source: Array = item.get(key, [])
		if source.size() < 3:
			continue
		var points := PackedVector2Array()
		for point in source:
			points.append(_to_map(float(point[0]), float(point[1])))
		canvas.draw_colored_polygon(points, color)


func _draw_water(canvas: Node2D) -> void:
	for polygon in CampusData.campus.get("water", []):
		if polygon.size() < 3:
			continue
		var points := PackedVector2Array()
		for point in polygon:
			points.append(_to_map(float(point[0]), float(point[1])))
		canvas.draw_colored_polygon(points, COLOR_WATER)
	for polygon in CampusData.campus.get("waterIslands", []):
		if polygon.size() < 3:
			continue
		var points := PackedVector2Array()
		for point in polygon:
			points.append(_to_map(float(point[0]), float(point[1])))
		canvas.draw_colored_polygon(points, COLOR_ISLAND)


func _draw_tracks(canvas: Node2D) -> void:
	for track in CampusData.campus.get("tracks", []):
		var x := float(track.get("x", 0.0))
		var z := float(track.get("z", 0.0))
		var w := float(track.get("w", 40.0))
		var d := float(track.get("d", 60.0))
		var kind := str(track.get("kind", "field"))
		if kind == "track":
			var ring_outer := _ellipse_points(x, z, w * 0.5 * _scale, d * 0.5 * _scale, 48)
			canvas.draw_colored_polygon(ring_outer, COLOR_TRACK)
			var infield := _ellipse_points(x, z, (w * 0.5 - 9.0) * _scale, (d * 0.5 - 9.0) * _scale, 48)
			canvas.draw_colored_polygon(infield, COLOR_FIELD)
		else:
			var color := COLOR_FIELD if kind == "field" else COLOR_TRACK
			canvas.draw_colored_polygon(_rect_points(x - w * 0.5, z - d * 0.5, x + w * 0.5, z + d * 0.5), color)


func _ellipse_points(x: float, z: float, rx: float, rz: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center := _to_map(x, z)
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * rz))
	return points


func _draw_roads(canvas: Node2D) -> void:
	for road in CampusData.campus.get("roads", []):
		var points: Array = road.get("points", [])
		if points.size() < 2:
			continue
		var mapped := PackedVector2Array()
		for point in points:
			mapped.append(_to_map(float(point[0]), float(point[1])))
		var width := maxf(1.5, float(road.get("width", 12.0)) * _scale)
		canvas.draw_polyline(mapped, COLOR_ROAD, width, true)


func _draw_corridors(canvas: Node2D) -> void:
	for corridor in CampusData.campus.get("corridors", []):
		var x := float(corridor.get("x", 0.0))
		var z := float(corridor.get("z", 0.0))
		var w := float(corridor.get("w", 9.0))
		var d := float(corridor.get("d", 46.0))
		canvas.draw_colored_polygon(
			_rect_points(x - w * 0.5, z - d * 0.5, x + w * 0.5, z + d * 0.5),
			COLOR_CORRIDOR
		)


func _draw_buildings(canvas: Node2D) -> void:
	for building in CampusData.buildings:
		var rect: Dictionary = building.get("rect", {})
		if rect.is_empty():
			continue
		var x := float(rect.get("x", 0.0))
		var z := float(rect.get("z", 0.0))
		var w := maxf(2.0, float(rect.get("w", 20.0)) * _scale)
		var d := maxf(2.0, float(rect.get("d", 20.0)) * _scale)
		var rot := deg_to_rad(float(rect.get("rot", 0.0)))
		var c := cos(rot)
		var s := sin(rot)
		var center := _to_map(x, z)
		var corners := PackedVector2Array()
		for local in [Vector2(-w * 0.5, -d * 0.5), Vector2(w * 0.5, -d * 0.5), Vector2(w * 0.5, d * 0.5), Vector2(-w * 0.5, d * 0.5)]:
			corners.append(center + Vector2(local.x * c - local.y * s, local.x * s + local.y * c))
		var color: Color = CATEGORY_MAP_COLORS.get(str(building.get("category", "public")), Color("#cfbda4"))
		canvas.draw_colored_polygon(corners, color)
		var outline := PackedVector2Array(corners)
		outline.append(corners[0])
		canvas.draw_polyline(outline, Color(0.0, 0.0, 0.0, 0.35), 1.0, true)


func _draw_player(canvas: Node2D) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var position: Vector3 = _player.global_position
	var point := _to_map(position.x, position.z)
	var heading := float(_player.heading_yaw())
	var camera_yaw := float(_player.camera_yaw)

	var cone := PackedVector2Array()
	cone.append(point)
	var cone_angle := -camera_yaw
	for i in range(9):
		var spread := lerpf(-0.55, 0.55, float(i) / 8.0)
		var direction := Vector2(0.0, -1.0).rotated(cone_angle + spread)
		cone.append(point + direction * 30.0)
	canvas.draw_colored_polygon(cone, COLOR_CONE)

	var arrow := PackedVector2Array()
	var angle := -heading
	for local in [Vector2(0.0, -7.0), Vector2(5.0, 5.0), Vector2(0.0, 2.5), Vector2(-5.0, 5.0)]:
		arrow.append(point + local.rotated(angle))
	canvas.draw_colored_polygon(arrow, COLOR_PLAYER)
	var outline := PackedVector2Array(arrow)
	outline.append(arrow[0])
	canvas.draw_polyline(outline, Color(0.08, 0.09, 0.1, 0.9), 1.2, true)


func _draw_compass(canvas: Node2D) -> void:
	var tip := Vector2(VIEW_SIZE * 0.5, 8.0)
	var left := Vector2(VIEW_SIZE * 0.5 - 5.0, 17.0)
	var right := Vector2(VIEW_SIZE * 0.5 + 5.0, 17.0)
	canvas.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.92, 0.94, 0.96, 0.85))
	canvas.draw_string(GameState.ui_font, Vector2(VIEW_SIZE * 0.5 - 4.0, 32.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.92, 0.94, 0.96, 0.9))
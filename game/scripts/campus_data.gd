extends Node
## 校园数据：直接读取 web/src/data 下的同一份 JSON，保证网页参观与游戏使用同一套坐标。
## +X 东、+Z 南、+Y 上，1 单位 = 1 米，原点在北门。

signal loaded

const DATA_CANDIDATES := {
	"buildings": [
		"res://web/src/data/buildings.json",
		"res://game/data/buildings.json",
	],
	"campus": [
		"res://web/src/data/campus.json",
		"res://game/data/campus.json",
	],
}

const CATEGORY_LABELS := {
	"gate": {"zh": "校门", "en": "GATE"},
	"teaching": {"zh": "教学", "en": "TEACHING"},
	"lab": {"zh": "实验实训", "en": "LAB"},
	"library": {"zh": "图书馆", "en": "LIBRARY"},
	"public": {"zh": "公共建筑", "en": "PUBLIC"},
	"canteen": {"zh": "餐饮", "en": "DINING"},
	"dorm": {"zh": "学生公寓", "en": "DORMITORY"},
	"gym": {"zh": "体育", "en": "SPORTS"},
	"logistics": {"zh": "后勤", "en": "LOGISTICS"},
}

const LANDMARKS := [
	"gate-north", "library", "gym", "admin",
	"canteen-1", "canteen-2", "canteen-south", "canteen-3",
	"activity-center", "music-hall", "research-dorm",
]

var buildings: Array = []
var campus: Dictionary = {}
var is_loaded := false
var load_error := ""
var buildings_source := ""
var campus_source := ""


func _ready() -> void:
	ensure_loaded()


func ensure_loaded() -> bool:
	if is_loaded:
		return true
	var buildings_json := _read_first(DATA_CANDIDATES["buildings"])
	var campus_json := _read_first(DATA_CANDIDATES["campus"])
	if buildings_json.is_empty() or campus_json.is_empty():
		load_error = "无法读取 buildings.json / campus.json"
		push_error("[qlnu] " + load_error)
		return false
	var parsed_buildings = JSON.parse_string(buildings_json["text"])
	var parsed_campus = JSON.parse_string(campus_json["text"])
	if not (parsed_buildings is Dictionary) or not (parsed_campus is Dictionary):
		load_error = "校园数据 JSON 解析失败"
		push_error("[qlnu] " + load_error)
		return false
	buildings = parsed_buildings.get("buildings", [])
	campus = parsed_campus
	buildings_source = buildings_json["path"]
	campus_source = campus_json["path"]
	is_loaded = not buildings.is_empty() and not campus.is_empty()
	if is_loaded:
		loaded.emit()
	return is_loaded


func _read_first(candidates: Array) -> Dictionary:
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		if text.strip_edges().is_empty():
			continue
		return {"path": path, "text": text}
	return {}


func spawn_position() -> Vector3:
	var spawn: Dictionary = campus.get("spawn", {})
	return Vector3(float(spawn.get("x", 0.0)), 0.12, float(spawn.get("z", 10.0)))


func spawn_yaw() -> float:
	var spawn: Dictionary = campus.get("spawn", {})
	return deg_to_rad(float(spawn.get("yawDeg", 180.0)))


func bounds() -> Dictionary:
	return campus.get("bounds", {"minX": -440, "maxX": 440, "minZ": -30, "maxZ": 740})


func category_label(category: String) -> String:
	var entry: Dictionary = CATEGORY_LABELS.get(category, {"zh": category, "en": category.to_upper()})
	return "%s / %s" % [entry["zh"], entry["en"]]


func category_zh(category: String) -> String:
	var entry: Dictionary = CATEGORY_LABELS.get(category, {"zh": category, "en": category.to_upper()})
	return str(entry["zh"])


## 点到旋转矩形（建筑占地）的平面距离；在矩形内返回 0。
func distance_to_building(position: Vector3, building: Dictionary) -> float:
	var rect: Dictionary = building.get("rect", {})
	if rect.is_empty():
		return INF
	var dx := position.x - float(rect.get("x", 0.0))
	var dz := position.z - float(rect.get("z", 0.0))
	var rot := deg_to_rad(float(rect.get("rot", 0.0)))
	var cos_r := cos(rot)
	var sin_r := sin(rot)
	var local_x := dx * cos_r + dz * sin_r
	var local_z := -dx * sin_r + dz * cos_r
	var half_w := float(rect.get("w", 1.0)) * 0.5
	var half_d := float(rect.get("d", 1.0)) * 0.5
	var outside_x := maxf(absf(local_x) - half_w, 0.0)
	var outside_z := maxf(absf(local_z) - half_d, 0.0)
	return sqrt(outside_x * outside_x + outside_z * outside_z)


func nearest_building(position: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for building in buildings:
		var dist := distance_to_building(position, building)
		if dist < best_distance:
			best_distance = dist
			best = building
	if best.is_empty():
		return {}
	var result: Dictionary = best.duplicate(true)
	result["distance"] = best_distance
	return result


func landmark_buildings() -> Array:
	var result: Array = []
	for building in buildings:
		if LANDMARKS.has(str(building.get("id", ""))):
			result.append(building)
	return result
extends Node
## 全局状态：性别、输入映射、中文字体与 UI 主题、设置持久化。
## 作为 autoload 在 Main 之前就绪，所有界面共享同一套字体和配色。

signal gender_changed(gender: String)

const SETTINGS_PATH := "user://settings.json"
const FONT_DIR := "res://game/assets/fonts"
const FONT_CANDIDATES := [
	"SourceHanSansSC-Regular.otf",
	"NotoSansSC-Regular.otf",
	"NotoSansCJKsc-Regular.otf",
	"NotoSansSC-Regular.ttf",
	"LXGWWenKai-Regular.ttf",
	"SmileySans-Oblique.ttf",
]

const COLOR_TEXT := Color(0.93, 0.95, 0.97, 1.0)
const COLOR_MUTED := Color(0.66, 0.72, 0.77, 1.0)
const COLOR_ACCENT := Color(0.91, 0.71, 0.38, 1.0)
const COLOR_PANEL := Color(0.055, 0.075, 0.095, 0.86)
const COLOR_DIM := Color(0.03, 0.04, 0.05, 0.72)

var gender := "female"
var mouse_sensitivity := 0.0022
var invert_y := false
var show_fps := true
var playing := false

var ui_font: Font
var font_source := "default"
var ui_theme: Theme


func _ready() -> void:
	_setup_input_map()
	_load_settings()
	_load_ui_font()
	ui_theme = _build_theme()


func _setup_input_map() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("jump", [KEY_SPACE])
	_bind_keys("sprint", [KEY_SHIFT])
	_bind_keys("fly", [KEY_F])
	_bind_keys("fly_down", [KEY_Q, KEY_CTRL])
	_bind_keys("view", [KEY_V])
	_bind_keys("interact", [KEY_E])
	_bind_keys("respawn", [KEY_R])
	_bind_keys("pause", [KEY_ESCAPE, KEY_P])
	_bind_keys("fullscreen", [KEY_F11])


func _bind_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_erase_events(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func set_gender(value: String) -> void:
	if value != "female" and value != "male":
		return
	if gender == value:
		return
	gender = value
	_save_settings()
	gender_changed.emit(gender)


func set_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0006, 0.006)
	_save_settings()


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var text := FileAccess.get_file_as_string(SETTINGS_PATH)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	gender = str(parsed.get("gender", gender))
	if gender != "female" and gender != "male":
		gender = "female"
	mouse_sensitivity = clampf(float(parsed.get("mouse_sensitivity", mouse_sensitivity)), 0.0006, 0.006)
	invert_y = bool(parsed.get("invert_y", invert_y))
	show_fps = bool(parsed.get("show_fps", show_fps))


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"gender": gender,
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"show_fps": show_fps,
	}, "\t"))
	file.close()


func _load_ui_font() -> void:
	var candidates: Array = []
	candidates.append_array(FONT_CANDIDATES)

	# 用户可以直接把任意中文字体丢进 assets/fonts，无需改代码。
	var dir := DirAccess.open(FONT_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var lower := file_name.to_lower()
				if (lower.ends_with(".otf") or lower.ends_with(".ttf")) and not candidates.has(file_name):
					candidates.push_front(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	for candidate in candidates:
		var path: String = FONT_DIR + "/" + str(candidate)
		if not FileAccess.file_exists(path):
			continue
		var font := _load_font_file(path)
		if font != null:
			ui_font = font
			font_source = str(candidate)
			ThemeDB.fallback_font = font
			print("[qlnu] UI font: ", font_source)
			return

	# 桌面端兜底：调用系统字体。Web 端没有系统字体，必须放置字体文件。
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei",
		"Noto Sans CJK SC", "Source Han Sans SC", "PingFang SC",
	])
	system_font.font_weight = 500
	ui_font = system_font
	font_source = "system-fallback"
	ThemeDB.fallback_font = system_font
	push_warning("[qlnu] 未找到中文字体文件，已回退到系统字体；Web 导出前请运行 download_font.bat")


func _load_font_file(path: String) -> Font:
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Font:
			return resource
	var absolute := ProjectSettings.globalize_path(path)
	var font := FontFile.new()
	var error := font.load_dynamic_font(absolute)
	if error == OK:
		return font
	push_warning("[qlnu] 字体加载失败: %s (%s)" % [path, error_string(error)])
	return null


func _build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", COLOR_TEXT)

	var panel := _stylebox(COLOR_PANEL, 14, 16)
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.border_color = Color(1, 1, 1, 0.10)
	theme.set_stylebox("panel", "PanelContainer", panel)

	theme.set_stylebox("normal", "Button", _button_box(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.14)))
	theme.set_stylebox("hover", "Button", _button_box(Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.24)))
	theme.set_stylebox("pressed", "Button", _button_box(Color(0.91, 0.71, 0.38, 0.92), Color(0.96, 0.79, 0.49, 1)))
	theme.set_stylebox("focus", "Button", _button_box(Color(0, 0, 0, 0), COLOR_ACCENT))
	theme.set_stylebox("disabled", "Button", _button_box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06)))
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", Color(1, 1, 1, 1))
	theme.set_color("font_pressed_color", "Button", Color(0.07, 0.08, 0.09, 1))
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.28))
	theme.set_font_size("font_size", "Button", 18)

	# AccentButton：主行动按钮
	theme.set_type_variation("AccentButton", "Button")
	theme.set_stylebox("normal", "AccentButton", _button_box(Color(0.91, 0.71, 0.38, 1), Color(0.96, 0.79, 0.49, 1)))
	theme.set_stylebox("hover", "AccentButton", _button_box(Color(0.97, 0.79, 0.46, 1), Color(1, 0.87, 0.6, 1)))
	theme.set_stylebox("pressed", "AccentButton", _button_box(Color(0.82, 0.61, 0.29, 1), Color(0.91, 0.71, 0.38, 1)))
	theme.set_stylebox("focus", "AccentButton", _button_box(Color(0, 0, 0, 0), Color(0.99, 0.86, 0.58, 1)))
	theme.set_color("font_color", "AccentButton", Color(0.08, 0.09, 0.10, 1))
	theme.set_color("font_hover_color", "AccentButton", Color(0.05, 0.06, 0.07, 1))
	theme.set_color("font_pressed_color", "AccentButton", Color(0.05, 0.06, 0.07, 1))
	theme.set_font_size("font_size", "AccentButton", 20)

	# GhostButton：次要行动
	theme.set_type_variation("GhostButton", "Button")
	theme.set_stylebox("normal", "GhostButton", _button_box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.18)))
	theme.set_stylebox("hover", "GhostButton", _button_box(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.3)))
	theme.set_stylebox("pressed", "GhostButton", _button_box(Color(0.91, 0.71, 0.38, 0.9), Color(0.96, 0.79, 0.49, 1)))
	theme.set_stylebox("focus", "GhostButton", _button_box(Color(0, 0, 0, 0), COLOR_ACCENT))

	theme.set_stylebox("panel", "Panel", panel)
	return theme


func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.set_corner_radius_all(10)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


func _stylebox(bg: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box
extends CanvasLayer
## 游戏内 HUD：模式、速度、附近建筑、坐标、帧率与操作提示。

const MinimapScript = preload("res://game/scripts/minimap.gd")
const MINIMAP_SIZE := 210.0

var _root: Control
var _player = null
var _mode_label: Label
var _speed_label: Label
var _fps_label: Label
var _coord_label: Label
var _near_name: Label
var _near_meta: Label
var _near_desc: Label
var _near_panel: PanelContainer
var _click_hint: PanelContainer
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _minimap: Control
var _refresh_timer := 0.0


func _ready() -> void:
	layer = 5
	visible = false
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = GameState.ui_theme
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_mode_panel()
	_build_minimap()
	_build_stats_panel()
	_build_near_panel()
	_build_controls_panel()
	_build_click_hint()
	_build_toast()


func bind_player(player: Node) -> void:
	_player = player
	if _minimap != null:
		_minimap.bind_player(player)


func _process(delta: float) -> void:
	if not visible or _player == null or not is_instance_valid(_player):
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = 0.2
	_refresh()


func _refresh() -> void:
	var mode_text: String = str(_player.mode_label())
	_mode_label.text = mode_text
	var accent := GameState.COLOR_ACCENT if bool(_player.flying) else Color(0.93, 0.95, 0.97, 1.0)
	_mode_label.add_theme_color_override("font_color", accent)
	_speed_label.text = "%.1f m/s" % float(_player.current_speed)

	var position: Vector3 = _player.global_position
	_coord_label.text = "X %d    Z %d    Y %d" % [int(round(position.x)), int(round(position.z)), int(round(position.y))]
	_fps_label.visible = GameState.show_fps
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	var nearest: Dictionary = CampusData.nearest_building(position)
	if nearest.is_empty():
		_near_name.text = "校园边界"
		_near_meta.text = "CAMPUS BOUNDARY"
		_near_desc.text = "沿着道路继续探索，或按 R 回到北门。"
		return
	var distance := float(nearest.get("distance", 0.0))
	_near_name.text = str(nearest.get("name", "未知建筑"))
	var floors := int(nearest.get("floors", 1))
	var height := int(round(float(nearest.get("height_m", 0.0))))
	var distance_text := "门口" if distance < 1.5 else ("%d m" % int(round(distance)))
	_near_meta.text = "%s · %d 层 · 高 %d m · %s" % [
		CampusData.category_zh(str(nearest.get("category", "public"))),
		floors,
		height,
		distance_text,
	]
	_near_desc.text = str(nearest.get("description", ""))


func set_click_hint(value: bool) -> void:
	if _click_hint != null:
		_click_hint.visible = value


func toast(text: String) -> void:
	if _toast_panel == null:
		return
	_toast_label.text = text
	_toast_panel.reset_size()
	_place_top_center(_toast_panel, 26.0)
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.8)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(Callable(_toast_panel, "hide"))


## ---------------------------------------------------------------- panels

func _build_mode_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(true))
	panel.custom_minimum_size = Vector2(286.0, 0.0)
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var kicker := _label("QLNU CAMPUS · 章丘校区", 11, GameState.COLOR_MUTED)
	box.add_child(kicker)

	_mode_label = _label("步行 / WALK", 26, GameState.COLOR_TEXT)
	box.add_child(_mode_label)

	_speed_label = _label("0.0 m/s", 12, GameState.COLOR_MUTED)
	box.add_child(_speed_label)

	panel.reset_size()
	_place_top_left(panel, 24.0)


func _build_stats_panel() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(186.0, 0.0)
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	_fps_label = _label("60 FPS", 13, GameState.COLOR_ACCENT)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_fps_label)

	_coord_label = _label("X 0    Z 10    Y 0", 11, GameState.COLOR_MUTED)
	_coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_coord_label)

	panel.reset_size()
	_place_top_right(panel, 24.0, 24.0 + MINIMAP_SIZE + 12.0)


func _build_minimap() -> void:
	var backing := Panel.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.05, 0.45)
	style.set_corner_radius_all(int(MINIMAP_SIZE * 0.5) + 4)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	backing.add_theme_stylebox_override("panel", style)
	_root.add_child(backing)
	backing.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	backing.offset_left = -24.0 - MINIMAP_SIZE - 4.0
	backing.offset_right = -24.0 + 4.0
	backing.offset_top = 24.0 - 4.0
	backing.offset_bottom = 24.0 + MINIMAP_SIZE + 4.0

	_minimap = MinimapScript.new()
	_minimap.name = "Minimap"
	_root.add_child(_minimap)
	_minimap.reset_size()
	_place_top_right(_minimap, 24.0)


func _build_near_panel() -> void:
	_near_panel = PanelContainer.new()
	_near_panel.add_theme_stylebox_override("panel", _card_style(true))
	_near_panel.custom_minimum_size = Vector2(348.0, 0.0)
	_root.add_child(_near_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_near_panel.add_child(box)

	var kicker := _label("附近建筑 / NEARBY", 11, GameState.COLOR_MUTED)
	box.add_child(kicker)

	_near_name = _label("北门", 23, GameState.COLOR_TEXT)
	box.add_child(_near_name)

	_near_meta = _label("校门 · 1 层", 12, GameState.COLOR_ACCENT)
	box.add_child(_near_meta)

	_near_desc = _label("校园北门，面向文博路，是中轴景观与步行主入口。", 13, GameState.COLOR_MUTED)
	_near_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_near_desc.max_lines_visible = 3
	_near_desc.custom_minimum_size = Vector2(308.0, 44.0)
	box.add_child(_near_desc)

	_near_panel.reset_size()
	_place_bottom_left(_near_panel, 24.0)


func _build_controls_panel() -> void:
	var panel := PanelContainer.new()
	_root.add_child(panel)

	var hint := _label(
		"WASD 移动    Shift 奔跑    Space 跳跃    F 飞行/落地    Q / Ctrl 下降\n鼠标 视角    滚轮 缩放    R 回到起点    Esc 暂停",
		12,
		Color(0.80, 0.85, 0.89, 1.0)
	)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hint)

	panel.reset_size()
	_place_bottom_center(panel, 24.0)


func _build_click_hint() -> void:
	_click_hint = PanelContainer.new()
	_click_hint.add_theme_stylebox_override("panel", _card_style(true))
	_click_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_click_hint)

	var label := _label("点击画面继续探索\nCLICK TO RESUME", 16, GameState.COLOR_TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_hint.add_child(label)
	_click_hint.reset_size()
	_place_center(_click_hint)
	_click_hint.visible = false


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", _card_style(false))
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_panel)

	_toast_label = _label("已进入校园", 15, GameState.COLOR_TEXT)
	_toast_panel.add_child(_toast_label)
	_toast_panel.reset_size()
	_place_top_center(_toast_panel, 26.0)
	_toast_panel.visible = false


## ---------------------------------------------------------------- layout

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _card_style(accent_edge: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GameState.COLOR_PANEL
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_width_left = 3 if accent_edge else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.10)
	if accent_edge:
		style.border_color = GameState.COLOR_ACCENT
	return style


func _place_top_left(control: Control, margin: float) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var min_size := control.get_combined_minimum_size()
	control.offset_left = margin
	control.offset_top = margin
	control.offset_right = margin + min_size.x
	control.offset_bottom = margin + min_size.y


func _place_top_right(control: Control, margin: float, top := 24.0) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var min_size := control.get_combined_minimum_size()
	control.offset_left = -margin - min_size.x
	control.offset_right = -margin
	control.offset_top = top
	control.offset_bottom = top + min_size.y


func _place_bottom_left(control: Control, margin: float) -> void:
	control.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var min_size := control.get_combined_minimum_size()
	control.offset_left = margin
	control.offset_right = margin + min_size.x
	control.offset_top = -margin - min_size.y
	control.offset_bottom = -margin


func _place_bottom_center(control: Control, margin: float) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var min_size := control.get_combined_minimum_size()
	control.offset_left = -min_size.x * 0.5
	control.offset_right = min_size.x * 0.5
	control.offset_top = -margin - min_size.y
	control.offset_bottom = -margin


func _place_center(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER)
	var min_size := control.get_combined_minimum_size()
	control.offset_left = -min_size.x * 0.5
	control.offset_right = min_size.x * 0.5
	control.offset_top = -min_size.y * 0.5
	control.offset_bottom = min_size.y * 0.5


func _place_top_center(control: Control, margin: float) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var min_size := control.get_combined_minimum_size()
	control.offset_left = -min_size.x * 0.5
	control.offset_right = min_size.x * 0.5
	control.offset_top = margin
	control.offset_bottom = margin + min_size.y
extends CanvasLayer
## 暂停菜单：继续、回到开始界面、退出；鼠标灵敏度即时生效。

signal resume_requested
signal title_requested
signal quit_requested

var _root: Control
var _panel: PanelContainer
var _resume_button: Button
var _sensitivity_slider: HSlider
var _sensitivity_label: Label


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = GameState.ui_theme
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.035, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _menu_style())
	_panel.custom_minimum_size = Vector2(440.0, 0.0)
	_root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "暂停 / PAUSED"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GameState.COLOR_TEXT)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "章丘校区 · 第三人称探索"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", GameState.COLOR_MUTED)
	box.add_child(subtitle)

	var divider := ColorRect.new()
	divider.color = Color(1.0, 1.0, 1.0, 0.12)
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	box.add_child(divider)

	_resume_button = _action_button("继续探索   RESUME", "AccentButton")
	_resume_button.pressed.connect(_on_resume_pressed)
	box.add_child(_resume_button)

	var title_button := _action_button("回到开始界面   RETURN TO TITLE", "GhostButton")
	title_button.pressed.connect(_on_title_pressed)
	box.add_child(title_button)

	var quit_button := _action_button("退出游戏   QUIT", "GhostButton")
	quit_button.pressed.connect(_on_quit_pressed)
	box.add_child(quit_button)

	var sensitivity_row := HBoxContainer.new()
	sensitivity_row.add_theme_constant_override("separation", 12)
	box.add_child(sensitivity_row)

	var sensitivity_text := Label.new()
	sensitivity_text.text = "鼠标灵敏度"
	sensitivity_text.add_theme_font_size_override("font_size", 13)
	sensitivity_text.add_theme_color_override("font_color", GameState.COLOR_MUTED)
	sensitivity_row.add_child(sensitivity_text)

	_sensitivity_slider = HSlider.new()
	_sensitivity_slider.min_value = 0.4
	_sensitivity_slider.max_value = 3.0
	_sensitivity_slider.step = 0.1
	_sensitivity_slider.value = 1.0
	_sensitivity_slider.custom_minimum_size = Vector2(170.0, 24.0)
	_sensitivity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sensitivity_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	sensitivity_row.add_child(_sensitivity_slider)

	_sensitivity_label = Label.new()
	_sensitivity_label.text = "×1.0"
	_sensitivity_label.add_theme_font_size_override("font_size", 13)
	_sensitivity_label.add_theme_color_override("font_color", GameState.COLOR_ACCENT)
	_sensitivity_label.custom_minimum_size = Vector2(42.0, 0.0)
	sensitivity_row.add_child(_sensitivity_label)

	var controls := Label.new()
	controls.text = "WASD 移动　鼠标 视角　Shift 奔跑　Space 跳跃\nF 开关飞行　Q / Ctrl 下降　滚轮 缩放　R 回到起点　Esc 继续"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 12)
	controls.add_theme_color_override("font_color", Color(0.66, 0.72, 0.77, 1.0))
	controls.add_theme_constant_override("line_spacing", 4)
	box.add_child(controls)

	_panel.reset_size()
	_center_panel()


func _action_button(text: String, variation: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	return button


func _menu_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.075, 0.96)
	style.set_corner_radius_all(16)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.14)
	return style


func _center_panel() -> void:
	var min_size := _panel.get_combined_minimum_size()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -min_size.x * 0.5
	_panel.offset_right = min_size.x * 0.5
	_panel.offset_top = -min_size.y * 0.5
	_panel.offset_bottom = min_size.y * 0.5


func show_menu() -> void:
	visible = true
	_sync_sensitivity()
	GameState.release_mouse()
	_resume_button.grab_focus()


func hide_menu() -> void:
	visible = false


func _sync_sensitivity() -> void:
	var multiplier := clampf(GameState.mouse_sensitivity / 0.0022, 0.4, 3.0)
	_sensitivity_slider.set_value_no_signal(multiplier)
	_sensitivity_label.text = "×%.1f" % multiplier


func _on_sensitivity_changed(value: float) -> void:
	GameState.set_sensitivity(0.0022 * value)
	_sensitivity_label.text = "×%.1f" % value


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_title_pressed() -> void:
	title_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
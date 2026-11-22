extends CanvasLayer
## 开始界面：校名、男女角色选择、进入校园与操作提示。

signal start_requested

var _root: Control
var _female_button: Button
var _male_button: Button
var _start_button: Button
var _gender_group: ButtonGroup
var _fade_tween: Tween


func _ready() -> void:
	layer = 15
	visible = false

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = GameState.ui_theme
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_add_background()
	_add_menu()
	_add_location_tag()
	_sync_gender_buttons()
	GameState.gender_changed.connect(_on_gender_changed)


func _add_background() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.025, 0.04, 0.055, 0.96),
		Color(0.025, 0.04, 0.055, 0.78),
		Color(0.025, 0.04, 0.055, 0.18),
		Color(0.025, 0.04, 0.055, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.72, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 8
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 0.0)

	var scrim := TextureRect.new()
	scrim.texture = texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)

	# 底部渐隐用四层低透明度色块，模拟柔和过渡。
	var fade_colors := [0.02, 0.05, 0.10, 0.16]
	for i in range(4):
		var band := ColorRect.new()
		band.color = Color(0.02, 0.03, 0.04, fade_colors[i])
		band.anchor_top = 1.0
		band.anchor_bottom = 1.0
		band.anchor_left = 0.0
		band.anchor_right = 1.0
		band.offset_top = -160.0 + i * 40.0
		band.offset_bottom = -120.0 + i * 40.0
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(band)


func _add_menu() -> void:
	var menu := VBoxContainer.new()
	menu.anchor_left = 0.0
	menu.anchor_right = 0.0
	menu.anchor_top = 0.5
	menu.anchor_bottom = 0.5
	menu.offset_left = 84.0
	menu.offset_right = 536.0
	menu.offset_top = -272.0
	menu.offset_bottom = 272.0
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 9)
	_root.add_child(menu)

	var kicker := Label.new()
	kicker.text = "QILU NORMAL UNIVERSITY"
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", Color(0.82, 0.72, 0.54, 1.0))
	kicker.add_theme_constant_override("outline_size", 4)
	kicker.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.7))
	menu.add_child(kicker)

	var title := Label.new()
	title.text = "齐鲁师范学院"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.98, 0.97, 0.94, 1.0))
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.75))
	menu.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "章丘校区 · 校园漫游"
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.add_theme_color_override("font_color", GameState.COLOR_ACCENT)
	subtitle.add_theme_constant_override("outline_size", 6)
	subtitle.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.7))
	menu.add_child(subtitle)

	var version := Label.new()
	version.text = "v0.2  第三人称探索 / THIRD-PERSON WALK"
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", GameState.COLOR_MUTED)
	menu.add_child(version)

	menu.add_child(_spacer(10))
	menu.add_child(_divider())
	menu.add_child(_spacer(8))

	var choose := Label.new()
	choose.text = "选择你的角色 / CHOOSE YOUR AVATAR"
	choose.add_theme_font_size_override("font_size", 13)
	choose.add_theme_color_override("font_color", Color(0.84, 0.86, 0.88, 1.0))
	menu.add_child(choose)

	var gender_row := HBoxContainer.new()
	gender_row.add_theme_constant_override("separation", 12)
	gender_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_child(gender_row)

	_gender_group = ButtonGroup.new()
	_female_button = _make_gender_button("女生\nFEMALE\n\n长发 · 枣红连帽衫")
	_female_button.pressed.connect(_on_female_pressed)
	gender_row.add_child(_female_button)

	_male_button = _make_gender_button("男生\nMALE\n\n短发 · 藏蓝连帽衫")
	_male_button.pressed.connect(_on_male_pressed)
	gender_row.add_child(_male_button)

	menu.add_child(_spacer(6))

	_start_button = Button.new()
	_start_button.text = "进入校园   ENTER CAMPUS"
	_start_button.theme_type_variation = "AccentButton"
	_start_button.custom_minimum_size = Vector2(0.0, 54.0)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.pressed.connect(_on_start_pressed)
	menu.add_child(_start_button)

	menu.add_child(_spacer(4))

	var controls := Label.new()
	controls.text = "WASD 移动　鼠标 视角　Shift 奔跑　Space 跳跃\nF 开关飞行　Q / Ctrl 下降　滚轮 缩放　R 回到起点　Esc 暂停"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.custom_minimum_size = Vector2(440.0, 0.0)
	controls.add_theme_font_size_override("font_size", 13)
	controls.add_theme_color_override("font_color", Color(0.72, 0.78, 0.83, 1.0))
	controls.add_theme_constant_override("line_spacing", 5)
	menu.add_child(controls)

	var note := Label.new()
	note.text = "Godot 4 · 校园数据与网页版同源"
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.55, 0.61, 0.66, 1.0))
	menu.add_child(note)


func _make_gender_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = _gender_group
	button.custom_minimum_size = Vector2(204.0, 118.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_constant_override("outline_size", 0)
	return button


func _add_location_tag() -> void:
	var tag := Label.new()
	tag.text = "北门 · NORTH GATE"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.anchor_top = 0.0
	tag.anchor_bottom = 0.0
	tag.offset_left = -360.0
	tag.offset_right = -42.0
	tag.offset_top = 34.0
	tag.offset_bottom = 60.0
	tag.add_theme_font_size_override("font_size", 13)
	tag.add_theme_color_override("font_color", Color(0.90, 0.87, 0.80, 0.9))
	tag.add_theme_constant_override("outline_size", 6)
	tag.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.6))
	_root.add_child(tag)


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1.0, 1.0, 1.0, 0.16)
	line.custom_minimum_size = Vector2(440.0, 1.0)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer


func _on_female_pressed() -> void:
	GameState.set_gender("female")


func _on_male_pressed() -> void:
	GameState.set_gender("male")


func _on_gender_changed(_value: String) -> void:
	_sync_gender_buttons()


func _sync_gender_buttons() -> void:
	if _female_button != null:
		_female_button.set_pressed_no_signal(GameState.gender == "female")
	if _male_button != null:
		_male_button.set_pressed_no_signal(GameState.gender == "male")


func _on_start_pressed() -> void:
	_start_button.disabled = true
	start_requested.emit()


func show_screen() -> void:
	visible = true
	_start_button.disabled = false
	_sync_gender_buttons()
	_root.modulate.a = 0.0
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_root, "modulate:a", 1.0, 0.45)
	_start_button.grab_focus()


func hide_screen() -> void:
	visible = false
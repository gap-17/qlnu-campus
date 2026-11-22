extends Node3D
## v0.2 主流程：构建校园 → 开始界面（男女选择）→ 第三人称探索 → 暂停/返回标题。
## 支持 `--headless --path . -- --smoke` 做无界面冒烟测试。

const CampusBuilderScript = preload("res://game/scripts/campus_builder.gd")
const PlayerScript = preload("res://game/scripts/player.gd")
const StartScreenScript = preload("res://game/scripts/start_screen.gd")
const HudScript = preload("res://game/scripts/hud.gd")
const PauseMenuScript = preload("res://game/scripts/pause_menu.gd")

var campus: Node3D
var player: CharacterBody3D
var start_screen: CanvasLayer
var hud: CanvasLayer
var pause_menu: CanvasLayer
var overview_camera: Camera3D
var loading_layer: CanvasLayer
var loading_label: Label
var _title_time := 0.0
var _started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.playing = false

	if OS.get_cmdline_user_args().has("--ui-smoke"):
		_run_ui_smoke()
		return

	if OS.get_cmdline_user_args().has("--smoke"):
		_run_smoke()
		return

	_build_loading()
	await get_tree().process_frame
	await get_tree().process_frame

	var started_at := Time.get_ticks_msec()
	if not _build_world():
		_show_data_error()
		return
	var elapsed := Time.get_ticks_msec() - started_at
	_build_ui()
	_show_title()
	_remove_loading()
	print("[qlnu] v0.2 ready in %d ms, font=%s" % [elapsed, GameState.font_source])


func _build_loading() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.layer = 30
	add_child(loading_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = GameState.ui_theme
	loading_layer.add_child(root)

	var background := ColorRect.new()
	background.color = Color(0.028, 0.042, 0.058, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -240.0
	box.offset_right = 240.0
	box.offset_top = -90.0
	box.offset_bottom = 90.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)

	var title := Label.new()
	title.text = "齐鲁师范学院"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", GameState.COLOR_TEXT)
	box.add_child(title)

	loading_label = Label.new()
	loading_label.text = "正在构建校园 / BUILDING CAMPUS"
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 14)
	loading_label.add_theme_color_override("font_color", GameState.COLOR_MUTED)
	box.add_child(loading_label)


func _remove_loading() -> void:
	if loading_layer != null:
		loading_layer.queue_free()
		loading_layer = null


func _show_data_error() -> void:
	if loading_label != null:
		loading_label.text = "无法加载校园数据\n%s\n请确认 web/src/data/buildings.json 与 campus.json 存在。" % CampusData.load_error
		loading_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.62, 1.0))
	push_error("[qlnu] 启动失败: " + CampusData.load_error)


func _build_world() -> bool:
	if not CampusData.ensure_loaded():
		return false

	campus = CampusBuilderScript.new()
	campus.name = "Campus"
	add_child(campus)
	campus.build_all()

	player = PlayerScript.new()
	add_child(player)
	player.spawn_at(CampusData.spawn_position(), CampusData.spawn_yaw())

	overview_camera = Camera3D.new()
	overview_camera.name = "OverviewCamera"
	overview_camera.fov = 55.0
	overview_camera.near = 0.1
	overview_camera.far = 2200.0
	overview_camera.position = Vector3(0.0, 38.0, -64.0)
	add_child(overview_camera)
	overview_camera.look_at(Vector3(0.0, 10.0, 280.0))
	overview_camera.current = true
	return true


func _build_ui() -> void:
	start_screen = StartScreenScript.new()
	start_screen.name = "StartScreen"
	add_child(start_screen)
	start_screen.start_requested.connect(_on_start_requested)

	hud = HudScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.bind_player(player)

	pause_menu = PauseMenuScript.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.title_requested.connect(_return_to_title)
	pause_menu.quit_requested.connect(_quit_game)


func _show_title() -> void:
	GameState.playing = false
	GameState.release_mouse()
	get_tree().paused = false
	_started = false
	if pause_menu != null:
		pause_menu.hide_menu()
	if hud != null:
		hud.visible = false
		hud.set_click_hint(false)
	if player != null:
		player.reset_to_spawn()
		player.set_active(false)
	if overview_camera != null:
		overview_camera.current = true
	if start_screen != null:
		start_screen.show_screen()


func _on_start_requested() -> void:
	if start_screen != null:
		start_screen.hide_screen()
	if player != null:
		player.reset_to_spawn()
		player.set_active(true)
	if overview_camera != null:
		overview_camera.current = false
	if hud != null:
		hud.visible = true
		hud.set_click_hint(false)
	GameState.playing = true
	_started = true
	GameState.capture_mouse()
	if hud != null:
		hud.toast("已进入校园 · 北门\nWASD 移动　F 开关飞行　Q / Ctrl 下降　Esc 暂停")


func _pause_game() -> void:
	if not GameState.playing:
		return
	get_tree().paused = true
	if pause_menu != null:
		pause_menu.show_menu()
	if hud != null:
		hud.set_click_hint(false)


func _resume_game() -> void:
	if not GameState.playing:
		return
	get_tree().paused = false
	if pause_menu != null:
		pause_menu.hide_menu()
	GameState.capture_mouse()
	if hud != null:
		hud.set_click_hint(false)


func _return_to_title() -> void:
	get_tree().paused = false
	if pause_menu != null:
		pause_menu.hide_menu()
	_show_title()


func _quit_game() -> void:
	get_tree().quit()


func _process(delta: float) -> void:
	if overview_camera != null and overview_camera.current and start_screen != null and start_screen.visible:
		_title_time += delta
		overview_camera.position.x = sin(_title_time * 0.11) * 5.0
		overview_camera.position.y = 38.0 + sin(_title_time * 0.08) * 1.4
		overview_camera.look_at(Vector3(0.0, 10.0, 280.0))

	if hud != null and hud.visible and GameState.playing and not get_tree().paused:
		hud.set_click_hint(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameState.playing and not get_tree().paused:
			_pause_game()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("fullscreen"):
		GameState.toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return

	if not GameState.playing or get_tree().paused:
		return

	if event.is_action_pressed("respawn") and player != null:
		player.reset_to_spawn()
		if hud != null:
			hud.toast("已回到北门起点")
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			GameState.capture_mouse()
			get_viewport().set_input_as_handled()


## ---------------------------------------------------------------- smoke test

func _run_ui_smoke() -> void:
	print("[ui-smoke] boot")
	var failures := 0
	if not _build_world():
		print("[ui-smoke] FAIL world build")
		get_tree().quit(1)
		return
	_build_ui()
	_show_title()
	await get_tree().process_frame
	await get_tree().process_frame

	var minimap: Node = hud.find_child("Minimap", true, false)
	if minimap == null:
		failures += 1
		print("[ui-smoke] FAIL minimap missing")
	else:
		for child in minimap.get_children():
			print("[ui-smoke] minimap child: %s (%s)" % [child.name, child.get_class()])
		var viewport := minimap.get_node_or_null("MinimapViewport")
		print("[ui-smoke] minimap size=%s viewport=%s" % [minimap.size, viewport != null])
		if viewport == null:
			failures += 1
			print("[ui-smoke] FAIL minimap viewport")
	if hud.visible:
		failures += 1
		print("[ui-smoke] FAIL hud visible on title")
	if start_screen == null or not start_screen.visible:
		failures += 1
		print("[ui-smoke] FAIL start screen")

	_on_start_requested()
	await get_tree().process_frame
	await get_tree().process_frame
	if not hud.visible:
		failures += 1
		print("[ui-smoke] FAIL hud hidden after start")
	if player == null or not player.active:
		failures += 1
		print("[ui-smoke] FAIL player inactive after start")
	if player != null and player.mode_label() != "步行 / WALK":
		failures += 1
		print("[ui-smoke] FAIL initial mode ", player.mode_label())

	if minimap != null:
		print("[ui-smoke] minimap draws=", minimap.draw_count)
		if int(minimap.draw_count) <= 0:
			failures += 1
			print("[ui-smoke] FAIL minimap did not draw")

	player.flying = true
	player.position = Vector3(0.0, 30.0, 120.0)
	player.velocity = Vector3.ZERO
	Input.action_press("fly_down")
	for i in range(10):
		await get_tree().physics_frame
	Input.action_release("fly_down")
	if player.mode_label() != "飞行 / FLY":
		failures += 1
		print("[ui-smoke] FAIL flight mode label")
	if player.position.y > 29.7:
		failures += 1
		print("[ui-smoke] FAIL Q/Ctrl descent")

	player.flying = false
	player.gliding = true
	player.velocity.y = -20.0
	await get_tree().physics_frame
	if player.velocity.y < -7.0:
		failures += 1
		print("[ui-smoke] FAIL glide clamp ", player.velocity.y)
	if player.mode_label() != "缓降 / LANDING":
		failures += 1
		print("[ui-smoke] FAIL glide mode label")

	if failures == 0:
		print("[ui-smoke] PASS")
		get_tree().quit(0)
	else:
		print("[ui-smoke] FAILURES=", failures)
		get_tree().quit(1)


func _validate_layout() -> int:
	var problems := 0
	var buildings: Array = CampusData.buildings
	var roads: Array = CampusData.campus.get("roads", [])
	var tracks: Array = CampusData.campus.get("tracks", [])
	var waters: Array = CampusData.campus.get("water", [])

	for i in range(buildings.size()):
		var a: Dictionary = buildings[i]
		var ra: Dictionary = a.get("rect", {})
		if ra.is_empty() or str(a.get("category", "")) == "gate":
			continue
		var ax := float(ra.get("x", 0.0))
		var az := float(ra.get("z", 0.0))
		var aw := float(ra.get("w", 0.0))
		var ad := float(ra.get("d", 0.0))

		for j in range(i + 1, buildings.size()):
			var b: Dictionary = buildings[j]
			var rb: Dictionary = b.get("rect", {})
			if rb.is_empty() or str(b.get("category", "")) == "gate":
				continue
			var overlap_x := minf(ax + aw * 0.5, float(rb.get("x", 0.0)) + float(rb.get("w", 0.0)) * 0.5) - maxf(ax - aw * 0.5, float(rb.get("x", 0.0)) - float(rb.get("w", 0.0)) * 0.5)
			var overlap_z := minf(az + ad * 0.5, float(rb.get("z", 0.0)) + float(rb.get("d", 0.0)) * 0.5) - maxf(az - ad * 0.5, float(rb.get("z", 0.0)) - float(rb.get("d", 0.0)) * 0.5)
			if overlap_x > 1.0 and overlap_z > 1.0:
				problems += 1
				print("[smoke] FAIL overlap %s × %s = %.1f m²" % [a.get("id", "?"), b.get("id", "?"), overlap_x * overlap_z])

		for track in tracks:
			var tw := float(track.get("w", 0.0))
			var td := float(track.get("d", 0.0))
			var tx := float(track.get("x", 0.0))
			var tz := float(track.get("z", 0.0))
			var track_x := minf(ax + aw * 0.5, tx + tw * 0.5) - maxf(ax - aw * 0.5, tx - tw * 0.5)
			var track_z := minf(az + ad * 0.5, tz + td * 0.5) - maxf(az - ad * 0.5, tz - td * 0.5)
			if track_x > 1.0 and track_z > 1.0 and str(track.get("kind", "field")) != "basketball":
				problems += 1
				print("[smoke] FAIL track overlap %s × %s" % [a.get("id", "?"), track.get("id", "?")])

		for water in waters:
			var polygon := PackedVector2Array()
			for point in water:
				polygon.append(Vector2(float(point[0]), float(point[1])))
			for corner in [
				Vector2(ax - aw * 0.5, az - ad * 0.5),
				Vector2(ax + aw * 0.5, az - ad * 0.5),
				Vector2(ax + aw * 0.5, az + ad * 0.5),
				Vector2(ax - aw * 0.5, az + ad * 0.5),
				Vector2(ax, az),
			]:
				if Geometry2D.is_point_in_polygon(corner, polygon):
					problems += 1
					print("[smoke] FAIL water overlap %s" % a.get("id", "?"))
					break

		var reported: Dictionary = {}
		for road in roads:
			var road_id := str(road.get("id", "road"))
			if reported.has(road_id):
				continue
			var half_width := float(road.get("width", 12.0)) * 0.5
			var points: Array = road.get("points", [])
			for k in range(points.size() - 1):
				if reported.has(road_id):
					break
				var start := Vector2(float(points[k][0]), float(points[k][1]))
				var end := Vector2(float(points[k + 1][0]), float(points[k + 1][1]))
				var length := start.distance_to(end)
				var steps := maxi(2, int(ceil(length)))
				for s in range(steps + 1):
					var point := start.lerp(end, float(s) / float(steps))
					if absf(point.x - ax) < aw * 0.5 + half_width and absf(point.y - az) < ad * 0.5 + half_width:
						problems += 1
						reported[road_id] = true
						print("[smoke] FAIL road overlap %s × %s" % [a.get("id", "?"), road_id])
						break
	return problems


func _run_smoke() -> void:
	print("[smoke] QLNU campus v0.2")
	var failures := 0
	if not CampusData.ensure_loaded():
		print("[smoke] FAIL data: ", CampusData.load_error)
		get_tree().quit(1)
		return
	print("[smoke] buildings=%d roads=%d tree_zones=%d" % [
		CampusData.buildings.size(),
		CampusData.campus.get("roads", []).size(),
		CampusData.campus.get("treeZones", []).size(),
	])
	if CampusData.buildings.size() != 41:
		failures += 1
		print("[smoke] FAIL building count")

	var builder = CampusBuilderScript.new()
	builder.name = "SmokeCampus"
	add_child(builder)
	builder.build_all()
	var stats: Dictionary = builder.stats
	print("[smoke] stats=", JSON.stringify(stats))
	if int(stats.get("buildings", 0)) != 41:
		failures += 1
		print("[smoke] FAIL built buildings")
	if int(stats.get("colliders", 0)) < 85:
		failures += 1
		print("[smoke] FAIL colliders")
	if int(stats.get("windows", 0)) < 1000:
		failures += 1
		print("[smoke] FAIL windows")
	if int(stats.get("trees", 0)) < 120:
		failures += 1
		print("[smoke] FAIL trees")
	if int(stats.get("labels", 0)) < 15:
		failures += 1
		print("[smoke] FAIL labels")
	failures += _validate_layout()

	var spawn := CampusData.spawn_position()
	var nearest: Dictionary = CampusData.nearest_building(spawn)
	print("[smoke] spawn=", spawn, " nearest=", nearest.get("name", "?"), " dist=", nearest.get("distance", -1.0))
	if nearest.is_empty():
		failures += 1
		print("[smoke] FAIL nearest")

	var test_player = PlayerScript.new()
	test_player.name = "SmokePlayer"
	add_child(test_player)
	test_player.spawn_at(spawn, CampusData.spawn_yaw())
	await get_tree().physics_frame
	await get_tree().physics_frame
	var settled: Vector3 = test_player.global_position
	print("[smoke] player=", settled, " mode=", test_player.mode_label())
	if settled.distance_to(spawn) > 6.0:
		failures += 1
		print("[smoke] FAIL spawn position")

	test_player.queue_free()
	builder.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("[smoke] PASS")
		get_tree().quit(0)
	else:
		print("[smoke] FAILURES=", failures)
		get_tree().quit(1)
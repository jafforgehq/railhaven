extends Node
## Dev-only screenshot tour: godot --path . -- --shots=<dir>
## Walks every screen and saves PNGs so layouts can be reviewed without a device.

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.substr(8)
		if a == "--soak":
			# Headless soak: skip the tutorial gate so events fire, then just let the game run.
			Game.autosave = false
			Game.new_game()
			Game.goal_index = 4
			Game.event_timer = 20.0
			Game.res["scrap"] = 400.0
			Game.res["parts"] = 120.0
			Game.event_started.connect(func(id): print("event ", id))
			Game.event_ended.connect(func(id): print("event ended ", id))
			Game.drone_returned.connect(func(_u, a2): print("drone +", int(a2)))
			return
	if dir == "":
		queue_free()
		return
	Game.autosave = false
	if OS.get_cmdline_user_args().has("--gallery"):
		_gallery.call_deferred()
	elif OS.get_cmdline_user_args().has("--chars"):
		_chars.call_deferred()
	elif OS.get_cmdline_user_args().has("--detour"):
		_detour.call_deferred()
	else:
		_tour.call_deferred()


func _shot(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("shot ", name)


func _tour() -> void:
	var main: Node = get_parent()
	await get_tree().create_timer(0.3).timeout
	while not main._modal_stack.is_empty():
		main.close_modal()
	Game.new_game()
	main.world.rebuild()
	main._rebuild_plates()
	main.set_tab("train")
	await _shot("01_overview")
	await _input_checks(main)
	main.open_carriage(Game.first_of("workshop")["uid"])
	await _shot("02_workshop")
	main.open_carriage(Game.first_of("dronebay")["uid"])
	await get_tree().create_timer(1.5).timeout
	await _shot("03_dronebay")
	main.open_build()
	await _shot("04_build")
	Game.res["scrap"] = 2000.0
	Game.res["parts"] = 900.0
	for t in ["greenhouse", "cooling", "recycler"]:
		Game.build(t)
	Game.auto_assign()
	for i in 6:
		Game.survivors.append(Game._make_survivor())
	Game.upgrade(Game.first_of("quarters")["uid"])
	main.show_train_overview()
	main.world.focus(Game.first_of("greenhouse")["uid"])
	await get_tree().create_timer(1.2).timeout
	await _shot("05_greenhouse_view")
	main.world.focus(Game.first_of("recycler")["uid"])
	await get_tree().create_timer(1.2).timeout
	await _shot("06_recycler_view")
	main.set_tab("crew")
	await _shot("07_crew")
	Popups.assign(main, Game.survivors[5]["id"])
	await _shot("08_assign")
	main.close_modal()
	main.set_tab("journey")
	await _shot("09_journey")
	Game.distance = Data.TOWER_DISTANCE + 1
	await _shot("10_journey_range")
	main.set_tab("train")
	Game.start_event("heatwave")
	await get_tree().create_timer(2.5).timeout
	await _shot("11_heatwave")
	main.close_modal()
	Game.choose_event("b")
	await get_tree().create_timer(1.0).timeout
	await _shot("12_safe_mode")
	Game.event = {}
	Game.start_event("sandstorm")
	main.close_modal()
	await get_tree().create_timer(3.0).timeout
	await _shot("13_sandstorm")
	Game.event = {}
	Game.pending_report = {"seconds": 12000.0, "gains": {"scrap": 420.0, "parts": 120.0, "food": 180.0, "water": -20.0},
		"survivors": 2, "distance": 900.0, "safe_mode": true, "rationing": false, "stages": 0}
	main._on_offline_report(Game.pending_report)
	await _shot("14_offline")
	main.close_modal()
	Popups.goals(main)
	await _shot("15_goals")
	main.close_modal()
	Popups.settings(main)
	await _shot("16_settings")
	main.close_modal()
	Game.chapter_done = true
	main._on_chapter_complete()
	await _shot("17_tower")
	get_tree().quit()


func _push(ev: InputEvent) -> void:
	get_viewport().push_input(ev, true)
	await get_tree().process_frame


func _mouse(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	return e


## Simulated touch: tap a carriage opens its panel; horizontal drag pans the camera.
func _input_checks(main: Node) -> void:
	var uid: int = Game.first_of("quarters")["uid"]
	main.world.focus(uid)
	await get_tree().create_timer(1.0).timeout
	var p: Vector2 = main.world.world_to_screen(main.world.carriage_center(uid))
	await _push(_mouse(p, true))
	await _push(_mouse(p, false))
	await get_tree().create_timer(0.3).timeout
	print("CHECK tap opens carriage panel: ", main.current is CarriagePanel and main.current.uid == uid)
	main.show_train_overview()
	var cam_before: float = main.world.camera.position.x
	var start := Vector2(600, p.y)
	await _push(_mouse(start, true))
	for i in 12:
		var m := InputEventMouseMotion.new()
		m.position = start - Vector2(30 * (i + 1), 0)
		m.global_position = m.position
		m.relative = Vector2(-30, 0)
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		await _push(m)
	await _push(_mouse(start - Vector2(360, 0), false))
	await get_tree().create_timer(0.3).timeout
	print("CHECK drag pans camera: ", main.world.camera.position.x > cam_before + 100, " (", cam_before, " -> ", main.world.camera.position.x, ")")
	print("CHECK drag did not open a panel: ", main.current is OverviewPanel)


## Every carriage type at levels 1, 3 and 5 in one image.
func _gallery() -> void:
	var main: Node = get_parent()
	await get_tree().create_timer(0.3).timeout
	while not main._modal_stack.is_empty():
		main.close_modal()
	var bg := ColorRect.new()
	bg.color = Color("101318")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.modal_layer.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 3
	bg.add_child(grid)
	for t in ["locomotive"] + Data.BUILDABLE:
		for l in [1, 3, 5]:
			grid.add_child(Preview.make(t, l, 0.95))
	await _shot("gallery")
	get_tree().quit()


class CharSheet extends Control:
	var t := 0.0
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _process(d: float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1d4a4c"))
		var presets: Array = CrewSprites.meta()["presets"]
		var anims := ["idle", "walk", "carry", "hammer", "tend", "panel", "wrench", "sit"]
		for i in presets.size():
			var p := Vector2(70 + (i % 5) * 140, 260 + (i / 5) * 300)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_set_transform(p, 0.0, Vector2(4, 4))
			var m := CrewSprites.meta()
			var row: int = m["anims"].find(anims[i % anims.size()])
			var col := int(t * 8.0) % int(m["counts"][anims[i % anims.size()]])
			draw_texture_rect_region(CrewSprites.tex(presets[i]), Rect2(-CrewSprites.FEET * 0.25, Vector2(40, 50)), Rect2(col * 160, row * 200, 160, 200))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _chars() -> void:
	var main: Node = get_parent()
	await get_tree().create_timer(0.3).timeout
	while not main._modal_stack.is_empty():
		main.close_modal()
	var sheet := CharSheet.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.modal_layer.add_child(sheet)
	var row := UIKit.hbox(8)
	row.position = Vector2(10, 1080)
	sheet.add_child(row)
	for k in 5:
		var p := Portrait.new()
		p.look = {"skin": k % 4, "hair": k, "hat": k % 3}
		p.role = ["Engineer", "Grower", "Mechanic", "Pilot", "Technician"][k]
		p.custom_minimum_size = Vector2(130, 130)
		row.add_child(p)
	await _shot("chars")
	get_tree().quit()


## Regression view: recycler built before the greenhouse goal; the coach must send the
## player to build a Cooling Module instead of dead-ending.
func _detour() -> void:
	var main: Node = get_parent()
	await get_tree().create_timer(0.3).timeout
	while not main._modal_stack.is_empty():
		main.close_modal()
	Game.new_game()
	Game.intro_seen = true
	Game.res["scrap"] = 400.0
	Game.res["parts"] = 120.0
	Game.goal_index = 2
	Game.build("recycler")
	main.world.rebuild()
	main._rebuild_plates()
	main.show_train_overview()
	await _shot("detour_overview")
	main.open_build()
	await get_tree().create_timer(0.8).timeout
	await _shot("detour_build")
	get_tree().quit()

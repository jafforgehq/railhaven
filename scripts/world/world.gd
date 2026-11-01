class_name World
extends Node2D
## Side-view world in the main viewport (camera zoom 2 = native-resolution vector art):
## parallax wasteland, train cutaway, drones, weather effects and the camera.
## World units are 2 design px; input arrives via _unhandled_input in design px.

signal tapped_carriage(uid: int)
signal tapped_ghost
signal tapped_empty
signal float_text(world_pos: Vector2, text: String, color: Color)

const MAX_ZOOM := 2.5 # design px per world unit when there is room
const MIN_ZOOM := 1.3
const TRAIN_H := 168.0 # world units the camera tries to keep visible (roof gear to rails)
const PITCH := CarriageView.W + 6.0
const TRAIN_MID_Y := -78.0
const RES_COLOR := {"scrap": Color("c9d1da"), "parts": Color("ffd27a"), "food": Color("8be06a"), "water": Color("6cc8ff")}

var camera: Camera2D
var views := {} # uid -> CarriageView
var ghost: Node2D
var selected_uid := 0

var _layers := {} # kind -> scenery node
var _parallax: Array[Parallax2D] = []
var _pinned: Array[Node2D] = []
var _train: Node2D
var _drones: Node2D
var _smoke: CPUParticles2D
var _dust: CPUParticles2D
var _wind: CPUParticles2D
var _storm_fx: CPUParticles2D
var _storm_rect: ColorRect
var _front_fx: Node2D
var _t := 0.0
var _heat := 0.0
var _storm := 0.0
var _whistle := 20.0

var _press := false
var _press_pos := Vector2.ZERO
var _moved := 0.0
var _vel := 0.0
var _last_drag_time := 0
var _target_x := NAN
var _target_y := TRAIN_MID_Y
var _target_zoom := MAX_ZOOM
var _band_mid := 490.0
var _cam := Vector2(118, TRAIN_MID_Y)
var heat_uid := 0 # carriage glowing with the puzzle's heat


func _ready() -> void:
	_build_scenery()
	camera = Camera2D.new()
	camera.zoom = Vector2(MAX_ZOOM, MAX_ZOOM)
	camera.position = Vector2(150, TRAIN_MID_Y)
	add_child(camera)
	_train = Coupler.new()
	add_child(_train)
	_drones = DroneLayer.new()
	_drones.z_index = 5
	add_child(_drones)
	ghost = Ghost.new()
	add_child(ghost)
	_build_fx()
	rebuild()
	_apply_region()
	_set_cool()


func _build_scenery() -> void:
	# kind, scroll_scale.x, autoscroll factor, z
	var defs := [["sky", 0.0, 0.0, -100], ["far", 0.05, 0.04, -90], ["landmark", 0.0, 0.0, -85], ["mid", 0.15, 0.12, -80],
		["near", 0.4, 0.35, -70], ["track", 1.0, 1.0, -50], ["front", 1.25, 1.3, 20]]
	for d in defs:
		var s := preload("res://scripts/world/scenery.gd").new()
		s.kind = d[0]
		_layers[d[0]] = s
		if d[1] == 0.0:
			# Screen-fixed horizontally (sky, distant tower): plain node pinned to the view's left edge.
			s.z_index = d[3]
			add_child(s)
			_pinned.append(s)
			continue
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(d[1], 1.0)
		p.repeat_size = Vector2(720, 0)
		p.repeat_times = 2
		p.z_index = d[3]
		p.set_meta("auto", d[2])
		p.add_child(s)
		add_child(p)
		_parallax.append(p)


func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 16
	tex.height = 16
	return tex


func _build_fx() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.texture = _soft_dot()
	_smoke.amount = 36
	_smoke.lifetime = 4.0
	_smoke.position = Vector2(101, -148)
	_smoke.direction = Vector2(0.2, -1)
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 20.0
	_smoke.initial_velocity_max = 30.0
	_smoke.gravity = Vector2(32, 4)
	_smoke.scale_amount_min = 0.7
	_smoke.scale_amount_max = 1.1
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 3.2))
	_smoke.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.22, 0.2, 0.19, 0.6))
	ramp.set_color(1, Color(0.35, 0.28, 0.24, 0.0))
	_smoke.color_ramp = ramp
	_smoke.z_index = 2
	add_child(_smoke)

	_dust = CPUParticles2D.new()
	_dust.amount = 50
	_dust.lifetime = 1.1
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.direction = Vector2(1, -0.4)
	_dust.spread = 20.0
	_dust.initial_velocity_min = 25.0
	_dust.initial_velocity_max = 55.0
	_dust.gravity = Vector2(0, 30)
	_dust.color = Color(0.85, 0.55, 0.3, 0.6)
	_dust.z_index = 3
	add_child(_dust)

	_front_fx = Node2D.new()
	_front_fx.z_index = 30
	add_child(_front_fx)
	_wind = CPUParticles2D.new()
	_wind.amount = 50
	_wind.lifetime = 4.0
	_wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_wind.emission_rect_extents = Vector2(220, 260)
	_wind.position = Vector2(-60, -60)
	_wind.direction = Vector2(1, 0.05)
	_wind.spread = 6.0
	_wind.initial_velocity_min = 60.0
	_wind.initial_velocity_max = 120.0
	_wind.gravity = Vector2.ZERO
	_wind.color = Color(1.0, 0.85, 0.6, 0.45)
	_wind.preprocess = 4.0
	_front_fx.add_child(_wind)
	_storm_rect = ColorRect.new()
	_storm_rect.color = Color(0.55, 0.35, 0.2, 0.0)
	_storm_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front_fx.add_child(_storm_rect)
	_storm_fx = CPUParticles2D.new()
	_storm_fx.amount = 260
	_storm_fx.lifetime = 1.6
	_storm_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_storm_fx.emission_rect_extents = Vector2(40, 300)
	_storm_fx.position = Vector2(-220, -60)
	_storm_fx.direction = Vector2(1, 0.12)
	_storm_fx.spread = 8.0
	_storm_fx.initial_velocity_min = 220.0
	_storm_fx.initial_velocity_max = 320.0
	_storm_fx.gravity = Vector2.ZERO
	_storm_fx.color = Color(0.8, 0.55, 0.3, 0.55)
	_storm_fx.emitting = false
	_front_fx.add_child(_storm_fx)


# ---------------------------------------------------------------- train

func rebuild() -> void:
	var keep := {}
	for c in Game.carriages:
		keep[c["uid"]] = true
	for uid in views.keys():
		var old: CarriageView = views[uid]
		if not keep.has(uid) or old.type != Game.carriage(uid).get("type", ""):
			old.queue_free()
			views.erase(uid)
	var x := 0.0
	for c in Game.carriages:
		var v: CarriageView = views.get(c["uid"])
		if v == null:
			v = LocoView.new() if c["type"] == "locomotive" else CarriageView.new()
			v.uid = c["uid"]
			v.type = c["type"]
			v.level = c["level"]
			_train.add_child(v)
			views[c["uid"]] = v
		v.position.x = x
		x += (LocoView.LW + 6.0) if c["type"] == "locomotive" else PITCH
	ghost.position = Vector2(x, 0)
	# The next carriage waits at the end of the train as an outline that fills with parts.
	var next := Game.next_build()
	ghost.visible = next != ""
	if next != ghost.kind:
		ghost.kind = next
		ghost.shown = 0.0
	_train.ends = views.values().map(func(v): return v.position.x)
	_train.queue_redraw()
	var length := train_end()
	_dust.position = Vector2(length * 0.5, -2)
	_dust.emission_rect_extents = Vector2(length * 0.5, 2)
	_dust.amount = clampi(int(length / 6.0), 30, 200)
	set_selected(selected_uid)
	_set_cool()


func train_end() -> float:
	return ghost.position.x + (CarriageView.W if ghost.visible else 0.0)


func carriage_center(uid: int) -> Vector2:
	if uid == -1:
		return ghost.position + Vector2(CarriageView.W * 0.5, TRAIN_MID_Y)
	var v: CarriageView = views.get(uid)
	if v == null:
		return Vector2.ZERO
	var w := LocoView.LW if v is LocoView else CarriageView.W
	return v.position + Vector2(w * 0.5, TRAIN_MID_Y)


func set_selected(uid: int) -> void:
	selected_uid = uid
	for k in views:
		views[k].selected = (k == uid)
	ghost.selected = (uid == -1)


func focus(uid: int) -> void:
	_target_x = carriage_center(uid).x
	_vel = 0.0


## A restoration task finished: drop a new carriage in, or flash an upgraded one.
func celebrate(uid: int, built: bool) -> void:
	rebuild()
	var v: CarriageView = views.get(uid)
	if v == null:
		return
	v.level = Game.carriage(uid).get("level", v.level)
	if built:
		v.position.y = -70.0
		v.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(v, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "modulate:a", 1.0, 0.25)
		tw.chain().tween_callback(func():
			if not is_instance_valid(v):
				return
			v.flash = 1.0
			for k in 5:
				v.spark(Vector2(randf_range(10, CarriageView.W - 10), -20), 6, Color("ffcf7a")))
	else:
		v.flash = 1.0
		for k in 8:
			v.spark(Vector2(randf_range(20, CarriageView.W - 20), randf_range(-110, -40)), 6, Color("7ff0e0"))
	focus(uid)
	Audio.play("build" if built else "upgrade")


## Puzzle won: the heated carriage frosts over.
func frost_burst() -> void:
	var v: CarriageView = views.get(heat_uid)
	if v == null:
		return
	v.flash = 0.8
	v.frost = 1.0
	for k in 14:
		v.spark(Vector2(randf_range(10, CarriageView.W - 10), randf_range(-120, -30)), 6, Color("bff4ff"))


## New region: swap the scenery and landmark.
func on_region_started() -> void:
	_apply_region()
	_set_cool()
	rebuild()


func _apply_region() -> void:
	var c := Game.ch()
	for s in _layers.values():
		s.set_region(c["scenery"], c["landmark"], c["ground"])


func on_region_restored() -> void:
	_set_cool()


func _set_cool() -> void:
	for s in _layers.values():
		s.cool = 1.0 if Game.region_done else 0.0
		s.queue_redraw()


# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	_t += delta
	var vp := view_size()
	# Ambient: the scenery bakes as the puzzle heats up.
	_heat = move_toward(_heat, Game.heat_visual * 0.7, delta * 0.8)
	_storm = 0.0
	for s in _layers.values():
		s.heat = snappedf(_heat, 0.05)
		s.storm = 0.0
	for uid in views:
		views[uid].heat = Game.heat_visual if uid == heat_uid else 0.0
	if ghost.visible != (Game.next_build() != ""):
		rebuild()
	ghost.target = Game.task_progress()
	var sky: Node2D = _layers["landmark"]
	sky.tower = snappedf(Game.landmark_visibility(), 0.05)
	sky.restored = Game.region_done
	_storm_fx.emitting = _storm > 0.3
	_storm_rect.color.a = _storm * 0.28
	Audio.set_ambience_intensity(0.2 + _storm * 0.8)

	# Scenery motion = train speed.
	var speed := 70.0
	for p in _parallax:
		p.autoscroll = Vector2(speed * float(p.get_meta("auto")), 0)

	# Camera pan with inertia and soft focus. _cam is float; the camera snaps to whole pixels.
	if not _press:
		if not is_nan(_target_x):
			_cam.x = lerpf(_cam.x, _target_x, 1.0 - exp(-delta * 6.0))
			if absf(_cam.x - _target_x) < 0.5:
				_target_x = NAN
		else:
			_cam.x += _vel * delta
			_vel = move_toward(_vel, 0.0, absf(_vel) * 4.0 * delta + 10.0 * delta)
	var lo := -40.0 + vp.x * 0.5 - 60.0
	var hi := train_end() + 20.0 - vp.x * 0.5
	if hi < lo:
		_cam.x = (lo + hi) * 0.5
	else:
		_cam.x = clampf(_cam.x, lo, hi)
	_cam.y = lerpf(_cam.y, _target_y, 1.0 - exp(-delta * 8.0))
	var z := lerpf(camera.zoom.x, _target_zoom, 1.0 - exp(-delta * 8.0))
	camera.zoom = Vector2(z, z)
	_target_y = TRAIN_MID_Y + (get_viewport_rect().size.y * 0.5 - _band_mid) / z
	camera.position = _cam

	for n in _pinned:
		n.position.x = camera.get_screen_center_position().x - vp.x * 0.5
	# Shimmer band behind the train, effects follow the camera.
	_front_fx.position = camera.position
	_storm_rect.position = -vp * 0.5
	_storm_rect.size = vp

	# Rail-joint jolt travelling down the train.
	var i := 0
	for v in _train.get_children():
		if v is CarriageView and not _is_tweening(v):
			v.position.y = -1.0 if fmod(_t * 1.6 - i * 0.12, 1.0) < 0.06 else 0.0
		i += 1

	_whistle -= delta
	if _whistle <= 0.0:
		_whistle = randf_range(70.0, 150.0)
		Audio.play("whistle", 0.03)


func _is_tweening(v: Node2D) -> bool:
	return v.modulate.a < 1.0 or v.position.y < -1.5


## Camera keeps the train centred inside the visible band between top HUD and bottom panel.
func set_band(top_px: float, bottom_px: float) -> void:
	var want := (top_px + bottom_px) * 0.5
	_band_mid = want
	# Zoom out just enough for the whole train height to fit between HUD and sheet.
	_target_zoom = clampf((bottom_px - top_px - 16.0) / TRAIN_H, MIN_ZOOM, MAX_ZOOM)


## Visible world area in world units.
func view_size() -> Vector2:
	return get_viewport_rect().size / camera.zoom.x


func world_to_screen(p: Vector2) -> Vector2:
	return (p - camera.get_screen_center_position()) * camera.zoom.x + get_viewport_rect().size * 0.5


func screen_to_world(p: Vector2) -> Vector2:
	return (p - get_viewport_rect().size * 0.5) / camera.zoom.x + camera.get_screen_center_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		handle_input(event)


# ---------------------------------------------------------------- input

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_target_x = NAN
				_cam.x += (-40.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0)
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press = true
			_press_pos = mb.position
			_moved = 0.0
			_vel = 0.0
			_target_x = NAN
		elif _press:
			_press = false
			if _moved < 12.0:
				_tap(screen_to_world(mb.position))
			elif Time.get_ticks_msec() - _last_drag_time > 120:
				_vel = 0.0
	elif event is InputEventMouseMotion and _press:
		var mm := event as InputEventMouseMotion
		_moved += mm.relative.length()
		if _moved >= 12.0:
			var dx := mm.relative.x / camera.zoom.x
			_cam.x -= dx
			_vel = lerpf(_vel, -dx / maxf(get_process_delta_time(), 0.001), 0.35)
			_last_drag_time = Time.get_ticks_msec()


func _tap(wp: Vector2) -> void:
	if wp.y < -170.0 or wp.y > 10.0:
		tapped_empty.emit()
		return
	if ghost.visible and wp.x >= ghost.position.x and wp.x <= ghost.position.x + CarriageView.W:
		tapped_ghost.emit()
		return
	for uid in views:
		var v: CarriageView = views[uid]
		var w := LocoView.LW if v is LocoView else CarriageView.W
		if wp.x >= v.position.x and wp.x <= v.position.x + w:
			tapped_carriage.emit(uid)
			return
	tapped_empty.emit()


# ---------------------------------------------------------------- helper nodes

class Coupler extends Node2D:
	var ends: Array = []

	func _draw() -> void:
		for x in ends:
			if x > 0.0:
				draw_rect(Rect2(x - 8, -24, 10, 4), Color("2a2c31"))
				draw_rect(Rect2(x - 5, -26, 4, 8), Color("15171b"))


class Ghost extends Node2D:
	var selected := false
	var t := 0.0
	var kind := "" # carriage type being assembled
	var target := 0.0 # parts collected toward it, 0..1
	var shown := 0.0 # animated fill, rises after each win

	func _process(delta: float) -> void:
		t += delta
		shown = move_toward(shown, target, delta * 0.6)
		queue_redraw()

	func _draw() -> void:
		var full := shown >= 0.999
		var a := 0.55 + 0.25 * sin(t * (6.0 if full else 3.0)) + (0.2 if selected else 0.0)
		var col := Color(1.0, 0.82, 0.4, a) if full else Color(0.3, 0.95, 0.85, a)
		var w := CarriageView.W
		draw_rect(Rect2(0, -136, w, 116), Color(col.r, col.g, col.b, 0.07))
		if shown > 0.0:
			# Parts fill the frame from the floor up.
			var h := 116.0 * shown
			draw_rect(Rect2(1, -20 - h, w - 2, h), Color(col.r, col.g, col.b, 0.16 + (0.1 * sin(t * 6.0) if full else 0.0)))
			draw_rect(Rect2(1, -21 - h, w - 2, 2), Color(col.r, col.g, col.b, 0.8))
		var x := 0.0
		while x < w:
			draw_rect(Rect2(x, -136, minf(6, w - x), 1), col)
			draw_rect(Rect2(x, -21, minf(6, w - x), 1), col)
			x += 10.0
		var y := -136.0
		while y < -20.0:
			draw_rect(Rect2(0, y, 1, 6), col)
			draw_rect(Rect2(w - 1, y, 1, 6), col)
			y += 10.0
		for bx in [30.0, w - 30.0]:
			for wx in [bx - 13, bx + 13]:
				draw_arc(Vector2(wx, -7), 7, 0, TAU, 16, col, 1.0)
		var c := Vector2(w * 0.5, -78)
		draw_arc(c, 16, 0, TAU, 32, col, 2.0)
		draw_rect(Rect2(c.x - 8, c.y - 1, 16, 2), col)
		draw_rect(Rect2(c.x - 1, c.y - 8, 2, 16), col)


class DroneLayer extends CarriageView:
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var world := get_parent()
		for c in Game.carriages:
			if c["type"] != "dronebay" or not c["active"] or Game.drones_grounded():
				continue
			var v: CarriageView = world.views.get(c["uid"])
			if v == null:
				continue
			var base := v.position + Vector2(116, -150)
			var tau: float = c["timer"]
			var n := mini(c["level"], 3)
			var rem := Game.drone_run_time() - tau
			for i in n:
				var start := base + Vector2((i - 1) * 16, 0)
				var far := base + Vector2(170 + i * 36, -170 - i * 18)
				if tau < 4.0:
					var k := tau / 4.0
					var p := Vector2(lerpf(start.x, far.x, k * k), lerpf(start.y, far.y, sqrt(k)))
					draw_drone(p.round(), lerpf(1.0, 0.5, k), t + i)
				elif rem < 4.0:
					var k := 1.0 - rem / 4.0
					var p := Vector2(lerpf(far.x, start.x, sqrt(k)), lerpf(far.y, start.y, k * k))
					draw_drone(p.round(), lerpf(0.5, 1.0, k), t + i, true)
				else:
					# Scavenging over the ruins with searchlights.
					var p := base + Vector2(220 + i * 44 + sin(t * 0.7 + i * 2.0) * 30, -128 + sin(t * 1.3 + i) * 6)
					draw_polygon(PackedVector2Array([p + Vector2(-1, 2), p + Vector2(1, 2), p + Vector2(10, 40), p + Vector2(-6, 40)]),
						PackedColorArray([Color(0.6, 1, 0.95, 0.3), Color(0.6, 1, 0.95, 0.3), Color(0.6, 1, 0.95, 0), Color(0.6, 1, 0.95, 0)]))
					draw_drone(p.round(), 0.5, t + i)

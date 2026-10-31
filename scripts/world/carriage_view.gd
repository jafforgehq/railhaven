class_name CarriageView
extends Node2D
## Side-view cutaway of one carriage: Blender-rendered body, in-engine light/motion FX
## and animated crew. Local origin = left end at rail height; carriage spans x 0..W, y -164..0.
## In preview mode (uid == 0) it shows a fake crew sized to the level's slots.

const W := 232.0
const FLOOR := -32.0
const IN_TOP := -120.0
const SHIRT := {"Engineer": Color("c98a3a"), "Grower": Color("6f9a3a"), "Mechanic": Color("4f86b0"),
	"Pilot": Color("d0702a"), "Technician": Color("3fa29a")}

var uid := 0
var type := "workshop"
var level := 1
var selected := false
var flash := 0.0
var hatch := 0.0 # drone bay roof hatch 0 closed .. 1 open
var docked := 1 # drones visible on pads
var t := 0.0
var _crew := {} # sid -> {x, tx, state, timer, face}
var _sparks: Array = [] # [pos, vel, life]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for n in ["wheel", "wheel_big", "rod", "fan", "drone", "drone_crate"]:
		art(n)


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 2.0)
	if uid != 0:
		var c := Game.carriage(uid)
		if c.is_empty():
			return
		level = c["level"]
		if type == "dronebay":
			var phase: float = c["timer"]
			var active: bool = c["active"] and not Game.drones_grounded()
			var away := active and phase > 2.0 and phase < Data.DRONE_RUN_TIME - 2.5
			hatch = move_toward(hatch, 1.0 if (active and (phase < 4.0 or phase > Data.DRONE_RUN_TIME - 5.0)) else 0.0, delta * 1.5)
			docked = 0 if away else Data.drones(level)
	elif type == "dronebay":
		docked = Data.drones(level)
	# Textures load outside _draw (loading inside a draw call can leave a blank white quad).
	art("locomotive" if type == "locomotive" else "carriage_%s_%d" % [type, level])
	_update_crew(delta)
	_update_sparks(delta)
	if _visible_on_screen():
		queue_redraw()


func _visible_on_screen() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var cam := vp.get_camera_2d()
	if cam == null:
		return true
	var cx := cam.get_screen_center_position().x
	var half := vp.get_visible_rect().size.x * 0.5 / cam.zoom.x + 40.0
	return global_position.x + W > cx - half and global_position.x < cx + half


# ---------------------------------------------------------------- crew logic

func _crew_list() -> Array:
	if uid == 0:
		var fake := []
		var n := Data.slots(type, level) if type != "quarters" else mini(1 + level, 4)
		for i in n:
			fake.append({"id": 1000 + i, "role": Data.CARRIAGES[type].get("role", "Engineer"), "look": {"skin": i % 4, "hair": (i * 2 + 1) % 6, "hat": i % 3}})
		return fake
	if type == "quarters":
		# Resting crew are spread over all living quarters.
		var idle := Game.idle_survivors()
		var homes := Game.carriages.filter(func(c): return c["type"] == "quarters")
		var idx := homes.find(Game.carriage(uid))
		var out := []
		for i in idle.size():
			if homes.size() > 0 and i % homes.size() == idx:
				out.append(idle[i])
		return out
	return Game.workers_in(uid)


func _stations() -> Array:
	match type:
		"workshop": return [40.0, 92.0, 150.0, 196.0]
		"greenhouse": return [36.0, 82.0, 128.0, 176.0, 204.0]
		"recycler": return [44.0, 104.0, 160.0, 200.0]
		"cooling": return [150.0, 196.0]
		"dronebay": return [52.0, 116.0, 176.0]
		"quarters": return [60.0, 120.0, 150.0, 190.0]
		"locomotive": return [150.0]
	return [100.0]


func _update_crew(delta: float) -> void:
	var list := _crew_list()
	var seen := {}
	var st := _stations()
	var i := 0
	for s in list:
		var id: int = s["id"]
		seen[id] = true
		if not _crew.has(id):
			CrewSprites.tex(CrewSprites.preset_for(s["role"], s["look"]))
			var sx: float = st[i % st.size()]
			_crew[id] = {"x": sx, "tx": sx, "state": "work", "timer": randf_range(1.0, 5.0), "face": 1 if i % 2 == 0 else -1, "s": s, "i": i}
		var w: Dictionary = _crew[id]
		w["s"] = s
		w["i"] = i
		w["timer"] -= delta
		if w["state"] == "walk":
			w["x"] = move_toward(w["x"], w["tx"], 16.0 * delta)
			if is_equal_approx(w["x"], w["tx"]):
				w["state"] = "work"
				w["timer"] = randf_range(4.0, 9.0)
		elif w["timer"] <= 0.0:
			var target: float = st[(i + randi_range(0, st.size() - 1)) % st.size()] + randf_range(-6, 6)
			if type == "quarters":
				match i % 3:
					0: target = w["x"] # sleepers stay put
					1: target = [164.0, 188.0][(i / 3) % 2] # diners sit at the mess table
					2: target = randf_range(56.0, 140.0)
			w["tx"] = clampf(target, 28.0, W - 28.0)
			w["face"] = 1 if w["tx"] > w["x"] else -1
			w["state"] = "walk" if absf(w["tx"] - w["x"]) > 2.0 else "work"
			w["timer"] = randf_range(3.0, 7.0)
		i += 1
	for id in _crew.keys():
		if not seen.has(id):
			_crew.erase(id)


func _update_sparks(delta: float) -> void:
	for sp in _sparks:
		sp[1].y += 120.0 * delta
		sp[0] += sp[1] * delta
		sp[2] -= delta
	_sparks = _sparks.filter(func(sp): return sp[2] > 0.0)


func spark(at: Vector2, n := 5, col := Color("ffd27a")) -> void:
	for k in n:
		_sparks.append([at, Vector2(randf_range(-40, 40), randf_range(-60, -10)), randf_range(0.2, 0.5), col])


# ---------------------------------------------------------------- drawing
# Art comes from Blender (art/blender/carriages.py); this layer adds light and motion FX.

const TRAIN_DIR := "res://assets/sprites/train/"
const ART_RECT := Rect2(-4, -164, 240, 164) # region rendered in Blender (world units)

static var _art := {}
static var _glow_tex: Texture2D


static func art(name: String) -> Texture2D:
	if not _art.has(name):
		_art[name] = load(TRAIN_DIR + name + ".png")
	return _art[name]


## Soft radial light (one shared gradient texture, tinted per call).
static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.35))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_glow_tex = tex
	return _glow_tex


func glow(c: Vector2, r: float, col: Color, a := 0.25) -> void:
	draw_texture_rect(glow_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col, a * 1.6))


func ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


## Sprite part centred at `c`, `size` in world units, optional rotation.
func part(name: String, c: Vector2, size: Vector2, rot := 0.0, mod := Color.WHITE, flip := false) -> void:
	draw_set_transform(c, rot, Vector2(-1.0 if flip else 1.0, 1.0))
	draw_texture_rect(art(name), Rect2(-size * 0.5, size), false, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	draw_texture_rect(art("carriage_%s_%d" % [type, level]), ART_RECT, false)
	_draw_lights()
	match type:
		"quarters": _fx_quarters()
		"greenhouse": _fx_greenhouse()
		"recycler": _fx_recycler()
		"workshop": glow(Vector2(103.5, -66), 20, Color(1, 0.7, 0.35), 0.22)
		"cooling": _fx_cooling()
		"dronebay": _fx_dronebay()
	_draw_crew()
	for sp in _sparks:
		draw_circle(sp[0], 0.8, sp[3])
		draw_circle(sp[0], 2.0, Color(sp[3], 0.25))
	_draw_wheels()
	if flash > 0.0:
		draw_rect(Rect2(0, -146, W, 146), Color(1, 1, 1, flash * 0.6))
	if selected:
		var a := 0.6 + 0.4 * sin(t * 5.0)
		var r := Shapes.rounded(Rect2(-3, -152, W + 6, 140), 6.0)
		r.append(r[0])
		draw_polyline(r, Color(0.25, 0.95, 0.85, a), 1.6)


func _lamps() -> Array:
	return [58.0, 174.0] if level < 3 else [40.0, 116.0, 192.0]


func _lamp_color() -> Color:
	match type:
		"quarters", "workshop": return Color(1.0, 0.8, 0.5)
		"greenhouse": return Color(1.0, 0.82, 0.95)
	return Color(0.6, 1.0, 0.95)


func _draw_lights() -> void:
	var lamp := _lamp_color()
	for lx in _lamps():
		var hy := IN_TOP + 15.0
		draw_polygon(PackedVector2Array([Vector2(lx - 7, hy), Vector2(lx + 7, hy), Vector2(lx + 36, FLOOR), Vector2(lx - 36, FLOOR)]),
			PackedColorArray([Color(lamp, 0.18), Color(lamp, 0.18), Color(lamp, 0.0), Color(lamp, 0.0)]))
		glow(Vector2(lx, hy), 12, lamp, 0.3)
		ellipse(Vector2(lx, FLOOR + 1.2), 28, 2.2, Color(lamp, 0.14))
	for sx in [3.5, W - 3.5]:
		glow(Vector2(sx, -88), 6.0, Color(1.0, 0.6, 0.3), 0.18 * (0.7 + 0.3 * sin(t * 3.0 + sx)))


func _fx_quarters() -> void:
	var flick := 0.75 + 0.25 * sin(t * 11.0) * sin(t * 7.3)
	glow(Vector2(213.5, FLOOR - 13), 18, Color(1, 0.55, 0.2), 0.4 * flick)
	glow(Vector2(196, -70), 26, Color(1, 0.72, 0.4), 0.14)


func _fx_greenhouse() -> void:
	if fmod(t, 6.0) < 1.4:
		for k in 14:
			draw_circle(Vector2(20 + k * 15 + sin(t * 9 + k) * 3, IN_TOP + 18 + fmod(t * 30 + k * 7, 40)), 0.5, Color(0.8, 1, 1, 0.6))
	for k in 6:
		var dy := fmod(t * 30.0 + k * 13.0, 60.0)
		draw_circle(Vector2(26 + k * 36, IN_TOP + 16 + dy), 0.6, Color(0.7, 0.95, 1.0, 0.8 - dy / 80.0))


func _fx_recycler() -> void:
	var tanks := mini(1 + level / 2, 3)
	for k in tanks:
		var tx := 18.0 + k * 60.0
		for b in 7:
			var by := FLOOR - 9.0 - fmod(t * 12.0 + b * 9.0 + k * 5.0, 30.0)
			draw_circle(Vector2(tx + 7 + b * 4.5 + sin(t * 4.0 + b) * 0.8, by), 0.6 + (b % 3) * 0.35, Color(0.85, 1, 1, 0.75))
	for k in 6:
		var on := fmod(t * 2.0 + k * 0.7, 2.0) < 1.0
		var c := Vector2(W - 38 + (k % 3) * 9, -88 + (k / 3) * 9)
		draw_circle(c, 1.6, Color("3fd8c2") if on else Color("1d4440"))
		if on:
			glow(c, 4.0, Color(0.25, 0.85, 0.75), 0.3)
	draw_circle(Vector2(W - 54, IN_TOP + 12 + fmod(t * 40.0, 30.0)), 0.7, Color(0.6, 0.9, 1.0, 0.8))


func _fx_cooling() -> void:
	var fans := mini(1 + level / 2, 3)
	for f in fans:
		var c := Vector2(36 + f * 50, FLOOR - 38)
		glow(c, 30, Color(0.4, 0.9, 1.0), 0.12 + 0.05 * sin(t * 2.0 + f))
		part("fan", c, Vector2(38, 38), t * (6.0 + level) + f)
	var wave := PackedVector2Array()
	for i in 12:
		wave.append(Vector2(W - 42 + i * 2.2, FLOOR - 21.5 + sin(t * 6.0 + i * 0.8) * 3.0))
	draw_polyline(wave, Color("3fd8c2"), 0.7)
	for k in 10:
		var mx := fmod(t * 9.0 + k * 23.0, W - 24.0) + 12.0
		ellipse(Vector2(mx, FLOOR - 2 - (k % 3) * 2), 5, 1.2, Color(0.8, 1, 1, 0.12))


func _fx_dronebay() -> void:
	for p in mini(Data.drones(level), 3):
		var px := 44.0 + p * 64.0
		glow(Vector2(px, FLOOR - 8), 16, Color(0.25, 0.85, 0.76), 0.18 + 0.12 * sin(t * 3.0 + p))
		if p < docked:
			part("drone", Vector2(px, FLOOR - 16 + sin(t * 2.0 + p) * 0.5), Vector2(38, 28))
	var rc := Vector2(28, -89)
	var sa := t * 2.5
	draw_colored_polygon(PackedVector2Array([rc, rc + Vector2(cos(sa), sin(sa)) * 8, rc + Vector2(cos(sa - 0.5), sin(sa - 0.5)) * 8]), Color(0.25, 0.85, 0.76, 0.4))
	draw_circle(rc + Vector2(4, -3), 0.8, Color("ffb050"))


func _draw_wheels() -> void:
	var spin := -t * 9.0
	for bx in [30.0, W - 30.0]:
		for wx in [bx - 13, bx + 13]:
			part("wheel", Vector2(wx, -7), Vector2(17, 17), spin)


## Drone sprite for the flying salvage layer (s = 1 is full size).
func draw_drone(c: Vector2, s: float, ang: float, crate := false) -> void:
	part("drone_crate" if crate else "drone", c + (Vector2(0, 3.5 * s) if crate else Vector2.ZERO), Vector2(38, 28) * s, sin(ang) * 0.05)


# ---------------------------------------------------------------- crew drawing

func _draw_crew() -> void:
	for id in _crew:
		var w: Dictionary = _crew[id]
		var s: Dictionary = w["s"]
		var preset := CrewSprites.preset_for(s["role"], s["look"])
		var tt := t + float(id) * 0.37
		var pose := _work_pose(w)
		if w["state"] == "walk":
			pose = "carry" if (type == "workshop" or type == "dronebay") and int(id) % 2 == 0 else "walk"
		var p := Vector2(w["x"], FLOOR)
		if pose == "sleep":
			var bunks := mini(1 + level / 2, 3)
			var bunk: int = int(w["i"]) % (bunks * 2)
			p = Vector2(32.0 + (bunk / 2) * 40.0, FLOOR - 17.0 - (bunk % 2) * 26.0)
			CrewSprites.draw_sleep(self, p, preset, tt)
			var zt := fmod(tt, 3.0)
			draw_string(UIKit.font_bold, p + Vector2(-14 + zt * 3, -12 - zt * 5), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 1.0 - zt / 3.0))
			continue
		CrewSprites.draw(self, p, preset, pose, tt, w["face"])
		if pose == "hammer":
			var k := fmod(tt * CrewSprites.FPS["hammer"] / 8.0, 1.0)
			if k > 0.68 and k < 0.72:
				spark(p + Vector2(w["face"] * 12.0, -16.0), 6)


func _work_pose(w: Dictionary) -> String:
	match type:
		"workshop": return "hammer"
		"greenhouse": return "tend"
		"recycler", "cooling": return "panel"
		"dronebay": return "wrench"
		"quarters":
			return ["sleep", "sit", "idle"][int(w["i"]) % 3]
	return "idle"

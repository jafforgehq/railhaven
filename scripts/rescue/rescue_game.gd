class_name RescueGame
extends Control
## "Pull the pin" rescue mission (every 15 levels): a crew member is overheating in a pod at the
## bottom of a machinery chamber. Tap valve pins to slide them out so blue coolant falls into
## the pod; hot sand must stay away (hot sand touching coolant turns both into stone).
## Physics runs in its own SubViewport (own World2D): RigidBody2D balls, AnimatableBody2D pins,
## StaticBody2D walls.

signal finished(won: bool)

const W := 720.0
const H := 1000.0
const R := 21.0 # ball collision radius (sprites are 48 px with a 20-22 px body)
const WALL := 24.0
const DIR := "res://assets/sprites/rescue/"
const BASIN := Rect2(284, 830, 152, 152) # the pod and the pile in its mouth, chamber coords
const POD := Rect2(260, 840, 200, 160)
const NEED := 6
## Each layout: walls as segments [x1, y1, x2, y2], pins as [x0, x1, y, handle side (-1 left, 1 right)],
## spawn rects for coolant and hot sand. The pod and the outer frame are shared.
const LAYOUTS := [
	{"name": "Two valves", "hint": "Only one valve leads to safety. Pick wisely!",
		"walls": [[360, 40, 360, 430], [40, 600, 285, 880], [680, 600, 435, 880]],
		"pins": [[40, 348, 440, -1], [372, 680, 440, 1]],
		"cool": Rect2(70, 140, 260, 260), "hot": Rect2(390, 140, 260, 260)},
	{"name": "Stacked tanks", "hint": "Hot sand sits on top of the coolant. Mind the order!",
		"walls": [[200, 40, 200, 330], [520, 40, 520, 330], [200, 362, 200, 600], [520, 362, 520, 600], [40, 680, 285, 880], [680, 680, 435, 880]],
		"pins": [[188, 532, 346, -1], [188, 532, 616, 1]],
		"hot": Rect2(225, 90, 270, 220), "cool": Rect2(225, 380, 270, 200)},
	{"name": "Side bunkers", "hint": "Hot sand waits on both sides. Open the middle only.",
		"walls": [[230, 40, 230, 300], [490, 40, 490, 300], [230, 336, 230, 600], [490, 336, 490, 600], [40, 690, 285, 880], [680, 690, 435, 880]],
		"pins": [[218, 502, 318, -1], [218, 502, 616, 1], [40, 218, 590, -1], [502, 680, 590, 1]],
		"cool": Rect2(250, 90, 220, 210), "hot": Rect2(60, 400, 150, 170), "hot2": Rect2(510, 400, 150, 170)},
]

var main: Node
var layout := 0
var state := "play" # play | won | lost
var _vp: SubViewport
var _chamber: Chamber
var _pins: Array = [] # {body, x0, x1, y, side, pulled}
var _balls: Array[RigidBody2D] = []
var _tex := {}
var _hint: Label
var _since_pull := -1.0
var _settle := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for n in ["pin", "ball_cool", "ball_hot", "ball_stone", "wall", "chamber_bg", "capsule", "capsule_happy_glow"]:
		if ResourceLoader.exists(DIR + n + ".png"):
			_tex[n] = load(DIR + n + ".png")
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var top := UIKit.panel("Bar")
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top)
	var m := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	m.add_theme_constant_override("margin_top", 8 + int(main.safe_top()))
	top.add_child(m)
	var back := UIKit.button("LEAVE", "FlatButton", "close", 56)
	back.pressed.connect(func(): _finish(false, true))
	var d: Dictionary = LAYOUTS[layout % LAYOUTS.size()]
	var title := UIKit.label("RESCUE: " + d["name"].to_upper(), "Header")
	_hint = UIKit.label(d["hint"], "Small")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var col := UIKit.vbox(-2, [title, _hint])
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(UIKit.hbox(10, [back, col]))
	var box := SubViewportContainer.new()
	box.size = Vector2(W, H)
	add_child(box)
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(W), int(H))
	_vp.physics_object_picking = false
	_vp.transparent_bg = false
	box.add_child(_vp)
	_chamber = Chamber.new()
	_chamber.game = self
	_vp.add_child(_chamber)
	_build(d)
	box.gui_input.connect(_on_input)
	resized.connect(func(): box.position = Vector2((size.x - W) * 0.5, maxf(top.get_combined_minimum_size().y, (size.y - H) * 0.5 + 40.0)))
	box.position = Vector2(0, 130)


func _build(d: Dictionary) -> void:
	var walls: Array = [[0, 0, 40, H], [W - 40, 0, 40, H], [0, 0, W, 40], [0, H - 18, W, 18],
		[POD.position.x + 18, POD.position.y + 64, 12, 82], [POD.end.x - 30, POD.position.y + 64, 12, 82],
		[POD.position.x + 18, POD.position.y + 140, POD.size.x - 36, 14]]
	for r in walls:
		_static_rect(Rect2(r[0], r[1], r[2], r[3]), 0.0, false)
	for s in d["walls"]:
		var a := Vector2(s[0], s[1])
		var b := Vector2(s[2], s[3])
		_static_rect(Rect2((a + b) * 0.5 - Vector2(a.distance_to(b) * 0.5, WALL * 0.5), Vector2(a.distance_to(b), WALL)), a.angle_to_point(b), true)
	for p in d["pins"]:
		_add_pin(p[0], p[1], p[2], p[3])
	_spawn(d["cool"], "cool", 10)
	_spawn(d["hot"], "hot", 8)
	if d.has("hot2"):
		_spawn(d["hot2"], "hot", 8)


func _static_rect(r: Rect2, angle: float, visible_wall: bool) -> void:
	var body := StaticBody2D.new()
	body.position = r.get_center()
	body.rotation = angle
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	shape.shape = rs
	body.add_child(shape)
	_chamber.add_child(body)
	if visible_wall:
		_chamber.walls.append([r.get_center(), angle, r.size])


func _add_pin(x0: float, x1: float, y: float, side: int) -> void:
	var body := AnimatableBody2D.new()
	body.sync_to_physics = true
	body.position = Vector2((x0 + x1) * 0.5, y)
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(x1 - x0, 18)
	shape.shape = rs
	body.add_child(shape)
	_chamber.add_child(body)
	_pins.append({"body": body, "x0": x0, "x1": x1, "y": y, "side": side, "pulled": false})


func _spawn(r: Rect2, kind: String, n: int) -> void:
	var cols := maxi(1, int(r.size.x / (R * 2.2)))
	for i in n:
		var b := RigidBody2D.new()
		# Fixed stagger (no randomness) so every run of a layout plays out the same way.
		b.position = r.position + Vector2(R + (i % cols) * R * 2.2 + (i / cols % 2) * R * 0.5, r.size.y - R - (i / cols) * R * 2.1)
		b.contact_monitor = true
		b.max_contacts_reported = 4
		b.physics_material_override = PhysicsMaterial.new()
		b.physics_material_override.friction = 0.2
		b.physics_material_override.bounce = 0.05
		var shape := CollisionShape2D.new()
		var cs := CircleShape2D.new()
		cs.radius = R
		shape.shape = cs
		b.add_child(shape)
		var sp := Sprite2D.new()
		sp.texture = _tex.get("ball_" + kind)
		b.add_child(sp)
		b.set_meta("kind", kind)
		b.set_meta("sprite", sp)
		b.body_entered.connect(_on_contact.bind(b))
		_chamber.add_child(b)
		_balls.append(b)


## Hot sand touching coolant: both cool into stone with a puff of steam.
func _on_contact(other: Node, b: RigidBody2D) -> void:
	if not other is RigidBody2D or state != "play":
		return
	var kinds := [b.get_meta("kind"), other.get_meta("kind", "")]
	if "hot" in kinds and "cool" in kinds:
		for x in [b, other]:
			x.set_meta("kind", "stone")
			(x.get_meta("sprite") as Sprite2D).texture = _tex.get("ball_stone")
		_chamber.puff((b.position + other.position) * 0.5)
		Audio.play("collect", 0.05)


func _on_input(e: InputEvent) -> void:
	if state != "play" or not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = e.position
	for pin in _pins:
		if pin["pulled"]:
			continue
		var r := Rect2(pin["x0"] - 30, pin["y"] - 34, pin["x1"] - pin["x0"] + 60, 68)
		if r.has_point(p):
			pull(_pins.find(pin))
			return


## Slides pin i out of the chamber (also used by tests).
func pull(i: int) -> void:
	var pin: Dictionary = _pins[i]
	if pin["pulled"]:
		return
	pin["pulled"] = true
	_since_pull = 0.0
	var body: AnimatableBody2D = pin["body"]
	var dist: float = (pin["x1"] - pin["x0"]) + 120.0
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(body, "position:x", body.position.x + dist * pin["side"], 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): body.collision_layer = 0)
	Audio.play("ui_click")


func count_in_pod(kind: String) -> int:
	var n := 0
	for b in _balls:
		if b.get_meta("kind") == kind and BASIN.has_point(b.position):
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if state != "play":
		return
	if count_in_pod("hot") > 0:
		_end(false, "Hot sand reached the pod!")
		return
	if count_in_pod("cool") >= NEED:
		_settle += delta
		if _settle > 0.4:
			_end(true, "")
		return
	_settle = 0.0
	var cool_left := _balls.filter(func(b): return b.get_meta("kind") == "cool").size()
	if cool_left < NEED:
		_end(false, "Not enough coolant left!")
		return
	if _since_pull >= 0.0:
		_since_pull += delta
		var all_pulled := _pins.all(func(p): return p["pulled"])
		if all_pulled and _since_pull > 4.0:
			_end(false, "The coolant never made it.")


func _end(won: bool, why: String) -> void:
	state = "won" if won else "lost"
	_chamber.happy = won
	if not won:
		_hint.text = why
		_hint.add_theme_color_override("font_color", UIKit.RED)
	await get_tree().create_timer(0.9).timeout
	if is_inside_tree():
		_finish(won, false)


func _finish(won: bool, left: bool) -> void:
	finished.emit(won if not left else false)


## Draws the chamber background, tiled walls, pins, pod and crew.
class Chamber extends Node2D:
	var game: RescueGame
	var walls: Array = [] # [centre, angle, size]
	var happy := false
	var _t := 0.0
	var _puffs: Array = []

	func puff(at: Vector2) -> void:
		for k in 10:
			_puffs.append({"p": at, "v": Vector2(randf_range(-40, 40), randf_range(-90, -30)), "life": randf_range(0.5, 1.0)})

	func _process(delta: float) -> void:
		_t += delta
		for p in _puffs:
			p["p"] += p["v"] * delta
			p["life"] -= delta
		_puffs = _puffs.filter(func(p): return p["life"] > 0.0)
		queue_redraw()

	func _draw() -> void:
		var tex: Dictionary = game._tex
		if tex.has("chamber_bg"):
			draw_texture_rect_region(tex["chamber_bg"], Rect2(0, 0, W, H), Rect2(0, 50, 720, 1000))
		else:
			draw_rect(Rect2(0, 0, W, H), Color("1b2026"))
		# Frame.
		for r in [Rect2(0, 0, 40, H), Rect2(W - 40, 0, 40, H), Rect2(0, 0, W, 40), Rect2(0, H - 18, W, 18)]:
			_tiled(r)
		for w in walls:
			draw_set_transform(w[0], w[1])
			_tiled(Rect2(-w[2] * 0.5, w[2]))
			draw_set_transform(Vector2.ZERO)
		# Crew in the pod, then the pod glass in front.
		draw_set_transform(Vector2(360, 980), 0.0, Vector2(2.4, 2.4))
		CrewSprites.draw(self, Vector2.ZERO, "mechanic_a", "sit" if happy else "idle", _t, 1)
		draw_set_transform(Vector2.ZERO)
		if not happy and game.state == "play":
			draw_texture_rect(CarriageView.glow_texture(), Rect2(300, 860, 120, 120), false, Color(1, 0.4, 0.1, 0.35 + 0.15 * sin(_t * 5.0)))
		if tex.has("capsule"):
			draw_texture_rect(tex["capsule"], POD, false)
		if happy and tex.has("capsule_happy_glow"):
			draw_texture_rect(tex["capsule_happy_glow"], POD, false)
		# Pins: rod stretched between the walls, handle at the pulling end.
		for pin in game._pins:
			var body: AnimatableBody2D = pin["body"]
			var len: float = pin["x1"] - pin["x0"]
			var c := body.position
			var side: int = pin["side"]
			if tex.has("pin"):
				var rod := Rect2(c.x - len * 0.5, c.y - 24, len, 48)
				draw_texture_rect_region(tex["pin"], rod, Rect2(57, 0, 263, 48))
				if side < 0:
					draw_texture_rect_region(tex["pin"], Rect2(rod.position.x - 57, c.y - 24, 57, 48), Rect2(0, 0, 57, 48))
				else: # handle on the right: mirror it
					draw_set_transform(Vector2(rod.end.x + 57, c.y - 24), 0.0, Vector2(-1, 1))
					draw_texture_rect_region(tex["pin"], Rect2(0, 0, 57, 48), Rect2(0, 0, 57, 48))
					draw_set_transform(Vector2.ZERO)
			else:
				draw_rect(Rect2(c.x - len * 0.5, c.y - 9, len, 18), Color("c9d1da"))
		for p in _puffs:
			draw_circle(p["p"], 6.0 * p["life"] + 2.0, Color(1, 1, 1, 0.5 * p["life"]))

	func _tiled(r: Rect2) -> void:
		if game._tex.has("wall"):
			draw_texture_rect(game._tex["wall"], r, true)
		else:
			draw_rect(r, Color("3a4048"))

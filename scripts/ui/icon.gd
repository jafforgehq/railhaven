@tool
class_name Icon
extends Control
## Vector icon drawn in code (placeholder art). Kinds: scrap, parts, food, water, crew,
## train, home, cooling, drone, temp, sun, shield, warning, map, wrench, check, lock,
## up, plus, close, menu, clock, tower, bed, hammer, music, sound, star.

@export var kind := "parts":
	set(v):
		kind = v
		queue_redraw()
@export var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()

const RES_COLORS := {"scrap": Color("c9d1da"), "parts": Color("d8c08a"), "food": Color("8be06a"), "water": Color("5bb8ff"),
	"crew": Color("e8dcc4")}


static func make(k: String, size := 28.0, col := Color(0, 0, 0, 0)) -> Icon:
	var i := Icon.new()
	i.kind = k
	i.color = col if col.a > 0.0 else RES_COLORS.get(k, Color("f1e6cf"))
	i.custom_minimum_size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


const ART := ["arrow", "bulb", "scrap", "parts", "food", "water", "crew", "home", "cooling", "drone", "train", "tower",
	"wrench", "hammer", "bed", "shield", "sun", "temp", "map", "star", "warning",
	"data", "flask", "medkit", "crate", "raider", "trade", "rail", "ash", "desal", "mirror", "archive", "haven", "trophy",
	"heart", "snowflake", "undo", "tank", "condenser", "play", "gift",
	"magnet", "frostcharge", "key", "lock", "streak", "calendar", "card", "flag", "boss", "fox"]
static var _art := {}


## Blender-rendered icons (art/blender/icons.py); loaded once, never inside a draw call.
static func preload_art() -> void:
	for k in ART:
		var p := "res://assets/sprites/icons/icon_%s.png" % k
		if ResourceLoader.exists(p): # icons still being rendered fall back to vector glyphs
			_art[k] = load(p)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
	draw_kind(self, kind, Rect2(Vector2.ZERO, size), color)


static func draw_kind(ci: CanvasItem, k: String, r: Rect2, c: Color) -> void:
	if _art.has(k):
		var side := minf(r.size.x, r.size.y) * 1.12
		var dim := c.v < 0.45 # icons on bright buttons keep their colours but sit a touch darker
		ci.draw_texture_rect(_art[k], Rect2(r.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(0.85, 0.85, 0.85) if dim else Color.WHITE)
		return
	var s := minf(r.size.x, r.size.y)
	var o := r.position + (r.size - Vector2(s, s)) * 0.5
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var dark := c.darkened(0.55)
	match k:
		"scrap":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.1, 0.62), P.call(0.32, 0.38), P.call(0.92, 0.38), P.call(0.7, 0.62)]), c.lightened(0.2))
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.1, 0.62), P.call(0.7, 0.62), P.call(0.7, 0.8), P.call(0.1, 0.8)]), c)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.7, 0.62), P.call(0.92, 0.38), P.call(0.92, 0.56), P.call(0.7, 0.8)]), c.darkened(0.3))
			ci.draw_line(P.call(0.36, 0.44), P.call(0.8, 0.44), Color(1, 1, 1, 0.6), maxf(1.0, s * 0.04))
		"parts":
			var pts := PackedVector2Array()
			var center: Vector2 = P.call(0.5, 0.5)
			for i in 32:
				var a := TAU * i / 32.0
				var rad := s * (0.46 if (i / 2) % 2 == 0 else 0.34)
				pts.append(center + Vector2(cos(a), sin(a)) * rad)
			ci.draw_colored_polygon(pts, c)
			ci.draw_circle(center, s * 0.15, dark)
		"food":
			var pts := PackedVector2Array()
			for i in 21:
				var tt := i / 20.0
				var y := lerpf(0.88, 0.1, tt)
				var w := sin(tt * PI) * 0.3
				pts.append(P.call(0.5 - w + (0.5 - tt) * 0.2, y))
			for i in 21:
				var tt := 1.0 - i / 20.0
				var y := lerpf(0.88, 0.1, tt)
				var w := sin(tt * PI) * 0.3
				pts.append(P.call(0.5 + w + (0.5 - tt) * 0.2, y))
			ci.draw_colored_polygon(pts, c)
			ci.draw_line(P.call(0.6, 0.88), P.call(0.42, 0.2), dark, maxf(1.0, s * 0.05))
		"water":
			var pts := PackedVector2Array([P.call(0.5, 0.06)])
			for i in 25:
				var a := lerpf(-PI * 0.15, PI * 1.15, i / 24.0)
				pts.append(P.call(0.5, 0.62) + Vector2(cos(a), sin(a)) * s * 0.3)
			ci.draw_colored_polygon(pts, c)
			ci.draw_circle(P.call(0.4, 0.62), s * 0.07, Color(1, 1, 1, 0.6))
		"crew":
			ci.draw_circle(P.call(0.34, 0.32), s * 0.14, c.darkened(0.15))
			ci.draw_colored_polygon(_ellipse_top(P.call(0.34, 0.86), s * 0.24, s * 0.34), c.darkened(0.15))
			ci.draw_circle(P.call(0.64, 0.36), s * 0.15, c)
			ci.draw_colored_polygon(_ellipse_top(P.call(0.64, 0.92), s * 0.26, s * 0.36), c)
		"train":
			ci.draw_rect(Rect2(P.call(0.12, 0.3), Vector2(0.5, 0.36) * s), c)
			ci.draw_rect(Rect2(P.call(0.6, 0.18), Vector2(0.28, 0.48) * s), c)
			ci.draw_rect(Rect2(P.call(0.2, 0.18), Vector2(0.1, 0.14) * s), c)
			ci.draw_rect(Rect2(P.call(0.66, 0.26), Vector2(0.16, 0.14) * s), dark)
			for x in [0.24, 0.48, 0.74]:
				ci.draw_circle(P.call(x, 0.74), s * 0.09, c)
			ci.draw_rect(Rect2(P.call(0.06, 0.86), Vector2(0.88, 0.05) * s), c)
		"home":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.08, 0.48), P.call(0.5, 0.1), P.call(0.92, 0.48)]), c)
			ci.draw_rect(Rect2(P.call(0.2, 0.46), Vector2(0.6, 0.44) * s), c)
			ci.draw_rect(Rect2(P.call(0.42, 0.62), Vector2(0.16, 0.28) * s), dark)
		"cooling":
			var cc: Vector2 = P.call(0.5, 0.5)
			for i in 3:
				var a := PI * i / 3.0 + PI / 2.0
				var d := Vector2(cos(a), sin(a)) * s * 0.42
				ci.draw_line(cc - d, cc + d, c, maxf(1.5, s * 0.08))
				for sg in [-1.0, 1.0]:
					var tip: Vector2 = cc + d * sg
					var b: Vector2 = cc + d * sg * 0.6
					var perp := Vector2(-d.y, d.x).normalized() * s * 0.12
					ci.draw_line(b, tip - d * sg * 0.05 + perp, c, maxf(1.0, s * 0.06))
					ci.draw_line(b, tip - d * sg * 0.05 - perp, c, maxf(1.0, s * 0.06))
		"drone":
			ci.draw_rect(Rect2(P.call(0.3, 0.45), Vector2(0.4, 0.18) * s), c)
			ci.draw_rect(Rect2(P.call(0.18, 0.4), Vector2(0.64, 0.06) * s), c)
			ci.draw_rect(Rect2(P.call(0.04, 0.3), Vector2(0.3, 0.05) * s), c)
			ci.draw_rect(Rect2(P.call(0.66, 0.3), Vector2(0.3, 0.05) * s), c)
			ci.draw_line(P.call(0.19, 0.33), P.call(0.19, 0.44), c, maxf(1.0, s * 0.05))
			ci.draw_line(P.call(0.81, 0.33), P.call(0.81, 0.44), c, maxf(1.0, s * 0.05))
			ci.draw_line(P.call(0.36, 0.62), P.call(0.3, 0.78), c, maxf(1.0, s * 0.05))
			ci.draw_line(P.call(0.64, 0.62), P.call(0.7, 0.78), c, maxf(1.0, s * 0.05))
			ci.draw_circle(P.call(0.5, 0.54), s * 0.05, Color("3fd8c2"))
		"temp":
			ci.draw_rect(Rect2(P.call(0.4, 0.08), Vector2(0.2, 0.6) * s), c)
			ci.draw_circle(P.call(0.5, 0.08), s * 0.1, c)
			ci.draw_circle(P.call(0.5, 0.76), s * 0.18, c)
			ci.draw_rect(Rect2(P.call(0.46, 0.3), Vector2(0.08, 0.4) * s), dark)
			ci.draw_circle(P.call(0.5, 0.76), s * 0.1, dark)
		"sun":
			var cc: Vector2 = P.call(0.5, 0.5)
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(cc + Vector2(cos(a), sin(a)) * s * 0.3, cc + Vector2(cos(a), sin(a)) * s * 0.46, c, maxf(1.5, s * 0.07))
			ci.draw_circle(cc, s * 0.24, c)
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.06), P.call(0.88, 0.2), P.call(0.82, 0.58), P.call(0.5, 0.94), P.call(0.18, 0.58), P.call(0.12, 0.2)]), c)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.18), P.call(0.76, 0.28), P.call(0.72, 0.56), P.call(0.5, 0.8)]), dark)
		"warning":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.06), P.call(0.95, 0.9), P.call(0.05, 0.9)]), c)
			ci.draw_rect(Rect2(P.call(0.45, 0.34), Vector2(0.1, 0.3) * s), dark)
			ci.draw_rect(Rect2(P.call(0.45, 0.7), Vector2(0.1, 0.1) * s), dark)
		"map":
			ci.draw_circle(P.call(0.5, 0.36), s * 0.28, c)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.26, 0.48), P.call(0.74, 0.48), P.call(0.5, 0.94)]), c)
			ci.draw_circle(P.call(0.5, 0.36), s * 0.11, dark)
		"wrench":
			ci.draw_line(P.call(0.24, 0.8), P.call(0.66, 0.38), c, maxf(2.0, s * 0.14))
			ci.draw_circle(P.call(0.7, 0.3), s * 0.2, c)
			ci.draw_rect(Rect2(P.call(0.66, 0.08), Vector2(0.1, 0.22) * s), Color(0, 0, 0, 0))
			ci.draw_circle(P.call(0.76, 0.24), s * 0.09, dark)
		"hammer":
			ci.draw_line(P.call(0.22, 0.86), P.call(0.6, 0.38), c, maxf(2.0, s * 0.12))
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.4, 0.3), P.call(0.66, 0.08), P.call(0.9, 0.34), P.call(0.66, 0.5)]), c)
		"check":
			ci.draw_polyline(PackedVector2Array([P.call(0.16, 0.52), P.call(0.4, 0.76), P.call(0.86, 0.26)]), c, maxf(2.0, s * 0.13))
		"lock":
			ci.draw_arc(P.call(0.5, 0.42), s * 0.2, PI, TAU, 16, c, maxf(2.0, s * 0.09))
			ci.draw_rect(Rect2(P.call(0.22, 0.42), Vector2(0.56, 0.46) * s), c)
			ci.draw_circle(P.call(0.5, 0.62), s * 0.07, dark)
		"up":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.08), P.call(0.9, 0.5), P.call(0.66, 0.5), P.call(0.66, 0.92), P.call(0.34, 0.92), P.call(0.34, 0.5), P.call(0.1, 0.5)]), c)
		"plus":
			ci.draw_rect(Rect2(P.call(0.42, 0.12), Vector2(0.16, 0.76) * s), c)
			ci.draw_rect(Rect2(P.call(0.12, 0.42), Vector2(0.76, 0.16) * s), c)
		"minus":
			ci.draw_rect(Rect2(P.call(0.12, 0.42), Vector2(0.76, 0.16) * s), c)
		"close":
			ci.draw_line(P.call(0.2, 0.2), P.call(0.8, 0.8), c, maxf(2.0, s * 0.12))
			ci.draw_line(P.call(0.8, 0.2), P.call(0.2, 0.8), c, maxf(2.0, s * 0.12))
		"menu":
			for y in [0.2, 0.46, 0.72]:
				ci.draw_rect(Rect2(P.call(0.1, y), Vector2(0.8, 0.1) * s), c)
		"clock":
			ci.draw_arc(P.call(0.5, 0.5), s * 0.4, 0, TAU, 24, c, maxf(1.5, s * 0.08))
			ci.draw_line(P.call(0.5, 0.5), P.call(0.5, 0.24), c, maxf(1.5, s * 0.08))
			ci.draw_line(P.call(0.5, 0.5), P.call(0.7, 0.58), c, maxf(1.5, s * 0.08))
		"tower":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.36, 0.95), P.call(0.42, 0.18), P.call(0.58, 0.18), P.call(0.64, 0.95)]), c)
			ci.draw_rect(Rect2(P.call(0.3, 0.3), Vector2(0.4, 0.07) * s), c)
			ci.draw_rect(Rect2(P.call(0.48, 0.04), Vector2(0.04, 0.16) * s), c)
			ci.draw_rect(Rect2(P.call(0.2, 0.86), Vector2(0.6, 0.09) * s), c)
			ci.draw_circle(P.call(0.5, 0.45), s * 0.06, Color("3fd8c2"))
		"bed":
			ci.draw_rect(Rect2(P.call(0.06, 0.5), Vector2(0.88, 0.18) * s), c)
			ci.draw_rect(Rect2(P.call(0.06, 0.28), Vector2(0.08, 0.6) * s), c)
			ci.draw_rect(Rect2(P.call(0.86, 0.5), Vector2(0.08, 0.38) * s), c)
			ci.draw_rect(Rect2(P.call(0.18, 0.38), Vector2(0.2, 0.12) * s), c)
		"music":
			ci.draw_line(P.call(0.38, 0.76), P.call(0.38, 0.16), c, maxf(1.5, s * 0.08))
			ci.draw_line(P.call(0.38, 0.16), P.call(0.8, 0.08), c, maxf(1.5, s * 0.1))
			ci.draw_line(P.call(0.8, 0.08), P.call(0.8, 0.66), c, maxf(1.5, s * 0.08))
			ci.draw_circle(P.call(0.28, 0.78), s * 0.13, c)
			ci.draw_circle(P.call(0.7, 0.68), s * 0.13, c)
		"sound":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.1, 0.38), P.call(0.3, 0.38), P.call(0.54, 0.16), P.call(0.54, 0.84), P.call(0.3, 0.62), P.call(0.1, 0.62)]), c)
			ci.draw_arc(P.call(0.54, 0.5), s * 0.2, -0.9, 0.9, 12, c, maxf(1.5, s * 0.06))
			ci.draw_arc(P.call(0.54, 0.5), s * 0.34, -0.9, 0.9, 12, c, maxf(1.5, s * 0.06))
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + TAU * i / 10.0
				pts.append(P.call(0.5, 0.54) + Vector2(cos(a), sin(a)) * s * (0.46 if i % 2 == 0 else 0.2))
			ci.draw_colored_polygon(pts, c)
		_:
			ci.draw_circle(P.call(0.5, 0.5), s * 0.3, c)


static func _ellipse_top(bottom_center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(bottom_center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

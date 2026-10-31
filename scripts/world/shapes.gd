class_name Shapes
extends RefCounted
## Small geometry helpers for the procedural placeholder props.

const OUT := Color(0.12, 0.08, 0.07)
const LINE := 0.9


static func capsule(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color, outline := true) -> void:
	if outline:
		ci.draw_line(a, b, OUT, w + LINE * 2.0)
		ci.draw_circle(a, w * 0.5 + LINE, OUT)
		ci.draw_circle(b, w * 0.5 + LINE, OUT)
	ci.draw_line(a, b, col, w)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)


static func rounded(rect: Rect2, r: float, top_w_scale := 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cx := rect.get_center().x
	var corners := [
		[Vector2(rect.end.x, rect.end.y) - Vector2(r, r), 0.0],
		[Vector2(rect.position.x, rect.end.y) + Vector2(r, -r), PI * 0.5],
		[Vector2(rect.position.x, rect.position.y) + Vector2(r, r), PI],
		[Vector2(rect.end.x, rect.position.y) + Vector2(-r, r), PI * 1.5],
	]
	for i in 4:
		var c: Vector2 = corners[i][0]
		if i >= 2:
			c.x = cx + (c.x - cx) * top_w_scale
		for k in 5:
			var a: float = corners[i][1] + PI * 0.5 * k / 4.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(closed, OUT, LINE * 1.6)

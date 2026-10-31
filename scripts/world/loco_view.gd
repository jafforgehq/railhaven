class_name LocoView
extends CarriageView
## Modern armored diesel-electric at the head of the train (facing left, the direction of
## travel). Body, trucks and wheels are Blender renders; light, console glow and exhaust are FX.

const LW := 206.0


func _draw() -> void:
	var spin := -t * 7.0
	# Headlight beam ahead of the train.
	draw_polygon(PackedVector2Array([Vector2(-20, -58), Vector2(-20, -50), Vector2(-200, -20), Vector2(-200, -96)]),
		PackedColorArray([Color(1, 0.92, 0.7, 0.3), Color(1, 0.92, 0.7, 0.3), Color(1, 0.92, 0.7, 0), Color(1, 0.92, 0.7, 0)]))
	draw_texture_rect(art("locomotive"), Rect2(-36, -164, 246, 164), false)
	glow(Vector2(-20, -54), 12, Color(1, 0.9, 0.6), 0.45)
	glow(Vector2(36, -90), 16, Color(0.3, 0.9, 0.8), 0.25 + 0.05 * sin(t * 3.0))
	glow(Vector2(35, -138), 14, Color(1, 0.85, 0.55), 0.18)
	CrewSprites.draw(self, Vector2(54, -80), "pilot_b", "panel", t, -1)
	# Trucks: three wheels each, side frames drawn in front.
	for tx in [40.0, 160.0]:
		for k in [-17.0, 0.0, 17.0]:
			part("wheel", Vector2(tx + k, -8), Vector2(18.7, 18.7), spin * 1.1)
		draw_texture_rect(art("truck3"), Rect2(tx - 30, -24, 60, 24), false)
	if flash > 0.0:
		draw_rect(Rect2(-36, -150, LW + 36, 150), Color(1, 1, 1, flash * 0.6))
	if selected:
		var a := 0.6 + 0.4 * sin(t * 5.0)
		var r := Shapes.rounded(Rect2(-40, -156, LW + 44, 144), 6.0)
		r.append(r[0])
		draw_polyline(r, Color(0.25, 0.95, 0.85, a), 1.6)

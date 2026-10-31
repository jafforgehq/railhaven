class_name LocoView
extends CarriageView
## Armored locomotive at the head of the train (facing left, the direction of travel).
## Body, wheels and coupling rod are Blender renders; beam, fire glow and steam are FX.

const LW := 200.0


func _draw() -> void:
	var spin := t * 7.0
	var fire := 0.7 + 0.3 * sin(t * 13.0) * sin(t * 7.0)
	draw_polygon(PackedVector2Array([Vector2(10, -110), Vector2(10, -102), Vector2(-170, -64), Vector2(-170, -140)]),
		PackedColorArray([Color(1, 0.9, 0.6, 0.3), Color(1, 0.9, 0.6, 0.3), Color(1, 0.9, 0.6, 0), Color(1, 0.9, 0.6, 0)]))
	draw_texture_rect(art("locomotive"), Rect2(-26, -164, 232, 164), false)
	glow(Vector2(5, -106), 12, Color(1, 0.85, 0.5), 0.4)
	glow(Vector2(157, -75), 26, Color(1, 0.5, 0.2), 0.32 * fire)
	CrewSprites.draw(self, Vector2(180, -66), "pilot_b", "panel", t, -1)
	# Steam from the cylinder.
	var puff := fmod(t * 1.4, 1.0)
	for k in 3:
		draw_circle(Vector2(22 - puff * 14 - k * 4, -16 - k * 2 - puff * 4), 2.0 + puff * 3 + k, Color(1, 1, 1, 0.22 * (1.0 - puff)))
	# Wheels and coupling rod (crank pin 7 units off-centre).
	part("wheel", Vector2(30, -7), Vector2(17, 17), -spin * 1.8)
	for wx in [60.0, 90.0, 120.0]:
		part("wheel_big", Vector2(wx, -13), Vector2(29, 29), -spin)
	part("wheel", Vector2(176, -8), Vector2(19.4, 19.4), -spin * 1.6)
	var off := Vector2(cos(-spin), sin(-spin)) * 7.0
	part("rod", Vector2(90, -13) + off, Vector2(66, 6))
	Shapes.capsule(self, Vector2(46, -19), Vector2(60, -13) + off, 1.6, Color("8a8f96"))
	if flash > 0.0:
		draw_rect(Rect2(-6, -146, LW + 6, 146), Color(1, 1, 1, flash * 0.6))
	if selected:
		var a := 0.6 + 0.4 * sin(t * 5.0)
		var r := Shapes.rounded(Rect2(-8, -152, LW + 12, 140), 6.0)
		r.append(r[0])
		draw_polyline(r, Color(0.25, 0.95, 0.85, a), 1.6)

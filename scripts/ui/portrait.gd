class_name Portrait
extends Control
## Crew portrait rendered in Blender (art/blender/crew.py), on a role-tinted card.

var look := {}
var role := "Engineer"


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
	var base: Color = CarriageView.SHIRT.get(role, Color("8a8f96"))
	var top := base.darkened(0.5)
	var bottom := base.darkened(0.78)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	draw_texture_rect(CarriageView.glow_texture(), Rect2(size * Vector2(0.1, -0.1), size * 0.9), false, Color(1, 0.9, 0.7, 0.18))
	draw_texture_rect(CrewSprites.tex(CrewSprites.preset_for(role, look) + "_portrait"), Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.1), false, 2.0)

class_name Coach
extends Control
## Tutorial pointer: a bouncing arrow (Blender art) plus a short hint bubble that
## shows the player exactly what to tap for the current goal. Never blocks input.
## Off-screen targets get a sideways arrow at the screen edge ("drag to find it").

var target := Vector2.ZERO
var hint := ""
var active := false
var dir := "down" # where the arrow points: down, up, left, right, none
var _t := 0.0
var _bubble: PanelContainer
var _label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_label = UIKit.label("", "")
	_label.add_theme_font_size_override("font_size", 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = 230
	_bubble = UIKit.panel("CardGold", UIKit.hbox(8, [Icon.make("bulb", 30), _label]))
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.custom_minimum_size.x = 290
	add_child(_bubble)


## Point at `pos` (screen coordinates) with `text`; empty text hides the coach.
func point(pos: Vector2, text: String, show_arrow := true) -> void:
	active = text != ""
	visible = active
	if not active:
		return
	var w := get_viewport_rect().size.x
	target = pos
	dir = "down" if show_arrow else "none"
	if show_arrow and pos.x > w - 30.0:
		target = Vector2(w - 50.0, pos.y)
		dir = "right"
	elif show_arrow and pos.x < 30.0:
		target = Vector2(50.0, pos.y)
		dir = "left"
	elif show_arrow and pos.y - 160.0 < 190.0:
		dir = "up"
	if dir == "right" or dir == "left":
		text = "Drag the train to find it. " + text
	hint = text
	_label.text = text


func _process(delta: float) -> void:
	_t += delta
	if not active:
		return
	var vp := get_viewport_rect().size
	_bubble.size = _bubble.get_combined_minimum_size()
	var b := _bubble.size
	var bob := sin(_t * 6.0) * 8.0
	var p := Vector2.ZERO
	match dir:
		"down":
			# Beside the arrow when there is room (keeps sheet titles readable), else above it.
			if target.x + 44.0 + b.x < vp.x - 8.0:
				p = Vector2(target.x + 44.0, target.y - 70.0 - b.y * 0.5)
			elif target.x - 44.0 - b.x > 8.0:
				p = Vector2(target.x - 44.0 - b.x, target.y - 70.0 - b.y * 0.5)
			else:
				p = Vector2(target.x - b.x * 0.5, target.y - 90.0 - b.y)
		"up":
			p = Vector2(target.x - b.x * 0.5, target.y + 90.0)
		"right":
			p = Vector2(target.x - 60.0 - b.x, target.y - b.y * 0.5)
		"left":
			p = Vector2(target.x + 60.0, target.y - b.y * 0.5)
		_:
			p = Vector2(target.x - b.x * 0.5, target.y)
	p.x = clampf(p.x, 8.0, vp.x - b.x - 8.0)
	p.y = clampf(p.y + (bob * 0.3 if dir == "down" else 0.0), 90.0, vp.y - b.y - 8.0)
	_bubble.position = p
	queue_redraw()


func _draw() -> void:
	if not active or dir == "none":
		return
	var tex: Texture2D = Icon._art.get("arrow")
	if tex == null:
		return
	var bob := sin(_t * 6.0) * 8.0
	var s := 64.0
	# The arrow art points down; rotate it for the other directions, tip touching the target.
	var rot: float = {"down": 0.0, "up": PI, "right": -PI * 0.5, "left": PI * 0.5}[dir]
	var back: Vector2 = {"down": Vector2(0, -1), "up": Vector2(0, 1), "right": Vector2(-1, 0), "left": Vector2(1, 0)}[dir]
	var centre: Vector2 = target + back * (s * 0.5 + 6.0 - bob)
	draw_set_transform(centre, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

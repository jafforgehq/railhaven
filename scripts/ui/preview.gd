class_name Preview
extends RefCounted
## Small live render of a carriage (fake crew) for build / upgrade cards.


static func make(type: String, level: int, scale := 1.0) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = 1
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(240, 156) * scale
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.gui_disable_input = true
	box.add_child(vp)
	var root := Node2D.new()
	root.scale = Vector2(scale, scale)
	vp.add_child(root)
	var v: CarriageView = LocoView.new() if type == "locomotive" else CarriageView.new()
	v.type = type
	v.level = level
	v.uid = 0
	v.position = Vector2(4, 154)
	root.add_child(v)
	return box

class_name UIKit
extends RefCounted
## Shared palette, Theme and small widget builders. Styling lives in one Theme
## (type variations) so panels only pick a variation name.

const BG := Color("101318")
const PANEL := Color("181c22")
const PANEL2 := Color("20252d")
const BORDER := Color("394049")
const BRASS := Color("b08a45")
const TEXT := Color("f1e6cf")
const MUTED := Color("97a1a8")
const TEAL := Color("3fd8c2")
const ORANGE := Color("ff9a3d")
const RED := Color("ff5a4a")
const GREEN := Color("8be06a")
const GOLD := Color("e9b04a")

static var font_bold: Font = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
static var font_semi: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")


static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 10, bw := 2, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


static func build_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font_semi
	th.default_font_size = 24
	th.set_color("font_color", "Label", TEXT)

	# Buttons.
	_button(th, "Button", PANEL2, BORDER, TEXT)
	_button(th, "TealButton", Color("2bbfa9"), Color("7ff0e0"), Color("0d2422"))
	_button(th, "GoldButton", Color("d79a33"), Color("ffd27a"), Color("2a1a08"))
	_button(th, "GreenButton", Color("4d8a36"), Color("8fd06a"), Color("f1f8e8"))
	_button(th, "RedButton", Color("a8402f"), Color("ff8a6a"), TEXT)
	_button(th, "FlatButton", Color(0, 0, 0, 0), Color(0, 0, 0, 0), TEXT)
	_button(th, "TabButton", Color("1a1e24"), Color("2c323a"), MUTED)
	th.set_stylebox("pressed", "TabButton", box(Color("2a2418"), GOLD, 10, 2, 8))
	th.set_stylebox("hover_pressed", "TabButton", box(Color("2a2418"), GOLD, 10, 2, 8))
	th.set_color("font_pressed_color", "TabButton", GOLD)
	th.set_color("font_hover_pressed_color", "TabButton", GOLD)
	for v in ["TealButton", "GoldButton", "GreenButton", "RedButton"]:
		th.set_font(&"font", v, font_bold)
		th.set_font_size(&"font_size", v, 26)

	# Panels.
	th.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 14, 2, 14))
	for pair in [["Card", box(PANEL2, BORDER, 10, 1, 10)], ["CardTeal", box(Color("10302d"), TEAL, 10, 2, 10)],
			["CardGold", box(Color("2a2418"), GOLD, 10, 2, 10)], ["Chip", box(Color(0.07, 0.08, 0.1, 0.82), Color(1, 1, 1, 0.08), 8, 1, 6)],
			["Overlay", box(Color(0.06, 0.07, 0.09, 0.86), Color(1, 1, 1, 0.1), 10, 1, 10)],
			["Warn", box(Color(0.32, 0.07, 0.05, 0.92), RED, 10, 2, 10)],
			["Bar", box(Color("0c0e11"), Color("2c323a"), 0, 1, 0)], ["Modal", box(Color("15181d"), BRASS, 16, 3, 22)]]:
		th.set_type_variation(pair[0], "PanelContainer")
		th.set_stylebox("panel", pair[0], pair[1])

	# Labels.
	for v in [["Title", font_bold, 40, TEXT], ["Header", font_bold, 30, TEXT], ["Sub", font_semi, 20, MUTED],
			["Small", font_semi, 18, MUTED], ["Value", font_bold, 26, TEXT], ["Accent", font_bold, 24, TEAL]]:
		th.set_type_variation(v[0], "Label")
		th.set_font(&"font", v[0], v[1])
		th.set_font_size(&"font_size", v[0], v[2])
		th.set_color(&"font_color", v[0], v[3])

	# Progress bars.
	th.set_stylebox("background", "ProgressBar", box(Color("0c0e11"), Color("2c323a"), 6, 1, 0))
	th.set_stylebox("fill", "ProgressBar", box(GOLD, Color(0, 0, 0, 0), 6, 0, 0))
	th.set_font_size("font_size", "ProgressBar", 1)
	th.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))

	# Scrollbars: thin.
	var grab := box(Color(1, 1, 1, 0.18), Color(0, 0, 0, 0), 4, 0, 0)
	th.set_stylebox("grabber", "VScrollBar", grab)
	th.set_stylebox("grabber_highlight", "VScrollBar", grab)
	th.set_stylebox("grabber_pressed", "VScrollBar", grab)
	th.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 3))
	th.set_stylebox("grabber", "HScrollBar", grab)
	th.set_stylebox("scroll", "HScrollBar", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 3))
	return th


static func _button(th: Theme, v: String, bg: Color, border: Color, fg: Color) -> void:
	if v != "Button":
		th.set_type_variation(v, "Button")
	th.set_stylebox("normal", v, box(bg, border, 10, 2, 10))
	th.set_stylebox("hover", v, box(bg.lightened(0.08), border, 10, 2, 10))
	th.set_stylebox("pressed", v, box(bg.darkened(0.15), border, 10, 2, 10))
	th.set_stylebox("disabled", v, box(Color("2a2d33"), Color("3a3d44"), 10, 2, 10))
	th.set_stylebox("focus", v, StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(st, v, fg)
	th.set_color("font_disabled_color", v, Color("6f767e"))


# ---------------------------------------------------------------- widget builders

static func label(text: String, variation := "", align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap_label(text: String, variation := "Sub") -> Label:
	var l := label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 60
	return l


static func button(text: String, variation := "", icon := "", min_h := 64.0) -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	if icon == "":
		b.text = text
	else:
		var fg := _btn_fg(variation)
		var l := label(text, "Value" if variation.ends_with("Button") and variation != "FlatButton" else "")
		l.add_theme_color_override("font_color", fg)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var row := hbox(8, [Icon.make(icon, 26, fg), l])
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var fit := func(): b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, row.get_combined_minimum_size().x + 28.0)
		row.minimum_size_changed.connect(fit)
		row.ready.connect(fit)
		b.draw.connect(func(): row.modulate = Color(1, 1, 1, 0.35) if b.disabled else Color.WHITE)
		b.set_meta("label", l)
	b.pressed.connect(func(): Audio.play("ui_click"))
	b.mouse_filter = Control.MOUSE_FILTER_PASS # lets touch drags bubble to ScrollContainers
	return b


static func _btn_fg(v: String) -> Color:
	match v:
		"TealButton": return Color("0d2422")
		"GoldButton": return Color("2a1a08")
		"GreenButton": return Color("f1f8e8")
	return TEXT


static func hbox(sep := 8, children: Array = []) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in children:
		h.add_child(c)
	return h


static func vbox(sep := 8, children: Array = []) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in children:
		v.add_child(c)
	return v


static func panel(variation := "", child: Control = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	if child:
		p.add_child(child)
	return p


static func spacer(h := true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func bar(value: float, color: Color, h := 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 1.0
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(40, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("fill", box(color, Color(0, 0, 0, 0), 6, 0, 0))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Row of resource costs, red when unaffordable.
static func cost_row(cost: Dictionary, size := 24) -> HBoxContainer:
	var row := hbox(14)
	for k in cost:
		var have: float = Game.scrap if k == "scrap" else (Game.parts if k == "parts" else 0.0)
		var l := label(str(int(cost[k])), "Value")
		l.add_theme_font_size_override("font_size", size)
		if have < cost[k]:
			l.add_theme_color_override("font_color", RED)
		row.add_child(hbox(4, [Icon.make(k, size), l]))
	return row


static func fmt(v: float) -> String:
	if absf(v) >= 10000.0:
		return "%.1fK" % (v / 1000.0)
	return str(int(floor(v + 0.0001)))


static func fmt_rate(v: float) -> String:
	if absf(v) < 0.05:
		return "±0/m"
	return ("+" if v > 0 else "") + ("%.1f" % v if absf(v) < 10.0 else "%d" % int(round(v))) + "/m"


static func fmt_time(sec: float) -> String:
	var s := int(maxf(0.0, sec))
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

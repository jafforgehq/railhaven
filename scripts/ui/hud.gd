class_name HUD
extends Control
## Top resource bar plus floating cards over the world: chapter goal, temperatures
## and event / safe-mode status.

var main: Node
var _chips := {}
var _crew_label: Label
var _top: PanelContainer
var _goal_card: PanelContainer
var _goal_text: Label
var _goal_prog: Label
var _goal_bar: ProgressBar
var _out_temp: Label
var _region: Label
var _cabin: Label
var _status: PanelContainer
var _status_label: Label
var _status_icon: Icon
var _safe_top := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_top = _safe_area_top()
	_build_top()
	_build_cards()
	refresh()


func _safe_area_top() -> int:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0 or OS.has_feature("pc"):
		return 0
	return int(maxf(0.0, safe.position.y * get_viewport_rect().size.y / float(win.y)))


func band_top() -> float:
	return 84.0 + _safe_top + 96.0


func _build_top() -> void:
	_top = UIKit.panel("Bar")
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_top)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 8 + _safe_top)
	m.add_theme_constant_override("margin_bottom", 8)
	_top.add_child(m)
	var row := UIKit.hbox(6)
	m.add_child(row)
	var logo := UIKit.vbox(-12, [UIKit.label("RAIL", "Header"), UIKit.label("HAVEN", "Header")])
	for l in logo.get_children():
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", UIKit.GOLD)
	logo.custom_minimum_size.x = 58
	row.add_child(logo)
	for k in Data.RES:
		var val := UIKit.label("0", "Value")
		val.add_theme_font_size_override("font_size", 22)
		var rate := UIKit.label("", "Small")
		rate.add_theme_font_size_override("font_size", 15)
		var chip := UIKit.panel("Chip", UIKit.hbox(4, [Icon.make(k, 24), UIKit.vbox(-6, [val, rate])]))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 58)
		row.add_child(chip)
		_chips[k] = [val, rate, chip]
	_crew_label = UIKit.label("0/0", "Value")
	_crew_label.add_theme_font_size_override("font_size", 22)
	var crew_chip := UIKit.panel("Chip", UIKit.hbox(4, [Icon.make("crew", 24), _crew_label]))
	crew_chip.custom_minimum_size = Vector2(86, 58)
	row.add_child(crew_chip)
	var menu := UIKit.button("", "FlatButton", "", 58)
	menu.custom_minimum_size = Vector2(50, 58)
	var mi := Icon.make("menu", 30, UIKit.TEXT)
	mi.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.add_child(mi)
	menu.pressed.connect(func(): Popups.settings(main))
	row.add_child(menu)


func _build_cards() -> void:
	var y := 84 + _safe_top
	# Goal card (tap for the chapter checklist).
	_goal_card = UIKit.panel("Overlay")
	_goal_card.position = Vector2(12, y)
	_goal_card.custom_minimum_size = Vector2(430, 0)
	_goal_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_goal_card)
	_goal_text = UIKit.label("", "")
	_goal_text.add_theme_font_size_override("font_size", 23)
	_goal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_text.custom_minimum_size.x = 300
	_goal_prog = UIKit.label("", "Small")
	_goal_bar = UIKit.bar(0.0, UIKit.GOLD, 6)
	var tag := UIKit.label("CHAPTER 1 GOAL", "Small")
	tag.add_theme_color_override("font_color", UIKit.GOLD)
	var gbox := UIKit.vbox(2, [UIKit.hbox(6, [tag, UIKit.spacer(), _goal_prog]), _goal_text, _goal_bar])
	gbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_card.add_child(UIKit.hbox(10, [Icon.make("star", 36, UIKit.GOLD), gbox, UIKit.label("›", "Header")]))
	_goal_card.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.play("ui_click")
			main.goto_goal())

	# Temperatures.
	var right := UIKit.vbox(6)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(get_viewport_rect().size.x - 170, y)
	right.custom_minimum_size.x = 158
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(right)
	_out_temp = UIKit.label("65°C", "Header")
	_out_temp.add_theme_color_override("font_color", UIKit.ORANGE)
	_region = UIKit.label("", "Small")
	var out_card := UIKit.panel("Overlay", UIKit.hbox(6, [Icon.make("sun", 30, UIKit.ORANGE), UIKit.vbox(-6, [UIKit.label("Outside", "Small"), _out_temp, _region])]))
	_cabin = UIKit.label("24°C", "Header")
	_cabin.add_theme_color_override("font_color", UIKit.TEAL)
	var cab_card := UIKit.panel("Overlay", UIKit.hbox(6, [Icon.make("temp", 30, UIKit.TEAL), UIKit.vbox(-6, [UIKit.label("Cabin", "Small"), _cabin])]))
	right.add_child(out_card)
	right.add_child(cab_card)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	right.offset_top = y

	# Status banner (events, safe mode).
	_status = UIKit.panel("Warn")
	_status.position = Vector2(12, y + 118)
	_status.mouse_filter = Control.MOUSE_FILTER_STOP
	_status_icon = Icon.make("warning", 26, UIKit.ORANGE)
	_status_label = UIKit.label("", "")
	_status_label.add_theme_font_size_override("font_size", 21)
	_status.add_child(UIKit.hbox(8, [_status_icon, _status_label]))
	_status.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and not Game.event.is_empty() and Game.event["choice"] == "":
			Popups.event(main))
	add_child(_status)


func refresh() -> void:
	var r := Game.rates()
	for k in Data.RES:
		var chip: Array = _chips[k]
		var v: float = Game.res[k]
		chip[0].text = UIKit.fmt(v)
		var full: bool = v >= Game.storage(k) - 0.5
		chip[0].add_theme_color_override("font_color", UIKit.GOLD if full else UIKit.TEXT)
		chip[1].text = "FULL" if full and r[k] > 0 else UIKit.fmt_rate(r[k])
		chip[1].add_theme_color_override("font_color", UIKit.GREEN if r[k] > 0.05 else (UIKit.RED if r[k] < -0.05 else UIKit.MUTED))
	_crew_label.text = "%d/%d" % [Game.survivors.size(), Game.capacity()]

	var g := Game.current_goal()
	if g.is_empty():
		_goal_text.text = "Climate Tower restored — Ash Coast unlocked!" if Game.chapter_done else "Chapter complete"
		_goal_prog.text = ""
		_goal_bar.value = 1.0
	else:
		_goal_text.text = g["text"]
		var p := Game.goal_progress(g)
		_goal_prog.text = "%d / %d" % [mini(p[0], p[1]), p[1]]
		_goal_bar.value = clampf(float(p[0]) / maxf(1.0, p[1]), 0.0, 1.0)

	var ot := Game.outside_temp()
	_out_temp.text = "%d°C" % ot
	_out_temp.add_theme_color_override("font_color", UIKit.RED if ot > 70 else UIKit.ORANGE)
	_region.text = Game.region_name()
	_cabin.text = "%d°C" % Game.cabin_temp()

	var ev := Game.event
	var msg := ""
	if not ev.is_empty():
		var d: Dictionary = Data.EVENTS[ev["id"]]
		if ev["choice"] == "":
			msg = "%s — decide in %ds (tap)" % [d["title"], int(ceil(ev["decide_left"]))]
		else:
			msg = "%s · %s · %s" % [d["title"], d[ev["choice"]]["effect"], UIKit.fmt_time(ev["time_left"])]
	if Game.rationing:
		msg = ("SAFE MODE: rationing — production -30%, growth paused" if msg == "" else msg + "\nSAFE MODE: rationing")
	_status.visible = msg != ""
	_status_label.text = msg


func pulse_goal() -> void:
	_goal_card.pivot_offset = _goal_card.size * 0.5
	var tw := create_tween()
	tw.tween_property(_goal_card, "scale", Vector2(1.06, 1.06), 0.12)
	tw.tween_property(_goal_card, "scale", Vector2.ONE, 0.2)

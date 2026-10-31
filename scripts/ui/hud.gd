class_name HUD
extends Control
## Top resource bar and floating cards over the world: the next step (with GO),
## outside temperature and event / safe-mode status. Tapping a resource explains it.

const TIPS := {
	"scrap": "Scrap: drones bring it in automatically. You build with it, and the Workshop turns it into parts.",
	"parts": "Parts: made in the Workshop from scrap. Needed for building and upgrading carriages.",
	"food": "Food: grown in the Greenhouse. Every survivor eats a little each minute.",
	"water": "Water: cleaned in the Water Recycler. Every survivor drinks a little each minute.",
	"crew": "Survivors aboard / beds. Upgrade the Living Quarters to make room for more.",
	"temp": "Outside heat. Heatwaves push it higher. Your Cooling Modules keep the cabins safe.",
}

var main: Node
var go_button: Button
var _chips := {}
var _crew_label: Label
var _top: PanelContainer
var _goal_card: PanelContainer
var _goal_text: Label
var _goal_prog: Label
var _goal_bar: ProgressBar
var _out_temp: Label
var _status: PanelContainer
var _status_label: Label
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


func _tap(control: Control, tip: String) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.play("ui_click")
			main.show_toast(tip, "info"))


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
	for k in Data.RES:
		var val := UIKit.label("0", "Value")
		val.add_theme_font_size_override("font_size", 26)
		var note := UIKit.label("", "Small")
		note.add_theme_font_size_override("font_size", 15)
		var chip := UIKit.panel("Chip", UIKit.hbox(6, [Icon.make(k, 32), UIKit.vbox(-6, [val, note])]))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 60)
		row.add_child(chip)
		_tap(chip, TIPS[k])
		_chips[k] = [val, note]
	_crew_label = UIKit.label("0/0", "Value")
	_crew_label.add_theme_font_size_override("font_size", 26)
	var crew_chip := UIKit.panel("Chip", UIKit.hbox(6, [Icon.make("crew", 32), _crew_label]))
	crew_chip.custom_minimum_size = Vector2(104, 60)
	row.add_child(crew_chip)
	_tap(crew_chip, TIPS["crew"])
	var menu := UIKit.button("", "FlatButton", "", 60)
	menu.custom_minimum_size = Vector2(52, 60)
	var mi := Icon.make("menu", 30, UIKit.TEXT)
	mi.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.add_child(mi)
	menu.pressed.connect(func(): Popups.settings(main))
	row.add_child(menu)


func _build_cards() -> void:
	var y := 86 + _safe_top
	# Next step: what to do now, with a GO button that takes you there.
	_goal_card = UIKit.panel("Overlay")
	_goal_card.position = Vector2(12, y)
	_goal_card.custom_minimum_size = Vector2(520, 0)
	_goal_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_goal_card)
	_goal_text = UIKit.label("", "")
	_goal_text.add_theme_font_size_override("font_size", 24)
	_goal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_text.custom_minimum_size.x = 300
	_goal_prog = UIKit.label("", "Small")
	_goal_bar = UIKit.bar(0.0, UIKit.GOLD, 6)
	var tag := UIKit.label("NEXT STEP", "Small")
	tag.add_theme_color_override("font_color", UIKit.GOLD)
	var gbox := UIKit.vbox(2, [UIKit.hbox(6, [tag, UIKit.spacer(), _goal_prog]), _goal_text, _goal_bar])
	gbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go_button = UIKit.button("GO", "TealButton", "", 56)
	go_button.custom_minimum_size = Vector2(76, 56)
	go_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_button.pressed.connect(func(): main.goto_goal())
	_goal_card.add_child(UIKit.hbox(10, [Icon.make("star", 36, UIKit.GOLD), gbox, go_button]))

	# Outside temperature (one small chip).
	_out_temp = UIKit.label("65°C", "Header")
	_out_temp.add_theme_font_size_override("font_size", 28)
	var temp := UIKit.panel("Overlay", UIKit.hbox(6, [Icon.make("sun", 30), _out_temp]))
	add_child(temp)
	temp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	temp.offset_top = y
	_tap(temp, TIPS["temp"])

	# Status banner (events, safe mode).
	_status = UIKit.panel("Warn")
	_status.position = Vector2(12, y + 118)
	_status.mouse_filter = Control.MOUSE_FILTER_STOP
	_status_label = UIKit.label("", "")
	_status_label.add_theme_font_size_override("font_size", 21)
	_status.add_child(UIKit.hbox(8, [Icon.make("warning", 26), _status_label]))
	_status.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and not Game.event.is_empty() and Game.event["choice"] == "":
			Popups.event(main))
	add_child(_status)


func refresh() -> void:
	var r := Game.rates()
	for k in Data.RES:
		var chip: Array = _chips[k]
		var v: float = Game.res[k]
		var cap := Game.storage(k)
		chip[0].text = UIKit.fmt(v)
		var note := ""
		var col := UIKit.TEXT
		if v >= cap - 0.5 and r[k] >= 0.0:
			note = "MAX"
			col = UIKit.GOLD
		elif r[k] < -0.05 and v < cap * 0.3:
			note = "LOW"
			col = UIKit.RED
		chip[0].add_theme_color_override("font_color", col)
		chip[1].text = note
		chip[1].add_theme_color_override("font_color", col)
		chip[1].visible = note != ""
	_crew_label.text = "%d/%d" % [Game.survivors.size(), Game.capacity()]

	var g := Game.current_goal()
	if g.is_empty():
		_goal_text.text = "Climate Tower restored! Keep growing your train." if Game.chapter_done else "Chapter complete"
		_goal_prog.text = ""
		_goal_bar.value = 1.0
		go_button.visible = false
	else:
		_goal_text.text = g["text"]
		var p := Game.goal_progress(g)
		_goal_prog.text = "%d / %d" % [mini(p[0], p[1]), p[1]]
		_goal_bar.value = clampf(float(p[0]) / maxf(1.0, p[1]), 0.0, 1.0)
		go_button.visible = true

	var ot := Game.outside_temp()
	_out_temp.text = "%d°C" % ot
	_out_temp.add_theme_color_override("font_color", UIKit.RED if ot > 70 else UIKit.ORANGE)

	var ev := Game.event
	var msg := ""
	if not ev.is_empty():
		var d: Dictionary = Data.EVENTS[ev["id"]]
		if ev["choice"] == "":
			msg = "%s: tap to choose (%ds)" % [d["title"], int(ceil(ev["decide_left"]))]
		else:
			msg = "%s · %s · %s" % [d["title"], d[ev["choice"]]["effect"], UIKit.fmt_time(ev["time_left"])]
	if Game.rationing:
		var ration := "Out of food or water: crew is rationing"
		msg = ration if msg == "" else msg + "\n" + ration
	_status.visible = msg != ""
	_status_label.text = msg


func pulse_goal() -> void:
	_goal_card.pivot_offset = _goal_card.size * 0.5
	var tw := create_tween()
	tw.tween_property(_goal_card, "scale", Vector2(1.06, 1.06), 0.12)
	tw.tween_property(_goal_card, "scale", Vector2.ONE, 0.2)

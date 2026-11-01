class_name HUD
extends Control
## Home top bar: lives (with refill timer), scrap, parts, outside temperature and the menu.
## Tapping a chip explains it.

const TIPS := {
	"heart": "Lives: losing or leaving a level costs one. They refill one every 20 minutes.",
	"scrap": "Scrap: earned from levels, the Condenser and daily drops. Buys boosters and continues.",
	"parts": "Parts: one per level won (two on heatwave levels). Spend them to restore the train.",
	"temp": "Outside heat. Cool the carriages with puzzles and restore the region's landmark.",
}

var main: Node
var _lives: Label
var _lives_t: Label
var _scrap: Label
var _parts: Label
var _temp: Label
var _top: PanelContainer
var _safe_top := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_top = int(main.safe_top())
	_top = UIKit.panel("Bar")
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_top)
	var m := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	m.add_theme_constant_override("margin_top", 8 + _safe_top)
	_top.add_child(m)
	var row := UIKit.hbox(8)
	m.add_child(row)
	_lives = _value()
	_lives_t = UIKit.label("", "Small")
	_lives_t.add_theme_font_size_override("font_size", 15)
	row.add_child(_chip("heart", UIKit.vbox(-6, [_lives, _lives_t]), func():
		if Game.lives < Data.MAX_LIVES:
			Popups.out_of_lives(main)
		else:
			main.show_toast(TIPS["heart"], "info")))
	_scrap = _value()
	row.add_child(_chip("scrap", _scrap, func(): Popups.shop(main)))
	_parts = _value()
	row.add_child(_chip("parts", _parts, func(): main.show_toast(TIPS["parts"], "info")))
	_temp = _value()
	var t := _chip("sun", _temp, func(): main.show_toast(TIPS["temp"], "info"))
	t.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(t)
	var menu := UIKit.button("", "FlatButton", "", 60)
	menu.custom_minimum_size = Vector2(52, 60)
	var mi := Icon.make("menu", 30, UIKit.TEXT)
	mi.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.add_child(mi)
	menu.pressed.connect(func(): Popups.settings(main))
	row.add_child(menu)
	refresh()


func _value() -> Label:
	var l := UIKit.label("0", "Value")
	l.add_theme_font_size_override("font_size", 26)
	return l


func _chip(icon: String, content: Control, on_tap: Callable) -> PanelContainer:
	var chip := UIKit.panel("Chip", UIKit.hbox(6, [Icon.make(icon, 32), content]))
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size = Vector2(0, 60)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.play("ui_click")
			on_tap.call())
	return chip


func band_top() -> float:
	return _top.get_combined_minimum_size().y + 8.0


func refresh() -> void:
	_lives.text = "%d" % Game.lives
	_lives.add_theme_color_override("font_color", UIKit.RED if Game.lives == 0 else UIKit.TEXT)
	_lives_t.text = "FULL" if Game.lives >= Data.MAX_LIVES else UIKit.fmt_time(Game.next_life_in())
	_lives_t.add_theme_color_override("font_color", UIKit.GREEN if Game.lives >= Data.MAX_LIVES else UIKit.MUTED)
	_scrap.text = UIKit.fmt(Game.scrap)
	_parts.text = "%d" % Game.parts
	_temp.text = "%d°C" % Game.outside_temp()
	_temp.add_theme_color_override("font_color", UIKit.ORANGE)

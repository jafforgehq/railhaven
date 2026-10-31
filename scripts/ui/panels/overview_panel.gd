class_name OverviewPanel
extends BasePanel
## Default Train screen sheet: production overview, storage bars, capacity summary.

const COLORS := {"scrap": Color("c9d1da"), "parts": Color("e9b04a"), "food": Color("8be06a"), "water": Color("5bb8ff")}
var _cells := {}
var _status: Label
var _status_icon: Icon
var _summary: Label


func build() -> void:
	var title := UIKit.label("PRODUCTION OVERVIEW", "Header")
	title.add_theme_font_size_override("font_size", 26)
	_status_icon = Icon.make("check", 22, UIKit.GREEN)
	_status = UIKit.label("", "Small")
	add_child(UIKit.hbox(8, [Icon.make("train", 26, UIKit.GOLD), title, UIKit.spacer(), _status_icon, _status]))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	for k in Data.RES:
		var rate := UIKit.label("", "Value")
		var amount := UIKit.label("", "Small")
		var b := UIKit.bar(0.0, COLORS[k], 8)
		var nm := UIKit.label(Data.RES_NAMES[k], "")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card := UIKit.panel("Card", UIKit.vbox(4, [UIKit.hbox(8, [Icon.make(k, 28), nm, rate]), b, amount]))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		_cells[k] = [rate, amount, b]
	_summary = UIKit.label("", "Small")
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_summary)
	var build_btn := UIKit.button("ADD A CARRIAGE", "TealButton", "plus", 58)
	build_btn.pressed.connect(func(): main.open_build())
	add_child(build_btn)


func refresh() -> void:
	var r := Game.rates()
	for k in Data.RES:
		var cell: Array = _cells[k]
		cell[0].text = UIKit.fmt_rate(r[k])
		cell[0].add_theme_color_override("font_color", UIKit.GREEN if r[k] > 0.05 else (UIKit.RED if r[k] < -0.05 else UIKit.MUTED))
		var cap := Game.storage(k)
		cell[1].text = "%s / %s stored" % [UIKit.fmt(Game.res[k]), UIKit.fmt(cap)]
		cell[2].value = clampf(Game.res[k] / cap, 0.0, 1.0)
	if Game.rationing:
		_status.text = "Safe mode: rationing"
		_status_icon.kind = "shield"
		_status_icon.color = UIKit.ORANGE
	elif Game.event.get("choice", "") == "b" and Game.event.get("id", "") == "heatwave":
		_status.text = "Heatwave safe mode"
		_status_icon.kind = "shield"
		_status_icon.color = UIKit.ORANGE
	else:
		_status.text = "Stable production"
		_status_icon.kind = "check"
		_status_icon.color = UIKit.GREEN
	_summary.text = "Cooling %d/%d carriages  ·  Beds %d/%d  ·  Tap a carriage to manage · drag to pan" % [
		Game.cooling_used(), Game.cooling_capacity(), Game.survivors.size(), Game.capacity()]

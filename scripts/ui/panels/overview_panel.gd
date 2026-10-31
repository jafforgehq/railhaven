class_name OverviewPanel
extends BasePanel
## Default Train sheet: one plain-language status line telling the player what matters
## right now, compact resource rows, and the add-carriage button.

const COLORS := {"scrap": Color("c9d1da"), "parts": Color("e9b04a"), "food": Color("8be06a"), "water": Color("5bb8ff")}
var _rows := {}
var _status: Label
var _status_icon: Icon
var _beds: Label
var _slots: Label


func build() -> void:
	var title := UIKit.label("YOUR TRAIN", "Header")
	add_child(UIKit.hbox(10, [Icon.make("train", 34), title, UIKit.spacer(), UIKit.label("Tap a carriage to manage it", "Small")]))
	_status_icon = Icon.make("star", 30)
	_status = UIKit.wrap_label("", "")
	_status.add_theme_font_size_override("font_size", 23)
	add_child(UIKit.panel("Card", UIKit.hbox(10, [_status_icon, _status])))
	for k in Data.RES:
		var nm := UIKit.label(Data.RES_NAMES[k], "")
		nm.custom_minimum_size.x = 76
		var b := UIKit.bar(0.0, COLORS[k], 10)
		var amount := UIKit.label("", "Value")
		amount.custom_minimum_size.x = 104
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var rate := UIKit.label("", "Small")
		rate.custom_minimum_size.x = 76
		rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(UIKit.hbox(10, [Icon.make(k, 30), nm, b, amount, rate]))
		_rows[k] = [b, amount, rate]
	_beds = UIKit.label("", "Small")
	_slots = UIKit.label("", "Small")
	add_child(UIKit.hbox(18, [UIKit.hbox(6, [Icon.make("bed", 24), _beds]), UIKit.hbox(6, [Icon.make("cooling", 24), _slots])]))
	var build_btn := UIKit.button("ADD A CARRIAGE", "TealButton", "hammer", 62)
	build_btn.pressed.connect(func(): main.open_build())
	add_child(build_btn)
	main.register_target("add_carriage", build_btn)


func refresh() -> void:
	var r := Game.rates()
	for k in Data.RES:
		var row: Array = _rows[k]
		var cap := Game.storage(k)
		row[0].value = clampf(Game.res[k] / cap, 0.0, 1.0)
		row[1].text = "%s/%s" % [UIKit.fmt(Game.res[k]), UIKit.fmt(cap)]
		row[2].text = UIKit.fmt_rate(r[k])
		row[2].add_theme_color_override("font_color", UIKit.GREEN if r[k] > 0.05 else (UIKit.RED if r[k] < -0.05 else UIKit.MUTED))
	_beds.text = "Beds %d/%d" % [Game.survivors.size(), Game.capacity()]
	_slots.text = "Train has room for %d more carriage%s" % [maxi(0, Game.cooling_capacity() - Game.cooling_used()), "" if Game.cooling_capacity() - Game.cooling_used() == 1 else "s"]
	var s := status_line()
	_status.text = s[1]
	_status_icon.kind = s[0]
	_status.add_theme_color_override("font_color", s[2])


## The single most important thing for the player right now: [icon, text, colour].
static func status_line() -> Array:
	var r := Game.rates()
	if Game.rationing:
		return ["warning", "Out of food or water! The crew is rationing. Put workers in the Greenhouse or Water Recycler.", UIKit.RED]
	for k in ["food", "water"]:
		if r[k] < -0.05:
			var minutes: float = Game.res[k] / -r[k]
			if minutes < 20.0:
				var where := "Greenhouse" if k == "food" else "Water Recycler"
				var fix := "Put workers in the %s" % where if Game.count_type("greenhouse" if k == "food" else "recycler") > 0 else "Build a %s" % where
				return ["warning", "%s runs out in about %d min. %s." % [Data.RES_NAMES[k], int(minutes), fix], UIKit.ORANGE]
	var idle := Game.idle_survivors().size()
	var open := 0
	for c in Game.carriages:
		open += maxi(0, Game.free_slots(c["uid"]))
	if idle > 0 and open > 0:
		return ["crew", "%d survivor%s resting. Open a carriage and tap + to give them work." % [idle, "" if idle == 1 else "s"], UIKit.GOLD]
	if Game.res["scrap"] >= Game.storage("scrap") - 0.5:
		return ["scrap", "Scrap storage is full. Spend it on building, or upgrade the Drone Bay.", UIKit.GOLD]
	return ["check", "Everything is running. Your crew keeps working even when the game is closed.", UIKit.GREEN]

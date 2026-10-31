class_name CarriagePanel
extends BasePanel
## Management sheet for one carriage: level preview, stats, crew slots, upgrade,
## and for drone bays the auto-salvage loop.

var uid := 0
var _type := ""
var _stats: Array = [] # [labels, stat key]
var _crew_row: HBoxContainer
var _crew_title: Label
var _cost_box: HBoxContainer
var _upgrade: Button
var _reason: Label
var _salvage_bar: ProgressBar
var _salvage_time: Label
var _salvage_reward: Label
var _repeat: CheckButton
var _launch: Button
var _crew_sig := ""


func build() -> void:
	var c := Game.carriage(uid)
	if c.is_empty():
		return
	_type = c["type"]
	var d: Dictionary = Data.CARRIAGES[_type]
	var head := header(d["icon"], "%s   Lv.%d" % [d["name"].to_upper(), c["level"]], d["desc"])
	head.get_child(1).get_child(0).add_theme_color_override("font_color", UIKit.TEXT)

	# Level previews.
	var lv: int = c["level"]
	var prev := UIKit.hbox(8)
	prev.alignment = BoxContainer.ALIGNMENT_CENTER
	prev.add_child(UIKit.vbox(2, [UIKit.label("Level %d" % lv, "Small", HORIZONTAL_ALIGNMENT_CENTER), Preview.make(_type, lv, 0.62)]))
	if lv < Data.MAX_LEVEL:
		var arrow := UIKit.label("→", "Title")
		arrow.add_theme_color_override("font_color", UIKit.TEAL)
		prev.add_child(arrow)
		var nl := UIKit.label("Level %d" % (lv + 1), "Small", HORIZONTAL_ALIGNMENT_CENTER)
		nl.add_theme_color_override("font_color", UIKit.TEAL)
		prev.add_child(UIKit.vbox(2, [nl, Preview.make(_type, lv + 1, 0.62)]))
	add_child(prev)

	if _type == "dronebay":
		_build_salvage()

	_stats.clear()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for s in _stat_defs():
		_stats.append([stat_row(s[0], s[1], "", "", grid), s[2]])

	if Data.slots(_type, 1) > 0:
		_crew_title = UIKit.label("", "Small")
		_crew_row = UIKit.hbox(6)
		var scroll := ScrollContainer.new()
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size.y = 56
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_crew_row)
		add_child(UIKit.hbox(10, [UIKit.vbox(0, [UIKit.label("CREW", "Small"), _crew_title]), scroll]))
		_crew_sig = ""

	_cost_box = UIKit.hbox(8)
	_cost_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reason = UIKit.label("", "Small")
	_upgrade = UIKit.button("UPGRADE", "GoldButton", "up", 62)
	_upgrade.custom_minimum_size.x = 250
	_upgrade.pressed.connect(func():
		if not Game.upgrade(uid):
			Audio.play("error"))
	add_child(HSeparator.new())
	add_child(UIKit.hbox(10, [UIKit.vbox(0, [_cost_box, _reason]), _upgrade]))


func _build_salvage() -> void:
	_salvage_bar = UIKit.bar(0.0, UIKit.GOLD, 16)
	_salvage_time = UIKit.label("", "Value")
	_salvage_time.custom_minimum_size.x = 130
	_salvage_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_salvage_reward = UIKit.label("", "")
	_repeat = CheckButton.new()
	_repeat.text = "Repeat"
	_repeat.focus_mode = Control.FOCUS_NONE
	_repeat.toggled.connect(func(on):
		Audio.play("ui_click")
		Game.set_repeat(uid, on))
	_launch = UIKit.button("LAUNCH", "TealButton", "drone", 50)
	_launch.pressed.connect(func(): Game.launch(uid); Audio.play("drone_launch"))
	var title := UIKit.label("AUTO SALVAGE · RUINED FOUNDRY", "Small")
	title.add_theme_color_override("font_color", UIKit.GOLD)
	var box := UIKit.vbox(6, [title, UIKit.hbox(10, [_salvage_bar, _salvage_time]),
		UIKit.hbox(10, [Icon.make("scrap", 24), _salvage_reward, UIKit.spacer(), _launch, _repeat])])
	add_child(UIKit.panel("Card", box))


func _stat_defs() -> Array:
	match _type:
		"greenhouse", "recycler", "workshop":
			var res: String = Data.CARRIAGES[_type]["res"]
			return [[res, "%s / min" % Data.RES_NAMES[res], "output"], ["crew", "Worker slots", "slots"], ["home", "Storage", "storage"]]
		"quarters":
			return [["bed", "Beds", "beds"]]
		"cooling":
			return [["cooling", "Carriage cap", "cooling"], ["crew", "Staffed bonus", "tech"]]
		"dronebay":
			return [["drone", "Drones", "drones"], ["scrap", "Scrap / run", "run"], ["crew", "Pilot slots", "slots"]]
		"locomotive":
			return [["home", "Cargo hold", "cargo"], ["train", "Speed km/h", "speed"]]
	return []


func _stat_value(key: String, l: int) -> String:
	var c := Game.carriage(uid)
	match key:
		"output":
			var mult := Game.water_mult() if _type == "recycler" else 1.0
			return "%.1f" % (Game.worker_power(c) * Data.worker_rate(_type, l) * Game.efficiency() * mult * 60.0)
		"slots":
			return str(Data.slots(_type, l))
		"storage":
			return "+%d" % int(Data.storage_bonus(_type, l)[Data.CARRIAGES[_type]["res"]])
		"beds":
			return str(Data.beds(l))
		"cooling":
			return "+%d" % Data.cooling_capacity(l, not Game.workers_in(uid).is_empty())
		"tech":
			return "+1"
		"drones":
			return str(Data.drones(l))
		"run":
			return str(int(Data.drones(l) * Data.DRONE_YIELD * (1.0 + 0.25 * Game.worker_power(c))))
		"cargo":
			return "x%.1f" % Data.loco_mult(l)
		"speed":
			return str(int(Data.TRAIN_SPEED * (1.0 + 0.1 * (l - 1)) * 360.0))
	return ""


func refresh() -> void:
	var c := Game.carriage(uid)
	if c.is_empty():
		return
	var lv: int = c["level"]
	for s in _stats:
		var labels: Array = s[0]
		labels[0].text = _stat_value(s[1], lv)
		if lv < Data.MAX_LEVEL:
			labels[1].text = _stat_value(s[1], lv + 1)
			labels[2].text = "→" if labels[1].text != labels[0].text else ""
			if labels[2].text == "":
				labels[1].text = ""

	if _crew_row:
		_refresh_crew(c)

	if _salvage_bar:
		var active: bool = c["active"]
		_salvage_bar.value = c["timer"] / Data.DRONE_RUN_TIME if active else 0.0
		if Game.drones_grounded():
			_salvage_time.text = "Grounded"
		elif active:
			_salvage_time.text = UIKit.fmt_time(Data.DRONE_RUN_TIME - c["timer"])
		else:
			_salvage_time.text = "Idle"
		_salvage_reward.text = "+%d scrap per run" % int(Game.drone_yield(c) * Game.efficiency())
		_repeat.set_pressed_no_signal(c["repeat"])
		_launch.visible = not active

	UIKit.clear(_cost_box)
	if lv >= Data.MAX_LEVEL:
		_cost_box.add_child(UIKit.label("Maximum level reached", "Accent"))
		_upgrade.disabled = true
		_reason.text = ""
	else:
		_cost_box.add_child(UIKit.cost_row(Data.upgrade_cost(_type, lv), 26))
		var why := Game.upgrade_block_reason(uid)
		_upgrade.disabled = why != ""
		_reason.text = why


func _refresh_crew(c: Dictionary) -> void:
	var workers := Game.workers_in(uid)
	var slots := Data.slots(_type, c["level"])
	var sig := "%s|%d|%d" % [str(workers.map(func(s): return s["id"])), slots, Game.idle_survivors().size()]
	_crew_title.text = "%d / %d" % [workers.size(), slots]
	if sig == _crew_sig:
		return
	_crew_sig = sig
	UIKit.clear(_crew_row)
	var want: String = Data.CARRIAGES[_type].get("role", "")
	for s in workers:
		var b := UIKit.button(s["name"] + ("  ★" if s["role"] == want else ""), "", "minus", 52)
		b.tooltip_text = "Unassign"
		var sid: int = s["id"]
		b.pressed.connect(func(): Game.assign(sid, 0))
		_crew_row.add_child(b)
	if workers.size() < slots:
		var idle := Game.idle_survivors()
		var add := UIKit.button("ASSIGN" if not idle.is_empty() else "No resting crew", "GreenButton" if not idle.is_empty() else "", "plus", 52)
		add.disabled = idle.is_empty()
		add.pressed.connect(func():
			var pool := Game.idle_survivors()
			if pool.is_empty():
				return
			var best: Dictionary = pool[0]
			for s in pool:
				if s["role"] == want:
					best = s
					break
			Game.assign(best["id"], uid))
		_crew_row.add_child(add)

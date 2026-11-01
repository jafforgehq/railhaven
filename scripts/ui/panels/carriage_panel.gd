class_name CarriagePanel
extends BasePanel
## One carriage in plain words: what it does, what it makes right now, who works
## there (tap + to add, tap a worker to send them to rest) and one upgrade box.

const PLAIN := {
	"locomotive": "Pulls the whole train. Upgrading it grows the cargo hold (storage) and speed.",
	"quarters": "Beds for survivors. More beds let more survivors join you.",
	"greenhouse": "Workers grow food here. Everyone aboard eats.",
	"recycler": "Workers clean water here. Everyone aboard drinks.",
	"workshop": "Workers turn scrap into parts here. Parts are needed to build and upgrade.",
	"cooling": "Keeps the train cool. Each module lets the train carry more carriages.",
	"dronebay": "Drones fly out on their own and bring back scrap. Pilots make each trip bring more.",
	"cargo": "Extra storage for every resource. Build one when costs no longer fit in your hold.",
	"lab": "Scientists gather data here. Spend data on research for permanent bonuses.",
	"medbay": "Medics keep the crew healthy: the whole train works harder and newcomers settle in faster.",
}

var uid := 0
var _type := ""
var _main_text: Label
var _sub_text: Label
var _bar: ProgressBar
var _slots_row: HBoxContainer
var _slots_sig := ""
var _benefit: Label
var _cost_box: HBoxContainer
var _upgrade: Button
var _reason: Label
var _boost: Button


func build() -> void:
	var c := Game.carriage(uid)
	if c.is_empty():
		return
	_type = c["type"]
	var d: Dictionary = Data.CARRIAGES[_type]
	header(d["icon"], "%s  ·  Lv.%d" % [d["name"].to_upper(), c["level"]], PLAIN[_type])

	# What it does right now.
	_main_text = UIKit.label("", "Header")
	_main_text.add_theme_font_size_override("font_size", 28)
	_sub_text = UIKit.label("", "Small")
	var col := UIKit.vbox(2, [_main_text, _sub_text])
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var main_icon: String = d.get("res", d["icon"])
	var box := UIKit.vbox(6, [UIKit.hbox(12, [Icon.make(main_icon, 48), col])])
	if _type == "dronebay":
		_bar = UIKit.bar(0.0, UIKit.GOLD, 14)
		box.add_child(_bar)
	if Data.BOOSTABLE.has(_type):
		_boost = UIKit.button("OVERDRIVE", "GoldButton", "up", 52)
		_boost.size_flags_horizontal = Control.SIZE_SHRINK_END
		_boost.pressed.connect(func():
			if Game.boost(uid):
				Audio.play("boost")
				Audio.play("upgrade")
			else:
				Audio.play("error"))
		box.get_child(0).add_child(_boost)
	add_child(UIKit.panel("Card", box))

	if _type == "lab":
		var rb := UIKit.button("OPEN RESEARCH", "TealButton", "flask", 58)
		rb.pressed.connect(func(): main.open_research())
		main.register_target("open_research", rb)
		add_child(rb)

	# Workers as slots.
	if Data.slots(_type, 1) > 0:
		var t := UIKit.label("WORKERS", "Small")
		t.add_theme_color_override("font_color", UIKit.GOLD)
		_slots_row = UIKit.hbox(8)
		add_child(UIKit.vbox(4, [t, _slots_row]))
		_slots_sig = ""

	# One upgrade box.
	_benefit = UIKit.wrap_label("", "")
	_benefit.add_theme_font_size_override("font_size", 21)
	_cost_box = UIKit.hbox(8)
	_reason = UIKit.label("", "Small")
	_reason.add_theme_color_override("font_color", UIKit.ORANGE)
	_upgrade = UIKit.button("UPGRADE", "GoldButton", "up", 62)
	_upgrade.custom_minimum_size.x = 210
	_upgrade.pressed.connect(func():
		if not Game.upgrade(uid):
			Audio.play("error"))
	main.register_target("upgrade", _upgrade)
	var left := UIKit.vbox(4, [_benefit, _cost_box, _reason])
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UIKit.panel("CardGold", UIKit.hbox(10, [left, _upgrade])))


func _status(c: Dictionary) -> Array:
	var lv: int = c["level"]
	var n := Game.workers_in(uid).size()
	match _type:
		"greenhouse", "recycler", "workshop", "lab":
			var res: String = Data.CARRIAGES[_type]["res"]
			var per_min := Game.carriage_output(c)
			if n == 0:
				return ["Makes nothing yet", "Add a worker below to start making %s" % Data.RES_NAMES[res].to_lower()]
			var extra := " (uses %.1f scrap/min)" % (per_min * Data.SCRAP_PER_PART) if _type == "workshop" else ""
			return ["Makes %.1f %s / min" % [per_min, Data.RES_NAMES[res].to_lower()], "with %d worker%s%s" % [n, "" if n == 1 else "s", extra]]
		"quarters":
			return ["%d beds" % Data.beds(lv), "%d of %d beds used on the whole train" % [Game.survivors.size(), Game.capacity()]]
		"cooling":
			return ["Room for +%d carriages" % Data.cooling_capacity(lv, n > 0), "A worker here adds +1 more"]
		"dronebay":
			if Game.drones_grounded():
				return ["Drones grounded", "Waiting for the sandstorm to pass"]
			var left := Game.drone_run_time() - float(c["timer"])
			return ["+%d scrap in %s" % [int(Game.drone_yield(c) * Game.efficiency()), UIKit.fmt_time(left)], "%d drone%s · trips repeat automatically" % [Data.drones(lv), "" if Data.drones(lv) == 1 else "s"]]
		"locomotive":
			return ["Storage x%.1f" % Data.loco_mult(lv), "Speed %d km/h" % int(Game.train_speed() * 360.0)]
		"cargo":
			var b := Data.storage_bonus("cargo", lv)
			return ["+%s scrap storage" % UIKit.fmt(b["scrap"] * (1.0 + Game.bonus("storage"))), "+%s parts, food and water · +%s data" % [UIKit.fmt(b["parts"]), UIKit.fmt(b["data"])]]
		"medbay":
			if n == 0:
				return ["No medic on duty", "Add a worker below to boost the whole train"]
			return ["Whole train +%d%%" % int(round(Game.care() * 100.0)), "Newcomers arrive %d%% faster" % int(round(Game.care() * 200.0))]
	return ["", ""]


func _benefit_text(lv: int) -> String:
	var parts: PackedStringArray = []
	match _type:
		"greenhouse", "recycler", "workshop", "lab":
			parts.append("+40% output per worker")
			if Data.slots(_type, lv + 1) > Data.slots(_type, lv):
				parts.append("+1 worker slot")
			parts.append("more storage")
		"quarters":
			parts.append("+%d beds" % (Data.beds(lv + 1) - Data.beds(lv)))
		"cooling":
			parts.append("room for +1 carriage")
		"dronebay":
			parts.append("+1 drone (more scrap per trip)")
			if Data.slots(_type, lv + 1) > Data.slots(_type, lv):
				parts.append("+1 pilot slot")
			parts.append("more scrap storage")
		"locomotive":
			parts.append("+50% storage for everything")
			parts.append("faster journey")
		"cargo":
			parts.append("+60% storage in this hold")
		"medbay":
			parts.append("stronger care per medic")
			if Data.slots(_type, lv + 1) > Data.slots(_type, lv):
				parts.append("+1 medic slot")
	return "Upgrade to Lv.%d: %s" % [lv + 1, ", ".join(parts)]


func refresh() -> void:
	var c := Game.carriage(uid)
	if c.is_empty():
		return
	var s := _status(c)
	_main_text.text = s[0]
	_sub_text.text = s[1]
	if _bar:
		_bar.value = float(c["timer"]) / Game.drone_run_time() if c["active"] else 0.0
	if _boost:
		_boost.visible = Game.tutorial_done()
		var lbl: Label = _boost.get_meta("label")
		if c["boost"] > 0.0:
			lbl.text = "x2 · %s" % UIKit.fmt_time(c["boost"])
		elif c["boost_cd"] > 0.0:
			lbl.text = UIKit.fmt_time(c["boost_cd"])
		else:
			lbl.text = "OVERDRIVE x2"
		_boost.disabled = Game.boost_block_reason(uid) != ""
	if _slots_row:
		_refresh_slots(c)
	var lv: int = c["level"]
	UIKit.clear(_cost_box)
	if lv >= Game.level_cap():
		_benefit.text = "Fully upgraded" if lv >= Data.MAX_LEVEL else "Max level for this region. The next region allows Lv.%d." % (lv + 1)
		_upgrade.disabled = true
		_reason.text = ""
	else:
		_benefit.text = _benefit_text(lv)
		_cost_box.add_child(UIKit.cost_row(Game.upgrade_cost(c), 26))
		var why := Game.upgrade_block_reason(uid)
		_upgrade.disabled = why != ""
		_reason.text = "Not enough resources yet" if why == "Not enough resources" else why


func _refresh_slots(c: Dictionary) -> void:
	var workers := Game.workers_in(uid)
	var slots := Data.slots(_type, c["level"])
	var sig := "%s|%d|%d" % [str(workers.map(func(s): return [s["id"], Game.crew_level(s)])), slots, Game.idle_survivors().size()]
	if sig == _slots_sig:
		return
	_slots_sig = sig
	UIKit.clear(_slots_row)
	var want: String = Data.CARRIAGES[_type].get("role", "")
	for s in workers:
		var p := Portrait.new()
		p.look = s["look"]
		p.role = s["role"]
		p.custom_minimum_size = Vector2(52, 52)
		var name := UIKit.label("%s%s\nLv.%d" % [s["name"], " ★" if s["role"] == want else "", Game.crew_level(s)], "Small")
		name.add_theme_color_override("font_color", UIKit.TEXT)
		var b := Button.new()
		b.theme_type_variation = "Button"
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.custom_minimum_size = Vector2(150, 64)
		b.tooltip_text = "Tap to send to rest"
		var row := UIKit.hbox(6, [p, name])
		b.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 6
		var sid: int = s["id"]
		b.pressed.connect(func():
			Audio.play("ui_click")
			Game.assign(sid, 0))
		_slots_row.add_child(b)
	var first_empty := true
	var idle := Game.idle_survivors()
	var others := Game.survivors.size() - workers.size()
	for i in slots - workers.size():
		var add := UIKit.button("+", "GreenButton" if not idle.is_empty() else "", "", 64)
		add.custom_minimum_size = Vector2(64, 64)
		add.add_theme_font_size_override("font_size", 34)
		add.disabled = others <= 0
		add.tooltip_text = "Add a resting survivor" if not idle.is_empty() else "Move a worker here from another carriage"
		add.pressed.connect(func():
			Audio.play("ui_click")
			Game.pull_worker(uid))
		_slots_row.add_child(add)
		if first_empty:
			main.register_target("assign_slot", add)
			first_empty = false
	if workers.size() < slots and idle.is_empty():
		var note := UIKit.label("Everyone is busy. Tap + to move a worker here, or add beds so more survivors join.", "Small")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_slots_row.add_child(note)

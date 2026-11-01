class_name CrewPanel
extends BasePanel
## Crew screen: every survivor with portrait, specialty and job assignment.

const JOB_LABEL := {"workshop": "Workshop", "greenhouse": "Greenhouse", "recycler": "Water Recycler",
	"dronebay": "Drone Bay", "cooling": "Cooling Module", "lab": "Research Lab", "medbay": "Med Bay"}
var _title: Label
var _sub: Label
var _grid: GridContainer
var _sig := ""
var _xp := {} # sid -> [level label, xp bar]


func build() -> void:
	var row := header("crew", "CREW", "", false)
	_title = row.get_child(1).get_child(0)
	_sub = UIKit.wrap_label("", "Small")
	row.get_child(1).add_child(_sub)
	var auto := UIKit.button("AUTO-ASSIGN", "TealButton", "crew", 56)
	auto.pressed.connect(func():
		var n := Game.auto_assign()
		main.show_toast("Assigned %d resting survivor%s" % [n, "" if n == 1 else "s"] if n > 0 else "No free job slots for resting crew", "good" if n > 0 else "info"))
	row.add_child(auto)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = clampf(main.get_viewport_rect().size.y - 820.0, 380.0, 640.0)
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	_sig = ""


func refresh() -> void:
	var assigned := Game.survivors.size() - Game.idle_survivors().size()
	_title.text = "CREW · %d SURVIVORS" % Game.survivors.size()
	var upkeep := Game.survivors.size() * Data.FOOD_PER_SURVIVOR * 60.0 * Game.upkeep_mult()
	_sub.text = "Assigned %d · Resting %d · Beds %d/%d · Upkeep %.1f food & water/min" % [
		assigned, Game.survivors.size() - assigned, Game.survivors.size(), Game.capacity(), upkeep]
	var sig := str(Game.survivors.map(func(s): return [s["id"], s["job"]]))
	if sig != _sig:
		_sig = sig
		UIKit.clear(_grid)
		_xp.clear()
		# Most experienced first, so the veterans are easy to find.
		var list := Game.survivors.duplicate()
		list.sort_custom(func(a, b): return a.get("xp", 0.0) > b.get("xp", 0.0))
		for s in list:
			_grid.add_child(_card(s))
	for s in Game.survivors:
		if not _xp.has(s["id"]):
			continue
		var lv := Game.crew_level(s)
		_xp[s["id"]][0].text = "Lv.%d" % lv
		var lo := Data.xp_for(lv)
		var hi := Data.xp_for(lv + 1)
		_xp[s["id"]][1].value = 1.0 if lv >= Data.MAX_CREW_LEVEL else (s.get("xp", 0.0) - lo) / (hi - lo)


func _card(s: Dictionary) -> Control:
	var p := Portrait.new()
	p.look = s["look"]
	p.role = s["role"]
	p.custom_minimum_size = Vector2(112, 112)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var name := UIKit.label(s["name"], "Header", HORIZONTAL_ALIGNMENT_CENTER)
	name.add_theme_font_size_override("font_size", 26)
	var role := UIKit.label(s["role"], "Sub", HORIZONTAL_ALIGNMENT_CENTER)
	role.add_theme_color_override("font_color", CarriageView.SHIRT.get(s["role"], UIKit.MUTED).lightened(0.25))
	var job := "Resting"
	var icon := "bed"
	var c := Game.carriage(s["job"])
	if not c.is_empty():
		job = "%s Lv.%d" % [JOB_LABEL.get(c["type"], c["type"]), c["level"]]
		icon = Data.CARRIAGES[c["type"]]["icon"]
	var btn := UIKit.button(job, "Button" if c.is_empty() else "GreenButton", icon, 50)
	(btn.get_meta("label") as Label).add_theme_font_size_override("font_size", 20)
	(btn.get_meta("label") as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	(btn.get_meta("label") as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sid: int = s["id"]
	btn.pressed.connect(func(): Popups.assign(main, sid))
	var match_job: String = Data.ROLE_JOB.get(s["role"], "")
	var perk := UIKit.wrap_label("+25%% in %s" % JOB_LABEL.get(match_job, "?"), "Small")
	perk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not c.is_empty() and c["type"] == match_job:
		perk.add_theme_color_override("font_color", UIKit.GREEN)
		perk.text = "★ " + perk.text
	var lvl := UIKit.label("", "Accent")
	var bar := UIKit.bar(0.0, UIKit.GOLD, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp[s["id"]] = [lvl, bar]
	var card := UIKit.panel("Card", UIKit.vbox(4, [p, name, role, UIKit.hbox(6, [lvl, bar]), btn, perk]))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 200
	return card

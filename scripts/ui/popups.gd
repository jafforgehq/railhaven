class_name Popups
extends RefCounted
## Modal dialogs: offline report, environmental event choice, tower restored,
## settings, job picker and chapter goals.


static func _modal_box(width := 640.0) -> VBoxContainer:
	var v := UIKit.vbox(14)
	v.custom_minimum_size.x = width
	return v


static func _wrap(main: Node, v: Control, dismissable := true, variation := "Modal") -> PanelContainer:
	var p := UIKit.panel(variation, v)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	main.open_modal(p, dismissable)
	return p


static func _title(text: String, sub := "", col := UIKit.TEXT) -> Control:
	var t := UIKit.label(text, "Title", HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_color", col)
	var v := UIKit.vbox(0, [t])
	if sub != "":
		var s := UIKit.label(sub, "Header", HORIZONTAL_ALIGNMENT_CENTER)
		s.add_theme_color_override("font_color", UIKit.GOLD)
		v.add_child(s)
	return v


# ---------------------------------------------------------------- offline

static func offline(main: Node, r: Dictionary) -> void:
	var v := _modal_box(600)
	v.add_child(_title("WHILE YOU WERE AWAY", UIKit.fmt_time(r["seconds"])))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	for k in Data.RES:
		var g: float = r["gains"][k]
		var val := UIKit.label(("+" if g >= 0 else "") + UIKit.fmt(g) if absf(g) >= 1.0 else "±0", "Value", HORIZONTAL_ALIGNMENT_CENTER)
		val.add_theme_color_override("font_color", UIKit.GREEN if g >= 1.0 else (UIKit.RED if g <= -1.0 else UIKit.MUTED))
		var ic := Icon.make(k, 44)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tile := UIKit.panel("Card", UIKit.vbox(4, [ic, UIKit.label(Data.RES_NAMES[k], "Small", HORIZONTAL_ALIGNMENT_CENTER), val]))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(tile)
	v.add_child(grid)
	var extra: PackedStringArray = []
	if r["survivors"] > 0:
		extra.append("+%d survivors joined" % r["survivors"])
	extra.append("%d km travelled" % int(r["distance"]))
	if r["stages"] > 0:
		extra.append("%d tower stage%s finished" % [r["stages"], "" if r["stages"] == 1 else "s"])
	v.add_child(UIKit.label(" · ".join(extra), "Sub", HORIZONTAL_ALIGNMENT_CENTER))
	var safe: bool = r["safe_mode"]
	var status := UIKit.label("Safe mode engaged — rationing kept the crew alive. Growth slowed." if safe else "Crew safe · Systems stable", "")
	status.add_theme_color_override("font_color", UIKit.ORANGE if safe else UIKit.GREEN)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(UIKit.panel("Card", UIKit.hbox(8, [Icon.make("shield", 28, UIKit.ORANGE if safe else UIKit.GREEN), status])))
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn := UIKit.button("COLLECT", "TealButton", "check", 70)
	v.add_child(btn)
	var g := Game.current_goal()
	if not g.is_empty():
		var p := Game.goal_progress(g)
		v.add_child(UIKit.label("Next goal: %s (%d/%d)" % [g["text"], mini(p[0], p[1]), p[1]], "Small", HORIZONTAL_ALIGNMENT_CENTER))
	var panel := _wrap(main, v, false)
	btn.pressed.connect(func():
		Audio.play("collect")
		main.close_modal_of(panel))


# ---------------------------------------------------------------- events

static func event(main: Node) -> void:
	if Game.event.is_empty() or Game.event["choice"] != "":
		return
	var id: String = Game.event["id"]
	var d: Dictionary = Data.EVENTS[id]
	var v := _modal_box(660)
	var head := UIKit.panel("Warn", UIKit.hbox(12, [Icon.make("warning", 40, UIKit.ORANGE), UIKit.vbox(-4, [UIKit.label(d["title"], "Header"), UIKit.label(d["sub"], "Sub")])]))
	v.add_child(head)
	v.add_child(UIKit.wrap_label(d["text"], ""))
	var row := UIKit.hbox(12)
	v.add_child(row)
	var timer := UIKit.label("", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(UIKit.hbox(6, [UIKit.spacer(), Icon.make("shield", 20, UIKit.MUTED), timer, UIKit.spacer()]))
	var buttons := []
	for choice in ["a", "b"]:
		var o: Dictionary = d[choice]
		var effect := UIKit.label(o["effect"], "Accent" if choice == "a" else "Value")
		if choice == "b":
			effect.add_theme_color_override("font_color", UIKit.GOLD)
		var cost: Control = UIKit.cost_row(o["cost"], 24) if not o["cost"].is_empty() else UIKit.label("No cost", "Small")
		var btn := UIKit.button(o["label"], "TealButton" if choice == "a" else "GoldButton", "", 60)
		var ch: String = choice
		btn.pressed.connect(func():
			if Game.choose_event(ch):
				main.close_modal() # topmost; lambdas capture locals by value so `panel` is still null here
			else:
				Audio.play("error"))
		buttons.append([btn, o["cost"], id == "signal" and choice == "a"])
		var col := UIKit.vbox(8, [Icon.make(o["icon"], 48, UIKit.TEAL if choice == "a" else UIKit.GOLD), UIKit.label(o["title"], "Header"),
			UIKit.wrap_label(o["desc"], "Small"), HSeparator.new(), cost, effect, UIKit.spacer(false), btn])
		var card := UIKit.panel("CardTeal" if choice == "a" else "CardGold", col)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
	var panel := _wrap(main, v, true)
	var refresh := func():
		if Game.event.is_empty() or Game.event["choice"] != "" or Game.event.get("id", "") != id:
			main.close_modal_of(panel)
			return
		timer.text = ("The flare fades in %ds" if id == "signal" else "Automatic safe mode in %ds") % int(ceil(Game.event["decide_left"]))
		for b in buttons:
			b[0].disabled = not Game.can_afford(b[1]) or (b[2] and not Game.can_rescue())
	refresh.call()
	panel.set_meta("refresh", refresh)
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.timeout.connect(refresh)
	panel.add_child(t)


# ---------------------------------------------------------------- chapter complete

static func tower_restored(main: Node) -> void:
	Game.chapter_seen = true
	var v := _modal_box(640)
	var ic := Icon.make("tower", 96, UIKit.TEAL)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(_title("CLIMATE TOWER RESTORED", "", UIKit.TEAL))
	v.add_child(UIKit.wrap_label("The tower hums once more. A small zone of stable climate brings water, life and new possibilities to the Ash Coast.", ""))
	var lbl := UIKit.label("REWARDS UNLOCKED", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	lbl.add_theme_color_override("font_color", UIKit.GOLD)
	v.add_child(lbl)
	for r in [["water", "Water recovery unlocked", "+25% water from every recycler."],
			["map", "New region: Ash Coast", "Outside temperature drops to 55°C."],
			["cooling", "Cooler air", "+1 cooling capacity for the whole train."]]:
		var txt := UIKit.vbox(0, [UIKit.label(r[1], "Value"), UIKit.wrap_label(r[2], "Small")])
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.panel("Card", UIKit.hbox(12, [Icon.make(r[0], 40, UIKit.TEAL), txt])))
	var btn := UIKit.button("CONTINUE JOURNEY", "TealButton", "map", 70)
	v.add_child(btn)
	var panel := _wrap(main, v, false)
	btn.pressed.connect(func(): main.close_modal_of(panel))
	Audio.play("whistle")
	if Game.autosave:
		Game.save_game()


# ---------------------------------------------------------------- settings

static func settings(main: Node) -> void:
	var v := _modal_box(560)
	v.add_child(_title("SETTINGS"))
	var music := CheckButton.new()
	music.text = "Music"
	music.button_pressed = Audio.music_on
	music.toggled.connect(func(on): Audio.set_music(on))
	var sfx := CheckButton.new()
	sfx.text = "Sound effects & ambience"
	sfx.button_pressed = Audio.sfx_on
	sfx.toggled.connect(func(on): Audio.set_sfx(on))
	for c in [music, sfx]:
		c.focus_mode = Control.FOCUS_NONE
		c.add_theme_font_size_override("font_size", 26)
	v.add_child(UIKit.panel("Card", UIKit.vbox(6, [UIKit.hbox(10, [Icon.make("music", 28, UIKit.TEAL), music]), UIKit.hbox(10, [Icon.make("sound", 28, UIKit.TEAL), sfx])])))
	music.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var credits := UIKit.wrap_label("Railhaven: Scorched Line · first playable. Music: \"Lone Scavenger\" by vitalezzz (CC0). Fanfare: \"Smooth Guitar Fanfare\" by OwlishMedia (CC BY 4.0). Wind: \"Wind Loop\" by AntumDeluge from InspectorJ (CC BY 3.0). SFX: Kenney, Wikimedia Commons and OpenGameArt contributors (CC0). Font: Barlow Condensed (OFL). Full list in assets/audio/CREDITS.md.", "Small")
	v.add_child(credits)
	var reset := UIKit.button("RESET PROGRESS", "RedButton", "warning", 58)
	var close := UIKit.button("CLOSE", "TealButton", "", 58)
	v.add_child(UIKit.hbox(10, [reset, close]))
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := _wrap(main, v)
	close.pressed.connect(func(): main.close_modal_of(panel))
	reset.pressed.connect(func(): _confirm_reset(main, panel))


static func _confirm_reset(main: Node, parent: Control) -> void:
	var v := _modal_box(520)
	v.add_child(_title("RESET PROGRESS?", "", UIKit.RED))
	v.add_child(UIKit.wrap_label("This deletes your train, crew and journey and starts over. It cannot be undone.", ""))
	var yes := UIKit.button("DELETE SAVE", "RedButton", "", 58)
	var no := UIKit.button("KEEP PLAYING", "TealButton", "", 58)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.hbox(10, [no, yes]))
	var panel := _wrap(main, v)
	no.pressed.connect(func(): main.close_modal_of(panel))
	yes.pressed.connect(func():
		main.close_modal_of(panel)
		main.close_modal_of(parent)
		Game.reset_game()
		main.world.rebuild()
		main._rebuild_plates()
		main.set_tab("train"))


# ---------------------------------------------------------------- job picker

static func assign(main: Node, sid: int) -> void:
	var s := Game.survivor(sid)
	if s.is_empty():
		return
	var v := _modal_box(560)
	var pic := Portrait.new()
	pic.look = s["look"]
	pic.role = s["role"]
	pic.custom_minimum_size = Vector2(80, 80)
	v.add_child(UIKit.hbox(14, [pic, UIKit.vbox(0, [UIKit.label(s["name"], "Title"), UIKit.label("%s · +25%% in %s" % [s["role"], Data.CARRIAGES[Data.ROLE_JOB[s["role"]]]["name"]], "Sub")])]))
	var list := UIKit.vbox(8)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 460
	scroll.add_child(list)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var rest := UIKit.button("Rest in Living Quarters", "" if s["job"] != 0 else "GreenButton", "bed", 58)
	rest.pressed.connect(func():
		Game.assign(sid, 0)
		main.close_modal())
	list.add_child(rest)
	for c in Game.carriages:
		var slots := Data.slots(c["type"], c["level"])
		if slots == 0:
			continue
		var d: Dictionary = Data.CARRIAGES[c["type"]]
		var here: bool = s["job"] == c["uid"]
		var n := Game.workers_in(c["uid"]).size()
		var star := "  ★" if Data.ROLE_JOB.get(s["role"], "") == c["type"] else ""
		var b := UIKit.button("%s Lv.%d   %d/%d%s" % [d["name"], c["level"], n, slots, star], "GreenButton" if here else "", d["icon"], 58)
		b.disabled = not here and n >= slots
		var uid: int = c["uid"]
		b.pressed.connect(func():
			Game.assign(sid, uid)
			main.close_modal())
		list.add_child(b)
	_wrap(main, v)


# ---------------------------------------------------------------- goals

static func goals(main: Node) -> void:
	var v := _modal_box(600)
	v.add_child(_title("CHAPTER 1", "Toward the Climate Tower"))
	for i in Data.GOALS.size():
		var g: Dictionary = Data.GOALS[i]
		var done := i < Game.goal_index
		var cur := i == Game.goal_index
		var p := Game.goal_progress(g)
		var l := UIKit.label(g["text"], "Value" if cur else "")
		l.add_theme_color_override("font_color", UIKit.GREEN if done else (UIKit.TEXT if cur else UIKit.MUTED))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var right := UIKit.label("" if not cur else "%d/%d" % [mini(p[0], p[1]), p[1]], "Small")
		var reward := Data.cost_text(g["reward"])
		var row := UIKit.hbox(10, [Icon.make("check" if done else ("star" if cur else "lock"), 24, UIKit.GREEN if done else (UIKit.GOLD if cur else UIKit.MUTED)), l, UIKit.label(reward, "Small"), right])
		v.add_child(UIKit.panel("CardGold" if cur else "Card", row))
	var close := UIKit.button("CLOSE", "TealButton", "", 58)
	v.add_child(close)
	var panel := _wrap(main, v)
	close.pressed.connect(func(): main.close_modal_of(panel))

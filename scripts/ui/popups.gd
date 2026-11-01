class_name Popups
extends RefCounted
## Modal dialogs: level won, overheated, leave level, booster shop, Condenser, daily gift,
## out of lives, region restored, carriage info, settings and how to play.


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


static func _big_icon(kind: String, size := 96, col := Color.WHITE) -> Control:
	var ic := Icon.make(kind, size, col)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return ic


static func _reward_row(items: Array) -> Control:
	# items: [[icon, text], ...]
	var row := UIKit.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for it in items:
		var l := UIKit.label(it[1], "Title")
		l.add_theme_font_size_override("font_size", 40)
		row.add_child(UIKit.hbox(8, [Icon.make(it[0], 48), l]))
	return row


static func _ad_button(text: String) -> Button:
	return UIKit.button(text, "GoldButton", "play", 64)


# ---------------------------------------------------------------- level results

static func win(main: Node, r: Dictionary) -> void:
	var v := _modal_box(600)
	v.add_child(_big_icon("snowflake", 110, Color("9fe6ff")))
	v.add_child(_title("CARRIAGE COOLED!", "Level %d complete" % r["level"], UIKit.TEAL))
	v.add_child(_reward_row([["parts", "+%d" % r["parts"]], ["scrap", "+%d" % r["scrap"]]]))
	if r["bonus"] > 0:
		v.add_child(UIKit.label("Includes +%d scrap cool bonus for finishing below 70°C" % r["bonus"], "Small", HORIZONTAL_ALIGNMENT_CENTER))
	var t := Game.current_task()
	if not t.is_empty():
		# Progress toward the next piece of the train, so every win visibly moves it forward.
		var can := Game.task_block_reason() == ""
		var hint := UIKit.label(("You can restore: %s" if can else "Next: %s") % t["text"], "Accent" if can else "", HORIZONTAL_ALIGNMENT_CENTER)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
		var bar := UIKit.bar(Game.task_progress(), UIKit.GREEN if can else UIKit.GOLD, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.hbox(8, [Icon.make("parts", 24), bar, UIKit.label("%d/%d" % [mini(Game.parts, int(t["cost"])), int(t["cost"])], "Small")]))
	var cont := UIKit.button("CONTINUE", "TealButton", "check", 72)
	v.add_child(cont)
	var panel := _wrap(main, v, false)
	cont.pressed.connect(func():
		main.close_modal_of(panel)
		main.show_home())


static func overheated(main: Node, screen: Node, stuck := false) -> void:
	var v := _modal_box(600)
	v.add_child(_big_icon("temp", 100, UIKit.RED))
	v.add_child(_title("NO MOVES LEFT" if stuck else "OVERHEATED!", "Add a spare tank to keep going" if stuck else "The carriage hit %d°C" % int(Data.HEAT_MAX), UIKit.RED))
	var cost: int = Game.continue_cost(screen.continues)
	var pay := UIKit.button("COOL DOWN  -%d°C   %d" % [int(Data.CONTINUE_COOL), cost], "TealButton", "scrap", 66)
	pay.disabled = Game.scrap < cost
	var ad := _ad_button("WATCH AD TO COOL DOWN")
	var quit := UIKit.button("GIVE UP (lose a life)", "RedButton", "heart", 60)
	v.add_child(pay)
	if screen.continues == 0:
		v.add_child(ad)
	v.add_child(quit)
	var panel := _wrap(main, v, false)
	pay.pressed.connect(func():
		if Game.spend(cost):
			main.close_modal_of(panel)
			screen.continue_level())
	ad.pressed.connect(func():
		ad.disabled = true
		Ads.rewarded("continue", func():
			main.close_modal_of(panel)
			screen.continue_level()))
	quit.pressed.connect(func():
		main.close_modal_of(panel)
		screen.give_up())


static func confirm_leave(main: Node, screen: Node) -> void:
	var v := _modal_box(540)
	v.add_child(_title("LEAVE LEVEL?", "", UIKit.ORANGE))
	v.add_child(UIKit.wrap_label("You will lose a life. Lives refill over time.", ""))
	var stay := UIKit.button("KEEP PLAYING", "TealButton", "", 62)
	var leave := UIKit.button("LEAVE", "RedButton", "heart", 62)
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.hbox(10, [leave, stay]))
	var panel := _wrap(main, v)
	stay.pressed.connect(func(): main.close_modal_of(panel))
	leave.pressed.connect(func():
		main.close_modal_of(panel)
		screen.give_up())


# ---------------------------------------------------------------- shop & lives

static func shop(main: Node, focus := "") -> void:
	var v := _modal_box(620)
	v.add_child(_title("BOOSTERS", "You have %d scrap" % Game.scrap))
	var rows := []
	for id in Data.BOOSTER_ORDER:
		var d: Dictionary = Data.BOOSTERS[id]
		var name := UIKit.label("%s  x%d" % [d["name"], Game.booster_count(id)], "Value")
		var col := UIKit.vbox(0, [name, UIKit.wrap_label(d["desc"], "Small")])
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buy := UIKit.button("%d" % d["price"], "GoldButton", "scrap", 58)
		buy.custom_minimum_size.x = 140
		buy.disabled = Game.scrap < int(d["price"])
		var bid: String = id
		buy.pressed.connect(func():
			if Game.buy_booster(bid):
				Audio.play("collect")
				name.text = "%s  x%d" % [d["name"], Game.booster_count(bid)]
				for r in rows:
					r[0].disabled = Game.scrap < int(Data.BOOSTERS[r[1]]["price"])
			else:
				Audio.play("error"))
		rows.append([buy, id])
		v.add_child(UIKit.panel("CardGold" if id == focus else "Card", UIKit.hbox(12, [Icon.make(d["icon"], 52), col, buy])))
	var close := UIKit.button("CLOSE", "TealButton", "", 58)
	v.add_child(close)
	var panel := _wrap(main, v)
	close.pressed.connect(func(): main.close_modal_of(panel))


static func out_of_lives(main: Node) -> void:
	var v := _modal_box(560)
	v.add_child(_big_icon("heart", 96))
	v.add_child(_title("OUT OF LIVES", "Next life in %s" % UIKit.fmt_time(Game.next_life_in())))
	v.add_child(UIKit.wrap_label("Lives come back one every %d minutes. Refill now to keep cooling the train." % int(Data.LIFE_REGEN / 60.0), ""))
	var refill := UIKit.button("REFILL ALL   %d" % Data.REFILL_COST, "TealButton", "scrap", 64)
	refill.disabled = Game.scrap < Data.REFILL_COST
	var ad := _ad_button("WATCH AD FOR 1 LIFE")
	var close := UIKit.button("LATER", "", "", 56)
	v.add_child(refill)
	v.add_child(ad)
	v.add_child(close)
	var panel := _wrap(main, v)
	refill.pressed.connect(func():
		if Game.refill_lives():
			Audio.play("collect")
			main.close_modal_of(panel))
	ad.pressed.connect(func():
		ad.disabled = true
		Ads.rewarded("life", func():
			Game.lives = mini(Data.MAX_LIVES, Game.lives + 1)
			Game.changed.emit()
			main.close_modal_of(panel)))
	close.pressed.connect(func(): main.close_modal_of(panel))


# ---------------------------------------------------------------- condenser & daily

static func condenser(main: Node) -> void:
	var v := _modal_box(620)
	v.add_child(_big_icon("condenser", 96))
	var title := _title("CONDENSER", "Turns cool night air into scrap, even while you are away")
	v.add_child(title)
	var amount := UIKit.label("", "Title", HORIZONTAL_ALIGNMENT_CENTER)
	var fill := UIKit.bar(0.0, UIKit.TEAL, 16)
	var info := UIKit.label("", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(UIKit.hbox(8, [UIKit.spacer(), Icon.make("scrap", 48), amount, UIKit.spacer()]))
	v.add_child(fill)
	v.add_child(info)
	var claim := UIKit.button("COLLECT", "TealButton", "check", 64)
	var double := _ad_button("AD: COLLECT x2")
	claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	double.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.hbox(10, [claim, double]))
	var up_text := UIKit.wrap_label("", "Small")
	up_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var up := UIKit.button("UPGRADE", "GoldButton", "up", 58)
	up.custom_minimum_size.x = 190
	v.add_child(UIKit.panel("CardGold", UIKit.hbox(10, [up_text, up])))
	var close := UIKit.button("CLOSE", "", "", 56)
	v.add_child(close)
	var panel := _wrap(main, v)
	var refresh := func():
		var l := Game.condenser_level()
		var cap := Data.condenser_cap_hours(l)
		(title.get_child(0) as Label).text = "CONDENSER  Lv.%d" % l
		amount.text = "%d" % Game.condenser_amount()
		fill.value = Game.condenser_seconds() / (cap * 3600.0)
		info.text = "FULL: collect it to keep harvesting (a full tank adds a booster)" if Game.condenser_full() else "%d scrap per hour · holds %d hours · a full tank adds a booster" % [int(Data.condenser_rate(l)), int(cap)]
		claim.disabled = not Game.condenser_ready()
		double.disabled = not Game.condenser_ready() or double.has_meta("used")
		if l >= Data.CONDENSER_MAX:
			up_text.text = "Fully upgraded"
			up.disabled = true
		else:
			up_text.text = "Lv.%d: %d scrap/h, holds %d h\nCost %d scrap" % [l + 1, int(Data.condenser_rate(l + 1)), int(Data.condenser_cap_hours(l + 1)), Data.condenser_upgrade_cost(l)]
			up.disabled = Game.condenser_upgrade_block() != ""
	refresh.call()
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(refresh)
	panel.add_child(t)
	var collect := func(mult: int):
		var got := Game.claim_condenser(mult)
		if got.is_empty():
			return
		Audio.play("collect")
		main.show_toast("Condenser: +%d scrap%s" % [got["scrap"], (" and a " + Data.BOOSTERS[got["booster"]]["name"]) if got["booster"] != "" else ""], "good")
		refresh.call()
	claim.pressed.connect(func(): collect.call(1))
	double.pressed.connect(func():
		double.set_meta("used", true)
		double.disabled = true
		Ads.rewarded("condenser", func(): collect.call(2)))
	up.pressed.connect(func():
		if Game.upgrade_condenser():
			Audio.play("upgrade")
			refresh.call())
	close.pressed.connect(func(): main.close_modal_of(panel))


static func daily(main: Node) -> void:
	var v := _modal_box(540)
	v.add_child(_big_icon("gift", 100))
	if Game.daily_ready():
		v.add_child(_title("DAILY SUPPLY DROP", "A crate fell from a passing drone"))
		var open := UIKit.button("OPEN", "TealButton", "gift", 66)
		v.add_child(open)
		var panel := _wrap(main, v)
		open.pressed.connect(func():
			var got := Game.claim_daily()
			Audio.play("collect")
			main.close_modal_of(panel)
			main.show_toast("Supply drop: +%d scrap and a %s" % [got["scrap"], Data.BOOSTERS[got["booster"]]["name"]], "good"))
	else:
		v.add_child(_title("NEXT DROP", "in %s" % UIKit.fmt_time(Game.daily_in())))
		var close := UIKit.button("OK", "TealButton", "", 58)
		v.add_child(close)
		var panel := _wrap(main, v)
		close.pressed.connect(func(): main.close_modal_of(panel))


# ---------------------------------------------------------------- region

static func region_complete(main: Node) -> void:
	Game.region_seen = true
	var c := Game.region()
	var v := _modal_box(640)
	v.add_child(_big_icon(c["landmark"], 110, UIKit.TEAL))
	var last := Game.is_last_region()
	v.add_child(_title(("%s IS FOUNDED" if last else "%s RESTORED") % c["landmark_name"].to_upper(), "Region %d of %d complete" % [Game.region_index + 1, Data.REGIONS.size()], UIKit.TEAL))
	v.add_child(UIKit.wrap_label(c["done_text"], ""))
	var btn: Button
	if last:
		v.add_child(UIKit.panel("CardGold", UIKit.wrap_label("The journey is complete! Keep playing levels to collect scrap and boosters.", "Small")))
		btn = UIKit.button("KEEP PLAYING", "TealButton", "star", 70)
	else:
		var nxt: Dictionary = Data.REGIONS[Game.region_index + 1]
		var txt := UIKit.vbox(0, [UIKit.label("Next: %s" % nxt["region"], "Value"), UIKit.wrap_label(nxt["desc"], "Small")])
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.panel("Card", UIKit.hbox(12, [Icon.make(nxt["landmark"], 48, UIKit.TEAL), txt])))
		btn = UIKit.button("DEPART", "TealButton", "train", 70)
	v.add_child(btn)
	var panel := _wrap(main, v, false)
	btn.pressed.connect(func():
		main.close_modal_of(panel)
		if Game.advance_region():
			Audio.play("whistle"))
	Audio.play("whistle")


static func carriage_info(main: Node, uid: int) -> void:
	var c := Game.carriage(uid)
	if c.is_empty():
		return
	if c["type"] == "condenser":
		condenser(main)
		return
	var d: Dictionary = Data.CARRIAGES[c["type"]]
	var v := _modal_box(520)
	v.add_child(_big_icon(d["icon"], 80, UIKit.TEAL))
	v.add_child(_title(d["name"].to_upper(), "Lv.%d" % c["level"] if c["type"] != "locomotive" else ""))
	var text: String = d.get("desc", "Restored with parts from puzzle wins. Keep cooling carriages to upgrade it further.")
	if c["type"] == "cooling":
		text += " Puzzles now start at %d°C." % int(Game.start_heat())
	v.add_child(UIKit.wrap_label(text, ""))
	var ok := UIKit.button("OK", "TealButton", "", 58)
	v.add_child(ok)
	var panel := _wrap(main, v)
	ok.pressed.connect(func(): main.close_modal_of(panel))


# ---------------------------------------------------------------- settings & help

static func settings(main: Node) -> void:
	var v := _modal_box(560)
	v.add_child(_title("SETTINGS"))
	var rows := []
	for s in [["Music", "music", Audio.music_on, func(on): Audio.set_music(on)],
			["Sound effects", "sound", Audio.sfx_on, func(on): Audio.set_sfx(on)],
			["Vibration", "bulb", Audio.haptics_on, func(on): Audio.set_haptics(on)]]:
		var cb := CheckButton.new()
		cb.text = s[0]
		cb.button_pressed = s[2]
		cb.toggled.connect(s[3])
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", 26)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.append(UIKit.hbox(10, [Icon.make(s[1], 28, UIKit.TEAL), cb]))
	v.add_child(UIKit.panel("Card", UIKit.vbox(6, rows)))
	v.add_child(UIKit.wrap_label("Railhaven: Scorched Line. Music: \"Lone Scavenger\" by vitalezzz (CC0). Fanfare: \"Smooth Guitar Fanfare\" by OwlishMedia (CC BY 4.0). Wind: \"Wind Loop\" by AntumDeluge from InspectorJ (CC BY 3.0). SFX: Kenney, Wikimedia Commons and OpenGameArt contributors (CC0). Font: Barlow Condensed (OFL). Full list in assets/audio/CREDITS.md.", "Small"))
	var how := UIKit.button("HOW TO PLAY", "", "bulb", 58)
	v.add_child(how)
	var reset := UIKit.button("RESET PROGRESS", "RedButton", "warning", 58)
	var close := UIKit.button("CLOSE", "TealButton", "", 58)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.hbox(10, [reset, close]))
	var panel := _wrap(main, v)
	close.pressed.connect(func(): main.close_modal_of(panel))
	how.pressed.connect(func():
		main.close_modal_of(panel)
		how_to_play(main))
	reset.pressed.connect(func(): _confirm_reset(main, panel))


static func _confirm_reset(main: Node, parent: Control) -> void:
	var v := _modal_box(520)
	v.add_child(_title("RESET PROGRESS?", "", UIKit.RED))
	v.add_child(UIKit.wrap_label("This deletes your train, levels and scrap and starts over. It cannot be undone.", ""))
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
		main.world.on_region_started()
		main.show_home())


static func how_to_play(main: Node) -> void:
	var v := _modal_box(600)
	v.add_child(_title("HOW TO PLAY", "Keep the last train cool"))
	for step in [
		["tank", "Tap a tank to lift its top canisters, then tap another tank to pour them onto the same colour or into an empty tank."],
		["temp", "Every pour heats the carriage. Fill each tank with one colour before the gauge hits 70°C."],
		["snowflake", "Sealing tanks cools the carriage. Seal several within a few seconds for a cold snap."],
		["parts", "Wins give parts. Spend them to restore the train and the region's landmark."],
		["condenser", "The Condenser collects scrap while you are away. Tap it to collect."],
	]:
		var l := UIKit.wrap_label(step[1], "")
		l.add_theme_font_size_override("font_size", 23)
		v.add_child(UIKit.panel("Card", UIKit.hbox(14, [Icon.make(step[0], 48), l])))
	var ok := UIKit.button("LET'S GO", "TealButton", "", 66)
	v.add_child(ok)
	var panel := _wrap(main, v, false)
	ok.pressed.connect(func():
		Game.intro_seen = true
		main.close_modal_of(panel))

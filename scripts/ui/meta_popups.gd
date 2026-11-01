class_name MetaPopups
extends RefCounted
## Popups for the retention systems (pre-level start, calendar, album, events, race, story).
## Built from the same helpers as Popups so they share the modal look.


# ---------------------------------------------------------------- level start

## Candy-Crush-style level start: goal, blockers, win streak and pre-level boosters.
static func pre_level(main: Node) -> void:
	var n := Game.level
	var data := Game.level_data(n)
	var v := Popups._modal_box(620)
	var hard: bool = data.get("hard", false)
	v.add_child(Popups._title("LEVEL %d" % n, "HEATWAVE · double parts" if hard else Game.region_name(), UIKit.RED if hard else UIKit.TEXT))
	# Blockers in this level.
	var chips := UIKit.hbox(8)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	for kind in Data.BLOCKERS:
		var has: bool = data.has(kind) and (kind != "hidden" or data[kind].any(func(r): return r.has(true)))
		if has:
			var b: Dictionary = Data.BLOCKERS[kind]
			chips.add_child(UIKit.panel("Chip", UIKit.hbox(4, [Icon.make(b["icon"], 22), UIKit.label(b["title"].capitalize(), "Small")])))
	if chips.get_child_count() > 0:
		v.add_child(chips)
	# Win streak.
	var s := Meta.streak()
	var pips := UIKit.hbox(6)
	for k in 3:
		pips.add_child(Icon.make("streak", 34, UIKit.ORANGE if s > k else UIKit.MUTED))
	var st := UIKit.label("Win streak %d" % s if s > 0 else "Win in a row for free boosters", "Value")
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.panel("Card", UIKit.hbox(10, [st, pips])))
	# Pre-level boosters.
	var picked := []
	var free := Meta.streak_free()
	var row := UIKit.hbox(8)
	var cost_label := UIKit.label("", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	var play := UIKit.button("PLAY", "RedButton" if hard else "TealButton", "play", 80)
	var refresh := func():
		var cost := Meta.pre_cost(picked)
		cost_label.text = ("Costs %d scrap" % cost) if cost > 0 else ""
		play.disabled = Game.scrap < cost
	for id in Meta.PRE_ORDER:
		var d: Dictionary = Meta.PRE[id]
		var is_free: bool = id in free
		var owned := Game.booster_count(id)
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 128)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = is_free
		b.disabled = is_free
		var col := UIKit.vbox(2, [Icon.make(d["icon"], 44), UIKit.label(d["name"], "Small", HORIZONTAL_ALIGNMENT_CENTER),
			UIKit.label("FREE" if is_free else ("x%d" % owned if owned > 0 else "%d scrap" % d["price"]), "Small", HORIZONTAL_ALIGNMENT_CENTER)])
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in col.get_children():
			c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_child(col)
		var bid: String = id
		b.toggled.connect(func(on: bool):
			if on and not bid in picked:
				picked.append(bid)
			elif not on:
				picked.erase(bid)
			Audio.play("ui_click")
			refresh.call())
		row.add_child(b)
	v.add_child(row)
	v.add_child(cost_label)
	v.add_child(play)
	refresh.call()
	var panel := Popups._wrap(main, v)
	play.pressed.connect(func():
		main.close_modal_of(panel)
		main.play(picked))


# ---------------------------------------------------------------- 7-day calendar

static func calendar(main: Node) -> void:
	var v := Popups._modal_box(660)
	v.add_child(Popups._title("DAILY SUPPLIES", "A new crate every day. Day 7 is the big one."))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var day := Meta.cal_day()
	var ready := Meta.cal_ready()
	for i in Meta.CALENDAR.size():
		var r: Dictionary = Meta.CALENDAR[i]
		var done := i < day
		var now := i == day and ready
		var items := UIKit.vbox(2)
		items.add_child(UIKit.label("DAY %d" % (i + 1), "Small", HORIZONTAL_ALIGNMENT_CENTER))
		for k in r:
			items.add_child(UIKit.hbox(4, [Icon.make(Meta.reward_icon(k), 24), UIKit.label("%d" % int(r[k]), "Small")]))
		if done:
			items.add_child(Icon.make("check", 26, UIKit.GREEN))
		var card := UIKit.panel("CardGold" if now else ("CardTeal" if i == 6 else "Card"), items)
		card.custom_minimum_size = Vector2(140, 0)
		card.modulate.a = 0.55 if done else 1.0
		grid.add_child(card)
	var center := CenterContainer.new()
	center.add_child(grid)
	v.add_child(center)
	var btn := UIKit.button("CLAIM DAY %d" % (day + 1) if ready else "NEXT IN %s" % UIKit.fmt_time(Meta.cal_in()), "TealButton", "gift", 66)
	btn.disabled = not ready
	v.add_child(btn)
	var close := UIKit.button("CLOSE", "", "", 54)
	v.add_child(close)
	var panel := Popups._wrap(main, v)
	close.pressed.connect(func(): main.close_modal_of(panel))
	btn.pressed.connect(func():
		var got := Meta.claim_calendar()
		if got.is_empty():
			return
		Audio.play("collect")
		main.close_modal_of(panel)
		main.show_toast("Day %d supplies: %s" % [day + 1, Meta.reward_text(got)], "good"))


# ---------------------------------------------------------------- liveries

## Homescapes-style choice: three paint styles for a freshly built carriage.
static func livery(main: Node, uid: int) -> void:
	var c := Game.carriage(uid)
	if c.is_empty() or c["type"] == "locomotive":
		return
	var v := Popups._modal_box(620)
	v.add_child(Popups._title("PAINT THE %s" % Data.CARRIAGES[c["type"]]["name"].to_upper(), "Pick a livery. You can repaint it any time."))
	var row := UIKit.hbox(10)
	var panel: PanelContainer
	for l in Meta.livery_choices(uid):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sw := ColorRect.new()
		sw.color = Color(l["color"])
		sw.custom_minimum_size = Vector2(70, 70)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := UIKit.vbox(6, [sw, UIKit.label(l["name"], "Small", HORIZONTAL_ALIGNMENT_CENTER)])
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for ch in col.get_children():
			ch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_child(col)
		var hex: String = l["color"]
		b.pressed.connect(func():
			Meta.set_livery(uid, hex)
			main.world.rebuild()
			Audio.play("upgrade")
			main.close_modal_of(panel))
		row.add_child(b)
	v.add_child(row)
	panel = Popups._wrap(main, v)


# ---------------------------------------------------------------- postcard album

## A postcard image: an icon or a texture on a framed card.
static func card_view(src: String, size: Vector2, owned := true) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = size
	if not owned:
		var q := UIKit.label("?", "Title", HORIZONTAL_ALIGNMENT_CENTER)
		q.add_theme_color_override("font_color", UIKit.MUTED)
		card.add_child(q)
		return card
	if src.begins_with("icon:"):
		var ic := Icon.make(src.substr(5), int(size.y * 0.7))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.add_child(ic)
	else:
		var tr := TextureRect.new()
		tr.texture = load(src) if ResourceLoader.exists(src) else null
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = size - Vector2(12, 12)
		card.add_child(tr)
	return card


static func album(main: Node) -> void:
	var v := Popups._modal_box(680)
	var total := 0
	for r in Meta.ALBUM:
		total += r["cards"].size()
	v.add_child(Popups._title("POSTCARD ALBUM", "%d / %d collected · wins sometimes drop a postcard" % [Meta.cards().size(), total]))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UIKit.vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for ri in Meta.ALBUM.size():
		var r: Dictionary = Meta.ALBUM[ri]
		var head := UIKit.label(r["region"].to_upper() + ("  · COMPLETE" if Meta.set_done(ri) else "  · set reward: " + Meta.reward_text(Meta.SET_REWARD)), "Value")
		head.add_theme_color_override("font_color", UIKit.GREEN if Meta.set_done(ri) else UIKit.GOLD)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for c in r["cards"]:
			var owned := Meta.has_card(c[0])
			var cell := UIKit.vbox(2, [card_view(c[2], Vector2(190, 130), owned), UIKit.label(c[1] if owned else "???", "Small", HORIZONTAL_ALIGNMENT_CENTER)])
			grid.add_child(cell)
		list.add_child(grid)
	v.add_child(scroll)
	var close := UIKit.button("CLOSE", "TealButton", "", 58)
	v.add_child(close)
	var panel := Popups._wrap(main, v)
	close.pressed.connect(func(): main.close_modal_of(panel))

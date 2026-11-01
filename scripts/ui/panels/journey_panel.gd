class_name JourneyPanel
extends BasePanel
## Journey screen: the route through all regions and the current chapter goal — restoring
## the region's landmark remotely with drone expeditions, then departing for the next one.

var _route: RouteView
var _dist: Label
var _stages: VBoxContainer
var _exp_bar: ProgressBar
var _exp_time: Label
var _sig := ""
var _launch: Button
var _launch_cost: HBoxContainer
var _launch_reason: Label
var _goals_btn: Button
var _contracts: VBoxContainer
var _con_rows := [] # per slot: [bar, label, button-or-null]
var _con_sig := ""
var _ach_btn: Button


func build() -> void:
	header("map", "JOURNEY", "Across a burning world, towards a cooler tomorrow.", false)
	_route = RouteView.new()
	_route.custom_minimum_size = Vector2(0, 150)
	add_child(UIKit.panel("Card", _route))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = clampf(main.get_viewport_rect().size.y - 960.0, 300.0, 560.0)
	add_child(scroll)
	var body := UIKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var c := Game.ch()
	var title := UIKit.label(c["landmark_name"].to_upper(), "Header")
	_dist = UIKit.label("", "Sub")
	var desc := UIKit.wrap_label(c["desc"] + " Drones can restore it remotely once the train is in range.", "Small")
	var col := UIKit.vbox(0, [title, _dist, desc])
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(UIKit.hbox(12, [UIKit.panel("CardTeal", Icon.make(c["landmark"], 54, UIKit.TEAL)), col]))
	_stages = UIKit.vbox(8)
	body.add_child(_stages)
	if not Game.is_last_chapter():
		var nxt: Dictionary = Data.CHAPTERS[Game.chapter + 1]
		var reward := UIKit.wrap_label("Reward: the way to the %s opens (carriages up to Lv.%d, train length %d%s)." % [
			nxt["region"], nxt["level_cap"], nxt["train"], (", " + nxt["perk_text"]) if nxt["perk_text"] != "" else ""], "Small")
		reward.add_theme_color_override("font_color", UIKit.GOLD)
		body.add_child(reward)
	if c["perk_text"] != "":
		var perk := UIKit.label("Region bonus here: %s" % c["perk_text"], "Small")
		perk.add_theme_color_override("font_color", UIKit.TEAL)
		body.add_child(perk)
	_contracts = UIKit.vbox(6)
	body.add_child(_contracts)
	_goals_btn = UIKit.button("CHAPTER GOALS", "", "star", 54)
	_goals_btn.pressed.connect(func(): Popups.goals(main))
	_goals_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ach_btn = UIKit.button("ACHIEVEMENTS", "", "trophy", 54)
	_ach_btn.pressed.connect(func(): Popups.achievements(main))
	_ach_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(UIKit.hbox(8, [_goals_btn, _ach_btn]))
	_sig = ""
	_con_sig = ""


func refresh() -> void:
	_route.queue_redraw()
	var d := Game.distance
	var total := Game.landmark_distance()
	var n_st := Game.stages().size()
	if Game.chapter_done:
		_dist.text = "Restored" if Game.is_last_chapter() else "Restored · the %s lies ahead" % Data.CHAPTERS[Game.chapter + 1]["region"]
	elif d >= total:
		_dist.text = "In drone range · stage %d of %d" % [mini(Game.tower_stage + 1, n_st), n_st]
	elif Game.train_speed() <= 0.0:
		_dist.text = "%d / %d km · train stopped" % [int(d), int(total)]
	else:
		var left := (total - d) / Game.train_speed()
		_dist.text = "%d / %d km · in range in %s" % [int(d), int(total), UIKit.fmt_time(left)]
	var why := Game.stage_block_reason()
	# Affordability changes every few seconds; it is refreshed in place, not by rebuilding.
	var sig := "%d|%d|%s|%s|%s|%d" % [Game.chapter, Game.tower_stage, Game.expedition >= 0.0, Game.chapter_done, "" if why == "Not enough resources" else why, Game.survivors.size()]
	if sig != _sig:
		_sig = sig
		_build_stages()
	if is_instance_valid(_launch):
		_launch.disabled = why != ""
		_launch_reason.text = Game.stage_shortfall() if why == "Not enough resources" else why
		UIKit.clear(_launch_cost)
		_launch_cost.add_child(UIKit.cost_row(Game.stages()[mini(Game.tower_stage, n_st - 1)]["cost"], 24))
	var gl := Game.goals()
	_goals_btn.get_meta("label").text = "GOALS  %d/%d" % [mini(Game.goal_index, gl.size()), gl.size()]
	_ach_btn.get_meta("label").text = "ACHIEVEMENTS  %d/%d" % [Game.achievements.size(), Data.ACHIEVEMENTS.size()]
	_refresh_contracts()
	if _exp_bar and Game.expedition >= 0.0 and Game.tower_stage < n_st:
		var t: float = Game.stages()[Game.tower_stage]["time"]
		_exp_bar.value = 1.0 - Game.expedition / t
		_exp_time.text = UIKit.fmt_time(Game.expedition)


func _build_stages() -> void:
	UIKit.clear(_stages)
	_exp_bar = null
	_launch = null
	var sts := Game.stages()
	for i in sts.size():
		var st: Dictionary = sts[i]
		var done := i < Game.tower_stage
		var cur := i == Game.tower_stage and not Game.chapter_done
		var icon := Icon.make("check" if done else ("drone" if cur else "lock"), 28, UIKit.GREEN if done else (UIKit.GOLD if cur else UIKit.MUTED))
		var name := UIKit.label("%d. %s" % [i + 1, st["name"]], "Value" if cur else "")
		if not cur:
			name.add_theme_color_override("font_color", UIKit.GREEN if done else UIKit.MUTED)
		var col := UIKit.vbox(6, [UIKit.hbox(10, [icon, name])])
		if cur:
			col.add_child(UIKit.wrap_label(st["desc"], "Small"))
			for k in st["req"]:
				var ok: bool
				var text: String
				if k == "survivors":
					ok = Game.survivors.size() >= st["req"][k]
					text = "%d survivors aboard (%d)" % [st["req"][k], Game.survivors.size()]
				else:
					ok = Game.max_level(k) >= st["req"][k]
					text = "%s Lv.%d (have Lv.%d)" % [Data.CARRIAGES[k]["name"], st["req"][k], Game.max_level(k)]
				var l := UIKit.label(text, "Small")
				l.add_theme_color_override("font_color", UIKit.GREEN if ok else UIKit.ORANGE)
				col.add_child(UIKit.hbox(6, [Icon.make("check" if ok else "close", 18, UIKit.GREEN if ok else UIKit.ORANGE), l]))
			var range_ok := Game.distance >= Game.landmark_distance()
			var rl := UIKit.label("%s within drone range" % Game.ch()["landmark_name"], "Small")
			rl.add_theme_color_override("font_color", UIKit.GREEN if range_ok else UIKit.ORANGE)
			col.add_child(UIKit.hbox(6, [Icon.make("check" if range_ok else "close", 18, UIKit.GREEN if range_ok else UIKit.ORANGE), rl]))
			if Game.expedition >= 0.0:
				_exp_bar = UIKit.bar(0.0, UIKit.TEAL, 16)
				_exp_time = UIKit.label("", "Value")
				col.add_child(UIKit.hbox(10, [UIKit.label("Drones en route", "Accent"), _exp_bar, _exp_time]))
			else:
				_launch = UIKit.button("LAUNCH EXPEDITION", "TealButton", "drone", 58)
				main.register_target("launch", _launch)
				_launch.pressed.connect(func():
					if not Game.start_expedition():
						Audio.play("error"))
				_launch_reason = UIKit.label("", "Small")
				_launch_reason.add_theme_color_override("font_color", UIKit.ORANGE)
				_launch_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_launch_cost = UIKit.hbox(0)
				col.add_child(UIKit.hbox(10, [_launch_cost, UIKit.spacer(), _launch]))
				col.add_child(_launch_reason)
		_stages.add_child(UIKit.panel("CardTeal" if cur else "Card", col))
	if Game.chapter_done:
		if Game.is_last_chapter():
			var l := UIKit.label("HAVEN IS FOUNDED — the journey is complete. Keep growing your train!", "Accent")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_stages.add_child(UIKit.panel("CardGold", l))
		else:
			var nxt: Dictionary = Data.CHAPTERS[Game.chapter + 1]
			var l := UIKit.wrap_label("The %s is open. Depart when you are ready: the train keeps everything it has." % nxt["region"], "")
			var go := UIKit.button("DEPART FOR %s" % nxt["region"].to_upper(), "TealButton", "train", 64)
			main.register_target("depart", go)
			go.pressed.connect(func():
				if Game.advance_chapter():
					Audio.play("whistle"))
			_stages.add_child(UIKit.panel("CardGold", UIKit.vbox(8, [l, go])))


## Supply contracts: three side tasks with progress bars and CLAIM buttons.
func _refresh_contracts() -> void:
	# Contracts unlock after the first-chapter tutorial so new players see one thing at a time.
	_contracts.visible = Game.chapter > 0 or Game.goal_index >= 8
	if not _contracts.visible:
		return
	var sig := ""
	for i in Game.contracts.size():
		sig += "%s|%s;" % [Game.contracts[i].get("id", ""), Game.contract_claimable(i)]
	if sig != _con_sig:
		_con_sig = sig
		UIKit.clear(_contracts)
		_con_rows.clear()
		var head := UIKit.label("SUPPLY CONTRACTS", "Small")
		head.add_theme_color_override("font_color", UIKit.GOLD)
		_contracts.add_child(head)
		for i in Game.contracts.size():
			var c: Dictionary = Game.contracts[i]
			if c.get("id", "") == "":
				var wait := UIKit.label("", "Small")
				_contracts.add_child(UIKit.panel("Card", UIKit.hbox(10, [Icon.make("clock", 28, UIKit.MUTED), wait])))
				_con_rows.append([null, wait, null])
				continue
			var d := Game.contract_def(c["id"])
			var name := UIKit.label(Game.contract_text(c), "Value")
			var bar := UIKit.bar(0.0, UIKit.TEAL, 8)
			var prog := UIKit.label("", "Small")
			var col := UIKit.vbox(2, [name, UIKit.hbox(8, [bar, prog]), UIKit.hbox(4, [UIKit.label("Reward", "Small"), UIKit.cost_row(c["reward"], 20)])])
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var row := UIKit.hbox(10, [Icon.make(d["icon"], 36), col])
			var btn: Button = null
			if Game.contract_claimable(i):
				btn = UIKit.button("CLAIM", "GoldButton", "", 54)
				btn.custom_minimum_size.x = 110
				btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var idx := i
				btn.pressed.connect(func():
					if Game.claim_contract(idx):
						Audio.play("collect"))
				row.add_child(btn)
			_contracts.add_child(UIKit.panel("CardGold" if btn else "Card", row))
			_con_rows.append([bar, prog, btn])
	for i in _con_rows.size():
		var c: Dictionary = Game.contracts[i]
		if c.get("id", "") == "":
			_con_rows[i][1].text = "New contract in %s" % UIKit.fmt_time(c.get("ready_at", 0.0) - Game.stats["play_time"])
		else:
			var p := Game.contract_progress(c)
			_con_rows[i][0].value = p[0] / maxf(1.0, p[1])
			_con_rows[i][1].text = "%s / %s" % [UIKit.fmt(p[0]), UIKit.fmt(p[1])]


class RouteView extends Control:
	const SHORT := ["DESERT", "ASH COAST", "GLASS FLATS", "DROWNED CITY", "HIGHLANDS"]

	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.62
		var n := Data.CHAPTERS.size()
		var xs: Array = []
		for i in n:
			xs.append(lerpf(w * 0.1, w * 0.9, float(i) / (n - 1)))
		var font := UIKit.font_bold
		var cur := Game.chapter
		draw_line(Vector2(xs[0], y), Vector2(xs[n - 1], y), Color("3a3f45"), 4.0)
		# Progress inside the current chapter runs from this stop toward the next.
		var k := clampf(Game.distance / Game.landmark_distance(), 0.0, 1.0)
		var tx: float = xs[cur]
		if cur < n - 1:
			tx = lerpf(xs[cur], xs[cur + 1], 0.5 * k + (0.5 if Game.chapter_done else 0.0))
		draw_line(Vector2(xs[0], y), Vector2(tx, y), UIKit.GOLD, 4.0)
		for i in n:
			var c := Vector2(xs[i], y)
			var done := i < cur or (i == cur and Game.chapter_done)
			var here := i == cur
			var col: Color = UIKit.GREEN if done else (UIKit.GOLD if here else UIKit.MUTED)
			draw_circle(c, 24, Color("15181d"))
			draw_arc(c, 24, 0, TAU, 32, col, 3.0)
			Icon.draw_kind(self, Data.CHAPTERS[i]["landmark"] if i <= cur else "lock", Rect2(c - Vector2(15, 15), Vector2(30, 30)), col)
			var name: String = SHORT[i]
			var sz := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
			var ny := y - 38 if i % 2 == 0 else y + 46
			draw_string(font, Vector2(c.x - sz.x * 0.5, ny), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIKit.TEXT if i <= cur else UIKit.MUTED)
		# Train marker.
		var m := Vector2(tx, y - 2)
		draw_rect(Rect2(m - Vector2(12, 8), Vector2(24, 12)), UIKit.GOLD)
		draw_rect(Rect2(m - Vector2(12, 14), Vector2(6, 6)), UIKit.GOLD)
		draw_circle(m + Vector2(-6, 6), 3, Color("15181d"))
		draw_circle(m + Vector2(6, 6), 3, Color("15181d"))

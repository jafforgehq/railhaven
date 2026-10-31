class_name JourneyPanel
extends BasePanel
## Journey screen: route between regions and the chapter goal — restoring the
## Climate Tower remotely with drone expeditions that consume parts.

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
	var title := UIKit.label("CLIMATE TOWER", "Header")
	_dist = UIKit.label("", "Sub")
	var desc := UIKit.wrap_label(Data.REGIONS[1]["desc"] + " Drones can restore it remotely once the train is in range.", "Small")
	body.add_child(UIKit.hbox(12, [UIKit.panel("CardTeal", Icon.make("tower", 54, UIKit.TEAL)), UIKit.vbox(0, [title, _dist, desc])]))
	body.get_child(0).get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stages = UIKit.vbox(8)
	body.add_child(_stages)
	var reward := UIKit.wrap_label("Reward: water recovery (+25% water), new region Ash Coast (55°C, +1 cooling capacity).", "Small")
	reward.add_theme_color_override("font_color", UIKit.GOLD)
	body.add_child(reward)
	_goals_btn = UIKit.button("CHAPTER GOALS", "", "star", 54)
	_goals_btn.pressed.connect(func(): Popups.goals(main))
	body.add_child(_goals_btn)
	_sig = ""


func refresh() -> void:
	_route.queue_redraw()
	var d := Game.distance
	if Game.chapter_done:
		_dist.text = "Restored · the Ash Coast lies ahead"
	elif d >= Data.TOWER_DISTANCE:
		_dist.text = "In drone range · stage %d of %d" % [mini(Game.tower_stage + 1, 3), Data.TOWER_STAGES.size()]
	else:
		var left := (Data.TOWER_DISTANCE - d) / Game.train_speed()
		_dist.text = "%d / %d km · in range in %s" % [int(d), int(Data.TOWER_DISTANCE), UIKit.fmt_time(left)]
	var why := Game.stage_block_reason()
	# Affordability changes every few seconds; it is refreshed in place, not by rebuilding.
	var sig := "%d|%s|%s|%d" % [Game.tower_stage, Game.expedition >= 0.0, "" if why == "Not enough resources" else why, Game.survivors.size()]
	if sig != _sig:
		_sig = sig
		_build_stages()
	if is_instance_valid(_launch):
		_launch.disabled = why != ""
		_launch_reason.text = why
		UIKit.clear(_launch_cost)
		_launch_cost.add_child(UIKit.cost_row(Data.TOWER_STAGES[mini(Game.tower_stage, 2)]["cost"], 24))
	_goals_btn.get_meta("label").text = "CHAPTER GOALS  %d/%d" % [mini(Game.goal_index, Data.GOALS.size()), Data.GOALS.size()]
	if _exp_bar and Game.expedition >= 0.0 and Game.tower_stage < Data.TOWER_STAGES.size():
		var total: float = Data.TOWER_STAGES[Game.tower_stage]["time"]
		_exp_bar.value = 1.0 - Game.expedition / total
		_exp_time.text = UIKit.fmt_time(Game.expedition)


func _build_stages() -> void:
	UIKit.clear(_stages)
	_exp_bar = null
	_launch = null
	for i in Data.TOWER_STAGES.size():
		var st: Dictionary = Data.TOWER_STAGES[i]
		var done := i < Game.tower_stage
		var cur := i == Game.tower_stage
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
			var range_ok := Game.distance >= Data.TOWER_DISTANCE
			var rl := UIKit.label("Tower within drone range", "Small")
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
				_launch_cost = UIKit.hbox(0)
				col.add_child(UIKit.hbox(10, [_launch_cost, UIKit.spacer(), _launch]))
				col.add_child(_launch_reason)
		_stages.add_child(UIKit.panel("CardTeal" if cur else "Card", col))
	if Game.chapter_done:
		var l := UIKit.label("ASH COAST UNLOCKED — more of the journey arrives in Chapter 2.", "Accent")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_stages.add_child(UIKit.panel("CardGold", l))


class RouteView extends Control:
	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.62
		var xs := [w * 0.14, w * 0.5, w * 0.86]
		var names := ["DRY BASIN", "CLIMATE TOWER", "ASH COAST"]
		var icons := ["sun", "tower", "water"]
		var reached := [true, Game.distance >= Data.TOWER_DISTANCE, Game.chapter_done]
		var font := UIKit.font_bold
		# Track.
		draw_line(Vector2(xs[0], y), Vector2(xs[2], y), Color("3a3f45"), 4.0)
		var k := clampf(Game.distance / Data.TOWER_DISTANCE, 0.0, 1.0)
		var tx: float = lerpf(xs[0], xs[1], k)
		if Game.chapter_done:
			tx = lerpf(xs[1], xs[2], 0.25)
		draw_line(Vector2(xs[0], y), Vector2(tx, y), UIKit.GOLD, 4.0)
		for i in 3:
			var c := Vector2(xs[i], y)
			var col: Color = UIKit.GREEN if reached[i] else (UIKit.GOLD if i == 1 else UIKit.MUTED)
			draw_circle(c, 26, Color("15181d"))
			draw_arc(c, 26, 0, TAU, 32, col, 3.0)
			Icon.draw_kind(self, icons[i] if (i < 2 or Game.chapter_done) else "lock", Rect2(c - Vector2(16, 16), Vector2(32, 32)), col)
			var sz := font.get_string_size(names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
			draw_string(font, Vector2(c.x - sz.x * 0.5, y - 40), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIKit.TEXT if reached[i] or i == 1 else UIKit.MUTED)
			var st := "COMPLETE" if reached[i] and (i == 0 or i == 1 and Game.chapter_done) else ("%d%%" % int(k * 100) if i == 1 else ("UNLOCKED" if reached[i] else "LOCKED"))
			if i == 1 and k >= 1.0 and not Game.chapter_done:
				st = "RESTORING %d/3" % Game.tower_stage
			var s2 := font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
			draw_string(font, Vector2(c.x - s2.x * 0.5, y + 48), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		# Train marker.
		var m := Vector2(tx, y - 2)
		draw_rect(Rect2(m - Vector2(12, 8), Vector2(24, 12)), UIKit.GOLD)
		draw_rect(Rect2(m - Vector2(12, 14), Vector2(6, 6)), UIKit.GOLD)
		draw_circle(m + Vector2(-6, 6), 3, Color("15181d"))
		draw_circle(m + Vector2(6, 6), 3, Color("15181d"))

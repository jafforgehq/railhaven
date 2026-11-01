class_name ResearchPanel
extends BasePanel
## Research sheet: data stock, the project running now, and the projects to pick from.
## One project runs at a time; finished projects are permanent train-wide bonuses.

var _data: Label
var _rate: Label
var _run_box: VBoxContainer
var _run_bar: ProgressBar
var _run_time: Label
var _list: VBoxContainer
var _rows := {} # id -> [button, reason label]
var _sig := ""


func build() -> void:
	header("flask", "RESEARCH", "Scientists in the Research Lab gather data. Spend it on permanent upgrades.")
	_data = UIKit.label("", "Value")
	_data.add_theme_font_size_override("font_size", 28)
	_rate = UIKit.label("", "Small")
	var col := UIKit.vbox(-2, [_data, _rate])
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UIKit.panel("Card", UIKit.hbox(12, [Icon.make("data", 44), col])))
	_run_box = UIKit.vbox(6)
	add_child(_run_box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = clampf(main.get_viewport_rect().size.y - 1000.0, 260.0, 520.0)
	add_child(scroll)
	_list = UIKit.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_sig = ""


func refresh() -> void:
	var r := Game.rates()
	_data.text = "Data %s / %s" % [UIKit.fmt(Game.res["data"]), UIKit.fmt(Game.storage("data"))]
	_rate.text = "%s · lab speed x%.2f" % [UIKit.fmt_rate(r["data"]), Game.research_speed()] if Game.count_type("lab") > 0 else "Build a Research Lab to gather data"
	var sig := "%s|%d|%d|%d" % [Game.research_id, Game.research_done.size(), Game.chapter, Game.count_type("lab")]
	if sig != _sig:
		_sig = sig
		_build_running()
		_build_list()
	if _run_bar and Game.research_id != "":
		var d := Game.research_def(Game.research_id)
		_run_bar.value = 1.0 - Game.research_left / float(d["time"])
		_run_time.text = UIKit.fmt_time(Game.research_left / Game.research_speed())
	for id in _rows:
		var why := Game.research_block_reason(id)
		_rows[id][0].disabled = why != ""
		_rows[id][1].text = "" if why == "" or why == "Another project is running" else why


func _build_running() -> void:
	UIKit.clear(_run_box)
	_run_bar = null
	if Game.research_id == "":
		return
	var d := Game.research_def(Game.research_id)
	_run_bar = UIKit.bar(0.0, UIKit.TEAL, 14)
	_run_time = UIKit.label("", "Value")
	var name := UIKit.label("Researching: %s" % d["name"], "Accent")
	var col := UIKit.vbox(4, [name, UIKit.label(d["text"], "Small"), UIKit.hbox(10, [_run_bar, _run_time])])
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_box.add_child(UIKit.panel("CardTeal", UIKit.hbox(12, [Icon.make(d["icon"], 40, UIKit.TEAL), col])))


func _build_list() -> void:
	UIKit.clear(_list)
	_rows.clear()
	var first := true
	for d in Game.research_list():
		if Game.research_done.has(d["id"]) or d["id"] == Game.research_id:
			continue
		var name := UIKit.label(d["name"], "Value")
		var text := UIKit.label(d["text"], "Small")
		text.add_theme_color_override("font_color", UIKit.TEAL)
		var info := UIKit.hbox(8, [UIKit.cost_row(d["cost"], 22), Icon.make("clock", 18, UIKit.MUTED), UIKit.label(UIKit.fmt_time(d["time"] / Game.research_speed()), "Small")])
		var reason := UIKit.label("", "Small")
		reason.add_theme_color_override("font_color", UIKit.ORANGE)
		var col := UIKit.vbox(2, [name, text, info, reason])
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn := UIKit.button("START", "TealButton", "", 56)
		btn.custom_minimum_size.x = 120
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var id: String = d["id"]
		btn.pressed.connect(func():
			if not Game.start_research(id):
				Audio.play("error"))
		_list.add_child(UIKit.panel("Card", UIKit.hbox(12, [Icon.make(d["icon"], 40), col, btn])))
		_rows[id] = [btn, reason]
		if first:
			main.register_target("research_start", btn)
			first = false
	var later := Data.RESEARCH.size() - Game.research_list().size()
	var done := Game.research_done.size()
	var foot: PackedStringArray = []
	if done > 0:
		foot.append("%d project%s finished" % [done, "" if done == 1 else "s"])
	if later > 0:
		foot.append("%d more unlock in later regions" % later)
	if not foot.is_empty():
		_list.add_child(UIKit.label(" · ".join(foot), "Small"))

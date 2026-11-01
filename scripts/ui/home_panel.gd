class_name HomePanel
extends VBoxContainer
## Home sheet under the train: the region's restoration progress, the next task with its
## RESTORE button, Condenser / boosters / daily drop shortcuts and the big PLAY button.

var main: Node
var _region: Label
var _progress: ProgressBar
var _progress_text: Label
var _task_icon: Icon
var _task_text: Label
var _task_cost: Label
var _task_hint: Label
var _cost_icon: Icon
var _restore: Button
var _cond: Button
var _shop: Button
var _daily: Button
var _play: Button
var _play_sub: Label
var _region_icon: Icon


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_region_icon = Icon.make("tower", 34, UIKit.TEAL)
	_region = UIKit.label("", "Header")
	_progress = UIKit.bar(0.0, UIKit.TEAL, 10)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_text = UIKit.label("", "Small")
	var head := UIKit.vbox(2, [_region, UIKit.hbox(8, [_progress, _progress_text])])
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UIKit.hbox(10, [UIKit.panel("CardTeal", _region_icon), head]))

	_task_icon = Icon.make("home", 44)
	_task_text = UIKit.label("", "Value")
	_task_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_cost = UIKit.label("", "Value")
	_task_hint = UIKit.label("", "Small")
	_cost_icon = Icon.make("parts", 24)
	var col := UIKit.vbox(0, [_task_text, UIKit.hbox(6, [_cost_icon, _task_cost, _task_hint])])
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restore = UIKit.button("RESTORE", "GoldButton", "hammer", 62)
	_restore.custom_minimum_size.x = 190
	_restore.pressed.connect(_on_restore)
	main.register_target("restore", _restore)
	add_child(UIKit.panel("CardGold", UIKit.hbox(10, [_task_icon, col, _restore])))

	_cond = UIKit.button("CONDENSER", "", "condenser", 58)
	_shop = UIKit.button("BOOSTERS", "", "tank", 58)
	_daily = UIKit.button("DAILY", "", "gift", 58)
	for b in [_cond, _shop, _daily]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cond.pressed.connect(func():
		if Game.has_condenser():
			Popups.condenser(main)
		else:
			main.show_toast("Couple the Condenser to earn scrap while you are away", "info"))
	_shop.pressed.connect(func(): Popups.shop(main))
	_daily.pressed.connect(func(): MetaPopups.calendar(main))
	add_child(UIKit.hbox(8, [_cond, _shop, _daily]))

	_play = UIKit.button("LEVEL 1", "TealButton", "play", 84)
	(_play.get_meta("label") as Label).add_theme_font_size_override("font_size", 36)
	_play.pressed.connect(func():
		if Game.lives <= 0:
			Popups.out_of_lives(main)
		else:
			MetaPopups.pre_level(main))
	main.register_target("play", _play)
	_play_sub = UIKit.label("", "Small", HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UIKit.vbox(2, [_play, _play_sub]))
	refresh()


func refresh() -> void:
	var r := Game.region()
	var n: int = r["tasks"].size()
	_region.text = "%s · %s" % [r["region"].to_upper(), r["landmark_name"]]
	_region_icon.kind = r["landmark"]
	_progress.value = float(Game.task_index) / n
	_progress_text.text = "%d/%d restored" % [mini(Game.task_index, n), n]
	if Game.region_done:
		_task_icon.kind = r["landmark"]
		if Game.is_last_region():
			_task_text.text = "Haven is founded! The journey is complete."
			_restore.visible = false
		else:
			_task_text.text = "%s restored. The %s awaits." % [r["landmark_name"], Data.REGIONS[Game.region_index + 1]["region"]]
			_restore.visible = true
			_restore.disabled = false
			_restore.get_meta("label").text = "DEPART"
		_task_cost.text = ""
		_task_hint.text = ""
		_cost_icon.visible = false
	else:
		var t := Game.current_task()
		_task_icon.kind = r["landmark"] if t.get("landmark", false) else Data.CARRIAGES[t["type"]]["icon"]
		_task_text.text = t["text"]
		_cost_icon.visible = true
		_task_cost.text = "%d / %d" % [mini(Game.parts, int(t["cost"])), int(t["cost"])]
		var why := Game.task_block_reason()
		_task_hint.text = "  win levels to earn parts" if why != "" else "  ready!"
		_task_hint.add_theme_color_override("font_color", UIKit.MUTED if why != "" else UIKit.GREEN)
		_restore.visible = true
		_restore.disabled = why != ""
		_restore.get_meta("label").text = "RESTORE"
	var amount := Game.condenser_amount()
	_cond.get_meta("label").text = ("FULL %d" % amount) if Game.condenser_full() else ("+%d" % amount if Game.condenser_ready() else "CONDENSER")
	if not Game.has_condenser():
		_cond.get_meta("label").text = "LOCKED"
	_cond.modulate.a = 1.0 if Game.has_condenser() else 0.55
	_cond.theme_type_variation = "GreenButton" if Game.condenser_ready() else ""
	_daily.get_meta("label").text = "DAILY" if Meta.cal_ready() else UIKit.fmt_time(Meta.cal_in())
	_daily.theme_type_variation = "GreenButton" if Meta.cal_ready() else ""
	var hard := Game.is_hard(Game.level)
	_play.get_meta("label").text = "LEVEL %d" % Game.level
	_play.theme_type_variation = "RedButton" if hard else "TealButton"
	if Game.lives <= 0:
		_play_sub.text = "No lives · next in %s" % UIKit.fmt_time(Game.next_life_in())
		_play_sub.add_theme_color_override("font_color", UIKit.RED)
	elif hard:
		_play_sub.text = "HEATWAVE LEVEL · double parts"
		_play_sub.add_theme_color_override("font_color", UIKit.RED)
	elif Meta.streak() > 0:
		_play_sub.text = "Lives %d/%d · win streak %d" % [Game.lives, Data.MAX_LIVES, Meta.streak()]
		_play_sub.add_theme_color_override("font_color", UIKit.ORANGE)
	else:
		_play_sub.text = "Lives %d/%d" % [Game.lives, Data.MAX_LIVES]
		_play_sub.add_theme_color_override("font_color", UIKit.MUTED)


func _on_restore() -> void:
	if Game.region_done:
		if Game.advance_region():
			Audio.play("whistle")
		return
	var t := Game.current_task()
	if Game.complete_task():
		Audio.play("build")
	else:
		Audio.play("error")
		main.show_toast("Need %d parts. Win levels to earn them." % int(t.get("cost", 0)), "info")

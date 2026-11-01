extends Control
## UI root (CanvasLayer 1) over the World node. Two modes: Home (top bar, train, home sheet
## with RESTORE and PLAY) and Puzzle (a PuzzleScreen over the train). Modals, toasts and the
## coach pointer sit on top of both.

var world: World
var overlay: Control
var hud: HUD
var home_host: PanelContainer
var home: HomePanel
var puzzle: PuzzleScreen
var modal_layer: Control
var toasts: VBoxContainer
var coach: Coach
var targets := {} # name -> Control the coach can point at
var mode := "home"
var _plates := {}
var _modal_stack: Array[Control] = []
var _home_root: Control
var story: StoryBubble
var rail: VBoxContainer # event / album buttons down the right edge (home)
var _rail_btns := {}
var _pending_events: Array = [] # event results shown once the player is home
var _last_band_bottom := -1.0
var _refresh_accum := 0.0


func _ready() -> void:
	Icon.preload_art()
	theme = UIKit.build_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	world = get_node("../../World")
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	_home_root = Control.new()
	_home_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_home_root)
	hud = HUD.new()
	hud.main = self
	_home_root.add_child(hud)
	_build_home_sheet()
	story = StoryBubble.new()
	_home_root.add_child(story)
	rail = UIKit.vbox(8)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_root.add_child(rail)
	_rail_button("rescue", "warning", "RESCUE!", func(): play_rescue())
	_rail_button("run", "streak", "HEAT RUN", func(): MetaPopups.heat_run(self))
	_rail_button("race", "flag", "RACE", func(): MetaPopups.race(self))
	_rail_button("album", "card", "ALBUM", func(): MetaPopups.album(self))

	toasts = UIKit.vbox(6)
	toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toasts.offset_top = 230
	toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)
	coach = Coach.new()
	add_child(coach)
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)

	Game.changed.connect(_on_changed)
	Game.toast.connect(show_toast)
	Game.carriage_built.connect(func(uid): _on_restored(uid, true))
	Game.carriage_upgraded.connect(func(uid): _on_restored(uid, false))
	Game.carriage_built.connect(func(uid): say("built_" + Game.carriage(uid).get("type", "")))
	Game.carriage_upgraded.connect(func(_uid): say("upgraded"))
	Game.region_started.connect(func(i): say("region_%d" % i))
	Game.region_complete.connect(func(): say("landmark"))
	Meta.event_result.connect(func(kind, info): _pending_events.append([kind, info]))
	Game.region_complete.connect(_on_region_complete)
	Game.region_started.connect(func(_i): world.on_region_started(); _rebuild_plates(); _refresh())
	world.tapped_carriage.connect(func(uid):
		if mode == "home" and _modal_stack.is_empty():
			Popups.carriage_info(self, uid))
	world.tapped_ghost.connect(func():
		if mode == "home" and _modal_stack.is_empty():
			if Game.task_block_reason() == "":
				home._on_restore()
			else:
				show_toast("%s: win levels to earn parts (%d/%d)" % [Game.current_task()["text"], Game.parts, int(Game.current_task()["cost"])], "info"))
	world.float_text.connect(_float_text)
	get_viewport().size_changed.connect(_layout)

	_rebuild_plates()
	show_home()
	if OS.is_debug_build() and OS.get_cmdline_user_args().size() > 0:
		add_child(preload("res://scripts/debug/shots.gd").new())
	Audio.play_music("theme")
	say.call_deferred("intro")
	if not Game.intro_seen:
		Popups.how_to_play.call_deferred(self)
	elif Game.region_done and not Game.region_seen:
		_on_region_complete.call_deferred()
	elif Game.condenser_ready() and Game.condenser_seconds() >= 3600.0:
		Popups.condenser.call_deferred(self) # welcome back: the Condenser filled up while away


func _build_home_sheet() -> void:
	var bottom := UIKit.vbox(0)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_root.add_child(bottom)
	home_host = UIKit.panel("")
	home_host.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom.add_child(home_host)
	var m := MarginContainer.new()
	for side in ["left", "right", "top"]:
		m.add_theme_constant_override("margin_" + side, 14)
	m.add_theme_constant_override("margin_bottom", 14 + int(safe_bottom()))
	home_host.add_child(m)
	home = HomePanel.new()
	home.main = self
	m.add_child(home)


func safe_top() -> float:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0 or OS.has_feature("pc"):
		return 0.0
	return maxf(0.0, safe.position.y * get_viewport_rect().size.y / float(win.y))


func safe_bottom() -> float:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0 or OS.has_feature("pc"):
		return 0.0
	return maxf(0.0, (win.y - safe.end.y) * get_viewport_rect().size.y / float(win.y))


# ---------------------------------------------------------------- modes

func show_home() -> void:
	mode = "home"
	if puzzle:
		puzzle.queue_free()
		puzzle = null
	Game.heat_visual = 0.0
	world.heat_uid = 0
	_home_root.visible = true
	overlay.visible = true
	coach.point(Vector2.ZERO, "")
	_refresh()
	_layout.call_deferred()
	world.focus(_focus_uid())


## Starts the next level (or the region's landmark boss). `pre` = pre-level boosters picked on
## the start popup (paid here).
func play(pre: Array = [], boss := false) -> void:
	if Game.lives <= 0:
		Popups.out_of_lives(self)
		return
	var paid := Meta.take_pre(pre)
	if not paid["ok"]:
		show_toast("Not enough scrap for those boosters", "warn")
		return
	mode = "puzzle"
	coach.point(Vector2.ZERO, "")
	_home_root.visible = false
	overlay.visible = false
	puzzle = PuzzleScreen.new()
	puzzle.main = self
	add_child(puzzle)
	move_child(puzzle, toasts.get_index())
	puzzle.start(Game.level, paid["apply"], boss)
	var uid := _focus_uid(true)
	world.heat_uid = uid
	world.focus(uid)
	Audio.play("ui_open")


## Pull-the-pin rescue mission: runs over the whole screen, no lives at stake.
func play_rescue() -> void:
	if not Meta.rescue_pending():
		return
	mode = "rescue"
	coach.point(Vector2.ZERO, "")
	_home_root.visible = false
	overlay.visible = false
	var game := RescueGame.new()
	game.main = self
	game.layout = Meta.rescue_index()
	add_child(game)
	move_child(game, toasts.get_index())
	game.finished.connect(func(won: bool):
		game.queue_free()
		show_home()
		if won:
			Meta.rescue_won()
			Audio.play("goal_complete")
			show_toast("Crew rescued! %s" % Meta.reward_text(Meta.RESCUE_REWARD), "good")
			world.pet.cheer()
		else:
			show_toast("The rescue is still waiting. Try again any time.", "info"))
	Audio.play("alarm", 0.1)


## The carriage the next task is about (or a random carriage to cool). At home a carriage
## still being assembled is the ghost (-1); a puzzle always heats a real carriage.
func _focus_uid(for_heat := false) -> int:
	if not for_heat and Game.next_build() != "":
		return -1
	var t := Game.current_task()
	if not t.is_empty() and t.has("type"):
		var c := Game.first_of(t["type"])
		if not c.is_empty():
			return c["uid"]
	var pool := Game.carriages.filter(func(c): return c["type"] != "locomotive")
	if pool.is_empty():
		return Game.carriages[0]["uid"]
	return pool[Game.level % pool.size()]["uid"]


func _layout() -> void:
	if mode == "home" and home_host:
		world.set_band(hud.band_top() + safe_top() * 0.0, home_host.get_global_rect().position.y)
		var vp := get_viewport_rect().size
		story.size = Vector2(vp.x - 32.0, 0)
		story.size = story.get_combined_minimum_size().max(Vector2(vp.x - 32.0, 0))
		story.position = Vector2(16, home_host.get_global_rect().position.y - story.size.y - 10.0)
		rail.size = rail.get_combined_minimum_size()
		rail.position = Vector2(vp.x - rail.size.x - 10.0, hud.band_top() + 10.0)


## Juno says the story line for an event (if she has something new to say).
func say(key: String) -> void:
	story.say(Meta.story_line(key))


func _rail_button(id: String, icon: String, text: String, on_press: Callable) -> void:
	var b := UIKit.button("", "", icon, 76)
	b.custom_minimum_size = Vector2(80, 76)
	b.pressed.connect(on_press)
	var l := UIKit.label(text, "Small", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	rail.add_child(UIKit.vbox(0, [b, l]))
	_rail_btns[id] = [b, l]


func _process(delta: float) -> void:
	if mode == "home" and home_host:
		var bottom := home_host.get_global_rect().position.y
		if not is_equal_approx(bottom, _last_band_bottom):
			_last_band_bottom = bottom
			_layout()
		_refresh_accum += delta
		if _refresh_accum >= 0.5:
			_refresh_accum = 0.0
			_refresh()
		_update_plates()
		_update_coach()


func _refresh() -> void:
	hud.refresh()
	home.refresh()
	_refresh_rail()
	if mode == "home" and _modal_stack.is_empty() and not _pending_events.is_empty():
		var e: Array = _pending_events.pop_front()
		MetaPopups.event_result(self, e[0], e[1])


func _refresh_rail() -> void:
	var run := Meta.run()
	_rail_btns["run"][0].get_parent().visible = Meta.run_open()
	_rail_btns["run"][1].text = ("RUN %d/%d" % [int(run["wins"]), Meta.RUN_STEPS]) if run["state"] == "running" else ("JOIN!" if Meta.run_can_join() else "HEAT RUN")
	_rail_btns["race"][0].get_parent().visible = Meta.race_open()
	if Meta.race_open():
		_rail_btns["race"][1].text = "RACE #%d" % Meta.race_rank()
	_rail_btns["album"][1].text = "ALBUM %d" % Meta.cards().size()
	var rescue_was: bool = _rail_btns["rescue"][0].get_parent().visible
	_rail_btns["rescue"][0].get_parent().visible = Meta.rescue_pending()
	if Meta.rescue_pending() and not rescue_was:
		say("rescue")


func _on_changed() -> void:
	if mode == "home":
		_refresh()


func _on_restored(uid: int, built: bool) -> void:
	if built and Game.carriage(uid).get("type", "") == "condenser":
		show_toast("Condenser online: it now earns scrap while you are away", "good")
	if built:
		# Pick a paint style once the new carriage has landed.
		get_tree().create_timer(1.1).timeout.connect(func():
			if mode == "home" and _modal_stack.is_empty():
				MetaPopups.livery(self, uid))
	_rebuild_plates()
	world.celebrate(uid, built)
	_refresh()


func _on_region_complete() -> void:
	Audio.play_music("tower_restored")
	world.on_region_restored()
	Popups.region_complete(self)


# ---------------------------------------------------------------- coach (home)

func _update_coach() -> void:
	if not _modal_stack.is_empty():
		coach.point(Vector2.ZERO, "")
		return
	var text := ""
	var pos := Vector2(-1, -1)
	var can_restore := not Game.region_done and Game.task_block_reason() == ""
	if can_restore and Game.task_index < 4 and Game.region_index == 0:
		pos = _target_pos("restore")
		text = "You have enough parts. Grow the train!"
	elif Game.level <= 3 and Game.lives > 0 and not can_restore:
		pos = _target_pos("play")
		text = "Play a level to cool the train and earn parts"
	if pos.x < 0:
		coach.point(Vector2.ZERO, "")
	else:
		coach.point(pos, text)


func register_target(name: String, control: Control) -> void:
	targets[name] = control


func _target_pos(name: String) -> Vector2:
	var c: Control = targets.get(name)
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return Vector2(-1, -1)
	var r := c.get_global_rect()
	return Vector2(r.get_center().x, r.position.y)


# ---------------------------------------------------------------- name plates

func _rebuild_plates() -> void:
	for p in _plates.values():
		p.queue_free()
	_plates.clear()
	var uids: Array = Game.carriages.map(func(c): return c["uid"])
	if Game.next_build() != "":
		uids.append(-1) # the ghost of the carriage being assembled
	for uid in uids:
		var type: String = Game.next_build() if uid == -1 else Game.carriage(uid)["type"]
		var plate := UIKit.panel("Chip")
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := Icon.make(Data.CARRIAGES[type]["icon"], 20, UIKit.TEAL)
		var name := UIKit.label("", "Small")
		name.add_theme_color_override("font_color", UIKit.TEXT)
		plate.add_child(UIKit.hbox(6, [icon, name]))
		plate.set_meta("name", name)
		overlay.add_child(plate)
		_plates[uid] = plate


func _update_plates() -> void:
	var w := get_viewport_rect().size.x
	for uid in _plates:
		var plate: PanelContainer = _plates[uid]
		var c := Game.carriage(uid)
		if uid == -1:
			c = {"type": Game.next_build(), "level": 0}
		if c.is_empty() or c["type"] == "":
			plate.visible = false
			continue
		var center := world.carriage_center(uid)
		var sp: Vector2 = world.world_to_screen(Vector2(center.x, -112.0))
		var nm: Label = plate.get_meta("name")
		var d: Dictionary = Data.CARRIAGES[c["type"]]
		var t := Game.current_task()
		var target: bool = t.get("type", "") == c["type"] and not Game.region_done
		var cost := int(t.get("cost", 0))
		if target:
			# The carriage the next task builds or upgrades shows the parts collected for it.
			var lv := "NEW" if uid == -1 else "UPGRADE"
			nm.text = "%s %s · %d/%d" % [d["name"], lv, mini(Game.parts, cost), cost]
			nm.add_theme_color_override("font_color", UIKit.GOLD if Game.parts >= cost else UIKit.TEXT)
		elif c["type"] == "condenser" and Game.condenser_ready():
			nm.text = "%s · +%d" % [d["name"], Game.condenser_amount()]
			nm.add_theme_color_override("font_color", UIKit.GREEN)
		else:
			nm.text = d["name"] if c["type"] == "locomotive" else "%s Lv.%d" % [d["name"], c["level"]]
			nm.add_theme_color_override("font_color", UIKit.TEXT)
		plate.size = plate.get_combined_minimum_size()
		plate.position = (sp - Vector2(plate.size.x * 0.5, 0)).round()
		plate.visible = sp.x > -plate.size.x and sp.x < w + plate.size.x and sp.y > hud.band_top() - 20


func _float_text(world_pos: Vector2, text: String, color: Color) -> void:
	var l := UIKit.label(text, "Value")
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	move_child(l, toasts.get_index())
	l.position = world.world_to_screen(world_pos) - Vector2(40, 0)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- toasts and modals

func show_toast(text: String, kind := "info") -> void:
	var col: Color = {"good": UIKit.GREEN, "warn": UIKit.ORANGE, "bad": UIKit.RED}.get(kind, UIKit.TEAL)
	var p := UIKit.panel("Overlay")
	var icon := "check" if kind == "good" else ("warning" if kind in ["warn", "bad"] else "star")
	var l := UIKit.label(text, "")
	l.add_theme_font_size_override("font_size", 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 420
	p.add_child(UIKit.hbox(8, [Icon.make(icon, 22, col), l]))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(p)
	while toasts.get_child_count() > 2:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func open_modal(content: Control, dismissable := true) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	center.add_child(content)
	if dismissable:
		dim.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and not content.get_global_rect().has_point(e.global_position):
				close_modal(dim))
	_modal_stack.append(dim)
	dim.set_meta("content", content)
	dim.modulate.a = 0.0
	content.pivot_offset = content.get_combined_minimum_size() * 0.5
	content.scale = Vector2(0.92, 0.92)
	var tw := dim.create_tween().set_parallel()
	tw.tween_property(dim, "modulate:a", 1.0, 0.18)
	tw.tween_property(content, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("ui_open")
	if puzzle:
		puzzle.view.locked = true
	return dim


func close_modal(dim: Control = null) -> void:
	if dim == null:
		if _modal_stack.is_empty():
			return
		dim = _modal_stack.back()
	_modal_stack.erase(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := dim.create_tween()
	tw.tween_property(dim, "modulate:a", 0.0, 0.15)
	tw.tween_callback(dim.queue_free)
	if puzzle and _modal_stack.is_empty() and not puzzle.finished and puzzle.heat < Data.HEAT_MAX:
		puzzle.view.locked = false


func close_modal_of(content: Control) -> void:
	for d in _modal_stack:
		if d.get_meta("content") == content:
			close_modal(d)
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not _modal_stack.is_empty():
			close_modal()
		elif mode == "puzzle" and puzzle:
			puzzle._on_back()
		else:
			Game.save_game()
			get_tree().quit()

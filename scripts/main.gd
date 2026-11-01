extends Control
## UI root (CanvasLayer 1) over the World node: HUD, contextual bottom panels, modals.
## Screens: Train / Crew / Journey (bottom nav). Panels refresh in place on Game.changed.

var world: World
var overlay: Control
var hud: HUD
var panel_host: PanelContainer
var nav: HBoxContainer
var modal_layer: Control
var toasts: VBoxContainer

var tab := "train"
var current: BasePanel
var _tab_buttons := {}
var _plates := {}
var _modal_stack: Array[Control] = []
var _last_band_bottom := -1.0
var coach: Coach
var targets := {} # name -> Control the coach can point at
var _go_boost := 0.0
const TUTORIAL_GOALS := 8 # the pointer guides these goals without being asked


func _ready() -> void:
	Icon.preload_art()
	theme = UIKit.build_theme()
	_build_world()
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	hud = HUD.new()
	hud.main = self
	add_child(hud)
	_build_bottom()
	toasts = UIKit.vbox(6)
	toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toasts.offset_top = 300
	toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(toasts)
	coach = Coach.new()
	add_child(coach)
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)

	Game.changed.connect(_on_changed)
	Game.toast.connect(show_toast)
	Game.goal_completed.connect(_on_goal_completed)
	Game.event_started.connect(_on_event_started)
	Game.event_ended.connect(func(_id): _refresh_now())
	Game.chapter_complete.connect(_on_chapter_complete)
	Game.chapter_started.connect(_on_chapter_started)
	Game.research_finished.connect(func(_id): Audio.play("goal_complete"); _refresh_panel(true))
	Game.crew_leveled.connect(func(_s, _l): Audio.play("upgrade"))
	Game.offline_report.connect(_on_offline_report)
	Game.carriage_built.connect(func(_u): _rebuild_plates(); _refresh_panel(true))
	Game.carriage_upgraded.connect(func(_u): _refresh_panel(true))
	Game.survivor_joined.connect(func(_n): _refresh_panel(); Audio.play("collect"))
	Game.expedition_started.connect(func(_s): Audio.play("drone_launch"); _refresh_panel())
	Game.expedition_done.connect(func(_s): Audio.play("goal_complete"); _refresh_panel())
	world.tapped_carriage.connect(_on_tap_carriage)
	world.tapped_ghost.connect(func(): open_build())
	world.tapped_empty.connect(func():
		if tab == "train" and not (current is OverviewPanel):
			show_train_overview())
	world.float_text.connect(_float_text)
	get_viewport().size_changed.connect(_layout)

	_rebuild_plates()
	set_tab("train")
	if OS.is_debug_build() and OS.get_cmdline_user_args().size() > 0:
		add_child(preload("res://scripts/debug/shots.gd").new())
	Audio.play_music("theme")
	_layout.call_deferred()
	if not Game.pending_report.is_empty():
		_on_offline_report.call_deferred(Game.pending_report)
	if not Game.intro_seen:
		Popups.how_to_play.call_deferred(self)
	if Game.chapter_done and not Game.chapter_seen:
		_on_chapter_complete.call_deferred()


## World is a sibling in the scene (canvas layer 0, camera-driven); taps the GUI does not
## consume fall through to World._unhandled_input.
func _build_world() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	world = get_node("../../World")


func _build_bottom() -> void:
	var bottom := UIKit.vbox(0)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var pm := MarginContainer.new()
	for side in ["left", "right"]:
		pm.add_theme_constant_override("margin_" + side, 10)
	pm.add_theme_constant_override("margin_bottom", 8)
	pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(pm)
	panel_host = PanelContainer.new()
	panel_host.mouse_filter = Control.MOUSE_FILTER_STOP
	pm.add_child(panel_host)

	var nav_bg := UIKit.panel("Bar")
	nav_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom.add_child(nav_bg)
	var nm := MarginContainer.new()
	for side in ["left", "right", "top"]:
		nm.add_theme_constant_override("margin_" + side, 10)
	nm.add_theme_constant_override("margin_bottom", 12 + _safe_bottom())
	nav_bg.add_child(nm)
	nav = UIKit.hbox(10)
	nm.add_child(nav)
	var group := ButtonGroup.new()
	for d in [["train", "TRAIN", "Build · Upgrade", "train"], ["crew", "CREW", "Survivors · Jobs", "crew"], ["journey", "JOURNEY", "Route · Landmark", "map"]]:
		var b := Button.new()
		b.theme_type_variation = "TabButton"
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := UIKit.hbox(10, [Icon.make(d[3], 34, UIKit.TEXT), UIKit.vbox(-4, [UIKit.label(d[1], "Header"), UIKit.label(d[2], "Small")])])
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(inner)
		var dot := ColorRect.new()
		dot.color = UIKit.RED
		dot.size = Vector2(12, 12)
		dot.position = Vector2(12, 10)
		dot.visible = false
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
		b.set_meta("dot", dot)
		b.set_meta("inner", inner)
		var id: String = d[0]
		b.pressed.connect(func():
			Audio.play("ui_click")
			set_tab(id))
		nav.add_child(b)
		_tab_buttons[id] = b
		targets["tab_" + id] = b


func _safe_bottom() -> int:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.y <= 0 or safe.size.y <= 0:
		return 0
	var scale := get_viewport_rect().size.y / float(win.y)
	return int(maxf(0.0, (win.y - safe.end.y) * scale))


# ---------------------------------------------------------------- tabs and panels

func set_tab(id: String) -> void:
	tab = id
	_tab_buttons[id].button_pressed = true
	for k in _tab_buttons:
		var inner: Control = _tab_buttons[k].get_meta("inner")
		inner.modulate = UIKit.GOLD if k == id else Color(0.75, 0.78, 0.8)
	match id:
		"train": show_train_overview()
		"crew": _show(CrewPanel.new())
		"journey": _show(JourneyPanel.new())


func _show(p: BasePanel) -> void:
	if current:
		panel_host.remove_child(current)
		current.queue_free()
	current = p
	p.main = self
	panel_host.add_child(p)
	p.build()
	p.refresh()
	if not (p is CarriagePanel):
		world.set_selected(0)
	_layout.call_deferred()


func show_train_overview() -> void:
	if tab != "train":
		tab = "train"
		_tab_buttons["train"].button_pressed = true
	_show(OverviewPanel.new())


func open_carriage(uid: int) -> void:
	if tab != "train":
		set_tab("train")
	var p := CarriagePanel.new()
	p.uid = uid
	_show(p)
	world.set_selected(uid)
	world.focus(uid)
	Audio.play("ui_open")


func open_build() -> void:
	if tab != "train":
		set_tab("train")
	_show(BuildPanel.new())
	world.set_selected(-1)
	world.focus(-1)
	Audio.play("ui_open")


func open_research() -> void:
	if tab != "train":
		set_tab("train")
	_show(ResearchPanel.new())
	var lab := Game.first_of("lab")
	if not lab.is_empty():
		world.set_selected(lab["uid"])
		world.focus(lab["uid"])
	Audio.play("ui_open")


func _on_tap_carriage(uid: int) -> void:
	if current is CarriagePanel and current.uid == uid:
		show_train_overview()
		return
	open_carriage(uid)


func _refresh_panel(structural := false) -> void:
	if current == null:
		return
	if structural:
		current.rebuild()
	current.refresh()


func _refresh_now() -> void:
	_on_changed()


func _on_changed() -> void:
	hud.refresh()
	if current:
		current.refresh()
	# Nav badges.
	var idle := Game.idle_survivors().size()
	var open_slots := 0
	for c in Game.carriages:
		open_slots += maxi(0, Game.free_slots(c["uid"]))
	_tab_buttons["crew"].get_meta("dot").visible = idle > 0 and open_slots > 0
	_tab_buttons["journey"].get_meta("dot").visible = Game.stage_block_reason() == ""
	for m in _modal_stack:
		if m.has_method("refresh"):
			m.refresh()


func _layout() -> void:
	if panel_host == null or world == null:
		return
	world.set_band(hud.band_top(), panel_host.get_global_rect().position.y)


# ---------------------------------------------------------------- world overlay

func _rebuild_plates() -> void:
	for p in _plates.values():
		p.queue_free()
	_plates.clear()
	for c in Game.carriages:
		var plate := UIKit.panel("Chip")
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := Icon.make(Data.CARRIAGES[c["type"]]["icon"], 20, UIKit.TEAL)
		var name := UIKit.label("", "Small")
		name.add_theme_color_override("font_color", UIKit.TEXT)
		var extra := UIKit.label("", "Small")
		plate.add_child(UIKit.hbox(6, [icon, name, extra]))
		plate.set_meta("name", name)
		plate.set_meta("extra", extra)
		overlay.add_child(plate)
		_plates[c["uid"]] = plate


func _process(_delta: float) -> void:
	if world == null:
		return
	# Sheet height changes with content; keep the camera band in sync every frame (cheap).
	var bottom := panel_host.get_global_rect().position.y
	if not is_equal_approx(bottom, _last_band_bottom):
		_last_band_bottom = bottom
		_layout()
	var w := get_viewport_rect().size.x
	for uid in _plates:
		var plate: PanelContainer = _plates[uid]
		var c := Game.carriage(uid)
		if c.is_empty():
			continue
		var center := world.carriage_center(uid)
		var sp: Vector2 = world.world_to_screen(Vector2(center.x, -112.0))
		var nm: Label = plate.get_meta("name")
		var ex: Label = plate.get_meta("extra")
		var d: Dictionary = Data.CARRIAGES[c["type"]]
		nm.text = d["name"]
		var slots := Data.slots(c["type"], c["level"])
		if slots > 0:
			var n := Game.workers_in(uid).size()
			if n == 0 and not c["type"] in ["dronebay", "cooling"]:
				ex.text = "needs workers"
				ex.add_theme_color_override("font_color", UIKit.RED)
			else:
				ex.text = "●".repeat(n) + "○".repeat(slots - n)
				ex.add_theme_color_override("font_color", UIKit.TEAL)
		else:
			ex.text = ""
		plate.size = plate.get_combined_minimum_size()
		plate.position = (sp - Vector2(plate.size.x * 0.5, 0)).round()
		plate.visible = sp.x > -plate.size.x and sp.x < w + plate.size.x and sp.y > hud.band_top() - 40
	_update_coach(_delta)


func _float_text(world_pos: Vector2, text: String, color: Color) -> void:
	var l := UIKit.label(text, "Value")
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	overlay.add_child(l)
	l.position = world.world_to_screen(world_pos) - Vector2(20, 0)
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


func close_modal_of(content: Control) -> void:
	for d in _modal_stack:
		if d.get_meta("content") == content:
			close_modal(d)
			return


func register_target(name: String, control: Control) -> void:
	targets[name] = control


func _target_pos(name: String) -> Vector2:
	var c: Control = targets.get(name)
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return Vector2(-1, -1)
	var r := c.get_global_rect()
	if r.end.y < 0 or r.position.y > get_viewport_rect().size.y:
		return Vector2(-1, -1)
	return Vector2(r.get_center().x, r.position.y)


func _carriage_pos(uid: int) -> Vector2:
	var c := world.carriage_center(uid)
	return world.world_to_screen(Vector2(c.x, -60.0))


## Works out what the player should tap next for the current goal.
func _update_coach(delta: float) -> void:
	_go_boost = maxf(0.0, _go_boost - delta)
	var g := Game.current_goal()
	var tutorial := Game.chapter == 0 and Game.goal_index < TUTORIAL_GOALS
	if g.is_empty() or not _modal_stack.is_empty() or (not tutorial and _go_boost <= 0.0):
		coach.point(Vector2.ZERO, "")
		return
	var pos := Vector2(-1, -1)
	var text := ""
	var arrow := true
	var on_train := tab == "train"
	var to_build := Game.goal_build_type()
	if to_build != "":
		# Building flow (also covers goals whose carriage does not exist yet).
		var name: String = Data.CARRIAGES[to_build]["name"]
		var detour: bool = to_build != g.get("arg", "")
		if not on_train:
			pos = _target_pos("tab_train")
			text = "Back to the train"
		elif current is BuildPanel:
			pos = _target_pos("build_" + to_build)
			if detour:
				text = "No room left on the train. Build a Cooling Module first"
			elif Game.build_block_reason(to_build) == "":
				text = "Build the %s" % name
			else:
				text = "%s: %s. Your drones and workshop are collecting more" % [name, Game.build_block_reason(to_build).to_lower()]
		elif current is OverviewPanel:
			pos = _target_pos("add_carriage")
			text = "No room left. Add a Cooling Module first" if detour else "Add a %s to your train" % name
		else:
			pos = world.world_to_screen(world.carriage_center(-1))
			text = "Tap the empty slot to add a carriage"
		if pos.x < 0:
			text = ""
		coach.point(pos, text)
		return
	match g["kind"]:
		"assign", "level", "survivors":
			var type: String = g.get("arg", "quarters")
			var c := Game.first_of(type)
			var name: String = Data.CARRIAGES[type]["name"]
			if c.is_empty():
				pos = _target_pos("add_carriage")
				text = "Build a %s first" % name
			elif on_train and current is CarriagePanel and current.uid == c["uid"]:
				if g["kind"] == "assign":
					pos = _target_pos("assign_slot")
					text = "Tap + to put a survivor to work here"
				else:
					pos = _target_pos("upgrade")
					text = "Tap UPGRADE" if Game.upgrade_block_reason(c["uid"]) == "" else "Upgrade needs more resources. Your drones and workshop are collecting them"
			elif not on_train:
				pos = _target_pos("tab_train")
				text = "Back to the train"
			else:
				pos = _carriage_pos(c["uid"])
				text = "Tap the %s" % name
		"build":
			var type: String = g["arg"]
			var name: String = Data.CARRIAGES[type]["name"]
			if not on_train:
				pos = _target_pos("tab_train")
				text = "Back to the train"
			elif current is BuildPanel:
				pos = _target_pos("build_" + type)
				text = "Build the %s" % name if Game.build_block_reason(type) == "" else "%s: %s" % [name, Game.build_block_reason(type).to_lower()]
			elif current is OverviewPanel:
				pos = _target_pos("add_carriage")
				text = "Add a %s to your train" % name
			else:
				pos = world.world_to_screen(world.carriage_center(-1))
				text = "Tap the empty slot to add a carriage"
		"salvaged":
			var bay := Game.first_of("dronebay")
			pos = _carriage_pos(bay["uid"])
			text = "Drones collect scrap by themselves. Just watch them work"
		"distance":
			pos = Vector2(get_viewport_rect().size.x * 0.5, hud.band_top() + 10)
			text = "The train is driving to the %s. Keep building meanwhile" % Game.ch()["landmark_name"]
			arrow = false
		"research":
			if current is ResearchPanel:
				pos = _target_pos("research_start")
				text = "Pick a project and tap START" if Game.research_id == "" else "Research is running. Keep building meanwhile"
				arrow = Game.research_id == ""
			elif not on_train:
				pos = _target_pos("tab_train")
				text = "Back to the train"
			else:
				pos = _carriage_pos(Game.first_of("lab").get("uid", -1))
				text = "Tap the Research Lab"
		"crew_level":
			pos = Vector2(get_viewport_rect().size.x * 0.5, hud.band_top() + 10)
			text = "Workers gain experience while they work. Keep everyone busy"
			arrow = false
		"any_level":
			pos = _target_pos("tab_train") if not on_train else Vector2(get_viewport_rect().size.x * 0.5, hud.band_top() + 10)
			text = "Upgrade your best carriage all the way"
			arrow = not on_train
		"tower":
			if tab != "journey":
				pos = _target_pos("tab_journey")
				text = "Open Journey to restore the %s" % Game.ch()["landmark_name"]
			else:
				pos = _target_pos("launch")
				text = "Send the drones to the tower"
	if pos.x < 0:
		coach.point(Vector2.ZERO, "")
	else:
		coach.point(pos, text, arrow)


## Takes the player to the place where the current goal is solved.
func goto_goal() -> void:
	_go_boost = 10.0
	var g := Game.current_goal()
	if g.is_empty():
		set_tab("journey")
		return
	match g["kind"]:
		"assign":
			var c := Game.first_of(g["arg"])
			if c.is_empty():
				open_build()
			else:
				open_carriage(c["uid"])
		"build":
			open_build()
		"level":
			open_carriage(Game.first_of(g["arg"])["uid"])
		"salvaged":
			open_carriage(Game.first_of("dronebay")["uid"])
		"survivors":
			open_carriage(Game.first_of("quarters")["uid"])
		"research":
			if Game.count_type("lab") == 0:
				open_build()
			else:
				open_research()
		"crew_level":
			set_tab("crew")
		"any_level":
			var best: Dictionary = Game.carriages[0]
			for c in Game.carriages:
				if c["level"] > best["level"] and c["level"] < Game.level_cap():
					best = c
			open_carriage(best["uid"])
		_:
			set_tab("journey")


func _on_goal_completed(index: int) -> void:
	var g: Dictionary = Game.goals()[index]
	var reward := Data.cost_text(g["reward"])
	show_toast("Goal complete: %s%s" % [g["text"], (" (+" + reward + ")") if reward != "" else ""], "good")
	Audio.play("goal_complete")
	hud.pulse_goal()


func _on_event_started(_id: String) -> void:
	Audio.play("alarm")
	Popups.event(self)


func _on_chapter_complete() -> void:
	Audio.play_music("tower_restored")
	Popups.chapter_complete(self)


func _on_chapter_started(_index: int) -> void:
	world.on_chapter_started()
	_rebuild_plates()
	set_tab("journey" if tab == "journey" else "train")
	show_toast("Chapter %d: %s" % [Game.chapter + 1, Game.region_name()], "good")


func _on_offline_report(report: Dictionary) -> void:
	if report.is_empty():
		return
	Game.pending_report = {}
	Popups.offline(self, report)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not _modal_stack.is_empty():
			close_modal()
		elif not (current is OverviewPanel) and tab == "train":
			show_train_overview()
		else:
			Game.save_game()
			get_tree().quit()

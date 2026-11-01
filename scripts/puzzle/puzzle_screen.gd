class_name PuzzleScreen
extends Control
## One coolant-sort level: top bar with the heat gauge, the train band (World shows through),
## the board and the booster bar. Every pour heats the carriage; sealing tanks cools it, and
## chaining seals within a few seconds triggers a cold snap. At 70°C the level is lost.

var main: Node
var board := SortBoard.new()
var view: PuzzleView
var gauge: HeatGauge
var level_n := 1
var boss := false # landmark boss level: winning restores the region's landmark
var heat := Data.HEAT_START
var per_move := 1.0
var continues := 0
var moves_made := 0
var finished := false
var _chain := 0
var _last_seal := -99.0
var _t := 0.0
var _title: Label
var _tag: Label
var _banner: Label
var _booster_btns := {}
var _top: PanelContainer
var _bottom: PanelContainer
var _tutorial_step := -1
var charges := {"magnet": 0, "frost": 0} # earned in-level from cold snaps
var _charge_btns := {}
var _charge_row: HBoxContainer
var _goal: GoalStrip


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	var safe: float = main.safe_top()
	_top = UIKit.panel("Bar")
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_top)
	var m := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	m.add_theme_constant_override("margin_top", 8 + int(safe))
	_top.add_child(m)
	var back := UIKit.button("", "FlatButton", "", 56)
	back.custom_minimum_size = Vector2(56, 56)
	var bi := Icon.make("close", 26, UIKit.TEXT)
	bi.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	back.add_child(bi)
	back.pressed.connect(_on_back)
	_title = UIKit.label("LEVEL 1", "Header")
	_tag = UIKit.label("", "Small")
	_tag.add_theme_color_override("font_color", UIKit.RED)
	gauge = HeatGauge.new()
	gauge.custom_minimum_size = Vector2(0, 46)
	gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIKit.hbox(10, [back, UIKit.vbox(-6, [_title, _tag]), gauge])
	m.add_child(head)

	view = PuzzleView.new()
	add_child(view)
	view.poured.connect(_on_poured)
	view.selected_tank.connect(func(_i): _tutorial_next(1))
	view.blocked.connect(func(text: String):
		_banner.text = text
		_banner.add_theme_color_override("font_color", UIKit.ORANGE))
	view.target_picked.connect(_on_target)
	_goal = GoalStrip.new()
	_goal.view = view
	add_child(_goal)
	# Combo charges appear above the boosters when a cold snap earns them.
	_charge_row = UIKit.hbox(10)
	add_child(_charge_row)
	for id in ["magnet", "frost"]:
		var b := UIKit.button("", "GreenButton", "magnet" if id == "magnet" else "frostcharge", 64)
		b.custom_minimum_size.x = 190
		var cid: String = id
		b.pressed.connect(func(): _use_charge(cid))
		_charge_row.add_child(b)
		_charge_btns[id] = b

	_banner = UIKit.label("", "Value", HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_color_override("font_color", UIKit.ORANGE)
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_banner)

	_bottom = UIKit.panel("Bar")
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bottom)
	var bm := MarginContainer.new()
	for side in ["left", "right", "top"]:
		bm.add_theme_constant_override("margin_" + side, 12)
	bm.add_theme_constant_override("margin_bottom", 14 + int(main.safe_bottom()))
	_bottom.add_child(bm)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bm.add_child(row)
	for id in Data.BOOSTER_ORDER:
		var d: Dictionary = Data.BOOSTERS[id]
		var b := UIKit.button(d["name"].to_upper(), "", d["icon"], 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var badge := UIKit.label("", "Small")
		badge.add_theme_color_override("font_color", UIKit.GOLD)
		var bid: String = id
		b.pressed.connect(func(): _use_booster(bid))
		var col := UIKit.vbox(2, [b, badge])
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(col)
		_booster_btns[id] = [b, badge]
	resized.connect(_layout)
	_layout.call_deferred()


## Top bar, then the train band, then the board, then the boosters.
func _layout() -> void:
	var top_h := _top.get_combined_minimum_size().y
	var bottom_h := _bottom.get_combined_minimum_size().y
	var band := clampf(size.y * 0.2, 200.0, 300.0)
	view.position = Vector2(0, top_h + band)
	view.size = Vector2(size.x, size.y - top_h - band - bottom_h)
	_banner.position = Vector2(20, top_h + band - 40)
	_banner.size = Vector2(size.x - 40, 36)
	if _goal.visible:
		_goal.position = Vector2(16, view.position.y + 4)
		_goal.size = Vector2(size.x - 32, 56)
		view.position.y += 60
		view.size.y -= 60
	_place_charges()
	main.world.set_band(top_h + 6, top_h + band)


func band_bottom() -> float:
	return view.position.y


# ---------------------------------------------------------------- level flow

func start(n: int, pre: Array = [], is_boss := false) -> void:
	level_n = n
	boss = is_boss
	var data := Game.boss_data(Game.region_index) if boss else Game.level_data(n)
	board = SortBoard.new()
	board.load_level(data)
	per_move = (Data.HEAT_MAX - Data.HEAT_START) / float(data.get("moves", 30))
	heat = Game.start_heat()
	# Pre-level boosters (picked or free from the win streak).
	if "pre_cool" in pre:
		heat -= Meta.PRE_COOL
	if "pre_tank" in pre:
		board.add_tank()
	if "pre_ash" in pre:
		for row in board.hidden:
			row.fill(false)
	continues = 0
	moves_made = 0
	finished = false
	_chain = 0
	_last_seal = -99.0
	_title.text = "BOSS LEVEL" if boss else "LEVEL %d" % n
	_tag.text = Game.region()["landmark_name"] if boss else ("HEATWAVE · double parts" if data.get("hard", false) else Game.region_name())
	_tag.add_theme_color_override("font_color", UIKit.RED if data.get("hard", false) else UIKit.MUTED)
	view.boss = boss
	_goal.board = board
	_goal.visible = not board.goal.is_empty()
	charges = {"magnet": 0, "frost": 0}
	_banner.text = ""
	view.locked = false
	view.set_board(board)
	_update()
	_tutorial_step = 0 if n == 1 and not Game.tutorial["first_pour"] else -1
	_tutorial_next(0)
	_layout.call_deferred()
	if not pre.is_empty():
		_float.call_deferred(", ".join(pre.map(func(id): return Meta.PRE[id]["name"])), Color("ffd27a"))
	# First time a blocker shows up, explain it (one per level).
	for kind in Data.BLOCKERS:
		var has: bool = data.has(kind) and (kind != "hidden" or data[kind].any(func(r): return r.has(true)))
		if has and not Game.tutorial.get("blk_" + kind, false):
			Game.tutorial["blk_" + kind] = true
			Popups.blocker.call_deferred(main, kind)
			break


func _process(delta: float) -> void:
	_t += delta
	Game.heat_visual = clampf(inverse_lerp(Data.HEAT_START - 10.0, Data.HEAT_MAX, heat), 0.0, 1.0)
	gauge.heat = heat
	if _tutorial_step >= 0:
		_tutorial_point()


func _update() -> void:
	gauge.heat = heat
	for id in _charge_btns:
		var b: Button = _charge_btns[id]
		b.visible = charges[id] > 0 and not finished
		b.get_meta("label").text = ("MAGNET x%d" if id == "magnet" else "FROST x%d") % charges[id]
		b.theme_type_variation = "GoldButton" if view.target_mode == id else "GreenButton"
	_goal.queue_redraw()
	_place_charges.call_deferred()
	for id in _booster_btns:
		var n := Game.booster_count(id)
		var price: int = Data.BOOSTERS[id]["price"]
		_booster_btns[id][1].text = "x%d" % n if n > 0 else "%d scrap" % price
		var b: Button = _booster_btns[id][0]
		b.disabled = finished or (id == "undo" and not board.can_undo())


func _on_poured(_from: int, _to: int, result: Dictionary) -> void:
	moves_made += 1
	heat += per_move
	if _tutorial_step >= 0:
		Game.tutorial["first_pour"] = true
		_tutorial_next(2)
	_settle(result)
	_update()
	_check_end()


## Seals, thaws, hot canisters and rust from one pour (also used for magnet pours).
func _settle(result: Dictionary) -> void:
	for _s in result.get("sealed", []):
		_on_seal()
	if not result.get("thawed", []).is_empty():
		_float("OPEN!", Color("bff4ff"))
		Audio.play("upgrade")
	if not result.get("rusted", []).is_empty():
		_float("RUST SPREADS", UIKit.ORANGE)
	if result.get("defused", 0) > 0:
		heat = maxf(Game.start_heat() - 5.0, heat - Data.HOT_DEFUSE_COOL * result["defused"])
		_float("HOT CANISTER SEALED  -%d°C" % int(Data.HOT_DEFUSE_COOL * result["defused"]), Color("7fe8ff"))
	if result.get("flared", 0) > 0:
		heat += Data.HOT_FLARE * result["flared"]
		_float("FLARE!  +%d°C" % int(Data.HOT_FLARE * result["flared"]), UIKit.RED)
		Audio.play("alarm", 0.1)


func _check_end() -> void:
	if board.is_won():
		_win()
	elif heat >= Data.HEAT_MAX:
		_overheat()
	elif board.is_stuck():
		var help: bool = Game.booster_count("undo") > 0 or Game.booster_count("tank") > 0 or charges["magnet"] > 0 or charges["frost"] > 0
		_banner.text = "No moves left! Use Undo or a Spare Tank" if help else "No moves left!"
		if not help:
			_overheat(true)
	elif not board.hot_left().is_empty() and board.hot_left().min() <= 3:
		var left: int = board.hot_left().min()
		_banner.text = "Hot canister flares in %d move%s!" % [left, "" if left == 1 else "s"]
		_banner.add_theme_color_override("font_color", UIKit.RED)
	else:
		_banner.text = ""


## Sealing a tank cools the carriage; seals chained within a few seconds make a cold snap.
func _on_seal() -> void:
	_chain = _chain + 1 if _t - _last_seal <= Data.COMBO_WINDOW else 1
	_last_seal = _t
	var cool := 2.0 + Data.COMBO_COOL * (_chain - 1)
	heat = maxf(Game.start_heat() - 5.0, heat - cool)
	if _chain >= 2:
		Game.stats["snaps"] += 1
		_float("COLD SNAP x%d  -%d°C" % [_chain, int(cool)], Color("7fe8ff"))
		Audio.play("upgrade")
		# Combo pieces: a 2-chain earns a Magnet, a 3-chain a Frost Charge.
		if _chain == Data.MAGNET_CHAIN:
			charges["magnet"] += 1
			_float.call_deferred("MAGNET CHARGE!", Color("ffd27a"))
		elif _chain == Data.FROST_CHAIN:
			charges["frost"] += 1
			_float.call_deferred("FROST CHARGE!", Color("bff4ff"))
	else:
		_float("-%d°C" % int(cool), Color("9fe6ff"))


func _win() -> void:
	finished = true
	view.locked = true
	_update()
	main.coach.point(Vector2.ZERO, "")
	await get_tree().create_timer(0.6).timeout
	await _cash_out(maxi(0, int(Data.HEAT_MAX - heat)) * Data.COOL_BONUS_PER_DEG)
	main.world.frost_burst()
	Audio.play("goal_complete")
	var reward := Game.win_boss(heat) if boss else Game.win_level(heat)
	reward["card"] = Meta.roll_card(boss)
	Popups.win(main, reward)


## Sugar-Crush-style finale: the unused heat headroom bursts out of the tanks as frost that
## flies up to the train and counts into the cool bonus.
func _cash_out(bonus: int) -> void:
	if bonus <= 0:
		return
	var counter := UIKit.label("COOL BONUS +0", "Header", HORIZONTAL_ALIGNMENT_CENTER)
	counter.add_theme_color_override("font_color", Color("9fe6ff"))
	counter.add_theme_constant_override("outline_size", 8)
	counter.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	counter.size = Vector2(size.x, 50)
	counter.position = Vector2(0, view.position.y + 8)
	add_child(counter)
	var target := Vector2(size.x * 0.5, view.position.y - 60)
	var n := clampi(bonus / 2, 6, 18)
	for k in n:
		var flake := Icon.make("snowflake", 38, Color("bff4ff"))
		var r := view.tank_rect(k % board.tanks.size())
		flake.position = view.position + r.get_center() - Vector2(19, 19)
		flake.pivot_offset = Vector2(19, 19)
		add_child(flake)
		var tw := flake.create_tween().set_parallel()
		tw.tween_property(flake, "position", target - Vector2(19, 19) + Vector2(randf_range(-80, 80), 0), 0.55).set_delay(k * 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(flake, "rotation", randf_range(-3.0, 3.0), 0.55).set_delay(k * 0.05)
		tw.chain().tween_callback(func():
			counter.text = "COOL BONUS +%d" % int(bonus * float(k + 1) / n)
			Audio.play("collect", 0.02)
			flake.queue_free())
	await get_tree().create_timer(0.55 + n * 0.05 + 0.5).timeout
	counter.queue_free()


func _overheat(stuck := false) -> void:
	view.locked = true
	await get_tree().create_timer(0.5).timeout
	Audio.play("alarm")
	Popups.overheated(main, self, stuck)


## Called from the overheated popup after paying or watching an ad.
func continue_level() -> void:
	continues += 1
	heat = maxf(Game.start_heat(), heat - Data.CONTINUE_COOL)
	if board.is_stuck():
		board.add_tank()
		view.refresh_board()
	_banner.text = ""
	view.locked = false
	_update()


func give_up() -> void:
	finished = true
	Game.lose_life()
	main.show_home()


func _on_back() -> void:
	if finished:
		return
	if moves_made == 0:
		main.show_home()
		return
	Popups.confirm_leave(main, self)


func _use_booster(id: String) -> void:
	if finished or view.is_animating():
		return
	if Game.booster_count(id) <= 0:
		Popups.shop(main, id)
		return
	match id:
		"undo":
			if not board.can_undo():
				return
			Game.use_booster(id)
			board.undo()
			view.refresh_board()
		"tank":
			if board.tanks.size() >= 14:
				return
			Game.use_booster(id)
			board.add_tank()
			view.refresh_board()
		"flush":
			Game.use_booster(id)
			heat = maxf(Game.start_heat() - 5.0, heat - Data.FLUSH_COOL)
			_float("HEAT FLUSH  -%d°C" % int(Data.FLUSH_COOL), Color("7fe8ff"))
	Audio.play("upgrade")
	_banner.text = ""
	_update()


## Charges sit at the top right of the train band, clear of the board and the banner.
func _place_charges() -> void:
	_charge_row.size = _charge_row.get_combined_minimum_size()
	_charge_row.position = Vector2(size.x - _charge_row.size.x - 12, _top.get_combined_minimum_size().y + 10)


func _use_charge(id: String) -> void:
	if finished or charges[id] <= 0 or view.is_animating():
		return
	if id == "magnet":
		view.target_mode = "" if view.target_mode == "magnet" else "magnet"
		_banner.text = "Tap a tank: every matching canister flies into it" if view.target_mode != "" else ""
		_banner.add_theme_color_override("font_color", UIKit.GOLD)
	else:
		charges["frost"] -= 1
		heat = maxf(Game.start_heat() - 5.0, heat - Data.FROST_CHARGE_COOL)
		board.frost_charge()
		view.refresh_board()
		view.burst_all()
		_float("FROST CHARGE  -%d°C" % int(Data.FROST_CHARGE_COOL), Color("bff4ff"))
		Audio.play("upgrade")
	_update()


func _on_target(i: int) -> void:
	if view.target_mode != "magnet":
		return
	var results := board.magnet(i)
	if results.is_empty():
		_banner.text = "Pick a tank with a free canister on top"
		Audio.play("error")
		return
	charges["magnet"] -= 1
	view.target_mode = ""
	view.refresh_board()
	view.burst_at(i)
	Audio.play("collect")
	_float("MAGNET!", Color("ffd27a"))
	for r in results:
		_settle(r)
	_update()
	_check_end()


func _float(text: String, col: Color) -> void:
	var l := UIKit.label(text, "Header", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.size = Vector2(size.x, 40)
	l.position = Vector2(0, view.position.y + 10)
	add_child(l)
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 60, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- tutorial (level 1)

func _tutorial_next(step: int) -> void:
	if _tutorial_step < 0:
		return
	if step == 1 and _tutorial_step == 0:
		_tutorial_step = 1
	elif step == 2:
		_tutorial_step = -1
		main.coach.point(Vector2.ZERO, "")
		_banner.text = "Fill each tank with one colour before the heat hits 70°C"
		_banner.add_theme_color_override("font_color", UIKit.TEAL)
	elif step == 0:
		_tutorial_step = 0


func _tutorial_point() -> void:
	if view.selected < 0:
		_tutorial_step = 0
	var target := 0 if _tutorial_step == 0 else 2
	var r := view.tank_rect(target)
	if r.size == Vector2.ZERO:
		return
	var text := "Tap a tank to lift its top canisters" if _tutorial_step == 0 else "Now tap the empty tank to pour them in"
	main.coach.point(view.global_position + Vector2(r.get_center().x, r.position.y), text)


class HeatGauge extends Control:
	var heat := 30.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var lo := 20.0
		var hi := Data.HEAT_MAX
		var bar := Rect2(4, size.y * 0.5 - 9, size.x - 92, 18)
		draw_style_box(UIKit.box(Color(0.08, 0.1, 0.12), Color(0.3, 0.34, 0.38), 9, 2), bar)
		var k := clampf((heat - lo) / (hi - lo), 0.0, 1.0)
		var fill := Rect2(bar.position + Vector2(3, 3), Vector2((bar.size.x - 6) * k, bar.size.y - 6))
		var col := Color("3fb6ff").lerp(Color("f2873a"), clampf(k * 1.4, 0, 1)).lerp(Color("ff3b30"), clampf((k - 0.6) / 0.4, 0, 1))
		if k > 0.8:
			col = col.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(_t * 10.0)))
		if fill.size.x > 2:
			draw_style_box(UIKit.box(col, col, 7, 0), fill)
		for tick in [40.0, 50.0, 60.0]:
			var x: float = bar.position.x + bar.size.x * (tick - lo) / (hi - lo)
			draw_line(Vector2(x, bar.position.y + 3), Vector2(x, bar.end.y - 3), Color(0, 0, 0, 0.35), 2.0)
		Icon.draw_kind(self, "temp", Rect2(Vector2(size.x - 86, size.y * 0.5 - 15), Vector2(30, 30)), col)
		var font := UIKit.font_bold
		draw_string(font, Vector2(size.x - 54, size.y * 0.5 + 10), "%d°" % int(round(heat)), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col if k > 0.6 else UIKit.TEXT)


## Goal bar under the train: the colours to rescue (with drone parts) or to seal in order.
class GoalStrip extends Control:
	var view: PuzzleView
	var board: SortBoard

	func _draw() -> void:
		if board == null or board.goal.is_empty():
			return
		draw_style_box(UIKit.box(Color(0.05, 0.06, 0.08, 0.85), Color(1, 1, 1, 0.1), 12, 2), Rect2(Vector2.ZERO, size))
		var order: bool = board.goal["type"] == "order"
		var font := UIKit.font_bold
		var title := "SEAL IN ORDER" if order else "RESCUE DRONE PARTS"
		draw_string(font, Vector2(14, size.y * 0.5 + 9), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIKit.GOLD)
		var x := 14.0 + font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 16.0
		var want := board.next_in_order()
		for c in board.goal["colors"]:
			var r := Rect2(x, 8, 58, 40)
			var done := board.color_sealed(int(c))
			view.draw_canister_on(self, r, int(c), 0.45 if done else 1.0)
			if order and int(c) == want:
				draw_rect(r.grow(3), UIKit.GOLD, false, 2.0)
			if done:
				Icon.draw_kind(self, "check", Rect2(r.position + Vector2(30, 14), Vector2(30, 30)), UIKit.GREEN)
			elif not order:
				Icon.draw_kind(self, "drone", Rect2(r.position + Vector2(36, -4), Vector2(24, 24)), UIKit.GOLD)
			x += 70.0

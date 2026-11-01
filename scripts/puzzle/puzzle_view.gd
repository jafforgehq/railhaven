class_name PuzzleView
extends Control
## Draws a SortBoard as rows of glass tanks and handles taps: tap a tank to lift its top
## canisters, tap another to pour. Pours animate as canisters flying in an arc; finished tanks
## get a frosted seal. Uses the Blender sprites in assets/sprites/puzzle/ (vector fallback).

signal poured(from: int, to: int, result: Dictionary)
signal selected_tank(index: int)
signal invalid_move
signal blocked(text: String) # a tap hit a blocker; the screen explains it
signal target_picked(index: int) # a tank tapped while a charge waits for its target

const DIR := "res://assets/sprites/puzzle/"
const ART := Vector2(160, 420) # tank sprite size (px)
const INNER_X := 16.0 # canister column inside the tank sprite
const INNER_BOTTOM := 390.0
const SLOT_H := 88.0
const CAN_W := 128.0
const FLY_TIME := 0.3

var board: SortBoard
var selected := -1
var locked := false # input off during popups and the win sequence
var boss := false # boss level: hazard rims on every tank
var target_mode := "" # "magnet" while a charge waits for a tank tap
var _targets: Array[Rect2] = [] # where each tank should be (conveyor slides _rects toward these)
var _belt := 0.0 # conveyor belt scroll
var _rects: Array[Rect2] = []
var _lift: Array[float] = []
var _shake: Array[float] = []
var _seal: Array[float] = []
var _ice: Array[float] = [] # frost overlay, fades out when a tank thaws
var _pending: Array[int] = [] # canisters still flying into each tank
var _flying: Array = [] # {c, from, to, t, tank}
var _sparks: Array = [] # {p, v, life}
var _tex := {}
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for n in ["tank_back", "tank_front", "tank_seal", "canister_hidden", "board_bg", "tank_ice", "tank_tag", "canister_hot",
			"canister_key", "tank_padlock", "canister_rust", "canister_part", "conveyor", "pipe_link", "tank_boss"] + Data.COLORS.map(func(c): return "canister_" + c):
		var p: String = DIR + n + ".png"
		if ResourceLoader.exists(p):
			_tex[n] = load(p)
	resized.connect(_layout)


func set_board(b: SortBoard) -> void:
	board = b
	selected = -1
	_flying.clear()
	_sparks.clear()
	_sync_arrays()
	for i in board.tanks.size():
		_seal[i] = 1.0 if board.is_complete(i) else 0.0
		_ice[i] = 1.0 if board.is_frozen(i) else 0.0
	_layout()


func _sync_arrays() -> void:
	var n := board.tanks.size()
	while _lift.size() < n:
		_lift.append(0.0)
		_shake.append(0.0)
		_seal.append(0.0)
		_ice.append(0.0)
		_pending.append(0)
	_lift.resize(n)
	_shake.resize(n)
	_seal.resize(n)
	_ice.resize(n)
	_pending.resize(n)


## Tank rects in rows (one row up to 6 tanks, otherwise two), sized to fit.
func _layout() -> void:
	if board == null or size.x < 100.0 or size.y < 100.0:
		return
	_sync_arrays()
	var n := board.tanks.size()
	var per_row := n if n <= 6 else ceili(n / 2.0)
	var rows := 1 if n <= 6 else 2
	var gap := 14.0
	var tw := minf(118.0, (size.x - 40.0) / per_row - gap)
	var th := tw * ART.y / ART.x
	var row_gap := 46.0
	var max_h := (size.y - 50.0 - row_gap * (rows - 1)) / rows
	if th > max_h:
		th = max_h
		tw = th * ART.x / ART.y
	if board.lock.any(func(x): return x >= 0):
		row_gap += 10.0 # room for the tags hanging on the rims
	_targets.clear()
	var top := (size.y - (th * rows + row_gap * (rows - 1))) * 0.5 + 20.0
	var shift := board.shift()
	for i in n:
		var r := i / per_row
		var count := per_row if r == 0 else n - per_row
		var row_w := count * tw + (count - 1) * gap
		var x0 := (size.x - row_w) * 0.5
		var slot := (i % per_row + shift) % count # conveyor rows slide along
		_targets.append(Rect2(x0 + slot * (tw + gap), top + r * (th + row_gap), tw, th))
	if _rects.size() != n:
		_rects = _targets.duplicate()
	else:
		for i in n:
			_rects[i].size = _targets[i].size
	queue_redraw()


func tank_center(i: int) -> Vector2:
	return _rects[i].get_center() if i < _rects.size() else Vector2.ZERO


func tank_rect(i: int) -> Rect2:
	return _rects[i] if i < _rects.size() else Rect2()


func _slot_rect(i: int, k: int, lift := 0.0) -> Rect2:
	var r := _rects[i]
	var s := r.size.x / ART.x
	return Rect2(r.position.x + INNER_X * s, r.position.y - lift + (INNER_BOTTOM - SLOT_H * (k + 1)) * s, CAN_W * s, SLOT_H * s)


# ---------------------------------------------------------------- input

func _gui_input(e: InputEvent) -> void:
	if locked or board == null:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit(e.position)
		if hit < 0:
			_select(-1)
			return
		accept_event()
		_tap(hit)


func _hit(p: Vector2) -> int:
	for i in _rects.size():
		if _rects[i].grow_individual(10, 40, 10, 10).has_point(p):
			return i
	return -1


func _tap(i: int) -> void:
	if target_mode != "":
		target_picked.emit(i)
		return
	if board.is_shut(i) or (selected < 0 and board.top_run(i) == 0 and not board.tanks[i].is_empty() and not board.is_complete(i)):
		_shake[i] = 0.35
		Audio.play("error")
		blocked.emit(board.block_reason(selected, i))
		return
	if selected < 0:
		if board.tanks[i].is_empty() or board.is_complete(i) or _pending[i] > 0:
			_shake[i] = 0.35
			Audio.play("error")
			invalid_move.emit()
			return
		_select(i)
		return
	if i == selected:
		_select(-1)
		return
	var from := selected
	var n := board.can_pour(from, i)
	if n == 0:
		# Tapping another tank that could itself be lifted switches the selection.
		if not board.tanks[i].is_empty() and not board.is_complete(i):
			_select(i)
		else:
			_shake[i] = 0.35
			Audio.play("error")
			invalid_move.emit()
			var why := board.block_reason(from, i)
			if why != "":
				blocked.emit(why)
		return
	var color: int = board.tanks[from][-1]
	var start_k: int = board.tanks[from].size() - 1
	var sizes: Array = board.tanks.map(func(t): return t.size())
	var lift := _lift[from]
	var result := board.pour(from, i)
	var m := 0
	for d in result["dests"]: # twins share a pour, so canisters can land in two tanks
		var a := _slot_rect(from, start_k - m, lift)
		var b := _slot_rect(d, sizes[d])
		sizes[d] += 1
		_flying.append({"c": color, "from": a.position, "to": b.position, "size": a.size, "t": -m * 0.06, "tank": d})
		_pending[d] += 1
		m += 1
	selected = -1
	Audio.play("drone_launch", 0.15)
	for s in result["sealed"]:
		_seal_later(s, FLY_TIME + n * 0.06)
	poured.emit(from, i, result)
	if board.conveyor > 0:
		_layout()


func _select(i: int) -> void:
	selected = i
	if i >= 0:
		Audio.play("ui_click")
		selected_tank.emit(i)


func _seal_later(i: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or i >= _seal.size():
		return
	var tw := create_tween()
	tw.tween_method(func(v): _seal[i] = v, 0.0, 1.0, 0.35)
	Audio.play("collect")
	var r := _rects[i]
	for k in 18:
		_sparks.append({"p": Vector2(r.get_center().x + randf_range(-r.size.x * 0.4, r.size.x * 0.4), r.position.y + randf_range(0, r.size.y)),
			"v": Vector2(randf_range(-30, 30), randf_range(-90, -30)), "life": randf_range(0.5, 1.0)})


## Sparkle burst over one tank (magnet) or every tank (frost charge).
func burst_at(i: int, col := Color(1.0, 0.85, 0.5)) -> void:
	var r := _rects[i]
	for k in 22:
		_sparks.append({"p": Vector2(r.get_center().x + randf_range(-r.size.x * 0.4, r.size.x * 0.4), r.position.y + randf_range(0, r.size.y)),
			"v": Vector2(randf_range(-40, 40), randf_range(-110, -30)), "life": randf_range(0.5, 1.1), "c": col})


func burst_all() -> void:
	for i in _rects.size():
		burst_at(i, Color(0.75, 0.95, 1.0))


## Rebuilds after undo or an added tank (no animation).
func refresh_board() -> void:
	selected = -1
	_flying.clear()
	_sync_arrays()
	for i in _pending.size():
		_pending[i] = 0
		_seal[i] = 1.0 if board.is_complete(i) else 0.0
		_ice[i] = 1.0 if board.is_frozen(i) else 0.0
	_rects.clear()
	_layout()


func is_animating() -> bool:
	return not _flying.is_empty()


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if board == null:
		return
	_t += delta
	for i in _lift.size():
		_lift[i] = lerpf(_lift[i], 30.0 if i == selected else 0.0, 1.0 - exp(-delta * 18.0))
		_shake[i] = maxf(0.0, _shake[i] - delta)
		_ice[i] = move_toward(_ice[i], 1.0 if board.is_frozen(i) else 0.0, delta * 2.5)
		if i < _targets.size() and i < _rects.size():
			var p := _rects[i].position.lerp(_targets[i].position, 1.0 - exp(-delta * 7.0))
			if p.distance_to(_targets[i].position) > 0.5:
				_belt += (p.x - _rects[i].position.x) * 0.15
			_rects[i].position = p
	for f in _flying:
		f["t"] += delta / FLY_TIME
	var done := _flying.filter(func(f): return f["t"] >= 1.0)
	for f in done:
		_pending[f["tank"]] = maxi(0, _pending[f["tank"]] - 1)
	_flying = _flying.filter(func(f): return f["t"] < 1.0)
	for s in _sparks:
		s["p"] += s["v"] * delta
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	if board == null or _rects.is_empty():
		return
	# Dark machinery panel behind the tanks keeps the board readable over any scenery.
	var area := _rects[0]
	for r in _rects:
		area = area.merge(r)
	area = area.grow_individual(22, 52, 22, 18)
	if _tex.has("board_bg"):
		draw_texture_rect(_tex["board_bg"], area, false, Color(1, 1, 1, 0.95))
	else:
		draw_style_box(UIKit.box(Color(0.05, 0.06, 0.08, 0.82), Color(1, 1, 1, 0.08), 18, 2), area)
	if board.conveyor > 0:
		_draw_belts()
	var key_colors := {}
	for i in board.tanks.size():
		if board.is_keylocked(i):
			key_colors[board.keylock[i]] = true
	for i in _rects.size():
		var off := Vector2(sin(_shake[i] * 60.0) * 6.0 * _shake[i] / 0.35, -_lift[i])
		var r := Rect2(_rects[i].position + off, _rects[i].size)
		_draw_tank_back(r)
		var t: Array = board.tanks[i]
		var shown := t.size() - _pending[i]
		for k in shown:
			var sr := _slot_rect(i, k, _lift[i])
			sr.position.x += off.x
			_draw_canister(sr, t[k], board.hidden[i][k], i == selected and k >= t.size() - board.top_run(i))
			if board.hidden[i][k]:
				continue
			if board.rust[i][k]:
				_overlay("canister_rust", sr, Color(0.62, 0.33, 0.16, 0.7))
			var is_hot: bool = k < board.hot[i].size() and board.hot[i][k] > 0
			if key_colors.has(t[k]) and not is_hot: # both badges use the top-right corner
				_overlay("canister_key", sr, Color(0.9, 0.72, 0.3))
			if board.part[i][k]:
				_overlay("canister_part", sr, UIKit.GOLD)
			if k < board.hot[i].size() and board.hot[i][k] > 0:
				_draw_hot(sr, board.hot[i][k])
		_draw_tank_front(r, _seal[i])
		if _ice[i] > 0.0:
			_draw_ice(r, board.thaw_left(i), _ice[i])
		if board.is_keylocked(i):
			_draw_padlock(r, board.keylock[i])
		if board.lock[i] >= 0:
			_draw_tag(r, board.lock[i])
		if boss:
			_overlay("tank_boss", r, Color(1, 0.3, 0.1, 0.4))
		if target_mode != "" and not board.tanks[i].is_empty() and not board.is_complete(i):
			draw_rect(r.grow(4), Color(1.0, 0.82, 0.4, 0.5 + 0.4 * sin(_t * 6.0)), false, 3.0)
	_draw_twins()
	for f in _flying:
		var e := clampf(f["t"], 0.0, 1.0)
		if f["t"] < 0.0:
			continue
		var ease := e * e * (3.0 - 2.0 * e)
		var p: Vector2 = f["from"].lerp(f["to"], ease) + Vector2(0, -sin(ease * PI) * 70.0)
		_draw_canister(Rect2(p, f["size"]), f["c"], false, false)
	for s in _sparks:
		var a := clampf(s["life"], 0.0, 1.0)
		var sc: Color = s.get("c", Color(0.75, 0.95, 1.0))
		draw_circle(s["p"], 2.5 * a + 0.5, Color(sc.r, sc.g, sc.b, a))


func _draw_tank_back(r: Rect2) -> void:
	if _tex.has("tank_back"):
		draw_texture_rect(_tex["tank_back"], r, false)
		return
	var s := r.size.x / ART.x
	var inner := Rect2(r.position + Vector2(10, 20) * s, r.size - Vector2(20, 26) * s)
	draw_style_box(UIKit.box(Color(0.1, 0.13, 0.16, 0.85), Color(0.32, 0.38, 0.44), 14, 3), inner)


func _draw_tank_front(r: Rect2, seal: float) -> void:
	if _tex.has("tank_front"):
		draw_texture_rect(_tex["tank_front"], r, false)
	else:
		var s := r.size.x / ART.x
		draw_rect(Rect2(r.position + Vector2(22, 30) * s, Vector2(10, r.size.y / s - 80) * s), Color(1, 1, 1, 0.12))
	if seal > 0.0:
		if _tex.has("tank_seal"):
			draw_texture_rect(_tex["tank_seal"], r, false, Color(1, 1, 1, seal))
		else:
			var s2 := r.size.x / ART.x
			draw_rect(Rect2(r.position + Vector2(4, 0) * s2, Vector2(152, 26) * s2), Color(0.7, 0.92, 1.0, seal))
		draw_texture_rect(CarriageView.glow_texture(), r.grow(r.size.x * 0.3), false, Color(0.4, 0.85, 1.0, 0.18 * seal * (0.7 + 0.3 * sin(_t * 3.0))))


## Sprite overlay, or a plain tinted frame until the art exists.
func _overlay(key: String, r: Rect2, fallback: Color) -> void:
	if _tex.has(key):
		draw_texture_rect(_tex[key], r, false)
	else:
		draw_rect(r.grow(-3), fallback, false, 3.0)


func _draw_padlock(r: Rect2, c: int) -> void:
	_overlay("tank_padlock", r, Color(0.7, 0.72, 0.75, 0.9))
	var s := r.size.x / ART.x
	var cw := 40.0 * s
	var ch := cw * SLOT_H / CAN_W
	_draw_canister(Rect2(r.position + Vector2(80, 222) * s - Vector2(cw, ch) * 0.5, Vector2(cw, ch)), c, false, false)


func _draw_twins() -> void:
	for i in board.twin.size():
		var p: int = board.twin[i]
		if p <= i or p >= _rects.size():
			continue
		var left_i := i if _rects[i].position.x < _rects[p].position.x else p
		var a := _rects[left_i]
		var b := _rects[p if left_i == i else i]
		var y := a.get_center().y + a.size.y * 0.18
		var h := a.size.x * 0.3
		var pr := Rect2(a.end.x - a.size.x * 0.12, y - h * 0.5, b.position.x - a.end.x + a.size.x * 0.24, h)
		if _tex.has("pipe_link"):
			# 24 px flanges stay fixed; only the plain middle of the 64 px sprite stretches.
			var cap := minf(24.0 * h / 40.0, pr.size.x * 0.5)
			var tex: Texture2D = _tex["pipe_link"]
			draw_texture_rect_region(tex, Rect2(pr.position, Vector2(cap, h)), Rect2(0, 0, 24, 40))
			draw_texture_rect_region(tex, Rect2(pr.position + Vector2(cap, 0), Vector2(pr.size.x - cap * 2.0, h)), Rect2(24, 0, 16, 40))
			draw_texture_rect_region(tex, Rect2(Vector2(pr.end.x - cap, pr.position.y), Vector2(cap, h)), Rect2(40, 0, 24, 40))
		else:
			draw_rect(pr, Color(0.35, 0.75, 0.95, 0.9))


func _draw_belts() -> void:
	var rows := {}
	for i in _targets.size():
		var y := _targets[i].end.y
		rows[y] = rows.get(y, []) + [i]
	for y in rows:
		var xs: Array = rows[y].map(func(i): return _targets[i].position.x)
		var x0: float = xs.min() - 10.0
		var x1: float = xs.max() + _targets[rows[y][0]].size.x + 10.0
		var h := 24.0
		var belt := Rect2(x0, y - 8.0, x1 - x0, h)
		if _tex.has("conveyor"):
			var tw := h * 256.0 / 40.0
			var x := x0 - fposmod(_belt, tw)
			while x < x1:
				var seg := Rect2(maxf(x, x0), belt.position.y, minf(x + tw, x1) - maxf(x, x0), h)
				var src := Rect2((seg.position.x - x) / tw * 256.0, 0, seg.size.x / tw * 256.0, 40)
				draw_texture_rect_region(_tex["conveyor"], seg, src)
				x += tw
		else:
			draw_rect(belt, Color(0.12, 0.12, 0.14))


## Draws a canister texture on another canvas item (the goal strip).
func draw_canister_on(ci: CanvasItem, r: Rect2, c: int, alpha := 1.0) -> void:
	var key: String = "canister_" + Data.COLORS[c]
	if _tex.has(key):
		ci.draw_texture_rect(_tex[key], r, false, Color(1, 1, 1, alpha))
	else:
		ci.draw_rect(r, Color(Data.COLOR_HEX[c], alpha))


func _draw_ice(r: Rect2, left: int, a: float) -> void:
	if _tex.has("tank_ice"):
		draw_texture_rect(_tex["tank_ice"], r, false, Color(1, 1, 1, a))
	else:
		var s := r.size.x / ART.x
		draw_style_box(UIKit.box(Color(0.75, 0.92, 1.0, 0.45 * a), Color(0.9, 0.98, 1.0, 0.9 * a), 16, 3), Rect2(r.position + Vector2(6, 14) * s, r.size - Vector2(12, 18) * s))
	if left > 0:
		_draw_number(r.get_center(), str(left), r.size.x * 0.42, Color(0.1, 0.25, 0.4, a), Color(1, 1, 1, a))


func _draw_tag(r: Rect2, c: int) -> void:
	# A tag hangs on the rim: only colour c may be poured in.
	var w := r.size.x * 0.82
	var tr := Rect2(r.get_center().x - w * 0.5, r.position.y - w * 0.5 * 64.0 / 120.0 - 4.0, w, w * 64.0 / 120.0)
	if _tex.has("tank_tag"):
		draw_texture_rect(_tex["tank_tag"], tr, false)
	else:
		draw_style_box(UIKit.box(Color("5b6470"), Color("c9d1da"), 8, 2), tr)
	# Canister icon in the tag's 44 px socket at (60, 32) of the 120x64 sprite.
	var cw := tr.size.x * 0.32
	var ch := cw * SLOT_H / CAN_W
	var sc := tr.position + tr.size * Vector2(60.0 / 120.0, 32.0 / 64.0)
	_draw_canister(Rect2(sc - Vector2(cw, ch) * 0.5, Vector2(cw, ch)), c, false, false)


func _draw_hot(sr: Rect2, left: int) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * (5.0 + 10.0 / maxf(1.0, left)))
	draw_texture_rect(CarriageView.glow_texture(), sr.grow(sr.size.x * 0.25), false, Color(1.0, 0.4, 0.1, 0.25 + 0.3 * pulse * (1.0 if left <= 3 else 0.5)))
	if _tex.has("canister_hot"):
		draw_texture_rect(_tex["canister_hot"], sr, false)
	else:
		draw_style_box(UIKit.box(Color(0, 0, 0, 0), Color(1.0, 0.45, 0.15, 0.9), 10, 3), sr.grow(-2))
	var s := sr.size.x / CAN_W
	_draw_number(sr.position + Vector2(108, 19) * s, str(left), 26.0 * s, Color(0.5, 0.05, 0.0), Color(1, 0.95, 0.85) if left > 3 else Color(1, 1, 0.6).lerp(Color.WHITE, pulse))


func _draw_number(center: Vector2, text: String, fs_f: float, outline: Color, col: Color) -> void:
	var fs := int(fs_f)
	if fs < 6:
		return
	var font := UIKit.font_bold
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p := center + Vector2(-sz.x * 0.5, fs * 0.36)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 6), outline)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_canister(r: Rect2, c: int, is_hidden: bool, lifted: bool) -> void:
	var key: String = "canister_hidden" if is_hidden else "canister_" + Data.COLORS[c]
	if _tex.has(key):
		draw_texture_rect(_tex[key], r, false)
	else:
		var col := Color("777c82") if is_hidden else Color(Data.COLOR_HEX[c])
		var body := r.grow_individual(-2, -6, -2, -4)
		draw_style_box(UIKit.box(col, col.darkened(0.45), 10, 2), body)
		draw_rect(Rect2(body.position + Vector2(6, 4), Vector2(body.size.x * 0.18, body.size.y - 10)), Color(1, 1, 1, 0.25))
		var mark: String = "?" if is_hidden else ["▲", "◆", "●", "■", "★", "✚", "♦", "✦", "○"][c]
		var font := UIKit.font_bold
		var fs := int(r.size.y * 0.42)
		if fs < 4:
			return
		var sz := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(font, r.get_center() + Vector2(-sz.x * 0.5, fs * 0.36), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.45))
	if lifted:
		draw_rect(r.grow(-1), Color(1, 1, 1, 0.12 + 0.08 * sin(_t * 8.0)))

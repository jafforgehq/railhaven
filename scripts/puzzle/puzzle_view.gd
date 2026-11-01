class_name PuzzleView
extends Control
## Draws a SortBoard as rows of glass tanks and handles taps: tap a tank to lift its top
## canisters, tap another to pour. Pours animate as canisters flying in an arc; finished tanks
## get a frosted seal. Uses the Blender sprites in assets/sprites/puzzle/ (vector fallback).

signal poured(from: int, to: int, result: Dictionary)
signal selected_tank(index: int)
signal invalid_move
signal blocked(text: String) # a tap hit a blocker; the screen explains it

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
	for n in ["tank_back", "tank_front", "tank_seal", "canister_hidden", "board_bg", "tank_ice", "tank_tag", "canister_hot"] + Data.COLORS.map(func(c): return "canister_" + c):
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
	_rects.clear()
	if board.lock.any(func(x): return x >= 0):
		row_gap += 10.0 # room for the tags hanging on the rims
	var top := (size.y - (th * rows + row_gap * (rows - 1))) * 0.5 + 20.0
	for r in rows:
		var count := per_row if r == 0 else n - per_row
		var row_w := count * tw + (count - 1) * gap
		var x0 := (size.x - row_w) * 0.5
		for k in count:
			_rects.append(Rect2(x0 + k * (tw + gap), top + r * (th + row_gap), tw, th))
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
	if board.is_frozen(i):
		_shake[i] = 0.35
		Audio.play("error")
		var left := board.thaw_left(i)
		blocked.emit("Frozen: seal %d more tank%s to thaw it" % [left, "" if left == 1 else "s"])
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
			if board.lock[i] >= 0 and board.tanks[i].size() < board.cap:
				blocked.emit("Tagged tank: it only takes %s" % Data.COLORS[board.lock[i]])
		return
	var color: int = board.tanks[from][-1]
	var start_k: int = board.tanks[from].size() - 1
	var dest_k: int = board.tanks[i].size()
	var lift := _lift[from]
	var result := board.pour(from, i)
	for m in n:
		var a := _slot_rect(from, start_k - m, lift)
		var b := _slot_rect(i, dest_k + m)
		_flying.append({"c": color, "from": a.position, "to": b.position, "size": a.size, "t": -m * 0.06, "tank": i})
	_pending[i] += n
	selected = -1
	Audio.play("drone_launch", 0.15)
	if result["completed"]:
		_seal_later(i, FLY_TIME + n * 0.06)
	poured.emit(from, i, result)


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


## Rebuilds after undo or an added tank (no animation).
func refresh_board() -> void:
	selected = -1
	_flying.clear()
	_sync_arrays()
	for i in _pending.size():
		_pending[i] = 0
		_seal[i] = 1.0 if board.is_complete(i) else 0.0
		_ice[i] = 1.0 if board.is_frozen(i) else 0.0
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
			if k < board.hot[i].size() and board.hot[i][k] > 0:
				_draw_hot(sr, board.hot[i][k])
		_draw_tank_front(r, _seal[i])
		if _ice[i] > 0.0:
			_draw_ice(r, board.thaw_left(i), _ice[i])
		if board.lock[i] >= 0:
			_draw_tag(r, board.lock[i])
	for f in _flying:
		var e := clampf(f["t"], 0.0, 1.0)
		if f["t"] < 0.0:
			continue
		var ease := e * e * (3.0 - 2.0 * e)
		var p: Vector2 = f["from"].lerp(f["to"], ease) + Vector2(0, -sin(ease * PI) * 70.0)
		_draw_canister(Rect2(p, f["size"]), f["c"], false, false)
	for s in _sparks:
		var a := clampf(s["life"], 0.0, 1.0)
		draw_circle(s["p"], 2.5 * a + 0.5, Color(0.75, 0.95, 1.0, a))


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
	var d := tr.size.y * 0.62
	var cr := Rect2(tr.get_center() - Vector2(d, d * 0.69) * 0.5, Vector2(d, d * 0.69))
	_draw_canister(cr, c, false, false)


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

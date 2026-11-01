class_name Pet
extends Node2D
## Sandy, the fennec fox who joins when the Living Quarters are built. She trots along the
## carriage floors, sits, naps, and leaps when the player wins or taps her.
## Small enum state machine: four states with trivial enter logic, so no state nodes.

enum State { SIT, WALK, SLEEP, JUMP }

const DIR := "res://assets/sprites/pet/"
const FLOOR_Y := -32.0 # carriage floor in world units (CarriageView.FLOOR)
const SPEED := 22.0
const SIZE := Vector2(24, 24)
const FEET := Vector2(-12, -23) # draw offset so the feet sit on position

var world: Node
var state := State.SIT
var _t := 0.0
var _timer := 2.0
var _target_x := 0.0
var _face := -1.0 # -1 = left (sprite default), 1 = right
var _tex := {}


func _ready() -> void:
	z_index = 4
	for n in ["fox_sit_0", "fox_sit_1", "fox_jump", "fox_sleep"] + range(6).map(func(i): return "fox_walk_%d" % i):
		if ResourceLoader.exists(DIR + n + ".png"):
			_tex[n] = load(DIR + n + ".png")
	position = Vector2(_floor_range().x + 30.0, FLOOR_Y)


## Walkable x range: from the first carriage behind the locomotive to the end of the train.
func _floor_range() -> Vector2:
	var lo := INF
	var hi := -INF
	for uid in world.views:
		var v: Node2D = world.views[uid]
		if v is LocoView:
			continue
		lo = minf(lo, v.position.x + 16.0)
		hi = maxf(hi, v.position.x + CarriageView.W - 16.0)
	return Vector2(lo, hi) if lo < hi else Vector2(0, 0)


func _process(delta: float) -> void:
	var r := _floor_range()
	visible = Game.count_type("quarters") > 0 and r.y > 0.0
	if not visible:
		return
	if position.x < r.x - 1.0 or position.x > r.y + 1.0: # train changed under her
		position.x = clampf(position.x, r.x, r.y)
	_t += delta
	_timer -= delta
	match state:
		State.SIT:
			if _timer <= 0.0:
				_enter(State.SLEEP if randf() < 0.2 else State.WALK)
		State.SLEEP:
			if _timer <= 0.0:
				_enter(State.SIT)
		State.WALK:
			var dx := _target_x - position.x
			if absf(dx) < 1.0:
				_enter(State.SIT)
			else:
				_face = signf(dx)
				position.x += clampf(dx, -SPEED * delta, SPEED * delta)
		State.JUMP:
			var k := clampf(1.0 - _timer / 0.6, 0.0, 1.0)
			position.y = FLOOR_Y - sin(k * PI) * 14.0
			if _timer <= 0.0:
				position.y = FLOOR_Y
				_enter(State.SIT)
	queue_redraw()


func _enter(s: State) -> void:
	state = s
	match s:
		State.SIT:
			_timer = randf_range(2.5, 6.0)
		State.SLEEP:
			_timer = randf_range(8.0, 15.0)
		State.WALK:
			var r := _floor_range()
			_target_x = randf_range(r.x, r.y)
		State.JUMP:
			_timer = 0.6


## A happy leap (wins, taps).
func cheer() -> void:
	if visible and state != State.JUMP:
		_enter(State.JUMP)


func hit(world_pos: Vector2) -> bool:
	return visible and Rect2(position + FEET - Vector2(4, 4), SIZE + Vector2(8, 8)).has_point(world_pos)


func _draw() -> void:
	var key := "fox_sit_%d" % (int(_t / 0.6) % 2)
	match state:
		State.WALK:
			key = "fox_walk_%d" % (int(_t * 10.0) % 6)
		State.SLEEP:
			key = "fox_sleep"
		State.JUMP:
			key = "fox_jump"
	if not _tex.has(key):
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-_face, 1.0)) # sprite faces left
	draw_texture_rect(_tex[key], Rect2(FEET, SIZE), false)
	if state == State.SLEEP:
		var z := fmod(_t, 2.0)
		draw_set_transform(Vector2.ZERO)
		draw_string(UIKit.font_bold, Vector2(4 + z * 3.0, -24 - z * 6.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 1.0 - z * 0.5))

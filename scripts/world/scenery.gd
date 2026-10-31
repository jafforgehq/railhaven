extends Node2D
## One scenery strip rendered in Blender (art/blender/scenery.py). Strips cover x 0..720 and
## tile through Parallax2D; weather tints are applied as a colour multiply.

const WIDTH := 720.0
const HORIZON := -70.0
const DIR := "res://assets/sprites/scenery/scenery_%s.png"
# Region each render covers, in world units (y down).
const RECTS := {
	"sky": Rect2(-300, -900, 1200, 960),
	"far": Rect2(0, -310, 720, 242),
	"mid": Rect2(0, -170, 720, 104),
	"near": Rect2(0, -72, 720, 74),
	"track": Rect2(0, -6, 720, 18),
	"front": Rect2(0, 8, 720, 292),
}

@export var kind := "far"
var heat := 0.0:
	set(v):
		heat = v
		_retint()
var storm := 0.0:
	set(v):
		storm = v
		_retint()
var cool := 0.0:
	set(v):
		cool = v
		_retint()
var tower := 0.0 # landmark visibility 0..1
var restored := false
var _t := 0.0
var _tex: Texture2D
var _towers: Array = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if RECTS.has(kind):
		_tex = load(DIR % kind)
	elif kind == "landmark":
		_towers = [load(DIR % "tower"), load(DIR % "tower_restored")]


func _retint() -> void:
	var c := Color.WHITE.lerp(Color(1.0, 0.74, 0.66), heat * 0.8)
	c = c.lerp(Color(0.9, 0.78, 0.66), storm * 0.7)
	self_modulate = c.lerp(Color(0.86, 0.93, 1.0), cool * 0.6)


func _process(delta: float) -> void:
	if kind == "landmark" and tower > 0.0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if _tex:
		draw_texture_rect(_tex, RECTS[kind], false)
		if kind == "front":
			draw_rect(Rect2(0, 299, WIDTH, 700), Color("2e1208"))
	elif kind == "landmark" and tower > 0.0:
		_draw_tower(Vector2(240, HORIZON))


## The Climate Tower on the horizon, fading in as the train approaches; glows once restored.
func _draw_tower(base: Vector2) -> void:
	var tex: Texture2D = _towers[1 if restored else 0]
	draw_texture_rect(tex, Rect2(base + Vector2(-70, -200), Vector2(140, 202)), false, Color(1, 1, 1, tower))
	var glow := CarriageView.glow_texture()
	if restored:
		var pulse := 0.5 + 0.5 * sin(_t * 2.0)
		draw_texture_rect(glow, Rect2(base + Vector2(-50, -210) - Vector2(pulse, pulse) * 6, Vector2(100, 100) + Vector2(pulse, pulse) * 12), false, Color(0.4, 1.0, 0.9, 0.45 * tower))
		for k in 6:
			draw_set_transform(base + Vector2(-80 + k * 32, -10 - (k % 2) * 6), 0.0, Vector2(1.0, 0.25))
			draw_texture_rect(glow, Rect2(-24, -24, 48, 48), false, Color(0.6, 0.95, 1.0, 0.25 * tower))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var blink := 0.5 + 0.5 * sin(_t * 4.0)
		draw_texture_rect(glow, Rect2(base + Vector2(-8, -202), Vector2(16, 16)), false, Color(1.0, 0.35, 0.25, blink * tower))

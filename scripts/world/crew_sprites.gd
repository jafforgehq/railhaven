class_name CrewSprites
extends RefCounted
## Blender-rendered crew sprite sheets (art/blender/crew.py -> assets/sprites/crew).
## Sheets load lazily per preset; frames are drawn with draw_texture_rect_region.

const DIR := "res://assets/sprites/crew/"
const UNITS_PER_PX := 0.25 # world units per sprite pixel (~38-unit tall crew)
const FEET := Vector2(77.0, 187.5) # feet position inside a 160x200 frame
const SLEEP_SCALE := 0.17
const SLEEP_ANCHOR := Vector2(120.0, 106.0)
const FPS := {"idle": 5.0, "walk": 12.0, "carry": 12.0, "hammer": 10.0, "tend": 6.0, "panel": 8.0, "wrench": 8.0, "sit": 3.0}

static var _meta: Dictionary = {}
static var _tex := {}


static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "crew.json"))
	return _meta


static func preset_for(role: String, look: Dictionary) -> String:
	return "%s_%s" % [role.to_lower(), "a" if int(look.get("hair", 0)) % 2 == 0 else "b"]


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png")
	return _tex[name]


## Draws one animation frame with the feet at `pos`, facing +x (face = 1) or -x (face = -1).
static func draw(ci: CanvasItem, pos: Vector2, preset: String, anim: String, t: float, face: int) -> void:
	var m := meta()
	var row: int = m["anims"].find(anim)
	if row < 0:
		row = 0
		anim = "idle"
	var count: int = m["counts"][anim]
	var col := int(t * FPS.get(anim, 6.0)) % count
	var fw: float = m["frame"][0]
	var fh: float = m["frame"][1]
	ci.draw_set_transform(pos, 0.0, Vector2(UNITS_PER_PX * face, UNITS_PER_PX))
	ci.draw_texture_rect_region(tex(preset), Rect2(-FEET, Vector2(fw, fh)), Rect2(col * fw, row * fh, fw, fh))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Sleeping pose; `pos` is where the back rests on the mattress, head toward -x.
static func draw_sleep(ci: CanvasItem, pos: Vector2, preset: String, t: float) -> void:
	var m := meta()
	var sw: float = m["sleep_frame"][0]
	var sh: float = m["sleep_frame"][1]
	var col := int(t * 1.5) % 4
	ci.draw_set_transform(pos, 0.0, Vector2(SLEEP_SCALE, SLEEP_SCALE))
	ci.draw_texture_rect_region(tex(preset + "_sleep"), Rect2(-SLEEP_ANCHOR, Vector2(sw, sh)), Rect2(col * sw, 0, sw, sh))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

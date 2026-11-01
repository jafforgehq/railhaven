class_name StoryBubble
extends PanelContainer
## Juno's speech bubble on the home screen: portrait, name and one line. Lines queue up,
## each stays a few seconds (tap to skip).

const HOLD := 7.0

var _queue: Array[String] = []
var _text: Label
var _left := 0.0


func _ready() -> void:
	theme_type_variation = "CardTeal"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var face := TextureRect.new()
	face.texture = load(Meta.JUNO_PORTRAIT)
	face.custom_minimum_size = Vector2(76, 76)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var name := UIKit.label(Meta.JUNO_NAME.to_upper(), "Small")
	name.add_theme_color_override("font_color", UIKit.TEAL)
	_text = UIKit.label("", "")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 22)
	var col := UIKit.vbox(0, [name, _text])
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UIKit.hbox(10, [face, col]))
	visible = false
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_left = 0.0)


func say(text: String) -> void:
	if text != "":
		_queue.append(text)


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			visible = false
	elif not _queue.is_empty() and is_visible_in_tree() == false and get_parent().visible:
		_text.text = _queue.pop_front()
		visible = true
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
		_left = HOLD

class_name BasePanel
extends VBoxContainer
## Bottom-sheet content. build() creates controls once; refresh() updates values in place
## (called ~4x/s) so buttons are never recreated under the player's finger.

var main: Node


func _init() -> void:
	add_theme_constant_override("separation", 10)


func build() -> void:
	pass


func refresh() -> void:
	pass


func rebuild() -> void:
	UIKit.clear(self)
	build()


func header(icon: String, title: String, sub := "", closable := true) -> HBoxContainer:
	var ic := UIKit.panel("CardGold", Icon.make(icon, 34, UIKit.GOLD))
	var t := UIKit.label(title, "Header")
	var col := UIKit.vbox(-4, [t])
	if sub != "":
		col.add_child(UIKit.wrap_label(sub, "Sub"))
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIKit.hbox(12, [ic, col])
	if closable:
		var x := UIKit.button("", "FlatButton", "", 48)
		x.custom_minimum_size = Vector2(48, 48)
		var xi := Icon.make("close", 22, UIKit.MUTED)
		xi.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		x.add_child(xi)
		x.pressed.connect(func(): main.show_train_overview())
		row.add_child(x)
	add_child(row)
	return row


func stat_row(icon: String, name: String, cur: String, nxt := "", parent: Control = null) -> Array:
	var c := UIKit.label(cur, "Value")
	var n := UIKit.label(nxt, "Value")
	n.add_theme_color_override("font_color", UIKit.TEAL)
	var arrow := UIKit.label("→" if nxt != "" else "", "Sub")
	var nm := UIKit.label(name, "")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIKit.hbox(10, [Icon.make(icon, 24, UIKit.MUTED), nm, c, arrow, n])
	var p := UIKit.panel("Card", row)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent else self).add_child(p)
	return [c, n, arrow]

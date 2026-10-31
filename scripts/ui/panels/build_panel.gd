class_name BuildPanel
extends BasePanel
## "Add a carriage" sheet: one card per buildable type with live preview and cost.

const ACCENT := {"quarters": "GoldButton", "greenhouse": "GreenButton", "recycler": "TealButton",
	"workshop": "GoldButton", "cooling": "TealButton", "dronebay": "GoldButton"}
var _cards := {}
var _sub: Label


func build() -> void:
	var row := header("wrench", "ADD A CARRIAGE", "Expand your train. Every carriage needs cooling capacity.")
	_sub = row.get_child(1).get_child(1)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 420
	add_child(scroll)
	var cards := UIKit.hbox(10)
	scroll.add_child(cards)
	for t in Data.BUILDABLE:
		var d: Dictionary = Data.CARRIAGES[t]
		var name := UIKit.label(d["name"].to_upper(), "Header")
		name.add_theme_font_size_override("font_size", 25)
		var desc := UIKit.wrap_label(d["desc"], "Small")
		desc.custom_minimum_size = Vector2(220, 64)
		var perk := UIKit.label(_perk(t), "Accent")
		perk.add_theme_font_size_override("font_size", 21)
		var cost := UIKit.hbox(0)
		var why := UIKit.label("", "Small")
		why.add_theme_color_override("font_color", UIKit.ORANGE)
		var btn := UIKit.button("BUILD", ACCENT[t], "hammer", 56)
		var type: String = t
		btn.pressed.connect(func():
			var uid := Game.build(type)
			if uid == 0:
				Audio.play("error")
			else:
				main.open_carriage(uid))
		var box := UIKit.vbox(6, [Preview.make(t, 1, 0.92), UIKit.hbox(6, [Icon.make(d["icon"], 26, UIKit.TEAL), name]), desc, perk, cost, why, btn])
		var card := UIKit.panel("Card", box)
		card.custom_minimum_size.x = 246
		cards.add_child(card)
		_cards[t] = [cost, why, btn]


func _perk(t: String) -> String:
	match t:
		"quarters": return "+%d beds" % Data.beds(1)
		"greenhouse": return "+%.0f food/min per worker" % (Data.worker_rate("greenhouse", 1) * 60)
		"recycler": return "+%.1f water/min per worker" % (Data.worker_rate("recycler", 1) * 60)
		"workshop": return "+%.0f parts/min per worker" % (Data.worker_rate("workshop", 1) * 60)
		"cooling": return "+%d carriage capacity" % Data.cooling_capacity(1, false)
		"dronebay": return "+1 salvage drone"
	return ""


func refresh() -> void:
	_sub.text = "Cooling %d/%d used · Train %d/%d carriages" % [Game.cooling_used(), Game.cooling_capacity(), Game.carriages.size() - 1, Data.MAX_CARRIAGES]
	for t in _cards:
		var parts: Array = _cards[t]
		UIKit.clear(parts[0])
		parts[0].add_child(UIKit.cost_row(Data.build_cost(t, Game.count_type(t)), 24))
		var why := Game.build_block_reason(t)
		parts[1].text = why
		parts[2].disabled = why != ""

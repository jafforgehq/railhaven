class_name BuildPanel
extends BasePanel
## "Add a carriage" sheet: one card per buildable type with live preview and cost.

const ACCENT := {"quarters": "GoldButton", "greenhouse": "GreenButton", "recycler": "TealButton",
	"workshop": "GoldButton", "cooling": "TealButton", "dronebay": "GoldButton"}
var _cards := {}
var _sub: Label


func build() -> void:
	var row := header("hammer", "ADD A CARRIAGE", " ")
	_sub = row.get_child(1).get_child(1)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 420
	add_child(scroll)
	var cards := UIKit.hbox(10)
	scroll.add_child(cards)
	for t in Data.BUILDABLE.filter(func(x): return Game.unlocked(x)):
		var d: Dictionary = Data.CARRIAGES[t]
		var name := UIKit.label(d["name"].to_upper(), "Header")
		name.add_theme_font_size_override("font_size", 25)
		var desc := UIKit.wrap_label(CarriagePanel.PLAIN[t], "Small")
		desc.custom_minimum_size = Vector2(220, 64)
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
		var box := UIKit.vbox(6, [Preview.make(t, 1, 0.92), UIKit.hbox(6, [Icon.make(d["icon"], 28), name]), desc, cost, why, btn])
		var card := UIKit.panel("Card", box)
		card.custom_minimum_size.x = 246
		cards.add_child(card)
		_cards[t] = [cost, why, btn]
		main.register_target("build_" + t, btn)
		if Game.goal_build_type() == t:
			card.theme_type_variation = "CardTeal"
			scroll.ensure_control_visible.call_deferred(card)


func refresh() -> void:
	var room := maxi(0, mini(Game.cooling_capacity() - Game.cooling_used(), Game.train_length() - (Game.carriages.size() - 1)))
	_sub.text = "Room for %d more carriage%s. Cooling Modules make room for more." % [room, "" if room == 1 else "s"]
	for t in _cards:
		var parts: Array = _cards[t]
		UIKit.clear(parts[0])
		parts[0].add_child(UIKit.cost_row(Game.build_cost(t), 24))
		var why := Game.build_block_reason(t)
		parts[1].text = why
		parts[2].disabled = why != ""

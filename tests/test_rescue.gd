extends SceneTree
## Physics check for the pull-the-pin rescue layouts (deterministic frame steps):
##   godot --headless --path . --fixed-fps 60 -s tests/test_rescue.gd
## Every layout must be won by its intended pins and lost by a wrong one.

const CASES := [
	[0, [0], "won"], [0, [1], "lost"],
	[1, [1], "won"], [1, [0, 1], "lost"],
	[2, [0, 1], "won"], [2, [2], "lost"],
]

var fails := 0


class FakeMain extends Node:
	func safe_top() -> float:
		return 0.0


func _initialize() -> void:
	var g: Node = root.get_node("Game")
	g.autosave = false
	var fake := FakeMain.new()
	root.add_child(fake)
	# Loaded at runtime: compiling it with this script would happen before autoloads exist.
	var rescue_script: GDScript = load("res://scripts/rescue/rescue_game.gd")
	for c in CASES:
		var game = rescue_script.new()
		game.main = fake
		game.layout = c[0]
		var result := [""]
		game.finished.connect(func(won: bool): result[0] = "won" if won else "lost")
		root.add_child(game)
		await _frames(60) # let the balls settle on the pins
		for p in c[1]:
			game.pull(p)
			await _frames(90)
		var waited := 0
		while game.state == "play" and waited < 900:
			await _frames(10)
			waited += 10
		var ok: bool = game.state == c[2]
		if not ok:
			fails += 1
			printerr("FAIL: layout %d pins %s -> %s (cool in pod %d, hot in pod %d), expected %s" % [c[0], str(c[1]), game.state,
				game.count_in_pod("cool"), game.count_in_pod("hot"), c[2]])
		else:
			print("ok   layout %d pins %s -> %s" % [c[0], str(c[1]), game.state])
		game.queue_free()
		await _frames(2)
	print("\n%s (%d failures)" % ["PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for k in n:
		await physics_frame

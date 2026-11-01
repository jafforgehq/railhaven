extends Node
## Dev-only screenshot tour: godot --path . --resolution 720x1280 -- --shots=<dir> [--regions]
## Walks the home screen, puzzle states and popups and saves PNGs so layouts can be reviewed
## without a device. Autosave is off, so the real save is never written.

var dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.substr(8)
	if dir == "":
		queue_free()
		return
	Game.autosave = false
	if OS.get_cmdline_user_args().has("--regions"):
		_regions.call_deferred()
	else:
		_tour.call_deferred()


func _shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("shot ", name)


func _close_all(main: Node) -> void:
	while not main._modal_stack.is_empty():
		main.close_modal()
	await get_tree().create_timer(0.2).timeout


func _tour() -> void:
	var main: Node = get_parent()
	await get_tree().create_timer(0.3).timeout
	await _close_all(main)
	Game.new_game()
	Game.intro_seen = true
	main.world.on_region_started()
	main._rebuild_plates()
	main.show_home()
	await _shot("01_home")
	main.play()
	await _shot("02_level1")
	# Tutorial: lift the first tank.
	main.puzzle.view._tap(0)
	await _shot("03_level1_lifted", 0.4)
	main.puzzle.view._tap(2)
	await _shot("04_level1_poured", 0.8)
	# Win level 1 by solving it.
	for m in [[1, 0], [1, 2], [0, 1], [0, 2]]:
		main.puzzle.view._tap(m[0])
		main.puzzle.view._tap(m[1])
		await get_tree().create_timer(0.45).timeout
	await _shot("05_win", 1.8)
	await _close_all(main)
	main.show_home()
	await _shot("06_home_restore")
	Game.complete_task()
	await _shot("07_restored", 1.0)
	# The next carriage waits as an outline that fills with every win.
	Game.parts = 1
	main._refresh()
	await _shot("07b_ghost_half", 1.2)
	Game.parts = 2
	Game.complete_task()
	Game.parts = 4
	Game.complete_task()
	await _shot("07c_four_carriages", 1.2)
	# A bigger level: two rows, some ash-covered canisters.
	Game.level = 45
	main.play()
	await _shot("08_level45", 0.8)
	main.puzzle.heat = 64.0
	await _shot("09_hot", 0.5)
	main.puzzle.heat = Data.HEAT_MAX
	main.puzzle._overheat()
	await _shot("10_overheated", 1.2)
	await _close_all(main)
	main.show_home()
	Game.condenser_at = Game.now() - 6 * 3600.0
	Popups.condenser(main)
	await _shot("11_condenser")
	await _close_all(main)
	Popups.shop(main)
	await _shot("12_shop")
	await _close_all(main)
	Game.lives = 0
	main._refresh()
	Popups.out_of_lives(main)
	await _shot("13_no_lives")
	await _close_all(main)
	Game.lives = Data.MAX_LIVES
	Game.parts = 99
	while not Game.region_done:
		Game.complete_task()
	await _shot("14_region_done", 1.5)
	await _close_all(main)
	main._refresh()
	await _shot("15_home_depart")
	get_tree().quit()


## Every region's home screen with its landmark restored.
func _regions() -> void:
	var main: Node = get_parent()
	await get_tree().create_timer(0.3).timeout
	await _close_all(main)
	Game.new_game()
	Game.intro_seen = true
	Game.parts = 999
	for r in Data.REGIONS.size():
		while not Game.region_done:
			Game.complete_task()
		await _close_all(main)
		main.show_home()
		await _shot("r%d_%s" % [r + 1, Game.region()["scenery"]], 1.2)
		if not Game.advance_region():
			break
	get_tree().quit()

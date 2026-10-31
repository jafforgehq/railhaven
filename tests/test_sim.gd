extends SceneTree
## Headless economy self-check: godot --headless --path . -s tests/test_sim.gd
## Uses the Game autoload with saving disabled (no user save is touched).

var fails := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: ", msg)
	else:
		print("ok   ", msg)


func _initialize() -> void:
	await process_frame
	var g: Node = root.get_node("Game")
	g.autosave = false
	g.set_process(false)
	g.new_game()

	# Starting state.
	check(g.carriages.size() == 4, "starts with locomotive + 3 carriages")
	check(g.capacity() == 6 and g.survivors.size() == 4, "4/6 survivors")

	# Offline: 8h with no food production must never go negative, must engage safe mode, nobody lost.
	var pop: int = g.survivors.size()
	var r: Dictionary = g.run_offline(8 * 3600.0)
	check(g.res["food"] >= 0.0 and g.res["water"] >= 0.0, "no negative food/water offline")
	check(r["safe_mode"], "safe mode engaged when supplies ran out offline")
	check(g.survivors.size() >= pop, "no survivors lost offline")
	for k in Data.RES:
		check(g.res[k] <= g.storage(k) + 0.01, "%s within storage after offline" % k)

	# Workshop converts scrap to parts at 2:1.
	g.new_game()
	var mara: Dictionary = g.survivors[0]
	check(g.assign(mara["id"], g.first_of("workshop")["uid"]), "assign Mara to workshop")
	check(g.goal_index == 1, "first goal completes on assignment")
	var s0: float = g.res["scrap"]
	var p0: float = g.res["parts"]
	g._sim(10.0)
	var made: float = g.res["parts"] - p0
	check(made > 0.0, "workshop produced parts")
	check(absf((s0 - g.res["scrap"]) - made * 2.0) < 0.01 or g.res["scrap"] > s0, "scrap consumed 2:1 (or drones delivered)")

	# Building respects cooling capacity.
	g.res["scrap"] = 5000.0
	g.res["parts"] = 5000.0
	check(g.build("greenhouse") > 0, "build greenhouse")
	check(g.build_block_reason("recycler") == "Needs more cooling capacity", "recycler blocked by cooling")
	check(g.build("cooling") > 0, "build cooling module")
	check(g.build("recycler") > 0, "recycler after cooling")
	var gh: Dictionary = g.first_of("greenhouse")
	check(g.upgrade(gh["uid"]) and gh["level"] == 2, "upgrade greenhouse")

	# Drones deliver scrap over a full run.
	var bay: Dictionary = g.first_of("dronebay")
	g.res["scrap"] = 0.0
	g._sim(Data.DRONE_RUN_TIME + 0.1)
	check(g.res["scrap"] > 0.0, "drone run delivered scrap")

	# Events: auto safe mode after timeout.
	g.start_event("heatwave")
	g._tick_event(30.0)
	check(g.event.get("choice", "") == "b", "heatwave auto-selects safe mode")
	check(is_equal_approx(g.efficiency(), 0.7), "safe mode reduces production 30%")
	g._tick_event(200.0)
	check(g.event.is_empty(), "event ends")

	check(g.event_timer > 100.0, "starting an event re-arms the event timer")

	# Train never fills up with carriages the chapter does not need.
	g.new_game()
	g.res["scrap"] = 99999.0
	g.res["parts"] = 99999.0
	g.build("cooling")
	g.build("cooling")
	while g.build("quarters") > 0:
		pass
	check(g.build_block_reason("quarters").begins_with("Room reserved"), "free slots reserved for goal carriages")
	check(g.build("greenhouse") > 0 and g.build("recycler") > 0, "reserved goal carriages can still be built")

	# Building the recycler first must not dead-end the greenhouse goal: detour to cooling.
	g.new_game()
	g.res["scrap"] = 5000.0
	g.res["parts"] = 5000.0
	g.goal_index = 2 # "Build a Greenhouse"
	g.build("recycler")
	check(g.build_block_reason("greenhouse") == "Needs more cooling capacity", "greenhouse blocked after early recycler")
	check(g.goal_build_type() == "cooling", "tutorial detours to a Cooling Module")
	g.build("cooling")
	check(g.goal_build_type() == "greenhouse" and g.build("greenhouse") > 0, "greenhouse buildable after cooling")

	# Tower chapter.
	g.distance = Data.TOWER_DISTANCE
	g.res["scrap"] = 5000.0
	g.res["parts"] = 5000.0
	g.res["water"] = 5000.0
	while g.max_level("dronebay") < 3:
		g.upgrade(g.first_of("dronebay")["uid"])
	while g.max_level("workshop") < 3:
		g.upgrade(g.first_of("workshop")["uid"])
	while g.survivors.size() < 10:
		g.survivors.append(g._make_survivor())
	for i in 3:
		g.res["parts"] = 5000.0
		g.res["water"] = 5000.0
		check(g.start_expedition(), "launch stage %d" % (i + 1))
		g._sim(130.0)
	check(g.chapter_done, "chapter complete after 3 stages")
	g.chapter_done = false
	g.tower_stage = 2
	g.res["parts"] = 5000.0
	g.start_expedition()
	var seen := [false]
	g.chapter_complete.connect(func(): seen[0] = true)
	g.run_offline(600.0)
	check(seen[0] and g.chapter_done, "chapter completion during offline time is announced")

	# Save round-trip.
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var before: int = g.carriages.size()
	g.from_dict(d)
	check(g.carriages.size() == before and typeof(g.carriages[0]["uid"]) == TYPE_INT, "save round-trip keeps carriages with int ids")

	print("\n%s (%d failures)" % ["PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)

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
	g.distance = g.landmark_distance()
	g.res["scrap"] = 5000.0
	g.res["parts"] = 5000.0
	g.res["water"] = 5000.0
	while g.max_level("dronebay") < 3:
		g.upgrade(g.first_of("dronebay")["uid"])
	while g.max_level("workshop") < 3:
		g.upgrade(g.first_of("workshop")["uid"])
	while g.survivors.size() < 10:
		g.survivors.append(g._make_survivor())
	g.res["parts"] = 0.0
	check(g.stage_shortfall().begins_with("Needs ") and "parts" in g.stage_shortfall(), "tower shortfall names the missing resource")
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

	# Next chapter.
	check(g.advance_chapter(), "depart for chapter 2")
	check(g.chapter == 1 and g.goal_index == 0 and g.distance == 0.0 and not g.chapter_done, "chapter 2 starts fresh")
	check(g.level_cap() == 6 and g.train_length() == 12, "chapter 2 raises level cap and train length")
	check(g.unlocked("cargo") and g.unlocked("lab") and not g.unlocked("medbay"), "chapter 2 unlocks cargo hold and lab")
	check(g.build_block_reason("medbay").begins_with("Unlocks in Chapter"), "med bay still locked")
	check(not g.advance_chapter(), "cannot skip a chapter")

	# Research.
	g.res["scrap"] = 50000.0
	g.res["parts"] = 50000.0
	while g.cooling_used() + 1 > g.cooling_capacity():
		g.upgrade(g.first_of("cooling")["uid"])
	var lab_uid: int = g.build("lab")
	check(lab_uid > 0, "build research lab")
	var sci: Dictionary = g._make_survivor("Testa", "Scientist")
	g.survivors.append(sci)
	g.assign(sci["id"], lab_uid)
	g.res["data"] = 0.0
	g._sim(60.0)
	check(g.res["data"] > 0.0, "lab produces data")
	check(g.research_block_reason("rotors1") == "Not enough resources", "research needs data")
	g.res["data"] = 100.0
	var y0: float = g.drone_yield(g.first_of("dronebay"))
	check(g.start_research("rotors1"), "start research")
	check(g.research_block_reason("drip1") == "Another project is running", "one project at a time")
	g._sim(400.0)
	check(g.research_done.has("rotors1") and g.research_id == "", "research completes")
	check(g.drone_yield(g.first_of("dronebay")) > y0 * 1.15, "research boosts drone haul")
	check(g.research_block_reason("swarm1") != "" and not g.research_list().any(func(r): return r["id"] == "swarm1"), "later research hidden until its chapter")

	# Crew experience.
	var p0w: float = g.worker_power(g.carriage(lab_uid))
	sci["xp"] = Data.xp_for(3)
	check(g.crew_level(sci) == 3, "xp maps to level 3")
	check(g.worker_power(g.carriage(lab_uid)) > p0w, "experience raises output")
	var xp0: float = sci["xp"]
	g._sim(10.0)
	check(sci["xp"] > xp0, "working crew gain xp")

	# Storage gate and level cap.
	var wk: Dictionary = g.first_of("workshop")
	wk["level"] = g.level_cap()
	check(g.upgrade_block_reason(wk["uid"]).begins_with("Max level for now"), "chapter level cap")
	wk["level"] = 2
	g.res["parts"] = 0.0
	check(g.storage_short({"parts": 1e9}) == "parts", "storage shortfall detected")

	# Scaled events.
	check(g.event_cost("trader", "a")["scrap"] == 360, "event costs scale with the chapter")
	g.res["scrap"] = 1000.0
	g.start_event("raiders")
	g.choose_event("b")
	check(absf(g.res["scrap"] - 850.0) < 0.1 and g.event.is_empty(), "raider toll takes 15% scrap")
	g.start_event("rail")
	g.choose_event("b")
	check(g.train_speed() == 0.0, "waiting at a broken rail stops the train")
	g._tick_event(200.0)
	check(g.train_speed() > 0.0, "train moves again after the rail event")

	# Chapter data sanity: every goal and stage can be met inside its own chapter.
	for ci in Data.CHAPTERS.size():
		var chd: Dictionary = Data.CHAPTERS[ci]
		for gl in chd["goals"]:
			if gl.has("arg"):
				check(Data.CARRIAGES.has(gl["arg"]) and int(Data.CARRIAGES[gl["arg"]].get("chapter", 0)) <= ci, "ch%d goal '%s' uses an unlocked carriage" % [ci + 1, gl["text"]])
			if gl["kind"] in ["level", "any_level"]:
				check(gl["n"] <= chd["level_cap"], "ch%d goal '%s' within level cap" % [ci + 1, gl["text"]])
			if gl["kind"] == "research":
				check(gl["n"] <= Data.RESEARCH.filter(func(r): return r["chapter"] <= ci).size(), "ch%d research goal reachable" % (ci + 1))
		check(chd["goals"][-1]["kind"] == "tower" and chd["goals"][-1]["n"] == chd["stages"].size(), "ch%d ends with its landmark" % (ci + 1))
		for st in chd["stages"]:
			for k in st["req"]:
				if k != "survivors":
					check(st["req"][k] <= chd["level_cap"] and int(Data.CARRIAGES[k].get("chapter", 0)) <= ci, "ch%d stage '%s' req %s reachable" % [ci + 1, st["name"], k])

	# v1 save (one chapter, tower restored) loads into the departure flow.
	var v1 := {"version": 1, "time": 0, "res": {"scrap": 10, "parts": 5, "food": 50, "water": 50},
		"carriages": [{"uid": 1, "type": "locomotive", "level": 2}, {"uid": 2, "type": "quarters", "level": 3}],
		"survivors": [{"id": 1, "name": "Mara", "role": "Engineer", "job": 0, "look": {}}],
		"goal_index": 11, "tower_stage": 3, "chapter_done": true, "chapter_seen": true, "distance": 300.0}
	g.from_dict(v1)
	check(g.chapter == 0 and g.chapter_done and g.res["data"] == 0.0 and g.survivors[0]["xp"] == 0.0, "v1 save migrates")
	check(g.advance_chapter() and g.chapter == 1, "v1 save can depart for chapter 2")

	# Save round-trip.
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var before: int = g.carriages.size()
	g.from_dict(d)
	check(g.carriages.size() == before and typeof(g.carriages[0]["uid"]) == TYPE_INT, "save round-trip keeps carriages with int ids")
	g.research_done = ["rotors1"]
	g.research_id = "drip1"
	g.research_left = 99.0
	g.survivors[0]["xp"] = 1234.0
	d = JSON.parse_string(JSON.stringify(g.to_dict()))
	g.from_dict(d)
	check(g.chapter == 1 and g.research_done == ["rotors1"] and g.research_id == "drip1" and g.survivors[0]["xp"] == 1234.0, "save keeps chapter, research and xp")
	check(g.bonus("drone") > 0.0, "research bonus restored on load")

	print("\n%s (%d failures)" % ["PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)

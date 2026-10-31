extends SceneTree
## Greedy bot plays chapter 1 headless to check pacing and that it is completable.
## godot --headless --path . -s tests/bot_playthrough.gd

func _initialize() -> void:
	await process_frame
	var g: Node = root.get_node("Game")
	g.autosave = false
	g.set_process(false)
	g.new_game()
	var t := 0.0
	var last_goal := -1
	var dt := 1.0
	while t < 4.0 * 3600.0 and not g.chapter_done:
		g._sim(dt)
		g._tick_event(dt)
		if not g.event.is_empty() and g.event["choice"] == "":
			if not g.choose_event("a"):
				g.choose_event("b")
		g._check_goals()
		t += dt
		if int(t) % 5 == 0:
			_act(g)
		if g.expedition >= 0.0 and int(t) % 60 == 0:
			print("   expedition stage %d running at %.1f min" % [g.tower_stage, t / 60.0])
		if g.goal_index != last_goal:
			last_goal = g.goal_index
			print("%6.1f min  goal %d  surv %d  scrap %d parts %d food %d water %d  carriages %d" % [t / 60.0, g.goal_index, g.survivors.size(), g.res["scrap"], g.res["parts"], g.res["food"], g.res["water"], g.carriages.size()])
	print("chapter done: %s at %.1f min, rationing=%s" % [g.chapter_done, t / 60.0, g.rationing])
	quit()


func _act(g: Node) -> void:
	g.auto_assign()
	g.start_expedition()
	var goal: Dictionary = g.current_goal()
	var r: Dictionary = g.rates()
	var wants: Array = []
	if not goal.is_empty():
		match goal["kind"]:
			"build": wants.append(["build", goal["arg"]])
			"level": wants.append(["up", goal["arg"]])
			"survivors": wants.append(["up", "quarters"])
			"tower":
				var st: Dictionary = Data.TOWER_STAGES[mini(g.tower_stage, 2)]
				for k in st["req"]:
					if k != "survivors" and g.max_level(k) < st["req"][k]:
						wants.append(["up", k] if g.count_type(k) > 0 else ["build", k])
				if st["req"].has("survivors") and g.survivors.size() < st["req"]["survivors"]:
					wants.append(["up", "quarters"])
	if r["food"] < 0.5 and g.count_type("greenhouse") > 0:
		wants.append(["up", "greenhouse"])
	if r["water"] < 0.5 and g.count_type("recycler") > 0:
		wants.append(["up", "recycler"])
	if g.survivors.size() >= g.capacity():
		wants.append(["up", "quarters"])
	if g.idle_survivors().size() > 0:
		wants.append(["up", "workshop"])
	wants.append(["up", "dronebay"])
	if g.build_block_reason("greenhouse") == "Needs more cooling capacity":
		wants.append(["up", "cooling"])
	# Save up for the current goal instead of spending on side upgrades.
	if not goal.is_empty() and goal["kind"] in ["build", "level", "tower"] and r["food"] >= 0.0 and r["water"] >= 0.0:
		wants = wants.slice(0, 1)
		if goal["kind"] == "tower" and wants.is_empty() and g.idle_survivors().size() > 1 and g.res["scrap"] > 250:
			wants.append(["build", "workshop"])
	for w in wants:
		if w[0] == "build":
			if g.build(w[1]) > 0:
				return
			if g.build_block_reason(w[1]) == "Needs more cooling capacity" and g.count_type("cooling") > 0:
				g.upgrade(g.first_of("cooling")["uid"])
		else:
			var c: Dictionary = g.first_of(w[1])
			if not c.is_empty() and g.upgrade(c["uid"]):
				return

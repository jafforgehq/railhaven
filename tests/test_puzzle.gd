extends SceneTree
## Headless self-check: godot --headless --path . -s tests/test_puzzle.gd
## Covers the sort rules, every authored level's data, and the progress systems.
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
	_board_rules()
	_levels()
	_progress(g)
	print("\n%s (%d failures)" % ["PASS" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)


func _board_rules() -> void:
	var b := SortBoard.new()
	b.load_level({"tanks": [[0, 1, 0, 0], [1, 0, 1, 1], []], "hidden": [[false, false, false, false], [false, false, false, false], []]})
	check(b.top_run(0) == 2 and b.top_run(1) == 2, "top run counts matching canisters")
	check(b.can_pour(0, 1) == 0, "cannot pour onto a different colour")
	check(b.can_pour(0, 2) == 2, "pour moves the whole run into an empty tank")
	var r := b.pour(0, 2)
	check(r["n"] == 2 and b.tanks[0] == [0, 1] and b.tanks[2] == [0, 0], "pour result")
	check(b.can_pour(1, 0) == 2, "run of 2 fits onto a matching top")
	b.pour(1, 0)
	b.pour(1, 2)
	check(b.can_pour(0, 1) == 3 and not b.is_won(), "three onto one")
	r = b.pour(0, 1)
	check(r["completed"] and b.is_complete(1), "a full single-colour tank is complete")
	check(b.can_pour(1, 2) == 0, "complete tanks are locked")
	b.pour(0, 2)
	check(b.is_won(), "level 1 solution wins")
	check(b.undo() and not b.is_won() and b.tanks[0] == [0], "undo reverses the last pour")

	# Capacity: only what fits moves.
	var c := SortBoard.new()
	c.load_level({"tanks": [[2, 0, 0, 0], [1, 1, 0], [1, 1]]})
	check(c.can_pour(0, 1) == 1, "pour stops at capacity")

	# Ash-covered canisters: revealed when exposed, hidden again on undo, run stops at them.
	var h := SortBoard.new()
	h.load_level({"tanks": [[3, 1, 2, 2], [2], []], "hidden": [[true, true, false, false], [false], []]})
	check(h.top_run(0) == 2, "run includes visible canisters only")
	h.pour(0, 2)
	check(not h.hidden[0][1], "pouring exposes the next canister")
	h.undo()
	check(h.hidden[0][1], "undo hides it again")
	var full := SortBoard.new()
	full.load_level({"tanks": [[5, 5, 5], [5], []], "hidden": [[true, true, false], [false], []]})
	r = full.pour(1, 0)
	check(r["completed"] and not full.hidden[0][0], "completing a tank reveals its ash")

	# Frozen tank: no pours in or out until enough tanks are sealed; undo refreezes it.
	var f := SortBoard.new()
	f.load_level({"tanks": [[0, 0, 0], [1, 1, 1, 0], [1], []], "frozen": [0, 1, 0, 0]})
	check(f.is_frozen(1) and f.can_pour(1, 3) == 0 and f.can_pour(2, 1) == 0, "frozen tank is shut")
	r = f.pour(1, 0)
	check(r.is_empty(), "cannot pour out of a frozen tank")
	f.frozen[1] = 1
	var g := SortBoard.new()
	g.load_level({"tanks": [[0, 0, 0], [1, 1, 1, 0], [0], []], "frozen": [0, 1, 0, 0]})
	r = g.pour(2, 0)
	check(r["completed"] and r["thawed"] == [1] and not g.is_frozen(1), "sealing a tank thaws it")
	check(g.can_pour(1, 3) == 1, "a thawed tank pours")
	g.undo()
	check(g.is_frozen(1), "undoing the seal refreezes it")

	# Tagged tank only takes its colour.
	var t := SortBoard.new()
	t.load_level({"tanks": [[0, 1], [1, 0], []], "lock": [-1, -1, 1]})
	check(t.can_pour(0, 2) == 1 and t.can_pour(1, 2) == 0, "tagged tank only accepts its colour")

	# Hot canister: counts down per pour, flares at zero, defused when its tank is sealed.
	var hc := SortBoard.new()
	hc.load_level({"tanks": [[2, 2, 2], [2], [3, 3], []], "hot": [[1, 0, 2]]})
	r = hc.pour(2, 3)
	check(r["flared"] == 0 and hc.hot_left() == [1], "hot canister counts down")
	hc.undo()
	check(hc.hot_left() == [2], "undo restores the countdown")
	r = hc.pour(1, 0)
	check(r["completed"] and r["defused"] == 1 and hc.hot_left().is_empty(), "sealing defuses it")
	var hf := SortBoard.new()
	hf.load_level({"tanks": [[2, 2, 2], [2], [3, 3], []], "hot": [[1, 0, 1]]})
	r = hf.pour(2, 3)
	check(r["flared"] == 1 and hf.hot_left().is_empty(), "countdown at zero flares once")
	hf.add_tank()
	hf.undo()
	check(hf.hot.size() == hf.tanks.size(), "undo after a spare tank keeps flags aligned")

	# Padlocked tank opens when its colour is sealed.
	var kl := SortBoard.new()
	kl.load_level({"tanks": [[0, 0, 0], [0], [1, 1], []], "keylock": [-1, -1, -1, 0]})
	check(kl.is_keylocked(3) and kl.can_pour(2, 3) == 0, "padlocked tank is shut")
	r = kl.pour(1, 0)
	check(r["thawed"] == [3] and kl.can_pour(2, 3) == 2, "sealing the key colour opens it")

	# Rust welds a canister until its tank or a neighbour seals; it creeps when idle.
	var ru := SortBoard.new()
	ru.load_level({"tanks": [[2, 2, 2], [3, 1], [2], [1, 1, 1], []], "rust": [[], [false, true], [], [], []]})
	check(ru.top_run(1) == 0 and ru.can_pour(1, 3) == 0, "rusted top canister cannot move")
	r = ru.pour(2, 0)
	check(r["completed"] and not ru.rust[1][1], "sealing the tank beside it scrubs the rust")
	var rs := SortBoard.new()
	rs.load_level({"tanks": [[0, 1, 0], [2, 3], [], []], "rust": [[true, false, false], [], [], []]})
	rs.pour(1, 2)
	rs.pour(2, 3)
	rs.pour(3, 2)
	var rusty := 0
	for row in rs.rust:
		rusty += row.count(true)
	check(rusty == 2, "rust creeps after %d idle pours" % SortBoard.RUST_SPREAD)
	rs.undo()
	rusty = 0
	for row in rs.rust:
		rusty += row.count(true)
	check(rusty == 1, "undo takes the creep back")

	# Twin tanks share a pour one canister each.
	var tw := SortBoard.new()
	tw.load_level({"tanks": [[0, 0, 0, 0].slice(0, 3) + [], [], [], [1, 1]], "twin": [-1, 2, 1, -1]})
	r = tw.pour(0, 1)
	check(r["n"] == 3 and tw.tanks[1].size() == 2 and tw.tanks[2].size() == 1, "twins split a pour in turn")
	tw.undo()
	check(tw.tanks[0].size() == 3 and tw.tanks[1].is_empty() and tw.tanks[2].is_empty(), "undo gathers a split pour back")

	# Conveyor: rows shift every N pours, undo slides back.
	var cv := SortBoard.new()
	cv.load_level({"tanks": [[0, 1], [1, 0], [], []], "conveyor": 2})
	cv.pour(0, 2)
	cv.pour(1, 3)
	check(cv.shift() == 1, "conveyor shifts after 2 pours")
	cv.undo()
	check(cv.shift() == 0, "undo shifts back")

	# Goals: rescue wins once its colours are sealed; order blocks out-of-turn seals.
	var gc := SortBoard.new()
	gc.load_level({"tanks": [[0, 0, 0], [0], [1, 2], [2, 1], []], "goal": {"type": "colors", "colors": [0]}})
	gc.pour(1, 0)
	check(gc.is_won(), "rescue goal wins with other tanks still mixed")
	var go := SortBoard.new()
	go.load_level({"tanks": [[0, 0, 0], [0], [1, 1, 1], [1]], "goal": {"type": "order", "colors": [1, 0]}})
	check(go.can_pour(1, 0) == 0 and go.block_reason(1, 0).begins_with("Seal"), "order goal blocks sealing out of turn")
	check(go.can_pour(3, 2) == 1, "the next colour in order may seal")

	# Combo charges.
	var mg := SortBoard.new()
	mg.load_level({"tanks": [[1, 0], [2, 0], [0, 0], [], [1, 2, 1, 2]]})
	var pulled := mg.magnet(2)
	check(pulled.size() == 2 and mg.is_complete(2), "magnet pulls every matching top into the tank")
	var fc := SortBoard.new()
	fc.load_level({"tanks": [[0, 0, 0], [1, 1], []], "frozen": [0, 3, 0], "rust": [[true], [], []], "hot": [[0, 1, 2]]})
	fc.frost_charge()
	check(not fc.is_frozen(1) and not fc.rust[0][0] and fc.hot_left() == [7], "frost charge thaws, scrubs rust and buys time")

	# Stuck detection and the spare tank.
	var s := SortBoard.new()
	s.load_level({"tanks": [[0, 1, 0, 1], [1, 0, 1, 0]]})
	check(s.is_stuck(), "no legal pour = stuck")
	s.add_tank()
	check(not s.is_stuck() and s.tanks.size() == 3, "spare tank unsticks")


func _levels() -> void:
	var n: int = root.get_node("Game").level_count()
	check(n >= 1000, "1000 authored levels (%d)" % n)
	var ok := true
	var bad := ""
	for i in range(1, n + 1):
		var d: Dictionary = root.get_node("Game").level_data(i)
		var counts := {}
		var cap_ok := true
		for t in d["tanks"]:
			cap_ok = cap_ok and t.size() <= Data.CAPACITY
			for x in t:
				counts[int(x)] = counts.get(int(x), 0) + 1
		var each_four := counts.values().all(func(v): return v == Data.CAPACITY)
		var empties: int = d["tanks"].filter(func(t): return t.is_empty()).size()
		var fine: bool = cap_ok and each_four and empties >= 1 and int(d["moves"]) >= int(d["solution"]) and counts.size() <= Data.COLORS.size()
		var nt: int = d["tanks"].size()
		fine = fine and nt <= 12 and d.get("frozen", []).all(func(x): return int(x) < counts.size())
		fine = fine and d.get("lock", []).all(func(x): return int(x) < counts.size()) and d.get("frozen", []).size() in [0, nt]
		for h in d.get("hot", []):
			fine = fine and int(h[0]) < nt and int(h[1]) < d["tanks"][int(h[0])].size() and int(h[2]) > 0 and int(h[2]) < int(d["moves"])
		if not fine:
			ok = false
			bad = "level %d" % i
			break
	check(ok, "every level has 4 of each colour, an empty tank, sane blockers and a move budget >= its solution %s" % bad)
	var first := {}
	for i in range(1, n + 1):
		for k in Data.level_blockers(root.get_node("Game").level_data(i)):
			if not first.has(k):
				first[k] = i
	var want := {"frozen": 16, "hidden": 31, "lock": 46, "hot": 66, "keylock": 81, "rescue": 96, "rust": 111, "conveyor": 126, "twin": 141, "order": 161}
	check(first == want, "blockers arrive one at a time %s" % str(first))
	for k in Data.BLOCKERS:
		check(Data.BLOCKERS[k].has("text"), "intro text for %s" % k)
	check(root.get_node("Game").boss_data(4).get("boss", false), "five landmark boss levels")

	# Replay the generator's solutions on this board: proves the solver and the game agree.
	var sols: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/solutions.json"))
	var replay_ok := true
	var replay_bad := ""
	var cases := []
	for key in sols["levels"]:
		cases.append([root.get_node("Game").level_data(int(key)), sols["levels"][key], "level " + key])
	for b in sols["bosses"].size():
		cases.append([root.get_node("Game").boss_data(b), sols["bosses"][b], "boss %d" % b])
	for c in cases:
		var rb := SortBoard.new()
		rb.load_level(c[0])
		rb.rust_spreads = false
		for row in rb.hidden: # the solver sees through ash
			row.fill(false)
		var good := true
		for mv in c[1]:
			if rb.can_pour(int(mv[0]), int(mv[1])) != int(mv[2]):
				good = false
				break
			rb.pour(int(mv[0]), int(mv[1]))
		if not good or not rb.is_won():
			replay_ok = false
			replay_bad = c[2]
			break
	check(replay_ok, "%d solver solutions replay to a win on the game board %s" % [cases.size(), replay_bad])
	var late: Dictionary = root.get_node("Game").level_data(n + 846)
	check(late.has("lock") and late["lock"].all(func(x): return int(x) < Data.COLORS.size()), "repeated levels keep valid tag colours")
	var big: Dictionary = root.get_node("Game").level_data(n + 57)
	check(big["tanks"].size() >= 9, "levels past the authored set repeat with shuffled colours")
	check(root.get_node("Game").level_data(1)["tanks"].size() == 3, "level 1 is the hand-made tutorial")


func _progress(g: Node) -> void:
	g.new_game()
	check(g.lives == Data.MAX_LIVES and g.scrap == Data.START_SCRAP and g.level == 1, "new game")
	check(g.carriages.size() == 1 and g.count_type("locomotive") == 1, "train starts as the locomotive alone")
	check(not g.has_condenser() and not g.condenser_ready() and g.condenser_upgrade_block() != "", "no Condenser earnings before it is coupled")
	check(g.next_build() == "cooling" and g.task_progress() == 0.0, "first task assembles the Cooling Core")

	# Winning pays parts and scrap, heatwave levels pay double parts.
	var r: Dictionary = g.win_level(50.0)
	check(r["parts"] == 1 and r["scrap"] == Data.WIN_SCRAP + 20 and g.level == 2, "win pays 1 part + scrap + cool bonus")
	g.level = 10
	r = g.win_level(69.0)
	check(r["hard"] and r["parts"] == 2, "heatwave level pays 2 parts")

	# Tasks grow the train in order; the landmark ends the region.
	g.parts = 0
	check(g.task_block_reason().begins_with("Need"), "task needs parts")
	g.parts = 1
	check(g.task_progress() == 1.0 and g.complete_task() and g.carriages.size() == 2 and g.level_of("cooling") == 1, "first task couples the Cooling Core")
	g.parts = 1
	check(g.next_build() == "condenser" and is_equal_approx(g.task_progress(), 0.5), "half the parts for the Condenser")
	g.parts = 100
	g.complete_task()
	check(g.has_condenser() and not g.condenser_ready(), "a new Condenser starts empty")
	var sizes := []
	while not g.region_done:
		g.complete_task()
		sizes.append(g.carriages.size())
	check(g.region_done and g.landmark_visibility() == 1.0 and g.next_build() == "", "landmark task restores the region")
	check(g.carriages.size() == 7, "region 1 grows the train to 7 carriages (%d)" % g.carriages.size())
	var total := 0
	for reg in Data.REGIONS:
		for t in reg["tasks"]:
			total += int(t["cost"])
	check(total < 0.85 * g.level_count(), "the whole journey fits inside the authored levels (%d parts)" % total)
	check(g.advance_region() and g.region_index == 1 and g.task_index == 0, "depart for region 2")
	check(g.start_heat() < Data.HEAT_START, "an upgraded Cooling Core starts puzzles cooler")

	# Lives: losing costs one, they regenerate over time.
	g.lives = Data.MAX_LIVES
	g.lose_life()
	check(g.lives == Data.MAX_LIVES - 1, "losing costs a life")
	g.lives_at = g.now() - Data.LIFE_REGEN * 2.5
	g.lives = 1
	g._tick_lives()
	check(g.lives == 3, "lives regenerate one per %d s" % int(Data.LIFE_REGEN))

	# Condenser: fills over time up to its cap, a full tank adds a booster.
	g.condenser_at = g.now() - 60.0
	check(not g.condenser_ready(), "condenser needs a few minutes")
	g.condenser_at = g.now() - 100 * 3600.0
	check(g.condenser_full() and g.condenser_amount() == int(Data.condenser_rate(1) * Data.condenser_cap_hours(1)), "condenser caps at %d h" % int(Data.condenser_cap_hours(1)))
	var boosters_before: int = Data.BOOSTER_ORDER.map(func(b): return g.booster_count(b)).reduce(func(a, b): return a + b)
	var s0: int = g.scrap
	var got: Dictionary = g.claim_condenser(2)
	var boosters_after: int = Data.BOOSTER_ORDER.map(func(b): return g.booster_count(b)).reduce(func(a, b): return a + b)
	check(g.scrap == s0 + got["scrap"] and got["scrap"] == 2 * int(Data.condenser_rate(1) * 8.0) and boosters_after == boosters_before + 1, "claim x2 pays and a full tank adds a booster")
	g.scrap = 10000
	check(g.upgrade_condenser() and g.condenser_level() == 2 and Data.condenser_cap_hours(2) > Data.condenser_cap_hours(1), "condenser upgrade raises rate and cap")

	# Boosters and daily drop.
	g.scrap = 1000
	var u: int = g.booster_count("undo")
	check(g.buy_booster("undo") and g.booster_count("undo") == u + 1, "buy a booster")
	check(g.use_booster("undo") and g.booster_count("undo") == u, "use a booster")
	var meta: Node = root.get_node("Meta")
	check(meta.cal_ready() and meta.cal_day() == 0, "calendar starts at day 1")
	var s1: int = g.scrap
	check(not meta.claim_calendar().is_empty() and not meta.cal_ready() and meta.cal_day() == 1 and g.scrap == s1 + 100, "calendar pays once per day and advances")
	check(meta.claim_calendar().is_empty(), "no second claim on the same day")
	g.meta["cal_date"] = "2000-01-01"
	g.meta["cal_day"] = 6
	var day7: Dictionary = meta.claim_calendar()
	check(day7.has("pre_cool") and meta.cal_day() == 0, "day 7 pays the big crate and the week restarts")

	# Win streak gives free pre-level boosters; picked ones use stock first, then scrap.
	g.stats["streak"] = 0
	check(meta.streak_free().is_empty(), "no streak, no freebies")
	g.stats["streak"] = 2
	g.boosters["pre_ash"] = 0
	g.scrap = 1000
	var paid: Dictionary = meta.take_pre(["pre_ash", "pre_cool"])
	check(paid["ok"] and paid["apply"].size() == 3 and g.scrap == 1000 - int(meta.PRE["pre_ash"]["price"]), "streak 2: cool start and extra tank free, ash sweep bought")
	g.scrap = 0
	check(not meta.take_pre(["pre_ash"])["ok"], "cannot buy pre-level boosters without scrap")
	g.lose_life()
	check(meta.streak() == 0, "a loss resets the streak")

	# Juno speaks one-time lines once; liveries, postcards.
	check(meta.story_line("built_greenhouse") != "" and meta.story_line("built_greenhouse") == "", "one-time story lines play once")
	var picks: Array = meta.livery_choices(7)
	check(picks.size() == 3 and picks[0]["color"] != picks[1]["color"] and meta.livery_choices(7) == picks, "three stable livery choices per carriage")
	meta.set_livery(g.carriages[1]["uid"], "c4572e")
	g.meta["cards"] = []
	g.region_index = 0
	var first_card: Dictionary = meta.roll_card(true)
	check(first_card["new"] and meta.has_card(first_card["id"]), "a postcard drop adds a new card")
	g.meta["cards"] = meta.ALBUM[0]["cards"].map(func(c): return c[0])
	var sc: int = g.scrap
	var dupe: Dictionary = meta.roll_card(true)
	check(not dupe["new"] and g.scrap == sc + meta.CARD_DUPLICATE_SCRAP, "a duplicate postcard pays scrap")
	g.meta["cards"] = meta.ALBUM[0]["cards"].slice(1).map(func(c): return c[0])
	var bonus_before: int = g.booster_count("pre_tank")
	var got_card := {}
	for k in 50:
		got_card = meta.roll_card(true)
		if got_card["set_done"]:
			break
	check(got_card["set_done"] and g.booster_count("pre_tank") == bonus_before + 1, "completing a set pays its reward")

	# Save round-trip.
	g.tutorial["blk_frozen"] = true
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var lv: int = g.level
	var reg: int = g.region_index
	g.new_game()
	g.from_dict(d)
	check(g.tutorial.get("blk_frozen", false), "blocker intro flags survive a save")
	check(g.carriages[1].get("livery", "") == "c4572e" and g.meta.get("cards", []).size() == 6, "liveries and postcards survive a save")
	check(g.level == lv and g.region_index == reg and g.condenser_level() == 2 and typeof(g.carriages[0]["uid"]) == TYPE_INT, "save round-trip")
	var old := {"version": 2, "res": {}, "carriages": []}
	check(int(old["version"]) < Data.SAVE_VERSION, "idle saves (v1/v2) are older than the puzzle save version")

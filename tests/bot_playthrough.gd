extends SceneTree
## Greedy bot plays the whole journey headless to check pacing and that it is completable.
## godot --headless --path . -s tests/bot_playthrough.gd [-- quiet] [passive]
## Reports time per chapter and the longest "wall" (stretch with nothing to buy, build,
## research or launch) so dead waits show up in numbers.

const DT := 2.0
const LIMIT_H := 60.0

var g: Node
var last_action := 0.0
var t := 0.0
var walls := [] # [chapter, start, length]
var blocked_since := {} # want key -> time first blocked


func _initialize() -> void:
	await process_frame
	g = root.get_node("Game")
	g.autosave = false
	g.set_process(false)
	g.new_game()
	var quiet := OS.get_cmdline_user_args().has("quiet")
	var ch_start := 0.0
	var last_goal := -1
	var last_ch := 0
	var gap_max := 0.0
	var gap_at := 0.0
	var chapter_times := []
	while t < LIMIT_H * 3600.0 and not g.journey_complete():
		g._sim(DT)
		g._tick_event(DT)
		if not g.event.is_empty() and g.event["choice"] == "":
			if not g.choose_event("a"):
				g.choose_event("b")
		g._check_goals()
		t += DT
		if int(t) % 6 == 0:
			_act()
		if g.chapter != last_ch:
			chapter_times.append(t - ch_start)
			print("== chapter %d done in %s (total %s) | surv %d, research %d, best crew Lv.%d" % [last_ch + 1, _h(t - ch_start), _h(t), g.survivors.size(), g.research_done.size(), g.best_crew_level()])
			ch_start = t
			last_ch = g.chapter
			last_goal = -1
		if g.goal_index != last_goal:
			last_goal = g.goal_index
			last_action = t
			if not quiet:
				var gl: Array = g.goals()
				var txt: String = gl[g.goal_index]["text"] if g.goal_index < gl.size() else "(landmark restored)"
				print("%7s ch%d goal %2d %-40s surv %2d cars %2d | %s" % [_h(t), g.chapter + 1, g.goal_index, txt, g.survivors.size(), g.carriages.size(), _levels()])
		var gap := t - last_action
		if gap > gap_max:
			gap_max = gap
			gap_at = last_action
	if g.journey_complete():
		chapter_times.append(t - ch_start)
		print("== chapter %d done in %s (total %s)" % [last_ch + 1, _h(t - ch_start), _h(t)])
	print("JOURNEY COMPLETE: %s at %s | longest wall %s (from %s) | research %d/%d | survivors %d" % [
		g.journey_complete(), _h(t), _h(gap_max), _h(gap_at), g.research_done.size(), Data.RESEARCH.size(), g.survivors.size()])
	print("CHAPTERS: " + ", ".join(chapter_times.map(func(x): return _h(x))))
	quit()


func _h(sec: float) -> String:
	return "%dh%02d" % [int(sec / 3600.0), int(fmod(sec, 3600.0) / 60.0)]


func _levels() -> String:
	var out: PackedStringArray = []
	for ty in ["locomotive", "quarters", "workshop", "dronebay", "greenhouse", "recycler", "cooling", "cargo", "lab", "medbay"]:
		if g.count_type(ty) > 0:
			out.append("%s%d%s" % [ty.substr(0, 2), g.max_level(ty), ("x%d" % g.count_type(ty)) if g.count_type(ty) > 1 else ""])
	return " ".join(out)


func _did() -> void:
	last_action = t


func _act() -> void:
	g.auto_assign()
	# Plays like an active player (claims contracts, taps Overdrive) for a worst-case pace;
	# "-- passive" skips both, like a player who only builds and upgrades.
	if not OS.get_cmdline_user_args().has("passive"):
		_active()
	_act_core()


func _active() -> void:
	for i in g.contracts.size():
		g.claim_contract(i)
	for c in g.carriages:
		g.boost(c["uid"])


func _act_core() -> void:
	if g.chapter_done and g.advance_chapter():
		_did()
		return
	if g.start_expedition():
		_did()
		if not OS.get_cmdline_user_args().has("quiet"):
			print("%7s   stage %d launched | parts %d scrap %d | %s" % [_h(t), g.tower_stage + 1, g.res["parts"], g.res["scrap"], _levels()])
	var goal: Dictionary = g.current_goal()
	if not goal.is_empty() and goal["kind"] == "assign" and g.count_type(goal["arg"]) > 0:
		if g.pull_worker(g.first_of(goal["arg"])["uid"]):
			_did()
	if g.research_id == "":
		for r in g.research_list():
			if g.start_research(r["id"]):
				_did()
				break
	var wants := _wants()
	# Save up for the most important want once it is half affordable.
	for i in wants.size():
		var w: Array = wants[i]
		var why := _try(w)
		if why == "":
			_did()
			return
		if i == 0 and why == "Not enough resources" and _half_there(w):
			return


func _cost(w: Array) -> Dictionary:
	if w[0] == "build":
		return g.build_cost(w[1])
	var c: Dictionary = _upgrade_target(w[1])
	return {} if c.is_empty() else g.upgrade_cost(c)


func _half_there(w: Array) -> bool:
	var cost := _cost(w)
	for k in cost:
		if g.res[k] < cost[k] * 0.5:
			return false
	return not cost.is_empty()


## Lowest-level carriage of a type (spreads upgrades), or the only one.
func _upgrade_target(ty: String) -> Dictionary:
	var best: Dictionary = {}
	for c in g.carriages:
		if c["type"] == ty and c["level"] < g.level_cap() and (best.is_empty() or c["level"] < best["level"]):
			best = c
	return best


func _try(w: Array) -> String:
	if w[0] == "build":
		var why: String = g.build_block_reason(w[1])
		if why == "":
			g.build(w[1])
			return ""
		if why == "Needs more cooling capacity":
			_try_grow_cooling()
		elif why.begins_with("Needs a bigger hold"):
			_try_grow_storage()
		return why
	var c := _upgrade_target(w[1])
	if c.is_empty():
		if g.count_type(w[1]) == 0 and w[1] != "locomotive":
			return _try(["build", w[1]])
		return "max"
	var why2: String = g.upgrade_block_reason(c["uid"])
	if why2 == "":
		g.upgrade(c["uid"])
		return ""
	if why2.begins_with("Needs a bigger hold"):
		_try_grow_storage()
	return why2


func _try_grow_cooling() -> void:
	var c := _upgrade_target("cooling")
	if not c.is_empty() and g.upgrade(c["uid"]):
		_did()
	elif g.build("cooling") > 0:
		_did()


func _try_grow_storage() -> void:
	if g.unlocked("cargo"):
		var c := _upgrade_target("cargo")
		if g.count_type("cargo") == 0 and g.build("cargo") > 0:
			_did()
			return
		if not c.is_empty() and g.upgrade(c["uid"]):
			_did()
			return
	var loco: Dictionary = g.first_of("locomotive")
	if g.upgrade(loco["uid"]):
		_did()


## What to spend on, most important first.
func _wants() -> Array:
	var w := []
	var goal: Dictionary = g.current_goal()
	if not goal.is_empty():
		match goal["kind"]:
			"build": w.append(["build", goal["arg"]])
			"level": w.append(["up", goal["arg"]])
			"assign":
				if g.count_type(goal["arg"]) == 0:
					w.append(["build", goal["arg"]])
				else:
					w.append(["up", goal["arg"]])
			"research":
				if g.count_type("lab") == 0:
					w.append(["build", "lab"])
				else:
					w.append(["up", "lab"])
			"survivors": w.append(["up", "quarters"])
			"any_level":
				var best: Dictionary = g.carriages[1]
				for c in g.carriages:
					if c["type"] != "locomotive" and c["level"] > best["level"]:
						best = c
				w.append(["up", best["type"]])
	if not g.chapter_done and g.tower_stage < g.stages().size():
		var st: Dictionary = g.stages()[g.tower_stage]
		for k in st["req"]:
			if k == "survivors":
				if g.survivors.size() < st["req"][k]:
					w.append(["up", "quarters"])
			elif g.max_level(k) < st["req"][k]:
				w.append(["up", k] if g.count_type(k) > 0 else ["build", k])
		if g.storage_short(st["cost"]) != "":
			w.append(["up", "cargo"] if g.unlocked("cargo") else ["up", "locomotive"])
	var r: Dictionary = g.rates()
	var n: int = g.survivors.size()
	for pair in [["food", "greenhouse"], ["water", "recycler"]]:
		if r[pair[0]] < 0.08 * n:
			w.append(["up", pair[1]] if not _upgrade_target(pair[1]).is_empty() else ["build", pair[1]])
	if n >= g.capacity():
		w.append(["up", "quarters"] if not _upgrade_target("quarters").is_empty() else ["build", "quarters"])
	if g.idle_survivors().size() > 1:
		for ty in ["workshop", "lab", "medbay", "greenhouse", "recycler", "dronebay"]:
			if g.unlocked(ty):
				w.append(["up", ty] if not _upgrade_target(ty).is_empty() else ["build", ty])
	for ty in ["dronebay", "workshop", "lab", "medbay", "cargo", "locomotive"]:
		if g.unlocked(ty) or ty == "locomotive":
			w.append(["up", ty])
	if g.carriages.size() - 1 < g.train_length():
		for ty in ["workshop", "dronebay", "greenhouse", "recycler"]:
			w.append(["build", ty])
	return w

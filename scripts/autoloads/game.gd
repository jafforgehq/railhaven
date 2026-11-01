extends Node
## Owns the whole colony state: economy simulation, crew, drones, journey,
## events, chapter goals, research, saving and offline catch-up.
## Signals live here (state owner emits) instead of a separate EventBus autoload.

signal changed
signal carriage_built(uid: int)
signal carriage_upgraded(uid: int)
signal drone_launched(uid: int)
signal drone_returned(uid: int, amount: float)
signal survivor_joined(name: String)
signal goal_completed(index: int)
signal toast(text: String, kind: String)
signal event_started(id: String)
signal event_ended(id: String)
signal expedition_started(stage: int)
signal expedition_done(stage: int)
signal chapter_complete
signal chapter_started(index: int)
signal research_finished(id: String)
signal crew_leveled(sid: int, level: int)
signal offline_report(report: Dictionary)

const SAVE_PATH := "user://railhaven_save.json"

var res: Dictionary = {}
var carriages: Array = [] # {uid, type, level, timer, active, repeat, acc}
var survivors: Array = [] # {id, name, role, job, look, xp}
var next_uid := 1
var next_sid := 1
var growth_timer := 0.0
var chapter := 0 # index into Data.CHAPTERS
var distance := 0.0 # km travelled in the current chapter
var goal_index := 0
var tower_stage := 0 # landmark stages finished in the current chapter
var expedition := -1.0 # seconds left; < 0 means none running
var research_done: Array = [] # ids
var research_id := "" # project running now
var research_left := -1.0
var stats := {"salvaged": 0.0}
var rationing := false
var chapter_done := false # current chapter's landmark restored
var chapter_seen := false
var intro_seen := false
var event: Dictionary = {} # {id, choice, time_left, decide_left}
var event_timer := 150.0
var pending_report: Dictionary = {}

var _offline := false
var _changed_accum := 0.0
var _save_accum := 0.0
var _paused_at := 0.0
var _bonus := {} # summed research effects, rebuilt by _recalc_bonus()
var autosave := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not load_game():
		new_game()


func _process(delta: float) -> void:
	# Clamp: after an app resume the first frame can carry the whole pause; offline catch-up handles that.
	var dt := minf(delta, 1.0)
	_sim(dt)
	_tick_event(dt)
	_check_goals()
	_changed_accum += dt
	if _changed_accum >= 0.25:
		_changed_accum = 0.0
		changed.emit()
	_save_accum += dt
	if autosave and _save_accum >= 20.0:
		_save_accum = 0.0
		save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_paused_at = Time.get_unix_time_from_system()
			if autosave:
				save_game()
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused_at > 0.0:
				var away := Time.get_unix_time_from_system() - _paused_at
				_paused_at = 0.0
				run_offline(away)


# ---------------------------------------------------------------- setup

func new_game() -> void:
	res = Data.START_RES.duplicate()
	carriages.clear()
	survivors.clear()
	next_uid = 1
	next_sid = 1
	growth_timer = 0.0
	chapter = 0
	distance = 0.0
	goal_index = 0
	tower_stage = 0
	expedition = -1.0
	research_done = []
	research_id = ""
	research_left = -1.0
	stats = {"salvaged": 0.0}
	rationing = false
	chapter_done = false
	chapter_seen = false
	intro_seen = false
	event = {}
	event_timer = 150.0
	_recalc_bonus()
	for t in ["locomotive", "quarters", "workshop", "dronebay"]:
		_add_carriage(t)
	for pair in [["Mara", "Engineer"], ["Ivo", "Grower"], ["Nia", "Pilot"], ["Tomas", "Mechanic"]]:
		survivors.append(_make_survivor(pair[0], pair[1]))
	survivors[2]["job"] = first_of("dronebay")["uid"]


func _add_carriage(type: String) -> Dictionary:
	var c := {"uid": next_uid, "type": type, "level": 1, "timer": 0.0, "active": true, "repeat": true, "acc": 0.0}
	next_uid += 1
	carriages.append(c)
	return c


func _make_survivor(name_hint := "", role := "") -> Dictionary:
	var used := {}
	for s in survivors:
		used[s["name"]] = true
	var name := name_hint
	if name == "":
		var pool := Data.NAMES.filter(func(n): return not used.has(n))
		name = pool.pick_random() if not pool.is_empty() else "Drifter %d" % next_sid
	if role == "":
		# New arrivals bring skills the train can use now.
		role = Data.ROLES.filter(func(r): return unlocked(Data.ROLE_JOB[r])).pick_random()
	var s := {
		"id": next_sid, "name": name, "role": role, "job": 0, "xp": 0.0,
		"look": {"skin": randi() % 4, "hair": randi() % 6, "hat": randi() % 3},
	}
	next_sid += 1
	return s


# ---------------------------------------------------------------- chapter

func ch() -> Dictionary:
	return Data.CHAPTERS[chapter]


func goals() -> Array:
	return ch()["goals"]


func stages() -> Array:
	return ch()["stages"]


func landmark_distance() -> float:
	return ch()["distance"]


func level_cap() -> int:
	return ch()["level_cap"]


func train_length() -> int:
	return ch()["train"]


func is_last_chapter() -> bool:
	return chapter >= Data.CHAPTERS.size() - 1


## The whole journey is over (last landmark restored); the game continues as free play.
func journey_complete() -> bool:
	return is_last_chapter() and chapter_done


func unlocked(type: String) -> bool:
	return chapter >= int(Data.CARRIAGES[type].get("chapter", 0))


## Moves on to the next region once the current landmark is restored.
func advance_chapter() -> bool:
	if not chapter_done or is_last_chapter():
		return false
	chapter += 1
	goal_index = 0
	tower_stage = 0
	expedition = -1.0
	distance = 0.0
	chapter_done = false
	chapter_seen = false
	toast.emit("Departing for the %s" % ch()["region"], "good")
	chapter_started.emit(chapter)
	_check_goals()
	changed.emit()
	return true


# ---------------------------------------------------------------- queries

func carriage(uid: int) -> Dictionary:
	for c in carriages:
		if c["uid"] == uid:
			return c
	return {}


func first_of(type: String) -> Dictionary:
	for c in carriages:
		if c["type"] == type:
			return c
	return {}


func count_type(type: String) -> int:
	return carriages.filter(func(c): return c["type"] == type).size()


func max_level(type: String) -> int:
	var m := 0
	for c in carriages:
		if c["type"] == type:
			m = maxi(m, c["level"])
	return m


func survivor(sid: int) -> Dictionary:
	for s in survivors:
		if s["id"] == sid:
			return s
	return {}


func workers_in(uid: int) -> Array:
	return survivors.filter(func(s): return s["job"] == uid)


func idle_survivors() -> Array:
	return survivors.filter(func(s): return s["job"] == 0)


func free_slots(uid: int) -> int:
	var c := carriage(uid)
	if c.is_empty():
		return 0
	return Data.slots(c["type"], c["level"]) - workers_in(uid).size()


func crew_level(s: Dictionary) -> int:
	return Data.crew_level(s.get("xp", 0.0))


func best_crew_level() -> int:
	var m := 1
	for s in survivors:
		m = maxi(m, crew_level(s))
	return m


## Sum of worker strength; a matching role and experience count extra.
func worker_power(c: Dictionary) -> float:
	var p := 0.0
	var want: String = Data.CARRIAGES[c["type"]].get("role", "")
	for s in workers_in(c["uid"]):
		var w := Data.ROLE_BONUS if s["role"] == want else 1.0
		p += w * (1.0 + Data.CREW_LEVEL_BONUS * (crew_level(s) - 1))
	return p


func bonus(key: String) -> float:
	return _bonus.get(key, 0.0)


func _recalc_bonus() -> void:
	_bonus = {}
	for r in Data.RESEARCH:
		if research_done.has(r["id"]):
			for k in r["effect"]:
				_bonus[k] = _bonus.get(k, 0.0) + r["effect"][k]


## Production multiplier for a resource: region perk x research.
func output_mult(k: String) -> float:
	var key := "drone" if k == "scrap" else k
	return float(ch()["perk"].get(k, 1.0)) * (1.0 + bonus(key) + bonus("all"))


func storage(k: String) -> float:
	var loco := first_of("locomotive")
	var cap: float = Data.BASE_STORAGE[k] * Data.loco_mult(loco.get("level", 1))
	for c in carriages:
		cap += Data.storage_bonus(c["type"], c["level"]).get(k, 0.0)
	return cap * (1.0 + bonus("storage"))


func capacity() -> int:
	var b := 0
	for c in carriages:
		if c["type"] == "quarters":
			b += Data.beds(c["level"])
	return b


func cooling_capacity() -> int:
	var cap := 4 + chapter + (1 if chapter_done else 0)
	for c in carriages:
		if c["type"] == "cooling":
			cap += Data.cooling_capacity(c["level"], not workers_in(c["uid"]).is_empty())
	return cap


func cooling_used() -> int:
	return carriages.filter(func(c): return c["type"] != "locomotive" and c["type"] != "cooling").size()


## Train-wide bonus from Med Bay staff (capped).
func care() -> float:
	var b := 0.0
	for c in carriages:
		if c["type"] == "medbay":
			b += worker_power(c) * Data.care_rate(c["level"])
	return minf(0.6, b * (1.0 + bonus("care")))


func efficiency() -> float:
	var e := 1.0 + care()
	if rationing:
		e *= 0.7
	if event.get("id", "") == "heatwave" and event.get("choice", "") == "b":
		e *= 0.7
	return e


func drones_grounded() -> bool:
	return event.get("id", "") == "sandstorm" and event.get("choice", "") == "b"


func drone_run_time() -> float:
	return Data.DRONE_RUN_TIME / (1.0 + bonus("speed"))


func drone_yield(c: Dictionary) -> float:
	return Data.drones(c["level"]) * Data.DRONE_YIELD * (1.0 + 0.25 * worker_power(c)) * output_mult("scrap")


## Per-second output of one producing carriage before efficiency (food, water, parts, data).
func _carriage_rate(c: Dictionary) -> float:
	var t: String = c["type"]
	var r := worker_power(c) * Data.worker_rate(t, c["level"]) * output_mult(Data.CARRIAGES[t]["res"])
	if t == "greenhouse" and event.get("id", "") == "ashstorm" and event.get("choice", "") == "b":
		r *= 0.5
	return r


func upkeep_mult() -> float:
	return (0.5 if rationing else 1.0) * (1.0 - bonus("upkeep"))


func train_speed() -> float:
	if event.get("id", "") == "rail" and event.get("choice", "") == "b":
		return 0.0
	return Data.TRAIN_SPEED * (1.0 + 0.1 * (first_of("locomotive").get("level", 1) - 1))


func outside_temp() -> int:
	var t: int = ch()["temp"]
	if event.get("id", "") == "heatwave":
		return t + 13
	return t - 8 if chapter_done else t


func cabin_temp() -> int:
	var t := 22.0 + 4.0 * float(cooling_used()) / maxf(1.0, cooling_capacity())
	if event.get("id", "") == "heatwave":
		t += 1.0 if event.get("choice", "") == "a" else 5.0
	return int(round(t))


func region_name() -> String:
	return ch()["region"]


func offline_cap() -> float:
	return Data.MAX_OFFLINE_SEC + bonus("offline") * 3600.0


## Net per-minute rates for the HUD.
func rates() -> Dictionary:
	var r := {"scrap": 0.0, "parts": 0.0, "food": 0.0, "water": 0.0, "data": 0.0}
	var eff := efficiency()
	var up := survivors.size() * 60.0 * upkeep_mult()
	r["food"] -= up * Data.FOOD_PER_SURVIVOR
	r["water"] -= up * Data.WATER_PER_SURVIVOR
	for c in carriages:
		match c["type"]:
			"greenhouse", "recycler", "lab":
				r[Data.CARRIAGES[c["type"]]["res"]] += _carriage_rate(c) * eff * 60.0
			"workshop":
				var p := _carriage_rate(c) * eff * 60.0
				r["parts"] += p
				r["scrap"] -= p * Data.SCRAP_PER_PART
			"dronebay":
				if (c["active"] or c["repeat"]) and not drones_grounded():
					r["scrap"] += drone_yield(c) * eff * 60.0 / drone_run_time()
	return r


## Per-minute output of a single carriage (for panels).
func carriage_output(c: Dictionary) -> float:
	var eff := efficiency()
	match c["type"]:
		"greenhouse", "workshop", "recycler", "lab":
			return _carriage_rate(c) * eff * 60.0
		"dronebay":
			return drone_yield(c) * eff * 60.0 / drone_run_time()
	return 0.0


# ---------------------------------------------------------------- economy helpers

func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if res.get(k, 0.0) < cost[k] - 0.001:
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for k in cost:
		res[k] = maxf(0.0, res[k] - cost[k])
	return true


## Adds resource up to storage; returns amount actually stored.
func gain(k: String, v: float, cap := -1.0) -> float:
	if cap < 0.0:
		cap = storage(k)
	var before: float = res[k]
	res[k] = clampf(before + v, 0.0, maxf(cap, before))
	return res[k] - before


func grant(reward: Dictionary) -> void:
	for k in reward:
		res[k] = res.get(k, 0.0) + reward[k] # rewards may overflow storage on purpose


func _discounted(cost: Dictionary) -> Dictionary:
	var d := bonus("cost")
	return cost if d <= 0.0 else Data.scaled_cost(cost, 1.0 - d)


func build_cost(type: String) -> Dictionary:
	return _discounted(Data.build_cost(type, count_type(type)))


func upgrade_cost(c: Dictionary) -> Dictionary:
	return _discounted(Data.upgrade_cost(c["type"], c["level"]))


## First resource whose storage is too small for a cost ("" if all fit).
func storage_short(cost: Dictionary) -> String:
	for k in cost:
		if cost[k] > storage(k) + 0.5:
			return k
	return ""


const NEEDS_HOLD := "Needs a bigger hold: build a Cargo Hold or upgrade the Locomotive"


# ---------------------------------------------------------------- player actions

func build_block_reason(type: String) -> String:
	if not unlocked(type):
		return "Unlocks in Chapter %d" % (int(Data.CARRIAGES[type]["chapter"]) + 1)
	var free := train_length() - (carriages.size() - 1)
	if free <= 0:
		return "Train is at full length"
	var needed := _required_types()
	if not needed.has(type) and free <= needed.size():
		return "Room reserved for %s" % ", ".join(needed.map(func(n): return Data.CARRIAGES[n]["name"]))
	if type != "cooling" and cooling_used() + 1 > cooling_capacity():
		return "Needs more cooling capacity"
	var cost := build_cost(type)
	if storage_short(cost) != "":
		return NEEDS_HOLD if unlocked("cargo") else "Needs a bigger hold: upgrade the Locomotive"
	if not can_afford(cost):
		return "Not enough resources"
	return ""


## Carriage types still needed by the chapter that the train does not have yet.
func _required_types() -> Array:
	var out := []
	var gl := goals()
	for i in range(goal_index, gl.size()):
		var g: Dictionary = gl[i]
		if g["kind"] == "build" and count_type(g["arg"]) < g["n"] and not out.has(g["arg"]):
			out.append(g["arg"])
	if not chapter_done:
		for st in stages().slice(tower_stage):
			for k in st["req"]:
				if Data.CARRIAGES.has(k) and count_type(k) == 0 and not out.has(k):
					out.append(k)
	if count_type("cooling") == 0 and not out.has("cooling"):
		out.append("cooling")
	return out


func build(type: String) -> int:
	if build_block_reason(type) != "":
		return 0
	pay(build_cost(type))
	var c := _add_carriage(type)
	carriage_built.emit(c["uid"])
	toast.emit("%s built" % Data.CARRIAGES[type]["name"], "good")
	_check_goals()
	changed.emit()
	return c["uid"]


func upgrade_block_reason(uid: int) -> String:
	var c := carriage(uid)
	if c.is_empty():
		return "Missing"
	if c["level"] >= Data.MAX_LEVEL:
		return "Max level"
	if c["level"] >= level_cap():
		return "Max level for now: more in the next region"
	var cost := upgrade_cost(c)
	if storage_short(cost) != "":
		return NEEDS_HOLD if unlocked("cargo") else "Needs a bigger hold: upgrade the Locomotive"
	if not can_afford(cost):
		return "Not enough resources"
	return ""


func upgrade(uid: int) -> bool:
	if upgrade_block_reason(uid) != "":
		return false
	var c := carriage(uid)
	pay(upgrade_cost(c))
	c["level"] += 1
	carriage_upgraded.emit(uid)
	toast.emit("%s upgraded to Lv.%d" % [Data.CARRIAGES[c["type"]]["name"], c["level"]], "good")
	_check_goals()
	changed.emit()
	return true


func assign(sid: int, uid: int) -> bool:
	var s := survivor(sid)
	if s.is_empty():
		return false
	if uid != 0 and s["job"] != uid and free_slots(uid) <= 0:
		return false
	s["job"] = uid
	_check_goals()
	changed.emit()
	return true


## Puts someone to work in a carriage: a resting survivor if any, otherwise moves a worker
## over (a matching specialist first, then someone from a carriage that keeps others working).
func pull_worker(uid: int) -> bool:
	var c := carriage(uid)
	if c.is_empty() or free_slots(uid) <= 0:
		return false
	var want: String = Data.CARRIAGES[c["type"]].get("role", "")
	var pool := idle_survivors()
	if pool.is_empty():
		pool = survivors.filter(func(s): return s["job"] != uid and s["job"] != 0 and workers_in(s["job"]).size() > 1)
	if pool.is_empty():
		pool = survivors.filter(func(s): return s["job"] != uid and s["job"] != 0)
	if pool.is_empty():
		return false
	var best: Dictionary = pool[0]
	for s in pool:
		if s["role"] == want:
			best = s
			break
	if best["job"] != 0 and not _offline:
		toast.emit("%s moved to the %s" % [best["name"], Data.CARRIAGES[c["type"]]["name"]], "info")
	return assign(best["id"], uid)


## Fills free slots with idle crew: matching roles first, then shortages.
func auto_assign() -> int:
	var placed := 0
	var order := ["greenhouse", "recycler", "workshop", "dronebay", "lab", "medbay", "cooling"]
	var r := rates()
	if r["water"] < r["food"]:
		order = ["recycler", "greenhouse", "workshop", "dronebay", "lab", "medbay", "cooling"]
	for pass_role in [true, false]:
		for s in idle_survivors():
			for t in order:
				if pass_role and Data.ROLE_JOB.get(s["role"], "") != t:
					continue
				var done := false
				for c in carriages:
					if c["type"] == t and free_slots(c["uid"]) > 0:
						s["job"] = c["uid"]
						placed += 1
						done = true
						break
				if done:
					break
	_check_goals()
	changed.emit()
	return placed


func set_repeat(uid: int, on: bool) -> void:
	var c := carriage(uid)
	c["repeat"] = on
	if on and not c["active"]:
		launch(uid)
	changed.emit()


func launch(uid: int) -> void:
	var c := carriage(uid)
	if c.is_empty() or c["active"]:
		return
	c["active"] = true
	c["timer"] = 0.0
	drone_launched.emit(uid)
	changed.emit()


func stage_block_reason() -> String:
	if tower_stage >= stages().size():
		return "%s restored" % ch()["landmark_name"]
	if expedition >= 0.0:
		return "Expedition underway"
	if distance < landmark_distance():
		return "%s out of drone range" % ch()["landmark_name"]
	var st: Dictionary = stages()[tower_stage]
	for k in st["req"]:
		if k == "survivors":
			if survivors.size() < st["req"][k]:
				return "Needs %d survivors" % st["req"][k]
		elif max_level(k) < st["req"][k]:
			return "Needs %s Lv.%d" % [Data.CARRIAGES[k]["name"], st["req"][k]]
	if storage_short(st["cost"]) != "":
		return NEEDS_HOLD
	if not can_afford(st["cost"]):
		return "Not enough resources"
	return ""


## What the next landmark stage still lacks, in plain words ("" when affordable).
func stage_shortfall() -> String:
	if tower_stage >= stages().size():
		return ""
	var cost: Dictionary = stages()[tower_stage]["cost"]
	var where := {"water": "Water Recycler", "food": "Greenhouse", "parts": "Workshop", "scrap": "Drone Bay", "data": "Research Lab"}
	for k in cost:
		if res[k] < cost[k]:
			return "Needs %d more %s: staff or upgrade the %s" % [ceili(cost[k] - res[k]), Data.RES_NAMES[k].to_lower(), where[k]]
	return ""


func start_expedition() -> bool:
	if stage_block_reason() != "":
		return false
	var st: Dictionary = stages()[tower_stage]
	pay(st["cost"])
	expedition = st["time"]
	expedition_started.emit(tower_stage)
	toast.emit("Drones away: %s" % st["name"], "info")
	changed.emit()
	return true


# ---------------------------------------------------------------- research

func research_def(id: String) -> Dictionary:
	for r in Data.RESEARCH:
		if r["id"] == id:
			return r
	return {}


## Projects the player can see now (current and earlier chapters), in list order.
func research_list() -> Array:
	return Data.RESEARCH.filter(func(r): return r["chapter"] <= chapter)


func research_speed() -> float:
	return 1.0 + 0.15 * maxi(0, max_level("lab") - 1)


func research_block_reason(id: String) -> String:
	var r := research_def(id)
	if r.is_empty():
		return "Unknown"
	if research_done.has(id):
		return "Done"
	if count_type("lab") == 0:
		return "Build a Research Lab first"
	if r["chapter"] > chapter:
		return "Unlocks in Chapter %d" % (r["chapter"] + 1)
	if research_id != "":
		return "Another project is running"
	if storage_short(r["cost"]) != "":
		return NEEDS_HOLD
	if not can_afford(r["cost"]):
		return "Not enough resources"
	return ""


func start_research(id: String) -> bool:
	if research_block_reason(id) != "":
		return false
	var r := research_def(id)
	pay(r["cost"])
	research_id = id
	research_left = r["time"]
	toast.emit("Research started: %s" % r["name"], "info")
	changed.emit()
	return true


func _finish_research() -> void:
	var r := research_def(research_id)
	research_done.append(research_id)
	research_id = ""
	research_left = -1.0
	_recalc_bonus()
	if not _offline:
		toast.emit("Research complete: %s (%s)" % [r["name"], r["text"]], "good")
		research_finished.emit(r["id"])


# ---------------------------------------------------------------- events

func event_scale() -> float:
	return Data.EVENT_SCALE[chapter]


func _scaled(d: Dictionary) -> Dictionary:
	return Data.scaled_cost(d, event_scale()) if event_scale() != 1.0 else d


func event_cost(id: String, choice: String) -> Dictionary:
	return _scaled(Data.EVENTS[id][choice]["cost"])


func event_effect(id: String, choice: String) -> String:
	var o: Dictionary = Data.EVENTS[id][choice]
	if o.has("gain"):
		var g := _scaled(o["gain"])
		return o["effect"] % g.values()[0]
	return o["effect"]


func choose_event(choice: String) -> bool:
	if event.is_empty() or event["choice"] != "":
		return false
	if not pay(event_cost(event["id"], choice)):
		return false
	_apply_choice(choice)
	return true


func _apply_choice(choice: String) -> void:
	var ev: Dictionary = Data.EVENTS[event["id"]]
	event["choice"] = choice
	var opt: Dictionary = ev[choice]
	if opt.has("gain"):
		var g := _scaled(opt["gain"])
		grant(g)
		toast.emit("Traded: +%s" % Data.cost_text(g), "good")
	match [event["id"], choice]:
		["signal", "a"]:
			var n := 0
			for i in 2:
				if survivors.size() < capacity():
					_join(_make_survivor(), "rescued")
					n += 1
			toast.emit("Rescued %d survivor%s" % [n, "" if n == 1 else "s"], "good")
		["heatwave", "a"]:
			toast.emit("Cooling boosted — full production", "info")
		["heatwave", "b"]:
			toast.emit("Safe mode engaged — crew protected", "warn")
		["sandstorm", "a"]:
			toast.emit("Drones reinforced — salvage continues", "info")
		["sandstorm", "b"]:
			toast.emit("Drones grounded until the storm passes", "warn")
		["rail", "a"]:
			toast.emit("Rail welded — full speed ahead", "info")
		["rail", "b"]:
			toast.emit("The train waits for the rail to cool", "warn")
		["ashstorm", "a"]:
			toast.emit("Greenhouse sealed — crops keep growing", "info")
		["ashstorm", "b"]:
			toast.emit("Ash blots out the grow lamps", "warn")
		["raiders", "a"]:
			toast.emit("Hatches bolted — the raiders give up", "good")
		["raiders", "b"]:
			var lost_s: float = res["scrap"] * 0.15
			var lost_f: float = res["food"] * 0.15
			res["scrap"] -= lost_s
			res["food"] -= lost_f
			toast.emit("Raiders took %d scrap and %d food" % [int(lost_s), int(lost_f)], "warn")
	if ev["duration"] <= 0.0:
		_end_event()
	changed.emit()


func can_rescue() -> bool:
	return survivors.size() < capacity()


# ---------------------------------------------------------------- simulation

func _sim(dt: float) -> void:
	var eff := efficiency()
	var cap := {} # storage is constant within a step; computing it once keeps offline catch-up fast
	for k in Data.RES:
		cap[k] = storage(k)
	var n := survivors.size()
	var up := n * dt * upkeep_mult()
	res["food"] = maxf(0.0, res["food"] - up * Data.FOOD_PER_SURVIVOR)
	res["water"] = maxf(0.0, res["water"] - up * Data.WATER_PER_SURVIVOR)
	for c in carriages:
		match c["type"]:
			"greenhouse", "recycler", "lab":
				var k: String = Data.CARRIAGES[c["type"]]["res"]
				c["acc"] += gain(k, _carriage_rate(c) * eff * dt, cap[k])
			"workshop":
				var want := _carriage_rate(c) * eff * dt
				var made := minf(want, minf(res["scrap"] / Data.SCRAP_PER_PART, cap["parts"] - res["parts"]))
				if made > 0.0:
					res["scrap"] -= made * Data.SCRAP_PER_PART
					res["parts"] += made
					c["acc"] += made
			"dronebay":
				_drone_tick(c, dt, eff, cap["scrap"])

	# Crew learn on the job.
	var xp := dt * (1.0 + bonus("xp"))
	for s in survivors:
		if s["job"] != 0:
			var before := crew_level(s)
			s["xp"] = s.get("xp", 0.0) + xp
			var after := crew_level(s)
			if after > before and not _offline:
				crew_leveled.emit(s["id"], after)
				toast.emit("%s reached Lv.%d" % [s["name"], after], "good")

	# Automatic safe mode: rationing instead of losses when food or water runs out.
	if res["food"] <= 0.01 or res["water"] <= 0.01:
		if not rationing:
			rationing = true
			if not _offline:
				toast.emit("Supplies low — automatic safe mode: rationing", "warn")
	elif rationing and res["food"] >= cap["food"] * 0.15 and res["water"] >= cap["water"] * 0.15:
		rationing = false
		if not _offline:
			toast.emit("Supplies stable — rationing lifted", "good")

	if not rationing and survivors.size() < capacity() and res["food"] > 5.0 and res["water"] > 5.0:
		growth_timer += dt * (1.0 + care() * 2.0)
		if growth_timer >= Data.GROWTH_INTERVAL:
			growth_timer -= Data.GROWTH_INTERVAL
			_join(_make_survivor(), "arrived")

	if not chapter_done:
		distance = minf(distance + train_speed() * dt, landmark_distance())

	if research_left >= 0.0:
		research_left -= dt * research_speed()
		if research_left < 0.0:
			_finish_research()

	if expedition >= 0.0:
		expedition -= dt
		if expedition < 0.0:
			expedition = -1.0
			tower_stage += 1
			if not _offline:
				expedition_done.emit(tower_stage - 1)
				toast.emit("Stage complete: %s" % stages()[tower_stage - 1]["name"], "good")
			if tower_stage >= stages().size():
				chapter_done = true
				if not _offline:
					chapter_complete.emit()


func _drone_tick(c: Dictionary, dt: float, eff: float, scrap_cap: float) -> void:
	if not c["active"] or drones_grounded():
		return
	c["timer"] += dt
	var run := drone_run_time()
	while c["timer"] >= run:
		var haul := drone_yield(c) * eff
		var got := gain("scrap", haul, scrap_cap)
		stats["salvaged"] += haul # counts the whole haul so a full hold never blocks the goal
		c["acc"] = 0.0
		if not _offline:
			drone_returned.emit(c["uid"], got)
		if randf() < Data.SURVIVOR_FIND_CHANCE and survivors.size() < capacity():
			_join(_make_survivor(), "found")
		if c["repeat"]:
			c["timer"] -= run
		else:
			c["timer"] = 0.0
			c["active"] = false


func _join(s: Dictionary, how: String) -> void:
	survivors.append(s)
	if _offline:
		return
	var verb: String = {"arrived": "climbed aboard", "found": "was found by the drones", "rescued": "was rescued"}[how]
	toast.emit("%s (%s) %s" % [s["name"], s["role"], verb], "good")
	survivor_joined.emit(s["name"])


func _tick_event(dt: float) -> void:
	if event.is_empty():
		if goal_index < 3 and chapter == 0:
			return # keep the tutorial calm
		event_timer -= dt
		if event_timer <= 0.0:
			var pool := Data.EVENTS.keys().filter(func(id): return Data.EVENTS[id]["chapter"] <= chapter)
			start_event(pool.pick_random())
		return
	if event["choice"] == "":
		event["decide_left"] -= dt
		if event["decide_left"] <= 0.0:
			_auto_choose()
	else:
		event["time_left"] -= dt
		if event["time_left"] <= 0.0:
			_end_event()


func start_event(id: String) -> void:
	event_timer = randf_range(200.0, 320.0)
	event = {"id": id, "choice": "", "time_left": Data.EVENTS[id]["duration"], "decide_left": 25.0}
	event_started.emit(id)
	changed.emit()


## Nobody answered in time: offers fade, raiders take their toll, hazards go to safe mode.
func _auto_choose() -> void:
	match event["id"]:
		"signal", "trader":
			toast.emit("The chance passes by", "info")
			_end_event()
		_:
			_apply_choice("b")
			if Data.EVENTS.get(event.get("id", ""), {}).get("duration", 0.0) > 0.0:
				toast.emit("Automatic safe mode engaged", "warn")


func _end_event() -> void:
	var id: String = event.get("id", "")
	event = {}
	event_timer = randf_range(200.0, 320.0)
	event_ended.emit(id)
	changed.emit()


# ---------------------------------------------------------------- goals

func current_goal() -> Dictionary:
	if goal_index >= goals().size():
		return {}
	return goals()[goal_index]


## Returns [current, target] for a goal.
func goal_progress(g: Dictionary) -> Array:
	match g["kind"]:
		"assign":
			var n := 0
			for c in carriages:
				if c["type"] == g["arg"]:
					n += workers_in(c["uid"]).size()
			return [n, g["n"]]
		"salvaged":
			return [int(stats["salvaged"]), g["n"]]
		"build":
			return [count_type(g["arg"]), g["n"]]
		"level":
			return [max_level(g["arg"]), g["n"]]
		"any_level":
			var m := 0
			for c in carriages:
				m = maxi(m, c["level"])
			return [m, g["n"]]
		"distance":
			return [int(distance), g["n"]]
		"survivors":
			return [survivors.size(), g["n"]]
		"tower":
			return [tower_stage, g["n"]]
		"research":
			return [research_done.size(), g["n"]]
		"crew_level":
			return [best_crew_level(), g["n"]]
	return [0, 1]


## Carriage the player should build next for the current goal ("" if none). Detours to a
## Cooling Module when the train has no room, so out-of-order building never dead-ends.
func goal_build_type() -> String:
	var g := current_goal()
	if g.is_empty():
		return ""
	var t := ""
	match g["kind"]:
		"build":
			t = g["arg"] if count_type(g["arg"]) < g["n"] else ""
		"assign", "level":
			t = g["arg"] if count_type(g["arg"]) == 0 else ""
		"research":
			t = "lab" if count_type("lab") == 0 else ""
	if t != "" and t != "cooling" and build_block_reason(t) == "Needs more cooling capacity":
		return "cooling"
	return t


func _check_goals() -> void:
	var gl := goals()
	while goal_index < gl.size():
		var g: Dictionary = gl[goal_index]
		var p := goal_progress(g)
		if p[0] < p[1]:
			return
		grant(g["reward"])
		goal_index += 1
		if not _offline:
			goal_completed.emit(goal_index - 1)


# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	return {
		"version": Data.SAVE_VERSION,
		"time": Time.get_unix_time_from_system(),
		"res": res, "carriages": carriages, "survivors": survivors,
		"next_uid": next_uid, "next_sid": next_sid,
		"growth_timer": growth_timer, "chapter": chapter, "distance": distance,
		"goal_index": goal_index, "tower_stage": tower_stage, "expedition": expedition,
		"research_done": research_done, "research_id": research_id, "research_left": research_left,
		"stats": stats, "rationing": rationing,
		"chapter_done": chapter_done, "chapter_seen": chapter_seen, "intro_seen": intro_seen,
		"event_timer": event_timer,
	}


## Writes to a temp file then renames, so a kill mid-write never corrupts the save.
func save_game() -> bool:
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	var err := DirAccess.rename_absolute(tmp, SAVE_PATH)
	if err != OK:
		push_error("Save rename failed: %s" % error_string(err))
		return false
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) < 1:
		push_warning("Save file unreadable, kept as .bak, starting a new game")
		DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".bak")
		return false
	from_dict(d)
	run_offline(Time.get_unix_time_from_system() - float(d.get("time", 0.0)))
	return true


## JSON turns ints into floats, so ids and levels are cast back on load.
## v1 saves (single chapter) load as chapter 1; a restored tower then offers the departure.
func from_dict(d: Dictionary) -> void:
	res = {}
	for k in Data.RES:
		res[k] = float(d["res"].get(k, 0.0))
	carriages = []
	for c in d["carriages"]:
		if not Data.CARRIAGES.has(str(c.get("type", ""))):
			continue
		carriages.append({
			"uid": int(c["uid"]), "type": str(c["type"]), "level": clampi(int(c["level"]), 1, Data.MAX_LEVEL),
			"timer": float(c.get("timer", 0.0)), "active": bool(c.get("active", true)),
			"repeat": bool(c.get("repeat", true)), "acc": 0.0,
		})
	survivors = []
	for s in d["survivors"]:
		if not Data.ROLE_JOB.has(str(s.get("role", ""))):
			continue
		var look: Dictionary = s.get("look", {})
		survivors.append({
			"id": int(s["id"]), "name": str(s["name"]), "role": str(s["role"]), "job": int(s.get("job", 0)),
			"xp": float(s.get("xp", 0.0)),
			"look": {"skin": int(look.get("skin", 0)), "hair": int(look.get("hair", 0)), "hat": int(look.get("hat", 0))},
		})
	next_uid = int(d.get("next_uid", carriages.size() + 1))
	next_sid = int(d.get("next_sid", survivors.size() + 1))
	growth_timer = float(d.get("growth_timer", 0.0))
	chapter = clampi(int(d.get("chapter", 0)), 0, Data.CHAPTERS.size() - 1)
	distance = float(d.get("distance", 0.0))
	goal_index = int(d.get("goal_index", 0))
	tower_stage = int(d.get("tower_stage", 0))
	expedition = float(d.get("expedition", -1.0))
	research_done = []
	for id in d.get("research_done", []):
		if not research_def(str(id)).is_empty():
			research_done.append(str(id))
	research_id = str(d.get("research_id", ""))
	research_left = float(d.get("research_left", -1.0))
	if research_def(research_id).is_empty():
		research_id = ""
		research_left = -1.0
	stats = {"salvaged": float(d.get("stats", {}).get("salvaged", 0.0))}
	rationing = bool(d.get("rationing", false))
	chapter_done = bool(d.get("chapter_done", false))
	chapter_seen = bool(d.get("chapter_seen", false))
	intro_seen = bool(d.get("intro_seen", true)) # older saves already know the game
	event = {}
	event_timer = float(d.get("event_timer", 150.0))
	_recalc_bonus()
	# Drop jobs that point at missing carriages.
	for s in survivors:
		if s["job"] != 0 and carriage(s["job"]).is_empty():
			s["job"] = 0


## Fast-forwards the simulation for time spent away, respecting storage caps,
## upkeep and automatic safe mode. Nobody is ever lost while offline.
func run_offline(seconds: float) -> Dictionary:
	seconds = clampf(seconds, 0.0, offline_cap())
	if seconds < 30.0:
		return {}
	var before := res.duplicate()
	var pop := survivors.size()
	var dist := distance
	var stage := tower_stage
	var was_done := chapter_done
	var done_before := research_done.size()
	var saw_ration := rationing
	event = {}
	_offline = true
	var t := 0.0
	while t < seconds:
		var dt := minf(5.0, seconds - t)
		_sim(dt)
		saw_ration = saw_ration or rationing
		t += dt
	_check_goals()
	_offline = false
	var gains := {}
	for k in Data.RES:
		gains[k] = res[k] - before[k]
	pending_report = {
		"seconds": seconds, "gains": gains, "survivors": survivors.size() - pop,
		"distance": distance - dist, "safe_mode": saw_ration, "rationing": rationing,
		"stages": tower_stage - stage, "research": research_done.size() - done_before,
	}
	for c in carriages:
		c["acc"] = 0.0 # no giant "+N" pops for hours of offline output
	offline_report.emit(pending_report)
	if chapter_done and not was_done:
		chapter_complete.emit()
	changed.emit()
	return pending_report


func reset_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	new_game()
	pending_report = {}
	changed.emit()

extends Node
## Owns the whole colony state: economy simulation, crew, drones, journey,
## events, chapter goals, saving and offline catch-up.
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
signal offline_report(report: Dictionary)

const SAVE_PATH := "user://railhaven_save.json"

var res: Dictionary = {}
var carriages: Array = [] # {uid, type, level, timer, active, repeat, acc}
var survivors: Array = [] # {id, name, role, job, look}
var next_uid := 1
var next_sid := 1
var growth_timer := 0.0
var distance := 0.0
var goal_index := 0
var tower_stage := 0
var expedition := -1.0 # seconds left; < 0 means none running
var stats := {"salvaged": 0.0}
var rationing := false
var chapter_done := false
var chapter_seen := false
var intro_seen := false
var event: Dictionary = {} # {id, choice, time_left, decide_left}
var event_timer := 150.0
var pending_report: Dictionary = {}

var _offline := false
var _changed_accum := 0.0
var _save_accum := 0.0
var _paused_at := 0.0
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
	distance = 0.0
	goal_index = 0
	tower_stage = 0
	expedition = -1.0
	stats = {"salvaged": 0.0}
	rationing = false
	chapter_done = false
	chapter_seen = false
	intro_seen = false
	event = {}
	event_timer = 150.0
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
	var s := {
		"id": next_sid, "name": name,
		"role": role if role != "" else Data.ROLES.pick_random(),
		"job": 0,
		"look": {"skin": randi() % 4, "hair": randi() % 6, "hat": randi() % 3},
	}
	next_sid += 1
	return s


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


## Sum of worker strength; a matching role counts extra.
func worker_power(c: Dictionary) -> float:
	var p := 0.0
	var want: String = Data.CARRIAGES[c["type"]].get("role", "")
	for s in workers_in(c["uid"]):
		p += Data.ROLE_BONUS if s["role"] == want else 1.0
	return p


func storage(k: String) -> float:
	var loco := first_of("locomotive")
	var cap: float = Data.BASE_STORAGE[k] * Data.loco_mult(loco.get("level", 1))
	for c in carriages:
		cap += Data.storage_bonus(c["type"], c["level"]).get(k, 0.0)
	return cap


func capacity() -> int:
	var b := 0
	for c in carriages:
		if c["type"] == "quarters":
			b += Data.beds(c["level"])
	return b


func cooling_capacity() -> int:
	var cap := 4 + (1 if chapter_done else 0)
	for c in carriages:
		if c["type"] == "cooling":
			cap += Data.cooling_capacity(c["level"], not workers_in(c["uid"]).is_empty())
	return cap


func cooling_used() -> int:
	return carriages.filter(func(c): return c["type"] != "locomotive" and c["type"] != "cooling").size()


func efficiency() -> float:
	var e := 1.0
	if rationing:
		e *= 0.7
	if event.get("id", "") == "heatwave" and event.get("choice", "") == "b":
		e *= 0.7
	return e


func drones_grounded() -> bool:
	return event.get("id", "") == "sandstorm" and event.get("choice", "") == "b"


func drone_yield(c: Dictionary) -> float:
	return Data.drones(c["level"]) * Data.DRONE_YIELD * (1.0 + 0.25 * worker_power(c))


func water_mult() -> float:
	return 1.25 if chapter_done else 1.0


func train_speed() -> float:
	return Data.TRAIN_SPEED * (1.0 + 0.1 * (first_of("locomotive").get("level", 1) - 1))


func outside_temp() -> int:
	if event.get("id", "") == "heatwave":
		return 78
	return 55 if chapter_done else 65


func cabin_temp() -> int:
	var t := 22.0 + 4.0 * float(cooling_used()) / maxf(1.0, cooling_capacity())
	if event.get("id", "") == "heatwave":
		t += 1.0 if event.get("choice", "") == "a" else 5.0
	return int(round(t))


func region_name() -> String:
	if chapter_done:
		return "Ash Coast"
	return "Scorched Desert"


## Net per-minute rates for the HUD.
func rates() -> Dictionary:
	var r := {"scrap": 0.0, "parts": 0.0, "food": 0.0, "water": 0.0}
	var eff := efficiency()
	var ration := 0.5 if rationing else 1.0
	r["food"] -= survivors.size() * Data.FOOD_PER_SURVIVOR * 60.0 * ration
	r["water"] -= survivors.size() * Data.WATER_PER_SURVIVOR * 60.0 * ration
	for c in carriages:
		match c["type"]:
			"greenhouse":
				r["food"] += worker_power(c) * Data.worker_rate("greenhouse", c["level"]) * eff * 60.0
			"recycler":
				r["water"] += worker_power(c) * Data.worker_rate("recycler", c["level"]) * eff * water_mult() * 60.0
			"workshop":
				var p := worker_power(c) * Data.worker_rate("workshop", c["level"]) * eff * 60.0
				r["parts"] += p
				r["scrap"] -= p * Data.SCRAP_PER_PART
			"dronebay":
				if (c["active"] or c["repeat"]) and not drones_grounded():
					r["scrap"] += drone_yield(c) * eff * 60.0 / Data.DRONE_RUN_TIME
	return r


## Per-minute output of a single carriage (for panels).
func carriage_output(c: Dictionary) -> float:
	var eff := efficiency()
	match c["type"]:
		"greenhouse", "workshop":
			return worker_power(c) * Data.worker_rate(c["type"], c["level"]) * eff * 60.0
		"recycler":
			return worker_power(c) * Data.worker_rate("recycler", c["level"]) * eff * water_mult() * 60.0
		"dronebay":
			return drone_yield(c) * eff * 60.0 / Data.DRONE_RUN_TIME
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


# ---------------------------------------------------------------- player actions

func build_block_reason(type: String) -> String:
	var free := Data.MAX_CARRIAGES - (carriages.size() - 1)
	if free <= 0:
		return "Train is at full length"
	var needed := _required_types()
	if not needed.has(type) and free <= needed.size():
		return "Room reserved for %s" % ", ".join(needed.map(func(n): return Data.CARRIAGES[n]["name"]))
	if type != "cooling" and cooling_used() + 1 > cooling_capacity():
		return "Needs more cooling capacity"
	if not can_afford(Data.build_cost(type, count_type(type))):
		return "Not enough resources"
	return ""


## Carriage types still needed by the chapter that the train does not have yet.
func _required_types() -> Array:
	var out := []
	for i in range(goal_index, Data.GOALS.size()):
		var g: Dictionary = Data.GOALS[i]
		if g["kind"] == "build" and count_type(g["arg"]) == 0 and not out.has(g["arg"]):
			out.append(g["arg"])
	if not chapter_done and count_type("cooling") == 0 and not out.has("cooling"):
		out.append("cooling")
	return out


func build(type: String) -> int:
	if build_block_reason(type) != "":
		return 0
	pay(Data.build_cost(type, count_type(type)))
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
	if not can_afford(Data.upgrade_cost(c["type"], c["level"])):
		return "Not enough resources"
	return ""


func upgrade(uid: int) -> bool:
	if upgrade_block_reason(uid) != "":
		return false
	var c := carriage(uid)
	pay(Data.upgrade_cost(c["type"], c["level"]))
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


## Fills free slots with idle crew: matching roles first, then shortages.
func auto_assign() -> int:
	var placed := 0
	var order := ["greenhouse", "recycler", "workshop", "dronebay", "cooling"]
	var r := rates()
	if r["water"] < r["food"]:
		order = ["recycler", "greenhouse", "workshop", "dronebay", "cooling"]
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
	if tower_stage >= Data.TOWER_STAGES.size():
		return "Tower restored"
	if expedition >= 0.0:
		return "Expedition underway"
	if distance < Data.TOWER_DISTANCE:
		return "Tower out of drone range"
	var st: Dictionary = Data.TOWER_STAGES[tower_stage]
	for k in st["req"]:
		if k == "survivors":
			if survivors.size() < st["req"][k]:
				return "Needs %d survivors" % st["req"][k]
		elif max_level(k) < st["req"][k]:
			return "Needs %s Lv.%d" % [Data.CARRIAGES[k]["name"], st["req"][k]]
	if not can_afford(st["cost"]):
		return "Not enough resources"
	return ""


func start_expedition() -> bool:
	if stage_block_reason() != "":
		return false
	var st: Dictionary = Data.TOWER_STAGES[tower_stage]
	pay(st["cost"])
	expedition = st["time"]
	expedition_started.emit(tower_stage)
	toast.emit("Drones away: %s" % st["name"], "info")
	changed.emit()
	return true


func choose_event(choice: String) -> bool:
	if event.is_empty() or event["choice"] != "":
		return false
	var ev: Dictionary = Data.EVENTS[event["id"]]
	var opt: Dictionary = ev[choice]
	if not pay(opt["cost"]):
		return false
	event["choice"] = choice
	match [event["id"], choice]:
		["signal", "a"]:
			var n := 0
			for i in 2:
				if survivors.size() < capacity():
					_join(_make_survivor(), "rescued")
					n += 1
			toast.emit("Rescued %d survivor%s" % [n, "" if n == 1 else "s"], "good")
		["signal", "b"]:
			grant({"scrap": 60.0})
			toast.emit("Traded food for 60 scrap", "good")
		["heatwave", "a"]:
			toast.emit("Cooling boosted — full production", "info")
		["heatwave", "b"]:
			toast.emit("Safe mode engaged — crew protected", "warn")
		["sandstorm", "a"]:
			toast.emit("Drones reinforced — salvage continues", "info")
		["sandstorm", "b"]:
			toast.emit("Drones grounded until the storm passes", "warn")
	if ev["duration"] <= 0.0:
		_end_event()
	changed.emit()
	return true


func can_rescue() -> bool:
	return survivors.size() < capacity()


# ---------------------------------------------------------------- simulation

func _sim(dt: float) -> void:
	var eff := efficiency()
	var cap := {} # storage is constant within a step; computing it once keeps offline catch-up fast
	for k in Data.RES:
		cap[k] = storage(k)
	var ration := 0.5 if rationing else 1.0
	var n := survivors.size()
	res["food"] = maxf(0.0, res["food"] - n * Data.FOOD_PER_SURVIVOR * dt * ration)
	res["water"] = maxf(0.0, res["water"] - n * Data.WATER_PER_SURVIVOR * dt * ration)
	for c in carriages:
		match c["type"]:
			"greenhouse":
				c["acc"] += gain("food", worker_power(c) * Data.worker_rate("greenhouse", c["level"]) * eff * dt, cap["food"])
			"recycler":
				c["acc"] += gain("water", worker_power(c) * Data.worker_rate("recycler", c["level"]) * eff * water_mult() * dt, cap["water"])
			"workshop":
				var want := worker_power(c) * Data.worker_rate("workshop", c["level"]) * eff * dt
				var made := minf(want, minf(res["scrap"] / Data.SCRAP_PER_PART, cap["parts"] - res["parts"]))
				if made > 0.0:
					res["scrap"] -= made * Data.SCRAP_PER_PART
					res["parts"] += made
					c["acc"] += made
			"dronebay":
				_drone_tick(c, dt, eff, cap["scrap"])

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
		growth_timer += dt
		if growth_timer >= Data.GROWTH_INTERVAL:
			growth_timer -= Data.GROWTH_INTERVAL
			_join(_make_survivor(), "arrived")

	distance += train_speed() * dt

	if expedition >= 0.0:
		expedition -= dt
		if expedition < 0.0:
			expedition = -1.0
			tower_stage += 1
			if not _offline:
				expedition_done.emit(tower_stage - 1)
				toast.emit("Tower stage complete: %s" % Data.TOWER_STAGES[tower_stage - 1]["name"], "good")
			if tower_stage >= Data.TOWER_STAGES.size():
				chapter_done = true
				if not _offline:
					chapter_complete.emit()


func _drone_tick(c: Dictionary, dt: float, eff: float, scrap_cap: float) -> void:
	if not c["active"] or drones_grounded():
		return
	c["timer"] += dt
	while c["timer"] >= Data.DRONE_RUN_TIME:
		var haul := drone_yield(c) * eff
		var got := gain("scrap", haul, scrap_cap)
		stats["salvaged"] += haul # counts the whole haul so a full hold never blocks the goal
		c["acc"] = 0.0
		if not _offline:
			drone_returned.emit(c["uid"], got)
		if randf() < Data.SURVIVOR_FIND_CHANCE and survivors.size() < capacity():
			_join(_make_survivor(), "found")
		if c["repeat"]:
			c["timer"] -= Data.DRONE_RUN_TIME
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
		if goal_index < 3:
			return # keep the tutorial calm
		event_timer -= dt
		if event_timer <= 0.0:
			start_event(["heatwave", "sandstorm", "signal"].pick_random())
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


func _auto_choose() -> void:
	if event["id"] == "signal":
		toast.emit("The flare fades over the dunes", "info")
		_end_event()
		return
	event["choice"] = "b"
	toast.emit("Automatic safe mode engaged", "warn")
	changed.emit()


func _end_event() -> void:
	var id: String = event.get("id", "")
	event = {}
	event_timer = randf_range(200.0, 320.0)
	event_ended.emit(id)
	changed.emit()


# ---------------------------------------------------------------- goals

func current_goal() -> Dictionary:
	if goal_index >= Data.GOALS.size():
		return {}
	return Data.GOALS[goal_index]


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
		"distance":
			return [int(distance), g["n"]]
		"survivors":
			return [survivors.size(), g["n"]]
		"tower":
			return [tower_stage, g["n"]]
	return [0, 1]


func _check_goals() -> void:
	while goal_index < Data.GOALS.size():
		var g: Dictionary = Data.GOALS[goal_index]
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
		"growth_timer": growth_timer, "distance": distance,
		"goal_index": goal_index, "tower_stage": tower_stage, "expedition": expedition,
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
			"look": {"skin": int(look.get("skin", 0)), "hair": int(look.get("hair", 0)), "hat": int(look.get("hat", 0))},
		})
	next_uid = int(d.get("next_uid", carriages.size() + 1))
	next_sid = int(d.get("next_sid", survivors.size() + 1))
	growth_timer = float(d.get("growth_timer", 0.0))
	distance = float(d.get("distance", 0.0))
	goal_index = int(d.get("goal_index", 0))
	tower_stage = int(d.get("tower_stage", 0))
	expedition = float(d.get("expedition", -1.0))
	stats = {"salvaged": float(d.get("stats", {}).get("salvaged", 0.0))}
	rationing = bool(d.get("rationing", false))
	chapter_done = bool(d.get("chapter_done", false))
	chapter_seen = bool(d.get("chapter_seen", false))
	intro_seen = bool(d.get("intro_seen", true)) # older saves already know the game
	event = {}
	event_timer = float(d.get("event_timer", 150.0))
	# Drop jobs that point at missing carriages.
	for s in survivors:
		if s["job"] != 0 and carriage(s["job"]).is_empty():
			s["job"] = 0


## Fast-forwards the simulation for time spent away, respecting storage caps,
## upkeep and automatic safe mode. Nobody is ever lost while offline.
func run_offline(seconds: float) -> Dictionary:
	seconds = clampf(seconds, 0.0, Data.MAX_OFFLINE_SEC)
	if seconds < 30.0:
		return {}
	var before := res.duplicate()
	var pop := survivors.size()
	var dist := distance
	var stage := tower_stage
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
		"stages": tower_stage - stage,
	}
	for c in carriages:
		c["acc"] = 0.0 # no giant "+N" pops for hours of offline output
	offline_report.emit(pending_report)
	if chapter_done and stage < Data.TOWER_STAGES.size():
		chapter_complete.emit()
	changed.emit()
	return pending_report


func reset_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	new_game()
	pending_report = {}
	changed.emit()

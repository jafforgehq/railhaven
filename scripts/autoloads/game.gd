extends Node
## Owns the player's progress: region and restoration tasks, the train's carriages, currencies,
## lives, boosters, the Condenser (offline earner), level loading and saving.
## The puzzle itself runs in PuzzleScreen with SortBoard; this autoload only settles results.

signal changed
signal toast(text: String, kind: String)
signal carriage_built(uid: int)
signal carriage_upgraded(uid: int)
signal task_completed(index: int)
signal region_complete
signal region_started(index: int)
signal level_won(reward: Dictionary) # events (Heat Run, race) listen to results
signal level_lost

const SAVE_PATH := "user://railhaven_save.json"
const DRONE_CYCLE := 30.0

var region_index := 0
var task_index := 0
var region_done := false # landmark restored, waiting to depart
var region_seen := false
var level := 1 # next puzzle level (1-based)
var parts := 0
var scrap := Data.START_SCRAP
var lives := Data.MAX_LIVES
var lives_at := 0.0 # unix time the regen clock started
var boosters: Dictionary = {}
var carriages: Array = [] # {uid, type, level, timer, active, repeat}
var next_uid := 1
var condenser_at := 0.0 # unix time of the last Condenser claim
var meta: Dictionary = {} # retention systems' state, owned by the Meta autoload
var stats := {"wins": 0, "losses": 0, "snaps": 0, "streak": 0, "best_streak": 0}
var tutorial := {"first_pour": false, "first_restore": false}
var intro_seen := false
var heat_visual := 0.0 # 0..1, set by the puzzle so the world can glow
var autosave := true

static var _levels: Array = []
static var _bosses: Array = []
var _save_accum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not load_game():
		new_game()


func _process(delta: float) -> void:
	# Drone bays keep flying sorties: purely cosmetic now.
	for c in carriages:
		if c["type"] == "dronebay":
			c["timer"] = fmod(c["timer"] + delta, DRONE_CYCLE)
	_tick_lives()
	_save_accum += delta
	if autosave and _save_accum >= 15.0:
		_save_accum = 0.0
		save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_game()


func now() -> float:
	return Time.get_unix_time_from_system()


# ---------------------------------------------------------------- setup

func new_game() -> void:
	region_index = 0
	task_index = 0
	region_done = false
	region_seen = false
	level = 1
	parts = 0
	scrap = Data.START_SCRAP
	lives = Data.MAX_LIVES
	lives_at = now()
	boosters = Data.START_BOOSTERS.duplicate()
	carriages = []
	next_uid = 1
	for pair in Data.START_TRAIN:
		_add_carriage(pair[0], pair[1])
	condenser_at = now()
	meta = {}
	stats = {"wins": 0, "losses": 0, "snaps": 0, "streak": 0, "best_streak": 0}
	tutorial = {"first_pour": false, "first_restore": false}
	intro_seen = false


func _add_carriage(type: String, lv := 1) -> Dictionary:
	var c := {"uid": next_uid, "type": type, "level": lv, "timer": randf() * DRONE_CYCLE, "active": true, "repeat": true}
	next_uid += 1
	carriages.append(c)
	return c


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


func level_of(type: String) -> int:
	return first_of(type).get("level", 0)


func ch() -> Dictionary:
	return Data.REGIONS[region_index]


func region() -> Dictionary:
	return Data.REGIONS[region_index]


func region_name() -> String:
	return region()["region"]


func is_last_region() -> bool:
	return region_index >= Data.REGIONS.size() - 1


func journey_complete() -> bool:
	return is_last_region() and region_done


## How far the landmark has come into view (0..1): grows with restoration progress.
func landmark_visibility() -> float:
	var n: int = region()["tasks"].size()
	return 1.0 if region_done else clampf(0.35 + 0.65 * float(task_index) / maxf(1.0, n - 1), 0.0, 1.0)


func drone_run_time() -> float:
	return DRONE_CYCLE


func drones_grounded() -> bool:
	return false


func outside_temp() -> int:
	return int(region()["temp"]) - (8 if region_done else 0)


# ---------------------------------------------------------------- restoration

func current_task() -> Dictionary:
	var tasks: Array = region()["tasks"]
	return {} if task_index >= tasks.size() else tasks[task_index]


## Type of the carriage the current task adds to the train ("" for upgrades and landmarks).
func next_build() -> String:
	var t := current_task()
	if region_done or not t.has("type") or count_type(t["type"]) > 0:
		return ""
	return t["type"]


## Parts collected toward the current task, 0..1.
func task_progress() -> float:
	var t := current_task()
	if region_done or t.is_empty():
		return 1.0
	return clampf(float(parts) / maxf(1.0, float(t["cost"])), 0.0, 1.0)


func task_block_reason() -> String:
	var t := current_task()
	if t.is_empty():
		return "Region restored"
	if parts < int(t["cost"]):
		var need := int(t["cost"]) - parts
		return "Need %d more part%s" % [need, "" if need == 1 else "s"]
	return ""


func complete_task() -> bool:
	if task_block_reason() != "":
		return false
	var t := current_task()
	parts -= int(t["cost"])
	tutorial["first_restore"] = true
	var idx := task_index
	task_index += 1
	if t.get("landmark", false):
		region_done = true
		region_seen = false
		task_completed.emit(idx)
		region_complete.emit()
	else:
		var c := first_of(t["type"])
		task_completed.emit(idx)
		if c.is_empty():
			c = _add_carriage(t["type"], int(t["level"]))
			if t["type"] == "condenser":
				condenser_at = now() # starts collecting from the moment it is coupled
			carriage_built.emit(c["uid"])
		else:
			c["level"] = maxi(c["level"], int(t["level"]))
			carriage_upgraded.emit(c["uid"])
		toast.emit("Restored: %s" % t["text"], "good")
	save_game()
	changed.emit()
	return true


func advance_region() -> bool:
	if not region_done or is_last_region():
		return false
	region_index += 1
	task_index = 0
	region_done = false
	region_seen = false
	region_started.emit(region_index)
	toast.emit("Departing for the %s" % region_name(), "good")
	save_game()
	changed.emit()
	return true


# ---------------------------------------------------------------- levels

static func _load_levels() -> void:
	if not _levels.is_empty():
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(Data.LEVELS_PATH))
	if typeof(d) == TYPE_DICTIONARY:
		_levels = d["levels"]
		_bosses = d.get("bosses", [])
	if _levels.is_empty():
		push_error("No levels found at %s" % Data.LEVELS_PATH)


static func level_count() -> int:
	_load_levels()
	return _levels.size()


## Level n (1-based). Past the authored set, later levels repeat with shuffled colours.
static func level_data(n: int) -> Dictionary:
	_load_levels()
	if n <= _levels.size():
		return _levels[n - 1]
	var base := 100
	var src: Dictionary = _levels[base + (n - 1 - base) % (_levels.size() - base)]
	var perm: Array = range(Data.COLORS.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	for i in range(perm.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = perm[i]
		perm[i] = perm[j]
		perm[j] = tmp
	var out := src.duplicate(true)
	out["tanks"] = src["tanks"].map(func(t): return t.map(func(x): return perm[int(x)]))
	for key in ["lock", "keylock"]:
		if src.has(key):
			out[key] = src[key].map(func(x): return perm[int(x)] if int(x) >= 0 else -1)
	if src.has("goal"):
		out["goal"]["colors"] = src["goal"]["colors"].map(func(x): return perm[int(x)])
	return out


## The landmark boss level of region r (tuned for the level players reach it at).
static func boss_data(r: int) -> Dictionary:
	_load_levels()
	return _bosses[clampi(r, 0, _bosses.size() - 1)] if not _bosses.is_empty() else level_data(25)


## Boss beaten: pays the boss reward. The landmark itself is restored when the player
## returns home (complete_task), so the region-complete moment plays on the home screen.
func win_boss(heat: float) -> Dictionary:
	var bonus := maxi(0, int(Data.HEAT_MAX - heat)) * Data.COOL_BONUS_PER_DEG
	var reward := {"parts": 0, "scrap": int(Data.BOSS_REWARD["scrap"]) + bonus, "bonus": bonus, "hard": true,
		"level": level, "boss": true}
	scrap += reward["scrap"]
	for k in Data.BOSS_REWARD:
		if k != "scrap":
			boosters[k] = booster_count(k) + int(Data.BOSS_REWARD[k])
	stats["wins"] += 1
	stats["streak"] += 1
	stats["best_streak"] = maxi(stats["best_streak"], stats["streak"])
	level_won.emit(reward)
	save_game()
	changed.emit()
	return reward


func is_hard(n: int) -> bool:
	return bool(level_data(n).get("hard", false))


## Heat at the first move: every Cooling Core level starts puzzles 1°C cooler.
func start_heat() -> float:
	return Data.HEAT_START - float(maxi(0, level_of("cooling") - 1))


## Records a win and pays out. Returns the reward breakdown for the win popup.
func win_level(heat: float) -> Dictionary:
	var hard := is_hard(level)
	var bonus := maxi(0, int(Data.HEAT_MAX - heat)) * Data.COOL_BONUS_PER_DEG
	var reward := {"parts": 2 if hard else 1, "scrap": (Data.HARD_SCRAP if hard else Data.WIN_SCRAP) + bonus,
		"bonus": bonus, "hard": hard, "level": level}
	parts += reward["parts"]
	scrap += reward["scrap"]
	level += 1
	stats["wins"] += 1
	stats["streak"] += 1
	stats["best_streak"] = maxi(stats["best_streak"], stats["streak"])
	level_won.emit(reward)
	save_game()
	changed.emit()
	return reward


## A failed or abandoned level costs one life.
func lose_life() -> void:
	if lives >= Data.MAX_LIVES:
		lives_at = now()
	lives = maxi(0, lives - 1)
	stats["losses"] += 1
	stats["streak"] = 0
	level_lost.emit()
	save_game()
	changed.emit()


func _tick_lives() -> void:
	if lives >= Data.MAX_LIVES:
		lives_at = now()
		return
	var gained := int((now() - lives_at) / Data.LIFE_REGEN)
	if gained > 0:
		lives = mini(Data.MAX_LIVES, lives + gained)
		lives_at += gained * Data.LIFE_REGEN
		if lives >= Data.MAX_LIVES:
			lives_at = now()
		changed.emit()


func next_life_in() -> float:
	if lives >= Data.MAX_LIVES:
		return 0.0
	return maxf(0.0, Data.LIFE_REGEN - (now() - lives_at))


func refill_lives(free := false) -> bool:
	if lives >= Data.MAX_LIVES:
		return false
	if not free and not spend(Data.REFILL_COST):
		return false
	lives = Data.MAX_LIVES
	lives_at = now()
	save_game()
	changed.emit()
	return true


# ---------------------------------------------------------------- currencies & boosters

func spend(amount: int) -> bool:
	if scrap < amount:
		return false
	scrap -= amount
	changed.emit()
	return true


func booster_count(id: String) -> int:
	return int(boosters.get(id, 0))


func use_booster(id: String) -> bool:
	if booster_count(id) <= 0:
		return false
	boosters[id] = booster_count(id) - 1
	changed.emit()
	return true


func buy_booster(id: String, n := 1) -> bool:
	if not spend(int(Data.BOOSTERS[id]["price"]) * n):
		return false
	boosters[id] = booster_count(id) + n
	save_game()
	changed.emit()
	return true


func continue_cost(used: int) -> int:
	return Data.CONTINUE_COST[mini(used, Data.CONTINUE_COST.size() - 1)]


# ---------------------------------------------------------------- condenser

func has_condenser() -> bool:
	return count_type("condenser") > 0


func condenser_level() -> int:
	return maxi(1, level_of("condenser"))


func condenser_seconds() -> float:
	return clampf(now() - condenser_at, 0.0, Data.condenser_cap_hours(condenser_level()) * 3600.0)


func condenser_amount() -> int:
	return int(Data.condenser_rate(condenser_level()) * condenser_seconds() / 3600.0)


func condenser_full() -> bool:
	return has_condenser() and condenser_seconds() >= Data.condenser_cap_hours(condenser_level()) * 3600.0 - 1.0


func condenser_ready() -> bool:
	return has_condenser() and condenser_seconds() >= Data.CONDENSER_MIN_CLAIM and condenser_amount() > 0


## Collects the Condenser's water as scrap; `mult` is 2 after a rewarded ad. A full tank also
## drips out one random booster.
func claim_condenser(mult := 1) -> Dictionary:
	if not condenser_ready():
		return {}
	var got := condenser_amount() * mult
	var gift := ""
	if condenser_full():
		gift = Data.BOOSTER_ORDER.pick_random()
		boosters[gift] = booster_count(gift) + 1
	scrap += got
	condenser_at = now()
	save_game()
	changed.emit()
	return {"scrap": got, "booster": gift}


func condenser_upgrade_block() -> String:
	if not has_condenser():
		return "Couple the Condenser first"
	var lv := condenser_level()
	if lv >= Data.CONDENSER_MAX:
		return "Max level"
	if scrap < Data.condenser_upgrade_cost(lv):
		return "Not enough scrap"
	return ""


func upgrade_condenser() -> bool:
	if condenser_upgrade_block() != "":
		return false
	var c := first_of("condenser")
	spend(Data.condenser_upgrade_cost(c["level"]))
	c["level"] += 1
	carriage_upgraded.emit(c["uid"])
	toast.emit("Condenser upgraded to Lv.%d" % c["level"], "good")
	save_game()
	changed.emit()
	return true


# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	return {
		"version": Data.SAVE_VERSION, "time": now(),
		"region_index": region_index, "task_index": task_index, "region_done": region_done, "region_seen": region_seen,
		"level": level, "parts": parts, "scrap": scrap, "lives": lives, "lives_at": lives_at,
		"boosters": boosters, "carriages": carriages.map(func(c): return {"uid": c["uid"], "type": c["type"], "level": c["level"], "livery": c.get("livery", "")}),
		"next_uid": next_uid, "condenser_at": condenser_at, "meta": meta,
		"stats": stats, "tutorial": tutorial, "intro_seen": intro_seen,
	}


## Writes to a temp file then renames, so a kill mid-write never corrupts the save.
func save_game() -> bool:
	if not autosave:
		return false
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


## Saves from the idle version (v1/v2) are kept as .idle.bak; the puzzle game starts fresh.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) < 3:
		push_warning("Old or unreadable save kept as .idle.bak; starting the puzzle game fresh")
		DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH + ".idle.bak")
		return false
	from_dict(d)
	return true


func from_dict(d: Dictionary) -> void:
	new_game()
	region_index = clampi(int(d.get("region_index", 0)), 0, Data.REGIONS.size() - 1)
	task_index = clampi(int(d.get("task_index", 0)), 0, region()["tasks"].size())
	region_done = bool(d.get("region_done", false))
	region_seen = bool(d.get("region_seen", false))
	level = maxi(1, int(d.get("level", 1)))
	parts = maxi(0, int(d.get("parts", 0)))
	scrap = maxi(0, int(d.get("scrap", 0)))
	lives = clampi(int(d.get("lives", Data.MAX_LIVES)), 0, Data.MAX_LIVES)
	lives_at = float(d.get("lives_at", now()))
	boosters = {}
	var saved: Dictionary = d.get("boosters", {})
	for k in saved: # in-level and pre-level boosters
		boosters[k] = maxi(0, int(saved[k]))
	carriages = []
	for c in d.get("carriages", []):
		if Data.CARRIAGES.has(str(c.get("type", ""))):
			carriages.append({"uid": int(c["uid"]), "type": str(c["type"]), "level": clampi(int(c.get("level", 1)), 1, 10),
				"livery": str(c.get("livery", "")), "timer": randf() * DRONE_CYCLE, "active": true, "repeat": true})
	if carriages.is_empty():
		next_uid = 1
		for pair in Data.START_TRAIN:
			_add_carriage(pair[0], pair[1])
	var max_uid := 0
	for c in carriages:
		max_uid = maxi(max_uid, c["uid"])
	next_uid = maxi(int(d.get("next_uid", 1)), max_uid + 1)
	condenser_at = float(d.get("condenser_at", now()))
	meta = d.get("meta", {}) if typeof(d.get("meta")) == TYPE_DICTIONARY else {}
	var st: Dictionary = d.get("stats", {})
	for k in stats:
		stats[k] = int(st.get(k, 0))
	var tu: Dictionary = d.get("tutorial", {})
	for k in tu: # includes the blk_<kind> flags for blocker intros already shown
		tutorial[k] = bool(tu[k])
	intro_seen = bool(d.get("intro_seen", true))
	_tick_lives()


func reset_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	new_game()
	changed.emit()

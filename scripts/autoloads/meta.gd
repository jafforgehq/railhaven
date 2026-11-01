extends Node
## Retention systems around the puzzle: win streak and pre-level boosters, the 7-day login
## calendar, the postcard album, the Heat Run event, the weekly race and Juno's story lines.
## All state lives in Game.meta (a plain Dictionary), so it saves with the rest of the game.

signal changed
signal event_result(kind: String, info: Dictionary) # Heat Run finished, race week settled


func _ready() -> void:
	Game.level_won.connect(_on_won)
	Game.level_lost.connect(_on_lost)


func _on_won(reward: Dictionary) -> void:
	_heat_run_step(true)
	if not reward.get("boss", false) and int(reward.get("level", 0)) % RESCUE_EVERY == 0:
		m()["rescue_pending"] = true
	_race_add(3 if reward.get("boss", false) else (2 if reward.get("hard", false) else 1))


func _on_lost() -> void:
	_heat_run_step(false)

# ---------------------------------------------------------------- pre-level boosters & streak

## Chosen on the level start popup; owned ones are used first, the rest bought with scrap.
const PRE := {
	"pre_cool": {"name": "Cool Start", "icon": "snowflake", "price": 150, "desc": "Start 5°C cooler"},
	"pre_tank": {"name": "Extra Tank", "icon": "tank", "price": 250, "desc": "Start with a spare tank"},
	"pre_ash": {"name": "Ash Sweep", "icon": "ash", "price": 200, "desc": "Clear the ash off every canister"},
}
const PRE_ORDER := ["pre_cool", "pre_tank", "pre_ash"]
const PRE_COOL := 5.0
## Free pre-level boosters for 1, 2 and 3+ wins in a row (a loss resets the streak).
const STREAK_FREE := [[], ["pre_cool"], ["pre_cool", "pre_tank"], ["pre_cool", "pre_tank", "pre_ash"]]


func m() -> Dictionary:
	return Game.meta


func streak() -> int:
	return int(Game.stats.get("streak", 0))


func streak_free() -> Array:
	return STREAK_FREE[mini(streak(), STREAK_FREE.size() - 1)]


## Scrap needed for the chosen pre-level boosters that are neither free nor owned.
func pre_cost(ids: Array) -> int:
	var cost := 0
	for id in ids:
		if not id in streak_free() and Game.booster_count(id) <= 0:
			cost += int(PRE[id]["price"])
	return cost


## Pays for the chosen boosters. Returns the full list to apply (chosen + streak freebies),
## or [] with ok=false when the player cannot afford them.
func take_pre(ids: Array) -> Dictionary:
	var cost := pre_cost(ids)
	if Game.scrap < cost:
		return {"ok": false, "apply": []}
	for id in ids:
		if id in streak_free():
			continue
		if Game.booster_count(id) > 0:
			Game.boosters[id] = Game.booster_count(id) - 1
		else:
			Game.scrap -= int(PRE[id]["price"])
	var apply := streak_free().duplicate()
	for id in ids:
		if not id in apply:
			apply.append(id)
	Game.changed.emit()
	return {"ok": true, "apply": apply}


## Adds a reward dictionary ({scrap, parts, <booster id>: n}) to the player's stock.
func grant(reward: Dictionary) -> void:
	for k in reward:
		match k:
			"scrap":
				Game.scrap += int(reward[k])
			"parts":
				Game.parts += int(reward[k])
			"lives":
				Game.lives = mini(Data.MAX_LIVES, Game.lives + int(reward[k]))
			_:
				Game.boosters[k] = Game.booster_count(k) + int(reward[k])
	Game.changed.emit()


## Short text for a reward ("+150 scrap, 1 Undo").
func reward_text(reward: Dictionary) -> String:
	var parts := []
	for k in reward:
		var n := int(reward[k])
		match k:
			"scrap", "parts":
				parts.append("+%d %s" % [n, k])
			"lives":
				parts.append("+%d live%s" % [n, "" if n == 1 else "s"])
			_:
				var d: Dictionary = PRE.get(k, Data.BOOSTERS.get(k, {"name": k}))
				parts.append("%d %s" % [n, d["name"]])
	return ", ".join(parts)


static func reward_icon(k: String) -> String:
	if k in ["scrap", "parts"]:
		return k
	if k == "lives":
		return "heart"
	return PRE.get(k, Data.BOOSTERS.get(k, {"icon": "gift"}))["icon"]


# ---------------------------------------------------------------- 7-day login calendar

## One claim per calendar day; day 7 is the big one, then the week starts over.
const CALENDAR := [
	{"scrap": 100},
	{"scrap": 150, "undo": 1},
	{"pre_cool": 2},
	{"scrap": 250, "tank": 1},
	{"pre_tank": 1, "flush": 1},
	{"scrap": 400, "pre_ash": 1},
	{"scrap": 800, "undo": 2, "tank": 2, "pre_cool": 2},
]


func today() -> String:
	return Time.get_date_string_from_system()


func cal_day() -> int:
	return int(m().get("cal_day", 0)) % CALENDAR.size()


func cal_ready() -> bool:
	return str(m().get("cal_date", "")) != today()


## Seconds until local midnight, when the next calendar reward opens.
func cal_in() -> float:
	var t := Time.get_time_dict_from_system()
	return maxf(0.0, 86400.0 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"])))


func claim_calendar() -> Dictionary:
	if not cal_ready():
		return {}
	var reward: Dictionary = CALENDAR[cal_day()]
	grant(reward)
	m()["cal_day"] = cal_day() + 1
	m()["cal_date"] = today()
	Game.save_game()
	changed.emit()
	return reward


# ---------------------------------------------------------------- Juno's story

## The train's engineer narrates the journey in one-line bubbles on the home screen.
const JUNO_NAME := "Juno"
const JUNO_PORTRAIT := "res://assets/sprites/crew/engineer_a_portrait.png"
const STORY := {
	"intro": "I'm Juno, the engineer. This old loco is all that got out of the heat. Win us parts and we'll rebuild her, carriage by carriage.",
	"built_cooling": "A Cooling Core! Every puzzle starts a little cooler from now on.",
	"built_condenser": "The Condenser pulls water out of the night air. It earns scrap even while you're away.",
	"built_quarters": "Real bunks at last. And look who snuck aboard with the timber: a fennec fox. I'm calling her Sandy.",
	"built_greenhouse": "Green leaves on a train in a desert. Don't tell me that isn't hope.",
	"built_recycler": "Every drop of water we use comes back clean. Out here that's worth more than gold.",
	"built_workshop": "A proper workshop! Now I can fix things instead of hitting them.",
	"built_dronebay": "Drones up. They'll scout the ruins ahead for anything worth salvaging.",
	"built_cargo": "A cargo hold. Finally somewhere to put all this scrap that isn't my bunk.",
	"built_lab": "The lab crew think the Mirror Array could cool a whole city. Let's find out.",
	"built_medbay": "A med bay. Heatstroke has taken too many of us. Not any more.",
	"region_1": "The Ash Coast. Somewhere under all that grey is a desalination plant. Get it running and the coast drinks again.",
	"region_2": "The Glass Flats. Mind your eyes, the mirrors still track the sun.",
	"region_3": "The Drowned City. The Seed Archive is down there, sealed and dry, if the old maps are right.",
	"region_4": "The Green Highlands. Cool air, real soil. This could be home.",
	"landmark": "We did it. Feel that breeze? That's the landmark running again.",
	"boss": "This one's guarded by the worst heat yet. Keep your head cool.",
	"rescue": "Mayday! One of the crew is cooking in the boiler room. Pull the right valves and get coolant to that pod!",
}
const UPGRADE_LINES := [
	"Another upgrade. She's starting to look like a real train again.",
	"Nice work. Sandy approves, I think. Hard to tell with foxes.",
	"Every part you win ends up bolted to something. I keep count.",
	"The crew sleeps better every time we fix something.",
	"Heat's still out there, but it's not winning any more.",
]


## Juno's line for a story event, or "" when it has nothing new to say. One-time lines
## (intro, first builds, regions) are remembered; upgrades get an occasional generic line.
func story_line(key: String) -> String:
	if key == "upgraded":
		return UPGRADE_LINES.pick_random() if randf() < 0.5 else ""
	if not STORY.has(key):
		return ""
	var seen: Dictionary = m().get("story", {})
	if seen.has(key) and key not in ["landmark", "boss", "rescue"]:
		return ""
	seen[key] = true
	m()["story"] = seen
	return STORY[key]


# ---------------------------------------------------------------- liveries

## Paint styles offered when a carriage is built (Homescapes-style three-way choice).
const LIVERIES := [
	{"name": "Desert Rust", "color": "c4572e"},
	{"name": "Teal Line", "color": "3fd8c2"},
	{"name": "Old Brass", "color": "e9b04a"},
	{"name": "Ash White", "color": "e8e4dc"},
	{"name": "Night Blue", "color": "3a6fd8"},
	{"name": "Cactus", "color": "6fbf4a"},
]


## The three liveries offered for a carriage (stable per carriage).
func livery_choices(uid: int) -> Array:
	var pool := LIVERIES.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = uid * 7919
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool.slice(0, 3)


func set_livery(uid: int, color: String) -> void:
	var c := Game.carriage(uid)
	if c.is_empty():
		return
	c["livery"] = color
	Game.save_game()
	changed.emit()


# ---------------------------------------------------------------- postcard album

## Six postcards per region. kind: "icon:<name>" or a texture path.
const ALBUM := [
	{"region": "Scorched Desert", "cards": [
		["tower", "Climate Tower", "icon:tower"], ["juno", "Juno", "res://assets/sprites/crew/engineer_a_portrait.png"],
		["loco", "The Old Loco", "res://assets/sprites/train/locomotive.png"], ["cooling", "Cooling Core", "res://assets/sprites/train/carriage_cooling_2.png"],
		["sandy", "Sandy the Fox", "res://assets/sprites/pet/fox_sit_0.png"], ["dunes", "Dune Sunset", "icon:sun"]]},
	{"region": "Ash Coast", "cards": [
		["desal", "Desalination Works", "icon:desal"], ["grower", "The Grower", "res://assets/sprites/crew/grower_a_portrait.png"],
		["drones", "Drone Bay", "res://assets/sprites/train/carriage_dronebay_3.png"], ["cargo", "Cargo Hold", "res://assets/sprites/train/carriage_cargo_2.png"],
		["mechanic", "The Mechanic", "res://assets/sprites/crew/mechanic_a_portrait.png"], ["water", "Fresh Water", "icon:water"]]},
	{"region": "Glass Flats", "cards": [
		["mirror", "Mirror Array", "icon:mirror"], ["lab", "Research Lab", "res://assets/sprites/train/carriage_lab_4.png"],
		["medbay", "Med Bay", "res://assets/sprites/train/carriage_medbay_2.png"], ["scientist", "The Scientist", "res://assets/sprites/crew/scientist_a_portrait.png"],
		["pilot", "The Pilot", "res://assets/sprites/crew/pilot_a_portrait.png"], ["glare", "Glare", "icon:sun"]]},
	{"region": "Drowned City", "cards": [
		["archive", "Seed Archive", "icon:archive"], ["greenhouse", "Greenhouse", "res://assets/sprites/train/carriage_greenhouse_7.png"],
		["medic", "The Medic", "res://assets/sprites/crew/medic_a_portrait.png"], ["workshop", "Workshop", "res://assets/sprites/train/carriage_workshop_7.png"],
		["seeds", "Seeds", "icon:food"], ["nap", "Sandy Asleep", "res://assets/sprites/pet/fox_sleep.png"]]},
	{"region": "Green Highlands", "cards": [
		["haven", "Haven", "icon:haven"], ["quarters", "Quarters", "res://assets/sprites/train/carriage_quarters_9.png"],
		["technician", "The Technician", "res://assets/sprites/crew/technician_a_portrait.png"], ["engineer", "The Engineer", "res://assets/sprites/crew/engineer_b_portrait.png"],
		["recycler", "Water Recycler", "res://assets/sprites/train/carriage_recycler_10.png"], ["home", "Home", "icon:home"]]},
]
const CARD_CHANCE := 0.35
const CARD_DUPLICATE_SCRAP := 25
const SET_REWARD := {"scrap": 500, "pre_tank": 1, "pre_cool": 2}


func cards() -> Array:
	return m().get("cards", [])


func has_card(id: String) -> bool:
	return id in cards()


func set_done(r: int) -> bool:
	for c in ALBUM[r]["cards"]:
		if not has_card(c[0]):
			return false
	return true


## After a win: maybe a postcard from the current region's set. Returns {} or
## {id, name, src, new, set_done} (a duplicate pays scrap instead).
func roll_card(force := false) -> Dictionary:
	if not force and randf() > CARD_CHANCE:
		return {}
	var r := mini(Game.region_index, ALBUM.size() - 1)
	var set: Array = ALBUM[r]["cards"]
	var missing := set.filter(func(c): return not has_card(c[0]))
	var pick: Array = missing.pick_random() if not missing.is_empty() and randf() < 0.7 else set.pick_random()
	var out := {"id": pick[0], "name": pick[1], "src": pick[2], "new": not has_card(pick[0]), "set_done": false}
	if out["new"]:
		var list := cards()
		list.append(pick[0])
		m()["cards"] = list
		if set_done(r):
			out["set_done"] = true
			grant(SET_REWARD)
	else:
		Game.scrap += CARD_DUPLICATE_SCRAP
	Game.save_game()
	changed.emit()
	return out


# ---------------------------------------------------------------- Heat Run (Lava Quest style)

## Win 7 levels in a row against 99 simulated crews; one loss and you are out. The survivors
## split the pool. Opens from level 20; a new run can start an hour after the last one ends.
const RUN_FROM_LEVEL := 20
const RUN_STEPS := 7
const RUN_CREWS := 100
const RUN_POOL := 10000
const RUN_SURVIVE := 0.72 # chance a simulated crew wins each step
const RUN_COOLDOWN := 3600.0


func run() -> Dictionary:
	return m().get("run", {"state": "idle"})


func run_open() -> bool:
	return Game.level >= RUN_FROM_LEVEL


func run_can_join() -> bool:
	var r := run()
	return run_open() and (r["state"] == "idle" or (r["state"] in ["won", "lost"] and Game.now() >= float(r.get("next_at", 0))))


## Survivors after each step (index 0 = start), fixed when the run starts.
static func run_survivors(seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var alive := RUN_CREWS - 1 # simulated crews; the player is added on top
	var out := [RUN_CREWS]
	for k in RUN_STEPS:
		var next := 0
		for i in alive:
			if rng.randf() < RUN_SURVIVE:
				next += 1
		alive = next
		out.append(alive + 1)
	return out


func run_join() -> bool:
	if not run_can_join():
		return false
	var seed := int(Game.now())
	m()["run"] = {"state": "running", "wins": 0, "seed": seed, "survivors": run_survivors(seed)}
	Game.save_game()
	changed.emit()
	return true


## Share of the pool for finishing the run with `alive` crews (including the player).
static func run_prize(alive: int) -> int:
	return maxi(100, RUN_POOL / maxi(1, alive))


func _heat_run_step(won: bool) -> void:
	var r := run()
	if r["state"] != "running":
		return
	if not won:
		r["state"] = "lost"
		r["next_at"] = Game.now() + RUN_COOLDOWN
		event_result.emit("run_lost", r)
	else:
		r["wins"] = int(r["wins"]) + 1
		if r["wins"] >= RUN_STEPS:
			var alive: int = r["survivors"][RUN_STEPS]
			var prize := run_prize(alive)
			Game.scrap += prize
			r["state"] = "won"
			r["prize"] = prize
			r["next_at"] = Game.now() + RUN_COOLDOWN
			event_result.emit("run_won", r)
	m()["run"] = r
	changed.emit()


# ---------------------------------------------------------------- weekly race (King's Cup style)

## A week-long leaderboard against 19 simulated crews: every win scores (heatwave 2, boss 3).
## Bots score at their own pace through the week. Top places pay when the week rolls over.
const RACE_FROM_LEVEL := 10
const RACE_BOTS := ["Dune Rats", "Rail Hawks", "Cinder Crew", "Ash Walkers", "Mirage Line", "Sun Dogs", "Copper Wheels",
	"Night Haulers", "Glass Wolves", "Salt Riders", "Ember Kids", "Iron Larks", "Dust Devils", "Tin Owls",
	"Cool Heads", "Far Signal", "Last Stop", "Red Valve", "Sand Swifts"]
const RACE_PRIZES := [
	{"scrap": 2000, "pre_tank": 2, "pre_cool": 2, "undo": 2},
	{"scrap": 1200, "pre_tank": 1, "undo": 1},
	{"scrap": 700, "pre_cool": 1},
]
const RACE_TOP10 := {"scrap": 200}
const WEEK := 604800.0
const WEEK_OFFSET := 345600.0 # unix week 0 starts on a Thursday; shift weeks to start Monday


static func week_of(t: float) -> int:
	return int(floor((t - WEEK_OFFSET) / WEEK))


static func week_end(week: int) -> float:
	return (week + 1) * WEEK + WEEK_OFFSET


func race_open() -> bool:
	return Game.level >= RACE_FROM_LEVEL


func race() -> Dictionary:
	var r: Dictionary = m().get("race", {})
	var wk := week_of(Game.now())
	if r.get("week", wk) != wk:
		_race_settle(r) # the week rolled over since the last look
		r = {}
	if r.is_empty():
		r = {"week": wk, "points": 0}
		m()["race"] = r
	return r


## Simulated scores for week `week` at time t: steady pace per crew with some lumps.
static func bot_scores(week: int, t: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = week * 977 + 13
	var hours := clampf((t - (week_end(week) - WEEK)) / 3600.0, 0.0, WEEK / 3600.0)
	var out := []
	for name in RACE_BOTS:
		var pace := rng.randf_range(0.08, 0.55) # points per hour
		var start := rng.randf_range(0.0, 30.0) # hours before they begin
		var lump := rng.randf_range(0.8, 1.2)
		out.append({"name": name, "points": int(maxf(0.0, hours - start) * pace * lump)})
	return out


## Sorted standings with the player included. [{name, points, you}]
func race_board(t := -1.0) -> Array:
	var r := race()
	var now := Game.now() if t < 0.0 else t
	var rows := bot_scores(int(r["week"]), now)
	rows.append({"name": "Your crew", "points": int(r["points"]), "you": true})
	rows.sort_custom(func(a, b): return a["points"] > b["points"] or (a["points"] == b["points"] and a.get("you", false)))
	return rows


func race_rank(t := -1.0) -> int:
	var rows := race_board(t)
	for i in rows.size():
		if rows[i].get("you", false):
			return i + 1
	return rows.size()


static func race_prize(rank: int) -> Dictionary:
	if rank <= RACE_PRIZES.size():
		return RACE_PRIZES[rank - 1]
	return RACE_TOP10 if rank <= 10 else {}


func _race_add(points: int) -> void:
	if not race_open():
		return
	var r := race()
	r["points"] = int(r["points"]) + points
	changed.emit()


## Pays last week's placing (called when a new week is first seen).
func _race_settle(r: Dictionary) -> void:
	if int(r.get("points", 0)) <= 0:
		return
	var wk := int(r["week"])
	var rows := bot_scores(wk, week_end(wk))
	rows.append({"name": "Your crew", "points": int(r["points"]), "you": true})
	rows.sort_custom(func(a, b): return a["points"] > b["points"] or (a["points"] == b["points"] and a.get("you", false)))
	var rank := rows.size()
	for i in rows.size():
		if rows[i].get("you", false):
			rank = i + 1
	var prize := race_prize(rank)
	if not prize.is_empty():
		grant(prize)
	event_result.emit.call_deferred("race_settled", {"rank": rank, "prize": prize, "points": int(r["points"])})


# ---------------------------------------------------------------- rescue missions

## Every 15th level won opens a pull-the-pin rescue mission (no lives at stake).
const RESCUE_EVERY := 15
const RESCUE_REWARD := {"scrap": 250, "undo": 1, "pre_cool": 1}


func rescue_pending() -> bool:
	return bool(m().get("rescue_pending", false))


func rescue_index() -> int:
	return int(m().get("rescues", 0))


func rescue_won() -> void:
	m()["rescue_pending"] = false
	m()["rescues"] = rescue_index() + 1
	grant(RESCUE_REWARD)
	Game.save_game()
	changed.emit()

class_name Data
extends RefCounted
## Static game definitions: puzzle rules, economy, boosters, the Condenser and the
## five regions with their train-restoration tasks.

const SAVE_VERSION := 3
const LEVELS_PATH := "res://data/levels.json"

# ---------------------------------------------------------------- puzzle
const CAPACITY := 4
const HEAT_START := 30.0 # °C at the first move (the Cooling Core lowers it)
const HEAT_MAX := 70.0 # overheat = level failed
const COMBO_WINDOW := 3.0 # seconds to chain tank completions into a cold snap
const COMBO_COOL := 3.0 # °C cooled per chained completion beyond the first
const FLUSH_COOL := 12.0 # Heat Flush booster
const CONTINUE_COOL := 15.0 # bought or watched continue after overheating
const HOT_FLARE := 8.0 # heat spike when a hot canister's countdown runs out
const HOT_DEFUSE_COOL := 2.0 # extra cooling for sealing a hot canister in time

## Blockers, introduced one at a time (levels from tools/gen_levels.py). Shown once, the first
## time a level with that blocker starts.
const BLOCKERS := {
	"frozen": {"title": "FROZEN TANK", "icon": "snowflake",
		"text": "This tank is iced shut. The number shows how many tanks you must seal before it thaws."},
	"hidden": {"title": "ASH CANISTERS", "icon": "ash",
		"text": "Ash hides some canisters. Clear the ones above to see what colour they are."},
	"lock": {"title": "TAGGED TANK", "icon": "tank",
		"text": "A tag on the rim means this tank only accepts that one colour."},
	"hot": {"title": "HOT CANISTER", "icon": "temp",
		"text": "Seal its colour before the countdown runs out, or it flares and heats the carriage by %d°C." % int(HOT_FLARE)},
}
const COLORS := ["red", "orange", "yellow", "lime", "teal", "blue", "purple", "pink", "white"]
const COLOR_HEX := ["e5484d", "f2873a", "f5cf3d", "8fd14f", "2fc2b0", "3f8cff", "9a5cf0", "f06fb4", "eef2f5"]

# ---------------------------------------------------------------- economy
const MAX_LIVES := 5
const LIFE_REGEN := 1200.0 # seconds per life
const WIN_SCRAP := 20
const HARD_SCRAP := 60
const COOL_BONUS_PER_DEG := 1 # extra scrap per °C left under the limit
const REFILL_COST := 400
const CONTINUE_COST := [250, 500, 800]
const START_SCRAP := 300

const BOOSTERS := {
	"undo": {"name": "Undo", "icon": "undo", "price": 120, "desc": "Take back your last pour."},
	"tank": {"name": "Spare Tank", "icon": "tank", "price": 300, "desc": "Adds an empty tank to this level."},
	"flush": {"name": "Heat Flush", "icon": "snowflake", "price": 180, "desc": "Cools the carriage by 12°C."},
}
const BOOSTER_ORDER := ["undo", "tank", "flush"]
const START_BOOSTERS := {"undo": 3, "tank": 1, "flush": 2}

# ---------------------------------------------------------------- condenser (offline earner)
## Night air is cooler: the Condenser harvests water into scrap while the player is away.
const CONDENSER_MAX := 10
const CONDENSER_MIN_CLAIM := 600.0 # seconds before anything is claimable


static func condenser_rate(level: int) -> float: # scrap per hour
	return 30.0 + 20.0 * (level - 1)


static func condenser_cap_hours(level: int) -> float:
	return minf(24.0, 8.0 + 4.0 * (level - 1))


static func condenser_upgrade_cost(level: int) -> int:
	return int(round(400.0 * pow(1.6, level - 1) / 10.0) * 10.0)


# ---------------------------------------------------------------- train
const CARRIAGES := {
	"locomotive": {"name": "Locomotive", "icon": "train"},
	"cooling": {"name": "Cooling Core", "icon": "cooling", "desc": "Each level starts every puzzle 1°C cooler."},
	"condenser": {"name": "Condenser", "icon": "condenser", "desc": "Harvests cool night air into scrap while you are away."},
	"quarters": {"name": "Living Quarters", "icon": "home"},
	"greenhouse": {"name": "Greenhouse", "icon": "food"},
	"recycler": {"name": "Water Recycler", "icon": "water"},
	"workshop": {"name": "Workshop", "icon": "parts"},
	"dronebay": {"name": "Drone Bay", "icon": "drone"},
	"cargo": {"name": "Cargo Hold", "icon": "crate"},
	"lab": {"name": "Research Lab", "icon": "flask"},
	"medbay": {"name": "Med Bay", "icon": "medkit"},
}
## The journey starts with the locomotive alone; every restoration task grows the train.
const START_TRAIN := [["locomotive", 1]]


## Decorative crew per carriage (the train is a home, not an economy any more).
static func crew_count(type: String, level: int) -> int:
	match type:
		"locomotive", "cargo": return 0
		"quarters": return mini(1 + level / 2, 4)
		"cooling", "condenser": return 1
	return mini(1 + level / 3, 3)


const ROLES_ALL := ["Engineer", "Grower", "Mechanic", "Pilot", "Technician", "Scientist", "Medic"]


static func crew_role(type: String) -> String:
	return {"greenhouse": "Grower", "recycler": "Mechanic", "workshop": "Engineer", "dronebay": "Pilot",
		"cooling": "Technician", "condenser": "Technician", "lab": "Scientist", "medbay": "Medic"}.get(type, "Engineer")


# ---------------------------------------------------------------- regions
## Each region: puzzle wins earn parts; parts complete restoration tasks in order; the last
## task restores the region's landmark, then the train departs for the next region.
## Task: {text, cost, type, level} upgrades (or adds) a carriage; {text, cost, landmark: true} ends it.
## Regions 2-5 raise every carriage one level at a time to Lv.10, so the train keeps growing
## until about level 700 of the 1000 authored levels.
const REGIONS := [
	{
		"region": "Scorched Desert", "scenery": "desert", "landmark": "tower", "landmark_name": "Climate Tower",
		"temp": 65, "ground": [0.0, Color(1, 1, 1)],
		"desc": "Only the old locomotive escaped the heat. Win levels for parts, rebuild the train carriage by carriage, then wake the dormant Climate Tower.",
		"done_text": "The tower hums once more. Cooler air rolls toward the coast, and the old desalination works lie within reach.",
		"tasks": [
			{"text": "Couple a Cooling Core", "cost": 1, "type": "cooling", "level": 1},
			{"text": "Couple the Condenser", "cost": 2, "type": "condenser", "level": 1},
			{"text": "Build the Living Quarters", "cost": 2, "type": "quarters", "level": 1},
			{"text": "Build a Greenhouse", "cost": 2, "type": "greenhouse", "level": 1},
			{"text": "Upgrade the Cooling Core", "cost": 3, "type": "cooling", "level": 2},
			{"text": "Build a Water Recycler", "cost": 3, "type": "recycler", "level": 1},
			{"text": "Expand the Living Quarters", "cost": 3, "type": "quarters", "level": 2},
			{"text": "Build a Workshop", "cost": 3, "type": "workshop", "level": 1},
			{"text": "Restore the Climate Tower", "cost": 5, "landmark": true},
		],
	},
	{
		"region": "Ash Coast", "scenery": "coast", "landmark": "desal", "landmark_name": "Desalination Works",
		"temp": 62, "ground": [0.85, Color("e4d8ec")],
		"desc": "A dead plant on a grey sea. Running again, it would turn the whole coast into a water source.",
		"done_text": "Fresh water pours from the works for the first time in decades. Beyond the coast, the Glass Flats glitter in the heat.",
		"tasks": [
			{"text": "Build a Drone Bay", "cost": 4, "type": "dronebay", "level": 1},
			{"text": "Grow the Greenhouse to Lv.2", "cost": 4, "type": "greenhouse", "level": 2},
			{"text": "Upgrade the Water Recycler to Lv.2", "cost": 4, "type": "recycler", "level": 2},
			{"text": "Upgrade the Workshop to Lv.2", "cost": 4, "type": "workshop", "level": 2},
			{"text": "Build a Cargo Hold", "cost": 4, "type": "cargo", "level": 1},
			{"text": "Upgrade the Drone Bay to Lv.2", "cost": 4, "type": "dronebay", "level": 2},
			{"text": "Upgrade the Cargo Hold to Lv.2", "cost": 4, "type": "cargo", "level": 2},
			{"text": "Upgrade the Cooling Core to Lv.3", "cost": 5, "type": "cooling", "level": 3},
			{"text": "Build a Research Lab", "cost": 5, "type": "lab", "level": 1},
			{"text": "Upgrade the Research Lab to Lv.2", "cost": 5, "type": "lab", "level": 2},
			{"text": "Expand the Living Quarters to Lv.3", "cost": 5, "type": "quarters", "level": 3},
			{"text": "Grow the Greenhouse to Lv.3", "cost": 5, "type": "greenhouse", "level": 3},
			{"text": "Upgrade the Water Recycler to Lv.3", "cost": 5, "type": "recycler", "level": 3},
			{"text": "Upgrade the Workshop to Lv.3", "cost": 5, "type": "workshop", "level": 3},
			{"text": "Upgrade the Drone Bay to Lv.3", "cost": 5, "type": "dronebay", "level": 3},
			{"text": "Upgrade the Cargo Hold to Lv.3", "cost": 5, "type": "cargo", "level": 3},
			{"text": "Upgrade the Research Lab to Lv.3", "cost": 5, "type": "lab", "level": 3},
			{"text": "Upgrade the Cooling Core to Lv.4", "cost": 5, "type": "cooling", "level": 4},
			{"text": "Expand the Living Quarters to Lv.4", "cost": 6, "type": "quarters", "level": 4},
			{"text": "Grow the Greenhouse to Lv.4", "cost": 6, "type": "greenhouse", "level": 4},
			{"text": "Upgrade the Water Recycler to Lv.4", "cost": 6, "type": "recycler", "level": 4},
			{"text": "Upgrade the Workshop to Lv.4", "cost": 6, "type": "workshop", "level": 4},
			{"text": "Upgrade the Drone Bay to Lv.4", "cost": 6, "type": "dronebay", "level": 4},
			{"text": "Upgrade the Cargo Hold to Lv.4", "cost": 6, "type": "cargo", "level": 4},
			{"text": "Upgrade the Research Lab to Lv.4", "cost": 6, "type": "lab", "level": 4},
			{"text": "Restore the Desalination Works", "cost": 8, "landmark": true},
		],
	},
	{
		"region": "Glass Flats", "scenery": "glass", "landmark": "mirror", "landmark_name": "Mirror Array",
		"temp": 68, "ground": [0.55, Color("fff6e2")],
		"desc": "A field of giant mirrors around a power tower. Restored, it could power a city — or cool one.",
		"done_text": "The mirrors swing back toward the sun and the tower glows white. With power to spare, the drowned city is within reach.",
		"tasks": [
			{"text": "Build a Med Bay", "cost": 6, "type": "medbay", "level": 1},
			{"text": "Upgrade the Med Bay to Lv.2", "cost": 6, "type": "medbay", "level": 2},
			{"text": "Upgrade the Med Bay to Lv.3", "cost": 6, "type": "medbay", "level": 3},
			{"text": "Upgrade the Med Bay to Lv.4", "cost": 6, "type": "medbay", "level": 4},
			{"text": "Upgrade the Cooling Core to Lv.5", "cost": 7, "type": "cooling", "level": 5},
			{"text": "Expand the Living Quarters to Lv.5", "cost": 7, "type": "quarters", "level": 5},
			{"text": "Grow the Greenhouse to Lv.5", "cost": 7, "type": "greenhouse", "level": 5},
			{"text": "Upgrade the Water Recycler to Lv.5", "cost": 7, "type": "recycler", "level": 5},
			{"text": "Upgrade the Workshop to Lv.5", "cost": 7, "type": "workshop", "level": 5},
			{"text": "Upgrade the Drone Bay to Lv.5", "cost": 7, "type": "dronebay", "level": 5},
			{"text": "Upgrade the Cargo Hold to Lv.5", "cost": 7, "type": "cargo", "level": 5},
			{"text": "Upgrade the Research Lab to Lv.5", "cost": 8, "type": "lab", "level": 5},
			{"text": "Upgrade the Med Bay to Lv.5", "cost": 8, "type": "medbay", "level": 5},
			{"text": "Upgrade the Cooling Core to Lv.6", "cost": 8, "type": "cooling", "level": 6},
			{"text": "Expand the Living Quarters to Lv.6", "cost": 8, "type": "quarters", "level": 6},
			{"text": "Grow the Greenhouse to Lv.6", "cost": 8, "type": "greenhouse", "level": 6},
			{"text": "Upgrade the Water Recycler to Lv.6", "cost": 8, "type": "recycler", "level": 6},
			{"text": "Upgrade the Workshop to Lv.6", "cost": 8, "type": "workshop", "level": 6},
			{"text": "Upgrade the Drone Bay to Lv.6", "cost": 9, "type": "dronebay", "level": 6},
			{"text": "Upgrade the Cargo Hold to Lv.6", "cost": 9, "type": "cargo", "level": 6},
			{"text": "Upgrade the Research Lab to Lv.6", "cost": 9, "type": "lab", "level": 6},
			{"text": "Upgrade the Med Bay to Lv.6", "cost": 9, "type": "medbay", "level": 6},
			{"text": "Restore the Mirror Array", "cost": 10, "landmark": true},
		],
	},
	{
		"region": "Drowned City", "scenery": "city", "landmark": "archive", "landmark_name": "Seed Archive",
		"temp": 64, "ground": [0.45, Color("d4bcbc")],
		"desc": "A sealed vault under a flooded city. Inside: seeds for every crop that ever grew here.",
		"done_text": "The vault doors grind open. Thousands of seed packets, still dry. Somewhere ahead, the highlands are waiting for them.",
		"tasks": [
			{"text": "Upgrade the Cooling Core to Lv.7", "cost": 8, "type": "cooling", "level": 7},
			{"text": "Expand the Living Quarters to Lv.7", "cost": 8, "type": "quarters", "level": 7},
			{"text": "Grow the Greenhouse to Lv.7", "cost": 8, "type": "greenhouse", "level": 7},
			{"text": "Upgrade the Water Recycler to Lv.7", "cost": 9, "type": "recycler", "level": 7},
			{"text": "Upgrade the Workshop to Lv.7", "cost": 9, "type": "workshop", "level": 7},
			{"text": "Upgrade the Drone Bay to Lv.7", "cost": 9, "type": "dronebay", "level": 7},
			{"text": "Upgrade the Cargo Hold to Lv.7", "cost": 9, "type": "cargo", "level": 7},
			{"text": "Upgrade the Research Lab to Lv.7", "cost": 10, "type": "lab", "level": 7},
			{"text": "Upgrade the Med Bay to Lv.7", "cost": 10, "type": "medbay", "level": 7},
			{"text": "Upgrade the Cooling Core to Lv.8", "cost": 10, "type": "cooling", "level": 8},
			{"text": "Expand the Living Quarters to Lv.8", "cost": 10, "type": "quarters", "level": 8},
			{"text": "Grow the Greenhouse to Lv.8", "cost": 11, "type": "greenhouse", "level": 8},
			{"text": "Upgrade the Water Recycler to Lv.8", "cost": 11, "type": "recycler", "level": 8},
			{"text": "Upgrade the Workshop to Lv.8", "cost": 11, "type": "workshop", "level": 8},
			{"text": "Upgrade the Drone Bay to Lv.8", "cost": 11, "type": "dronebay", "level": 8},
			{"text": "Upgrade the Cargo Hold to Lv.8", "cost": 12, "type": "cargo", "level": 8},
			{"text": "Upgrade the Research Lab to Lv.8", "cost": 12, "type": "lab", "level": 8},
			{"text": "Upgrade the Med Bay to Lv.8", "cost": 12, "type": "medbay", "level": 8},
			{"text": "Restore the Seed Archive", "cost": 13, "landmark": true},
		],
	},
	{
		"region": "Green Highlands", "scenery": "highland", "landmark": "haven", "landmark_name": "Haven",
		"temp": 60, "ground": [0.55, Color("dce4b0")],
		"desc": "The coolest place left on the line. Here the colony can finally step off the train and build a home.",
		"done_text": "Haven is founded. For the first time since the heat came, children sleep in houses that do not move. The line goes on, and so does Railhaven.",
		"tasks": [
			{"text": "Upgrade the Cooling Core to Lv.9", "cost": 11, "type": "cooling", "level": 9},
			{"text": "Expand the Living Quarters to Lv.9", "cost": 11, "type": "quarters", "level": 9},
			{"text": "Grow the Greenhouse to Lv.9", "cost": 11, "type": "greenhouse", "level": 9},
			{"text": "Upgrade the Water Recycler to Lv.9", "cost": 12, "type": "recycler", "level": 9},
			{"text": "Upgrade the Workshop to Lv.9", "cost": 12, "type": "workshop", "level": 9},
			{"text": "Upgrade the Drone Bay to Lv.9", "cost": 12, "type": "dronebay", "level": 9},
			{"text": "Upgrade the Cargo Hold to Lv.9", "cost": 12, "type": "cargo", "level": 9},
			{"text": "Upgrade the Research Lab to Lv.9", "cost": 13, "type": "lab", "level": 9},
			{"text": "Upgrade the Med Bay to Lv.9", "cost": 13, "type": "medbay", "level": 9},
			{"text": "Upgrade the Cooling Core to Lv.10", "cost": 13, "type": "cooling", "level": 10},
			{"text": "Expand the Living Quarters to Lv.10", "cost": 13, "type": "quarters", "level": 10},
			{"text": "Grow the Greenhouse to Lv.10", "cost": 14, "type": "greenhouse", "level": 10},
			{"text": "Upgrade the Water Recycler to Lv.10", "cost": 14, "type": "recycler", "level": 10},
			{"text": "Upgrade the Workshop to Lv.10", "cost": 14, "type": "workshop", "level": 10},
			{"text": "Upgrade the Drone Bay to Lv.10", "cost": 14, "type": "dronebay", "level": 10},
			{"text": "Upgrade the Cargo Hold to Lv.10", "cost": 15, "type": "cargo", "level": 10},
			{"text": "Upgrade the Research Lab to Lv.10", "cost": 15, "type": "lab", "level": 10},
			{"text": "Upgrade the Med Bay to Lv.10", "cost": 15, "type": "medbay", "level": 10},
			{"text": "Found Haven", "cost": 16, "landmark": true},
		],
	},
]

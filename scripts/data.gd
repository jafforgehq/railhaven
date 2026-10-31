class_name Data
extends RefCounted
## Static game definitions and balance curves. All rates are per second.

const SAVE_VERSION := 1
const MAX_LEVEL := 5
const MAX_CARRIAGES := 10
const MAX_OFFLINE_SEC := 8.0 * 3600.0

const RES := ["scrap", "parts", "food", "water"]
const RES_NAMES := {"scrap": "Scrap", "parts": "Parts", "food": "Food", "water": "Water"}

# Per-survivor upkeep, per second (0.6 / min).
const FOOD_PER_SURVIVOR := 0.01
const WATER_PER_SURVIVOR := 0.01
const GROWTH_INTERVAL := 90.0
const SCRAP_PER_PART := 2.0
const DRONE_RUN_TIME := 30.0
const DRONE_YIELD := 14.0
const SURVIVOR_FIND_CHANCE := 0.08
const ROLE_BONUS := 1.25
const TRAIN_SPEED := 0.2 # km per second
const TOWER_DISTANCE := 120.0

const BASE_STORAGE := {"scrap": 150.0, "parts": 60.0, "food": 100.0, "water": 100.0}
const START_RES := {"scrap": 100.0, "parts": 25.0, "food": 60.0, "water": 60.0}

const CARRIAGES := {
	"locomotive": {
		"name": "Locomotive", "icon": "train",
		"desc": "The armored heart of the train. Upgrades enlarge the cargo hold and speed up the journey.",
		"upgrade": {"scrap": 90, "parts": 40},
	},
	"quarters": {
		"name": "Living Quarters", "icon": "home",
		"desc": "Bunks and a mess table. Provides beds for more survivors.",
		"build": {"scrap": 50, "parts": 15}, "upgrade": {"scrap": 45, "parts": 25},
	},
	"greenhouse": {
		"name": "Greenhouse", "icon": "food", "res": "food", "role": "Grower",
		"desc": "Hydroponic racks under grow lamps. Workers grow food for the crew.",
		"build": {"scrap": 60, "parts": 20}, "upgrade": {"scrap": 50, "parts": 30},
	},
	"recycler": {
		"name": "Water Recycler", "icon": "water", "res": "water", "role": "Mechanic",
		"desc": "Filters, condensers and tanks. Workers recover usable water.",
		"build": {"scrap": 70, "parts": 25}, "upgrade": {"scrap": 55, "parts": 35},
	},
	"workshop": {
		"name": "Workshop", "icon": "parts", "res": "parts", "role": "Engineer",
		"desc": "Benches and lathes. Workers convert scrap into mechanical parts.",
		"build": {"scrap": 90, "parts": 20}, "upgrade": {"scrap": 60, "parts": 20},
	},
	"cooling": {
		"name": "Cooling Module", "icon": "cooling", "role": "Technician",
		"desc": "Heat exchangers and fans. Lets the train support more carriages.",
		"build": {"scrap": 80, "parts": 30}, "upgrade": {"scrap": 70, "parts": 40},
	},
	"dronebay": {
		"name": "Drone Bay", "icon": "drone", "res": "scrap", "role": "Pilot",
		"desc": "Launch pads and repair arms. Drones salvage scrap from the ruins automatically.",
		"build": {"scrap": 70, "parts": 30}, "upgrade": {"scrap": 60, "parts": 35},
	},
}
const BUILDABLE := ["quarters", "greenhouse", "recycler", "workshop", "cooling", "dronebay"]

const ROLES := ["Engineer", "Grower", "Mechanic", "Pilot", "Technician"]
const ROLE_JOB := {"Engineer": "workshop", "Grower": "greenhouse", "Mechanic": "recycler", "Pilot": "dronebay", "Technician": "cooling"}
const NAMES := ["Mara", "Ivo", "Nia", "Tomas", "Rhea", "Jun", "Odile", "Kasim", "Lena", "Bram", "Sefa", "Pell",
	"Yara", "Doran", "Ines", "Wick", "Talia", "Oren", "Mila", "Cato", "Esra", "Fenn", "Gia", "Hollis",
	"Juno", "Kai", "Luka", "Noor", "Rafe", "Suvi", "Teo", "Vera", "Wren", "Zane", "Ada", "Bex"]

const REGIONS := [
	{"id": "basin", "name": "Dry Basin", "desc": "Where the colony first boarded. Nothing left but cracked salt."},
	{"id": "tower", "name": "Climate Tower", "desc": "A dormant weather tower. Restored, it could cool the land around it."},
	{"id": "ash", "name": "Ash Coast", "desc": "A cooler shore beyond the tower. Habitable zones, new settlements."},
]

const TOWER_STAGES := [
	{"name": "Repair the power relays", "cost": {"parts": 60, "scrap": 40}, "time": 60.0,
		"req": {"dronebay": 2}, "desc": "Drones carry parts to the tower and patch its relays."},
	{"name": "Flush the coolant lines", "cost": {"parts": 120, "water": 60}, "time": 90.0,
		"req": {"cooling": 1, "survivors": 10}, "desc": "Pump recycled water through the frozen coolant loop."},
	{"name": "Reboot the climate core", "cost": {"parts": 200, "water": 80}, "time": 120.0,
		"req": {"dronebay": 3, "workshop": 3}, "desc": "A full drone squadron restarts the core remotely."},
]

const GOALS := [
	{"text": "Assign a worker to the Workshop", "kind": "assign", "arg": "workshop", "n": 1, "reward": {"scrap": 30}},
	{"text": "Salvage 60 scrap with drones", "kind": "salvaged", "n": 60, "reward": {"parts": 15}},
	{"text": "Build a Greenhouse", "kind": "build", "arg": "greenhouse", "n": 1, "reward": {"scrap": 40}},
	{"text": "Staff the Greenhouse", "kind": "assign", "arg": "greenhouse", "n": 1, "reward": {"food": 30}},
	{"text": "Build a Cooling Module", "kind": "build", "arg": "cooling", "n": 1, "reward": {"parts": 25}},
	{"text": "Build a Water Recycler", "kind": "build", "arg": "recycler", "n": 1, "reward": {"water": 40}},
	{"text": "Upgrade the Workshop to Lv.2", "kind": "level", "arg": "workshop", "n": 2, "reward": {"scrap": 60}},
	{"text": "Upgrade the Drone Bay to Lv.2", "kind": "level", "arg": "dronebay", "n": 2, "reward": {"parts": 30}},
	{"text": "Reach the Climate Tower", "kind": "distance", "n": 120, "reward": {"scrap": 80}},
	{"text": "Shelter 10 survivors", "kind": "survivors", "n": 10, "reward": {"parts": 40}},
	{"text": "Restore the Climate Tower", "kind": "tower", "n": 3, "reward": {}},
]

const EVENTS := {
	"heatwave": {
		"title": "HEATWAVE AHEAD", "sub": "Extreme temperatures incoming",
		"text": "A heatwave will push outside temperatures to 78°C. Choose how to prepare.",
		"duration": 120.0,
		"a": {"label": "BOOST COOLING", "title": "Boost cooling", "desc": "Run the exchangers hard to keep full operations.", "cost": {"water": 40}, "effect": "Full production", "icon": "cooling"},
		"b": {"label": "SAFE MODE", "title": "Safe mode", "desc": "Reduce load and prioritise crew safety.", "cost": {}, "effect": "Production -30%", "icon": "shield"},
	},
	"sandstorm": {
		"title": "SANDSTORM", "sub": "Visibility near zero",
		"text": "A wall of hot sand is rolling over the tracks. The drones are in the air.",
		"duration": 90.0,
		"a": {"label": "FLY THROUGH", "title": "Reinforce drones", "desc": "Patch rotors and keep salvaging.", "cost": {"parts": 15}, "effect": "Salvage continues", "icon": "drone"},
		"b": {"label": "GROUND DRONES", "title": "Ground drones", "desc": "Recall the fleet until the storm passes.", "cost": {}, "effect": "Salvage paused", "icon": "shield"},
	},
	"signal": {
		"title": "DISTRESS SIGNAL", "sub": "Survivors near the tracks",
		"text": "A flare rises from a buried outpost. Someone is still out there.",
		"duration": 0.0,
		"a": {"label": "RESCUE", "title": "Send a rescue drone", "desc": "Bring them aboard. Needs free beds.", "cost": {"parts": 20, "food": 20}, "effect": "+2 survivors", "icon": "crew"},
		"b": {"label": "TRADE", "title": "Trade supplies", "desc": "Lower a crate of food for their salvage.", "cost": {"food": 30}, "effect": "+60 scrap", "icon": "scrap"},
	},
}


static func def(type: String) -> Dictionary:
	return CARRIAGES[type]


static func scaled_cost(base: Dictionary, mult: float) -> Dictionary:
	var out := {}
	for k in base:
		out[k] = int(round(base[k] * mult / 5.0) * 5.0)
	return out


static func build_cost(type: String, owned: int) -> Dictionary:
	return scaled_cost(CARRIAGES[type]["build"], pow(1.7, owned))


static func upgrade_cost(type: String, level: int) -> Dictionary:
	return scaled_cost(CARRIAGES[type]["upgrade"], pow(1.8, level - 1))


## Worker slots for a carriage type at a level.
static func slots(type: String, level: int) -> int:
	match type:
		"greenhouse", "recycler", "workshop":
			return [2, 2, 3, 3, 4][level - 1]
		"dronebay":
			return [1, 1, 2, 2, 2][level - 1]
		"cooling":
			return 1
	return 0


## Output per worker-power per second (food, water or parts).
static func worker_rate(type: String, level: int) -> float:
	var mult := 1.0 + 0.4 * (level - 1)
	match type:
		"greenhouse": return 0.1 * mult
		"recycler": return 0.1 * mult
		"workshop": return 0.05 * mult
	return 0.0


static func beds(level: int) -> int:
	return 6 + 3 * (level - 1)


static func drones(level: int) -> int:
	return level


static func cooling_capacity(level: int, staffed: bool) -> int:
	return level + 1 + (1 if staffed else 0)


static func storage_bonus(type: String, level: int) -> Dictionary:
	match type:
		"greenhouse": return {"food": 100.0 * level}
		"recycler": return {"water": 100.0 * level}
		"workshop": return {"parts": 60.0 * level}
		"dronebay": return {"scrap": 120.0 * level}
	return {}


static func loco_mult(level: int) -> float:
	return 1.0 + 0.5 * (level - 1)


static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		parts.append("%d %s" % [cost[k], RES_NAMES.get(k, k)])
	return ", ".join(parts)

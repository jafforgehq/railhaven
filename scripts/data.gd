class_name Data
extends RefCounted
## Static game definitions and balance curves. All rates are per second.

const SAVE_VERSION := 2
const MAX_LEVEL := 10 # absolute; the current chapter sets the real cap (Game.level_cap())
const MAX_OFFLINE_SEC := 8.0 * 3600.0

## All stored resources. The top bar shows CORE only; data lives in the Research sheet.
const RES := ["scrap", "parts", "food", "water", "data"]
const CORE := ["scrap", "parts", "food", "water"]
const RES_NAMES := {"scrap": "Scrap", "parts": "Parts", "food": "Food", "water": "Water", "data": "Data"}

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
const XP_BASE := 600.0 # seconds of work for crew level 2; level L needs XP_BASE * (L-1)^2
const MAX_CREW_LEVEL := 10
const CREW_LEVEL_BONUS := 0.06 # output per crew level above 1

const BASE_STORAGE := {"scrap": 150.0, "parts": 60.0, "food": 100.0, "water": 100.0, "data": 60.0}
const START_RES := {"scrap": 100.0, "parts": 25.0, "food": 60.0, "water": 60.0, "data": 0.0}

## "chapter" = first chapter (0-based) in which the type can be built.
const CARRIAGES := {
	"locomotive": {
		"name": "Locomotive", "icon": "train",
		"desc": "The armored heart of the train. Upgrades enlarge the cargo hold and speed up the journey.",
		"upgrade": {"scrap": 90, "parts": 40},
	},
	"quarters": {
		"name": "Living Quarters", "icon": "home", "chapter": 0,
		"desc": "Bunks and a mess table. Provides beds for more survivors.",
		"build": {"scrap": 50, "parts": 15}, "upgrade": {"scrap": 45, "parts": 25},
	},
	"greenhouse": {
		"name": "Greenhouse", "icon": "food", "res": "food", "role": "Grower", "chapter": 0,
		"desc": "Hydroponic racks under grow lamps. Workers grow food for the crew.",
		"build": {"scrap": 60, "parts": 20}, "upgrade": {"scrap": 50, "parts": 30},
	},
	"recycler": {
		"name": "Water Recycler", "icon": "water", "res": "water", "role": "Mechanic", "chapter": 0,
		"desc": "Filters, condensers and tanks. Workers recover usable water.",
		"build": {"scrap": 70, "parts": 25}, "upgrade": {"scrap": 55, "parts": 35},
	},
	"workshop": {
		"name": "Workshop", "icon": "parts", "res": "parts", "role": "Engineer", "chapter": 0,
		"desc": "Benches and lathes. Workers convert scrap into mechanical parts.",
		"build": {"scrap": 90, "parts": 20}, "upgrade": {"scrap": 60, "parts": 20},
	},
	"cooling": {
		"name": "Cooling Module", "icon": "cooling", "role": "Technician", "chapter": 0,
		"desc": "Heat exchangers and fans. Lets the train support more carriages.",
		"build": {"scrap": 80, "parts": 30}, "upgrade": {"scrap": 70, "parts": 40},
	},
	"dronebay": {
		"name": "Drone Bay", "icon": "drone", "res": "scrap", "role": "Pilot", "chapter": 0,
		"desc": "Launch pads and repair arms. Drones salvage scrap from the ruins automatically.",
		"build": {"scrap": 70, "parts": 30}, "upgrade": {"scrap": 60, "parts": 35},
	},
	"cargo": {
		"name": "Cargo Hold", "icon": "crate", "chapter": 1,
		"desc": "Racks, tanks and crates. Stores more of every resource.",
		"build": {"scrap": 400, "parts": 120}, "upgrade": {"scrap": 260, "parts": 90},
	},
	"lab": {
		"name": "Research Lab", "icon": "flask", "res": "data", "role": "Scientist", "chapter": 1,
		"desc": "Consoles and sample tubes. Scientists gather data for research projects.",
		"build": {"scrap": 500, "parts": 200}, "upgrade": {"scrap": 300, "parts": 140},
	},
	"medbay": {
		"name": "Med Bay", "icon": "medkit", "role": "Medic", "chapter": 2,
		"desc": "Beds, coolers and medicine. Healthy crew work harder and new survivors recover faster.",
		"build": {"scrap": 1500, "parts": 500}, "upgrade": {"scrap": 700, "parts": 300},
	},
}
const BUILDABLE := ["quarters", "greenhouse", "recycler", "workshop", "cooling", "dronebay", "cargo", "lab", "medbay"]

const ROLES := ["Engineer", "Grower", "Mechanic", "Pilot", "Technician", "Scientist", "Medic"]
const ROLE_JOB := {"Engineer": "workshop", "Grower": "greenhouse", "Mechanic": "recycler", "Pilot": "dronebay",
	"Technician": "cooling", "Scientist": "lab", "Medic": "medbay"}
const NAMES := ["Mara", "Ivo", "Nia", "Tomas", "Rhea", "Jun", "Odile", "Kasim", "Lena", "Bram", "Sefa", "Pell",
	"Yara", "Doran", "Ines", "Wick", "Talia", "Oren", "Mila", "Cato", "Esra", "Fenn", "Gia", "Hollis",
	"Juno", "Kai", "Luka", "Noor", "Rafe", "Suvi", "Teo", "Vera", "Wren", "Zane", "Ada", "Bex",
	"Arlo", "Bea", "Cyrus", "Dalia", "Emre", "Faye", "Gus", "Hana", "Idris", "Jett", "Kira", "Lior",
	"Maeve", "Nico", "Olga", "Pim", "Quill", "Rosa", "Sami", "Tova", "Uma", "Vik", "Wes", "Xan",
	"Yusuf", "Zia", "Amos", "Brin", "Cleo", "Dov", "Edda", "Finn", "Greer", "Hugo", "Isla", "Jory"]

## The journey: one chapter per region, each ending with a landmark restored by drone expeditions.
## level_cap / train = carriage level cap and carriages behind the locomotive in this chapter.
## perk = production multipliers while the train is in this region.
## ground = [desaturation, tint] for the shared near/track/front strips in this region.
const CHAPTERS := [
	{
		"region": "Scorched Desert", "scenery": "desert", "landmark": "tower", "landmark_name": "Climate Tower",
		"temp": 65, "distance": 120.0, "level_cap": 5, "train": 10, "perk": {}, "perk_text": "",
		"ground": [0.0, Color(1, 1, 1)],
		"desc": "A dormant weather tower. Restored, it could cool the land around it.",
		"done_text": "The tower hums once more. Cooler air rolls toward the coast, and the old desalination works lie within reach.",
		"goals": [
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
		],
		"stages": [
			{"name": "Repair the power relays", "cost": {"parts": 60, "scrap": 40}, "time": 60.0,
				"req": {"dronebay": 2}, "desc": "Drones carry parts to the tower and patch its relays."},
			{"name": "Flush the coolant lines", "cost": {"parts": 120, "water": 60}, "time": 90.0,
				"req": {"cooling": 1, "survivors": 10}, "desc": "Pump recycled water through the frozen coolant loop."},
			{"name": "Reboot the climate core", "cost": {"parts": 200, "water": 50}, "time": 120.0,
				"req": {"dronebay": 3, "workshop": 3}, "desc": "A full drone squadron restarts the core remotely."},
		],
	},
	{
		"region": "Ash Coast", "scenery": "coast", "landmark": "desal", "landmark_name": "Desalination Works",
		"temp": 62, "distance": 520.0, "level_cap": 6, "train": 12, "perk": {"water": 1.25},
		"perk_text": "Sea air: +25% water", "ground": [0.85, Color("e4d8ec")],
		"desc": "A dead plant on a grey sea. Running again, it would turn the whole coast into a water source.",
		"done_text": "Fresh water pours from the works for the first time in decades. Beyond the coast, the Glass Flats glitter in the heat.",
		"goals": [
			{"text": "Build a Cargo Hold", "kind": "build", "arg": "cargo", "n": 1, "reward": {"parts": 80}},
			{"text": "Build a Research Lab", "kind": "build", "arg": "lab", "n": 1, "reward": {"scrap": 200}},
			{"text": "Staff the Research Lab", "kind": "assign", "arg": "lab", "n": 1, "reward": {"data": 20}},
			{"text": "Finish your first research", "kind": "research", "n": 1, "reward": {"parts": 120}},
			{"text": "Upgrade the Water Recycler to Lv.4", "kind": "level", "arg": "recycler", "n": 4, "reward": {"water": 150}},
			{"text": "Reach the Desalination Works", "kind": "distance", "n": 520, "reward": {"scrap": 400}},
			{"text": "Shelter 22 survivors", "kind": "survivors", "n": 22, "reward": {"parts": 200}},
			{"text": "Restore the Desalination Works", "kind": "tower", "n": 3, "reward": {}},
		],
		"stages": [
			{"name": "Clear the intake pipes", "cost": {"parts": 550, "scrap": 1100}, "time": 600.0,
				"req": {"dronebay": 4}, "desc": "Drones cut away decades of ash and salt from the sea intakes."},
			{"name": "Rebuild the pump hall", "cost": {"parts": 1100, "water": 400}, "time": 900.0,
				"req": {"workshop": 5, "lab": 2}, "desc": "Prime the pumps with your own water while the drones refit them."},
			{"name": "Restart the boilers", "cost": {"parts": 1900, "water": 650, "data": 200}, "time": 1200.0,
				"req": {"recycler": 5, "cooling": 3}, "desc": "Your scientists tune the boilers remotely as the drones fire them up."},
		],
	},
	{
		"region": "Glass Flats", "scenery": "glass", "landmark": "mirror", "landmark_name": "Mirror Array",
		"temp": 68, "distance": 760.0, "level_cap": 7, "train": 15, "perk": {"parts": 1.2},
		"perk_text": "Fused-glass salvage: +20% parts", "ground": [0.55, Color("fff6e2")],
		"desc": "A field of giant mirrors around a power tower. Restored, it could power a city — or cool one.",
		"done_text": "The mirrors swing back toward the sun and the tower glows white. With power to spare, the drones can finally reach the drowned city.",
		"goals": [
			{"text": "Build a Med Bay", "kind": "build", "arg": "medbay", "n": 1, "reward": {"food": 300}},
			{"text": "Staff the Med Bay", "kind": "assign", "arg": "medbay", "n": 1, "reward": {"parts": 300}},
			{"text": "Build a second Living Quarters", "kind": "build", "arg": "quarters", "n": 2, "reward": {"food": 400}},
			{"text": "Train a worker to Lv.7", "kind": "crew_level", "n": 7, "reward": {"data": 120}},
			{"text": "Finish 9 research projects", "kind": "research", "n": 9, "reward": {"scrap": 1500}},
			{"text": "Upgrade the Drone Bay to Lv.7", "kind": "level", "arg": "dronebay", "n": 7, "reward": {"parts": 500}},
			{"text": "Reach the Mirror Array", "kind": "distance", "n": 760, "reward": {"water": 600}},
			{"text": "Shelter 32 survivors", "kind": "survivors", "n": 32, "reward": {"parts": 800}},
			{"text": "Restore the Mirror Array", "kind": "tower", "n": 4, "reward": {}},
		],
		"stages": [
			{"name": "Polish the heliostats", "cost": {"parts": 2050, "water": 700}, "time": 1200.0,
				"req": {"dronebay": 6}, "desc": "Drones scrub sand-blasted mirrors one by one."},
			{"name": "Realign the mirror field", "cost": {"parts": 3450, "data": 350}, "time": 1800.0,
				"req": {"lab": 4}, "desc": "Your scientists compute a new aim for every mirror."},
			{"name": "Rewire the receiver", "cost": {"parts": 5200, "scrap": 10350}, "time": 2400.0,
				"req": {"workshop": 7, "medbay": 2}, "desc": "Heat-proof crews guide the drones through the glare."},
			{"name": "Ignite the power tower", "cost": {"parts": 6900, "water": 2300, "data": 700}, "time": 3000.0,
				"req": {"cooling": 6, "survivors": 34}, "desc": "Everyone on board watches the receiver light up."},
		],
	},
	{
		"region": "Drowned City", "scenery": "city", "landmark": "archive", "landmark_name": "Seed Archive",
		"temp": 64, "distance": 1300.0, "level_cap": 8, "train": 17, "perk": {"scrap": 1.3},
		"perk_text": "Endless ruins: +30% scrap", "ground": [0.45, Color("d4bcbc")],
		"desc": "A sealed vault under a flooded city. Inside: seeds for every crop that ever grew here.",
		"done_text": "The vault doors grind open. Thousands of seed packets, still dry. Somewhere ahead, the highlands are waiting for them.",
		"goals": [
			{"text": "Upgrade the Locomotive to Lv.8", "kind": "level", "arg": "locomotive", "n": 8, "reward": {"parts": 1500}},
			{"text": "Upgrade the Workshop to Lv.8", "kind": "level", "arg": "workshop", "n": 8, "reward": {"scrap": 3000}},
			{"text": "Upgrade the Greenhouse to Lv.8", "kind": "level", "arg": "greenhouse", "n": 8, "reward": {"food": 1500}},
			{"text": "Finish 15 research projects", "kind": "research", "n": 15, "reward": {"data": 300}},
			{"text": "Train a worker to Lv.8", "kind": "crew_level", "n": 8, "reward": {"water": 1500}},
			{"text": "Reach the Seed Archive", "kind": "distance", "n": 1300, "reward": {"scrap": 6000}},
			{"text": "Shelter 50 survivors", "kind": "survivors", "n": 50, "reward": {"parts": 2500}},
			{"text": "Restore the Seed Archive", "kind": "tower", "n": 4, "reward": {}},
		],
		"stages": [
			{"name": "Pump out the tunnels", "cost": {"parts": 12400, "water": 4150}, "time": 2400.0,
				"req": {"recycler": 7}, "desc": "Drones haul pumps into the flooded access tunnels."},
			{"name": "Shore up the vault", "cost": {"parts": 19300, "scrap": 34500}, "time": 3300.0,
				"req": {"workshop": 8, "dronebay": 8}, "desc": "Steel braces go in before the old concrete gives way."},
			{"name": "Crack the seal codes", "cost": {"parts": 24850, "data": 2050}, "time": 4200.0,
				"req": {"lab": 7}, "desc": "Scientists brute-force a lock built to last a thousand years."},
			{"name": "Recover the seed bank", "cost": {"parts": 33100, "food": 8300, "water": 8300}, "time": 5100.0,
				"req": {"greenhouse": 8, "survivors": 52}, "desc": "Every drone you own carries seeds home in cool boxes."},
		],
	},
	{
		"region": "Green Highlands", "scenery": "highland", "landmark": "haven", "landmark_name": "Haven",
		"temp": 60, "distance": 1900.0, "level_cap": 10, "train": 20, "perk": {"food": 1.3},
		"perk_text": "Living soil: +30% food", "ground": [0.55, Color("dce4b0")],
		"desc": "The coolest place left on the line. Here the colony can finally step off the train and build a home.",
		"done_text": "Haven is founded. For the first time since the heat came, children sleep in houses that do not move. The line goes on, and so does Railhaven.",
		"goals": [
			{"text": "Upgrade the Living Quarters to Lv.10", "kind": "level", "arg": "quarters", "n": 10, "reward": {"food": 3000}},
			{"text": "Upgrade the Research Lab to Lv.10", "kind": "level", "arg": "lab", "n": 10, "reward": {"data": 800}},
			{"text": "Finish 21 research projects", "kind": "research", "n": 21, "reward": {"parts": 8000}},
			{"text": "Train a worker to Lv.10", "kind": "crew_level", "n": 10, "reward": {"water": 5000}},
			{"text": "Reach Haven", "kind": "distance", "n": 1900, "reward": {"scrap": 20000}},
			{"text": "Shelter 70 survivors", "kind": "survivors", "n": 70, "reward": {"parts": 10000}},
			{"text": "Upgrade any carriage to Lv.10", "kind": "any_level", "n": 10, "reward": {"data": 1500}},
			{"text": "Found Haven", "kind": "tower", "n": 5, "reward": {}},
		],
		"stages": [
			{"name": "Survey the hillside", "cost": {"parts": 18000, "scrap": 80000, "data": 2500}, "time": 3000.0,
				"req": {"dronebay": 9}, "desc": "Drones map springs, soil and shade for the first houses."},
			{"name": "Raise the first houses", "cost": {"parts": 24000, "scrap": 160000}, "time": 3600.0,
				"req": {"workshop": 9, "quarters": 9}, "desc": "Prefab walls ride the drones up the hill."},
			{"name": "Plant the seed fields", "cost": {"parts": 24000, "scrap": 120000, "food": 15000, "water": 15000}, "time": 4200.0,
				"req": {"greenhouse": 9, "recycler": 9}, "desc": "The archive seeds go into living soil at last."},
			{"name": "Build the wind farm", "cost": {"parts": 32000, "scrap": 200000, "data": 3500}, "time": 4800.0,
				"req": {"lab": 9, "cooling": 9}, "desc": "Turbines on the ridge will keep Haven cool without the train."},
			{"name": "Found Haven", "cost": {"parts": 40000, "scrap": 250000, "food": 20000, "water": 20000, "data": 4000}, "time": 5400.0,
				"req": {"medbay": 8, "survivors": 72}, "desc": "Everyone who wants to stay steps off the train for good."},
		],
	},
]

## Research projects: run one at a time in the Research Lab. effect values add up per key.
## Keys: drone (haul), food/water/parts (output), upkeep (less eaten), storage, cost (cheaper),
## offline (hours), xp (crew XP), speed (faster drone trips), all (every output), care (Med Bay).
const RESEARCH := [
	{"id": "rotors1", "name": "Lighter Rotors", "icon": "drone", "chapter": 1, "cost": {"data": 15, "parts": 60}, "time": 300.0, "effect": {"drone": 0.2}, "text": "Drones haul +20% scrap"},
	{"id": "drip1", "name": "Drip Irrigation", "icon": "food", "chapter": 1, "cost": {"data": 25, "parts": 80}, "time": 420.0, "effect": {"food": 0.15}, "text": "+15% food"},
	{"id": "filters1", "name": "Fine Filters", "icon": "water", "chapter": 1, "cost": {"data": 25, "parts": 80}, "time": 420.0, "effect": {"water": 0.15}, "text": "+15% water"},
	{"id": "lathe1", "name": "Precision Lathes", "icon": "parts", "chapter": 1, "cost": {"data": 35, "parts": 120}, "time": 600.0, "effect": {"parts": 0.15}, "text": "+15% parts"},
	{"id": "racks1", "name": "Compression Racks", "icon": "crate", "chapter": 1, "cost": {"data": 50, "parts": 150}, "time": 900.0, "effect": {"storage": 0.25}, "text": "+25% storage for everything"},
	{"id": "ration1", "name": "Lean Rations", "icon": "home", "chapter": 1, "cost": {"data": 60, "parts": 200}, "time": 1200.0, "effect": {"upkeep": 0.1}, "text": "Crew eat and drink 10% less"},
	{"id": "swarm1", "name": "Swarm Routing", "icon": "drone", "chapter": 2, "cost": {"data": 150, "parts": 700}, "time": 1800.0, "effect": {"drone": 0.25}, "text": "Drones haul +25% scrap"},
	{"id": "turn1", "name": "Quick Turnaround", "icon": "clock", "chapter": 2, "cost": {"data": 180, "parts": 800}, "time": 2100.0, "effect": {"speed": 0.15}, "text": "Drone trips 15% faster"},
	{"id": "mentor1", "name": "Mentoring", "icon": "crew", "chapter": 2, "cost": {"data": 200, "parts": 900}, "time": 2400.0, "effect": {"xp": 0.5}, "text": "Crew gain experience 50% faster"},
	{"id": "drip2", "name": "Vertical Farming", "icon": "food", "chapter": 2, "cost": {"data": 220, "parts": 1000}, "time": 2700.0, "effect": {"food": 0.2}, "text": "+20% food"},
	{"id": "filters2", "name": "Membrane Stacks", "icon": "water", "chapter": 2, "cost": {"data": 220, "parts": 1000}, "time": 2700.0, "effect": {"water": 0.2}, "text": "+20% water"},
	{"id": "lathe2", "name": "CNC Benches", "icon": "parts", "chapter": 2, "cost": {"data": 260, "parts": 1200}, "time": 3000.0, "effect": {"parts": 0.2}, "text": "+20% parts"},
	{"id": "night1", "name": "Night Shift", "icon": "clock", "chapter": 2, "cost": {"data": 280, "parts": 1200}, "time": 3000.0, "effect": {"offline": 4.0}, "text": "Work continues 4 h longer while you are away"},
	{"id": "racks2", "name": "Vacuum Packing", "icon": "crate", "chapter": 3, "cost": {"data": 600, "parts": 4000}, "time": 3600.0, "effect": {"storage": 0.35}, "text": "+35% storage for everything"},
	{"id": "salvage1", "name": "Salvage Know-how", "icon": "hammer", "chapter": 3, "cost": {"data": 700, "parts": 5000}, "time": 4200.0, "effect": {"cost": 0.1}, "text": "Building and upgrading cost 10% less"},
	{"id": "swarm2", "name": "Heavy Lifters", "icon": "drone", "chapter": 3, "cost": {"data": 800, "parts": 6000}, "time": 4800.0, "effect": {"drone": 0.3}, "text": "Drones haul +30% scrap"},
	{"id": "ration2", "name": "Closed-loop Kitchen", "icon": "home", "chapter": 3, "cost": {"data": 800, "parts": 6000}, "time": 4800.0, "effect": {"upkeep": 0.15}, "text": "Crew eat and drink 15% less"},
	{"id": "care1", "name": "Field Medicine", "icon": "medkit", "chapter": 3, "cost": {"data": 900, "parts": 7000}, "time": 5400.0, "effect": {"care": 0.5}, "text": "Med Bay bonus +50%"},
	{"id": "drip3", "name": "Living Soil", "icon": "food", "chapter": 4, "cost": {"data": 1800, "parts": 18000}, "time": 6300.0, "effect": {"food": 0.25}, "text": "+25% food"},
	{"id": "filters3", "name": "Fog Harvesters", "icon": "water", "chapter": 4, "cost": {"data": 1800, "parts": 18000}, "time": 6300.0, "effect": {"water": 0.25}, "text": "+25% water"},
	{"id": "lathe3", "name": "Fabricators", "icon": "parts", "chapter": 4, "cost": {"data": 2000, "parts": 20000}, "time": 7200.0, "effect": {"parts": 0.25}, "text": "+25% parts"},
	{"id": "salvage2", "name": "Modular Carriages", "icon": "hammer", "chapter": 4, "cost": {"data": 2400, "parts": 24000}, "time": 8100.0, "effect": {"cost": 0.1}, "text": "Building and upgrading cost 10% less"},
	{"id": "night2", "name": "Autopilot", "icon": "train", "chapter": 4, "cost": {"data": 2400, "parts": 24000}, "time": 8100.0, "effect": {"offline": 4.0}, "text": "Work continues 4 h longer while you are away"},
	{"id": "climate1", "name": "Climate Models", "icon": "sun", "chapter": 4, "cost": {"data": 3200, "parts": 30000}, "time": 9000.0, "effect": {"all": 0.1}, "text": "+10% to every output"},
]

## Supply contracts: three short side tasks at a time. Amounts and rewards scale with the
## chapter unless "fixed"; a claimed slot offers a new contract after CONTRACT_COOLDOWN of play.
const CONTRACT_SCALE := [1.0, 4.0, 12.0, 30.0, 70.0]
const CONTRACT_COOLDOWN := 1800.0
const CONTRACTS := [
	{"id": "salvage", "text": "Salvage %s scrap", "icon": "scrap", "stat": "salvaged", "n": 800, "reward": {"parts": 80}},
	{"id": "parts", "text": "Make %s parts", "icon": "parts", "stat": "parts_made", "n": 200, "reward": {"scrap": 500}},
	{"id": "food", "text": "Grow %s food", "icon": "food", "stat": "food_made", "n": 250, "reward": {"water": 150}},
	{"id": "water", "text": "Recycle %s water", "icon": "water", "stat": "water_made", "n": 250, "reward": {"food": 150}},
	{"id": "upgrades", "text": "Upgrade carriages %s times", "icon": "hammer", "stat": "upgrades", "n": 3, "fixed": true, "reward": {"parts": 120}},
	{"id": "events", "text": "Handle %s events", "icon": "warning", "stat": "events", "n": 2, "fixed": true, "reward": {"scrap": 600}},
	{"id": "boosts", "text": "Use Overdrive %s times", "icon": "up", "stat": "boosts", "n": 3, "fixed": true, "reward": {"parts": 100}},
	{"id": "research", "text": "Finish %s research project", "icon": "flask", "stat": "research", "n": 1, "fixed": true, "chapter": 1, "reward": {"data": 30}},
]

## Achievements: one-time milestones, rewarded automatically (see Game.stat_value()).
const ACHIEVEMENTS := [
	{"id": "salv1", "name": "Scavenger", "text": "Salvage 10K scrap", "stat": "salvaged", "n": 10000, "reward": {"parts": 150}},
	{"id": "salv2", "name": "Salvage Baron", "text": "Salvage 1M scrap", "stat": "salvaged", "n": 1000000, "reward": {"parts": 4000}},
	{"id": "salv3", "name": "Ruin Eater", "text": "Salvage 25M scrap", "stat": "salvaged", "n": 25000000, "reward": {"parts": 30000}},
	{"id": "parts1", "name": "Machinist", "text": "Make 10K parts", "stat": "parts_made", "n": 10000, "reward": {"scrap": 6000}},
	{"id": "parts2", "name": "Assembly Line", "text": "Make 1M parts", "stat": "parts_made", "n": 1000000, "reward": {"scrap": 200000}},
	{"id": "crew1", "name": "Full House", "text": "25 survivors aboard", "stat": "survivors", "n": 25, "reward": {"food": 500}},
	{"id": "crew2", "name": "Town on Rails", "text": "50 survivors aboard", "stat": "survivors", "n": 50, "reward": {"food": 3000}},
	{"id": "crew3", "name": "The Ark", "text": "80 survivors aboard", "stat": "survivors", "n": 80, "reward": {"food": 15000}},
	{"id": "vet1", "name": "Veteran", "text": "A worker reaches Lv.5", "stat": "crew_level", "n": 5, "reward": {"data": 60}},
	{"id": "vet2", "name": "Old Hand", "text": "A worker reaches Lv.10", "stat": "crew_level", "n": 10, "reward": {"data": 1000}},
	{"id": "max1", "name": "Top of the Line", "text": "A carriage reaches Lv.10", "stat": "max_level", "n": 10, "reward": {"parts": 20000}},
	{"id": "len1", "name": "Long Haul", "text": "15 carriages behind the locomotive", "stat": "carriages", "n": 15, "reward": {"scrap": 20000}},
	{"id": "len2", "name": "Rolling City", "text": "20 carriages behind the locomotive", "stat": "carriages", "n": 20, "reward": {"scrap": 150000}},
	{"id": "sci1", "name": "Eureka", "text": "Finish 5 research projects", "stat": "research", "n": 5, "reward": {"data": 150}},
	{"id": "sci2", "name": "Think Tank", "text": "Finish every research project", "stat": "research", "n": 24, "reward": {"data": 3000}},
	{"id": "land1", "name": "First Light", "text": "Restore a landmark", "stat": "landmarks", "n": 1, "reward": {"parts": 100}},
	{"id": "land3", "name": "Pathfinder", "text": "Restore 3 landmarks", "stat": "landmarks", "n": 3, "reward": {"parts": 3000}},
	{"id": "land5", "name": "Railhaven", "text": "Found Haven", "stat": "landmarks", "n": 5, "reward": {"data": 2000}},
	{"id": "ev1", "name": "Weathered", "text": "Handle 25 events", "stat": "events", "n": 25, "reward": {"water": 2000}},
	{"id": "boost1", "name": "Overclocked", "text": "Use Overdrive 25 times", "stat": "boosts", "n": 25, "reward": {"parts": 1500}},
	{"id": "con1", "name": "Reliable", "text": "Complete 10 contracts", "stat": "contracts", "n": 10, "reward": {"scrap": 5000}},
	{"id": "con2", "name": "Quartermaster", "text": "Complete 50 contracts", "stat": "contracts", "n": 50, "reward": {"scrap": 100000}},
]

## Overdrive: tap to run a carriage at double speed for a minute, then it cools down.
const BOOSTABLE := ["greenhouse", "recycler", "workshop", "dronebay", "lab"]
const BOOST_TIME := 60.0
const BOOST_COOLDOWN := 600.0
const BOOST_MULT := 2.0

## Event costs and rewards scale with the chapter so they stay meaningful (see Game.event_scale()).
const EVENT_SCALE := [1.0, 3.0, 8.0, 20.0, 45.0]
const EVENTS := {
	"heatwave": {
		"chapter": 0, "icon": "sun",
		"title": "HEATWAVE AHEAD", "sub": "Extreme temperatures incoming",
		"text": "A heatwave will push outside temperatures past 75°C. Choose how to prepare.",
		"duration": 120.0,
		"a": {"label": "BOOST COOLING", "title": "Boost cooling", "desc": "Run the exchangers hard to keep full operations.", "cost": {"water": 25}, "effect": "Full production", "icon": "cooling"},
		"b": {"label": "SAFE MODE", "title": "Safe mode", "desc": "Reduce load and prioritise crew safety.", "cost": {}, "effect": "Production -30%", "icon": "shield"},
	},
	"sandstorm": {
		"chapter": 0, "icon": "warning",
		"title": "SANDSTORM", "sub": "Visibility near zero",
		"text": "A wall of hot sand is rolling over the tracks. The drones are in the air.",
		"duration": 90.0,
		"a": {"label": "FLY THROUGH", "title": "Reinforce drones", "desc": "Patch rotors and keep salvaging.", "cost": {"parts": 15}, "effect": "Salvage continues", "icon": "drone"},
		"b": {"label": "GROUND DRONES", "title": "Ground drones", "desc": "Recall the fleet until the storm passes.", "cost": {}, "effect": "Salvage paused", "icon": "shield"},
	},
	"signal": {
		"chapter": 0, "icon": "crew",
		"title": "DISTRESS SIGNAL", "sub": "Survivors near the tracks",
		"text": "A flare rises from a buried outpost. Someone is still out there.",
		"duration": 0.0,
		"a": {"label": "RESCUE", "title": "Send a rescue drone", "desc": "Bring them aboard. Needs free beds.", "cost": {"parts": 20, "food": 20}, "effect": "+2 survivors", "icon": "crew"},
		"b": {"label": "TRADE", "title": "Trade supplies", "desc": "Lower a crate of food for their salvage.", "cost": {"food": 30}, "effect": "+%d scrap", "icon": "scrap", "gain": {"scrap": 60}},
	},
	"trader": {
		"chapter": 1, "icon": "trade",
		"title": "TRADER CARAVAN", "sub": "A crawler pulls up alongside",
		"text": "Nomad traders match your speed and lower a ramp. They want scrap and food; they have parts and data drives.",
		"duration": 0.0,
		"a": {"label": "BUY PARTS", "title": "Buy parts", "desc": "Swap a pile of scrap for machined parts.", "cost": {"scrap": 120}, "effect": "+%d parts", "icon": "parts", "gain": {"parts": 50}},
		"b": {"label": "BUY DATA", "title": "Buy data drives", "desc": "Old-world drives, full of research notes.", "cost": {"food": 60}, "effect": "+%d data", "icon": "data", "gain": {"data": 25}},
	},
	"rail": {
		"chapter": 1, "icon": "rail",
		"title": "BROKEN RAIL", "sub": "The line ahead is buckled",
		"text": "Heat has twisted the rails ahead. The train has to stop unless someone fixes them fast.",
		"duration": 150.0,
		"a": {"label": "QUICK FIX", "title": "Weld it now", "desc": "Burn parts to patch the rail and keep moving.", "cost": {"parts": 30}, "effect": "Keep moving", "icon": "wrench"},
		"b": {"label": "WAIT", "title": "Wait for cooler air", "desc": "Stop and let the rail cool down before repairs.", "cost": {}, "effect": "Train stops for a while", "icon": "clock"},
	},
	"ashstorm": {
		"chapter": 1, "icon": "ash",
		"title": "ASH STORM", "sub": "Grey snow falls on the train",
		"text": "Volcanic ash is blotting out the light. The grow lamps will struggle unless the vents are sealed.",
		"duration": 120.0,
		"a": {"label": "SEAL VENTS", "title": "Seal the greenhouse", "desc": "Spend parts on filters and keep the crops growing.", "cost": {"parts": 25}, "effect": "Full food output", "icon": "food"},
		"b": {"label": "RIDE IT OUT", "title": "Ride it out", "desc": "Let the plants starve of light for a while.", "cost": {}, "effect": "Food -50%", "icon": "shield"},
	},
	"raiders": {
		"chapter": 2, "icon": "raider",
		"title": "RAIDERS", "sub": "Armed buggies on the flank",
		"text": "Raiders are racing alongside, hooks ready. They will grab whatever they can reach.",
		"duration": 0.0,
		"a": {"label": "FORTIFY", "title": "Seal the hatches", "desc": "Bolt plates over every door before they board.", "cost": {"parts": 40}, "effect": "Nothing lost", "icon": "shield"},
		"b": {"label": "PAY TOLL", "title": "Pay them off", "desc": "Throw them crates and hope they leave.", "cost": {}, "effect": "Lose 15% scrap and food", "icon": "scrap"},
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
	return scaled_cost(CARRIAGES[type]["upgrade"], pow(1.85, level - 1))


## Worker slots for a carriage type at a level.
static func slots(type: String, level: int) -> int:
	var i := clampi(level, 1, MAX_LEVEL) - 1
	match type:
		"greenhouse", "recycler", "workshop":
			return [2, 2, 3, 3, 4, 4, 5, 5, 6, 6][i]
		"lab":
			return [1, 2, 2, 3, 3, 3, 4, 4, 5, 5][i]
		"dronebay", "medbay":
			return [1, 1, 2, 2, 2, 3, 3, 3, 4, 4][i]
		"cooling":
			return 1
	return 0


## Output per worker-power per second (food, water, parts or data).
static func worker_rate(type: String, level: int) -> float:
	var mult := 1.0 + 0.4 * (level - 1)
	match type:
		"greenhouse": return 0.1 * mult
		"recycler": return 0.1 * mult
		"workshop": return 0.05 * mult
		"lab": return 0.01 * mult
	return 0.0


static func beds(level: int) -> int:
	return [6, 9, 12, 15, 18, 22, 26, 31, 36, 42][clampi(level, 1, MAX_LEVEL) - 1]


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
		"lab": return {"data": 80.0 * level}
		"cargo":
			var m := pow(2.0, level - 1) # outgrows upgrade costs (x1.85 per level) so holds never dead-end
			return {"scrap": 500.0 * m, "parts": 250.0 * m, "food": 250.0 * m, "water": 250.0 * m, "data": 60.0 * m}
	return {}


## Train-wide efficiency bonus per Med Bay worker-power.
static func care_rate(level: int) -> float:
	return 0.03 * (1.0 + 0.3 * (level - 1))


static func loco_mult(level: int) -> float:
	return 1.0 + 0.5 * (level - 1)


## Experience needed to reach a crew level.
static func xp_for(level: int) -> float:
	return XP_BASE * pow(level - 1, 2)


static func crew_level(xp: float) -> int:
	return clampi(1 + int(sqrt(xp / XP_BASE)), 1, MAX_CREW_LEVEL)


static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		parts.append("%d %s" % [cost[k], RES_NAMES.get(k, k)])
	return ", ".join(parts)

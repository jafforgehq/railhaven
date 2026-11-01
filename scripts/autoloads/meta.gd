extends Node
## Retention systems around the puzzle: win streak and pre-level boosters, the 7-day login
## calendar, the postcard album, the Heat Run event, the weekly race and Juno's story lines.
## All state lives in Game.meta (a plain Dictionary), so it saves with the rest of the game.

signal changed

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

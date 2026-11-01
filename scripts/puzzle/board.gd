class_name SortBoard
extends RefCounted
## Pure coolant-sort rules (no drawing): tanks hold up to CAPACITY canisters, bottom to top.
## A pour moves the whole run of matching canisters on top of a tank onto an empty tank or onto
## the same colour, as far as there is room. Ash-covered canisters stay hidden until exposed.
## Blockers: a frozen tank thaws once enough other tanks are sealed; a tagged tank only takes
## one colour; a hot canister flares (heat spike) unless its tank is sealed within its countdown.

var cap := Data.CAPACITY
var tanks: Array = [] # Array of Array[int] (colour index), bottom -> top
var hidden: Array = [] # parallel Array of Array[bool]
var hot: Array = [] # parallel Array of Array[int]: pours left before the canister flares (0 = calm)
var frozen: Array = [] # per tank: sealed tanks needed to thaw it (0 = not frozen)
var lock: Array = [] # per tank: the only colour it accepts (-1 = any)
var history: Array = [] # [from, to, n, revealed: Array of [tank, index], hot snapshot]


func load_level(level: Dictionary) -> void:
	tanks = []
	hidden = []
	history = []
	for t in level["tanks"]:
		tanks.append(t.map(func(x): return int(x)))
	var hid: Array = level.get("hidden", [])
	for i in tanks.size():
		var row: Array = hid[i] if i < hid.size() else []
		hidden.append(tanks[i].map(func(_x): return false))
		for k in mini(row.size(), tanks[i].size()):
			hidden[i][k] = bool(row[k])
		if not tanks[i].is_empty():
			hidden[i][-1] = false # the top canister is always visible
	var fz: Array = level.get("frozen", [])
	var lk: Array = level.get("lock", [])
	frozen = []
	lock = []
	hot = []
	for i in tanks.size():
		frozen.append(int(fz[i]) if i < fz.size() else 0)
		lock.append(int(lk[i]) if i < lk.size() else -1)
		hot.append(tanks[i].map(func(_x): return 0))
	for h in level.get("hot", []): # [tank, index, pours]
		if int(h[0]) < tanks.size() and int(h[1]) < tanks[int(h[0])].size():
			hot[int(h[0])][int(h[1])] = int(h[2])
			hidden[int(h[0])][int(h[1])] = false


func sealed_count() -> int:
	var n := 0
	for i in tanks.size():
		if is_complete(i):
			n += 1
	return n


## Seals still needed before tank i thaws (0 = free).
func thaw_left(i: int) -> int:
	return maxi(0, frozen[i] - sealed_count()) if i < frozen.size() else 0


func is_frozen(i: int) -> bool:
	return thaw_left(i) > 0


func colors_used() -> int:
	var seen := {}
	for t in tanks:
		for c in t:
			seen[c] = true
	return seen.size()


## Number of canisters of the top colour that sit together (stops at a hidden one).
func top_run(i: int) -> int:
	var t: Array = tanks[i]
	if t.is_empty():
		return 0
	var c: int = t[-1]
	var n := 0
	for k in range(t.size() - 1, -1, -1):
		if t[k] != c or hidden[i][k]:
			break
		n += 1
	return n


func is_complete(i: int) -> bool:
	var t: Array = tanks[i]
	if t.size() != cap:
		return false
	for k in cap:
		if t[k] != t[0]:
			return false
	return true


## How many canisters a pour from i to j would move (0 = not allowed).
func can_pour(i: int, j: int) -> int:
	if i == j or i < 0 or j < 0 or i >= tanks.size() or j >= tanks.size():
		return 0
	var a: Array = tanks[i]
	var b: Array = tanks[j]
	if a.is_empty() or b.size() >= cap or is_complete(i) or is_frozen(i) or is_frozen(j):
		return 0
	if not b.is_empty() and b[-1] != a[-1]:
		return 0
	if lock[j] >= 0 and a[-1] != lock[j]:
		return 0
	return mini(top_run(i), cap - b.size())


## Performs a pour. Returns {} if not allowed, else {n, completed (target is now full),
## revealed: Array of [tank, index], thawed: tanks that thawed, flared / defused: hot canisters}.
func pour(i: int, j: int) -> Dictionary:
	var n := can_pour(i, j)
	if n == 0:
		return {}
	var hot_before := hot.duplicate(true)
	var was_frozen := range(tanks.size()).filter(func(k): return is_frozen(k))
	for k in n:
		tanks[j].append(tanks[i].pop_back())
		hidden[j].append(false)
		hidden[i].pop_back()
		hot[j].append(hot[i].pop_back())
	var defused := 0
	var flared := 0
	for t in tanks.size():
		for k in hot[t].size():
			if hot[t][k] <= 0:
				continue
			if is_complete(t):
				hot[t][k] = 0 # sealed in time
				defused += 1
			else:
				hot[t][k] -= 1
				if hot[t][k] == 0:
					flared += 1
	var revealed := []
	if not tanks[i].is_empty() and hidden[i][-1]:
		hidden[i][-1] = false
		revealed.append([i, tanks[i].size() - 1])
	if is_complete(j):
		for k in cap: # a finished tank shows everything, ash included
			if hidden[j][k]:
				hidden[j][k] = false
				revealed.append([j, k])
	history.append([i, j, n, revealed, hot_before])
	var thawed := was_frozen.filter(func(k): return not is_frozen(k))
	return {"n": n, "completed": is_complete(j), "revealed": revealed, "thawed": thawed, "flared": flared, "defused": defused}


func can_undo() -> bool:
	return not history.is_empty()


func undo() -> bool:
	if history.is_empty():
		return false
	var h: Array = history.pop_back()
	for r in h[3]:
		hidden[r[0]][r[1]] = true
	for k in h[2]:
		tanks[h[0]].append(tanks[h[1]].pop_back())
		hidden[h[0]].append(false)
		hidden[h[1]].pop_back()
	hot = h[4]
	while hot.size() < tanks.size(): # spare tanks added after that pour (empty again by now)
		hot.append([])
	return true


func add_tank() -> void:
	tanks.append([])
	hidden.append([])
	hot.append([])
	frozen.append(0)
	lock.append(-1)


## Hot canisters still ticking (for the screen's warning).
func hot_left() -> Array:
	var out := []
	for t in tanks.size():
		for k in hot[t].size():
			if hot[t][k] > 0:
				out.append(hot[t][k])
	return out


func is_won() -> bool:
	for i in tanks.size():
		if not tanks[i].is_empty() and not is_complete(i):
			return false
	return true


## True when no pour is possible at all (the player needs undo, a spare tank or a restart).
func is_stuck() -> bool:
	for i in tanks.size():
		for j in tanks.size():
			if can_pour(i, j) > 0:
				return false
	return not is_won()

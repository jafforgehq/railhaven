class_name SortBoard
extends RefCounted
## Pure coolant-sort rules (no drawing): tanks hold up to CAPACITY canisters, bottom to top.
## A pour moves the whole run of matching canisters on top of a tank onto an empty tank or onto
## the same colour, as far as there is room. Ash-covered canisters stay hidden until exposed.

var cap := Data.CAPACITY
var tanks: Array = [] # Array of Array[int] (colour index), bottom -> top
var hidden: Array = [] # parallel Array of Array[bool]
var history: Array = [] # [from, to, n, revealed: Array of [tank, index]]


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
	if a.is_empty() or b.size() >= cap or is_complete(i):
		return 0
	if not b.is_empty() and b[-1] != a[-1]:
		return 0
	return mini(top_run(i), cap - b.size())


## Performs a pour. Returns {} if not allowed, else {n, completed (target is now full),
## revealed: Array of [tank, index]}.
func pour(i: int, j: int) -> Dictionary:
	var n := can_pour(i, j)
	if n == 0:
		return {}
	for k in n:
		tanks[j].append(tanks[i].pop_back())
		hidden[j].append(false)
		hidden[i].pop_back()
	var revealed := []
	if not tanks[i].is_empty() and hidden[i][-1]:
		hidden[i][-1] = false
		revealed.append([i, tanks[i].size() - 1])
	if is_complete(j):
		for k in cap: # a finished tank shows everything, ash included
			if hidden[j][k]:
				hidden[j][k] = false
				revealed.append([j, k])
	history.append([i, j, n, revealed])
	return {"n": n, "completed": is_complete(j), "revealed": revealed}


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
	return true


func add_tank() -> void:
	tanks.append([])
	hidden.append([])


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

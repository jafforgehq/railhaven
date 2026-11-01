class_name SortBoard
extends RefCounted
## Pure coolant-sort rules (no drawing): tanks hold up to CAPACITY canisters, bottom to top.
## A pour moves the whole run of matching canisters on top of a tank onto an empty tank or onto
## the same colour, as far as there is room. Ash-covered canisters stay hidden until exposed.
## Blockers (tools/gen_levels.py mirrors every rule here in its solver):
##   frozen  tank thaws once enough tanks are sealed       lock     tank only takes one colour
##   keylock tank opens once a given colour is sealed      hot      canister flares unless sealed in time
##   rust    canister is welded in place until it or a neighbouring tank is sealed; spreads when idle
##   twin    pours into a twin are shared with its partner, one canister each in turn
##   conveyor  rows slide one place every N pours (layout only, rules unchanged)
## Goals: "colors" wins once the listed colours are sealed (rescue the marked drone parts);
## "order" requires the listed colours to be the first tanks sealed, in that order.

const RUST_SPREAD := 3 # pours without a seal before rust creeps one canister further
const RUST_EXTRA := 4 # rust can spread at most this many times per level

var cap := Data.CAPACITY
var tanks: Array = [] # Array of Array[int] (colour index), bottom -> top
var hidden: Array = [] # parallel Array of Array[bool]
var hot: Array = [] # parallel Array of Array[int]: pours left before the canister flares (0 = calm)
var rust: Array = [] # parallel Array of Array[bool]
var frozen: Array = [] # per tank: sealed tanks needed to thaw it (0 = not frozen)
var lock: Array = [] # per tank: the only colour it accepts (-1 = any)
var keylock: Array = [] # per tank: colour whose sealing opens it (-1 = open)
var twin: Array = [] # per tank: partner tank index (-1 = none)
var conveyor := 0 # rows shift every this many pours (0 = still)
var goal := {} # {} = seal everything; {type: "colors"|"order", colors: [..]}
var part: Array = [] # parallel Array of Array[bool]: drone-part marks for a "colors" goal (cosmetic)
var history: Array = [] # [from, to, n, revealed, snapshot, dests]
var rust_spreads := true # off only in the solver replay test (the solver does not model spreading)
var pours := 0 # pours made (drives the conveyor; undo takes one back)
var _rust_quiet := 0
var _rust_spread := 0
var _rng := RandomNumberGenerator.new()


func load_level(level: Dictionary) -> void:
	tanks = []
	hidden = []
	history = []
	for t in level["tanks"]:
		tanks.append(t.map(func(x): return int(x)))
	var hid: Array = level.get("hidden", [])
	var rs: Array = level.get("rust", [])
	rust = []
	for i in tanks.size():
		var row: Array = hid[i] if i < hid.size() else []
		hidden.append(tanks[i].map(func(_x): return false))
		rust.append(tanks[i].map(func(_x): return false))
		for k in mini(row.size(), tanks[i].size()):
			hidden[i][k] = bool(row[k])
		if i < rs.size():
			for k in mini(rs[i].size(), tanks[i].size()):
				rust[i][k] = bool(rs[i][k])
		if not tanks[i].is_empty():
			hidden[i][-1] = false # the top canister is always visible
	frozen = _per_tank(level.get("frozen", []), 0)
	lock = _per_tank(level.get("lock", []), -1)
	keylock = _per_tank(level.get("keylock", []), -1)
	twin = _per_tank(level.get("twin", []), -1)
	hot = []
	for i in tanks.size():
		hot.append(tanks[i].map(func(_x): return 0))
	for h in level.get("hot", []): # [tank, index, pours]
		if int(h[0]) < tanks.size() and int(h[1]) < tanks[int(h[0])].size():
			hot[int(h[0])][int(h[1])] = int(h[2])
			hidden[int(h[0])][int(h[1])] = false
	conveyor = int(level.get("conveyor", 0))
	goal = level.get("goal", {})
	part = []
	for i in tanks.size():
		part.append(tanks[i].map(func(_x): return false))
	for p in level.get("parts", []):
		if int(p[0]) < tanks.size() and int(p[1]) < tanks[int(p[0])].size():
			part[int(p[0])][int(p[1])] = true
	_rust_quiet = 0
	_rust_spread = 0
	pours = 0
	_rng.seed = hash(str(level["tanks"]))


func _per_tank(src: Array, fill: int) -> Array:
	var out := []
	for i in tanks.size():
		out.append(int(src[i]) if i < src.size() else fill)
	return out


# ---------------------------------------------------------------- queries

func colors_used() -> int:
	var seen := {}
	for t in tanks:
		for c in t:
			seen[c] = true
	return seen.size()


func is_complete(i: int) -> bool:
	var t: Array = tanks[i]
	if t.size() != cap:
		return false
	for k in cap:
		if t[k] != t[0]:
			return false
	return true


func sealed_count() -> int:
	var n := 0
	for i in tanks.size():
		if is_complete(i):
			n += 1
	return n


func color_sealed(c: int) -> bool:
	for i in tanks.size():
		if is_complete(i) and tanks[i][0] == c:
			return true
	return false


## Seals still needed before tank i thaws (0 = free).
func thaw_left(i: int) -> int:
	return maxi(0, frozen[i] - sealed_count()) if i >= 0 and i < frozen.size() else 0


func is_frozen(i: int) -> bool:
	return thaw_left(i) > 0


func is_keylocked(i: int) -> bool:
	return i >= 0 and i < keylock.size() and keylock[i] >= 0 and not color_sealed(keylock[i])


## Tank i takes no part in pours right now (frozen or padlocked).
func is_shut(i: int) -> bool:
	return is_frozen(i) or is_keylocked(i)


## Number of canisters of the top colour that sit together (stops at a hidden or rusted one).
func top_run(i: int) -> int:
	var t: Array = tanks[i]
	if t.is_empty():
		return 0
	var c: int = t[-1]
	var n := 0
	for k in range(t.size() - 1, -1, -1):
		if t[k] != c or hidden[i][k] or rust[i][k]:
			break
		n += 1
	return n


## Tanks beside i in its row (layout: one row up to 6 tanks, else two rows).
func neighbours(i: int) -> Array:
	var n := tanks.size()
	var per_row := n if n <= 6 else ceili(n / 2.0)
	var out := []
	for j in [i - 1, i + 1]:
		if j >= 0 and j < n and j / per_row == i / per_row:
			out.append(j)
	return out


## Pours made so far shift each conveyor row by this many places.
func shift() -> int:
	return pours / conveyor if conveyor > 0 else 0


## The colour the order goal needs sealed next (-1 when there is no order constraint left).
func next_in_order() -> int:
	if goal.get("type", "") != "order":
		return -1
	for c in goal["colors"]:
		if not color_sealed(int(c)):
			return int(c)
	return -1


func _accepts(j: int, c: int, size: int) -> bool:
	return size < cap and not is_shut(j) and (lock[j] < 0 or lock[j] == c)


## Where each canister of a pour from i to j would land (twins share them in turn).
func _plan(i: int, j: int) -> Array:
	var a: Array = tanks[i]
	if a.is_empty() or is_complete(i) or is_shut(i):
		return []
	var c: int = a[-1]
	var run := top_run(i)
	if run == 0:
		return []
	var sizes := {j: tanks[j].size()}
	if not tanks[j].is_empty() and tanks[j][-1] != c:
		return []
	if not _accepts(j, c, sizes[j]):
		return []
	var p: int = twin[j]
	var partner_ok: bool = p >= 0 and p != i and not is_shut(p) and (lock[p] < 0 or lock[p] == c) \
		and (tanks[p].is_empty() or tanks[p][-1] == c)
	if partner_ok:
		sizes[p] = tanks[p].size()
	var dests := []
	var turn := j
	for k in run:
		var other: int = (p if turn == j else j) if partner_ok else j
		if sizes[turn] < cap:
			dests.append(turn)
			sizes[turn] += 1
		elif sizes[other] < cap:
			dests.append(other)
			sizes[other] += 1
		else:
			break
		if partner_ok:
			turn = other
	return dests


## How many canisters a pour from i to j would move (0 = not allowed).
func can_pour(i: int, j: int) -> int:
	if i == j or i < 0 or j < 0 or i >= tanks.size() or j >= tanks.size():
		return 0
	var dests := _plan(i, j)
	if dests.is_empty():
		return 0
	# Order goal: the next tank to seal must be the next colour on the list.
	var want := next_in_order()
	if want >= 0:
		var c: int = tanks[i][-1]
		var counts := {}
		for d in dests:
			counts[d] = counts.get(d, 0) + 1
		for d in counts:
			if tanks[d].size() + counts[d] == cap and c != want and _would_complete(d, c, counts[d]):
				return 0
	return dests.size()


func _would_complete(d: int, c: int, n: int) -> bool:
	for x in tanks[d]:
		if x != c:
			return false
	return tanks[d].size() + n == cap


## What a blocked pour from i to j is waiting for (for the hint banner), "" if nothing special.
func block_reason(i: int, j: int) -> String:
	var t := j if is_shut(j) else (i if i >= 0 and is_shut(i) else -1)
	if t >= 0 and is_frozen(t):
		var left := thaw_left(t)
		return "Frozen: seal %d more tank%s to thaw it" % [left, "" if left == 1 else "s"]
	if t >= 0:
		return "Locked: seal the %s tank to open it" % Data.COLORS[keylock[t]]
	if i < 0:
		return ""
	if not tanks[i].is_empty() and top_run(i) == 0 and rust[i][-1]:
		return "Rusted: seal this tank or one beside it to free it"
	if not tanks[i].is_empty() and lock[j] >= 0 and lock[j] != tanks[i][-1]:
		return "Tagged tank: it only takes %s" % Data.COLORS[lock[j]]
	var want := next_in_order()
	if want >= 0 and not tanks[i].is_empty() and not _plan(i, j).is_empty():
		return "Seal %s next" % Data.COLORS[want]
	return ""


# ---------------------------------------------------------------- moves

func _snapshot() -> Array:
	return [hot.duplicate(true), rust.duplicate(true), _rust_quiet, _rust_spread, part.duplicate(true)]


## Performs a pour. Returns {} if not allowed, else {n, completed (any tank sealed), sealed: tanks
## sealed by it, dests: tank per moved canister, revealed, thawed, opened, flared, defused, rusted}.
func pour(i: int, j: int) -> Dictionary:
	var n := can_pour(i, j)
	if n == 0:
		return {}
	var dests := _plan(i, j).slice(0, n)
	var snap := _snapshot()
	var was_shut := range(tanks.size()).filter(func(k): return is_shut(k))
	var sealed_before := range(tanks.size()).filter(func(k): return is_complete(k))
	for d in dests:
		tanks[d].append(tanks[i].pop_back())
		hidden[d].append(false)
		hidden[i].pop_back()
		hot[d].append(hot[i].pop_back())
		rust[d].append(rust[i].pop_back())
		part[d].append(part[i].pop_back())
	var sealed := range(tanks.size()).filter(func(k): return is_complete(k) and not k in sealed_before)
	# Hot canisters: sealed ones are defused, the rest tick down.
	var defused := 0
	var flared := 0
	for t in tanks.size():
		for k in hot[t].size():
			if hot[t][k] <= 0:
				continue
			if is_complete(t):
				hot[t][k] = 0
				defused += 1
			else:
				hot[t][k] -= 1
				if hot[t][k] == 0:
					flared += 1
	# Rust: a seal scrubs its own tank and the tanks beside it; idle pours let it creep.
	var rusted := []
	for t in sealed:
		for u in [t] + neighbours(t):
			for k in rust[u].size():
				rust[u][k] = false
	if sealed.is_empty():
		_rust_quiet += 1
		if rust_spreads and _rust_quiet >= RUST_SPREAD and _rust_spread < RUST_EXTRA and _has_rust():
			var spot := _rust_target()
			if not spot.is_empty():
				rust[spot[0]][spot[1]] = true
				rusted.append(spot)
				_rust_spread += 1
			_rust_quiet = 0
	else:
		_rust_quiet = 0
	var revealed := []
	if not tanks[i].is_empty() and hidden[i][-1]:
		hidden[i][-1] = false
		revealed.append([i, tanks[i].size() - 1])
	for t in sealed:
		for k in cap: # a finished tank shows everything, ash included
			if hidden[t][k]:
				hidden[t][k] = false
				revealed.append([t, k])
	history.append([i, j, n, revealed, snap, dests])
	pours += 1
	var opened := was_shut.filter(func(k): return not is_shut(k))
	return {"n": n, "completed": not sealed.is_empty(), "sealed": sealed, "dests": dests, "revealed": revealed,
		"thawed": opened, "flared": flared, "defused": defused, "rusted": rusted}


func _has_rust() -> bool:
	for r in rust:
		if r.has(true):
			return true
	return false


## Next canister rust creeps onto: the lowest clean canister in a tank beside a rusty one.
func _rust_target() -> Array:
	var cands := []
	for t in tanks.size():
		if not rust[t].has(true):
			continue
		for u in [t] + neighbours(t):
			if is_complete(u):
				continue
			for k in tanks[u].size() - 1: # never the top canister
				if not rust[u][k]:
					cands.append([u, k])
					break
	return [] if cands.is_empty() else cands[_rng.randi_range(0, cands.size() - 1)]


func can_undo() -> bool:
	return not history.is_empty()


func undo() -> bool:
	if history.is_empty():
		return false
	var h: Array = history.pop_back()
	pours -= 1
	for r in h[3]:
		hidden[r[0]][r[1]] = true
	var dests: Array = h[5]
	for k in range(dests.size() - 1, -1, -1):
		var d: int = dests[k]
		tanks[h[0]].append(tanks[d].pop_back())
		hidden[h[0]].append(false)
		hidden[d].pop_back()
	var snap: Array = h[4]
	hot = snap[0]
	rust = snap[1]
	_rust_quiet = snap[2]
	_rust_spread = snap[3]
	part = snap[4]
	while hot.size() < tanks.size(): # spare tanks added after that pour (empty again by now)
		hot.append([])
		rust.append([])
		part.append([])
	return true


func add_tank() -> void:
	tanks.append([])
	hidden.append([])
	hot.append([])
	rust.append([])
	part.append([])
	frozen.append(0)
	lock.append(-1)
	keylock.append(-1)
	twin.append(-1)


func is_won() -> bool:
	if goal.get("type", "") == "colors":
		for c in goal["colors"]:
			if not color_sealed(int(c)):
				return false
		return true
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


## Hot canisters still ticking (for the screen's warning).
func hot_left() -> Array:
	var out := []
	for t in tanks.size():
		for k in hot[t].size():
			if hot[t][k] > 0:
				out.append(hot[t][k])
	return out


# ---------------------------------------------------------------- combo charges

## Magnet: every other tank whose free top run matches tank j's top colour pours into j.
## Returns the merged pour results (normal, undoable pours).
func magnet(j: int) -> Array:
	if tanks[j].is_empty() or is_complete(j) or is_shut(j):
		return []
	var c: int = tanks[j][-1]
	var out := []
	for i in tanks.size():
		if i == j or tanks[i].is_empty() or tanks[i][-1] != c:
			continue
		if can_pour(i, j) > 0:
			out.append(pour(i, j))
		if tanks[j].size() >= cap:
			break
	return out


## Frost charge: thaws and unlocks every tank, scrubs all rust, and buys hot canisters 5 pours.
## Clears undo history (snapshots before it would bring the rust and ice back).
func frost_charge() -> void:
	for i in tanks.size():
		frozen[i] = 0
		keylock[i] = -1
		for k in rust[i].size():
			rust[i][k] = false
		for k in hot[i].size():
			if hot[i][k] > 0:
				hot[i][k] += 5
	history.clear()

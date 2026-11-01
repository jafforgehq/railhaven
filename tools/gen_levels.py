"""Generate Railhaven's coolant-sort levels and prove every one is solvable.

    python3 tools/gen_levels.py            # writes data/levels.json

A level is a list of tanks (bottom -> top colour indices, capacity 4) plus optional blockers:
  hidden   per-canister ash flags (revealed when exposed)
  frozen   per tank: sealed tanks needed before it thaws (0 = free)
  lock     per tank: the only colour it accepts (-1 = any)
  keylock  per tank: colour whose sealing opens it (-1 = open)
  rust     per-canister flags: welded until its tank or a neighbouring tank is sealed
  twin     per tank: partner index; pours into a twin are shared one canister each in turn
  conveyor rows slide one place every N pours (layout only)
  hot      [tank, index, pours]: a canister that flares (heat spike) unless sealed in time
  goal     {"type": "colors", colors} (rescue the marked drone parts) or {"type": "order", colors}
The solver obeys the same rules as scripts/puzzle/board.gd (all but ash, hot, conveyor and rust
spreading, which never change which moves are legal at the start). The solution length sets the
move budget. Each level has its own seeded RNG, so levels are generated in parallel and never
change between builds. "bosses" holds one landmark boss level per region.
"""
import heapq
import json
import math
import os
import random
from multiprocessing import Pool

CAP = 4
RUST = 16  # flag bit on a canister value inside the solver
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "levels.json")
N_LEVELS = 1000
SEED = 20261101

# First level each blocker appears. That level teaches it alone; the next PRACTICE levels keep it.
INTRO = {"frozen": 16, "ash": 31, "lock": 46, "hot": 66, "key": 81, "rescue": 96, "rust": 111,
         "conveyor": 126, "twin": 141, "order": 161}
PRACTICE = 4
CHANCE = {"frozen": 0.3, "ash": 0.45, "lock": 0.25, "hot": 0.3, "key": 0.25, "rescue": 0.2, "rust": 0.25,
          "conveyor": 0.2, "twin": 0.2, "order": 0.15}
EXCLUSIVE = [{"rescue", "order"}, {"rust", "conveyor"}, {"conveyor", "twin"}]
BOSS_AT = [25, 120, 270, 470, 700]  # level each region's landmark boss is tuned for


def colors_for(n):
    for upto, c in [(2, 2), (5, 3), (10, 4), (20, 5), (35, 6), (60, 7), (100, 8)]:
        if n <= upto:
            return c
    return 9


def is_hard(n):
    return n >= 10 and n % 10 == 0


def hidden_fraction(n):
    return min(0.35, 0.12 + max(0, n - 31) * 0.002)


def compatible(v, chosen):
    return not any(v in ex and (ex - {v}) & chosen for ex in EXCLUSIVE)


def variants_for(n, rng):
    for v, first in INTRO.items():
        if n == first:
            return {v}
    out = {v for v, first in INTRO.items() if first < n <= first + PRACTICE}
    pool = sorted(v for v, first in INTRO.items() if n > first + PRACTICE)
    rng.shuffle(pool)
    limit = 3 if is_hard(n) else 2
    for v in pool:
        if len(out) < limit and rng.random() < CHANCE[v] and compatible(v, out):
            out.add(v)
    return out


# ---------------------------------------------------------------- solver

def col(x):
    return x & 15


def complete(t):
    return len(t) == CAP and all(col(x) == col(t[0]) for x in t)


class Rules:
    def __init__(self, n, frozen=None, lock=None, keylock=None, twin=None, goal=None, symmetric=True):
        self.n = n
        self.frozen = frozen or [0] * n
        self.lock = lock or [-1] * n
        self.keylock = keylock or [-1] * n
        self.twin = twin or [-1] * n
        self.goal = goal or {}
        self.per_row = n if n <= 6 else math.ceil(n / 2)
        # Twins are labelled by pair so swapping the two members stays a symmetry.
        group = [min(i, p) if p >= 0 else -1 for i, p in enumerate(self.twin)]
        self.props = list(zip(self.frozen, self.lock, self.keylock, group))
        self.symmetric = symmetric

    def neighbours(self, i):
        return [j for j in (i - 1, i + 1) if 0 <= j < self.n and j // self.per_row == i // self.per_row]

    def key(self, s):
        return tuple(sorted(zip(self.props, s))) if self.symmetric else s


def top_run(t):
    if not t:
        return None, 0
    c = col(t[-1])
    k = 0
    for x in reversed(t):
        if col(x) != c or x & RUST:
            break
        k += 1
    return c, k


def plan(state, i, j, R, shut):
    a, b = state[i], state[j]
    if not a or complete(a) or shut[i]:
        return []
    c, run = top_run(a)
    if run == 0 or shut[j] or len(b) >= CAP or (R.lock[j] >= 0 and R.lock[j] != c) or (b and col(b[-1]) != c):
        return []
    p = R.twin[j]
    ok = (p >= 0 and p != i and not shut[p] and (R.lock[p] < 0 or R.lock[p] == c)
          and (not state[p] or col(state[p][-1]) == c))
    sizes = {j: len(b)}
    if ok:
        sizes[p] = len(state[p])
    dests, turn = [], j
    for _ in range(run):
        other = (p if turn == j else j) if ok else j
        if sizes[turn] < CAP:
            dests.append(turn)
            sizes[turn] += 1
        elif sizes[other] < CAP:
            dests.append(other)
            sizes[other] += 1
        else:
            break
        if ok:
            turn = other
    return dests


def sealed_colors(state):
    return {col(t[0]) for t in state if complete(t)}


def next_in_order(R, sealed):
    if R.goal.get("type") != "order":
        return -1
    for c in R.goal["colors"]:
        if c not in sealed:
            return c
    return -1


def moves(state, R):
    sealed = sealed_colors(state)
    nsealed = sum(1 for t in state if complete(t))
    shut = [R.frozen[i] > nsealed or (R.keylock[i] >= 0 and R.keylock[i] not in sealed) for i in range(R.n)]
    want = next_in_order(R, sealed)
    out = []
    for i, a in enumerate(state):
        if not a or shut[i]:
            continue
        c, k = top_run(a)
        if k == 0 or (len(a) == CAP and k == CAP):
            continue
        empty_kinds = set()
        for j, b in enumerate(state):
            if i == j:
                continue
            dests = plan(state, i, j, R, shut)
            if not dests:
                continue
            if not b:
                plain = R.twin[j] < 0 and R.keylock[j] < 0
                if plain and ((k == len(a) and R.lock[i] == R.lock[j] and R.twin[i] < 0) or R.lock[j] in empty_kinds):
                    continue  # pointless or a duplicate empty target
                if plain:
                    empty_kinds.add(R.lock[j])
            if want >= 0 and c != want:
                # The order goal forbids sealing anything but the next colour.
                if any(len(state[d]) + dests.count(d) == CAP and all(col(x) == c for x in state[d]) for d in set(dests)):
                    continue
            out.append((i, j, tuple(dests)))
    return out


def apply(state, m, R):
    i, _, dests = m
    s = [list(t) for t in state]
    before = [complete(t) for t in state]
    for d in dests:
        s[d].append(s[i].pop())
    for t in range(R.n):
        if complete(s[t]) and not before[t]:
            for u in [t] + R.neighbours(t):  # a seal scrubs rust here and next door
                s[u] = [x & ~RUST for x in s[u]]
    return tuple(tuple(t) for t in s)


def solved(state, R):
    if R.goal.get("type") == "colors":
        return set(R.goal["colors"]) <= sealed_colors(state)
    return all(len(t) == 0 or complete(t) for t in state)


def h(state):
    # Colour breaks inside tanks + tanks that are not yet a finished single colour.
    b = 0
    for t in state:
        for x, y in zip(t, t[1:]):
            if col(x) != col(y):
                b += 1
        if t and not complete(t):
            b += 1
    return b


def solve(start, R=None, limit=250000):
    start = tuple(tuple(t) for t in start)
    R = R or Rules(len(start))
    seen = {R.key(start): 0}
    heap = [(h(start), 0, start, [])]
    expanded = 0
    while heap:
        f, g, s, path = heapq.heappop(heap)
        if solved(s, R):
            return path
        expanded += 1
        if expanded > limit:
            return None
        for m in moves(s, R):
            ns = apply(s, m, R)
            k = R.key(ns)
            if k in seen and seen[k] <= g + 1:
                continue
            seen[k] = g + 1
            # Weighted A*: fast, near-short solutions.
            heapq.heappush(heap, (g + 1 + 2 * h(ns), g + 1, ns, path + [m]))
    return None


def seal_times(tanks, sol):
    """Move number (1-based) at which each starting canister (tank, index) ends up sealed."""
    st = [[(col(c), (ti, k)) for k, c in enumerate(t)] for ti, t in enumerate(tanks)]
    when = {}
    for m, (i, _, dests) in enumerate(sol, 1):
        for d in dests:
            st[d].append(st[i].pop())
        for t in st:
            if len(t) == CAP and all(x[0] == t[0][0] for x in t):
                for x in t:
                    when.setdefault(x[1], m)
    return when


# ---------------------------------------------------------------- generation

def build(n, rng, vs, colors, empties, hard, slack_base):
    while True:
        pool = [c for c in range(colors) for _ in range(CAP)]
        rng.shuffle(pool)
        tanks = [pool[i * CAP:(i + 1) * CAP] for i in range(colors)]
        if any(len(set(t)) == 1 for t in tanks):
            continue
        # Avoid trivially easy boards: need some mixing on top.
        if len(set(t[-1] for t in tanks)) < min(colors, 3):
            continue
        tanks += [[] for _ in range(empties)]
        frozen = [0] * len(tanks)
        lock = [-1] * len(tanks)
        if "frozen" in vs:
            nf = 2 if n > 150 and rng.random() < 0.4 else 1
            most = 1 if n <= INTRO["frozen"] + PRACTICE else min(3, colors - 2)
            for t in rng.sample(range(colors), nf):
                frozen[t] = rng.randint(1, max(1, most))
        if "lock" in vs:
            c = rng.randrange(colors)
            if empties == 1 or colors >= 7:
                tanks.append([])  # an extra tagged tank
                frozen.append(0)
                lock.append(c)
            else:
                lock[colors + rng.randrange(empties)] = c
        nt = len(tanks)
        keylock = [-1] * nt
        if "key" in vs:
            free = [t for t in range(nt) if not frozen[t] and lock[t] < 0]
            t = rng.choice(free)
            keylock[t] = rng.choice([c for c in range(colors) if not (tanks[t] and all(x == c for x in tanks[t]))])
        twin = [-1] * nt
        if "twin" in vs:
            per_row = nt if nt <= 6 else math.ceil(nt / 2)
            pairs = [(k, k + 1) for k in range(nt - 1) if k // per_row == (k + 1) // per_row
                     and not frozen[k] and not frozen[k + 1] and keylock[k] < 0 and keylock[k + 1] < 0]
            if pairs:
                a, b = rng.choice(pairs)
                twin[a], twin[b] = b, a
        rust = [[False] * len(t) for t in tanks]
        if "rust" in vs:
            spots = [(t, k) for t in range(colors) for k in range(len(tanks[t]) - 1)]
            for t, k in rng.sample(spots, rng.randint(2, 4)):
                rust[t][k] = True
        goal = {}
        if "rescue" in vs:
            goal = {"type": "colors", "colors": sorted(rng.sample(range(colors), rng.randint(2, 3)))}
        elif "order" in vs:
            goal = {"type": "order", "colors": rng.sample(range(colors), 3)}
        start = [[x | (RUST if rust[t][k] else 0) for k, x in enumerate(tanks[t])] for t in range(nt)]
        R = Rules(nt, frozen, lock, keylock, twin, goal, symmetric="rust" not in vs)
        sol = solve(start, R)
        if sol is None:
            continue
        hidden = [[False] * len(t) for t in tanks]
        if "ash" in vs:
            frac = hidden_fraction(n) + (0.08 if hard else 0.0)
            for t, hid in zip(tanks, hidden):
                for k in range(len(t) - 1):  # top canister always visible
                    if rng.random() < frac:
                        hid[k] = True
        slack = slack_base
        if empties == 1:
            slack += 0.1
        if hard:
            slack -= 0.12
        if "ash" in vs:
            slack += 0.15
        if vs & {"frozen", "lock", "key", "rust", "twin", "order"}:
            slack += 0.1
        allowed = max(len(sol) + 3, math.ceil(len(sol) * slack))
        lv = {"tanks": tanks, "moves": allowed, "solution": len(sol), "hard": hard,
              "_sol": [[i, j, len(d)] for i, j, d in sol]}  # stripped before writing levels.json
        if any(any(r) for r in hidden):
            lv["hidden"] = hidden
        for name, arr, none in (("frozen", frozen, 0), ("lock", lock, -1), ("keylock", keylock, -1), ("twin", twin, -1)):
            if any(x != none for x in arr):
                lv[name] = arr
        if any(any(r) for r in rust):
            lv["rust"] = rust
        if "conveyor" in vs:
            lv["conveyor"] = rng.choice([3, 4, 5])
        if goal:
            lv["goal"] = goal
            if goal["type"] == "colors":
                lv["parts"] = [rng.choice([[t, k] for t in range(nt) for k, x in enumerate(tanks[t]) if x == c]) for c in goal["colors"]]
        if "hot" in vs:
            when = seal_times(tanks, sol)
            lo, hi = 0.2 * len(sol), 0.75 * len(sol)
            cand = sorted(p for p, m in when.items() if lo <= m <= hi and not hidden[p[0]][p[1]]
                          and not frozen[p[0]] and not rust[p[0]][p[1]])
            if cand:
                nh = 2 if n > 150 and rng.random() < 0.4 and len(cand) > 4 else 1
                lv["hot"] = [[p[0], p[1], min(math.ceil(when[p] * 1.25) + 2, allowed - 2)] for p in rng.sample(cand, nh)]
        return lv


def make_level(n):
    rng = random.Random("%d-%d" % (SEED, n))
    vs = variants_for(n, rng)
    colors = colors_for(n) + (1 if is_hard(n) and colors_for(n) < 9 else 0)
    empties = 2
    # Variety past level 60: some boards have fewer colours but only one spare tank.
    if n > 60 and not is_hard(n) and rng.random() < 0.25:
        colors = max(5, colors - 3)
        empties = 1
    elif n > 100 and not is_hard(n):
        colors = rng.choice([7, 8, 9, 9])
    slack = 1.7 if n <= 10 else (1.5 if n <= 40 else 1.35)
    return build(n, rng, vs, colors, empties, is_hard(n), slack)


def make_boss(r):
    """Landmark boss for region r: every blocker met so far can appear, tighter budget."""
    n = BOSS_AT[r]
    rng = random.Random("%d-boss-%d" % (SEED, r))
    known = [v for v, first in INTRO.items() if first <= n]
    rng.shuffle(known)
    vs = set()
    for v in known:
        if len(vs) < 3 and compatible(v, vs) and v not in ("rescue", "order"):
            vs.add(v)
    colors = min(9, colors_for(n) + 1)
    lv = build(n, rng, vs, colors, 2, True, 1.4)
    lv["boss"] = True
    return lv


SOLUTIONS = os.path.join(os.path.dirname(__file__), "..", "tests", "solutions.json")


def write_solutions():
    """Solver move lists for a sample of blocker levels; tests/test_puzzle.gd replays them on
    the GDScript board to prove both implement the same rules."""
    sample = sorted(set([n for n in range(16, N_LEVELS + 1, 9)] + list(INTRO.values())))
    with Pool() as p:
        lvs = p.map(make_level, sample)
        bosses = p.map(make_boss, range(len(BOSS_AT)))
    out = {"levels": {str(n): lv["_sol"] for n, lv in zip(sample, lvs)},
           "bosses": [b["_sol"] for b in bosses]}
    with open(SOLUTIONS, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    print("wrote", len(sample), "level solutions +", len(bosses), "boss solutions to", os.path.normpath(SOLUTIONS))


def main():
    import sys
    if "--solutions" in sys.argv:
        write_solutions()
        return
    with Pool() as p:
        levels = []
        for n, lv in enumerate(p.imap(make_level, range(1, N_LEVELS + 1), chunksize=4), 1):
            levels.append(lv)
            if n % 50 == 0:
                tags = [k for k in ("hidden", "frozen", "lock", "keylock", "rust", "twin", "conveyor", "goal", "hot") if k in lv]
                print("level", n, "tanks", len(lv["tanks"]), "solution", lv["solution"], "moves", lv["moves"], tags, flush=True)
        bosses = p.map(make_boss, range(len(BOSS_AT)))
    # Tutorial level 1: hand-made, two quick pours.
    t1 = [[0, 1, 0, 0], [1, 0, 1, 1], []]
    levels[0] = {"tanks": t1, "moves": 12, "solution": len(solve(t1)), "hard": False}
    for lv in levels + bosses:
        lv.pop("_sol", None)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump({"capacity": CAP, "levels": levels, "bosses": bosses}, f, separators=(",", ":"))
    counts = {k: sum(1 for lv in levels if k in lv) for k in ("hidden", "frozen", "lock", "keylock", "rust", "twin", "conveyor", "goal", "hot")}
    print("wrote", len(levels), "levels +", len(bosses), "bosses to", os.path.normpath(OUT), counts)


if __name__ == "__main__":
    main()

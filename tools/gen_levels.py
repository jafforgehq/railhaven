"""Generate Railhaven's coolant-sort levels and prove every one is solvable.

    python3 tools/gen_levels.py            # writes data/levels.json

A level is a list of tanks (bottom -> top colour indices, capacity 4) plus optional blockers:
  hidden  per-canister ash flags (revealed when exposed)
  frozen  per tank: sealed tanks needed before it thaws (0 = free)
  lock    per tank: the only colour it accepts (-1 = any)
  hot     [tank, index, pours]: a canister that flares (heat spike) unless sealed in time
Every level is solved with a weighted A* that obeys the same rules as scripts/puzzle/board.gd
(frozen and lock; ash and hot do not change which moves are legal). The solution length sets
the move budget the heat gauge allows. Each level has its own seeded RNG, so levels are
generated in parallel and never change between builds.
"""
import heapq
import json
import math
import os
import random
from multiprocessing import Pool

CAP = 4
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "levels.json")
N_LEVELS = 1000
SEED = 20261101

# First level each blocker appears. That level teaches it alone; the next PRACTICE levels keep it.
INTRO = {"frozen": 16, "ash": 31, "lock": 46, "hot": 66}
PRACTICE = 4
CHANCE = {"frozen": 0.35, "ash": 0.5, "lock": 0.3, "hot": 0.35}


def colors_for(n):
    for upto, c in [(2, 2), (5, 3), (10, 4), (20, 5), (35, 6), (60, 7), (100, 8)]:
        if n <= upto:
            return c
    return 9


def is_hard(n):
    return n >= 10 and n % 10 == 0


def hidden_fraction(n):
    return min(0.35, 0.12 + max(0, n - 31) * 0.002)


def variants_for(n, rng):
    for v, first in INTRO.items():
        if n == first:
            return {v}
    out = {v for v, first in INTRO.items() if first < n <= first + PRACTICE}
    pool = sorted(v for v, first in INTRO.items() if n > first + PRACTICE)
    rng.shuffle(pool)
    limit = 3 if is_hard(n) else 2
    for v in pool:
        if len(out) < limit and rng.random() < CHANCE[v]:
            out.add(v)
    return out


def top_run(t):
    if not t:
        return None, 0
    c = t[-1]
    k = 0
    for x in reversed(t):
        if x != c:
            break
        k += 1
    return c, k


def complete(t):
    return len(t) == CAP and t.count(t[0]) == CAP


def solved(state):
    return all(len(t) == 0 or complete(t) for t in state)


def moves(state, frozen, lock):
    sealed = sum(1 for t in state if complete(t))
    out = []
    for i, a in enumerate(state):
        if not a or frozen[i] > sealed:
            continue
        c, k = top_run(a)
        if len(a) == CAP and k == CAP:
            continue  # finished tank stays put
        empty_kinds = set()
        for j, b in enumerate(state):
            if i == j or len(b) >= CAP or frozen[j] > sealed:
                continue
            if lock[j] >= 0 and lock[j] != c:
                continue
            if b and b[-1] != c:
                continue
            if not b:
                # Pointless: a whole uniform tank into an equivalent empty one, or a second
                # empty target of the same kind.
                if (k == len(a) and lock[i] == lock[j]) or lock[j] in empty_kinds:
                    continue
                empty_kinds.add(lock[j])
            out.append((i, j, min(k, CAP - len(b))))
    return out


def apply(state, m):
    i, j, n = m
    s = [list(t) for t in state]
    for _ in range(n):
        s[j].append(s[i].pop())
    return tuple(tuple(t) for t in s)


def h(state):
    # Colour breaks inside tanks + tanks that are not yet a finished single colour.
    b = 0
    for t in state:
        for x, y in zip(t, t[1:]):
            if x != y:
                b += 1
        if t and not complete(t):
            b += 1
    return b


def solve(start, frozen=None, lock=None, limit=250000):
    start = tuple(tuple(t) for t in start)
    frozen = frozen or [0] * len(start)
    lock = lock or [-1] * len(start)
    props = list(zip(frozen, lock))

    def key(s):  # tanks with the same blockers are interchangeable
        return tuple(sorted(zip(props, s)))

    seen = {key(start): 0}
    heap = [(h(start), 0, start, [])]
    expanded = 0
    while heap:
        f, g, s, path = heapq.heappop(heap)
        if solved(s):
            return path
        expanded += 1
        if expanded > limit:
            return None
        for m in moves(s, frozen, lock):
            ns = apply(s, m)
            k = key(ns)
            if k in seen and seen[k] <= g + 1:
                continue
            seen[k] = g + 1
            # Weighted A*: fast, near-short solutions.
            heapq.heappush(heap, (g + 1 + 2 * h(ns), g + 1, ns, path + [m]))
    return None


def seal_times(tanks, sol):
    """Move number (1-based) at which each starting canister (tank, index) ends up sealed."""
    st = [[(c, (ti, k)) for k, c in enumerate(t)] for ti, t in enumerate(tanks)]
    when = {}
    for m, (i, j, n) in enumerate(sol, 1):
        for _ in range(n):
            st[j].append(st[i].pop())
        for t in st:
            if len(t) == CAP and all(x[0] == t[0][0] for x in t):
                for x in t:
                    when.setdefault(x[1], m)
    return when


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
            col = rng.randrange(colors)
            if empties == 1 or colors >= 7:
                tanks.append([])  # an extra tagged tank
                frozen.append(0)
                lock.append(col)
            else:
                lock[colors + rng.randrange(empties)] = col
        sol = solve(tanks, frozen, lock)
        if sol is None:
            continue
        hard = is_hard(n)
        hidden = [[False] * len(t) for t in tanks]
        if "ash" in vs:
            frac = hidden_fraction(n) + (0.08 if hard else 0.0)
            for t, hid in zip(tanks, hidden):
                for k in range(len(t) - 1):  # top canister always visible
                    if rng.random() < frac:
                        hid[k] = True
        slack = 1.7 if n <= 10 else (1.5 if n <= 40 else 1.35)
        if empties == 1:
            slack += 0.1
        if hard:
            slack -= 0.12
        if "ash" in vs:
            slack += 0.15
        if "frozen" in vs or "lock" in vs:
            slack += 0.1
        allowed = max(len(sol) + 3, math.ceil(len(sol) * slack))
        lv = {"tanks": tanks, "moves": allowed, "solution": len(sol), "hard": hard}
        if any(any(r) for r in hidden):
            lv["hidden"] = hidden
        if any(frozen):
            lv["frozen"] = frozen
        if any(x >= 0 for x in lock):
            lv["lock"] = lock
        if "hot" in vs:
            when = seal_times(tanks, sol)
            lo, hi = 0.2 * len(sol), 0.75 * len(sol)
            cand = sorted(p for p, m in when.items() if lo <= m <= hi and not hidden[p[0]][p[1]] and not frozen[p[0]])
            if cand:
                nh = 2 if n > 150 and rng.random() < 0.4 and len(cand) > 4 else 1
                lv["hot"] = [[p[0], p[1], min(math.ceil(when[p] * 1.25) + 2, allowed - 2)] for p in rng.sample(cand, nh)]
        return lv


def main():
    with Pool() as p:
        levels = []
        for n, lv in enumerate(p.imap(make_level, range(1, N_LEVELS + 1), chunksize=4), 1):
            levels.append(lv)
            if n % 50 == 0:
                tags = [k for k in ("hidden", "frozen", "lock", "hot") if k in lv]
                print("level", n, "tanks", len(lv["tanks"]), "solution", lv["solution"], "moves", lv["moves"], tags, flush=True)
    # Tutorial level 1: hand-made, two quick pours.
    t1 = [[0, 1, 0, 0], [1, 0, 1, 1], []]
    levels[0] = {"tanks": t1, "moves": 12, "solution": len(solve(t1)), "hard": False}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump({"capacity": CAP, "levels": levels}, f, separators=(",", ":"))
    counts = {k: sum(1 for lv in levels if k in lv) for k in ("hidden", "frozen", "lock", "hot")}
    print("wrote", len(levels), "levels to", os.path.normpath(OUT), counts)


if __name__ == "__main__":
    main()

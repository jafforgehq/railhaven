"""Generate Railhaven's coolant-sort levels and prove every one is solvable.

    python3 tools/gen_levels.py            # writes data/levels.json

A level is a list of tanks (bottom -> top colour indices, capacity 4) plus hidden flags
(ash-covered canisters). Each level is solved with a best-first search; the solution length
sets the move budget the heat gauge allows. Deterministic (fixed seed) so levels never change
between builds.
"""
import heapq
import json
import math
import os
import random

CAP = 4
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "levels.json")
N_LEVELS = 300


def colors_for(n):
    for upto, c in [(2, 2), (5, 3), (10, 4), (20, 5), (35, 6), (60, 7), (100, 8)]:
        if n <= upto:
            return c
    return 9


def is_hard(n):
    return n >= 10 and n % 10 == 0


def hidden_fraction(n):
    if n < 31:
        return 0.0
    return min(0.35, 0.12 + (n - 31) * 0.002)


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


def solved(state):
    return all(len(t) == 0 or (len(t) == CAP and len(set(t)) == 1) for t in state)


def moves(state):
    out = []
    for i, a in enumerate(state):
        if not a:
            continue
        c, k = top_run(a)
        if len(a) == CAP and k == CAP:
            continue  # finished tank stays put
        moved_empty = False
        for j, b in enumerate(state):
            if i == j or len(b) >= CAP:
                continue
            if b and b[-1] != c:
                continue
            if not b:
                if k == len(a) or moved_empty:
                    continue  # pointless: whole uniform tank into an empty one, or a second empty target
                moved_empty = True
            n = min(k, CAP - len(b))
            out.append((i, j, n))
    return out


def apply(state, m):
    i, j, n = m
    s = [list(t) for t in state]
    for _ in range(n):
        s[j].append(s[i].pop())
    return tuple(tuple(t) for t in s)


def key(state):
    return tuple(sorted(state))


def h(state):
    # Colour breaks inside tanks + tanks that are not yet a finished single colour.
    b = 0
    for t in state:
        for x, y in zip(t, t[1:]):
            if x != y:
                b += 1
        if t and not (len(t) == CAP and len(set(t)) == 1):
            b += 1
    return b


def solve(start, limit=250000):
    start = tuple(tuple(t) for t in start)
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
        for m in moves(s):
            ns = apply(s, m)
            k = key(ns)
            if k in seen and seen[k] <= g + 1:
                continue
            seen[k] = g + 1
            # Weighted A*: fast, near-short solutions.
            heapq.heappush(heap, (g + 1 + 2 * h(ns), g + 1, ns, path + [m]))
    return None


def make_level(n, rng):
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
        tops = [t[-1] for t in tanks]
        if len(set(tops)) < min(colors, 3):
            continue
        tanks += [[] for _ in range(empties)]
        sol = solve(tanks)
        if sol is None:
            continue
        frac = hidden_fraction(n) + (0.08 if is_hard(n) and n > 31 else 0.0)
        hidden = [[False] * len(t) for t in tanks]
        if frac > 0:
            for t, hid in zip(tanks, hidden):
                for k in range(len(t) - 1):  # top canister always visible
                    if rng.random() < frac:
                        hid[k] = True
        slack = 1.7 if n <= 10 else (1.5 if n <= 40 else 1.35)
        if empties == 1:
            slack += 0.1
        if is_hard(n):
            slack -= 0.12
        if frac > 0:
            slack += 0.15
        allowed = max(len(sol) + 3, math.ceil(len(sol) * slack))
        return {"tanks": tanks, "hidden": hidden, "moves": allowed, "solution": len(sol), "hard": is_hard(n)}


def main():
    rng = random.Random(20261101)
    levels = []
    for n in range(1, N_LEVELS + 1):
        lv = make_level(n, rng)
        levels.append(lv)
        if n % 25 == 0:
            print("level", n, "colors", len(lv["tanks"]) - 2, "solution", lv["solution"], "moves", lv["moves"])
    # Tutorial level 1: hand-made, two quick pours.
    levels[0] = {"tanks": [[0, 1, 0, 0], [1, 0, 1, 1], []], "hidden": [[False] * 4, [False] * 4, []],
                 "moves": 12, "solution": len(solve([[0, 1, 0, 0], [1, 0, 1, 1], []])), "hard": False}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump({"capacity": CAP, "levels": levels}, f, separators=(",", ":"))
    print("wrote", len(levels), "levels to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()

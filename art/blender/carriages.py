"""Railhaven carriages, locomotive and moving parts, modelled and rendered in Blender.

  Blender -b --factory-startup --python art/blender/carriages.py -- <out_dir> [only...]

Outputs (4 px per world unit, transparent background):
  carriage_<type>_<level>.png   whole cutaway carriage, region x -4..236, height 0..164
  locomotive.png                locomotive body, region x -26..206, height 0..164
  wheel.png / wheel_big.png     wheels (rotated in Godot)
  fan.png                       cooling fan rotor (rotated in Godot)
  drone.png / drone_crate.png   salvage drone, empty and carrying a crate
Lamp light cones, glows, sparks, bubbles and smoke are in-engine effects.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import box, sphere, ycyl, xcyl, zcyl, cylinder, torus, prism, text, toon, shade  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/railhaven_carriages"
ONLY = set(ARGS[1:])
PX = 4.0
W = 232.0
FLOOR = 32.0
TOP = 120.0
BACK = 30.0  # back wall depth

HULL = "272b32"
HULL_DARK = "181b20"
TRIM = "b08a45"
WOOD = "7a5638"
METAL = "6f7882"
WALLS = {"quarters": "35514f", "greenhouse": "245a48", "recycler": "1f4c64", "workshop": "2f5452", "cooling": "1d5260", "dronebay": "235254"}


def M(hexstr, **kw):
    return toon(hexstr, **kw)


# ---------------------------------------------------------------- shared shell

def shell(kind, level):
    wall = WALLS[kind]
    # Back wall with panel seams, rivets and a wainscot rail.
    box("wall", 7, FLOOR, W - 7, TOP, BACK, BACK + 3, M(wall, ao=0.0), outline=False)
    box("wall_low", 7, FLOOR, W - 7, 70, BACK - 0.5, BACK, M(shade(wall, 0.85), ao=0.0), outline=False)
    for x in range(36, int(W) - 10, 30):
        box("seam", x - 0.6, FLOOR, x + 0.6, TOP, BACK - 0.6, BACK, M(shade(wall, 0.7), ao=0.0), outline=False)
        for z in (TOP - 14, 76, FLOOR + 5):
            sphere("rivet", 0.7, M(shade(wall, 1.25), ao=0.0), (x - 2.6, BACK - 0.7, z), outline=False, seg=8)
            sphere("rivet", 0.7, M(shade(wall, 1.25), ao=0.0), (x + 3.4, BACK - 0.7, z), outline=False, seg=8)
    box("rail", 7, 69.5, W - 7, 71.5, BACK - 1.5, BACK, M(shade(wall, 0.6)), outline=False)
    # Floor planks.
    box("floor", 7, FLOOR - 6, W - 7, FLOOR, -3, BACK, M("43362b"))
    for x in range(12, int(W) - 10, 14):
        box("plank", x - 0.3, FLOOR - 0.2, x + 0.3, FLOOR + 0.05, -3, BACK, M("2a2018", ao=0.0), outline=False)
    # Ceiling duct, brass pipe and brackets.
    box("ceiling", 7, TOP - 6, W - 7, TOP, 0, BACK + 3, M("11151a"), outline=False)
    xcyl("pipe", 1.5, 10, W - 10, TOP - 8.5, BACK - 3, M("8a6a38"))
    for x in range(22, int(W) - 10, 44):
        box("bracket", x, TOP - 11.5, x + 3, TOP - 5, BACK - 5, BACK - 1, M("3a3f45"))
    # Lamp housings (the light cones are drawn in-engine).
    for lx in ([58.0, 174.0] if level < 3 else [40.0, 116.0, 192.0]):
        cylinder("lamp", 9, 4, M("2c3036"), (lx, BACK - 8, TOP - 13), r2=6)
        box("bulb", lx - 7.5, TOP - 17.5, lx + 7.5, TOP - 15.5, BACK - 12, BACK - 4, M("fff2d0", glow=1.4), outline=False)
    # Bulkheads with doors and portholes.
    for sx in (0.0, W - 7):
        box("bulkhead", sx, 20, sx + 7, TOP, -5, BACK + 3, M(HULL))
        box("door", sx + 1.3, 32, sx + 5.7, 100, -5.6, -4.8, M("1d2025"), outline=False)
        ycyl("port_rim", 2.4, 1.0, M("3a3f45"), sx + 3.5, 88, -5.8)
        ycyl("porthole", 1.7, 1.2, M("ffad52", glow=1.3), sx + 3.5, 88, -6.0, outline=False)
        for z in range(36, 116, 12):
            sphere("rivet", 0.55, M("737985", ao=0.0), (sx + 3.5, -5.2, z), outline=False, seg=8)
    # Brass rim around the cutaway opening.
    for x0, z0, x1, z1 in ((7, TOP - 1, W - 7, TOP), (7, FLOOR - 1, W - 7, FLOOR)):
        box("rim", x0, z0, x1, z1, -5, -3.5, M(TRIM), outline=False)
    # Roof canopy with rivets and trim.
    box("roof", -1, TOP, W + 1, TOP + 19, -6, BACK + 4, M(HULL), bevel=6.5)
    box("trim", 0, TOP, W, TOP + 1.6, -6.4, BACK + 4, M(TRIM), outline=False)
    for x in range(8, int(W) - 4, 12):
        sphere("rivet", 0.75, M("737985", ao=0.0), (x, -6.6, TOP + 7.5), outline=False, seg=8)
    # Underframe, skirt, equipment boxes and bogie frames.
    box("frame", 0, 20, W, 26, -5, BACK + 3, M(HULL_DARK))
    box("frame_trim", 0, 25.2, W, 26, -5.4, BACK + 3, M(TRIM), outline=False)
    box("skirt", 0, 17, W, 20, -3, BACK, M("121417"), outline=False)
    for bx in (72.0, 126.0):
        box("equip", bx, 10.5, bx + 34, 19.5, -3, 10, M("2a2e34"))
        for k in range(4):
            box("hazard", bx + 3 + k * 8, 12, bx + 7 + k * 8, 14.5, -3.4, -2.9, M("d9a33a", ao=0.0), outline=False)
    for bx in (32.0, W - 32.0):  # bolster pads the bogies (rendered separately) bolt onto
        box("bolster", bx - 10, 16, bx + 10, 20, -4, BACK, M("2b2e34"))
    # Level pips on the roof.
    for i in range(level):
        ycyl("pip", 1.6, 1.0, M("f0b84a", glow=1.2), W - 14 - i * 6, TOP + 11.5, -6.8)


# ---------------------------------------------------------------- interiors

def leaf_cluster(x, z, y, size, greens, fruit=False):
    for k in range(5):
        a = -0.9 + k * 0.45
        sphere("leaf", size * 0.42, M(greens[k % len(greens)]), (x + math.sin(a) * size * 0.55, y, z + size * 0.55 + math.cos(a) * size * 0.35),
               scale=(1.0, 0.7, 1.4), rot=(0, a, 0), outline=(k == 2), seg=10)
    if fruit:
        sphere("fruit", size * 0.24, M("e0502e"), (x + size * 0.35, y - size * 0.4, z + size * 0.5), seg=10)


def quarters(level):
    bunks = min(1 + level // 2, 3)
    blankets = ["3f6f7a", "7a4a5a", "5f7a3a", "8a6a3a"]
    box("rug", 146, FLOOR - 0.05, 206, FLOOR + 0.3, 4, 26, M("7a3a2a"), outline=False)
    for b in range(bunks):
        bx = 14.0 + b * 40.0
        box("post", bx, FLOOR, bx + 2.6, FLOOR + 64, 10, 13, M("5a4632"))
        box("post", bx + 33.4, FLOOR, bx + 36, FLOOR + 64, 10, 13, M("5a4632"))
        for tier in range(2):
            bz = FLOOR + 14 + tier * 26
            box("bed", bx, bz - 3.5, bx + 36, bz, 8, 26, M("6a5038"))
            box("mattress", bx + 2.5, bz, bx + 33.5, bz + 4.4, 9, 25, M(blankets[(b + tier) % 4]), bevel=1.8)
            box("pillow", bx + 3, bz + 3, bx + 11.5, bz + 6.6, 11, 23, M("ece6d6"), bevel=1.5)
        for k in range(4):
            box("rung", bx + 29, FLOOR + 4 + k * 9, bx + 34, FLOOR + 4.8 + k * 9, 6, 8, M("8a6a48"), outline=False)
    lx = 16.0 + bunks * 40.0
    for k in range(2):
        box("locker", lx + k * 10.5, FLOOR, lx + k * 10.5 + 10, FLOOR + 44, 18, 28, M("536c76"))
        for v in range(3):
            box("vent", lx + k * 10.5 + 2.5, FLOOR + 38 - v * 2, lx + k * 10.5 + 7.5, FLOOR + 38.6 - v * 2, 17.6, 18, M("33454c"), outline=False)
        box("handle", lx + k * 10.5 + 7, FLOOR + 21, lx + k * 10.5 + 8.2, FLOOR + 26, 17.4, 18, M("c9ccd2"), outline=False)
    cylinder("pot", 3.6, 6, M("9a5a3a"), (lx + 10, 22, FLOOR + 47), r2=4.2)
    leaf_cluster(lx + 10, FLOOR + 49, 22, 6, ["4caf50", "5cbf5a", "2f7a3a"])
    # Mess table, stools, dishes.
    box("table", 152, FLOOR + 13, 202, FLOOR + 16, 8, 22, M(WOOD))
    for x in (157.0, 194.0):
        box("leg", x, FLOOR, x + 2.6, FLOOR + 13, 10, 12.6, M(shade(WOOD, 0.8)))
    for sx in (164.0, 188.0):
        cylinder("stool", 4, 2.2, M(shade(WOOD, 1.1)), (sx, 4, FLOOR + 8), seg=16)
        zcyl("stool_leg", 1.0, FLOOR, FLOOR + 7, sx, 4, M(shade(WOOD, 0.7)))
    for px in (166.0, 186.0):
        cylinder("plate", 4, 0.8, M("e8e2d2"), (px, 12, FLOOR + 16.6), seg=16)
    sphere("bread", 1.6, M("c0703a"), (166, 12, FLOOR + 17.6), seg=10)
    cylinder("mug", 1.5, 4.6, M("d0c8b0"), (177.5, 14, FLOOR + 18.3), seg=12)
    # Stove and flue.
    box("stove", 206, FLOOR, 221, FLOOR + 30, 14, 28, M("2c3036"))
    box("firebox", 209, FLOOR + 9, 218, FLOOR + 17, 13.6, 14, M("ff8a30", glow=1.6), outline=False)
    zcyl("flue", 1.3, FLOOR + 30, TOP - 9, 213.5, 20, M("3a3f45"))
    # Picture, banner.
    box("frame_pic", 148, 86, 168, 100, BACK - 1.5, BACK, M("a07a3c"))
    box("canvas", 150, 88, 166, 98, BACK - 1.8, BACK - 1.5, M("e0904a", ao=0.0), outline=False)
    ycyl("pic_sun", 2.2, 0.4, M("ffe0a0", ao=0.0), 161, 94, BACK - 2.0, outline=False)
    prism("banner", [(176, 104), (188, 104), (188, 82), (182, 78), (176, 82)], BACK - 1.6, BACK - 1.0, M("8a2a20"))
    ycyl("emblem", 3.0, 0.4, M("ffb050", ao=0.0), 182, 93, BACK - 1.8, outline=False)


def greenhouse(level):
    racks = min(2 + level // 2, 4)
    rw = (W - 30.0) / racks
    greens = ["3f9a48", "5cbf5a", "7fd66a"]
    for r in range(racks):
        rx = 14.0 + r * rw
        box("post", rx - 1.5, FLOOR, rx + 0.9, FLOOR + 78, 14, 17, M("7a8088"))
        box("post", rx + rw - 11, FLOOR, rx + rw - 8.6, FLOOR + 78, 14, 17, M("7a8088"))
        for tier in range(3):
            tz = FLOOR + 5 + tier * 24
            box("growlight", rx + 1, tz + 20.2, rx + rw - 11, tz + 22, 12, 20, M("ffb8e8", glow=1.5), outline=False)
            box("tray", rx, tz - 0.5, rx + rw - 10, tz + 3, 9, 22, M("4a3424"))
            n = int((rw - 14) / 9.5)
            for k in range(n):
                fruit = level >= 3 and (k + tier + r) % 3 == 0
                leaf_cluster(rx + 5.5 + k * 9.5, tz + 3, 14, 5.0 + level * 0.45, greens, fruit)
    for k in range(5):
        vx = 30.0 + k * 44.0
        for i in range(7):
            sphere("vine", 1.4, M("3f8f40"), (vx + math.sin(i * 0.9 + k) * 2.0, BACK - 4, TOP - 10 - i * 4), scale=(1.0, 0.6, 1.4), outline=False, seg=8)
    xcyl("irrigation", 0.8, 12, W - 12, TOP - 14, 8, M("4f86b0"))


def recycler(level):
    tanks = min(1 + level // 2, 3)
    for k in range(tanks):
        tx = 18.0 + k * 60.0
        cx = tx + 20
        zcyl("tank_back", 19, FLOOR + 7, FLOOR + 67, cx, 16, M("9fd4f0", ao=0.0), outline=False, seg=32)
        zcyl("water", 18, FLOOR + 7, FLOOR + 40, cx, 14, M("2a8ad8", light=1.25, ao=0.0), outline=False, seg=32)
        box("glint", tx + 5, FLOOR + 10, tx + 7.4, FLOOR + 62, -4.5, -4, M("ffffff", glow=0.5), outline=False)
        box("glint2", tx + 9, FLOOR + 10, tx + 10, FLOOR + 62, -4.5, -4, M("cfefff", glow=0.4), outline=False)
        zcyl("cap_top", 21, FLOOR + 66, FLOOR + 71, cx, 16, M(METAL), seg=32)
        zcyl("cap_bot", 21, FLOOR, FLOOR + 7, cx, 16, M(METAL), seg=32)
        zcyl("band", 20.5, FLOOR + 37, FLOOR + 39.4, cx, 16, M(shade(METAL, 0.85)), outline=False, seg=32)
        zcyl("feed", 1.5, FLOOR + 71, TOP - 9, cx, 20, M("6a5430"))
    fx = 22.0 + tanks * 60.0
    for k in range(2):
        zcyl("filter", 5, FLOOR, FLOOR + 46, fx + k * 13 + 5, 18, M("c8d0d6"))
        zcyl("filter_band", 5.2, FLOOR + 28, FLOOR + 31, fx + k * 13 + 5, 18, M("4f86b0"), outline=False)
    box("panel", W - 44, 70, W - 14, 96, BACK - 3, BACK, M("1a2228"))
    box("pump", W - 40, FLOOR, W - 18, FLOOR + 18, 16, 26, M("3a5866"))
    ycyl("pump_wheel", 5, 1.2, M(METAL), W - 29, FLOOR + 10, 15.4)
    xcyl("pump_pipe", 1.6, W - 60, W - 40, FLOOR + 14, 20, M("6f7882"))


def workshop(level):
    box("pegboard", 16, 70, 82, 106, BACK - 2, BACK, M("6a5236"))
    for x in range(20, 80, 5):
        for z in range(74, 104, 5):
            ycyl("hole", 0.4, 0.3, M("2e2216", ao=0.0), x, z, BACK - 2.1, outline=False, seg=6)
    steel = M("aeb6be")
    box("wrench", 23.2, 80, 24.8, 100, BACK - 3, BACK - 2, steel)
    torus("wrench_head", 2.4, 0.8, steel, (24, BACK - 2.6, 101.5), rot=(math.pi / 2, 0, 0))
    box("hammer_h", 33.3, 78, 34.7, 98, BACK - 3, BACK - 2, M("8a5a34"))
    box("hammer_head", 30.5, 97.5, 37.5, 101, BACK - 3.4, BACK - 2, M("9aa2aa"))
    prism("saw", [(44, 100), (58, 100), (58, 84), (44, 96)], BACK - 2.8, BACK - 2.0, M("c0c6cc"))
    box("saw_h", 56, 97, 61, 102, BACK - 3, BACK - 2, M("8a5a34"))
    box("plier_a", 67, 80, 68.4, 99, BACK - 3, BACK - 2, M("c83a2a"))
    box("plier_b", 72.6, 80, 74, 99, BACK - 3, BACK - 2, M("c83a2a"))
    box("blueprint", 122, 80, 158, 106, BACK - 1.5, BACK, M("2a5a8a", ao=0.0))
    for k in range(4):
        box("line", 126, 101 - k * 5, 154, 101.5 - k * 5, BACK - 1.7, BACK - 1.5, M("b8e0ff", ao=0.0), outline=False)
    torus("circle", 5, 0.35, M("d0f0ff", ao=0.0), (146, BACK - 1.7, 93), rot=(math.pi / 2, 0, 0))
    sphere("pin", 1.2, M("e04a3a"), (140, BACK - 2, 105), seg=8)
    benches = min(1 + level // 2, 3)
    for b in range(benches):
        bx = 18.0 + b * 70.0
        box("bench", bx, FLOOR + 14, bx + 56, FLOOR + 18, 6, 22, M(WOOD))
        box("leg", bx + 3, FLOOR, bx + 6, FLOOR + 14, 8, 11, M(shade(WOOD, 0.75)))
        box("leg", bx + 50, FLOOR, bx + 53, FLOOR + 14, 8, 11, M(shade(WOOD, 0.75)))
        box("shelf", bx + 6, FLOOR + 6.5, bx + 50, FLOOR + 9, 8, 20, M(shade(WOOD, 0.7)))
        box("vise", bx + 34, FLOOR + 18, bx + 46, FLOOR + 25, 10, 16, M("5f6b75"))
        box("vise_jaw", bx + 38, FLOOR + 25, bx + 42, FLOOR + 28, 11, 15, M("8a939c"))
        ycyl("gear", 3.0, 1.2, M("c9b07a"), bx + 14, FLOOR + 21, 12)
        box("toolbox", bx + 20, FLOOR + 18, bx + 28, FLOOR + 22, 10, 16, M("b83a2a"))
    lx = W - 58.0
    box("lathe", lx, FLOOR, lx + 42, FLOOR + 26, 10, 26, M("3d5d6c"))
    box("lathe_head", lx + 4, FLOOR + 26, lx + 34, FLOOR + 33, 12, 24, M("2c4752"))
    ycyl("chuck", 4.4, 3, M("9aa2aa"), lx + 10, FLOOR + 29.5, 10)
    xcyl("spindle", 0.9, lx + 10, lx + 28, FLOOR + 29.5, 10, M("c0c6cc"))
    sphere("stop", 2.0, M("e04a3a"), (lx + 32, 9.5, FLOOR + 16), seg=10)
    for k in range(3):
        cx = lx - 18.0 - k * 13.0
        box("crate", cx, FLOOR, cx + 11, FLOOR + 11, 10, 22, M("8a6a3a"))
        box("crate_band", cx, FLOOR + 5.2, cx + 11, FLOOR + 5.8, 9.6, 10, M("5a4024"), outline=False)
    box("worklamp", 100, 70, 107, 76, BACK - 4, BACK, M("2c3036"))
    sphere("worklamp_bulb", 2.0, M("ffd890", glow=1.6), (103.5, BACK - 4, 69), outline=False, seg=10)


def cooling(level):
    fans = min(1 + level // 2, 3)
    for f in range(fans):
        cx, cz = 36.0 + f * 50, FLOOR + 38
        torus("fan_ring", 21, 2.2, M("33474f"), (cx, BACK - 6, cz), rot=(math.pi / 2, 0, 0), outline=True)
        ycyl("fan_back", 20, 2, M("0f1e24", ao=0.0), cx, cz, BACK - 3, outline=False, seg=32)
        for k in range(8):
            a = k * math.pi / 4
            box("strut", cx + math.cos(a) * 19 - 0.5, cz + math.sin(a) * 19 - 0.5, cx + math.cos(a) * 19 + 0.5, cz + math.sin(a) * 19 + 0.5, BACK - 9, BACK - 6, M("5b6f78"), outline=False)
    px = 40.0 + fans * 50.0
    box("exchanger", px - 4, FLOOR, px + 28, TOP - 14, 16, BACK, M("27424c"))
    for k in range(6):
        box("fin", px - 1.6 + k * 5, FLOOR + 4, px - 0.4 + k * 5, TOP - 18, 15, 16, M("5f8a96"), outline=False)
    for k in range(3):
        zcyl("coolant", 1.5, TOP - 15, TOP - 9, px + 4 + k * 9, 20, M("9fd4e0"))
    box("console", W - 46, FLOOR, W - 14, FLOOR + 30, 12, 26, M("2c3a40"))
    box("screen", W - 43, FLOOR + 16, W - 17, FLOOR + 27, 11.6, 12, M("0f2a2e", ao=0.0), outline=False)
    torus("gauge", 4.6, 0.5, M("cfe0e6", ao=0.0), (W - 31, 11.5, FLOOR + 8), rot=(math.pi / 2, 0, 0))
    for i in range(min(level + 1, 4)):
        vx = 22.0 + i * 50.0
        box("roofvent", vx, TOP + 19, vx + 36, TOP + 30, 2, 26, M("30343b"))
        for k in range(5):
            box("louver", vx + 3 + k * 6.6, TOP + 21, vx + 6.6 + k * 6.6, TOP + 28, 1.4, 2, M("15181c"), outline=False)


def dronebay(level):
    for x in range(10, int(W) - 10, 22):
        box("stripe", x, FLOOR - 0.1, x + 8, FLOOR + 0.15, -3, 4, M("d9a33a", ao=0.0), outline=False)
    for p in range(min(level, 3)):
        px = 44.0 + p * 64.0
        box("pad", px - 19, FLOOR, px + 19, FLOOR + 8, 4, 24, M("3a3f45"))
        cylinder("pad_ring", 14, 0.6, M("3fd8c2", glow=0.8), (px, 14, FLOOR + 8.2), outline=False, seg=32)
        cylinder("pad_core", 12, 0.8, M("2c3036"), (px, 14, FLOOR + 8.4), outline=False, seg=32)
    base = (W - 36, TOP - 9)
    box("arm_base", base[0] - 6, base[1] - 3, base[0] + 6, base[1] + 3, 14, 22, M("3a3f45"))
    j = (base[0] + math.sin(0.35) * 26, base[1] - math.cos(0.35) * 26)
    e = (j[0] + math.sin(-0.75) * 20, j[1] - math.cos(-0.75) * 20)
    for (a, b, r) in ((base, j, 2.0), (j, e, 1.7)):
        length = math.dist(a, b)
        ang = math.atan2(b[0] - a[0], b[1] - a[1])
        cylinder("arm", r, length, M("d0943a"), ((a[0] + b[0]) / 2, 18, (a[1] + b[1]) / 2), rot=(0, ang, 0))
    sphere("joint", 3.0, M("3a3f45"), (j[0], 18, j[1]), seg=12)
    box("monitor", 14, 78, 42, 100, BACK - 3, BACK, M("101820"))
    torus("radar", 8, 0.35, M("1f6a5e", ao=0.0), (28, BACK - 3.2, 89), rot=(math.pi / 2, 0, 0))
    box("crate_a", W - 72, FLOOR, W - 57, FLOOR + 22, 12, 24, M("6a4e34"))
    box("crate_a_top", W - 72, FLOOR + 19.5, W - 57, FLOOR + 22, 11.6, 24, M("e9b04a"), outline=False)
    box("crate_b", W - 88, FLOOR, W - 74, FLOOR + 12, 12, 24, M("6a4e34"))
    # Roof hatch rails.
    box("hatch_frame", 68, TOP + 19, 164, TOP + 23, 2, 26, M("30343b"))
    for k, x in enumerate((74, 116)):
        box("hatch", x, TOP + 23, x + 42, TOP + 28.5, 2, 26, M("3d424a"))
        for s in range(4):
            box("hatch_stripe", x + 4 + s * 9, TOP + 24, x + 8 + s * 9, TOP + 27.5, 1.6, 2, M("d9a33a", ao=0.0), outline=False)


def roof_extra(kind):
    if kind == "greenhouse":
        for i in range(3):
            gx = 26.0 + i * 64.0
            prism("skylight", [(gx, TOP + 19), (gx + 6, TOP + 31), (gx + 42, TOP + 31), (gx + 48, TOP + 19)], 2, 26, M("2f5a48"))
            prism("glass", [(gx + 3, TOP + 19.5), (gx + 8, TOP + 29), (gx + 40, TOP + 29), (gx + 45, TOP + 19.5)], 1.2, 2, M("8cf0c0", glow=0.7), outline=False)
    elif kind == "recycler":
        box("roof_tank", 38, TOP + 19, 68, TOP + 39, 4, 24, M("30343b"), bevel=7)
        box("roof_box", 150, TOP + 19, 202, TOP + 28, 4, 24, M("30343b"))
        xcyl("roof_pipe", 1.2, 68, 150, TOP + 25, 10, M(METAL))
    elif kind in ("quarters", "workshop"):
        box("roof_a", 30, TOP + 19, 62, TOP + 27, 4, 24, M("30343b"))
        box("roof_b", 168, TOP + 19, 194, TOP + 26, 4, 24, M("30343b"))
        zcyl("chimney", 1.6, TOP + 27, TOP + 33, 46, 10, M("3a3f45"))


BUILDERS = {"quarters": quarters, "greenhouse": greenhouse, "recycler": recycler, "workshop": workshop, "cooling": cooling, "dronebay": dronebay}


# ---------------------------------------------------------------- locomotive and parts

def locomotive():
    """Modern armored diesel-electric: streamlined nose cab, side grilles, roof radiators.
    Trucks and wheels are separate sprites so they can turn; the cab window is a cutaway."""
    body = M("2a2f36")
    dark = M(HULL_DARK)
    plate = M("343a42")
    orange = M("e0782e", light=1.2)
    glass = M("3fa8b8", light=1.3, ao=0.0)
    # Interior seen through the cab window.
    box("cab_inside", 24, 80, 68, 128, 22, 24, M("23403e", ao=0.0), outline=False)
    box("console", 26, 80, 46, 92, 16, 22, M("1a2228"))
    box("console_screen", 28, 88, 44, 91.6, 15.6, 16, M("3fd8c2", glow=1.0), outline=False)
    box("cab_floor", 24, 76, 68, 80, -4, 24, M("43362b"))
    # Streamlined nose (front of the cab), shell around the window, long hood behind.
    nose = [(-24, 26), (-26, 46), (-18, 72), (2, 100), (18, 128), (30, 136), (24, 136), (24, 26)]
    prism("nose", nose, -6, 30, body)
    box("cab_low", 24, 26, 68, 80, -6, 30, body)
    box("cab_top", 22, 128, 70, 136, -6, 30, body)
    box("cab_rear", 66, 26, 74, 136, -6, 30, body)
    box("hood", 72, 26, 202, 128, -6, 30, body, bevel=4)
    box("roof", 20, 128, 204, 137, -7, 31, plate, bevel=4)
    # Windshield along the slope plus the cutaway frame.
    prism("windshield", [(2, 100), (18, 128), (24, 128), (24, 100)], -6.6, -6.0, glass, outline=False)
    prism("windshield_glint", [(9, 104), (19, 124), (21, 124), (11, 104)], -6.9, -6.6, M("ffffff", glow=0.45), outline=False)
    box("nose_panel", -24, 30, 22, 44, -6.6, -6.0, M("23282e"), outline=False)
    for x0, z0, x1, z1 in ((24, 126, 70, 128), (24, 78, 70, 80), (22, 78, 24, 128), (68, 78, 70, 128)):
        box("window_frame", x0, z0, x1, z1, -6.8, -5.6, M("b08a45"), outline=False)
    # Brand stripe, number, armour plates with rivets.
    box("stripe", -16, 60, 202, 66, -6.8, -6.0, orange, outline=False)
    box("stripe_thin", -10, 54, 202, 55.5, -6.8, -6.0, M("f0b84a", ao=0.0), outline=False)
    text("RH-01", "RH-01", 9, M("e9e4d8", ao=0.0), (114, -6.9, 88))
    for x0 in (76, 128):
        box("armor", x0, 30, x0 + 48, 52, -7.2, -6.2, plate)
        for x in range(x0 + 4, x0 + 46, 7):
            for z in (33, 49):
                sphere("rivet", 0.6, M("737985", ao=0.0), (x, -7.4, z), outline=False, seg=8)
    # Side grilles.
    for x0 in (138, 168):
        box("grille", x0, 74, x0 + 26, 112, -6.6, -6.0, M("1c2026"))
        for k in range(9):
            box("louver", x0 + 1.5, 76 + k * 4, x0 + 24.5, 77.4 + k * 4, -7.0, -6.6, M("4a515a", ao=0.0), outline=False)
    box("door", 78, 70, 90, 118, -6.6, -6.0, M("23282e"))
    box("door_handle", 87, 92, 88.4, 98, -7.0, -6.6, M("c9ccd2"), outline=False)
    # Lights: LED headlight cluster, marker lights, roof light bar.
    box("headlight_housing", -24, 50, -16, 58, -7, 4, M("1c1f24"))
    ycyl("headlight", 2.8, 1.0, M("fff4d0", glow=2.0), -20, 54, -7.6, outline=False)
    ycyl("marker", 1.4, 1.0, M("ff4a30", glow=1.6), -21, 40, -6.8, outline=False)
    box("lightbar", 20, 137, 50, 140, 2, 24, M("1c1f24"))
    box("lightbar_glow", 22, 137.5, 48, 139.4, 1.6, 2, M("ffd890", glow=1.4), outline=False)
    # Roof equipment: exhaust stack, radiator fans, AC unit, antenna.
    box("exhaust", 96, 137, 106, 146, 6, 18, M("1c1f24"))
    box("exhaust_cap", 94, 146, 108, 148, 5, 19, M("3a3f45"))
    for cx in (140.0, 170.0):
        C.cylinder("radiator", 11, 4, M("30353d"), (cx, 12, 139))
        C.cylinder("radiator_fan", 9, 1, M("15181c", ao=0.0), (cx, 12, 141.2), outline=False)
    box("ac_unit", 110, 137, 128, 143, 4, 22, M("3a3f45"))
    C.zcyl("antenna", 0.5, 137, 156, 60, 10, M("8a8f96"), outline=False)
    # Frame, fuel tank, plow.
    box("frame", -14, 22, 202, 28, -6, 30, dark)
    box("frame_trim", -14, 27.2, 202, 28, -6.4, 30, M(TRIM), outline=False)
    box("fuel_tank", 70, 8, 126, 22, -2, 26, M("30353d"), bevel=4)
    for k in range(6):
        box("tank_hazard", 74 + k * 8.5, 13, 78 + k * 8.5, 17, -2.6, -2.0, M("d9a33a", ao=0.0), outline=False)
    prism("plow", [(-34, 26), (-6, 26), (-6, 2), (-22, 2)], -8, 28, M("2c2f34"))
    for k in range(4):
        prism("plow_stripe", [(-31 + k * 6, 25), (-27 + k * 6, 25), (-17 + k * 6, 3), (-21 + k * 6, 3)], -8.6, -8.0, M("e9b04a", ao=0.0), outline=False)
    for bx in (40.0, 160.0):
        box("bolster", bx - 12, 18, bx + 12, 22, -4, 26, M("2b2e34"))


def bogie(axles, spacing, r):
    """Slim side frame at hub height with axle boxes, links up to a bolster beam.
    Drawn in front of the turning wheels so each wheel is visibly mounted."""
    half = spacing * (axles - 1) / 2 + 3
    frame = M("2b2e34")
    box("sideframe", -half, r - 1.2, half, r + 1.6, -10, -7, frame, bevel=0.8)
    box("bolster_beam", -half + 4, r + 7, half - 4, r + 11, -10, -7, frame, bevel=1.0)
    for k in range(axles):
        x = -spacing * (axles - 1) / 2 + k * spacing
        box("axlebox", x - 2.6, r - 2.6, x + 2.6, r + 2.6, -11, -7, M("3a3f45"), bevel=0.8)
        C.ycyl("axle_cap", 1.4, 1.0, M("b08a45"), x, r, -11.4)
        box("link", x - 0.9, r + 1.6, x + 0.9, r + 7, -10, -7.6, M("4a4f56"), outline=False)
        C.zcyl("spring", 1.3, r + 2.6, r + 7, x + 3.6, -9, M("8a8f96"))


def wheel(r, big):
    ycyl("flange", r + 0.6, 1.2, M("1c1e22"), 0, 0, 1.6, seg=40)
    ycyl("tyre", r, 4, M("2a2c31"), 0, 0, 0, seg=40)
    torus("rim", r - 1.0, 0.7, M("b08a45" if big else "4a4d55"), (0, -2.2, 0), rot=(math.pi / 2, 0, 0), seg_u=40)
    spokes = 8 if big else 6
    for k in range(spokes):
        a = k * math.pi / spokes
        box("spoke", -0.55, -(r - 1.6), 0.55, r - 1.6, -2.4, -1.8, M("44474f"), outline=False).rotation_euler = (0, a, 0)
    if big:
        cw = prism("counterweight", [(math.cos(a) * (r - 2.2), math.sin(a) * (r - 2.2)) for a in [math.pi + (i - 4) * 0.22 for i in range(9)]] + [(-r * 0.35, 0)],
                   -2.8, -2.2, M("3a3d44"), outline=False)
    ycyl("hub", 2.6 if big else 2.0, 5, M("b08a45"), 0, 0, -0.5)
    ycyl("axle", 0.9, 5.6, M("3a2a18"), 0, 0, -0.8, outline=False)


def fan_rotor():
    for k in range(5):
        a = k * 2 * math.pi / 5
        prism("blade", [(0, 0), (math.cos(a) * 18, math.sin(a) * 18), (math.cos(a + 0.55) * 16, math.sin(a + 0.55) * 16)], -0.6, 0.6, M("8cc4d0"))
    ycyl("hub", 4.2, 3, M("b08a45"), 0, 0, -1)


def drone(crate):
    box("body", -7, -3.2, 7, 3.2, -3, 3, M("3d434c"), bevel=2.4)
    box("stripe", -5, 1.8, 5, 3.4, -3.3, -2.8, M("c8923a", ao=0.0), outline=False)
    sphere("eye", 1.3, M("3fd8c2", glow=1.6), (4.4, -3.2, -0.6), outline=False, seg=10)
    for side in (-1, 1):
        hub = (side * 10, 4)
        length = math.dist((side * 5, 1), hub)
        cylinder("arm", 0.7, length, M("2a2c31"), ((side * 5 + hub[0]) / 2, 0, (1 + hub[1]) / 2), rot=(0, math.atan2(hub[0] - side * 5, hub[1] - 1), 0))
        zcyl("mast", 0.6, 4, 5.6, hub[0], 0, M("2a2c31"), outline=False)
        cylinder("rotor", 8, 0.4, M("d8e6f0", ao=0.0, light=1.0), (hub[0], 0, 6.0), outline=False, seg=32)
    for side in (-1, 1):
        box("leg", side * 4 - 0.4, -5, side * 4 + 0.4, -3, -0.4, 0.4, M("2a2c31"), outline=False)
    if crate:
        zcyl("cable", 0.35, -6, -3, 0, 0, M("2a2c31"), outline=False)
        box("crate", -5, -13, 5, -6, -4, 4, M("8a6a3a"))
        box("crate_band", -5, -10.5, 5, -9.3, -4.3, 4.3, M("e9b04a", ao=0.0), outline=False)


# ---------------------------------------------------------------- main

def job(name):
    return not ONLY or name in ONLY


if __name__ == "__main__":
    C.OUTLINE = 0.55
    sc, cam = C.setup_scene()
    for kind, build in BUILDERS.items():
        for level in range(1, 6):
            name = "carriage_%s_%d" % (kind, level)
            if not job(name) and not job(kind):
                continue
            C.clear_objects()
            shell(kind, level)
            roof_extra(kind)
            build(level)
            C.render_region(sc, cam, -4, 236, 0, 164, PX, os.path.join(OUT, name + ".png"))
            print("RENDERED", name)
    parts = {
        "locomotive": (locomotive, (-36, 210, 0, 164), PX),
        "wheel": (lambda: wheel(9.0, False), (-10.5, 10.5, -10.5, 10.5), 8.0),
        "bogie2": (lambda: bogie(2, 28, 9.0), (-28, 28, 0, 24), 8.0),
        "truck3": (lambda: bogie(3, 17, 8.0), (-30, 30, 0, 24), 8.0),
        "fan": (fan_rotor, (-19, 19, -19, 19), 8.0),
        "drone": (lambda: drone(False), (-19, 19, -14, 14), 8.0),
        "drone_crate": (lambda: drone(True), (-19, 19, -14, 14), 8.0),
    }
    for name, (build, region, px) in parts.items():
        if not job(name):
            continue
        C.clear_objects()
        build()
        C.render_region(sc, cam, region[0], region[1], region[2], region[3], px, os.path.join(OUT, name + ".png"))
        print("RENDERED", name)
    print("DONE")

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
HULL2 = "4e5864"   # level 6+: brushed steel
TEAL = "33c2b0"    # level 6+: trim stripe
GOLD = "e8c060"    # level 9+: trim
WALLS = {"quarters": "35514f", "greenhouse": "245a48", "recycler": "1f4c64", "workshop": "2f5452", "cooling": "1d5260", "dronebay": "235254",
         "cargo": "3c4a40", "medbay": "3f6a72", "lab": "263f58", "condenser": "1b4766"}


def M(hexstr, **kw):
    return toon(hexstr, **kw)


# ---------------------------------------------------------------- shared shell

def shell(kind, level):
    wall = WALLS[kind]
    hull = HULL2 if level >= 6 else HULL
    trim = GOLD if level >= 9 else TRIM
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
        box("bulkhead", sx, 20, sx + 7, TOP, -5, BACK + 3, M(hull))
        box("door", sx + 1.3, 32, sx + 5.7, 100, -5.6, -4.8, M("1d2025"), outline=False)
        ycyl("port_rim", 2.4, 1.0, M("3a3f45"), sx + 3.5, 88, -5.8)
        ycyl("porthole", 1.7, 1.2, M("ffad52", glow=1.3), sx + 3.5, 88, -6.0, outline=False)
        for z in range(36, 116, 12):
            sphere("rivet", 0.55, M("737985", ao=0.0), (sx + 3.5, -5.2, z), outline=False, seg=8)
    # Brass rim around the cutaway opening.
    for x0, z0, x1, z1 in ((7, TOP - 1, W - 7, TOP), (7, FLOOR - 1, W - 7, FLOOR)):
        box("rim", x0, z0, x1, z1, -5, -3.5, M(trim), outline=False)
    # Roof canopy with rivets and trim.
    box("roof", -1, TOP, W + 1, TOP + 19, -6, BACK + 4, M(hull), bevel=6.5)
    box("trim", 0, TOP, W, TOP + 1.6, -6.4, BACK + 4, M(trim), outline=False)
    for x in range(8, int(W) - 4, 12):
        sphere("rivet", 0.75, M("737985", ao=0.0), (x, -6.6, TOP + 7.5), outline=False, seg=8)
    # Underframe, skirt, equipment boxes and bogie frames.
    box("frame", 0, 20, W, 26, -5, BACK + 3, M(HULL_DARK))
    box("frame_trim", 0, 25.2, W, 26, -5.4, BACK + 3, M(trim), outline=False)
    box("skirt", 0, 17, W, 20, -3, BACK, M("121417"), outline=False)
    for bx in (72.0, 126.0):
        box("equip", bx, 10.5, bx + 34, 19.5, -3, 10, M("2a2e34"))
        for k in range(4):
            box("hazard", bx + 3 + k * 8, 12, bx + 7 + k * 8, 14.5, -3.4, -2.9, M("d9a33a", ao=0.0), outline=False)
    for bx in (32.0, W - 32.0):  # bolster pads the bogies (rendered separately) bolt onto
        box("bolster", bx - 10, 16, bx + 10, 20, -4, BACK, M("2b2e34"))
    # Level pips on the roof (teal past level 5).
    for i in range(level):
        ycyl("pip", 1.6, 1.0, M("f0b84a" if i < 5 else "5fe8d8", glow=1.2), W - 14 - i * 6, TOP + 11.5, -6.8)
    if level >= 6:
        tier2(kind, level)


# ---------------------------------------------------------------- tier 2 (levels 6-10)

def g_antenna(x, level):
    box("ant_base", x - 2.5, TOP + 19, x + 2.5, TOP + 21.5, 10, 16, M("3a3f45"))
    zcyl("antenna", 0.55, TOP + 21.5, TOP + 38, x, 13, M("aab2ba"))
    for z, half in ((TOP + 29, 2.6), (TOP + 34, 1.8)):
        xcyl("ant_bar", 0.35, x - half, x + half, z, 13, M("aab2ba"), outline=False)
    sphere("ant_tip", 1.1, M("ff6a3a", glow=1.6) if level >= 8 else M("c83a2a"), (x, 12, TOP + 38.6), seg=10)


def g_ac(x, level):
    box("ac", x - 7, TOP + 19, x + 7, TOP + 27, 6, 22, M("5f6873"))
    ycyl("ac_fan", 2.8, 0.6, M("1a1d22", ao=0.0), x - 1.5, TOP + 23, 5.6, outline=False)
    torus("ac_grille", 2.8, 0.4, M("9aa3ac"), (x - 1.5, 5.3, TOP + 23), rot=(math.pi / 2, 0, 0))
    for k in range(3):
        box("ac_slot", x + 3, TOP + 21 + k * 2, x + 6, TOP + 21.6 + k * 2, 5.6, 6, M("2a2e34", ao=0.0), outline=False)


def g_solar(x, level, w=36, z0=TOP + 24):
    for lx in (x - w / 2 + 4, x + w / 2 - 6):
        box("solar_leg", lx, TOP + 19, lx + 2, z0, 14, 18, M("3a3f45"))
    box("solar_frame", x - w / 2, z0, x + w / 2, z0 + 8, 6, 24, M("aab4be"))
    box("solar_cells", x - w / 2 + 1.2, z0 + 1.2, x + w / 2 - 1.2, z0 + 6.8, 5.4, 6, M("24467e", ao=0.0), outline=False)
    n = int(w / 6)
    for k in range(1, n):
        lx = x - w / 2 + k * w / n
        box("solar_line", lx - 0.25, z0 + 1.2, lx + 0.25, z0 + 6.8, 5.2, 5.4, M("7aa8e8", ao=0.0), outline=False)
    box("solar_line", x - w / 2 + 1.2, z0 + 3.75, x + w / 2 - 1.2, z0 + 4.25, 5.2, 5.4, M("7aa8e8", ao=0.0), outline=False)


def g_dish(x, level):
    box("dish_base", x - 3, TOP + 19, x + 3, TOP + 21.5, 10, 16, M("3a3f45"))
    zcyl("dish_mast", 0.9, TOP + 21.5, TOP + 26, x, 13, M("6f7882"))
    sphere("dish", 4.6, M("d8dde2"), (x, 13, TOP + 29), scale=(1, 1, 0.38), rot=(0, -0.55, 0), seg=20)
    cylinder("dish_feed", 0.4, 5, M("6f7882"), (x + 1.5, 12, TOP + 31.5), rot=(0, -0.55, 0), outline=False)


def g_tank(x, level):
    for lx in (x - 5, x + 3):
        box("tank_leg", lx, TOP + 19, lx + 2, TOP + 22, 12, 18, M("3a3f45"))
    xcyl("roof_tank", 3.8, x - 7, x + 7, TOP + 25.5, 15, M("6a8a96"))
    box("tank_band", x - 0.6, TOP + 21.5, x + 0.6, TOP + 29.5, 10.8, 11.2, M(TRIM), outline=False)


GEAR_FN = {"antenna": g_antenna, "ac": g_ac, "solar": g_solar, "dish": g_dish, "tank": g_tank}
# (min level, item, centre x, extra kwargs): roof gear placed clear of each type's roof_extra.
_HOME = [(7, "antenna", 22, {}), (7, "ac", 206, {}), (8, "solar", 86, {}), (9, "solar", 144, {}), (10, "dish", 115, {})]
GEAR = {
    "quarters": _HOME,
    "workshop": _HOME,
    "greenhouse": [(7, "antenna", 19, {}), (7, "ac", 211, {}), (8, "dish", 146, {}), (9, "tank", 82, {})],
    "recycler": [(7, "antenna", 17, {}), (7, "ac", 211, {}), (8, "solar", 89, {"w": 34, "z0": TOP + 28}),
                 (9, "solar", 127, {"w": 34, "z0": TOP + 28}), (10, "dish", 29, {})],
    "cooling": [(7, "antenna", 14, {}), (7, "ac", 216, {}), (8, "dish", 65, {}), (9, "antenna", 165, {}), (10, "dish", 115, {})],
    "dronebay": [(7, "antenna", 12, {}), (7, "ac", 212, {}), (8, "solar", 34, {}), (9, "solar", 186, {}), (10, "dish", 60, {})],
    "cargo": [(7, "antenna", 106, {}), (7, "ac", 212, {}), (8, "solar", 32, {}), (9, "solar", 190, {"w": 24}), (10, "dish", 122, {})],
    "medbay": [(7, "antenna", 18, {}), (7, "ac", 210, {}), (8, "solar", 77, {"w": 34}), (9, "solar", 160, {}), (10, "dish", 190, {})],
    "lab": [(7, "ac", 30, {}), (7, "antenna", 197, {}), (8, "solar", 94, {"w": 34}), (9, "solar", 130, {"w": 34}), (10, "dish", 213, {})],
    "condenser": [(7, "antenna", 16, {}), (7, "ac", 214, {}), (8, "tank", 102, {}), (9, "antenna", 182, {}), (10, "dish", 195, {})],
}


def tier2(kind, level):
    """Second-tier look: steel hull with a teal stripe (6+), roof gear (7+), warm marker
    lights (8+), gold trim and an emblem plate (9+), winged emblem and gold caps (10)."""
    teal = M(TEAL, light=1.25)
    box("t2_stripe", 0.5, TOP + 3.2, W - 0.5, TOP + 4.6, -6.6, BACK + 4, teal, outline=False)
    box("t2_frame_stripe", 0, 22, W, 23.2, -5.4, BACK + 3, teal, outline=False)
    for sx in (0.0, W - 7):
        box("t2_bulk_stripe", sx + 0.8, 34, sx + 1.6, TOP - 4, -5.6, -5.0, teal, outline=False)
    for lv, item, x, kw in GEAR.get(kind, ()):
        if level >= lv:
            GEAR_FN[item](x, level, **kw)
    if level >= 8:
        for sx in (0.0, W - 7):
            for z in (TOP - 7, 30):
                box("marker_box", sx + 1.4, z - 2.4, sx + 5.6, z + 2.4, -6.4, -5, M("23272d"))
                ycyl("marker", 1.5, 1.0, M("ffb347", glow=1.7), sx + 3.5, z, -6.9, outline=False)
    if level >= 9:
        gold = M(GOLD, light=1.3)
        cx = W / 2
        box("emblem_rim", cx - 13, TOP + 5.2, cx + 13, TOP + 16, -7.4, -6.4, gold)
        box("emblem_plate", cx - 11.6, TOP + 6.4, cx + 11.6, TOP + 14.8, -7.9, -7.4, M("1e242c", ao=0.0), outline=False)
        torus("emblem_wheel", 3.0, 0.6, gold, (cx, -8.2, TOP + 10.6), rot=(math.pi / 2, 0, 0))
        for k in range(4):
            a = k * math.pi / 4
            box("emblem_spoke", cx - 0.35, TOP + 10.6 - 2.8, cx + 0.35, TOP + 10.6 + 2.8, -8.3, -8.0, gold, outline=False).rotation_euler = (0, a, 0)
        ycyl("emblem_hub", 1.0, 0.6, gold, cx, TOP + 10.6, -8.4, outline=False)
        for s in (-1, 1):
            prism("emblem_bar", [(cx + s * 4.6, TOP + 10.0), (cx + s * 10, TOP + 10.0), (cx + s * 10, TOP + 11.2), (cx + s * 4.6, TOP + 11.2)], -8.3, -7.9, gold, outline=False)
    if level >= 10:
        gold = M(GOLD, light=1.3)
        cx = W / 2
        for s in (-1, 1):  # swept feathers either side of the plate
            for k in range(3):
                xi, zt, ln, rise = cx + s * 12.6, TOP + 15.2 - k * 3.0, 13.0 - k * 3.0, 2.6 - k * 0.7
                prism("wing", [(xi, zt - 2.1), (xi, zt), (xi + s * ln, zt + rise), (xi + s * (ln - 3.0), zt + rise - 2.1)], -7.6, -6.6, gold)
        for sx in (0.0, W - 7):
            box("gold_cap", sx - 0.4, TOP - 3, sx + 7.4, TOP, -5.6, BACK + 3, gold, outline=False)
            torus("port_gold", 2.5, 0.45, gold, (sx + 3.5, -6.2, 88), rot=(math.pi / 2, 0, 0))


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
    if level < 10:
        cylinder("pot", 3.6, 6, M("9a5a3a"), (lx + 10, 22, FLOOR + 47), r2=4.2)
        leaf_cluster(lx + 10, FLOOR + 49, 22, 6, ["4caf50", "5cbf5a", "2f7a3a"])
    else:  # aquarium on the lockers
        box("tank_stand", lx, FLOOR + 44, lx + 21, FLOOR + 46, 18, 28, M("3a3f45"))
        box("aquarium", lx + 1, FLOOR + 46, lx + 20, FLOOR + 58, 19, 27, M("3fa8d8", glow=0.55), outline=False)
        box("aq_frame", lx + 0.5, FLOOR + 57.4, lx + 20.5, FLOOR + 58.6, 18.6, 27.4, M("2a2e34"))
        for k, (fx, fz, c) in enumerate(((lx + 6, FLOOR + 52, "ffa040"), (lx + 14, FLOOR + 49.5, "ffd060"))):
            sphere("fish", 1.4, M(c, ao=0.0), (fx, 18.4, fz), scale=(1.5, 1, 0.9), outline=False, seg=10)
            prism("fin", [(fx - 2, fz), (fx - 3.6, fz + 1.3), (fx - 3.6, fz - 1.3)], 18.2, 18.6, M(c, ao=0.0), outline=False)
        for k in range(3):
            sphere("weed", 1.1, M("4caf50", ao=0.0), (lx + 3 + k * 0.6, 18.6, FLOOR + 47.5 + k * 2), scale=(0.7, 1, 1.6), outline=False, seg=8)
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
    # Tier 2: reading lamps (6+), bookshelf (7+), wall clock (8+), quilts and a gold-trimmed rug (9+).
    if level >= 6:
        for b in range(bunks):
            for tier in range(2):
                bz = FLOOR + 14 + tier * 26
                lx0 = 14.0 + b * 40.0 + 7
                box("lamp_arm", lx0 - 0.5, bz + 10, lx0 + 0.5, bz + 15, BACK - 2, BACK, M("a07a3c"), outline=False)
                sphere("read_lamp", 1.5, M("ffd890", glow=1.5), (lx0 + 1.2, BACK - 2.6, bz + 10), outline=False, seg=10)
    if level >= 7:
        box("bookshelf", 191, 70, 207, 100, BACK - 6, BACK, M("6a5038"))
        for z in (71.5, 85.5):
            box("book_back", 192, z, 206, z + 12.5, BACK - 5.6, BACK - 1, M("3a2a1e"), outline=False)
            for k in range(6):
                col = ["8a3a2a", "2f5a7a", "5f7a3a", "b08a45", "6a4a7a", "c8b088"][(k + int(z)) % 6]
                box("book", 192.6 + k * 2.2, z, 194.4 + k * 2.2, z + 9.5 + (k * 7 % 3), BACK - 6.4, BACK - 1.5, M(col), outline=False)
            box("shelf_board", 191, z - 1.5, 207, z, BACK - 6.4, BACK, M("7a5a3e"), outline=False)
    if level >= 8:
        ycyl("clock", 4.2, 1.2, M("e8e2d2"), 146, 99, BACK - 1.2)
        torus("clock_rim", 4.2, 0.5, M("a07a3c"), (146, BACK - 1.9, 99), rot=(math.pi / 2, 0, 0))
        box("hand_h", 145.6, 99, 146.4, 101.8, BACK - 2.1, BACK - 1.9, M("2a2018", ao=0.0), outline=False)
        box("hand_m", 146, 98.6, 149, 99.4, BACK - 2.2, BACK - 2.0, M("2a2018", ao=0.0), outline=False)
    if level >= 9:
        for b in range(bunks):
            for tier in range(2):
                bz = FLOOR + 14 + tier * 26
                bx = 14.0 + b * 40.0
                for k in range(3):
                    box("quilt", bx + 14 + k * 6.5, bz + 0.6, bx + 17 + k * 6.5, bz + 4.6, 8.6, 25.4, M(["e0b050", "d8d0b8", "a8443a"][(k + b + tier) % 3]), outline=False)
        box("rug_border", 146, FLOOR - 0.04, 206, FLOOR + 0.35, 3.6, 4.2, M(GOLD), outline=False)


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
                fruit = level >= 3 and (k + tier + r) % (2 if level >= 9 else 3) == 0
                size = 5.0 + min(level, 7) * 0.45
                leaf_cluster(rx + 5.5 + k * 9.5, tz + 3, 14, size, greens, fruit)
                if level >= 7 and not fruit and (k + tier + r) % 3 == 1:  # blossoms
                    for j in range(2):
                        sphere("flower", 1.1, M(["ffd84a", "ff8ad0"][(k + r + j) % 2]), (rx + 4 + k * 9.5 + j * 3.2, 9, tz + 3 + size * 1.25 - j * 1.5), seg=10)
                        sphere("flower_eye", 0.45, M("c86a20", ao=0.0), (rx + 4 + k * 9.5 + j * 3.2, 7.9, tz + 3 + size * 1.25 - j * 1.5), outline=False, seg=6)
            if level >= 6:  # glowing nutrient line along each tray
                xcyl("nutrient", 0.35, rx + 0.5, rx + rw - 10.5, tz + 2.3, 8.7, M("5fe8d8", glow=0.9), outline=False)
            if level >= 8:  # sensor tag per tier
                box("sensor", rx + rw - 14, tz + 8, rx + rw - 11.5, tz + 12, 12.6, 14, M("2a2e34"))
                ycyl("sensor_led", 0.5, 0.4, M("ffb347", glow=1.6), rx + rw - 12.75, tz + 10.8, 12.4, outline=False, seg=8)
    for k in range(5):
        vx = 30.0 + k * 44.0
        for i in range(7):
            sphere("vine", 1.4, M("3f8f40"), (vx + math.sin(i * 0.9 + k) * 2.0, BACK - 4, TOP - 10 - i * 4), scale=(1.0, 0.6, 1.4), outline=False, seg=8)
    xcyl("irrigation", 0.8, 12, W - 12, TOP - 14, 8, M("4f86b0"))
    if level >= 10:  # misting nozzles on the irrigation line
        for k in range(9):
            nx = 20.0 + k * 24.0
            zcyl("nozzle", 0.6, TOP - 17, TOP - 14, nx, 8, M("8a939c"), outline=False)
            for j in range(3):
                sphere("mist", 0.45, M("cff4ff", glow=0.8), (nx + (j - 1) * 1.4, 7.5, TOP - 18.5 - j * 1.3), outline=False, seg=6)


def recycler(level):
    tanks = min(1 + level // 2, 3)
    for k in range(tanks):
        tx = 18.0 + k * 60.0
        cx = tx + 20
        zcyl("tank_back", 19, FLOOR + 7, FLOOR + 67, cx, 16, M("9fd4f0", ao=0.0), outline=False, seg=32)
        zcyl("water", 18, FLOOR + 7, FLOOR + 40, cx, 14, M("2a8ad8" if level < 9 else "3aa8f0", light=1.25, ao=0.0), outline=False, seg=32)
        box("glint", tx + 5, FLOOR + 10, tx + 7.4, FLOOR + 62, -4.5, -4, M("ffffff", glow=0.5), outline=False)
        box("glint2", tx + 9, FLOOR + 10, tx + 10, FLOOR + 62, -4.5, -4, M("cfefff", glow=0.4), outline=False)
        zcyl("cap_top", 21, FLOOR + 66, FLOOR + 71, cx, 16, M(METAL), seg=32)
        zcyl("cap_bot", 21, FLOOR, FLOOR + 7, cx, 16, M(METAL), seg=32)
        zcyl("band", 20.5, FLOOR + 37, FLOOR + 39.4, cx, 16, M(shade(METAL, 0.85) if level < 10 else GOLD), outline=False, seg=32)
        zcyl("feed", 1.5, FLOOR + 71, TOP - 9, cx, 20, M("6a5430"))
        if level >= 7:  # level gauge on the cap
            ycyl("gauge", 2.4, 0.8, M("e8e2d2"), cx + 11, FLOOR + 68.5, -5.4)
            box("needle", cx + 10.6, FLOOR + 68.3, cx + 12.6, FLOOR + 68.9, -6.0, -5.8, M("c83a2a", ao=0.0), outline=False)
    if level >= 6:  # manifold between tanks with valve wheels
        xcyl("manifold", 1.8, 30, 18.0 + (tanks - 1) * 60 + 28, FLOOR + 54, 27, M("6a5430"))
        for k in range(tanks - 1):
            gx = 18.0 + k * 60 + 50
            zcyl("valve_stem", 0.7, FLOOR + 54, FLOOR + 59, gx, 24, M("8a939c"), outline=False)
            torus("valve", 3.0, 0.7, M("c83a2a"), (gx, 23, FLOOR + 60), rot=(math.pi / 2, 0, 0))
    fx = 22.0 + tanks * 60.0
    for k in range(2):
        zcyl("filter", 5, FLOOR, FLOOR + 46, fx + k * 13 + 5, 18, M("c8d0d6"))
        zcyl("filter_band", 5.2, FLOOR + 28, FLOOR + 31, fx + k * 13 + 5, 18, M("4f86b0"), outline=False)
    box("panel", W - 44, 70, W - 14, 96, BACK - 3, BACK, M("1a2228"))
    box("pump", W - 40, FLOOR, W - 18, FLOOR + 18, 16, 26, M("3a5866"))
    ycyl("pump_wheel", 5, 1.2, M(METAL), W - 29, FLOOR + 10, 15.4)
    xcyl("pump_pipe", 1.6, W - 60, W - 40, FLOOR + 14, 20, M("6f7882"))
    if level >= 8:  # UV purifier strip over the control panel
        box("uv_housing", W - 44, 97, W - 14, 101, BACK - 3, BACK, M("2a2e34"))
        box("uv_tube", W - 42, 97.6, W - 16, 99.6, BACK - 3.4, BACK - 3, M("c08aff", glow=1.6), outline=False)


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
    # Tier 2: parts bins (6+), diagnostics screen (7+), gas bottles (8+), chain hoist (9+), robot arm (10).
    if level >= 6:
        box("bin_shelf", 166, 82.5, 214, 84, BACK - 7, BACK, M("5f6b75"))
        for k in range(5):
            bx = 167.5 + k * 9.4
            box("bin", bx, 84, bx + 8, 89.5, BACK - 6.5, BACK - 1, M(["c83a2a", "3f6fb8", "e0b030", "3f8a7a", "c8702a"][k]))
            box("bin_label", bx + 2, 85.2, bx + 6, 86.8, BACK - 6.9, BACK - 6.5, M("e8e2d2", ao=0.0), outline=False)
    if level >= 7:
        box("diag", 86, 82, 116, 100, BACK - 2, BACK, M("1c2228"))
        box("diag_screen", 87.4, 83.4, 114.6, 98.6, BACK - 2.4, BACK - 2, M("0f2a2e", ao=0.0), outline=False)
        torus("diag_gear", 4.2, 0.4, M("3fd8c2", glow=1.3), (96, BACK - 2.5, 91), rot=(math.pi / 2, 0, 0), seg_v=6)
        for k in range(3):
            box("diag_line", 103, 94 - k * 3.4, 112 - k * 2, 94.7 - k * 3.4, BACK - 2.6, BACK - 2.4, M("3fd8c2", glow=1.2), outline=False)
    if level >= 8:
        for k, c in enumerate(("c83a2a", "3f8a5a")):
            gx = 78.5 + k * 6
            zcyl("gas", 2.8, FLOOR, FLOOR + 32, gx, 25, M(c))
            zcyl("gas_top", 2.8, FLOOR + 32, FLOOR + 34.5, gx, 25, M(shade(c, 0.8)), r2=1.4, outline=False)
            zcyl("gas_valve", 0.9, FLOOR + 34.5, FLOOR + 37, gx, 25, M("b08a45"), outline=False)
    if level >= 9:
        box("hoist", 115.5, TOP - 13, 122.5, TOP - 9, 12, 18, M("d0943a"))
        zcyl("hoist_chain", 0.45, 76, TOP - 13, 119, 14, M("8a8f96"), outline=False)
        torus("hoist_hook", 2.0, 0.6, M("8a8f96"), (119, 14, 74), rot=(math.pi / 2, 0, 0))
    if level >= 10:
        base = (93.0, FLOOR + 18)
        box("arm_base", base[0] - 4, base[1], base[0] + 4, base[1] + 3, 12, 20, M("3a3f45"))
        j = (base[0] + 4, base[1] + 22)
        e = (j[0] + 14, j[1] - 9)
        for (a, b, r) in ((base, j, 1.8), (j, e, 1.5)):
            cylinder("arm", r, math.dist(a, b), M("d0943a"), ((a[0] + b[0]) / 2, 16, (a[1] + b[1]) / 2), rot=(0, math.atan2(b[0] - a[0], b[1] - a[1]), 0))
        sphere("joint", 2.6, M("3a3f45"), (j[0], 16, j[1]), seg=12)
        box("welder", e[0] - 1.2, e[1] - 4, e[0] + 1.2, e[1], 15, 17, M("3a3f45"))
        sphere("weld_spark", 1.0, M("fff0a0", glow=2.0), (e[0], 14.5, e[1] - 4.5), outline=False, seg=8)


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
    # Tier 2: floor coolant lines (6+), frost on the fan rings (7+), sight glasses (8+), temp display (9+), cryo tank (10).
    if level >= 6:
        for z, r in ((FLOOR + 4, 1.8), (FLOOR + 9.5, 1.4)):
            xcyl("cool_line", r, 10, px - 4, z, 27, M("5f8a96"))
        for k in range(6):
            sphere("frost", 1.5, M("d8f6ff", ao=0.0), (18 + k * 27, 24.5, FLOOR + 5.6), scale=(2.2, 0.8, 0.7), outline=False, seg=10)
    if level >= 7:
        for f in range(fans):
            cx, cz = 36.0 + f * 50, FLOOR + 38
            for a in (2.2, 2.6, 0.6):
                sphere("rime", 1.4, M("d8f6ff", ao=0.0), (cx + math.cos(a) * 21, BACK - 9, cz + math.sin(a) * 21), scale=(1.4, 0.8, 0.8), outline=False, seg=8)
    if level >= 8:
        for k in range(2):
            gx = px + 3 + k * 10
            box("sight", gx - 1.6, 66, gx + 1.6, 100, 13.6, 15, M("1c2a30"))
            box("sight_glow", gx - 0.9, 67, gx + 0.9, 84 + k * 8, 13.2, 13.6, M("5fe8f0", glow=1.4), outline=False)
    if level >= 9:
        box("temp_panel", 58, 93, 100, 102, BACK - 1.6, BACK, M("1c2228"))
        for k in range(8):
            box("temp_bar", 60.5 + k * 4.8, 94.4, 63.5 + k * 4.8, 95.6 + k * 0.7, BACK - 2, BACK - 1.6, M("5fe8f0" if k < 6 else "ffb347", glow=1.3), outline=False)
    if level >= 10:
        zcyl("cryo", 7, FLOOR, FLOOR + 30, 171, 18, M("aebcc6"), seg=28)
        zcyl("cryo_cap", 7.4, FLOOR + 30, FLOOR + 33, 171, 18, M("5f6b75"), seg=28)
        box("cryo_window", 168.6, FLOOR + 6, 173.4, FLOOR + 26, 10.4, 11, M("8ff4ff", glow=1.2), outline=False)
        for k in range(3):
            sphere("cryo_frost", 1.4, M("ffffff"), (166 + k * 5, 11.5, FLOOR + 33), scale=(1.4, 0.8, 0.7), seg=8)
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
    # Tier 2: charging lines (6+), spare-rotor rack (7+), pad status lights (8+), nav screen (9+), fleet board (10).
    if level >= 6:
        for p in range(min(level, 3)):
            px = 44.0 + p * 64.0
            box("socket", px + 12, 62, px + 18, 70, BACK - 2, BACK, M("2a2e34"))
            ycyl("socket_led", 0.6, 0.4, M("5cff8a", glow=1.5), px + 15, 67.5, BACK - 2.2, outline=False, seg=8)
            zcyl("charge_cable", 0.7, FLOOR + 8, 62, px + 15, 26, M("1c1f24"), outline=False)
    if level >= 7:
        box("rotor_rail", 52, 98, 104, 100, BACK - 2, BACK, M("5f6b75"))
        for k in range(3):
            rx = 60 + k * 16
            zcyl("rotor_peg", 0.5, 94, 98, rx, BACK - 2, M("8a939c"), outline=False)
            sphere("spare_rotor", 6.5, M("d8e6f0"), (rx, BACK - 3, 92), scale=(1, 0.3, 0.16), seg=16)
    if level >= 8:
        for p in range(min(level, 3)):
            px = 44.0 + p * 64.0
            for s in (-1, 1):
                ycyl("pad_light", 1.2, 0.6, M("ffb347", glow=1.6), px + s * 15.5, FLOOR + 4, 3.6, outline=False, seg=10)
    if level >= 9:
        box("nav", 112, 80, 140, 100, BACK - 3, BACK, M("101820"))
        for k in range(3):
            box("nav_grid", 114, 84 + k * 5, 138, 84.4 + k * 5, BACK - 3.3, BACK - 3, M("1f6a5e", ao=0.0), outline=False)
            box("nav_grid", 118 + k * 8, 82, 118.4 + k * 8, 98, BACK - 3.3, BACK - 3, M("1f6a5e", ao=0.0), outline=False)
        for x, z in ((120, 90), (130, 94), (124, 86)):
            sphere("nav_blip", 0.9, M("ffb347", glow=1.5), (x, BACK - 3.5, z), outline=False, seg=8)
    if level >= 10:
        box("fleet_board", 146, 64, 176, 84, BACK - 2, BACK, M("1c2228"))
        for r in range(3):
            for k in range(5):
                ycyl("fleet_led", 0.9, 0.4, M(["5cff8a", "5fe8d8", "ffb347"][r], glow=1.5), 150 + k * 5.4, 79 - r * 6, BACK - 2.2, outline=False, seg=8)
    # Roof hatch rails.
    box("hatch_frame", 68, TOP + 19, 164, TOP + 23, 2, 26, M("30343b"))
    for k, x in enumerate((74, 116)):
        box("hatch", x, TOP + 23, x + 42, TOP + 28.5, 2, 26, M("3d424a"))
        for s in range(4):
            box("hatch_stripe", x + 4 + s * 9, TOP + 24, x + 8 + s * 9, TOP + 27.5, 1.6, 2, M("d9a33a", ao=0.0), outline=False)


def crate(x0, z0, s, col, y0=12, y1=28, kind="wood"):
    if kind == "steel":
        box("container", x0, z0, x0 + s, z0 + s, y0, y1, M(col))
        for k in range(1, 4):
            box("rib", x0 + k * s / 4 - 0.5, z0 + 1, x0 + k * s / 4 + 0.5, z0 + s - 1, y0 - 0.5, y0, M(shade(col, 0.75), ao=0.0), outline=False)
        box("latch", x0 + s / 2 - 1.5, z0 + s / 2 - 1, x0 + s / 2 + 1.5, z0 + s / 2 + 1, y0 - 0.9, y0 - 0.5, M("d9a33a", ao=0.0), outline=False)
        return
    box("crate", x0, z0, x0 + s, z0 + s, y0, y1, M(col))
    band = M(shade(col, 0.68), ao=0.0)
    for z in (z0 + 1.2, z0 + s - 2.4):
        box("crate_band", x0 + 0.6, z, x0 + s - 0.6, z + 1.2, y0 - 0.4, y0, band, outline=False)
    if kind == "vault":
        for x in (x0 + 2.5, x0 + s - 4):
            box("vault_band", x, z0 + 0.6, x + 1.5, z0 + s - 0.6, y0 - 0.7, y0 - 0.3, M(GOLD, light=1.3), outline=False)
        ycyl("vault_lock", 1.6, 0.6, M(GOLD, light=1.3), x0 + s / 2, z0 + s / 2, y0 - 0.6, outline=False)
        return
    cylinder("brace", 0.5, (s - 3) * 1.38, band, (x0 + s / 2, y0 - 0.2, z0 + s / 2), rot=(0, math.pi / 4, 0), outline=False)


def cargo(level):
    # Left: crate pile, filled bottom row first; steel containers past level 5, a gold vault crate at 9+.
    slots = [(12, 0), (29, 0), (46, 0), (63, 0), (20.5, 1), (37.5, 1), (54.5, 1), (29, 2), (46, 2), (37.5, 3)]
    woods = ["8a6a3a", "9a7444", "7a5a32", "a07a46"]
    for i in range(min(2 + level, 10)):
        x, row = slots[i]
        z = FLOOR + row * 16.2
        if level >= 9 and i == 9:
            crate(x, z, 16, "3a3230", kind="vault")
        elif level >= 6 and i in (3, 6, 8):
            crate(x, z, 16, ["3f6f8a", "3f8a7a", "8a4a3a"][(i // 3) % 3], kind="steel")
        else:
            crate(x, z, 16, woods[(i * 3) % 4] if i % 5 != 2 else "c0702e")
            if i % 3 == 0:
                box("label", x + 4, z + 6, x + 12, z + 10, 11.3, 11.7, M("e8dfc4", ao=0.0), outline=False)
    if level >= 3:  # ratchet straps over the lower stack
        for x in (24.0, 58.0):
            box("strap", x, FLOOR, x + 1.6, FLOOR + (32.4 if level >= 5 else 16.2), 11.2, 11.8, M("e0b030", ao=0.0), outline=False)
    # Middle: wall shelving with small stock.
    sx0, sx1 = 88.0, 148.0
    for x in (sx0, (sx0 + sx1) / 2 - 1, sx1 - 2):
        box("upright", x, FLOOR, x + 2, FLOOR + 70, 20, 23, M("5a636e"))
    for z in (FLOOR + 22, FLOOR + 44, FLOOR + 66):
        box("shelf", sx0, z - 1.6, sx1, z, 18, 28, M("6f7882"))
    stock = min(4 + level * 2, 18)
    for i in range(stock):
        tier, k = i // 6, i % 6
        x = sx0 + 4 + k * 9.4 + (1.6 if k >= 3 else 0)
        z = FLOOR + tier * 22
        v = (i * 7 + tier) % 5
        if level >= 10 and tier == 2:
            zcyl("cell", 2.8, z, z + 11, x + 3, 23, M("2f3a44"))
            box("cell_glow", x + 1.2, z + 2.5, x + 4.8, z + 8.5, 20.2, 20.6, M("5fe8d8", glow=1.3), outline=False)
        elif v == 0:
            box("box", x, z, x + 7.5, z + 7, 19, 27, M("b08a5a"))
            box("tape", x + 3.2, z + 0.5, x + 4.3, z + 7, 18.7, 19, M("d8c08a", ao=0.0), outline=False)
        elif v == 1:
            zcyl("drum", 3.2, z, z + 10, x + 3.6, 23, M("3f6a8a"))
            zcyl("drum_ring", 3.35, z + 4.5, z + 5.5, x + 3.6, 23, M("2a4a64"), outline=False)
        elif v == 2:
            sphere("sack", 4.2, M("c8b088"), (x + 3.8, 23, z + 3.2), scale=(1.0, 0.9, 0.78), seg=14)
        elif v == 3:
            box("toolcase", x, z, x + 8, z + 5, 19, 27, M("b83a2a"))
        else:
            for j in range(2):
                zcyl("jar", 1.5, z, z + 5.5, x + 2 + j * 4, 22, M("9fd4f0" if j else "d8b060"))
                zcyl("jar_lid", 1.6, z + 5.5, z + 6.6, x + 2 + j * 4, 22, M("5a636e"), outline=False)
    # Right: strapped gas tanks on a cradle (second one stacked at 6+), barrels in front.
    if level >= 2:
        for t in range(2 if level >= 6 else 1):
            tz = FLOOR + 11 + t * 19.5
            for x in (164.0, 203.0):  # saddles
                box("cradle", x, tz - 11 if t == 0 else tz - 9.6, x + 5, tz - 5, 12, 28, M("3a3f45"))
            xcyl("tank", 8.6, 158, 216, tz, 22, M("c8c0a0" if t == 0 else "8aa8b0"), seg=28)
            for ex in (158.0, 216.0):
                ycyl("tank_cap", 8.6, 1.0, M(shade("c8c0a0" if t == 0 else "8aa8b0", 0.85)), ex, tz, 22, outline=False)
            for x in (172.0, 200.0):
                box("tank_strap", x, tz - 9, x + 2.2, tz + 9, 13, 14, M("e0b030", ao=0.0), outline=False)
            box("tank_label", 182, tz - 2, 192, tz + 2, 13.2, 13.6, M("c83a2a" if t == 0 else "2f7a72", ao=0.0), outline=False)
    barrels = min(1 + level // 2, 4)
    cols = ["a8442a", "3a6a8a", "a8442a", "4a7a3a"]
    for b in range(barrels):
        bx = 214.0 - b * 12.5
        zcyl("barrel", 5.2, FLOOR, FLOOR + 15, bx, 8, M(cols[b]), seg=20)
        for z in (FLOOR + 3, FLOOR + 11.5):
            zcyl("barrel_ring", 5.35, z, z + 0.9, bx, 8, M(shade(cols[b], 0.7)), outline=False, seg=20)
    # Ceiling crane rail and hook (5+); the hook carries a crate at 8+.
    if level >= 5:
        box("crane_rail", 20, TOP - 13, W - 20, TOP - 10.5, 8, 14, M("3a3f45"))
        hx = 118.0
        box("trolley", hx - 5, TOP - 16, hx + 5, TOP - 12, 7, 15, M("d0943a"))
        zcyl("chain", 0.45, 86 if level >= 8 else 80, TOP - 16, hx, 11, M("8a8f96"), outline=False)
        if level >= 8:
            box("sling", hx - 0.5, 79, hx + 0.5, 86, 10.6, 11.4, M("e0b030", ao=0.0), outline=False)
            crate(hx - 8, 71, 16, "3f8a7a", y0=4, y1=18, kind="steel")
        else:
            torus("hook", 2.2, 0.6, M("8a8f96"), (hx, 11, 78), rot=(math.pi / 2, 0, 0))
    # Manifest terminal (7+) and hazard board.
    box("hazard_sign", 153, 92, 167, 102, BACK - 1.2, BACK, M("e0b030"))
    for k in range(3):
        prism("hazard_mark", [(154 + k * 4.6, 92.4), (156.4 + k * 4.6, 92.4), (158.6 + k * 4.6, 101.6), (156.2 + k * 4.6, 101.6)], BACK - 1.5, BACK - 1.2, M("1e1e22", ao=0.0), outline=False)
    if level >= 7:
        box("terminal", 154, 66, 168, 86, BACK - 3, BACK, M("2a3038"))
        box("terminal_screen", 155.8, 72, 166.2, 84, BACK - 3.4, BACK - 3, M("3fd8c2", glow=1.0), outline=False)
        for k in range(3):
            box("manifest", 157, 81 - k * 3, 163 - k * 1.5, 81.6 - k * 3, BACK - 3.6, BACK - 3.4, M("0f3a36", ao=0.0), outline=False)


def medbay_bed(x0, level):
    frame = M("c8d0d6")
    for x in (x0 + 3, x0 + 35):
        zcyl("bed_leg", 0.9, FLOOR + 3, FLOOR + 13, x, 17, frame)
        ycyl("caster", 2.2, 2.4, M("2a2e34"), x, FLOOR + 2.2, 17)
    box("bed_frame", x0, FLOOR + 11, x0 + 40, FLOOR + 14, 8, 26, frame)
    box("mattress", x0 + 1, FLOOR + 14, x0 + 39, FLOOR + 18, 9, 25, M("9ec2cc"), bevel=1.2)
    box("sheet", x0 + 12, FLOOR + 16.5, x0 + 39.6, FLOOR + 20, 8.4, 25.6, M("f2f4f2"), bevel=1.4)
    box("sheet_fold", x0 + 12, FLOOR + 17, x0 + 16, FLOOR + 20.6, 8.0, 26, M("ffffff"), bevel=1.2)
    box("pillow", x0 + 2.5, FLOOR + 17.5, x0 + 11.5, FLOOR + 22, 10, 24, M("eef0f0"), bevel=1.6)
    head = M("3f9a94" if level < 6 else TEAL)
    box("headboard", x0 - 1, FLOOR + 11, x0 + 2, FLOOR + 31, 8, 26, frame)
    box("head_panel", x0 - 0.6, FLOOR + 18, x0 + 1.6, FLOOR + 29, 7.6, 26, head, outline=False)
    box("footboard", x0 + 38, FLOOR + 11, x0 + 41, FLOOR + 24, 8, 26, frame)
    box("foot_panel", x0 + 38.4, FLOOR + 15, x0 + 40.6, FLOOR + 22.5, 7.6, 26, head, outline=False)


def vitals(x0, z0, w=14, h=11):
    box("monitor", x0, z0, x0 + w, z0 + h, BACK - 4, BACK - 1, M("1c2228"))
    box("monitor_screen", x0 + 1.2, z0 + 1.2, x0 + w - 1.2, z0 + h - 1.2, BACK - 4.4, BACK - 4, M("0c1a16", ao=0.0), outline=False)
    box("monitor_arm", x0 + w / 2 - 1, z0 + h, x0 + w / 2 + 1, z0 + h + 4, BACK - 3, BACK, M("6f7882"), outline=False)
    zc = z0 + h * 0.48
    pts = [(0, 0), (0.3, 0), (0.4, 0.12), (0.47, 0), (0.53, 0), (0.58, -0.25), (0.64, 0.42), (0.7, -0.1), (0.76, 0), (1, 0)]
    green = M("5cff7a", glow=1.5)
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        a = (x0 + 2 + ax * (w - 4), zc + az * h)
        b = (x0 + 2 + bx * (w - 4), zc + bz * h)
        cylinder("pulse", 0.32, math.dist(a, b) + 0.3, green, ((a[0] + b[0]) / 2, BACK - 4.6, (a[1] + b[1]) / 2),
                 rot=(0, math.atan2(b[0] - a[0], b[1] - a[1]), 0), outline=False, seg=6)
    sphere("monitor_led", 0.5, M("ff5a4a", glow=1.4), (x0 + w - 2, BACK - 4.6, z0 + h - 2), outline=False, seg=6)


def red_cross(cx, cz, s, y, mat=None):
    red = mat or M("d83a32", ao=0.0)
    box("cross_v", cx - s * 0.17, cz - s / 2, cx + s * 0.17, cz + s / 2, y - 0.4, y, red, outline=False)
    box("cross_h", cx - s / 2, cz - s * 0.17, cx + s / 2, cz + s * 0.17, y - 0.4, y, red, outline=False)


def medbay(level):
    beds = min(1 + (level - 1) // 2, 3)
    for b in range(beds):
        x0 = 12.0 + b * 46.0
        medbay_bed(x0, level)
        vitals(x0 + 2, 76)
        if level >= 3:  # IV stand beside each bed
            ix = x0 + 43.5
            for s in (-1, 1):
                box("iv_foot", ix + min(0, s * 4), FLOOR + 1.2, ix + max(0, s * 4), FLOOR + 2.2, 14, 16, M("aab2ba"), outline=False)
            zcyl("iv_pole", 0.55, FLOOR + 1, FLOOR + 58, ix, 15, M("c8d0d6"))
            xcyl("iv_hook", 0.4, ix - 3, ix + 3, FLOOR + 57, 15, M("c8d0d6"), outline=False)
            box("iv_bag", ix - 2.8, FLOOR + 46, ix + 0.4, FLOOR + 55, 13.5, 15.5, M("d8f0ec", ao=0.0), bevel=1.0)
            box("iv_fluid", ix - 2.4, FLOOR + 46.6, ix, FLOOR + 50.5, 13.2, 13.5, M("f0c040", ao=0.0), outline=False)
    # Red-cross wall sign.
    box("sign", 150, 82, 166, 98, BACK - 1.6, BACK, M("f4f4f0"), bevel=1.0)
    red_cross(158, 90, 11, BACK - 1.7)
    # Medicine cabinet: glass doors over bottle shelves (more stock per level), cross on top.
    cx0, cx1 = 172.0, 212.0
    box("cabinet", cx0, 62, cx1, 98, BACK - 6, BACK, M("e6ecec"))
    box("cabinet_glass", cx0 + 2, 64, cx1 - 2, 96, BACK - 6.4, BACK - 6, M("bfe6ec", ao=0.0), outline=False)
    box("cabinet_split", (cx0 + cx1) / 2 - 0.5, 64, (cx0 + cx1) / 2 + 0.5, 96, BACK - 6.8, BACK - 6.4, M("c8d0d6"), outline=False)
    for z in (75.0, 86.0):
        box("cab_shelf", cx0 + 2, z - 0.6, cx1 - 2, z, BACK - 7, BACK - 6.4, M("c8d0d6"), outline=False)
    bottle_cols = ["d08a2a", "c83a3a", "3fb0a0", "f2f2f2", "6a5ac8", "4a9a3a"]
    nb = min(3 + level * 2, 18)
    for i in range(nb):
        tier, k = i // 6, i % 6
        bx = cx0 + 5 + k * 6 + (1.2 if k >= 3 else 0)
        bz = (64.6, 75.4, 86.4)[tier]
        hgt = 5.0 + (i * 5 % 3) * 1.2
        col = bottle_cols[(i * 5 + tier) % len(bottle_cols)]
        box("bottle", bx - 1.6, bz, bx + 1.6, bz + hgt, BACK - 7.4, BACK - 7.0, M(col, ao=0.0), outline=False)
        box("bottle_cap", bx - 1.1, bz + hgt, bx + 1.1, bz + hgt + 1.2, BACK - 7.4, BACK - 7.0, M("f4f4f0", ao=0.0), outline=False)
    for x in ((cx0 + cx1) / 2 - 3, (cx0 + cx1) / 2 + 2):
        box("cab_handle", x, 78, x + 1, 84, BACK - 7.2, BACK - 6.4, M("8a939c"), outline=False)
    # Floor equipment under the cabinet: med cart (2+), oxygen bottles (4+).
    if level >= 2:
        box("cart", 176, FLOOR + 3, 200, FLOOR + 24, 12, 26, M("dfe6e8"))
        for k in range(3):
            box("drawer", 177.5, FLOOR + 6 + k * 6, 198.5, FLOOR + 10.6 + k * 6, 11.6, 12, M("c8d4d8"), outline=False)
            box("drawer_pull", 185, FLOOR + 8 + k * 6, 191, FLOOR + 8.8 + k * 6, 11.2, 11.6, M("3f9a94"), outline=False)
        for x in (179.0, 197.0):
            ycyl("cart_wheel", 1.8, 2, M("2a2e34"), x, FLOOR + 1.8, 14)
        if level >= 8:  # defibrillator on the cart
            box("defib", 179, FLOOR + 24, 195, FLOOR + 31, 14, 24, M("e0b030"))
            box("defib_screen", 181, FLOOR + 26, 188, FLOOR + 29.5, 13.6, 14, M("5cff7a", glow=1.1), outline=False)
            for x in (190.5, 193.5):
                box("paddle", x - 1.1, FLOOR + 31, x + 1.1, FLOOR + 34, 15, 22, M("c83a2a"))
    if level >= 4:
        for k in range(1 + (level >= 6)):
            ox = 207.5 + k * 8 - (4 if level >= 6 else 0)
            zcyl("o2", 3.2, FLOOR, FLOOR + 26, ox, 20, M("4a9a5a"))
            zcyl("o2_top", 3.2, FLOOR + 26, FLOOR + 28.5, ox, 20, M("f2f2f2"), r2=1.6, outline=False)
            zcyl("o2_valve", 1.0, FLOOR + 28.5, FLOOR + 31, ox, 20, M("8a939c"), outline=False)
    # Headwall service panels behind each bed (5+): outlets, gas ports, call light.
    if level >= 5:
        for b in range(beds):
            x0 = 12.0 + b * 46.0
            box("headwall", x0 + 1, 62, x0 + 30, 68, BACK - 1.2, BACK, M("d8e0e2"))
            for k, c in enumerate(("4a9a5a", "3f6fb8", "e8e8e8")):
                ycyl("port", 1.0, 0.5, M(c, ao=0.0), x0 + 6 + k * 5, 65, BACK - 1.4, outline=False, seg=10)
            ycyl("call", 1.0, 0.5, M("ffb347", glow=1.4), x0 + 26, 65, BACK - 1.4, outline=False, seg=10)
    # Tier 2: x-ray lightbox (6+), ceiling surgical lamp (7+), vaccine fridge (9+), scanner ring (10).
    if level >= 6:
        box("xray", 32, 78, 50, 100, BACK - 1.6, BACK, M("2a3038"))
        box("xray_glow", 33.2, 79.2, 48.8, 98.8, BACK - 2.0, BACK - 1.6, M("cfeaff", glow=1.0), outline=False)
        for k in range(4):
            box("rib", 35, 84 + k * 3, 46, 85 + k * 3, BACK - 2.2, BACK - 2.0, M("7f9fb8", ao=0.0), outline=False)
        box("spine", 40, 81, 41, 97.5, BACK - 2.3, BACK - 2.2, M("6f8fa8", ao=0.0), outline=False)
    if level >= 7:  # ceiling surgical lamp over the middle bed
        lx = 84.0
        zcyl("lamp_mount", 1.2, TOP - 20, TOP - 6, lx, 12, M("8a939c"))
        sphere("lamp_joint", 1.8, M("8a939c"), (lx, 12, TOP - 20), seg=10)
        cylinder("surg_lamp", 8, 4.5, M("e6ecec"), (lx, 12, TOP - 24), r2=3.5)
        cylinder("surg_glow", 6.5, 0.6, M("fffbe8", glow=1.6), (lx, 11, TOP - 26.4), outline=False)
    if level >= 9:
        box("fridge", 150, FLOOR, 172, FLOOR + 34, 14, 28, M("e6ecec"))
        box("fridge_window", 152.5, FLOOR + 12, 169.5, FLOOR + 30, 13.6, 14, M("7fe0e8", glow=0.7), outline=False)
        for k in range(3):
            box("vial_rack", 154, FLOOR + 15 + k * 5, 168, FLOOR + 15.6 + k * 5, 13.4, 13.6, M("2f7a72", ao=0.0), outline=False)
        box("fridge_handle", 168, FLOOR + 4, 169.4, FLOOR + 10, 13.4, 14, M("8a939c"), outline=False)
    if level >= 10:  # healing-pod canopy over the third bed
        cx, cz, a, b = 126.0, FLOOR + 18.5, 19.0, 13.0
        pts = [(cx + a * math.cos(t * math.pi / 12), cz + b * math.sin(t * math.pi / 12)) for t in range(13)]
        for p, q in zip(pts, pts[1:]):
            cylinder("pod_rim", 0.9, math.dist(p, q) + 0.8, M("bfeef0"), ((p[0] + q[0]) / 2, 7, (p[1] + q[1]) / 2),
                     rot=(0, math.atan2(q[0] - p[0], q[1] - p[1]), 0), seg=10)
        for k, (x0, x1) in enumerate(((cx - 9, cx - 4), (cx - 2, cx + 0.5))):
            prism("pod_glint", [(x0, cz + 3), (x1, cz + 3), (x1 + 3, cz + 11.5), (x0 + 3, cz + 11.5)], 6.0, 6.4, M("ffffff", glow=0.5), outline=False)
        box("pod_glow", cx - 18, FLOOR + 10.4, cx + 18, FLOOR + 11.2, 7.4, 8, M("5fe8d8", glow=1.4), outline=False)


def server_rack(x0, level, n):
    box("rack", x0, FLOOR, x0 + 18, FLOOR + 60, 14, 28, M("1e2630"))
    box("rack_trim", x0, FLOOR + 58, x0 + 18, FLOOR + 60, 13.6, 28, M("3a4450"), outline=False)
    led = [M("5cff8a", glow=1.5), M("ffb347", glow=1.5), M("5fe8d8", glow=1.5)]
    for r in range(7):
        z = FLOOR + 6 + r * 7.2
        box("drive", x0 + 2, z, x0 + 16, z + 5.6, 13.6, 14, M("2c3844"), outline=False)
        box("drive_slot", x0 + 3, z + 2.4, x0 + 10, z + 3.2, 13.4, 13.6, M("12181e", ao=0.0), outline=False)
        for k in range(2):
            ycyl("led", 0.6, 0.4, led[(r * 2 + k + n) % 3], x0 + 12.5 + k * 2.2, z + 2.8, 13.3, outline=False, seg=8)
    if level >= 6:  # liquid cooling loop along the rack top
        xcyl("coolant_line", 0.8, x0 + 1, x0 + 17, FLOOR + 61, 20, M("3fd8c2", glow=0.6), outline=False)
        box("coolant_pump", x0 + 6, FLOOR + 60, x0 + 12, FLOOR + 63, 16, 24, M("3a4450"))


def specimen_tube(cx, level, plant=True):
    zcyl("tube_base", 9.5, FLOOR, FLOOR + 7, cx, 20, M("4a5560"), seg=32)
    cylinder("tube_glow", 8.6, 0.6, M("5fe8d8", glow=1.3), (cx, 20, FLOOR + 7.3), outline=False, seg=32)
    box("tube_back", cx - 8, FLOOR + 7, cx + 8, FLOOR + 50, 26, 27, M("a8e8e0", ao=0.0), outline=False)
    box("tube_liquid", cx - 8, FLOOR + 7, cx + 8, FLOOR + 36, 25.6, 26, M("5cd8b8", ao=0.0), outline=False)
    box("liquid_top", cx - 8, FLOOR + 35.2, cx + 8, FLOOR + 36, 25.4, 25.6, M("9ff0d8", ao=0.0), outline=False)
    for x in (cx - 8, cx + 6.8):
        box("tube_edge", x, FLOOR + 7, x + 1.2, FLOOR + 50, 25.2, 25.6, M("6fb8b0", ao=0.0), outline=False)
    if plant:
        zcyl("stem", 0.7, FLOOR + 8, FLOOR + 30, cx, 18, M("3f8f40"), outline=False)
        leaf_cluster(cx, FLOOR + 21 + level * 0.4, 17, 7.0 + level * 0.3, ["4caf50", "7fd66a", "3f9a48"], fruit=level >= 5)
    elif level >= 10:  # contained energy core
        sphere("core", 4.6, M("c89aff", glow=1.6), (cx, 17, FLOOR + 26), outline=False, seg=16)
        for a in (0.5, -0.5):
            torus("core_ring", 6.2, 0.35, M("f0e0ff", glow=1.5), (cx, 16, FLOOR + 26), rot=(math.pi / 2, a, 0))
    else:
        sphere("specimen", 4.2, M("ff8ad8", glow=1.1), (cx, 18, FLOOR + 24), scale=(1, 1, 1.25), outline=False, seg=14)
    for x, w in ((cx - 6.6, 1.3), (cx - 4.4, 0.6)):
        box("tube_glint", x, FLOOR + 10, x + w, FLOOR + 46, 11.6, 12, M("ffffff", glow=0.45), outline=False)
    zcyl("tube_cap", 9.5, FLOOR + 50, FLOOR + 55, cx, 20, M("4a5560"), seg=32)
    zcyl("tube_feed", 1.2, FLOOR + 55, TOP - 6, cx, 22, M("6f7882"))


def lab(level):
    racks = min(1 + level // 2, 3)
    for r in range(racks):
        server_rack(10.0 + r * 20.0, level, r)
    # Whiteboard with notes: more scribbles at higher levels.
    wx0, wx1 = 78.0, 136.0
    box("wb_frame", wx0, 74, wx1, 106, BACK - 1.6, BACK, M("aab2ba"))
    box("whiteboard", wx0 + 1.4, 75.4, wx1 - 1.4, 104.6, BACK - 2.0, BACK - 1.6, M("f2f4f2", ao=0.0), outline=False)
    box("wb_tray", wx0 + 6, 72.6, wx1 - 6, 74.4, BACK - 4, BACK, M("aab2ba"), outline=False)
    for k, c in enumerate(("2a5ad0", "d03a3a", "2a2a2a")):
        box("marker", wx0 + 10 + k * 6, 74.4, wx0 + 14.5 + k * 6, 75.6, BACK - 3.6, BACK - 2.4, M(c), outline=False)
    ink = [M("2a5ad0", ao=0.0), M("d03a3a", ao=0.0), M("2a2a2a", ao=0.0)]
    for k in range(min(2 + level, 6)):
        z = 100.5 - k * 4.2
        w = [26, 18, 22, 14, 20, 16][k]
        box("note", wx0 + 4, z, wx0 + 4 + w, z + 0.8, BACK - 2.2, BACK - 2.0, ink[k % 3], outline=False)
    torus("wb_circle", 5.5, 0.4, ink[1], (wx1 - 12, BACK - 2.1, 95), rot=(math.pi / 2, 0, 0))
    if level >= 3:  # little bar chart
        for k, h in enumerate((4, 7, 5, 10)[:min(level - 1, 4)]):
            box("bar", wx1 - 22 + k * 4, 78, wx1 - 19.6 + k * 4, 78 + h, BACK - 2.2, BACK - 2.0, ink[0] if k < 3 else ink[1], outline=False)
    # Console desk under the whiteboard with glowing screens.
    box("desk", 74, FLOOR + 15, 138, FLOOR + 18, 8, 24, M("5a636e"))
    for x in (76.0, 133.0):
        box("desk_leg", x, FLOOR, x + 3, FLOOR + 15, 10, 13, M("3a3f45"))
    box("desk_drawers", 116, FLOOR + 2, 132, FLOOR + 15, 12, 24, M("4a525c"))
    screens = min(1 + (level + 1) // 3, 3)
    glows = ["3fd8c2", "5fb0ff", "7fe08a"]
    for s in range(screens):
        x = 78.0 + s * 19.0
        box("stand", x + 6.5, FLOOR + 18, x + 9.5, FLOOR + 22, 16, 19, M("3a3f45"), outline=False)
        box("screen_case", x, FLOOR + 21, x + 16, FLOOR + 33, 14, 18, M("1c2228"))
        box("screen", x + 1.2, FLOOR + 22.2, x + 14.8, FLOOR + 31.8, 13.6, 14, M(glows[s], glow=1.0), outline=False)
        for k in range(3):
            box("code", x + 2.5, FLOOR + 29 - k * 2.4, x + 2.5 + (9, 6, 11)[(k + s) % 3], FLOOR + 29.6 - k * 2.4, 13.4, 13.6, M("103a40", ao=0.0), outline=False)
    box("keyboard", 84, FLOOR + 18, 100, FLOOR + 19.2, 9, 13, M("2a2e34"), outline=False)
    # Specimen tubes: a plant, then a glowing specimen (4+) that becomes an energy core at 10.
    specimen_tube(151.0, level)
    if level >= 4:
        specimen_tube(172.0, level, plant=False)
    # Chemistry bench: flasks, microscope (6+), robot arm (8+).
    bx0 = 187.0
    box("bench", bx0, FLOOR + 15, 222, FLOOR + 18, 8, 26, M("e6ecec"))
    box("bench_body", bx0 + 1, FLOOR, 221, FLOOR + 15, 10, 26, M("4a525c"))
    for k in range(2):
        box("bench_door", bx0 + 3 + k * 16, FLOOR + 2, bx0 + 16 + k * 16, FLOOR + 13, 9.6, 10, M("5a636e"), outline=False)
    flasks = min(1 + level // 2, 4)
    fl = ["7fe08a", "ff8ad8", "5fb0ff", "ffd060"]
    for k in range(flasks):
        fx = bx0 + 14 + k * 6.5
        cylinder("flask", 2.6, 5.5, M(fl[k], light=1.3, ao=0.0), (fx, 16, FLOOR + 20.75), r2=0.9, seg=16)
        zcyl("flask_neck", 0.8, FLOOR + 23.5, FLOOR + 27, fx, 16, M("d8f0ec", ao=0.0))
    if level >= 6:  # microscope
        box("scope_base", bx0 + 2, FLOOR + 18, bx0 + 10, FLOOR + 19.5, 14, 22, M("e6ecec"))
        box("scope_arm", bx0 + 7.5, FLOOR + 19.5, bx0 + 10, FLOOR + 31, 16, 20, M("e6ecec"))
        cylinder("scope_tube", 1.4, 9, M("2a2e34"), (bx0 + 5.5, 18, FLOOR + 30), rot=(0, 0.45, 0))
        box("scope_stage", bx0 + 3, FLOOR + 23, bx0 + 8, FLOOR + 24, 15, 21, M("2a2e34"), outline=False)
    if level >= 8:  # robot arm on the bench end
        base = (218.0, FLOOR + 18)
        box("arm_base", base[0] - 3.5, base[1], base[0] + 3.5, base[1] + 3, 14, 22, M("3a3f45"))
        j = (base[0] - 3, base[1] + 18)
        e = (j[0] - 10, j[1] - 6)
        for (a, b, r) in ((base, j, 1.6), (j, e, 1.3)):
            cylinder("arm", r, math.dist(a, b), M("d0943a"), ((a[0] + b[0]) / 2, 18, (a[1] + b[1]) / 2), rot=(0, math.atan2(b[0] - a[0], b[1] - a[1]), 0))
        sphere("joint", 2.2, M("3a3f45"), (j[0], 18, j[1]), seg=12)
        box("gripper", e[0] - 1.5, e[1] - 3.5, e[0] + 1.5, e[1], 16.5, 19.5, M("3a3f45"))
    # Ceiling cable tray (3+), hologram over the bench (7+), data wall over the racks (9+).
    if level >= 3:
        box("cable_tray", 10, TOP - 14, 70, TOP - 11.5, 12, 22, M("3a3f45"))
        for k in range(3):
            xcyl("cable", 0.6, 12, 68, TOP - 13.2 + k * 0.6, 14 + k * 3, M(["d0943a", "3fd8c2", "c83a2a"][k]), outline=False)
    if level >= 7:  # wireframe hologram globe projected from the ceiling
        hx, hz = 207.0, 82.0
        cylinder("holo_emit", 4.0, 4, M("2a2e34"), (hx, 18, TOP - 14), r2=2.2)
        cylinder("holo_lens", 2.2, 0.6, M("5fe8d8", glow=1.6), (hx, 18, TOP - 16.2), outline=False)
        holo = M("7ff8ea", glow=1.4)
        for a in (0.0, 1.05, -1.05):
            torus("holo_long", 7.0, 0.22, holo, (hx, 18, hz), rot=(math.pi / 2, 0, a), seg_v=6)
        for dz, r in ((0.0, 7.0), (3.6, 6.0), (-3.6, 6.0)):
            torus("holo_lat", r, 0.22, holo, (hx, 18, hz + dz), rot=(0.22, 0, 0), seg_v=6)
        sphere("holo_core", 1.6, M("ffffff", glow=1.5), (hx, 18, hz), outline=False, seg=10)
        for s in (-1, 1):
            a, b = (hx + s * 1.6, TOP - 17), (hx + s * 5.5, hz + 4)
            cylinder("holo_beam", 0.15, math.dist(a, b), M("5fe8d8", glow=0.9), ((a[0] + b[0]) / 2, 19, (a[1] + b[1]) / 2),
                     rot=(0, math.atan2(b[0] - a[0], b[1] - a[1]), 0), outline=False, seg=6)
    if level >= 9:  # data wall over the racks with a live graph
        box("datawall", 10, 95, 70, 105.5, BACK - 1.6, BACK, M("1c2228"))
        box("data_screen", 11.2, 96.2, 68.8, 104.3, BACK - 2.0, BACK - 1.6, M("0f2a3a", ao=0.0), outline=False)
        pts = [(13, 98), (20, 101), (27, 99.5), (34, 102.5), (41, 100.5), (48, 103), (55, 101.5), (62, 103.4), (67, 102.6)]
        for a, b in zip(pts, pts[1:]):
            cylinder("graph", 0.3, math.dist(a, b) + 0.3, M("5fe8d8", glow=1.5), ((a[0] + b[0]) / 2, BACK - 2.2, (a[1] + b[1]) / 2),
                     rot=(0, math.atan2(b[0] - a[0], b[1] - a[1]), 0), outline=False, seg=6)
        for x, z in pts[1::2]:
            sphere("graph_pt", 0.6, M("ffb347", glow=1.5), (x, BACK - 2.3, z), outline=False, seg=8)


WATER = "3a9cf0"
COLD = "7fd8ff"


def intake_fan(cx, cz, r, level):
    """Wall intake fan: housing ring, dark throat, swept blades and a hub."""
    torus("fan_ring", r, 1.6, M("2d4656"), (cx, BACK - 5, cz), rot=(math.pi / 2, 0, 0), outline=True)
    ycyl("fan_throat", r - 0.6, 2, M("0c1a22", ao=0.0), cx, cz, BACK - 2.5, outline=False, seg=32)
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.3
        pts = [(cx, cz), (cx + math.cos(a) * (r - 1.5), cz + math.sin(a) * (r - 1.5)), (cx + math.cos(a + 0.75) * (r - 2.5), cz + math.sin(a + 0.75) * (r - 2.5))]
        prism("fan_blade", pts, BACK - 4.6, BACK - 3.8, M("6f97aa", light=1.25), outline=False)
    ycyl("fan_hub", r * 0.22, 1.4, M("9ab4c0"), cx, cz, BACK - 5.4)
    for k in range(3):  # inflow streaks: the cool air being pulled in
        box("airflow", cx - r - 9 + k * 2, cz - 5 + k * 5, cx - r - 3 + k * 2, cz - 4.4 + k * 5, BACK - 6, BACK - 5.6, M(COLD, glow=0.6), outline=False)


def dew_panel(x0, x1, z0, z1, level):
    """Mesh net the night air condenses on, with beads of dew and a gutter underneath."""
    frame = M("3a4a56")
    for a, b, c, d in ((x0, z0, x1, z0 + 2), (x0, z1 - 2, x1, z1), (x0, z0, x0 + 2, z1), (x1 - 2, z0, x1, z1)):
        box("net_frame", a, b, c, d, BACK - 4, BACK - 1, frame)
    box("net_back", x0 + 2, z0 + 2, x1 - 2, z1 - 2, BACK - 1.2, BACK - 1, M("15364a", ao=0.0), outline=False)
    mesh = M("7fb6cc", ao=0.0)
    step = 5.0
    n = int((x1 - x0 - 4 + (z1 - z0)) / step)
    for k in range(1, n):  # diagonal mesh both ways, clipped to the frame
        for sgn in (1, -1):
            d0 = x0 + 2 + k * step - (z1 - z0 - 4)
            ax, az = max(x0 + 2, d0), z0 + 2 + max(0.0, x0 + 2 - d0)
            bx, bz = min(x1 - 2, d0 + (z1 - z0 - 4)), z0 + 2 + min(z1 - z0 - 4, x1 - 2 - d0)
            if bx - ax < 0.8:
                continue
            if sgn < 0:
                az, bz = z0 + z1 - az, z0 + z1 - bz
            length = math.dist((ax, az), (bx, bz))
            ang = math.atan2(bx - ax, bz - az)
            cylinder("mesh", 0.22, length, mesh, ((ax + bx) / 2, BACK - 2.6, (az + bz) / 2), rot=(0, ang, 0), outline=False, seg=6)
    for k in range(int((x1 - x0) / 5) + level // 2):
        dx = x0 + 4 + (k * 7.3) % (x1 - x0 - 8)
        dz = z0 + 5 + (k * 11.7) % (z1 - z0 - 10)
        sphere("dew", 0.75, M("d8f6ff", glow=1.2), (dx, BACK - 3, dz), outline=False, seg=8)
    xcyl("gutter", 1.8, x0 - 1, x1 + 1, z0 - 1.5, BACK - 4, M("5a7684"))
    box("gutter_water", x0, z0 - 1.2, x1, z0 - 0.2, BACK - 5.9, BACK - 5.7, M(WATER, glow=0.9), outline=False)


def water_tank(cx, level, h=40.0):
    r = 7.5
    zcyl("wt_base", r + 1.2, FLOOR, FLOOR + 4, cx, 20, M("4a5a66"), seg=28)
    box("wt_back", cx - r, FLOOR + 4, cx + r, FLOOR + 4 + h, 26, 27, M("a8dcf0", ao=0.0), outline=False)
    lvl = h * (0.55 + 0.04 * min(level, 10))
    box("wt_water", cx - r, FLOOR + 4, cx + r, FLOOR + 4 + lvl, 25.6, 26, M(WATER if level < 9 else "4ab4ff", light=1.2, ao=0.0), outline=False)
    box("wt_surface", cx - r, FLOOR + 3.4 + lvl, cx + r, FLOOR + 4.2 + lvl, 25.4, 25.6, M("a8e4ff", ao=0.0), outline=False)
    for x in (cx - r, cx + r - 1.0):
        box("wt_edge", x, FLOOR + 4, x + 1.0, FLOOR + 4 + h, 25.2, 25.6, M("6fa8c0", ao=0.0), outline=False)
    box("wt_glint", cx - r + 1.6, FLOOR + 7, cx - r + 2.8, FLOOR + h, 11.6, 12, M("ffffff", glow=0.5), outline=False)
    zcyl("wt_cap", r + 1.2, FLOOR + 4 + h, FLOOR + 8 + h, cx, 20, M("4a5a66"), seg=28)
    for k in range(2):
        sphere("wt_bubble", 0.6, M("dff6ff", glow=1.0), (cx + 2 - k * 3, 13, FLOOR + 9 + k * 7), outline=False, seg=8)


def condenser(level):
    """Night-air water harvester: intake fans pull air over a frosty fin tower and dew nets;
    the condensate drains into a row of glass tanks. The floor in front stays clear for crew."""
    cold = M(COLD, glow=1.1)
    # Fin tower with a glowing cold core (grows with level), copper-to-frost coil from level 4.
    top = 76.0 + min(level, 5) * 4.0
    box("tower_base", 12, FLOOR, 54, FLOOR + 7, 12, 28, M("2a3640"))
    box("tower_core", 27, FLOOR + 7, 39, top, 16, 26, M("1a3a4c"))
    box("tower_glow", 29.5, FLOOR + 9, 36.5, top - 2, 15.6, 16, cold, outline=False)
    fins = int((top - FLOOR - 12) / 4.5)
    for k in range(fins):
        z = FLOOR + 11 + k * 4.5
        box("fin", 14, z, 52, z + 1.5, 14, 26, M("8fb8c8", light=1.25))
    box("tower_cap", 12, top, 54, top + 4, 12, 28, M("3a4a56"))
    zcyl("tower_pipe", 1.4, top + 4, TOP - 9, 33, 20, M("5a7684"))
    if level >= 4:
        coil = M("c98a4a" if level < 7 else "bfe6f2", light=1.25)
        n = 7
        for k in range(n):
            za, zb = FLOOR + 14 + k * (top - FLOOR - 22) / n, FLOOR + 14 + (k + 1) * (top - FLOOR - 22) / n
            xa, xb = (17, 49) if k % 2 == 0 else (49, 17)
            length = math.dist((xa, za), (xb, zb))
            cylinder("coil", 1.1, length, coil, ((xa + xb) / 2, 12.5, (za + zb) / 2), rot=(0, math.atan2(xb - xa, zb - za), 0), seg=10)
    # Dew nets on the back wall, draining into a gutter.
    dew_panel(60, 96, 60, 100, level)
    if level >= 2:
        dew_panel(144, 166, 62, 100, level)
    # Intake fans pulling the night air in.
    intake_fan(122, 86, 13, level)
    if level >= 5:
        intake_fan(122, 59, 9, level)
    # Collection line from the gutters to the tanks, with a pressure gauge.
    pipe = M("5a7684")
    tanks = 1 if level < 3 else (2 if level < 5 else 3)
    x_end = 211.0 - (tanks - 1) * 17.5 - 7.0  # the line runs into the first tank
    xcyl("collect", 1.6, 60, x_end, 46, BACK - 5, pipe)
    box("collect_glow", 64, 45.4, x_end - 2, 46.6, BACK - 6.7, BACK - 6.5, M(WATER, glow=0.8), outline=False)
    for x in (80.0, 158.0)[:1 if level < 2 else 2]:
        zcyl("drain", 1.2, 46, 58, x, BACK - 4, pipe, outline=False)
    gx, gz = 102.0, 46.0  # pressure gauge inline on the collection pipe
    ycyl("gauge", 4.6, 1.4, M("e8eef0"), gx, gz, BACK - 7.5)
    torus("gauge_rim", 4.6, 0.7, M("8a9aa6"), (gx, BACK - 8.3, gz), rot=(math.pi / 2, 0, 0))
    box("needle", gx - 0.4, gz, gx + 0.4, gz + 3.6, BACK - 8.6, BACK - 8.4, M("c83a2a", ao=0.0), outline=False).rotation_euler = (0, -0.6, 0)
    for k in range(5):
        a = math.radians(210 - k * 60)
        box("gauge_tick", gx + math.cos(a) * 3.4 - 0.3, gz + math.sin(a) * 3.4 - 0.3, gx + math.cos(a) * 3.4 + 0.3, gz + math.sin(a) * 3.4 + 0.3, BACK - 8.6, BACK - 8.4, M("2a2e34", ao=0.0), outline=False)
    if level >= 4:  # second gauge on the tower base
        ycyl("gauge2", 3.0, 1.2, M("e8eef0"), 46, FLOOR + 3.6, 11.2)
        torus("gauge2_rim", 3.0, 0.5, M("8a9aa6"), (46, 10.5, FLOOR + 3.6), rot=(math.pi / 2, 0, 0))
        box("needle2", 45.6, FLOOR + 3.6, 46.4, FLOOR + 6, 10.2, 10.4, M("c83a2a", ao=0.0), outline=False)
    # Glass tanks of collected water (more with level).
    for k in range(tanks):
        water_tank(211.0 - k * 17.5, level, h=40.0 + (k % 2) * 6)
    # Tier 2: glowing floor line (6+), frost on fins and fan (7+), sight glass (8+), humidity display (9+), cryo dome (10).
    if level >= 6:
        xcyl("floor_line", 1.3, 12, W - 12, FLOOR + 2.2, 27, M("2d5a70"))
        xcyl("floor_line_glow", 0.5, 14, W - 14, FLOOR + 2.2, 25.6, M(COLD, glow=1.0), outline=False)
    if level >= 7:
        frost = M("e4f8ff", ao=0.0)
        for k in range(0, fins, 2):
            z = FLOOR + 12.5 + k * 4.5
            sphere("rime", 1.2, frost, (16 + (k * 7) % 30, 13.6, z), scale=(2.4, 0.8, 0.7), outline=False, seg=8)
        for a in (2.0, 2.5, 0.7):
            sphere("fan_rime", 1.3, frost, (122 + math.cos(a) * 13, BACK - 7, 86 + math.sin(a) * 13), scale=(1.5, 0.8, 0.8), outline=False, seg=8)
    if level >= 8:  # glowing level lights on each tank base
        for k in range(tanks):
            cx = 211.0 - k * 17.5
            box("tank_led", cx - 4, FLOOR + 1.2, cx + 4, FLOOR + 2.6, 11.0, 11.4, M("5fe8f0", glow=1.5), outline=False)
    if level >= 9:  # console with a humidity read-out under the second dew net
        box("console", 141, FLOOR, 165, FLOOR + 11, 16, 28, M("23303a"))
        box("hum_screen", 143, FLOOR + 3, 163, FLOOR + 9.5, 15.6, 16, M("0c1820", ao=0.0), outline=False)
        for k in range(5):
            box("hum_bar", 145 + k * 3.6, FLOOR + 4.2, 147.4 + k * 3.6, FLOOR + 5.4 + k * 0.9, 15.4, 15.6, M(COLD if k < 4 else "ffb347", glow=1.3), outline=False)
    if level >= 10:  # gold-ringed cryo collar with a window on the fin tower
        for z in (FLOOR + 30, FLOOR + 44):
            box("cryo_band", 24, z, 42, z + 2.2, 10.6, 27, M(GOLD, light=1.3))
        box("cryo_case", 25, FLOOR + 32, 41, FLOOR + 44, 11.0, 26, M("2a4a5c"))
        box("cryo_window", 27.5, FLOOR + 34, 38.5, FLOOR + 42, 10.6, 11.0, M("c8fbff", glow=1.6), outline=False)
        for x in (18, 30, 44):
            cylinder("icicle", 1.0, 4.5, M("e4f8ff", ao=0.0), (x, 12.4, top - 2.2), rot=(math.pi, 0, 0), r2=0.1, seg=8)


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
    elif kind == "cargo":
        for x in (56.0, 132.0):
            box("cargo_hatch", x, TOP + 19, x + 44, TOP + 24.5, 2, 26, M("3d424a"))
            for hx in (x + 6, x + 34):
                box("hatch_handle", hx, TOP + 24.5, hx + 4, TOP + 26.5, 8, 20, M("d9a33a"))
    elif kind == "medbay":
        box("vent_box", 30, TOP + 19, 56, TOP + 26, 4, 24, M("30343b"))
        box("cross_sign", 98, TOP + 19, 134, TOP + 35, 4, 22, M("f4f4f0"), bevel=2.0)
        red_cross(116, TOP + 27, 11, 3.9, M("e0302a", glow=0.9))
    elif kind == "condenser":
        # Slanted dew net catching the night air, and a roof intake hood with a fan.
        for x in (32.0, 76.0):
            box("net_leg", x - 1, TOP + 19, x + 1, TOP + 27, 10, 14, M("3a3f45"))
        prism("net_frame", [(28, TOP + 25), (80, TOP + 25), (80, TOP + 36), (28, TOP + 30)], 4, 22, M("4a5a66"))
        prism("net_face", [(30, TOP + 26.2), (78, TOP + 26.2), (78, TOP + 34.4), (30, TOP + 29.6)], 3.2, 4, M("1e4a62", ao=0.0), outline=False)
        for k in range(1, 8):
            x = 30 + k * 6
            box("net_wire", x - 0.2, TOP + 26.4, x + 0.2, TOP + 29.6 + (x - 30) * 4.8 / 48, 3.0, 3.2, M("8fc8dc", ao=0.0), outline=False)
        box("hood", 124, TOP + 19, 168, TOP + 31, 4, 24, M("30343b"), bevel=2)
        ycyl("hood_fan", 5, 0.6, M("0c1a22", ao=0.0), 146, TOP + 25, 3.6, outline=False)
        torus("hood_grille", 5, 0.5, M("9ab4c0"), (146, 3.3, TOP + 25), rot=(math.pi / 2, 0, 0))
        for k in range(3):
            box("hood_slot", 129, TOP + 21.5 + k * 2.6, 137, TOP + 22.3 + k * 2.6, 3.6, 4, M("15181c"), outline=False)
            box("hood_slot", 155, TOP + 21.5 + k * 2.6, 163, TOP + 22.3 + k * 2.6, 3.6, 4, M("15181c"), outline=False)
    elif kind == "lab":
        sphere("sensor_dome", 13, M("aeb8c2"), (60, 15, TOP + 19), scale=(1, 0.9, 0.8), seg=28)
        box("dome_ring", 46, TOP + 18.5, 74, TOP + 21, 4, 26, M("30343b"))
        box("dome_slit", 57.5, TOP + 22, 62.5, TOP + 29.4, 3.0, 4.6, M("1a2228", ao=0.0), outline=False)
        box("lab_box", 150, TOP + 19, 186, TOP + 27, 4, 24, M("30343b"))
        for k in range(4):
            box("lab_louver", 153 + k * 8, TOP + 21, 158 + k * 8, TOP + 25, 3.4, 4, M("15181c"), outline=False)


BUILDERS = {"quarters": quarters, "greenhouse": greenhouse, "recycler": recycler, "workshop": workshop, "cooling": cooling, "dronebay": dronebay,
            "cargo": cargo, "medbay": medbay, "lab": lab, "condenser": condenser}


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
        for level in range(1, 11):
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

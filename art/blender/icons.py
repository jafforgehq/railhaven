"""Railhaven item / resource icons, modelled and rendered in Blender (128 px, transparent).

  Blender -b --factory-startup --python art/blender/icons.py -- <out_dir> [only...]

Viewed slightly from above so tops catch the light. Pure UI glyphs (check, plus,
close, menu, arrows) stay as vector shapes in Godot.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import box, sphere, cylinder, torus, prism, toon  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/railhaven_icons"
ONLY = set(ARGS[1:])
SIZE = 128


def M(h, **kw):
    return toon(h, **kw)


def teardrop(name, r, mat, loc, point=1.9):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=r)
    for v in bm.verts:
        if v.co.z > 0:
            k = v.co.z / r
            v.co.x *= 1.0 - k ** 1.4
            v.co.y *= 1.0 - k ** 1.4
            v.co.z *= point
    return C.finish(name, bm, mat, loc)


def gear(name, r, depth, mat, loc, teeth=10):
    cylinder(name, r * 0.8, depth, mat, loc, rot=(math.pi / 2, 0, 0), seg=32)
    for k in range(teeth):
        a = k * 2 * math.pi / teeth
        t = box(name + "_t", -r * 0.13, -r * 0.13, r * 0.13, r * 0.13, -depth / 2, depth / 2, mat, bevel=0.03)
        t.location = (loc[0] + math.cos(a) * r * 0.86, loc[1], loc[2] + math.sin(a) * r * 0.86)
        t.rotation_euler = (0, -a, 0)
    cylinder(name + "_hole", r * 0.28, depth * 1.2, M("2a2c31"), (loc[0], loc[1] - 0.01, loc[2]), rot=(math.pi / 2, 0, 0), outline=False)


def icon_scrap():
    for dx, dz, y in ((-0.16, -0.2, 0.1), (0.18, -0.2, -0.05), (0.02, 0.08, 0.0)):
        prism("ingot", [(-0.4 + dx, -0.13 + dz), (0.4 + dx, -0.13 + dz), (0.3 + dx, 0.13 + dz), (-0.3 + dx, 0.13 + dz)],
              y - 0.2, y + 0.2, M("aeb6c0", light=1.25))
    sphere("rivet", 0.05, M("6a6f78"), (0.04, -0.21, 0.12), outline=False)


def icon_parts():
    gear("gear", 0.62, 0.22, M("c9a560", light=1.25), (0, 0, 0))


def icon_food():
    cylinder("bowl", 0.58, 0.32, M("c0703a"), (0, 0, -0.22), r2=0.42)
    cylinder("bowl_rim", 0.6, 0.06, M("d88a4a"), (0, 0, -0.06))
    for i, (x, z, c) in enumerate(((-0.25, 0.05, "5cbf5a"), (0.05, 0.12, "4caf50"), (0.3, 0.04, "7fd66a"), (-0.05, -0.02, "e0502e"), (0.22, -0.02, "f0a030"))):
        sphere("veg", 0.2 if c != "e0502e" else 0.17, M(c), (x, -0.1, z), scale=(1, 1, 0.9))


def icon_water():
    teardrop("drop", 0.42, M("4fb4ff", light=1.3), (0, 0, -0.18))
    sphere("shine", 0.08, M("ffffff", glow=1.0), (-0.14, -0.38, -0.15), outline=False)


def icon_crew():
    for x, y, c in ((-0.25, 0.1, "c98a3a"), (0.22, -0.1, "4f86b0")):
        sphere("body", 0.3, M(c), (x, y, -0.42), scale=(1, 0.8, 0.9))
        sphere("head", 0.2, M("f3cba5"), (x, y, 0.0))
        sphere("hair", 0.21, M("2b1d16"), (x - 0.02, y + 0.03, 0.06), scale=(1, 1, 0.75))


def icon_home():
    box("walls", -0.42, -0.55, 0.42, 0.1, -0.3, 0.3, M("c9a07a"))
    prism("roof", [(-0.58, 0.05), (0.58, 0.05), (0.0, 0.55)], -0.36, 0.36, M("a0402a"))
    box("door", -0.1, -0.55, 0.12, -0.15, -0.32, -0.3, M("5a3a24"), outline=False)
    box("window", 0.18, -0.25, 0.34, -0.08, -0.32, -0.3, M("ffd890", glow=1.0), outline=False)


def icon_cooling():
    torus("ring", 0.55, 0.08, M("5f8a96"), (0, 0, 0), rot=(math.pi / 2, 0, 0), outline=True)
    for k in range(5):
        a = k * 2 * math.pi / 5
        prism("blade", [(0, 0), (math.cos(a) * 0.5, math.sin(a) * 0.5), (math.cos(a + 0.6) * 0.45, math.sin(a + 0.6) * 0.45)], -0.05, 0.05, M("8cd8e8", light=1.3))
    cylinder("hub", 0.12, 0.14, M("b08a45"), (0, -0.06, 0), rot=(math.pi / 2, 0, 0))


def icon_drone():
    box("body", -0.35, -0.12, 0.35, 0.14, -0.2, 0.2, M("3d434c"), bevel=0.1)
    box("stripe", -0.25, 0.08, 0.25, 0.15, -0.21, -0.19, M("c8923a"), outline=False)
    sphere("eye", 0.07, M("3fd8c2", glow=1.6), (0.2, -0.21, 0.0), outline=False)
    for s in (-1, 1):
        cylinder("arm", 0.035, 0.3, M("2a2c31"), (s * 0.45, 0, 0.18), rot=(0, s * 0.9, 0))
        cylinder("rotor", 0.3, 0.02, M("d8e6f0"), (s * 0.55, 0, 0.32), outline=False)


def icon_train():
    cylinder("boiler", 0.3, 0.8, M("2c3036"), (-0.1, 0, 0.0), rot=(0, math.pi / 2, 0))
    box("cab", 0.25, -0.35, 0.65, 0.42, -0.3, 0.3, M("2c3036"))
    box("window", 0.33, 0.05, 0.57, 0.3, -0.31, -0.29, M("ffb050", glow=1.0), outline=False)
    cylinder("chimney", 0.1, 0.3, M("1c1f24"), (-0.32, 0, 0.42), r2=0.14)
    for x in (-0.4, -0.05, 0.4):
        cylinder("wheel", 0.17, 0.1, M("b08a45"), (x, -0.32, -0.42), rot=(math.pi / 2, 0, 0))


def icon_tower():
    cylinder("shaft", 0.22, 1.1, M("6a7a84"), (0, 0, -0.05), r2=0.12)
    for z in (-0.3, 0.0, 0.3):
        cylinder("ring", 0.2 - z * 0.12, 0.06, M("66ffe8", glow=1.4), (0, -0.02, z), outline=False)
    cylinder("crown", 0.18, 0.18, M("4a5a64"), (0, 0, 0.55), r2=0.14)
    sphere("beacon", 0.07, M("b0ffff", glow=2.0), (0, 0, 0.72), outline=False)


def icon_wrench():
    ob = box("handle", -0.07, -0.6, 0.07, 0.3, -0.05, 0.05, M("aeb6be", light=1.3), bevel=0.04)
    torus("head", 0.17, 0.07, M("aeb6be", light=1.3), (0, 0, 0.42), rot=(math.pi / 2, 0, 0), outline=True)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.rotation_euler.y += -0.7


def icon_hammer():
    box("handle", -0.06, -0.6, 0.06, 0.35, -0.05, 0.05, M("8a5a34"), bevel=0.04)
    box("head", -0.32, 0.28, 0.32, 0.5, -0.12, 0.12, M("8a929a", light=1.3), bevel=0.04)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.rotation_euler.y += 0.6


def icon_bed():
    box("frame", -0.6, -0.35, 0.6, -0.15, -0.3, 0.3, M("6a5038"))
    box("mattress", -0.55, -0.15, 0.55, 0.02, -0.28, 0.28, M("3f6f7a"), bevel=0.05)
    box("pillow", -0.55, 0.0, -0.22, 0.14, -0.22, 0.22, M("ece6d6"), bevel=0.05)
    box("head", -0.66, -0.4, -0.56, 0.3, -0.3, 0.3, M("5a4632"))


def icon_shield():
    pts = [(0, 0.6), (0.48, 0.45), (0.42, -0.1), (0, -0.6), (-0.42, -0.1), (-0.48, 0.45)]
    prism("shield", pts, -0.08, 0.08, M("b08a45", light=1.3))
    prism("inner", [(x * 0.72, z * 0.72) for x, z in pts], -0.1, -0.08, M("2f9a90"), outline=False)


def icon_sun():
    sphere("sun", 0.32, M("ffb030", glow=1.3), (0, 0, 0), outline=False)
    for k in range(8):
        a = k * math.pi / 4
        cylinder("ray", 0.06, 0.2, M("ffd060", glow=1.2), (math.cos(a) * 0.5, 0, math.sin(a) * 0.5), rot=(0, math.pi / 2 - a, 0), outline=False, r2=0.0)


def icon_temp():
    cylinder("tube", 0.1, 0.8, M("dfe6ea"), (0, 0, 0.1))
    sphere("bulb", 0.2, M("e0402a"), (0, 0, -0.38))
    cylinder("mercury", 0.05, 0.5, M("e0402a"), (0, -0.06, -0.02), outline=False)


def icon_map():
    pin = teardrop("pin", 0.34, M("e0402a"), (0, 0, 0.18), point=2.2)
    pin.rotation_euler = (0, math.pi, 0)
    sphere("dot", 0.12, M("ffffff"), (0, -0.32, 0.2), outline=False)


def icon_star():
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = 0.6 if i % 2 == 0 else 0.26
        pts.append((math.cos(a) * r, math.sin(a) * r - 0.05))
    prism("star", pts, -0.1, 0.1, M("f0b84a", light=1.25))


def icon_warning():
    prism("tri", [(-0.6, -0.45), (0.6, -0.45), (0.0, 0.58)], -0.08, 0.08, M("f0b030", light=1.2))
    box("bar", -0.06, -0.12, 0.06, 0.28, -0.1, -0.08, M("2a1a08"), outline=False)
    box("dot", -0.06, -0.33, 0.06, -0.2, -0.1, -0.08, M("2a1a08"), outline=False)


def icon_arrow():
    prism("arrow", [(-0.22, 0.62), (0.22, 0.62), (0.22, 0.05), (0.5, 0.05), (0.0, -0.6), (-0.5, 0.05), (-0.22, 0.05)], -0.12, 0.12, M("f0b84a", light=1.3))


def icon_bulb():
    sphere("glass", 0.36, M("ffe08a", glow=1.2), (0, 0, 0.12), outline=True)
    cylinder("base", 0.17, 0.3, M("8a8f96"), (0, 0, -0.36))
    for z in (-0.28, -0.38):
        cylinder("thread", 0.19, 0.04, M("5a5f66"), (0, 0, z), outline=False)


ICONS = {"arrow": icon_arrow, "bulb": icon_bulb, 
    "scrap": icon_scrap, "parts": icon_parts, "food": icon_food, "water": icon_water, "crew": icon_crew,
    "home": icon_home, "cooling": icon_cooling, "drone": icon_drone, "train": icon_train, "tower": icon_tower,
    "wrench": icon_wrench, "hammer": icon_hammer, "bed": icon_bed, "shield": icon_shield, "sun": icon_sun,
    "temp": icon_temp, "map": icon_map, "star": icon_star, "warning": icon_warning,
}

if __name__ == "__main__":
    C.OUTLINE = 0.025
    C.LIGHT_DIR = Vector((-0.55, -0.6, 0.6)).normalized()
    sc, cam = C.setup_scene(samples=32)
    cam.rotation_euler = (math.radians(78), 0, 0)
    for name, build in ICONS.items():
        if ONLY and name not in ONLY:
            continue
        C.clear_objects()
        build()
        sc.render.resolution_x = SIZE
        sc.render.resolution_y = SIZE
        cam.data.ortho_scale = 1.55
        cam.location = (0, -10 * math.sin(math.radians(78)), 10 * math.cos(math.radians(78)))
        sc.render.filepath = os.path.join(OUT, "icon_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDERED", name)
    print("DONE")

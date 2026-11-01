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


def pivoted(loc, rot, build):
    """Run build() around the origin, then move and turn everything it made as one piece."""
    before = set(bpy.data.objects)
    build()
    p = bpy.data.objects.new("pivot", None)
    bpy.context.scene.collection.objects.link(p)
    for o in set(bpy.data.objects) - before:
        if o.parent is None and o is not p:
            o.parent = p
    p.location, p.rotation_euler = loc, rot
    return p


def lump(name, r, mat, loc, scale, seed=0, sub=1):
    """Faceted low-poly rock / hill with a flat underside."""
    from mathutils import noise
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        v.co *= 1.0 + noise.noise(v.co * 3.0 + Vector((seed, seed * 0.7, 0))) * 0.12
        if v.co.z < 0:
            v.co.z *= 0.15
    return C.finish(name, bm, mat, loc, (0, 0, 0), scale, smooth=False)


def icon_data():
    box("chip", -0.42, -0.42, 0.42, 0.42, -0.08, 0.08, M("2c3440"), bevel=0.06)
    gold = M("d8b060", light=1.3)
    for k in range(4):
        t = -0.27 + k * 0.18
        for x0, z0, x1, z1 in ((t - 0.045, 0.42, t + 0.045, 0.6), (t - 0.045, -0.6, t + 0.045, -0.42),
                               (0.42, t - 0.045, 0.6, t + 0.045), (-0.6, t - 0.045, -0.42, t + 0.045)):
            box("pin", x0, z0, x1, z1, -0.04, 0.04, gold)
    box("core", -0.25, -0.25, 0.25, 0.25, -0.11, -0.08, M("3fd8c2", glow=1.5), outline=False)
    trace = M("1a6e66", ao=0.0)
    for x0, z0, x1, z1 in ((-0.18, 0.08, 0.04, 0.12), (0.0, -0.18, 0.04, 0.12), (0.04, -0.06, 0.18, -0.02), (-0.18, -0.14, -0.04, -0.1)):
        box("trace", x0, z0, x1, z1, -0.12, -0.11, trace, outline=False)
    sphere("node", 0.035, M("e8fffa", glow=1.8), (-0.18, -0.12, 0.1), outline=False)
    sphere("node", 0.035, M("e8fffa", glow=1.8), (0.18, -0.12, -0.04), outline=False)


def icon_flask():
    glass = M("d4ecf4", light=1.2)
    cylinder("liquid", 0.47, 0.32, M("5fd07a", light=1.3), (0, 0, -0.42), r2=0.34)
    cylinder("glass", 0.34, 0.36, glass, (0, 0, -0.08), r2=0.14)
    cylinder("neck", 0.14, 0.34, glass, (0, 0, 0.27))
    torus("lip", 0.15, 0.045, M("eef8fb"), (0, 0, 0.44), outline=True)
    for x, z, r in ((-0.14, -0.42, 0.05), (0.1, -0.36, 0.035), (0.02, -0.5, 0.03)):
        sphere("bubble", r, M("e8fff0", glow=1.2), (x, -0.42, z), outline=False)
    box("shine", -0.2, -0.2, -0.16, 0.0, -0.3, -0.27, M("ffffff", glow=1.0), outline=False).rotation_euler = (0, -0.5, 0)


def icon_medkit():
    box("case", -0.58, -0.42, 0.58, 0.32, -0.26, 0.26, M("eeeae2"), bevel=0.08)
    torus("handle", 0.17, 0.05, M("8a8f96"), (0, 0, 0.33), rot=(math.pi / 2, 0, 0), outline=True)
    box("seam", -0.58, 0.14, 0.58, 0.165, -0.27, -0.26, M("bdb6aa", ao=0.0), outline=False)
    red = M("e0402a")
    box("cross_v", -0.08, -0.33, 0.08, 0.07, -0.29, -0.26, red)
    box("cross_h", -0.22, -0.21, 0.22, -0.05, -0.29, -0.26, red)


def icon_crate():
    wood = M("b07a44")
    board = M("c8905a", light=1.2)
    box("crate", -0.46, -0.52, 0.46, 0.36, -0.32, 0.32, wood, bevel=0.03)
    for z in (-0.24, 0.06):
        box("gap", -0.38, z, 0.38, z + 0.025, -0.33, -0.32, M("6a4424", ao=0.0), outline=False)
    for x0, z0, x1, z1 in ((-0.46, 0.25, 0.46, 0.36), (-0.46, -0.52, 0.46, -0.41), (-0.46, -0.52, -0.35, 0.36), (0.35, -0.52, 0.46, 0.36)):
        box("board", x0, z0, x1, z1, -0.36, -0.32, board)
    brace = box("brace", -0.5, -0.055, 0.5, 0.055, -0.35, -0.32, board)
    brace.location = (0, -0.34, -0.08)
    brace.rotation_euler = (0, -math.atan2(0.77, 0.7), 0)
    for x, z in ((-0.4, 0.3), (0.4, 0.3), (-0.4, -0.46), (0.4, -0.46)):
        sphere("nail", 0.025, M("4a3a30"), (x, -0.37, z), outline=False, seg=8)


def icon_raider():
    metal = M("7c828a", light=1.3)
    rust = M("a8602e", ao=0.0)
    for k, a in enumerate((-0.75, -0.38, 0.0, 0.38, 0.75)):
        h = 0.3 if k == 2 else 0.24
        cylinder("spike", 0.065, h, M("c9a560", light=1.25), (math.sin(a) * (0.4 + h / 2), 0.05, 0.05 + math.cos(a) * (0.4 + h / 2)), rot=(0, a, 0), r2=0.0, seg=12)
    sphere("dome", 0.46, metal, (0, 0, 0.02), scale=(1, 0.95, 0.92))
    sphere("rust", 0.1, rust, (-0.22, -0.34, 0.22), scale=(1, 0.3, 0.7), outline=False)
    sphere("dent", 0.07, M("5a6068", ao=0.0), (0.2, -0.38, 0.2), scale=(1, 0.3, 0.8), outline=False)
    box("plate", -0.38, -0.5, 0.38, 0.02, -0.5, -0.28, M("5e646c"), bevel=0.06)
    box("visor", -0.3, -0.17, 0.3, -0.05, -0.52, -0.5, M("ff5a30", glow=1.5), outline=False)
    for x in (-0.15, -0.05, 0.05, 0.15):
        box("grille", x - 0.018, -0.44, x + 0.018, -0.25, -0.52, -0.5, M("2a2c31", ao=0.0), outline=False)
    for x in (-0.31, 0.31):
        for z in (-0.4, -0.06):
            sphere("rivet", 0.03, M("c8ccd2"), (x, -0.52, z), outline=False, seg=8)


def arc_arrow(name, r, w, a0, a1, mat):
    d = 1 if a1 > a0 else -1
    n = 14
    outer = [((r + w) * math.cos(a0 + (a1 - a0) * i / n), (r + w) * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    inner = [((r - w) * math.cos(a0 + (a1 - a0) * i / n), (r - w) * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n, -1, -1)]
    head = [((r + w * 2.6) * math.cos(a1), (r + w * 2.6) * math.sin(a1)), (r * math.cos(a1 + d * 0.5), r * math.sin(a1 + d * 0.5)),
            ((r - w * 2.6) * math.cos(a1), (r - w * 2.6) * math.sin(a1))]
    prism(name, outer + head + inner, -0.08, 0.08, mat)


def icon_trade():
    arc_arrow("arrow_top", 0.42, 0.075, math.radians(165), math.radians(30), M("f0b84a", light=1.3))
    arc_arrow("arrow_bot", 0.42, 0.075, math.radians(-15), math.radians(-150), M("3fb8a8", light=1.3))


def icon_rail():
    steel, shine, tie = M("7d838c", light=1.3), M("dfe4ea", ao=0.0), M("7a5030")

    def piece(x0, x1, offs, right):
        """Head, web and foot each snap at a slightly different x, so the break looks torn."""
        for (z0, z1, hw), o in zip(((0.06, 0.17, 0.08), (-0.1, 0.06, 0.03), (-0.16, -0.1, 0.15)), offs):
            if right:
                pts = [(x0, z0), (x1 + o, z0), (x1 + o - 0.04, z1), (x0, z1)]
            else:
                pts = [(x0 + o + 0.04, z0), (x1, z0), (x1, z1), (x0 + o, z1)]
            prism("rail", pts, -hw, hw, steel)
        box("head_shine", x0 + 0.06, 0.165, x1 - 0.06, 0.18, -0.06, 0.06, shine, outline=False)

    def build():
        box("tie", -0.62, -0.3, -0.36, -0.16, -0.36, 0.36, tie, bevel=0.02)
        box("tie", 0.3, -0.3, 0.56, -0.16, -0.36, 0.36, tie, bevel=0.02)
        piece(-0.78, -0.04, (0.0, -0.05, 0.04), True)
        pivoted((0.1, 0, 0.0), (0, -0.22, 0), lambda: piece(0.0, 0.62, (0.0, 0.05, -0.03), False))

    pivoted((0.04, 0, 0.08), (0.42, 0, -0.95), build)


def icon_ash():
    ash = M("8e8a94", light=1.2)
    for x, z, r in ((-0.3, 0.02, 0.25), (0.02, 0.14, 0.32), (0.32, 0.03, 0.24), (-0.12, -0.12, 0.24), (0.17, -0.12, 0.24)):
        sphere("puff", r, ash, (x, -0.05 if r < 0.3 else 0.05, z), scale=(1, 0.8, 0.85))
    for x, z, r in ((-0.25, -0.42, 0.04), (0.02, -0.5, 0.035), (0.24, -0.4, 0.04), (-0.08, -0.62, 0.03), (0.15, -0.6, 0.03)):
        sphere("flake", r, M("4e4a52"), (x, -0.2, z), outline=False, seg=8)
    sphere("ember", 0.035, M("ff7a3a", glow=1.6), (-0.1, -0.25, -0.44), outline=False, seg=8)


def icon_desal():
    wall, band = M("5f7a86"), M("66ffe8", glow=1.4)
    for x, r, h in ((-0.32, 0.27, 0.62), (0.04, 0.2, 0.46)):
        cylinder("tank", r, h, wall, (x, 0.08, -0.6 + h / 2))
        cylinder("dome", r, 0.1, wall, (x, 0.08, -0.6 + h + 0.05), r2=r * 0.45)
        cylinder("band", r + 0.012, 0.04, band, (x, 0.08, -0.6 + h * 0.55), outline=False)
    box("tower", 0.3, -0.6, 0.44, 0.42, -0.07, 0.07, M("4a5a64"))
    box("tower_head", 0.22, 0.4, 0.52, 0.54, -0.1, 0.1, wall)
    sphere("light", 0.05, M("b0ffff", glow=2.0), (0.37, 0, 0.6), outline=False)
    cylinder("pipe", 0.045, 0.6, M("8aa4ae"), (-0.05, -0.2, -0.48), rot=(0, math.pi / 2, 0))
    teardrop("drop", 0.12, M("4fb4ff", light=1.3), (-0.5, -0.3, 0.35))


def icon_mirror():
    cylinder("shaft", 0.09, 0.98, M("4a5a64"), (0, 0.15, -0.13), r2=0.06)
    cylinder("receiver", 0.15, 0.22, M("fff0b0", glow=2.0), (0, 0.15, 0.45))
    cylinder("cap", 0.11, 0.06, M("4a5a64"), (0, 0.15, 0.59))
    for k in range(8):
        a = k * math.pi / 4
        cylinder("ray", 0.025, 0.12, M("ffd870", glow=1.3), (math.cos(a) * 0.27, 0.15, 0.45 + math.sin(a) * 0.27), rot=(0, math.pi / 2 - a, 0), outline=False, r2=0.0)

    def heliostat():
        box("frame", -0.2, -0.12, 0.2, 0.12, -0.02, 0.02, M("6a8a96"))
        box("face", -0.17, -0.09, 0.17, 0.09, -0.04, -0.02, M("c4ecff", light=1.3), outline=False)

    for s in (-1, 1):
        box("post", s * 0.42 - 0.025, -0.62, s * 0.42 + 0.025, -0.38, -0.1, -0.05, M("3a4a52"))
        pivoted((s * 0.42, -0.1, -0.33), (-0.6, s * 0.45, 0), heliostat)


def icon_archive():
    lump("rock", 0.6, M("6a5a52"), (0, 0.2, -0.6), (1.05, 0.7, 1.75), seed=3)
    box("portal", -0.32, -0.62, 0.32, 0.08, -0.45, -0.25, M("8a9296"), bevel=0.03)
    torus("rim", 0.22, 0.04, M("c9a560"), (0, -0.46, -0.27), rot=(math.pi / 2, 0, 0), outline=True)
    cylinder("open", 0.2, 0.02, M("6aff9a", glow=1.4), (0, -0.46, -0.27), rot=(math.pi / 2, 0, 0), outline=False)
    box("sign", -0.14, -0.02, 0.14, 0.05, -0.47, -0.45, M("2a3a30", ao=0.0), outline=False)
    for x in (-0.38, 0.36):
        sphere("bush", 0.09, M("5cbf5a"), (x, -0.5, -0.58), scale=(1.3, 1, 1))


def icon_haven():
    lump("hill", 0.62, M("6a9a3c"), (0, 0.2, -0.62), (1.15, 0.7, 0.75), seed=5, sub=2)
    box("walls", -0.32, -0.3, 0.06, 0.02, -0.15, 0.1, M("c9a07a"))
    prism("roof", [(-0.4, 0.0), (0.14, 0.0), (-0.13, 0.24)], -0.18, 0.13, M("a0402a"))
    box("window", -0.12, -0.2, -0.02, -0.1, -0.16, -0.15, M("ffd890", glow=1.0), outline=False)
    box("door", -0.26, -0.3, -0.17, -0.12, -0.16, -0.15, M("5a3a24"), outline=False)
    cylinder("mast", 0.035, 0.9, M("d8dcd6"), (0.36, 0.1, -0.03), r2=0.022)
    for k in range(3):
        a = math.radians(80 + k * 120)
        pts = [(0, -0.03), (0.3, -0.01), (0.3, 0.01), (0.06, 0.045)]
        pts = [(0.36 + x * math.cos(a) - z * math.sin(a), 0.42 + x * math.sin(a) + z * math.cos(a)) for x, z in pts]
        prism("blade", pts, 0.03, 0.05, M("eef0ec"))
    sphere("hub", 0.04, M("6a8a96"), (0.36, 0.02, 0.42), outline=False)
    sphere("tree", 0.15, M("5e8a3a"), (-0.5, 0.05, -0.12), scale=(1, 1, 0.9))
    cylinder("trunk", 0.03, 0.2, M("4a3424"), (-0.5, 0.06, -0.3))


def icon_trophy():
    gold = M("f0b84a", light=1.3)
    cylinder("cup", 0.2, 0.46, gold, (0, 0, 0.2), r2=0.38, seg=32)
    torus("rim", 0.38, 0.04, M("ffd27a"), (0, 0, 0.43), outline=True)
    for s in (-1, 1):
        torus("handle", 0.13, 0.04, gold, (s * 0.36, 0, 0.22), rot=(math.pi / 2, 0, 0), outline=True)
    cylinder("stem", 0.06, 0.22, gold, (0, 0, -0.12))
    sphere("knob", 0.09, gold, (0, 0, -0.06), scale=(1, 1, 0.8))
    cylinder("foot", 0.2, 0.06, gold, (0, 0, -0.25))
    box("base", -0.3, -0.6, 0.3, -0.28, -0.22, 0.22, M("6a4630"), bevel=0.03)
    box("plate", -0.16, -0.5, 0.16, -0.38, -0.23, -0.22, M("f0b84a", ao=0.0), outline=False)
    pts = [(math.cos(math.pi / 2 + i * math.pi / 5) * (0.11 if i % 2 == 0 else 0.045), 0.2 + math.sin(math.pi / 2 + i * math.pi / 5) * (0.11 if i % 2 == 0 else 0.045)) for i in range(10)]
    prism("star", pts, -0.36, -0.33, M("fff2b0", glow=1.1), outline=False)


def icon_heart():
    # Two lobes and a soft point, as one outline (round lobes keep the chamfer clean).
    pts = []
    for i in range(25):
        a = math.radians(-38 + 218 * i / 24)
        pts.append((0.26 + 0.29 * math.cos(a), 0.16 + 0.29 * math.sin(a)))
    for i in range(25):
        a = math.radians(0 + 218 * i / 24)
        pts.append((-0.26 + 0.29 * math.cos(a), 0.16 + 0.29 * math.sin(a)))
    pts = pts[:25] + pts[25:]
    pts += [(-0.06, -0.47), (0.0, -0.53), (0.06, -0.47)]
    C.slab("heart", pts, -0.13, 0.13, M("e0402a", light=1.25), chamfer=0.05, outline=True)
    teardrop("drop", 0.085, M("8fe6ff", light=1.25, ao=0.0), (-0.27, -0.2, 0.2), point=1.8)
    sphere("shine", 0.05, M("ffffff", glow=1.0), (-0.15, -0.21, 0.33), outline=False, seg=10)


def icon_snowflake():
    ice = M("a8e6ff", light=1.3)
    for k in range(3):
        a = math.pi / 2 + k * math.pi / 3
        C.slab("arm", C.stroke_poly([(-math.cos(a) * 0.56, -math.sin(a) * 0.56), (math.cos(a) * 0.56, math.sin(a) * 0.56)], 0.13), -0.07, 0.07, ice, chamfer=0.025, outline=True)
    for k in range(6):
        a = math.pi / 2 + k * math.pi / 3
        tip = (math.cos(a) * 0.32, math.sin(a) * 0.32)
        for sgn in (-1, 1):
            b = a + sgn * 0.8
            C.slab("branch", C.stroke_poly([tip, (tip[0] + math.cos(b) * 0.21, tip[1] + math.sin(b) * 0.21)], 0.1), -0.07, 0.07, ice, chamfer=0.02, outline=True)
    C.slab("hub", [(math.cos(math.pi / 6 + k * math.pi / 3) * 0.13, math.sin(math.pi / 6 + k * math.pi / 3) * 0.13) for k in range(6)], -0.1, 0.06,
           M("e8f8ff", light=1.2), chamfer=0.02, outline=True)


def icon_undo():
    arc_arrow("undo", 0.36, 0.095, math.radians(-50), math.radians(195), M("f0b84a", light=1.3))
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.location.z -= 0.04


def icon_tank():
    glass, steel = M("d4ecf4", light=1.2), M("6a7a88", light=1.3)
    cylinder("base", 0.36, 0.14, M("3a414b", light=1.25), (-0.06, 0, -0.55))
    cylinder("coolant", 0.3, 0.5, M("3fd8c2", light=1.3), (-0.06, 0.0, -0.23))
    cylinder("surface", 0.3, 0.03, M("8ff4e4", ao=0.0), (-0.06, 0.0, 0.03), outline=False)
    cylinder("glass", 0.3, 0.36, glass, (-0.06, 0.0, 0.2))
    cylinder("collar", 0.33, 0.1, steel, (-0.06, 0, 0.42))
    cylinder("collar_b", 0.33, 0.08, steel, (-0.06, 0, -0.46))
    box("shine", -0.27, -0.38, -0.22, 0.32, -0.31, -0.29, M("ffffff", glow=1.0), outline=False)
    for z in (-0.25, 0.0, 0.2):
        box("tick", 0.1, z, 0.18, z + 0.025, -0.31, -0.29, M("2a5a64", ao=0.0), outline=False)
    for x, z, r in ((-0.1, -0.36, 0.04), (0.04, -0.2, 0.03), (-0.04, -0.06, 0.025)):
        sphere("bubble", r, M("e8fff8", glow=1.1), (x, -0.3, z), outline=False, seg=8)
    cylinder("badge", 0.17, 0.06, M("f0b84a", light=1.3), (0.34, -0.3, 0.36), rot=(math.pi / 2, 0, 0), seg=24)
    plus = M("ffffff", ao=0.0)
    box("plus_v", 0.32, 0.27, 0.36, 0.45, -0.35, -0.33, plus, outline=False)
    box("plus_h", 0.25, 0.34, 0.43, 0.38, -0.35, -0.33, plus, outline=False)


def icon_condenser():
    body, fin, cold = M("5f7a86", light=1.3), M("a8d8e8", light=1.25), M("8fe6ff", glow=1.3)
    cx = -0.14
    cylinder("body", 0.19, 0.86, body, (cx, 0.05, 0.0))
    for k in range(6):
        cylinder("fin", 0.38, 0.045, fin, (cx, 0.05, -0.32 + k * 0.12), seg=28)
    cylinder("cap", 0.24, 0.12, body, (cx, 0.05, 0.42), r2=0.13)
    sphere("cap_light", 0.05, cold, (cx, 0.05, 0.5), outline=False, seg=10)
    cylinder("foot", 0.28, 0.1, M("3a414b", light=1.25), (cx, 0.05, -0.46))
    cylinder("spout", 0.05, 0.42, M("8aa4ae", light=1.3), (0.2, -0.05, -0.4), rot=(0, math.pi / 2, 0))
    cylinder("nozzle", 0.06, 0.1, M("8aa4ae", light=1.3), (0.38, -0.05, -0.45))
    teardrop("drop", 0.13, M("4fb4ff", light=1.3), (0.4, -0.12, -0.62), point=1.9)
    for x, z in ((-0.5, 0.15), (-0.5, -0.09), (-0.45, -0.25), (0.2, 0.2)):  # dew beading on the fins
        sphere("dew", 0.035, M("e8fbff", glow=1.2), (x, -0.32, z), outline=False, seg=8)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.location.z += 0.08


def icon_play():
    tri = C.fillet([(-0.36, 0.5), (-0.36, -0.5), (0.5, 0.0)], 0.1)
    C.slab("play", [(x + 0.04, z) for x, z in tri], -0.12, 0.12, M("62c95a", light=1.25), chamfer=0.06, outline=True)
    sphere("shine", 0.045, M("ffffff", glow=1.0), (-0.22, -0.2, 0.3), outline=False, seg=10)


def icon_gift():
    wood, board, ribbon = M("b07a44"), M("c8905a", light=1.2), M("e0402a", light=1.25)
    box("crate", -0.44, -0.58, 0.44, 0.16, -0.3, 0.3, wood, bevel=0.03)
    box("lid", -0.5, 0.12, 0.5, 0.3, -0.34, 0.34, board, bevel=0.03)
    for x0, x1 in ((-0.44, -0.34), (0.34, 0.44)):
        box("post", x0, -0.58, x1, 0.12, -0.33, -0.3, board)
    box("gap", -0.34, -0.22, 0.34, -0.2, -0.31, -0.3, M("6a4424", ao=0.0), outline=False)
    box("ribbon_v", -0.08, -0.58, 0.08, 0.31, -0.36, 0.36, ribbon)
    box("ribbon_h", -0.51, 0.15, 0.51, 0.27, -0.36, 0.36, ribbon, outline=False)
    for s_ in (-1, 1):
        sphere("bow", 0.15, ribbon, (s_ * 0.15, -0.05, 0.42), scale=(1.4, 0.6, 0.85), rot=(0, s_ * 0.5, 0))
        prism("tail", [(s_ * 0.02, 0.33), (s_ * 0.16, 0.33), (s_ * 0.26, 0.13), (s_ * 0.16, 0.17)], -0.1, 0.0, ribbon)
    sphere("knot", 0.08, M("ff6a4a", light=1.2), (0, -0.12, 0.37))
    for x, z in ((-0.39, -0.52), (0.39, -0.52), (-0.39, 0.05), (0.39, 0.05)):
        sphere("stud", 0.03, M("f0b84a", ao=0.0), (x, -0.34, z), outline=False, seg=8)
    sphere("sparkle", 0.05, M("fff2b0", glow=1.6), (0.36, -0.4, 0.55), outline=False, seg=8)


ICONS = {"arrow": icon_arrow, "bulb": icon_bulb,
    "scrap": icon_scrap, "parts": icon_parts, "food": icon_food, "water": icon_water, "crew": icon_crew,
    "home": icon_home, "cooling": icon_cooling, "drone": icon_drone, "train": icon_train, "tower": icon_tower,
    "wrench": icon_wrench, "hammer": icon_hammer, "bed": icon_bed, "shield": icon_shield, "sun": icon_sun,
    "temp": icon_temp, "map": icon_map, "star": icon_star, "warning": icon_warning,
    "data": icon_data, "flask": icon_flask, "medkit": icon_medkit, "crate": icon_crate, "raider": icon_raider,
    "trade": icon_trade, "rail": icon_rail, "ash": icon_ash, "desal": icon_desal, "mirror": icon_mirror,
    "archive": icon_archive, "haven": icon_haven, "trophy": icon_trophy,
    "heart": icon_heart, "snowflake": icon_snowflake, "undo": icon_undo, "tank": icon_tank,
    "condenser": icon_condenser, "play": icon_play, "gift": icon_gift,
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

"""Railhaven coolant-sort puzzle pieces, modelled and rendered in Blender.

  Blender -b --factory-startup --python art/blender/puzzle.py -- <out_dir> [only...]

Scene units are pixels (1 unit = 1 px), straight front view so pieces stack cleanly.
Outputs:
  canister_<colour>.png   128x88  coolant canister, one embossed emblem per colour
  canister_hidden.png     128x88  ash-covered unknown canister
  tank_back.png           160x420 frame, base and back glass (drawn behind canisters)
  tank_front.png          160x420 front glass and rims (drawn over canisters)
  tank_seal.png           160x420 frosted lid shown when a tank is complete
  board_bg.png            720x900 dark metal panel behind the board
Tank inner rect (where 4 canisters stack): x 16, y 38, w 128, h 352 (bottom at y 390).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import box, sphere, cylinder, zcyl, ycyl, lathe, slab, ring_slab, offset_poly, stroke_poly, fillet, spline, toon, shade  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/railhaven_puzzle"
ONLY = set(ARGS[1:])

INK = "140c0a"        # outline colour, same as the inverted hulls
STEEL = "7c8794"
STEEL_DARK = "3b424b"


def M(h, **kw):
    return toon(h, **kw)


# ---------------------------------------------------------------- emblems (unit coords, about -1..1)

def _teardrop(k=0.78, n=40):
    return [(k * math.sin(t) * math.sin(t / 2), math.cos(t) * 0.98) for t in (2 * math.pi * i / n for i in range(n))]


def _star(R=1.0, r=0.44):
    return [(math.cos(math.pi / 2 + i * math.pi / 5) * (R if i % 2 == 0 else r),
             math.sin(math.pi / 2 + i * math.pi / 5) * (R if i % 2 == 0 else r) - 0.08) for i in range(10)]


def _leaf():
    side_a, side_b = [], []
    for i in range(13):
        t = i / 12
        w = 0.5 * math.sin(math.pi * t) ** 0.85
        side_a.append((-0.78 + 1.56 * t, w))
        side_b.append((-0.78 + 1.56 * t, -w))
    pts = side_a + side_b[-2:0:-1]
    c, s = math.cos(math.pi / 4), math.sin(math.pi / 4)
    return [(x * c - z * s + 0.08, x * s + z * c + 0.04) for x, z in pts]


def _rot(path, a, d=(0, 0)):
    c, s = math.cos(a), math.sin(a)
    return [(x * c - z * s + d[0], x * s + z * c + d[1]) for x, z in path]


def _snowflake():
    parts = []
    for k in range(3):
        parts.append(("stroke", _rot([(-0.92, 0), (0.92, 0)], math.pi / 2 + k * math.pi / 3), 0.2))
    for k in range(6):
        a = math.pi / 2 + k * math.pi / 3
        tip = (math.cos(a) * 0.52, math.sin(a) * 0.52)
        for s in (-1, 1):
            b = a + s * 0.8
            parts.append(("stroke", [tip, (tip[0] + math.cos(b) * 0.34, tip[1] + math.sin(b) * 0.34)], 0.15))
    return parts


def _question():
    hook = [(0.42 * math.cos(math.radians(a)), 0.38 + 0.42 * math.sin(math.radians(a))) for a in range(165, -91, -15)]
    return [("stroke", hook + [(0.0, -0.3)], 0.27), ("poly", [(math.cos(t) * 0.17, -0.7 + math.sin(t) * 0.17) for t in (2 * math.pi * i / 20 for i in range(20))])]


FLAME = spline([(0.0, -1.0), (0.64, -0.8), (0.82, -0.32), (0.66, 0.12), (0.7, 0.58), (0.38, 0.32), (0.12, 1.0),
                (-0.28, 0.42), (-0.52, 0.64), (-0.68, 0.12), (-0.82, -0.34), (-0.62, -0.82)], n=5, sharp=(4, 6, 8))
FLAME_CORE = spline([(0.0, -0.8), (0.36, -0.6), (0.4, -0.22), (0.16, 0.18), (0.04, 0.5), (-0.18, 0.12), (-0.4, -0.22), (-0.34, -0.62)], n=5, sharp=(4,))
GEM = [(-0.92, 0.3), (-0.5, 0.78), (0.5, 0.78), (0.92, 0.3), (0.0, -0.95)]

# name: (coolant colour, emblem parts, detail parts drawn in the coolant colour on top of the emblem)
COLOURS = {
    "red":    ("e5383b", [("poly", FLAME)], [("poly", FLAME_CORE)]),
    "orange": ("f68a2a", [("poly", fillet([(0.0, 0.95), (-0.98, -0.75), (0.98, -0.75)], 0.12))], []),
    "yellow": ("f6cf35", [("poly", [(-0.05, 1.0), (0.55, 1.0), (0.12, 0.18), (0.6, 0.18), (-0.3, -1.0), (0.0, -0.15), (-0.5, -0.15)])], []),
    "lime":   ("8cd43a", [("poly", _leaf()), ("stroke", [(-0.62, -0.62), (-0.86, -0.92)], 0.14)],
               [("stroke", [(-0.5, -0.5), (0.46, 0.46)], 0.1)]),
    "teal":   ("1fc2b0", [("poly", _teardrop())], []),
    "blue":   ("3c7ef2", _snowflake(), []),
    "purple": ("a259e6", [("poly", GEM)], [("stroke", [(-0.8, 0.3), (0.8, 0.3)], 0.08), ("stroke", [(-0.3, 0.32), (0.0, -0.8)], 0.08), ("stroke", [(0.3, 0.32), (0.0, -0.8)], 0.08)]),
    "pink":   ("f26bb6", [("poly", _star())], []),
    "white":  ("e6edf2", [("ring", 0.0, 0.0, 0.48, 0.92)], []),
}


def emblem(parts, s, cx, cz, yf, col, edge=1.7, chamfer=1.3, details=(), detail_col=None):
    """Raised emblem with a dark ink border, built from polygons, strokes and rings.
    The border is a grown copy behind the face, so overlapping parts merge without seams."""
    ink, face = M(INK, glow=1.0), M(col, light=1.18, shadow=0.72, ao=0.0)
    for kind, *a in parts:
        if kind == "ring":
            x, z, r0, r1 = a
            ring_slab("emb", cx + x * s, cz + z * s, r0 * s, r1 * s, yf, yf + 14, face, chamfer=chamfer)
            ring_slab("emb_ink", cx + x * s, cz + z * s, r0 * s - edge, r1 * s + edge, yf + 0.4, yf + 14, ink)
            continue
        if kind == "poly":
            pts = [(cx + x * s, cz + z * s) for x, z in a[0]]
            ink_pts = offset_poly(pts, edge)
        else:
            path = [(cx + x * s, cz + z * s) for x, z in a[0]]
            pts, ink_pts = stroke_poly(path, a[1] * s), stroke_poly(path, a[1] * s + 2 * edge)
        slab("emb", pts, yf, yf + 14, face, chamfer=chamfer)
        slab("emb_ink", ink_pts, yf + 0.4, yf + 14, ink)
    for kind, *a in details:
        dm = M(detail_col, ao=0.0, shadow=0.85)
        if kind == "poly":
            slab("emb_detail", [(cx + x * s, cz + z * s) for x, z in a[0]], yf - chamfer - 0.4, yf + 4, dm)
        else:
            slab("emb_detail", stroke_poly([(cx + x * s, cz + z * s) for x, z in a[0]], a[1] * s), yf - chamfer - 0.4, yf + 4, dm)


# ---------------------------------------------------------------- canister

R_CAP, R_BODY = 57.5, 54.5
Z_TOP = 41.0
Z_BODY = 30.0


def cap_profile(flip):
    """Top cap: collar, straight band, rounded shoulder, flat lid (mirrored for the bottom)."""
    s = -1 if flip else 1
    prof = [(0.0, s * Z_BODY), (R_CAP - 1.0, s * Z_BODY), (R_CAP, s * (Z_BODY + 1.0)), (R_CAP, s * (Z_TOP - 7.0))]
    for k in range(1, 7):
        a = k * (math.pi / 2) / 6
        prof.append((R_CAP - 7.0 + 7.0 * math.cos(a), s * (Z_TOP - 7.0 + 7.0 * math.sin(a))))
    prof += [(R_CAP - 12.0, s * Z_TOP), (0.0, s * Z_TOP)]
    return prof if not flip else prof[::-1]


def canister_shell(cap_col, body_mat):
    metal = M(cap_col, light=1.3, shadow=0.62)
    lathe("cap_top", cap_profile(False), metal)
    lathe("cap_bot", cap_profile(True), metal)
    zcyl("body", R_BODY, -Z_BODY - 1, Z_BODY + 1, 0, 0, body_mat, seg=64)
    dark = M(STEEL_DARK, ao=0.0)
    for s in (-1, 1):  # dark collar where the glass body meets each cap
        zcyl("collar", R_BODY + 1.2, s * Z_BODY - 1.6, s * Z_BODY + 1.6, 0, 0, dark, outline=False, seg=64)
        for x in (-40.0, -20.0, 0.0, 20.0, 40.0):  # bolt heads around each cap band
            sphere("bolt", 1.9, M(shade(cap_col, 1.25), ao=0.0), (x, -math.sqrt(R_CAP ** 2 - x ** 2) - 0.6, s * (Z_BODY + 3.6)), outline=False, seg=10)
    return metal


def canister(name):
    col, parts, details = COLOURS[name]
    body = M(col, light=1.22, shadow=0.74, ao=0.0)
    canister_shell(STEEL, body)
    # Glass sheen on the lit side and a few bubbles on the shaded side.
    sheen = M(shade(col, 1.6), glow=1.0)
    for x, z0, z1, w in ((-45.5, -17.0, 19.0, 4.6), (-38.5, 9.0, 19.0, 2.0)):
        y = -math.sqrt(R_BODY ** 2 - x ** 2) - 0.6
        slab("sheen", stroke_poly([(x, z0), (x, z1)], w), y, y + 1, sheen)
    # Back-light rim on the shaded edge so the coolant reads as lit liquid behind glass.
    slab("rim_light", stroke_poly([(50.6, -21.0), (50.6, 21.0)], 1.8), -21.4, -20.4, M(shade(col, 1.3), glow=1.0))
    for x, z, r in ((42.0, -14.0, 2.6), (46.5, -4.0, 1.7), (40.5, 6.0, 1.3)):
        y = -math.sqrt(R_BODY ** 2 - (x - r) ** 2) - 0.6
        ring_slab("bubble", x, z, r - 0.9, r, y, y + 1, M(shade(col, 1.45), glow=1.0))
    face = {"yellow": "fff7d6", "white": "8aa0b3"}.get(name, shade(col, 1.72))
    emblem(parts, 21.0, 0.0, 0.0, -R_BODY - 1.6, face, details=details, detail_col=shade(col, 0.95))


def canister_hidden():
    ash, ash_dark = "77737c", "57535c"
    body = M(ash_dark, light=1.18, shadow=0.7)
    canister_shell("6d6a72", body)
    lump = M("8e8a94", light=1.2, shadow=0.7)
    # Ash drifts on the cap shoulders and streaks down the body, kept inside the silhouette.
    for x, z, sx, sz in ((-38, 35, 12, 4.5), (-14, 37, 15, 3.6), (16, 36.5, 13, 4.2), (40, 34.5, 10, 4.0), (-46, -34, 8, 4), (30, -36, 12, 3.5)):
        y = -math.sqrt(max(1.0, R_CAP ** 2 - x ** 2)) + 3
        sphere("ash", 1.0, lump, (x, y, z), scale=(sx, 5, sz), outline=False, seg=14)
    for x, z0, z1, w in ((-28, 8, 26, 6), (22, 2, 26, 5), (40, 14, 26, 4)):
        y = -math.sqrt(R_BODY ** 2 - x ** 2) - 0.2
        sphere("streak", 1.0, M(ash, ao=0.0, shadow=0.8), (x, y, (z0 + z1) / 2), scale=(w / 2, 2, (z1 - z0) / 2), outline=False, seg=14)
    # Crusted ash patches over the glass, with darker soot under them.
    crust = M("8b8791", light=1.16, shadow=0.72, ao=0.0)
    soot = M("3e3a42", glow=1.0)
    for cx, cz, rx, rz, seed in ((-36, 24, 15, 7, 0), (30, -25, 17, 6, 1), (40, 22, 9, 6, 2), (-44, -20, 9, 8, 3)):
        blob = [(cx + rx * math.cos(t) * (1 + 0.18 * math.sin(3 * t + seed)), cz + rz * math.sin(t) * (1 + 0.2 * math.cos(2 * t + seed)))
                for t in (2 * math.pi * i / 10 for i in range(10))]
        y = -math.sqrt(R_BODY ** 2 - max(0.0, abs(cx) - rx * 1.2) ** 2) - 1.0
        slab("ash_soot", offset_poly(spline(blob, n=3), 1.2), y - 2.0, y + 30, soot)
        slab("ash_crust", spline(blob, n=3), y - 2.6, y + 30, crust, chamfer=1.0)
    for x, z in ((-44, -2), (36, -8), (-20, 20)):
        sphere("ember", 1.2, M("ff7a3a", glow=1.5), (x, -math.sqrt(R_BODY ** 2 - x ** 2) - 1, z), outline=False, seg=8)
    emblem(_question(), 26.0, 0.0, 2.0, -R_BODY - 1.6, "d9d5de")


# ---------------------------------------------------------------- tank (x 0..160, z 0..420, z up)

CX = 80.0
IN_X0, IN_X1, IN_Z0, IN_Z1 = 16.0, 144.0, 30.0, 382.0   # canister stack area; image rect x16 y38 w128 h352
R_GLASS = 66.0


def glass(hexcol, alphas, cuts=(0.5, 0.82), name="glass"):
    """Unlit see-through material: alpha steps up in bands towards grazing angles (cel glass)."""
    m = C._new_mat(name)
    nt = m.node_tree
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    mix = nt.nodes.new("ShaderNodeMixShader")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = C.lin(hexcol)
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.5
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (alphas[0],) * 3 + (1.0,)
    els[1].position, els[1].color = cuts[0], (alphas[1],) * 3 + (1.0,)
    e = els.new(cuts[1])
    e.color = (alphas[2],) * 3 + (1.0,)
    nt.links.new(lw.outputs["Facing"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    m.surface_render_method = "BLENDED"
    m.use_backface_culling = True
    return m


def collar(name, z0, z1, r_out, mat, lip=2.0):
    """Metal band around the glass with rounded top and bottom edges."""
    prof = [(r_out - 8, z0), (r_out - lip, z0)]
    for k in range(1, 5):
        a = -math.pi / 2 + k * (math.pi / 2) / 4
        prof.append((r_out - lip + lip * math.cos(a), z0 + lip + lip * math.sin(a)))
    for k in range(1, 5):
        a = k * (math.pi / 2) / 4
        prof.append((r_out - lip + lip * math.cos(a), z1 - lip + lip * math.sin(a)))
    prof += [(r_out - 8, z1), (r_out - 8, z0)]
    return lathe(name, prof, mat, (CX, 0, 0), smooth=True)


def tank_back():
    frame, dark = M("39414b", light=1.3, shadow=0.62), M("232830", light=1.25)
    # Plinth the stack stands on.
    box("plinth", 3, 0, 157, 23, -8, 40, dark, bevel=4)
    box("plinth_panel", 26, 5, 134, 16, -8.7, -7.9, M("171b20", ao=0.0), outline=False)
    box("plinth_led", 58, 9.5, 102, 12, -9.0, -8.6, M("2fa8a0", glow=1.0), outline=False)
    for x in (12.0, 148.0):
        ycyl("plinth_bolt", 2.4, 1.0, M("6a7480", ao=0.0), x, 11.5, -8.6, outline=False, seg=12)
    # Frame posts either side of the glass.
    for x in (7.5, 152.5):
        zcyl("post", 4.6, 20, 398, x, 0, frame, seg=20)
        sphere("finial", 5.6, frame, (x, 0, 400), scale=(1, 1, 0.8), seg=20)
        for z in (IN_Z0 + 88, IN_Z0 + 176, IN_Z0 + 264):
            zcyl("post_band", 5.4, z - 2.5, z + 2.5, x, 0, dark, seg=20)
    # Back half of the glass, seen from inside: darker at the curved edges.
    bm = C.bmesh.new()
    C.bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=64, radius1=R_GLASS, radius2=R_GLASS, depth=IN_Z1 - IN_Z0)
    C.bmesh.ops.reverse_faces(bm, faces=bm.faces)
    C.finish("glass_back", bm, glass("0c2731", (0.42, 0.55, 0.72), cuts=(0.55, 0.85)), (CX, 0, (IN_Z0 + IN_Z1) / 2), outline=False)
    slab("back_sheen", stroke_poly([(112, 60), (112, 350)], 7.0), 20, 21, glass("bfefff", (0.07, 0.07, 0.07)))
    # Slot marks on the back wall between the four canister positions.
    tick = glass("8fe0ee", (0.5, 0.5, 0.5))
    for k in range(1, 4):
        z = IN_Z0 + 88 * k
        for x0, x1 in ((19, 25), (135, 141)):
            slab("tick", stroke_poly([(x0, z), (x1, z)], 2.0), 30, 31, tick)


def tank_front():
    g = glass("d4f2fb", (0.16, 0.24, 0.44), cuts=(0.5, 0.84))
    bm = C.bmesh.new()
    C.bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=64, radius1=R_GLASS, radius2=R_GLASS, depth=IN_Z1 - IN_Z0)
    C.finish("glass_front", bm, g, (CX, 0, (IN_Z0 + IN_Z1) / 2), outline=False)
    shine = glass("ffffff", (0.42, 0.42, 0.42))
    soft = glass("ffffff", (0.3, 0.3, 0.3))
    slab("streak", stroke_poly([(29, 52), (29, 364)], 6.0), -80, -79, shine)
    slab("streak", stroke_poly([(38, 70), (38, 300)], 2.2), -80, -79, soft)
    slab("streak", stroke_poly([(132, 90), (132, 250)], 2.2), -80, -79, soft)
    slab("glint", stroke_poly([(29, 372), (29, 376)], 6.0), -80, -79, shine)
    steel = M("5f6a76", light=1.3, shadow=0.6)
    collar("collar_top", IN_Z1 + 0.5, IN_Z1 + 15, 73, steel)
    collar("collar_lip", IN_Z1 + 14, IN_Z1 + 18, 70, M("4a535e", light=1.3))
    collar("collar_bot", 21, IN_Z0, 73, steel)
    for z in (IN_Z1 + 7.8, 25.5):
        for x in (-52.0, -26.0, 0.0, 26.0, 52.0):
            sphere("rivet", 1.8, M("aab4be", ao=0.0), (CX + x, -math.sqrt(73 ** 2 - x ** 2) - 0.4, z), outline=False, seg=10)
    # Slim glass-edge rims joining the two collars.
    for x0, x1 in ((12.0, 16.0), (144.0, 148.0)):
        box("rim", x0, IN_Z0, x1, IN_Z1 + 1, -30, -24, M("4a535e", light=1.3))


def tank_seal():
    """Frosted lid clamped over the mouth of a finished tank, with a cold blue glow."""
    lid = M("a3c6d8", light=1.22, shadow=0.66)
    frost = M("eef9ff", light=1.06, shadow=0.84, ao=0.0)
    # Soft cold aura behind the lid (stepped alpha discs).
    for k, (sx, sz, a) in enumerate(((80, 21, 0.14), (75, 17, 0.16), (70, 13, 0.2))):
        sphere("aura", 1.0, glass("6fdcff", (a, a, a)), (CX, 90 - k * 5, 398), scale=(sx, 1, sz), outline=False, seg=48)
    prof = [(0.0, 378.0), (75.0, 378.0), (77.0, 380.0), (77.0, 393.0), (75.0, 396.0), (66.0, 403.0), (48.0, 408.5), (24.0, 410.5), (0.0, 411.0)]
    lathe("lid", prof, lid, (CX, 0, 0))
    lathe("lid_band", [(0.0, 384.0), (78.2, 384.0), (78.2, 389.0), (0.0, 389.0)], M("74e0ff", glow=1.5), (CX, 0, 0), outline=False)
    lathe("lid_rim", [(0.0, 378.0), (77.6, 378.0), (77.6, 381.0), (0.0, 381.0)], M("5f7f90", light=1.2), (CX, 0, 0), outline=False)
    # Clamps hooked over the top collar either side.
    for s in (-1, 1):
        x = CX + s * 73
        box("clamp", x - 5.5, 362, x + 5.5, 398, -16, 16, M("353d47", light=1.3), bevel=2)
        box("clamp_hook", x - s * 5.5 - 3, 362, x - s * 5.5 + 3, 368, -14, 14, M("353d47", light=1.3), bevel=1.2)
        box("clamp_latch", x - 2.5, 370, x + 2.5, 392, -17.4, -15.8, M("74e0ff", glow=1.3), outline=False)
    # Snow cap over the dome with a drippy lower edge, a few clumps on top, thin icicles.
    dome = [(-77.0, 393.0), (-75.0, 396.0), (-66.0, 403.0), (-48.0, 408.5), (-24.0, 410.5), (0.0, 411.0),
            (24.0, 410.5), (48.0, 408.5), (66.0, 403.0), (75.0, 396.0), (77.0, 393.0)]
    cap = [(CX + x, z + 1.6) for x, z in dome]

    def dome_z(x):
        for (xa, za), (xb, zb) in zip(dome, dome[1:]):
            if xa <= x <= xb:
                return za + (zb - za) * (x - xa) / (xb - xa)
        return dome[0][1]

    drips = [(CX + x, min(400.0 - d, dome_z(x) - 2.5)) for x, d in ((74, 0), (64, 3), (56, 0.5), (46, 5.5), (36, 1), (22, 2.5), (8, 0), (-6, 4),
                                                                   (-18, 1), (-32, 6), (-44, 1.5), (-56, 3.5), (-66, 0.5), (-74, 1))]
    slab("snow", cap + drips, -86, -40, frost, chamfer=1.4, outline=True)
    for x, z, r in ((-52, 409.5, 4.2), (-30, 412.5, 4.8), (-6, 413.2, 3.8), (18, 413, 4.6), (42, 411, 4.2), (62, 406.5, 3.4)):
        sphere("clump", r, frost, (CX + x, -20, z), scale=(1.5, 1.0, 0.8), seg=16)
    for x, h in ((-63, 7), (-47, 12), (-24, 9), (-2, 6), (13, 13), (33, 8), (54, 11)):
        cylinder("icicle", 1.9, h, M("cdefff", light=1.1, shadow=0.8, ao=0.0), (CX + x, -math.sqrt(77 ** 2 - x ** 2) - 1, 378.5 - h / 2), rot=(math.pi, 0, 0), r2=0.2, seg=10)
    for x, z, r in ((-40, 404.5, 3.6), (30, 405.5, 2.8), (58, 399.5, 2.4)):  # sparkle glints
        slab("sparkle", [(CX + x + dx * r, z + dz * r) for dx, dz in ((0, 1), (0.22, 0.22), (1, 0), (0.22, -0.22), (0, -1), (-0.22, -0.22), (-1, 0), (-0.22, 0.22))],
             -90, -89, M("ffffff", glow=1.2))
    ycyl("badge_ring", 11, 2, M("5f7f90", light=1.25), CX, 395, -89, seg=32)
    ycyl("badge", 9, 2, M("2a7fa8", glow=1.0), CX, 395, -90, outline=False, seg=32)
    emblem(_snowflake(), 7.2, CX, 395, -93, "eafcff", edge=1.1, chamfer=0.6)


# ---------------------------------------------------------------- board background (720x900)

def board_bg():
    """Dark riveted wall plates in the carriage-interior palette, low contrast so pieces pop."""
    box("base", -10, -10, 730, 910, 20, 22, M("0e1418", glow=1.0), outline=False)
    plate = M("1b282e", light=1.16, shadow=0.7, ao=0.0)
    plate_alt = M("1e2c33", light=1.16, shadow=0.7, ao=0.0)
    rivet = M("2c3c44", light=1.3, ao=0.0)
    seam = 6.0
    cols, rows = [0, 240, 480, 720], [0, 300, 600, 900]
    for i in range(3):
        for j in range(3):
            x0, x1 = cols[i] + seam / 2, cols[i + 1] - seam / 2
            z0, z1 = rows[j] + seam / 2, rows[j + 1] - seam / 2
            box("plate", x0, z0, x1, z1, 8, 20, plate if (i + j) % 2 == 0 else plate_alt, bevel=5, outline=False)
            for x, z in ((x0 + 14, z0 + 14), (x1 - 14, z0 + 14), (x0 + 14, z1 - 14), (x1 - 14, z1 - 14)):
                sphere("rivet", 3.2, rivet, (x, 8, z), scale=(1, 0.6, 1), outline=False, seg=12)
            # Faint brushed streaks across each plate.
            for k in range(3):
                z = z0 + (z1 - z0) * (0.3 + 0.2 * k)
                box("brush", x0 + 30, z, x1 - 30 - k * 24, z + 1.2, 7.6, 8, M("223239", ao=0.0, glow=1.0), outline=False)
    # Vent grilles low on the middle plates.
    for cx in (360.0,):
        for k in range(6):
            box("vent", cx - 60, 40 + k * 9, cx + 60, 44 + k * 9, 7.4, 8, M("10181c", glow=1.0), outline=False)


# ---------------------------------------------------------------- main

def job(name):
    return not ONLY or name in ONLY


if __name__ == "__main__":
    C.OUTLINE = 2.2
    sc, cam = C.setup_scene(samples=32)
    for name in list(COLOURS) + ["hidden"]:
        out = "canister_%s" % name
        if not job(out) and not job("canisters"):
            continue
        C.clear_objects()
        canister_hidden() if name == "hidden" else canister(name)
        C.render_region(sc, cam, -64, 64, -44, 44, 1.0, os.path.join(OUT, out + ".png"))
        print("RENDERED", out)
    layers = {"tank_back": tank_back, "tank_front": tank_front, "tank_seal": tank_seal}
    for out, build in layers.items():
        if not job(out) and not job("tank"):
            continue
        C.clear_objects()
        build()
        C.render_region(sc, cam, 0, 160, 0, 420, 1.0, os.path.join(OUT, out + ".png"))
        print("RENDERED", out)
    if job("board_bg"):
        C.clear_objects()
        board_bg()
        C.render_region(sc, cam, 0, 720, 0, 900, 1.0, os.path.join(OUT, "board_bg.png"))
        print("RENDERED board_bg")
    print("DONE")

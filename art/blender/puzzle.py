"""Railhaven coolant-sort puzzle pieces, modelled and rendered in Blender.

  Blender -b --factory-startup --python art/blender/puzzle.py -- <out_dir> [only...]

Scene units are pixels (1 unit = 1 px), straight front view so pieces stack cleanly.
Outputs:
  canister_<colour>.png   128x88  coolant canister, one embossed emblem per colour
  canister_hidden.png     128x88  ash-covered unknown canister
  canister_hot.png        128x88  overheat overlay drawn over a canister (countdown plate x 92..124, y 4..34)
  tank_ice.png            160x420 frozen-tank overlay drawn over tank_front (flat field 70x70 at 80,210)
  tank_tag.png            120x64  single-colour tag with an empty 44 px socket centred at 60,32
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
from mathutils import Matrix, Vector

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


# ---------------------------------------------------------------- status overlays (frozen tank, hot canister, colour tag)

ICE, FROST, CRYSTAL = "a6d9f4", "e4f6ff", "aee6fb"
CALM = (45.0, 115.0, 175.0, 245.0)   # tank_ice: flat field behind the countdown number, image px (80, 210) +-35


def ice_glass(hexcol, alphas, cuts, name="ice"):
    """glass() whose colour is cel-lit like toon(), so jittered facets catch the light in bands."""
    m = glass(hexcol, alphas, cuts, name)
    nt = m.node_tree
    em = next(n for n in nt.nodes if n.type == "EMISSION")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = C.LIGHT_DIR
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = -1.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    els[0].color, els[1].position, els[1].color = C.lin(shade(hexcol, 0.86)), 0.4, C.lin(hexcol)
    els.new(0.8).color = C.lin(shade(hexcol, 1.35))
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    nt.links.new(dot.outputs["Value"], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    return m


def centred(ob):
    """Move an object's origin to its bounds centre: EEVEE sorts blended objects by origin."""
    c = sum((Vector(b) for b in ob.bound_box), Vector()) / 8
    ob.data.transform(Matrix.Translation(-c))
    ob.location += c
    return ob


def shard(name, base, h, r, ang, mat, tip=0.4, seg=6):
    """Faceted ice crystal: hexagonal prism with a pointed tip, growing from base at angle ang
    (radians from straight up, positive leans right). tip=1 makes a plain cone (icicle)."""
    bm = C.bmesh.new()
    hb = h * (1 - tip)
    if hb > 0:
        C.bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r * 0.9, depth=hb, matrix=Matrix.Translation((0, 0, hb / 2)))
    C.bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r * (0.9 if hb > 0 else 1), radius2=0.0, depth=h - hb,
                            matrix=Matrix.Translation((0, 0, hb + (h - hb) / 2)))
    C.bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(0.5, 3, "Z"))
    return C.finish(name, bm, mat, base, (0, ang, 0), smooth=False)


def _sparkle(x, z, r, y=-110):
    slab("sparkle", [(x + dx * r, z + dz * r) for dx, dz in ((0, 1), (0.22, 0.22), (1, 0), (0.22, -0.22), (0, -1), (-0.22, -0.22), (-1, 0), (-0.22, 0.22))],
         y, y + 1, M("ffffff", glow=1.2))


def tank_ice():
    """Frozen-solid overlay for a full tank (drawn over tank_front): a faceted ice shell hugging
    the glass, frost creeping in from the sides and top, a frost crust with icicles on the top
    rim, crystal clusters at the corners. The CALM square stays flat for the countdown number."""
    import random
    rnd = random.Random(11)
    # Faceted shell: a jittered cylinder grid split into triangles, flat shaded.
    r, z0, z1, rows, cols = 69.0, 26.0, 388.0, 12, 16
    zc = (z0 + z1) / 2
    bm = C.bmesh.new()
    grid = []
    for i in range(rows + 1):
        row = []
        for j in range(cols + 1):
            a, z = math.pi + math.pi * j / cols, z0 + (z1 - z0) * i / rows
            calm = CALM[0] - 14 < CX + r * math.cos(a) < CALM[1] + 14 and CALM[2] - 18 < z < CALM[3] + 18
            k = 0.0 if calm else 1.0
            rim = j in (0, cols)
            rr = r + k * rnd.uniform(-3.6, 3.6) * (0.3 if rim else 1)
            aa = a + (0.0 if rim else k * rnd.uniform(-0.05, 0.05))
            zz = z + (0.0 if i in (0, rows) else k * rnd.uniform(-9, 9))
            row.append(bm.verts.new((rr * math.cos(aa), rr * math.sin(aa), zz - zc)))
        grid.append(row)
    for i in range(rows):
        for j in range(cols):
            a, b, c, d = grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]
            if (i + j) % 2:
                bm.faces.new((a, b, c)), bm.faces.new((a, c, d))
            else:
                bm.faces.new((a, b, d)), bm.faces.new((b, c, d))
    C.finish("ice_shell", bm, ice_glass(ICE, (0.36, 0.52, 0.76), cuts=(0.3, 0.62)), (CX, 0, zc), outline=False, smooth=False)

    # Frost creeping in from the side edges, thicker towards the top (two stepped layers).
    def creep(x_edge, side, reach, zlo, zhi, seed):
        rr = random.Random(seed)
        inner = []
        for k in range(int((zhi - zlo) / 7) + 1):
            z = zlo + k * 7
            t = (z - zlo) / (zhi - zlo)
            inner.append((x_edge + side * (reach * (0.25 + 0.75 * t * t) + (rr.uniform(3, 7) if k % 2 else 0)), z))
        return [(x_edge, zlo), (x_edge, zhi)] + inner[::-1] if side > 0 else [(x_edge, zhi), (x_edge, zlo)] + inner

    for side, x in ((1, 11.0), (-1, 149.0)):
        centred(slab("frost_side", creep(x, side, 20, 34, 384, 3 + side), -76, -75, glass(FROST, (0.3,) * 3, name="frost_lo")))
        centred(slab("frost_side", creep(x, side, 10, 34, 384, 5 + side), -77, -76, glass(FROST, (0.42,) * 3, name="frost_hi")))
    # Frost band hanging from the top rim, with a jagged lower edge.
    for depth, a, y in ((44, 0.3, -78), (24, 0.4, -79)):
        rr = random.Random(depth)
        lower = [(x, 382 - depth * (0.55 + 0.45 * rr.random()) - (6 if k % 2 else 0)) for k, x in enumerate(range(12, 149, 8))]
        centred(slab("frost_top", [(11, 384), (149, 384), (149, 382 - depth * 0.6)] + lower[::-1] + [(11, 382 - depth * 0.6)], y, y + 1, glass(FROST, (a,) * 3, name="frost_top")))
    # Crystal facet plates in the outer bands of the shell (never inside the calm field).
    for k in range(18):
        side = -1 if k % 2 else 1
        x = CX + side * rnd.uniform(40, 60)
        z = 60 + k * 17 + rnd.uniform(-6, 6)
        w, h = rnd.uniform(7, 13), rnd.uniform(14, 26)
        tri = [(x - w, z - h * 0.4), (x + w * 0.6, z - h * 0.6), (x + w * rnd.uniform(-0.3, 0.8), z + h * 0.5)]
        a = (0.12, 0.2, 0.28)[k % 3]
        centred(slab("facet", tri, -74 - k * 0.05, -73.9 - k * 0.05, glass("f2fbff", (a,) * 3, name="facet")))
    # Light cracks and glints in the ice, kept to the edges.
    shine = glass("ffffff", (0.55,) * 3, name="ice_shine")
    for path, w in (([(22, 300), (28, 318), (26, 334)], 1.6), ([(24, 96), (31, 84), (36, 88)], 1.4), ([(134, 128), (130, 150), (136, 166)], 1.4),
                    ([(128, 318), (135, 330)], 1.4), ([(20, 150), (20, 250)], 3.4)):
        centred(slab("crack", stroke_poly(path, w), -80, -79, shine))

    frost, crystal = M(FROST, light=1.08, shadow=0.8, ao=0.0), M(CRYSTAL, light=1.2, shadow=0.72, ao=0.0)
    crystal_lt = M("d4f4ff", light=1.12, shadow=0.76, ao=0.0)
    # Thick crust over the top collar: lumpy top, drippy lower edge.
    top = [(3, 392), (4, 401), (14, 405), (30, 403.5), (44, 408), (60, 406), (76, 410), (94, 407.5), (110, 409), (126, 405), (142, 406.5), (154, 402), (157, 394)]
    drips = [(x, z) for x, z in ((152, 384), (146, 377), (138, 381), (128, 372), (118, 380), (106, 375), (94, 381), (82, 371), (70, 379),
                                 (58, 374), (46, 380), (34, 370), (24, 378), (14, 374), (7, 382))]
    slab("crust", spline(top + drips, n=3, sharp=(0, len(top) - 1)), -96, -40, frost, chamfer=1.6, outline=True)
    for x, z, rad in ((16, 404, 4.2), (40, 407.5, 5.0), (68, 409, 4.0), (100, 409.5, 5.2), (132, 406.5, 4.4)):
        sphere("clump", rad, frost, (x, -50, z), scale=(1.6, 1.0, 0.8), seg=16)
    # Icicles hanging off the crust over the top slot.
    ice_t = M("cdefff", light=1.14, shadow=0.74, ao=0.0)
    for x, z, h, rad in ((12, 378, 22, 3.6), (24, 377, 34, 4.2), (36, 371, 14, 3.0), (51, 377, 26, 3.6), (64, 375, 12, 2.6), (76, 372, 30, 4.0),
                         (90, 378, 18, 3.2), (104, 375, 28, 3.8), (117, 378, 12, 2.6), (130, 373, 24, 3.6), (143, 377, 30, 4.0), (150, 380, 13, 2.8)):
        shard("icicle", (x, -86, z), h, rad, math.pi + rnd.uniform(-0.06, 0.06), ice_t, tip=1.0, seg=7)
    # Crystal clusters poking up through the crust and out of the corners.
    for (x, z), spikes in (((22, 398), ((17, 3.6, -0.35), (13, 3.0, 0.3))), ((86, 401), ((15, 3.4, 0.15),)), ((128, 399), ((14, 3.2, -0.2), (17, 3.8, 0.35))),
                           ((10, 30), ((30, 5.2, 0.42), (20, 4.2, 0.05), (15, 3.6, 0.8))), ((150, 30), ((28, 5.0, -0.4), (21, 4.4, -0.02), (14, 3.6, -0.78)))):
        for k, (h, rad, ang) in enumerate(spikes):
            shard("crystal", (x, -86 + k, z), h, rad, ang, crystal if k % 2 == 0 else crystal_lt)
    # Frost drift over the bottom collar.
    drift = [(4, 18), (156, 18), (156, 26), (146, 33), (132, 30), (116, 36), (100, 31), (80, 35), (62, 30), (44, 35), (28, 31), (14, 34), (4, 27)]
    slab("drift", spline(drift, n=3, sharp=(0, 1)), -96, -40, frost, chamfer=1.4, outline=True)
    for x, z, rad in ((-36, 405, 3.2), (52, 401, 2.6), (60, 395, 2.2), (-58, 384, 2.4), (-62, 120, 2.6), (62, 64, 2.8), (54, 352, 3.0)):
        _sparkle(CX + x, z, rad)


def canister_hot():
    """Overheat overlay for a canister (drawn over canister_<colour>): dark clamp band on the top
    cap with a warning lamp and glowing chevrons, orange heat fringe round the silhouette, and a
    plain dark readout plate top right (image x 92..124, y 4..34) for the move countdown."""
    hot, dark = "ff6a2a", M("2b3037", light=1.3, shadow=0.62)
    # Heat fringe: a rounded box whose bevelled rim fades in orange while its flat front stays clear.
    centred(box("heat", -63.5, -43.5, 63.5, 43.5, -30, 60, glass("ff9a3d", (0.0, 0.34, 0.68), cuts=(0.2, 0.6), name="heat"), bevel=10, outline=False))
    lathe("clamp", [(0.0, 28.0), (59.6, 28.0), (60.6, 29.0), (60.6, 39.6), (59.6, 40.6), (0.0, 40.6)], dark)
    for x in (-30.0, 22.0):
        sphere("clamp_bolt", 1.9, M("8b939c", ao=0.0), (x, -math.sqrt(60.6 ** 2 - x ** 2) - 0.6, 34.3), outline=False, seg=10)
    box("hazard", -25, 29.6, 17, 39.0, -64, -50, M("1a1d22", glow=1.0), bevel=1.0, outline=False)
    for k in range(5):
        x = -19 + k * 8.0
        slab("chevron", stroke_poly([(x - 2.4, 37.0), (x + 1.8, 34.3), (x - 2.4, 31.6)], 2.4), -65, -64, M("ff7a2a" if k % 2 == 0 else "ffb347", glow=1.3))
    # Warning lamp: halo, housing, lens, hot core.
    for rad, a in ((13.0, 0.18), (9.5, 0.3)):
        centred(ring_slab("lamp_halo", -44, 34.2, 5.0, rad, -68 + rad * 0.1, -66, glass("ff4a1a", (a,) * 3, name="halo")))
    ycyl("lamp_ring", 6.4, 4, dark, -44, 34.2, -61, seg=32)
    ycyl("lamp", 4.6, 2, M("ff4a24", glow=1.5), -44, 34.2, -63.4, outline=False, seg=32)
    sphere("lamp_core", 2.0, M("ffd27a", glow=1.6), (-45, -66, 35.2), outline=False, seg=12)
    # Readout plate: plain and dark so the white countdown digit reads.
    plate = fillet([(27.5, 9.5), (60.5, 9.5), (60.5, 40.5), (27.5, 40.5)], 5)
    slab("plate", plate, -68, -40, dark, chamfer=1.4, outline=True)
    slab("plate_face", fillet([(30.5, 12.5), (57.5, 12.5), (57.5, 37.5), (30.5, 37.5)], 3.5), -68.6, -67, M("15181d", glow=1.0))
    # Hot metal on the bottom cap: glowing seam and heat streaks rising off the body edges.
    zcyl("hot_seam", 58.2, -36.0, -33.6, 0, 0, M("ff6a2a", glow=1.2), outline=False, seg=64)
    for s in (-1, 1):  # glowing hot rim down each side of the glass body (behind the plate), softer warm band inside
        centred(slab("heat_band", stroke_poly([(s * 49.0, -24.0), (s * 49.0, 24.0)], 6.0), -64, -63, glass(hot, (0.3,) * 3, name="heat_band")))
        slab("heat_rim", stroke_poly([(s * 52.6, -26.0), (s * 52.6, 26.0)], 2.2), -66, -65, M("ffa24a", glow=1.3))


def tank_tag():
    """Single-colour tag hung on a tank rim: brushed steel plate with rivets and teal arrows,
    a brass socket ring and an empty dark socket (44 px, centre 60,32) for the colour icon."""
    cx, cz = 60.0, 32.0
    steel = M("8e9aa6", light=1.22, shadow=0.64)
    for x in (16.0, 104.0):  # hanger loops over the rim
        C.torus("hook", 5.0, 1.7, M("5f6a76", light=1.3, shadow=0.6), (x, 6, 55.5), rot=(math.pi / 2, 0, 0), outline=True)
    slab("plate", fillet([(4, 13), (116, 13), (116, 51), (4, 51)], 9), -10, 6, steel, chamfer=1.8, outline=True)
    brush = M("a3aeb9", glow=1.0)
    for z, x0, x1 in ((20.5, 12, 34), (26.0, 9, 32), (38.0, 9, 32), (44.0, 13, 33)):
        for a, b in ((x0, x1), (120 - x1, 120 - x0)):
            slab("brush", stroke_poly([(a, z), (b, z)], 0.9), -12.4, -11.6, brush)
    rivet = M("c3ccd5", ao=0.0)
    for x in (10.5, 109.5):
        for z in (20.0, 44.0):
            sphere("rivet", 2.3, rivet, (x, -11.6, z), scale=(1, 0.6, 1), seg=12)
    teal = M("3fd8c2", glow=1.15)
    for s in (-1, 1):  # arrows pointing at the socket
        x = cx + s * 40
        slab("arrow_ink", offset_poly([(x - s * 6, 32), (x + s * 2, 38.5), (x + s * 2, 25.5)], 1.4), -12.5, -11, M(INK, glow=1.0))
        slab("arrow", [(x - s * 6, 32), (x + s * 2, 38.5), (x + s * 2, 25.5)], -13.2, -11, teal)
    brass = M("b08a45", light=1.3, shadow=0.62)
    ring_slab("socket_ring", cx, cz, 22.6, 29.0, -16, 4, brass, chamfer=1.6, outline=True)
    ring_slab("socket_lip", cx, cz, 22.6, 24.2, -16.6, -15.6, M("e9c27a", glow=1.0), seg=64)
    for k in range(6):
        a = math.pi / 2 + k * math.pi / 3
        sphere("ring_rivet", 1.4, M("ffe2a0", ao=0.0), (cx + 26.2 * math.cos(a), -16.6, cz + 26.2 * math.sin(a)), outline=False, seg=10)
    ycyl("socket", 23.0, 2, M("161b20", glow=1.0), cx, cz, -13, outline=False, seg=64)
    ring_slab("socket_shade", cx, cz, 20.0, 22.8, -14.4, -14.1, M("0b0d10", glow=1.0), seg=64)


# ---------------------------------------------------------------- main

def job(name):
    return not ONLY or name in ONLY


if __name__ == "__main__":
    C.OUTLINE = 2.2
    sc, cam = C.setup_scene(samples=32)
    for name in list(COLOURS) + ["hidden", "hot"]:
        out = "canister_%s" % name
        if not job(out) and not job("canisters"):
            continue
        C.clear_objects()
        {"hidden": canister_hidden, "hot": canister_hot}.get(name, lambda: canister(name))()
        C.render_region(sc, cam, -64, 64, -44, 44, 1.0, os.path.join(OUT, out + ".png"))
        print("RENDERED", out)
    layers = {"tank_back": tank_back, "tank_front": tank_front, "tank_seal": tank_seal, "tank_ice": tank_ice}
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
    if job("tank_tag"):
        C.clear_objects()
        tank_tag()
        C.render_region(sc, cam, 0, 120, 0, 64, 1.0, os.path.join(OUT, "tank_tag.png"))
        print("RENDERED tank_tag")
    print("DONE")

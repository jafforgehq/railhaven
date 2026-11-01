"""Railhaven "pull the pin" rescue mini-game pieces, modelled and rendered in Blender.

  Blender -b --factory-startup --python art/blender/rescue.py -- <out_dir> [only...]

Scene units are pixels (1 unit = 1 px), straight front view like puzzle.py.
Outputs (image coordinates, y down):
  pin.png                 320x48   steel valve pin, centre line y 24; handle x 0..57, rod x 57..318, rod body y 17..31
  ball_cool.png           48x48    coolant ball, centred, body radius 20 (22 with outline)
  ball_hot.png            48x48    molten sand ball, same size, faint heat halo out to 24
  ball_stone.png          48x48    cooled stone lump, same size
  wall.png                64x64    seamless riveted steel plate for chamber walls
  chamber_bg.png          720x1100 dark machinery wall behind the chamber
  capsule.png             200x160  open glass pod drawn over the crew; floor centre y 140, basin x 30..170, y 79..140
  capsule_happy_glow.png  200x160  cyan glow + coolant fill drawn over capsule (and crew) when full
"""
import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import box, sphere, ycyl, lathe, slab, stroke_poly, toon  # noqa: E402
from puzzle import glass, centred  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/railhaven_rescue"
ONLY = set(ARGS[1:])

M = toon
STEEL = "8e9aa6"
RED = "d8342c"
X_AXIS = (0, math.pi / 2, 0)   # lathe rotation that turns its Z axis into world X


def soft(hexcol, alphas, name="soft"):
    """glass() with a smooth ramp: alphas at facing 0 (towards camera), 0.5 and 1 (grazing)."""
    m = glass(hexcol, alphas, cuts=(0.5, 1.0), name=name)
    next(n for n in m.node_tree.nodes if n.type == "VALTORGB").color_ramp.interpolation = "LINEAR"
    return m


def shell(name, prof, mat, loc=(0, 0, 0), rot=(0, 0, 0), outline=False):
    """Open lathe surface (tube, tub) with outward normals. Unlike capped cylinders, its smooth
    normals stay purely radial, so the toon bands run straight along long pipes."""
    bm = C.bmesh.new()
    vs = [bm.verts.new((r, 0.0, z)) for r, z in prof]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    C.bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=64, use_merge=True)
    C.bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.faces.ensure_lookup_table()
    f = max(bm.faces, key=lambda f: f.calc_center_median().length)
    c = f.calc_center_median()
    if f.normal.dot(Vector((c.x, c.y, 0))) < 0:
        C.bmesh.ops.reverse_faces(bm, faces=bm.faces)
    return C.finish(name, bm, mat, loc, rot, outline=outline)


def hpipe(name, r, x0, x1, z, y, mat, outline=False):
    return shell(name, [(r, -(x1 - x0) / 2), (r, (x1 - x0) / 2)], mat, ((x0 + x1) / 2, y, z), X_AXIS, outline)


def vpipe(name, r, z0, z1, x, y, mat, outline=False):
    return shell(name, [(r, z0), (r, z1)], mat, (x, y, 0), outline=outline)


def flange(name, r, h, mat, loc, rot=(0, 0, 0), outline=False, bev=1.0):
    """Short bevelled disc (flange, collar, washer) centred on loc along the lathe axis."""
    return lathe(name, [(0.0, -h / 2), (r - bev, -h / 2), (r, -h / 2 + bev), (r, h / 2 - bev), (r - bev, h / 2), (0.0, h / 2)], mat, loc, rot, outline, smooth=False)


def sparkle(x, z, r, y=-60, col="ffffff"):
    slab("sparkle", [(x + dx * r, z + dz * r) for dx, dz in ((0, 1), (0.22, 0.22), (1, 0), (0.22, -0.22), (0, -1), (-0.22, -0.22), (-1, 0), (-0.22, 0.22))],
         y, y + 1, M(col, glow=1.2))


# ---------------------------------------------------------------- pin (320x48, centre line z 24)

def pin():
    zc = 24.0
    steel = M("a9b4bf", light=1.32, shadow=0.6, ao=0.0)
    dark = M("4a535e", light=1.3, shadow=0.62, ao=0.0)
    # Polished rod with a domed tip and a locking groove near the end.
    hpipe("rod", 7.0, 54, 310, zc, 0, steel, outline=True)
    sphere("tip", 7.0, steel, (310, 0, zc), scale=(0.9, 1, 1), seg=24)
    for x in (292.0, 298.0):
        flange("groove", 7.25, 1.8, dark, (x, 0, zc), X_AXIS, bev=0.3)
    shine = M("ffffff", glow=1.0)
    slab("rod_shine", stroke_poly([(64, zc + 3.4), (284, zc + 3.4)], 1.8), -9, -8, shine)
    slab("rod_shine", stroke_poly([(300, zc + 3.2), (310, zc + 2.6)], 1.6), -9, -8, shine)
    slab("rod_glint", stroke_poly([(72, zc - 3.6), (200, zc - 3.6)], 1.0), -9, -8, M("d6dde4", glow=1.0))
    # Collar the ring hangs from: steel ferrule with a red band, and a washer against the rod.
    collar = M(STEEL, light=1.3, shadow=0.6, ao=0.0)
    flange("collar", 10.5, 16, collar, (46, -2, zc), X_AXIS, outline=True, bev=1.6)
    flange("collar_band", 10.9, 4, M(RED, light=1.25, shadow=0.66, ao=0.0), (46, -2, zc), X_AXIS, bev=0.4)
    flange("washer", 12.0, 4, dark, (54, -1, zc), X_AXIS, outline=True, bev=0.8)
    # Chunky red pull ring, passing through a steel eye on the collar.
    C.torus("ring", 14.2, 5.8, M(RED, light=1.28, shadow=0.64, ao=0.0), (22.5, 4, zc), rot=(math.pi / 2, 0, 0), outline=True, seg_u=48, seg_v=16)
    flange("eye", 7.0, 9.0, collar, (36.5, 1, zc), X_AXIS, outline=True, bev=1.4)
    slab("ring_shine", stroke_poly([(11.5, zc + 12.0), (17.0, zc + 15.6)], 2.0), -12, -11, M("ffb0a6", glow=1.0))


# ---------------------------------------------------------------- balls (48x48, centre 24,24)

R_BALL = 20.0


def crescent(col, r=16.6, w=2.6, a0=-110, a1=0):
    """Back-light rim on the shaded lower right, so the ball reads as lit from behind too."""
    path = [(24 + r * math.cos(math.radians(a)), 24 + r * math.sin(math.radians(a))) for a in range(a0, a1 + 1, 10)]
    slab("rim", stroke_poly(path, w), -21, -20, M(col, glow=1.0))


def ball_cool():
    sphere("ball", R_BALL, M("3a8ef0", light=1.3, shadow=0.7, ao=0.0), (24, 0, 24), seg=40)
    crescent("9fe6ff")
    gloss = [(14 + 5.2 * math.cos(t) * math.cos(0.7) - 3.0 * math.sin(t) * math.sin(0.7),
              33 + 5.2 * math.cos(t) * math.sin(0.7) + 3.0 * math.sin(t) * math.cos(0.7)) for t in (2 * math.pi * i / 24 for i in range(24))]
    slab("gloss", gloss, -22, -21, M("ffffff", glow=1.0))
    sphere("gloss_dot", 1.6, M("ffffff", glow=1.0), (20.5, -21, 38), outline=False, seg=10)


def lumpy(name, r, mat, loc, seed, amp, smooth=True, seg=32, squash=(1, 1, 1)):
    """Sphere with low-frequency bumps (sand clumps, stone)."""
    rnd = random.Random(seed)
    waves = [(Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized(), rnd.uniform(1.5, 3.5), rnd.uniform(0, 6.28)) for _ in range(6)]
    bm = C.bmesh.new()
    C.bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        k = 1 + amp * sum(math.sin(f * d.dot(w) * 3 + p) for w, f, p in waves) / len(waves)
        v.co = Vector((d.x * squash[0], d.y * squash[1], d.z * squash[2])) * r * k
    return C.finish(name, bm, mat, loc, smooth=smooth)


def ball_hot():
    sphere("halo", 24.0, soft("ff8a2a", (0.9, 0.45, 0.0), name="halo"), (24, 12, 24), outline=False, seg=40)
    lumpy("ball", R_BALL - 0.4, M("e5531e", light=1.42, shadow=0.74, ao=0.0), (24, 0, 24), 3, 0.05)
    crescent("ffb347", w=2.2)
    # Darker grains for the sand, glowing fissures and ember specks on the camera side.
    rnd = random.Random(7)
    grain = M("b8401a", glow=1.0)
    for _ in range(16):
        a, d = rnd.uniform(0, 6.28), rnd.uniform(4, 15)
        ycyl("grain", rnd.uniform(0.6, 1.0), 1, grain, 24 + d * math.cos(a), 24 + d * math.sin(a), -20.5, outline=False, seg=8)
    crack = M("ffd36a", glow=1.3)
    for path in (((13, 27), (18, 25), (21, 28), (26, 26)), ((26, 15), (30, 19), (35, 17)), ((29, 33), (33, 30))):
        slab("crack", stroke_poly(path, 1.5), -21.5, -20.5, crack)
    for _ in range(12):
        a, d = rnd.uniform(0, 6.28), rnd.uniform(3, 16)
        sphere("ember", rnd.uniform(0.7, 1.2), M(rnd.choice(("fff1b0", "ffc04a", "ff9a3d")), glow=1.4),
               (24 + d * math.cos(a), -21.5, 24 + d * math.sin(a)), outline=False, seg=8)
    slab("gloss", stroke_poly([(15.5, 33.5), (19.5, 37)], 2.6), -22, -21, M("ffe2a0", glow=1.0))


def ball_stone():
    lumpy("ball", R_BALL - 0.6, M("7f7c7a", light=1.2, shadow=0.66, ao=0.0), (24, 0, 24), 12, 0.09, smooth=False, seg=14, squash=(1.0, 1, 0.94))
    pit = M("514e4d", glow=1.0)
    for x, z, r in ((17, 19, 2.0), (30, 29, 1.6), (28, 15, 1.3), (14, 29, 1.1), (33, 21, 1.0)):
        ycyl("pit", r, 1, pit, x, z, -21, outline=False, seg=12)
    fleck = M("a9a5a1", glow=1.0)
    for x, z in ((20, 32), (24, 26), (35, 26), (19, 13), (29, 34), (12, 23)):
        ycyl("fleck", 0.7, 1, fleck, x, z, -22, outline=False, seg=8)


# ---------------------------------------------------------------- wall tile (64x64, seamless)

def wall():
    """Built on a 3x3 grid and rendered for the middle tile, so edges, AO and bevels wrap."""
    plate = M("3a4550", light=1.2, shadow=0.7, ao=0.0)
    rivet = M("8693a0", light=1.25, shadow=0.6, ao=0.0)
    box("seam", -70, -70, 134, 134, 10, 12, M("12181d", glow=1.0), outline=False)
    for ox in (-64, 0, 64):
        for oz in (-64, 0, 64):
            box("plate", ox + 1.5, oz + 1.5, ox + 62.5, oz + 62.5, 0, 10, plate, bevel=3.5, outline=False)
            for x, z in ((7, 7), (57, 7), (7, 57), (57, 57)):
                sphere("rivet", 2.6, rivet, (ox + x, 0, oz + z), scale=(1, 0.6, 1), outline=False, seg=12)
                ycyl("rivet_ring", 3.4, 0.5, M("222a31", glow=1.0), ox + x, oz + z, 0.2, outline=False, seg=16)
            for z, x0, x1 in ((22, 14, 44), (32, 18, 50), (42, 12, 38)):
                box("brush", ox + x0, oz + z, ox + x1, oz + z + 0.8, -0.6, -0.2, M("44505b", glow=1.0), outline=False)


# ---------------------------------------------------------------- chamber background (720x1100)

def chamber_bg():
    """Dark riveted machinery wall: panels, pipes, dim gauges. Kept low contrast so balls pop."""
    W, H = 720, 1100
    box("base", -10, -10, W + 10, H + 10, 30, 32, M("0e1418", glow=1.0), outline=False)
    plate = M("1b282e", light=1.16, shadow=0.7, ao=0.0)
    plate_alt = M("1e2c33", light=1.16, shadow=0.7, ao=0.0)
    rivet = M("2c3c44", light=1.3, ao=0.0)
    brush = M("223239", glow=1.0)
    seam = 6.0
    cols, rows = [0, 240, 480, 720], [0, 220, 495, 770, 1100]
    for i in range(3):
        for j in range(4):
            x0, x1 = cols[i] + seam / 2, cols[i + 1] - seam / 2
            z0, z1 = rows[j] + seam / 2, rows[j + 1] - seam / 2
            box("plate", x0, z0, x1, z1, 20, 30, plate if (i + j) % 2 == 0 else plate_alt, bevel=5, outline=False)
            for x, z in ((x0 + 14, z0 + 14), (x1 - 14, z0 + 14), (x0 + 14, z1 - 14), (x1 - 14, z1 - 14)):
                sphere("rivet", 3.2, rivet, (x, 20, z), scale=(1, 0.6, 1), outline=False, seg=12)
            for k in range(3):
                z = z0 + (z1 - z0) * (0.3 + 0.2 * k)
                box("brush", x0 + 30, z, x1 - 30 - k * 24, z + 1.2, 19.6, 20, brush, outline=False)
    pipe = M("1d2b32", light=1.12, shadow=0.72, ao=0.0)
    fl = M("23333b", light=1.14, shadow=0.7, ao=0.0)
    # A pipe up each side, bent into a header across the top and a drain along the bottom.
    top, bot = 1048.0, 56.0
    for x in (30.0, 690.0):
        vpipe("pipe", 9.0, bot, top, x, 10, pipe)
        for z in (bot, top):
            sphere("elbow", 9.0, pipe, (x, 10, z), outline=False, seg=24)
        for z in (300.0, 640.0, 900.0):
            flange("flange", 12.5, 9, fl, (x, 10, z))
    for z in (bot, top):
        hpipe("header", 9.0, 30, 690, z, 10, pipe)
        for x in (180.0, 540.0):
            flange("flange", 12.5, 9, fl, (x, 10, z), X_AXIS)
    # A thinner feed pipe beside the left riser, and valve wheels on the header.
    vpipe("feed", 5.0, bot + 20, top - 20, 54, 12, pipe)
    for z in (bot + 20, top - 20):
        hpipe("feed_stub", 5.0, 30, 54, z, 12, pipe)
        sphere("feed_elbow", 5.0, pipe, (54, 12, z), outline=False, seg=16)
    for x in (300.0, 420.0):  # hand wheels facing out of the header
        flange("valve", 7, 10, fl, (x, -2, top), rot=(math.pi / 2, 0, 0))
        C.torus("wheel", 12, 2.2, fl, (x, -8, top), rot=(math.pi / 2, 0, 0), seg_u=32, seg_v=8)
        for a in (0, math.pi / 3, 2 * math.pi / 3):
            box("spoke", x - 11, top - 1, x + 11, top + 1, -9, -7, fl, outline=False).rotation_euler = (0, a, 0)
        ycyl("hub", 3.2, 2, fl, x, top, -9.5, outline=False, seg=16)
    # Dim round gauges on the panels and a status lamp strip.
    for x, z, r, ang in ((170.0, 860.0, 30.0, 0.6), (560.0, 600.0, 24.0, -0.4), (150.0, 330.0, 22.0, 1.1)):
        ycyl("gauge_ring", r + 5, 6, fl, x, z, 16, outline=False, seg=48)
        ycyl("gauge_face", r, 2, M("142024", glow=1.0), x, z, 12.5, outline=False, seg=48)
        for k in range(9):
            a = math.radians(225 - k * 33.75)
            slab("tick", stroke_poly([(x + (r - 6) * math.cos(a), z + (r - 6) * math.sin(a)), (x + (r - 2.5) * math.cos(a), z + (r - 2.5) * math.sin(a))], 1.6),
                 11, 12, M("2b3d45" if k < 7 else "4a2e22", glow=1.0))
        slab("needle", stroke_poly([(x, z), (x + (r - 7) * math.cos(ang), z + (r - 7) * math.sin(ang))], 2.0), 10, 11, M("5a3a2a", glow=1.0))
        ycyl("needle_hub", 2.6, 1, fl, x, z, 9.5, outline=False, seg=12)
    for cx, cz in ((360.0, 240.0), (600.0, 880.0)):
        for k in range(6):
            box("vent", cx - 50, cz + k * 9, cx + 50, cz + k * 9 + 4, 19.4, 20, M("10181c", glow=1.0), outline=False)
    for k, col in enumerate(("2a4a40", "2a4a40", "4a3a22")):
        ycyl("lamp", 4, 2, M(col, glow=1.0), 570 + k * 16, 1000, 18, outline=False, seg=16)


# ---------------------------------------------------------------- capsule (200x160)
# Straight front view on purpose: the sprite is drawn over the crew, so everything inside the tub
# is see-through glass and the only opaque parts (rim, posts, collar, plinth) are in front of the crew.

CAP_CX, CAP_FLOOR = 100.0, 20.0          # floor centre in scene coords (image y 140)
CUP_R, CUP_H, CUP_RC = 76.0, 66.0, 22.0  # glass tub radius, rim height above the floor, bottom corner radius


def cup_prof(r, h, rc, z0=0.0):
    prof = [(0.0, z0), (r - rc, z0)]
    for k in range(1, 9):
        a = -math.pi / 2 + k * (math.pi / 2) / 8
        prof.append((r - rc + rc * math.cos(a), z0 + rc + rc * math.sin(a)))
    return prof + [(r, h)]


def capsule():
    steel = M("5f6a76", light=1.3, shadow=0.6)
    dark = M("39414b", light=1.3, shadow=0.62)
    loc = (CAP_CX, 0, 0)
    # Plinth with a teal status strip, bolts and a small heat lamp.
    lathe("plinth", [(0.0, 1.5), (86.0, 1.5), (90.0, 5.5), (90.0, 13.5), (86.0, 17.5), (0.0, 17.5)], dark, loc)
    lathe("plinth_band", [(0.0, 8.5), (90.6, 8.5), (90.6, 10.5), (0.0, 10.5)], M("2fa8a0", glow=1.0), loc, outline=False)
    for x in (-72.0, -44.0, 44.0, 72.0):
        sphere("bolt", 1.8, M("aab4be", ao=0.0), (CAP_CX + x, -math.sqrt(90.6 ** 2 - x ** 2), 13.8), outline=False, seg=10)
    ycyl("lamp_ring", 5.0, 3, steel, CAP_CX, 9.5, -92, seg=24)
    ycyl("lamp", 3.4, 2, M("ff6a2a", glow=1.4), CAP_CX, 9.5, -94, outline=False, seg=24)
    # Glass tub (near wall only: the crew is drawn behind this sprite and must show through).
    shell("glass", cup_prof(CUP_R, CUP_H, CUP_RC), glass("d4f2fb", (0.14, 0.22, 0.46), cuts=(0.55, 0.86), name="glass"), (CAP_CX, 0, CAP_FLOOR))
    # Collar clamping the tub to the plinth, slim posts up the glass edges, rolled rim round the mouth.
    lathe("collar", [(70.0, 13.0), (79.0, 13.0), (81.0, 15.0), (81.0, 22.0), (78.0, 25.0), (70.0, 25.0)], steel, loc)
    for x in (CAP_CX - CUP_R + 1, CAP_CX + CUP_R - 1):
        vpipe("post", 3.0, 24, CAP_FLOOR + CUP_H, x, -6, steel, outline=True)
    C.torus("rim", CUP_R + 0.5, 3.6, steel, (CAP_CX, 0, CAP_FLOOR + CUP_H + 1.0), outline=True, seg_u=96, seg_v=12)
    for x in (-54.0, -27.0, 0.0, 27.0, 54.0):
        for z, r in ((CAP_FLOOR + CUP_H + 1.0, CUP_R + 4.1), (18.5, 81.0)):
            sphere("rivet", 1.5, M("aab4be", ao=0.0), (CAP_CX + x, -math.sqrt(r ** 2 - x ** 2) - 0.4, z), outline=False, seg=10)
    shine, soft_ = glass("ffffff", (0.42,) * 3, name="shine"), glass("ffffff", (0.26,) * 3, name="shine_soft")
    top = CAP_FLOOR + CUP_H
    centred(slab("streak", stroke_poly([(38, 44), (38, top - 16)], 5.0), -120, -119, shine))
    centred(slab("streak", stroke_poly([(47, 48), (47, top - 24)], 2.0), -120, -119, soft_))
    centred(slab("streak", stroke_poly([(163, 50), (163, top - 12)], 2.0), -120, -119, soft_))
    centred(slab("glint", stroke_poly([(38, top - 10), (38, top - 7)], 5.0), -120, -119, shine))


def capsule_happy_glow():
    """Drawn over capsule (and crew) when the pod is full: coolant fill, lit surface, cold halo."""
    fill = CUP_H - 10
    loc = (CAP_CX, 0, CAP_FLOOR)
    lathe("coolant", cup_prof(CUP_R - 1.5, fill, CUP_RC - 1.5, z0=1.0) + [(0.0, fill)], glass("38d6f0", (0.2, 0.3, 0.48), cuts=(0.5, 0.85), name="coolant"), loc, outline=False)
    box("surface", CAP_CX - CUP_R + 2, CAP_FLOOR + fill - 1.0, CAP_CX + CUP_R - 2, CAP_FLOOR + fill + 1.0, -90, -89, M("c8fbff", glow=1.2), outline=False)
    # Cold halo: a pill-shaped shell whose alpha peaks where the surface turns away (around the
    # tub outline) and fades to nothing at the camera-facing middle and the outer silhouette.
    hr, hc, z0, z1 = 96.0, 34.0, 6.0, CAP_FLOOR + CUP_H + 14
    prof = [(0.0, z0)] + [(hr - hc + hc * math.cos(a), z0 + hc + hc * math.sin(a)) for a in (-math.pi / 2 + k * math.pi / 16 for k in range(1, 8))]
    prof += [(hr - hc + hc * math.cos(a), z1 - hc + hc * math.sin(a)) for a in (k * math.pi / 16 for k in range(0, 8))] + [(0.0, z1)]
    lathe("halo", prof, soft("6fe6ff", (0.0, 0.5, 0.0), name="halo"), (CAP_CX, 40, 0), outline=False)
    for x, z, r in ((40, 56, 3.6), (152, 94, 3.0), (128, 40, 2.4), (58, 98, 2.6), (170, 34, 2.2)):
        sparkle(x, z, r, y=-130)


# ---------------------------------------------------------------- main

def job(name):
    return not ONLY or name in ONLY


JOBS = [  # name, build, region (x0, x1, z0, z1), outline
    ("pin", pin, (0, 320, 0, 48), 1.6),
    ("ball_cool", ball_cool, (0, 48, 0, 48), 1.6),
    ("ball_hot", ball_hot, (0, 48, 0, 48), 1.6),
    ("ball_stone", ball_stone, (0, 48, 0, 48), 1.6),
    ("wall", wall, (0, 64, 0, 64), 0.0),
    ("chamber_bg", chamber_bg, (0, 720, 0, 1100), 0.0),
    ("capsule", capsule, (0, 200, 0, 160), 2.0),
    ("capsule_happy_glow", capsule_happy_glow, (0, 200, 0, 160), 2.0),
]

if __name__ == "__main__":
    sc, cam = C.setup_scene(samples=32)
    for out, build, (x0, x1, z0, z1), outline in JOBS:
        if not job(out):
            continue
        C.OUTLINE = outline
        C.clear_objects()
        build()
        C.render_region(sc, cam, x0, x1, z0, z1, 1.0, os.path.join(OUT, out + ".png"))
        print("RENDERED", out)
    print("DONE")

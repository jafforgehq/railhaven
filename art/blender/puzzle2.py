"""Railhaven puzzle extras (locks, rust, rescue parts, conveyor, linked tanks, boss tanks) and
their UI icons, modelled and rendered in Blender with the puzzle.py / icons.py look.

  Blender -b --factory-startup --python art/blender/puzzle2.py -- <out_dir> [only...]

Writes <out_dir>/puzzle/*.png (1 unit = 1 px, front view, same framing as puzzle.py):
  canister_key.png   128x88  brass key on a dark badge, top right (image x 88..124, y 4..40)
  canister_part.png  128x88  gold rotor/gear on a dark badge, top left (image x 4..40, y 4..40)
  canister_rust.png  128x88  rust crust and weld beads round the edges; centre symbol stays clear
  tank_padlock.png   160x420 crossed chains and a padlock (centre 80,210) with an empty dark
                             socket 48 px across at image (80, 222) for the unlock colour icon
  tank_boss.png      160x420 glowing hazard rims on the tank frame; inner column fully clear
  conveyor.png       256x40  belt strip that tiles horizontally (period 32 px)
  pipe_link.png      64x40   coolant pipe between two tanks; columns 24..40 are identical,
                             so stretch it with 24 px fixed margins each side
and <out_dir>/icons/icon_<name>.png (128 px, icons.py camera and outline).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
import icons as I  # noqa: E402
import puzzle as P  # noqa: E402
from common import box, sphere, cylinder, zcyl, ycyl, xcyl, slab, ring_slab, stroke_poly, fillet, spline, toon, shade  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/railhaven_puzzle2"
ONLY = set(ARGS[1:])

M = toon
INK = P.INK
BRASS = "e9b44c"


def circle(cx, cz, r, n=24):
    return [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def centred(ob):
    """puzzle.centred that also works for rotated objects (ring_slab, ycyl): EEVEE sorts blended
    objects by origin, so move the origin to the bounds centre without moving the mesh."""
    c = sum((Vector(b) for b in ob.bound_box), Vector()) / 8
    ob.data.transform(Matrix.Translation(-c))
    ob.location += ob.matrix_basis.to_3x3() @ c
    return ob


def clip(ob, pts):
    """Trim ob to the (x, z) outline pts: boolean intersect with a prism hidden from the render."""
    cut = slab("cutter", pts, -400, 400, M("000000"))
    cut.hide_render = True
    mod = ob.modifiers.new("clip", "BOOLEAN")
    mod.operation = "INTERSECT"
    mod.object = cut
    return ob


def blob(cx, cz, rx, rz, seed, n=11, j=0.24):
    rnd = random.Random(seed)
    return spline([(cx + rx * math.cos(t) * (1 + rnd.uniform(-j, j)), cz + rz * math.sin(t) * (1 + rnd.uniform(-j, j)))
                   for t in (2 * math.pi * i / n for i in range(n))], n=3)


# ---------------------------------------------------------------- canister overlays (x -64..64, z -44..44)

def _key():
    parts = [("ring", -0.42, 0.42, 0.15, 0.42), ("stroke", [(-0.16, 0.16), (0.8, -0.8)], 0.22)]
    for (x, z), (u, w) in (((0.38, -0.38), (0.17, -0.59)), ((0.62, -0.62), (0.45, -0.79))):  # teeth on the lower-left side
        parts.append(("stroke", [(x, z), (u, w)], 0.18))
    return parts


def _rotor():
    """Toothed prop guard with a three-blade rotor inside."""
    parts = [("ring", 0.0, 0.0, 0.5, 0.74)]
    for k in range(8):
        a = k * math.pi / 4 + math.pi / 8
        c, s = math.cos(a), math.sin(a)
        parts.append(("poly", [(c * r - s * w, s * r + c * w) for r, w in ((0.68, -0.15), (0.98, -0.1), (0.98, 0.1), (0.68, 0.15))]))
    for k in range(3):
        a = math.pi / 2 + k * 2 * math.pi / 3
        blade = [(0.06 + 0.46 * t, 0.13 * math.sin(math.pi * t) ** 0.7 * (1.25 if i else -0.75))
                 for i in (0, 1) for t in ([j / 8 for j in range(9)] if i == 0 else [1 - j / 8 for j in range(1, 8)])]
        parts.append(("poly", P._rot(blade, a)))
    parts.append(("poly", circle(0, 0, 0.17, 16)))
    return parts


def badge(cx, cz, parts, s, col, details=(), y=-70.0):
    """Small dark round badge (steel rim, 18 px radius incl. outline) carrying a raised emblem."""
    ycyl("badge_rim", 15.6, 2, M("5f6a76", light=1.25), cx, cz, y, seg=48)
    ycyl("badge", 13.4, 2, M("1b2027", glow=1.0), cx, cz, y - 1, outline=False, seg=48)
    ring_slab("badge_lip", cx, cz, 13.0, 14.0, y - 2.2, y - 1.9, M("8d98a4", glow=1.0))
    P.emblem(parts, s, cx, cz, y - 5, col, edge=1.3, chamfer=0.7, details=details, detail_col="6a4a1a")


def canister_key():
    badge(42.0, 22.0, _key(), 12.5, BRASS)


def canister_part():
    badge(-42.0, 22.0, _rotor(), 12.0, "f4c75a", details=[("poly", circle(0, 0, 0.08, 12))])


# Front silhouette of a canister, pulled 1 px inside so its own ink outline stays visible.
CAN = fillet([(-56.5, -40.5), (56.5, -40.5), (56.5, -31), (54.4, -31), (54.4, 31), (56.5, 31), (56.5, 40.5), (-56.5, 40.5),
              (-56.5, 31), (-54.4, 31), (-54.4, -31), (-56.5, -31)], 6)


def canister_rust():
    """Rust crust packed into the corners and edges, weld beads along both cap seams.
    The middle (about x +-30, z +-24) stays clear for the coolant colour and emblem."""
    under, crust, flake = M("4a2312", glow=1.0), M("9a4822", light=1.22, shadow=0.7, ao=0.0), M("c26a34", light=1.18, shadow=0.76, ao=0.0)
    pit, fleck = M("33170a", glow=1.0), M("e08a42", glow=1.0)
    patches = ((-50, 33, 22, 15, 0), (49, 35, 23, 13, 1), (-47, -34, 24, 14, 2), (50, -31, 19, 17, 3), (-55, 2, 11, 20, 4),
               (55, -2, 10, 17, 5), (-12, 39, 15, 6, 6), (20, -39, 17, 6, 7), (30, 40, 10, 5, 8), (-26, -40, 10, 5, 9))
    for k, (cx, cz, rx, rz, seed) in enumerate(patches):
        b = blob(cx, cz, rx, rz, seed)
        clip(slab("rust_under", C.offset_poly(b, 1.6), -72 + k * 0.01, -40, under), CAN)
        clip(slab("rust", b, -73 + k * 0.01, -40, crust, chamfer=1.2), CAN)
        if rx > 12:  # lighter flaking layer on the bigger patches
            f = blob(cx + rx * 0.12, cz + rz * 0.15, rx * 0.55, rz * 0.5, seed + 20, n=9, j=0.3)
            clip(slab("rust_flake", C.offset_poly(f, 1.0), -75.6, -74.6, under), CAN)
            clip(slab("rust_flake", f, -76, -74.6, flake, chamfer=0.8), CAN)
        rnd = random.Random(seed + 40)
        for _ in range(int(rx * rz / 40)):  # pits and bright flecks
            a, d = rnd.uniform(0, 2 * math.pi), rnd.uniform(0.15, 0.75)
            x, z = cx + rx * d * math.cos(a), cz + rz * d * math.sin(a)
            if abs(x) < 53 and abs(z) < 39:
                r = rnd.uniform(0.8, 1.6)
                sphere("pit" if rnd.random() < 0.6 else "fleck", r, pit if rnd.random() < 0.6 else fleck, (x, -78, z), scale=(1, 0.3, 0.8), outline=False, seg=8)
    for x, z0, z1 in ((-44, 19, 10), (-36, 22, 15), (40, 23, 13), (47, 24, 7)):  # rust run-off streaks under the top patches
        slab("streak", stroke_poly([(x, z0), (x + 0.6, z1)], 2.2), -72.5, -71.5, M("6e3418", glow=1.0))
    # Weld beads along both cap seams: heat-tint halo, ink edge, then overlapping ripples.
    for zs in (30.0, -30.0):
        slab("weld_tint", stroke_poly([(-34, zs), (34, zs)], 10.0), -71.0, -70.6, M("4c3d55", glow=1.0))
        slab("weld_tint", stroke_poly([(-32, zs), (32, zs)], 6.6), -71.4, -71.1, M("8a5b2c", glow=1.0))
        slab("weld_ink", stroke_poly([(-30, zs), (30, zs)], 6.4), -71.8, -71.5, M(INK, glow=1.0))
        slab("bead", stroke_poly([(-29, zs), (29, zs)], 5.2), -74, -72, M("a39c92", light=1.24, shadow=0.66, ao=0.0), chamfer=1.0)
        ripple = M("6c665e", glow=1.0)
        for k in range(20):
            x = -27.0 + k * 2.84
            slab("ripple", stroke_poly([(x - 0.4, zs + 1.9), (x + 0.7, zs + 0.6), (x + 0.9, zs - 0.6), (x - 0.2, zs - 1.9)], 0.75), -75.4, -75.0, ripple)


# ---------------------------------------------------------------- tank overlays (x 0..160, z 0..420)

def link(name, cx, cz, ang, y, mat, flat, L=9.0, R=5.4, r=2.3):
    """Stadium-shaped chain link with straight length L, bend radius R and wire radius r.
    flat links face the camera, the others are seen edge-on."""
    path = [(L / 2 + R * math.cos(a), R * math.sin(a)) for a in (-math.pi / 2 + math.pi * k / 10 for k in range(11))]
    path += [(-L / 2 + R * math.cos(a), R * math.sin(a)) for a in (math.pi / 2 + math.pi * k / 10 for k in range(11))]
    bm = bmesh.new()
    n, seg, rings = len(path), 8, []
    for i, (u, v) in enumerate(path):
        t = Vector(path[(i + 1) % n]) - Vector(path[i - 1])
        nu, nv = t.y / t.length, -t.x / t.length
        ring = []
        for j in range(seg):
            b = 2 * math.pi * j / seg
            pu, pv, pw = u + nu * r * math.cos(b), v + nv * r * math.cos(b), r * math.sin(b)
            ring.append(bm.verts.new((pu, pw, pv) if flat else (pu, pv, pw)))
        rings.append(ring)
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for j in range(seg):
            bm.faces.new((a[j], b[j], b[(j + 1) % seg], a[(j + 1) % seg]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return C.finish(name, bm, mat, (cx, y, cz), (0, -ang, 0))


def chain(pts, y, mat, pitch=15.4, start=0):
    """Links laid along a polyline, alternating flat and edge-on."""
    k = start
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        d = math.hypot(x1 - x0, z1 - z0)
        ang = math.atan2(z1 - z0, x1 - x0)
        for i in range(int(d / pitch) + 1):
            t = i * pitch / d
            link("link", x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, ang, y + (0 if k % 2 else -1.5), mat, k % 2 == 0)
            k += 1


SOCKET = (80.0, 198.0, 25.0)   # padlock socket centre x, z and radius: image (80, 222), ~48 px dark disc


def tank_padlock():
    """Two chains crossed over the glass, hooked through a heavy padlock whose face carries an
    empty dark socket where the game draws the unlocking colour."""
    steel, dark = M("8a96a2", light=1.3, shadow=0.6), M("353d47", light=1.3)
    sx, sz, sr = SOCKET
    hook = (80.0, 251.0)
    chain([(21, 372), hook, (139, 38)], -100, steel)
    chain([(139, 372), hook, (21, 38)], -96, steel, start=1)
    for x, z in ((21, 382), (139, 382), (21, 30), (139, 30)):  # bolted anchor clamps on the collars
        box("anchor", x - 9, z - 7, x + 9, z + 7, -112, -88, dark, bevel=2.5)
        ycyl("anchor_bolt", 3.2, 2, M("aab4be", ao=0.0), x, z, -113, outline=False, seg=16)
        ycyl("anchor_bolt_dot", 1.2, 1, M("4a535e", glow=1.0), x, z, -114.4, outline=False, seg=10)
    # Shackle: thick steel U hooked round the chain crossing.
    arc = [(80 + 19 * math.cos(a), 246 + 19 * math.sin(a)) for a in (math.pi * k / 16 for k in range(17))]
    slab("shackle", stroke_poly([(99, 226)] + arc + [(61, 226)], 10.0), -110, -104, M("b4bec8", light=1.25, shadow=0.6), chamfer=1.6, outline=True)
    # Body: heavy iron block with a darker top housing, rivets and a brass-ringed socket.
    body = fillet([(36, 150), (124, 150), (124, 238), (36, 238)], 13)
    slab("body", body, -128, -108, M("4b5561", light=1.28, shadow=0.62), chamfer=2.2, outline=True)
    slab("housing", fillet([(40, 228), (120, 228), (120, 236), (40, 236)], 3), -130.6, -129.6, M("39414b", glow=1.0))
    for x in (46.0, 114.0):
        for z in (160.0, 220.0):
            sphere("rivet", 2.6, M("aab4be", ao=0.0), (x, -131, z), scale=(1, 0.6, 1), outline=False, seg=12)
    for z in (232.0,):
        for x in (52, 66, 94, 108):
            sphere("rivet", 1.7, M("8d98a4", ao=0.0), (x, -131.2, z), scale=(1, 0.6, 1), outline=False, seg=10)
    ring_slab("socket_ring", sx, sz, sr, sr + 6.5, -136, -120, M("b08a45", light=1.3, shadow=0.62), chamfer=1.8, outline=True)
    ring_slab("socket_lip", sx, sz, sr, sr + 1.6, -136.6, -135.6, M("e9c27a", glow=1.0), seg=64)
    for k in range(8):
        a = math.pi / 8 + k * math.pi / 4
        sphere("ring_rivet", 1.5, M("ffe2a0", ao=0.0), (sx + (sr + 3.6) * math.cos(a), -136.6, sz + (sr + 3.6) * math.sin(a)), outline=False, seg=10)
    ycyl("socket", sr + 0.5, 2, M("161b20", glow=1.0), sx, sz, -132, outline=False, seg=64)
    ring_slab("socket_shade", sx, sz, sr - 3.0, sr, -133.6, -133.3, M("0b0d10", glow=1.0), seg=64)
    # Light glints on the steel so it reads as metal.
    slab("glint", stroke_poly([(44, 172), (44, 212)], 2.4), -131.4, -131, M("8d98a4", glow=1.0))
    slab("glint", stroke_poly([(65, 248), (64, 255)], 2.0), -114.4, -114, M("eef4fa", glow=1.0))


INNER_CLEAR = (22.0, 138.0, 40.0, 374.0)   # tank_boss: x0, x1, z0, z1 kept fully transparent


def tank_boss():
    """Boss tank overlay: red-hot rim lights down both glass edges, hazard-striped collars,
    warning lamps at the corners and a heat haze round the outside. Inner column stays clear."""
    hot, core = M("ff4a1e", glow=1.4), M("ffc36a", glow=1.5)
    # Outer heat haze: a rounded box whose bevelled rim fades in while the flat front stays clear.
    centred(box("haze", 1, 13, 159, 409, -60, 120, P.glass("ff6a2a", (0.0, 0.3, 0.62), cuts=(0.22, 0.6), name="haze"), bevel=12, outline=False))
    for x in (14.0, 146.0):
        s = -1 if x < 80 else 1
        centred(slab("rim_glow", stroke_poly([(x, 34), (x, 380)], 9.0), -40, -39, P.glass("ff5a1a", (0.32,) * 3, name="rim_glow")))
        centred(slab("rim_glow", stroke_poly([(x - s * 5.5, 40), (x - s * 5.5, 374)], 3.0), -40.5, -39.5, P.glass("ff7a2a", (0.22,) * 3, name="rim_glow_in")))
        slab("rim_hot", stroke_poly([(x, 36), (x, 378)], 3.4), -42, -41, hot)
        slab("rim_core", stroke_poly([(x, 40), (x, 374)], 1.2), -42.6, -42.2, core)
    # Hazard bands over the top and bottom collars: dark plate with glowing diagonal stripes.
    for z0, z1 in ((384.5, 395.5), (22.0, 29.5)):
        band = fillet([(27, z0), (133, z0), (133, z1), (27, z1)], 2.5)
        slab("band", band, -84, -76, M("1a1d22", glow=1.0), chamfer=0.8, outline=True)
        inner = [(28.5, z0 + 1.4), (131.5, z0 + 1.4), (131.5, z1 - 1.4), (28.5, z1 - 1.4)]
        for k in range(12):
            x = 22 + k * 10.0
            stripe = [(x, z0 - 2), (x + 5, z0 - 2), (x + 5 + (z1 - z0 + 4) * 0.6, z1 + 2), (x + (z1 - z0 + 4) * 0.6, z1 + 2)]
            clip(slab("stripe", stripe, -86.2, -85.6, M("ff7a2a" if k % 2 else "ffa040", glow=1.3)), inner)
    # Warning lamps at the four corners, on the collar ends.
    for x in (17.0, 143.0):
        for z in (390.0, 25.5):
            for rad, a in ((11.0, 0.2), (8.0, 0.32)):
                centred(ring_slab("lamp_halo", x, z, 4.0, rad, -92 + rad * 0.05, -90, P.glass("ff3a1a", (a,) * 3, name="halo")))
            ycyl("lamp_ring", 5.6, 4, M("2b3037", light=1.3), x, z, -86, seg=32)
            ycyl("lamp", 4.0, 2, M("ff3a1e", glow=1.5), x, z, -88.4, outline=False, seg=32)
            sphere("lamp_core", 1.6, M("ffd27a", glow=1.6), (x - 0.8, -91, z + 0.8), outline=False, seg=10)
    # Glowing seams where the collars meet the glass.
    for z in (382.0, 30.5):
        slab("seam", stroke_poly([(16, z), (144, z)], 1.6), -44, -43, hot)


# ---------------------------------------------------------------- strips (conveyor 256x40, pipe link 64x40)

def conveyor():
    """Rubber belt over a roller frame. Everything repeats every 32 px and the long boxes run far
    past both ends; no AO (it is screen-space and drifts towards the image edges), so it tiles."""
    frame = M("343b44", light=1.28, shadow=0.62, ao=0.0)
    box("frame", -1000, 4, 1256, 25, -2, 30, frame, bevel=2.5)
    box("base", -1000, 1.8, 1256, 6.5, -4, 30, M("262b32", light=1.25, ao=0.0), bevel=1.2)
    roller, hub = M("6a7480", light=1.3, shadow=0.6, ao=0.0), M("aab4be", ao=0.0)
    for k in range(-2, 11):
        x = 32 * k + 16
        ycyl("roller", 7.6, 3, roller, x, 14.2, -3.5, seg=32)
        ycyl("roller_hub", 3.2, 2, hub, x, 14.2, -5.6, outline=False, seg=20)
        ycyl("roller_axle", 1.2, 1, M("2b3037", glow=1.0), x, 14.2, -7.0, outline=False, seg=12)
        for z in (8.5, 20.0):
            sphere("bolt", 1.3, M("5f6a76", ao=0.0), (x - 16, -2.4, z), scale=(1, 0.6, 1), outline=False, seg=10)
    belt = M("25282d", light=1.3, shadow=0.7, ao=0.0)
    box("belt", -1000, 24, 1256, 37.5, -8, 30, belt, bevel=3)
    paint = M("c98a2a", ao=0.0, light=1.1, shadow=0.85)
    for k in range(-2, 11):
        x = 32 * k + 16
        slab("chevron", stroke_poly([(x - 2.6, 34.2), (x + 2.4, 30.7), (x - 2.6, 27.2)], 2.6), -11.3, -10.6, paint)
        slab("groove", stroke_poly([(x - 16, 27.0), (x - 16, 34.4)], 1.4), -11.2, -10.8, M("15171b", glow=1.0))
    slab("belt_edge", [(-48, 35.2), (304, 35.2), (304, 35.9), (-48, 35.9)], -11.4, -11.0, M("3d424a", glow=1.0))


PIPE_MARGIN = 24   # pipe_link: columns 24..40 are identical; keep 24 px fixed at each end when stretching


def pipe_link():
    steel = M("7c8794", light=1.3, shadow=0.62, ao=0.0)
    # Many short rings: end normals (caps, outline rims) then only bend the last 2 px, hidden by the flanges.
    C.lathe("pipe", [(9.0, z) for z in range(-29, 30, 2)], steel, (32, 0, 20), (0, math.pi / 2, 0), seg=48)
    flange = M("4f5964", light=1.3, shadow=0.62, ao=0.0)
    for x0, x1 in ((1.0, 9.5), (54.5, 63.0)):
        xcyl("flange", 14.0, x0, x1, 20, 0, flange, seg=32)
        xcyl("weld", 10.2, x0 - 2.2 if x0 > 30 else x1, x0 if x0 > 30 else x1 + 2.2, 20, 0, M("5f6a76", ao=0.0, light=1.25), seg=32)
        xm = (x0 + x1) / 2
        for z in (9.5, 20.0, 30.5):
            sphere("bolt", 1.6, M("aab4be", ao=0.0), (xm, -math.sqrt(14.0 ** 2 - (z - 20) ** 2) - 0.5, z), outline=False, seg=10)
    # Sight glass: dark frame, coolant behind, one long horizontal glint (columns stay identical).
    slab("window_frame", stroke_poly([(19.5, 20), (44.5, 20)], 13.0), -11.0, -6, M("232a32", light=1.2, ao=0.0), chamfer=0.8)
    slab("coolant", stroke_poly([(19.5, 20), (44.5, 20)], 8.6), -12.0, -11.2, M("3a96f0", light=1.3, shadow=0.72, ao=0.0), chamfer=1.0)
    slab("glint", stroke_poly([(20.5, 22.4), (43.5, 22.4)], 1.6), -13.6, -13.2, M("dff6ff", glow=1.0))
    slab("deep", stroke_poly([(20.5, 17.4), (43.5, 17.4)], 1.4), -13.6, -13.2, M("1f5fc0", glow=1.0))
    sphere("bubble", 1.0, M("cfeeff", glow=1.0), (18.6, -13.8, 19.4), outline=False, seg=8)


# ---------------------------------------------------------------- icons (icons.py units: about -0.6..0.6)

def icon_magnet():
    red, tip = M("e0402a", light=1.25), M("dfe4ea", light=1.15)

    def build():
        arc = [(0.29 * math.cos(math.radians(a)), 0.08 + 0.29 * math.sin(math.radians(a))) for a in range(0, 181, 12)]
        C.slab("magnet", stroke_poly([(0.29, -0.34)] + arc + [(-0.29, -0.34)], 0.27), -0.12, 0.12, red, chamfer=0.045, outline=True)
        for s in (-1, 1):
            C.slab("tip", fillet([(s * 0.29 - 0.135, -0.33), (s * 0.29 + 0.135, -0.33), (s * 0.29 + 0.135, -0.55), (s * 0.29 - 0.135, -0.55)], 0.04),
                   -0.13, 0.13, tip, chamfer=0.045, outline=True)
        sphere("shine", 0.04, M("ffffff", glow=1.0), (-0.2, -0.2, 0.3), outline=False, seg=10)
    I.pivoted((-0.05, 0, 0.1), (0, -0.55, 0), build)
    spark = M("8fe6ff", glow=1.3)
    for path in (((0.42, -0.44), (0.52, -0.54)), ((0.26, -0.54), (0.3, -0.66)), ((0.52, -0.28), (0.64, -0.32))):
        C.slab("spark", stroke_poly(list(path), 0.05), -0.3, -0.28, spark)


def icon_frostcharge():
    ice, steel = M("8fdcff", light=1.3, shadow=0.68), M("8a96a2", light=1.3)
    for r, a in ((0.6, 0.14), (0.5, 0.2)):
        centred(ycyl("aura", r, 0.01, P.glass("6fdcff", (a,) * 3, name="aura"), 0, -0.1, 0.4 + r * 0.05, outline=False, seg=48))
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.38)
    C.finish("charge", bm, ice, (0, 0, -0.12), (0.3, 0.2, 0.1), (1, 1, 1.06), smooth=False)
    C.torus("band", 0.36, 0.045, M("74e0ff", glow=1.5), (0, 0, -0.12), rot=(0.12, 0, 0), outline=True)
    for x, z, h, a in ((-0.3, 0.12, 0.2, -0.8), (0.34, 0.06, 0.18, 0.95), (-0.36, -0.36, 0.16, -2.2), (0.3, -0.4, 0.17, 2.3)):
        cylinder("spike", 0.06, h, M("d4f4ff", light=1.12, shadow=0.76), (x, -0.12, z), rot=(0, a, 0), r2=0.0, seg=6)
    cylinder("cap", 0.15, 0.12, steel, (0, 0, 0.3))
    cylinder("fuse", 0.085, 0.1, steel, (0, 0, 0.4), r2=0.07)
    lever = [(0.06, 0.42)] + [(0.45 * math.cos(math.radians(a)), -0.1 + 0.45 * math.sin(math.radians(a))) for a in range(64, 4, -10)]
    C.slab("lever", stroke_poly(lever, 0.075), -0.06, 0.06, M("aab4be", light=1.25), chamfer=0.015, outline=True)
    C.torus("pin", 0.085, 0.022, M("f0b84a", light=1.3), (-0.2, -0.05, 0.42), rot=(math.pi / 2, 0.5, 0), outline=True)
    for x, z, r in ((-0.14, -0.06, 0.05), (0.1, -0.24, 0.035)):
        sphere("glint", r, M("ffffff", glow=1.2), (x, -0.42, z), outline=False, seg=10)


def icon_key():
    gold = M("f0b84a", light=1.3)

    def build():
        ring_slab("bow", -0.34, 0.0, 0.1, 0.27, -0.09, 0.09, gold, chamfer=0.035, outline=True)
        C.slab("shaft", stroke_poly([(-0.1, 0.0), (0.6, 0.0)], 0.14), -0.08, 0.08, gold, chamfer=0.03, outline=True)
        for x0, x1, z in ((0.3, 0.41, -0.19), (0.47, 0.6, -0.25)):
            C.slab("tooth", fillet([(x0, -0.02), (x1, -0.02), (x1, z), (x0, z)], 0.02), -0.08, 0.08, gold, chamfer=0.025, outline=True)
        ring_slab("collar", -0.06, 0.0, 0.0, 0.1, -0.1, 0.06, M("d8983a", light=1.3), chamfer=0.02, outline=True)
        sphere("shine", 0.035, M("ffffff", glow=1.0), (-0.44, -0.14, 0.12), outline=False, seg=10)
    I.pivoted((0.02, 0, 0.0), (0, 0.72, 0), build)


def padlock_icon(body_col, ring_col):
    steel = M("c8ccd2", light=1.2)
    arc = [(0.21 * math.cos(math.radians(a)), 0.2 + 0.21 * math.sin(math.radians(a))) for a in range(0, 181, 12)]
    C.slab("shackle", stroke_poly([(0.21, -0.08)] + arc + [(-0.21, -0.08)], 0.12), -0.07, 0.07, steel, chamfer=0.03, outline=True)
    C.slab("body", fillet([(-0.4, -0.6), (0.4, -0.6), (0.4, 0.06), (-0.4, 0.06)], 0.09), -0.15, 0.15, M(body_col, light=1.28, shadow=0.64), chamfer=0.05, outline=True)
    ring_slab("hole_ring", 0.0, -0.25, 0.1, 0.17, -0.22, -0.18, M(ring_col, light=1.3), chamfer=0.02, outline=True)
    C.slab("keyhole", circle(0.0, -0.22, 0.055, 16), -0.225, -0.2, M("15181d", glow=1.0))
    C.slab("keyslot", [(-0.03, -0.24), (0.03, -0.24), (0.045, -0.33), (-0.045, -0.33)], -0.225, -0.2, M("15181d", glow=1.0))
    for x in (-0.31, 0.31):
        for z in (-0.51, -0.03):
            sphere("rivet", 0.03, M("c8ccd2", ao=0.0), (x, -0.22, z), outline=False, seg=8)


def icon_lock():
    padlock_icon("5f6a76", "f0b84a")


def icon_streak():
    C.slab("flame", [(x * 0.46, z * 0.5 + 0.08) for x, z in P.FLAME], -0.1, 0.1, M("ff7a2a", light=1.2), chamfer=0.022, outline=True)
    C.slab("core", [(x * 0.44, z * 0.46 + 0.02) for x, z in P.FLAME_CORE], -0.13, -0.11, M("ffd060", light=1.12, ao=0.0), chamfer=0.02)
    x, z, h = 0.38, -0.36, 0.12
    for a in (math.pi / 4, -math.pi / 4):
        C.slab("x", stroke_poly([(x - h * math.cos(a), z - h * math.sin(a)), (x + h * math.cos(a), z + h * math.sin(a))], 0.08),
               -0.2, -0.12, M("fff6d0", light=1.1, ao=0.0), chamfer=0.015, outline=True)
    for dx, dz, r in ((0.2, -0.16, 0.035), (0.54, -0.18, 0.03), (0.52, -0.54, 0.025)):
        sphere("spark", r, M("ffd060", glow=1.6), (dx, -0.3, dz), outline=False, seg=8)


def icon_calendar():
    paper, red = M("eeeae2", light=1.08), M("e0402a", light=1.25)
    C.slab("page", fillet([(-0.5, -0.56), (0.5, -0.56), (0.5, 0.4), (-0.5, 0.4)], 0.08), -0.07, 0.07, paper, chamfer=0.03, outline=True)
    C.slab("header", fillet([(-0.5, 0.14), (0.5, 0.14), (0.5, 0.4), (-0.5, 0.4)], 0.08), -0.1, 0.05, red, chamfer=0.03, outline=True)
    for x in (-0.24, 0.24):
        C.slab("hole", circle(x, 0.31, 0.045, 12), -0.135, -0.12, M("6a1a12", glow=1.0))
        zcyl("ring", 0.04, 0.31, 0.54, x, -0.11, M("aab4be", light=1.3), seg=12)
    cell = M("c9c0b0", ao=0.0)
    for row in range(3):
        for col in range(4):
            x, z = -0.33 + col * 0.22, -0.02 - row * 0.17
            C.slab("cell", fillet([(x - 0.08, z - 0.06), (x + 0.08, z - 0.06), (x + 0.08, z + 0.06), (x - 0.08, z + 0.06)], 0.02), -0.105, -0.095,
                   M("f68a2a", ao=0.0) if (row, col) == (1, 2) else cell)
    ring_slab("today", 0.11, -0.19, 0.1, 0.135, -0.13, -0.11, M("e0402a", ao=0.0), outline=True, seg=32)


def icon_card():
    def build():
        C.slab("card", fillet([(-0.6, -0.4), (0.6, -0.4), (0.6, 0.38), (-0.6, 0.38)], 0.05), -0.04, 0.04, M("efe4cc", light=1.08), chamfer=0.02, outline=True)
        pic = [(-0.52, -0.31), (-0.05, -0.31), (-0.05, 0.29), (-0.52, 0.29)]
        C.slab("sky", pic, -0.066, -0.06, M("f6a03a", glow=1.0))
        C.slab("sky_top", [(-0.52, 0.12), (-0.05, 0.12), (-0.05, 0.29), (-0.52, 0.29)], -0.07, -0.066, M("f07a32", glow=1.0))
        C.slab("sun", circle(-0.22, 0.04, 0.1, 20), -0.074, -0.07, M("fff0a0", glow=1.0))
        C.slab("mesa", [(-0.52, -0.31), (-0.05, -0.31), (-0.05, -0.08), (-0.14, -0.06), (-0.17, 0.0), (-0.32, 0.0), (-0.36, -0.1), (-0.52, -0.12)],
               -0.078, -0.074, M("9a4426", glow=1.0))
        C.slab("rail", [(-0.52, -0.25), (-0.05, -0.25), (-0.05, -0.22), (-0.52, -0.22)], -0.082, -0.078, M("3a2418", glow=1.0))
        C.slab("divider", stroke_poly([(0.03, -0.3), (0.03, 0.3)], 0.018), -0.066, -0.06, M("c8b89a", glow=1.0))
        C.slab("stamp_edge", [(0.22, 0.04), (0.5, 0.04), (0.5, 0.32), (0.22, 0.32)], -0.066, -0.06, M("fbf6ea", glow=1.0))
        C.slab("stamp", [(0.25, 0.07), (0.47, 0.07), (0.47, 0.29), (0.25, 0.29)], -0.07, -0.066, M("3fb8a8", glow=1.0))
        C.slab("stamp_sun", circle(0.36, 0.18, 0.05, 16), -0.074, -0.07, M("ffe08a", glow=1.0))
        for z in (-0.06, -0.16, -0.26):
            C.slab("line", stroke_poly([(0.1, z), (0.5, z)], 0.026), -0.066, -0.06, M("8a7a66", glow=1.0))
    I.pivoted((0, 0, 0.02), (0, 0.16, 0), build)


def icon_flag():
    cylinder("pole", 0.035, 1.2, M("6a7480", light=1.3), (-0.46, 0.0, -0.04))
    sphere("knob", 0.065, M("f0b84a", light=1.3), (-0.46, 0.0, 0.6))
    white, black = M("f2f1ec", light=1.06, shadow=0.78), M("33363d", light=1.4, shadow=0.7)
    nx, nz, x0, x1, z0, z1 = 24, 8, -0.43, 0.56, -0.02, 0.56
    bm = bmesh.new()
    vs = []
    for j in range(nz + 1):
        for i in range(nx + 1):
            u, v = i / nx, j / nz
            vs.append(bm.verts.new((x0 + (x1 - x0) * u, 0.09 * math.sin(u * 2 * math.pi * 1.1) * u, z0 + (z1 - z0) * v - 0.08 * u * u + 0.03 * math.sin(u * 6.5))))
    for j in range(nz):
        for i in range(nx):
            f = bm.faces.new((vs[j * (nx + 1) + i], vs[j * (nx + 1) + i + 1], vs[(j + 1) * (nx + 1) + i + 1], vs[(j + 1) * (nx + 1) + i]))
            f.material_index = (i // 4 + j // 2) % 2
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.025)
    ob = C.finish("flag", bm, white, outline=True)
    mats = ob.data.materials
    mats[1] = black  # slot 1 held the outline; a pop() would remap the checker indices
    mats.append(C.outline_mat())
    ob.modifiers["outline"].material_offset = 2


def icon_boss():
    for r, a in ((0.66, 0.14), (0.58, 0.22)):
        centred(ycyl("halo", r, 0.01, P.glass("ff4a1a", (a,) * 3, name="halo"), 0, -0.06, 0.4 + r * 0.05, outline=False, seg=48))
    iron = M("3a3f48", light=1.35, shadow=0.66)
    for k in range(10):
        a = k * 2 * math.pi / 10
        cylinder("spike", 0.075, 0.2, iron, (math.sin(a) * 0.52, 0.12, math.cos(a) * 0.52), rot=(0, a, 0), r2=0.0, seg=12)
    ycyl("badge", 0.47, 0.14, M("8a2a1e", light=1.3, shadow=0.66), 0, 0, 0.06, seg=48)
    ycyl("badge_face", 0.4, 0.1, M("2a2d33", light=1.25), 0, 0, -0.02, seg=48)
    C.slab("flame", [(x * 0.4, z * 0.38 + 0.02) for x, z in P.FLAME], -0.1, -0.06, M("ff5a24", light=1.18, shadow=0.78), chamfer=0.02, outline=True)
    C.slab("flame_core", [(x * 0.4, z * 0.36 - 0.02) for x, z in P.FLAME_CORE], -0.11, -0.1, M("ffc04a", glow=1.2))
    C.slab("tube", stroke_poly([(0.0, -0.12), (0.0, 0.25)], 0.11), -0.16, -0.12, M("eef0f2", light=1.08), chamfer=0.02, outline=True)
    C.slab("bulb", circle(0.0, -0.2, 0.105, 24), -0.17, -0.12, M("ff3a1a", light=1.2, shadow=0.8), chamfer=0.025, outline=True)
    C.slab("mercury", stroke_poly([(0.0, -0.18), (0.0, 0.24)], 0.05), -0.2, -0.19, M("ff3a1a", glow=1.3))
    for z in (0.0, 0.08, 0.16):
        C.slab("tick", stroke_poly([(0.035, z), (0.06, z)], 0.015), -0.2, -0.19, M("4a4f58", glow=1.0))
    sphere("shine", 0.03, M("ffffff", glow=1.2), (-0.035, -0.22, -0.17), outline=False, seg=8)


def icon_fox():
    fur, cream = M("eebd78", light=1.2, shadow=0.7), M("faf3e6", light=1.05, shadow=0.84)
    inner, dark = M("f0a088", light=1.1, ao=0.0), M("2a1a14", light=1.6)
    for s in (-1, 1):
        C.slab("ear", fillet([(s * 0.06, 0.0), (s * 0.36, -0.14), (s * 0.6, 0.6)], 0.07), 0.02, 0.12, fur, chamfer=0.035, outline=True)
        C.slab("ear_in", fillet([(s * 0.15, -0.02), (s * 0.33, -0.1), (s * 0.52, 0.46)], 0.05), -0.02, 0.02, inner, chamfer=0.02)
    for s in (-1, 1):  # fluffy cheek tufts flaring out below the ears
        C.slab("tuft", spline([(s * 0.1, -0.12), (s * 0.36, -0.14), (s * 0.44, -0.3), (s * 0.3, -0.28), (s * 0.3, -0.38), (s * 0.08, -0.36)], n=3, sharp=(2, 4)),
               0.0, 0.1, cream, chamfer=0.03, outline=True)
    sphere("head", 0.27, fur, (0, 0, -0.12), scale=(1.06, 0.9, 0.9), seg=32)
    sphere("snout", 0.13, cream, (0, -0.2, -0.27), scale=(0.82, 1.05, 0.7), seg=24)
    sphere("blaze", 0.08, cream, (0, -0.21, -0.06), scale=(0.55, 0.4, 1.1), outline=False, seg=16)
    for s in (-1, 1):
        sphere("eye", 0.06, dark, (s * 0.12, -0.22, -0.08), rot=(0, s * 0.45, 0), scale=(1.15, 0.6, 0.85), outline=False, seg=16)
        sphere("eye_shine", 0.019, M("ffffff", glow=1.0), (s * 0.12 - 0.022, -0.27, -0.06), outline=False, seg=8)
        C.slab("tear", stroke_poly([(s * 0.1, -0.14), (s * 0.075, -0.2)], 0.022), -0.29, -0.27, M("9a5a2a", glow=1.0))
    sphere("nose", 0.045, dark, (0, -0.33, -0.25), scale=(1.25, 0.8, 0.8), outline=False, seg=14)
    sphere("nose_shine", 0.014, M("ffffff", glow=1.0), (-0.015, -0.37, -0.235), outline=False, seg=8)


# ---------------------------------------------------------------- main

CAN_REGION, TANK_REGION = (-64, 64, -44, 44), (0, 160, 0, 420)
PUZZLE = {
    "canister_key": (canister_key, CAN_REGION),
    "canister_part": (canister_part, CAN_REGION),
    "canister_rust": (canister_rust, CAN_REGION),
    "tank_padlock": (tank_padlock, TANK_REGION),
    "tank_boss": (tank_boss, TANK_REGION),
    "conveyor": (conveyor, (0, 256, 0, 40)),
    "pipe_link": (pipe_link, (0, 64, 0, 40)),
}
ICONS = {"magnet": icon_magnet, "frostcharge": icon_frostcharge, "key": icon_key, "lock": icon_lock, "streak": icon_streak,
         "calendar": icon_calendar, "card": icon_card, "flag": icon_flag, "boss": icon_boss, "fox": icon_fox}


def job(name, group):
    return not ONLY or name in ONLY or group in ONLY


if __name__ == "__main__":
    C.OUTLINE = 2.2
    sc, cam = C.setup_scene(samples=32)
    for name, (build, region) in PUZZLE.items():
        if not job(name, "puzzle"):
            continue
        C.clear_objects()
        build()
        C.render_region(sc, cam, *region, 1.0, os.path.join(OUT, "puzzle", name + ".png"))
        print("RENDERED", name)
    # Icons: same camera, outline and light as icons.py.
    C.OUTLINE = 0.025
    C.LIGHT_DIR = Vector((-0.55, -0.6, 0.6)).normalized()
    sc, cam = C.setup_scene(samples=32)
    cam.rotation_euler = (math.radians(78), 0, 0)
    for name, build in ICONS.items():
        if not job("icon_" + name, "icons"):
            continue
        C.clear_objects()
        build()
        sc.render.resolution_x = sc.render.resolution_y = I.SIZE
        cam.data.ortho_scale = 1.55
        cam.location = (0, -10 * math.sin(math.radians(78)), 10 * math.cos(math.radians(78)))
        sc.render.filepath = os.path.join(OUT, "icons", "icon_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDERED icon", name)
    print("DONE")

"""Railhaven train pet (a fennec fox) and the carriage livery trim, modelled and rendered in Blender.

  Blender -b --factory-startup --python art/blender/pet.py -- <out_dir> [only...]

Outputs (4 px per world unit, the crew and carriage density; transparent background):
  pet/fox_walk_0..5.png   6-frame trot, facing left
  pet/fox_sit_0..1.png    sitting, tail swish
  pet/fox_jump.png        happy leap, hind paws just leaving the ground
  pet/fox_sleep.png       curled up asleep
  pet/pet.json            canvas size, world draw size and feet anchor
  train/livery_trim.png   white trim overlay for every carriage (ART_RECT framing),
                          tinted in Godot with modulate
The out dir mirrors assets/sprites/, so build_all.sh copies it over as is.
Fox frames share one canvas: feet on a baseline BASE_PX above the bottom edge, and each
animation's union bounding box centred horizontally (so walk frames do not jitter).
"""
import bmesh
import bpy
import json
import math
import os
import sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import shade, toon  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/railhaven_pet"
ONLY = set(ARGS[1:])
PX = 4.0                      # px per world unit (crew_sprites.gd UNITS_PER_PX = 0.25)
CANVAS = (96, 96)             # fox canvas in px
BASE_PX = 4                   # feet baseline above the canvas bottom (room for the outline)
YAW = 0.35                    # three-quarter turn toward the camera, like the crew
CREW_LIGHT = Vector((-0.45, -0.75, 0.65)).normalized()

FUR = "e2b06e"
FUR_FAR = shade(FUR, 0.82)    # far-side limbs read a little darker, as on the crew
CREAM = "f7e8cb"
EAR_IN = "f3bfa0"
TIP = "3a2a22"
INK = "1c120e"


# ---------------------------------------------------------------- fox geometry

def _shape(name, bm, mat, parent, loc, rot, sc, outline):
    """Scale the mesh itself (not the object) so the inverted-hull outline stays even."""
    for v in bm.verts:
        v.co = Vector((v.co.x * sc[0], v.co.y * sc[1], v.co.z * sc[2]))
    ob = C.finish(name, bm, mat, loc, rot, (1, 1, 1), outline)
    ob.parent = parent
    return ob


def ell(name, r, sc, mat, parent, loc, rot=(0, 0, 0), outline=True, seg=24):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
    return _shape(name, bm, mat, parent, loc, rot, sc, outline)


def spun(name, prof, sc, mat, parent, loc, rot=(0, 0, 0), outline=True, seg=24):
    """(radius, z) profile spun around local Z, then squashed by sc (ears)."""
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0.0, z)) for r, z in prof]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=seg, use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _shape(name, bm, mat, parent, loc, rot, sc, outline)


def empty(name, parent=None, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    e.parent = parent
    return e


def on_head(az, el, r):
    """Point on a sphere around the head centre; az = 0 is the snout (-X), az > 0 turns to the camera."""
    return Vector((-math.cos(el) * math.cos(az), -math.cos(el) * math.sin(az), math.sin(el))) * r


EAR = [(0.0, -0.3), (1.5, -0.2), (1.6, 0.5), (1.55, 1.5), (1.3, 2.7), (0.9, 3.8), (0.45, 4.7), (0.0, 5.3)]


class Fox:
    """Empty-joint rig (as in crew.py): legs hang along -Z and swing forward (-X) with
    positive Y rotation; the tail chain points along +X and droops with positive Y rotation."""

    def __init__(self):
        fur, far, cream, ink = toon(FUR, 0.62, 1.16, ao=0.0), toon(FUR_FAR, 0.62, 1.16, ao=0.0), toon(CREAM, 0.7, 1.1, ao=0.0), toon(INK, 1.0, 1.0, ao=0.0)
        self.root = empty("root")
        self.body = empty("body", self.root, (0, 0, 6.3))
        ell("torso", 1.0, (4.4, 2.2, 2.5), fur, self.body, (0, 0, 0))
        ell("belly", 1.0, (3.4, 1.7, 1.45), cream, self.body, (-0.4, -0.6, -1.15), outline=False)
        ell("chest", 1.0, (1.6, 1.8, 2.1), cream, self.body, (-3.7, -0.35, 0.1), rot=(0, -0.3, 0))
        self.neck = empty("neck", self.body, (-3.6, 0, 1.3))
        ell("neckm", 1.0, (1.5, 1.55, 2.0), fur, self.neck, (-0.3, 0, 0.7), rot=(0, 0.45, 0))
        self.head = empty("head", self.neck, (-0.9, 0, 2.3))
        h = self.head
        ell("headm", 2.8, (1.05, 0.98, 0.92), fur, h, (0, 0, 0), seg=32)
        ell("cheek", 1.0, (1.9, 1.95, 1.15), cream, h, (-0.8, -0.45, -1.25))
        ell("muzzle", 1.0, (1.9, 0.95, 0.85), cream, h, (-2.85, -0.15, -0.85), rot=(0, 0.12, 0))
        ell("nose", 0.5, (1.0, 0.9, 0.75), ink, h, (-4.7, -0.2, -0.62), outline=False)
        ell("nose_shine", 0.14, (1, 1, 1), toon("ffffff", 1.0, 1.0, ao=0.0), h, (-4.85, -0.55, -0.42), outline=False)
        p = on_head(0.62, 0.1, 2.7)
        self.eye = ell("eye", 0.8, (0.45, 0.78, 1.18), ink, h, p, rot=(0, 0, 0.62), outline=False)
        self.shine = ell("eye_shine", 0.26, (1, 1, 1), toon("ffffff", 1.0, 1.0, ao=0.0), h, p + Vector((-0.14, -0.36, 0.38)), outline=False)
        ell("blush", 0.55, (0.3, 1.2, 0.65), toon("f08a80", 1.0, 1.0, ao=0.0), h, on_head(1.05, -0.38, 2.62), rot=(0, 0, 1.05), outline=False)
        self.mouth = [ell("mouth", 0.55, (1.2, 0.8, 0.7), toon("6a2420", 1.0, 1.0, ao=0.0), h, (-3.2, -0.55, -1.6), outline=False),
                      ell("tongue", 0.38, (1.1, 0.9, 0.7), toon("f07a78", 0.8, 1.1, ao=0.0), h, (-3.35, -0.75, -1.75), outline=False)]
        # Ears: flat cones whose openings face forward-outward; the near one shows its pink inside.
        self.ears = {}
        for side, s, x in (("N", -1, -0.1), ("F", 1, 1.2)):
            e = empty("ear" + side, h, (x, s * 1.25, 1.9))
            spun("ear", EAR, (1.0, 0.5, 1.0), fur if side == "N" else far, e, (0, 0, 0))
            spun("ear_in", [(r * 0.68, z * 0.84 + 0.4) for r, z in EAR], (1.0, 0.35, 1.0), toon(EAR_IN, 0.8, 1.1, ao=0.0), e, (0, s * 0.55, 0), outline=False)
            self.ears[side] = (e, s)
        # Legs: N = near (camera side), B = far side.
        self.j = {}
        for leg, x, z, hind in (("F", -2.8, -0.9, False), ("H", 2.9, -0.5, True)):
            for side, y in (("N", -1.15), ("B", 1.15)):
                m = fur if side == "N" else far
                top = empty("top" + leg + side, self.body, (x, y, z))
                seg = 2.7 if hind else 2.4
                if hind:
                    ell("haunch", 1.0, (1.9, 1.1, 2.1), m, top, (0.15, 0, -0.55))
                ell("upper", 0.8 if hind else 0.72, (1, 1, 1.85), m, top, (0, 0, -seg / 2))
                knee = empty("knee" + leg + side, top, (0, 0, -seg))
                ell("lower", 0.58, (1, 1, 2.2), m, knee, (0, 0, -seg / 2))
                ankle = empty("ankle" + leg + side, knee, (0, 0, -seg))
                ell("paw", 0.72, (1.4, 1.0, 0.72), toon(shade("ecc690", 0.82 if side == "B" else 1.0), 0.62, 1.16, ao=0.0), ankle, (-0.35, 0, -0.12))
                self.j[leg + side] = (top, knee)
        self.tail_mats = (fur, toon(TIP, 0.7, 1.25, ao=0.0))
        self.tail_obs = []
        self.legs = [o for o in bpy.data.objects if o.name.split(".")[0] in ("upper", "lower", "paw", "haunch")]

    def set_ears(self, back, splay=0.25):
        for side, (e, s) in self.ears.items():
            # Open forward-outward, splay sideways, then lean back; the far ear leans further
            # back so the pair reads as a V through the three-quarter turn.
            m = Matrix.Rotation(back + (0.5 if s > 0 else -0.05), 3, "Y") @ Matrix.Rotation(-s * (splay + (0.1 if s > 0 else 0.0)), 3, "X") @ Matrix.Rotation(s * 0.55, 3, "Z")
            e.rotation_euler = m.to_euler()

    def set_tail(self, joints, lengths=(1.6, 3.0, 3.1)):
        """Rebuild the tail as one smooth swept tube along a Catmull-Rom curve through the
        (droop, yaw) joint chain, plus a dark brush tip."""
        for o in self.tail_obs:
            bpy.data.objects.remove(o, do_unlink=True)
        dr, hd, pts = 0.0, 0.0, [Vector((4.0, 0.0, 0.7))]
        for (d, y), ln in zip(joints, lengths):  # angles accumulate as droop + heading, never roll
            dr, hd = dr + d, hd + y
            pts.append(pts[-1] + Matrix.Rotation(hd, 3, "Z") @ Matrix.Rotation(dr, 3, "Y") @ Vector((ln, 0, 0)))
        ctl = [2 * pts[0] - pts[1]] + pts + [2 * pts[-1] - pts[-2]]
        path = []
        for i in range(1, len(ctl) - 2):
            p0, p1, p2, p3 = ctl[i - 1:i + 3]
            for k in range(10):
                t = k / 10
                path.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
        path.append(pts[-1])
        self.tail_obs = [self._tube("tail", path, 0.0, 0.88, self.tail_mats[0], 0.0),
                         self._tube("tail_tip", path, 0.8, 1.0, self.tail_mats[1], 0.05)]

    def _tube(self, name, path, t0, t1, mat, grow, ring=18):
        def radius(t):  # thin root, bushy middle, rounded brush tip
            if t > 0.86:
                return 1.32 * max(0.0, 1 - ((t - 0.86) / 0.14) ** 1.7) ** 0.5
            ks = [(0.0, 0.7), (0.25, 1.1), (0.55, 1.5), (0.75, 1.55), (0.86, 1.32)]
            for (a, ra), (b, rb) in zip(ks, ks[1:]):
                if t <= b:
                    u = (t - a) / (b - a)
                    return ra + (rb - ra) * (3 * u * u - 2 * u * u * u)
        n = len(path) - 1
        tang = [(path[min(i + 1, n)] - path[max(i - 1, 0)]).normalized() for i in range(n + 1)]
        nrm = tang[0].cross(Vector((0, 1, 0))).normalized()
        bm = bmesh.new()
        rings = []
        for i in range(n + 1):
            t = i / n
            nrm = (nrm - tang[i] * nrm.dot(tang[i])).normalized()  # rotation-minimising frame
            if t < t0 - 1e-6 or t > t1 + 1e-6:
                continue
            r = radius(t) + grow
            bi = tang[i].cross(nrm)
            if radius(t) < 0.02:
                rings.append([bm.verts.new(path[i])])
                continue
            rings.append([bm.verts.new(path[i] + (nrm * math.cos(a) + bi * math.sin(a)) * r)
                          for a in (2 * math.pi * k / ring for k in range(ring))])
        for ra, rb in zip(rings, rings[1:]):
            if len(rb) == 1:
                for k in range(ring):
                    bm.faces.new((ra[k], ra[(k + 1) % ring], rb[0]))
            else:
                for k in range(ring):
                    bm.faces.new((ra[k], ra[(k + 1) % ring], rb[(k + 1) % ring], rb[k]))
        bm.faces.new(rings[0])
        if len(rings[-1]) > 1:
            bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return _shape(name, bm, mat, self.body, (0, 0, 0), (0, 0, 0), (1, 1, 1), True)

    def pose(self, anim, f):
        legs = {"FN": (0.0, 0.0), "FB": (0.0, 0.0), "HN": (0.45, -0.75), "HB": (0.45, -0.75)}
        tail = [(0.6, 0.0), (-0.3, 0.0), (-0.35, 0.0)]  # (droop, yaw) per joint
        pitch, head, neck, ears, closed, mouth, hide_legs = 0.0, 0.0, 0.0, 0.3, False, False, False
        if anim == "walk":  # trot: diagonal pairs (near front + far hind) move together
            p = 2 * math.pi * f / 6
            for pair, sgn in ((("FN", "HB"), 1), (("FB", "HN"), -1)):
                s, lift = sgn * math.sin(p), max(0.0, sgn * math.cos(p))
                for k in pair:
                    if k[0] == "F":
                        legs[k] = (0.45 * s + 0.3 * lift, -1.2 * lift)
                    else:
                        legs[k] = (0.45 + 0.4 * s + 0.25 * lift, -0.75 - 0.7 * lift)
            pitch = 0.03 * math.sin(2 * p)
            head = -pitch + 0.04 * math.cos(2 * p)
            tail = [(0.6 + 0.08 * math.sin(p), 0.0), (-0.3, 0.0), (-0.35 - 0.15 * math.sin(p + 1.0), 0.0)]
            ears = 0.3 + 0.06 * math.cos(2 * p)
        elif anim == "sit":
            pitch = 0.95
            legs = {"FN": (-0.95, 0.0), "FB": (-0.82, 0.0), "HN": (0.55, -2.1), "HB": (0.4, -1.9)}
            neck, head = -0.35, -0.55
            # Swish: tail along the floor behind, tip curled up, then flicked out flat.
            tail = [(0.45, -0.4), (-0.75, -0.25), (-2.1, 0.3)] if f == 0 else [(0.45, -0.4), (-0.9, -0.2), (-1.0, 0.2)]
        elif anim == "jump":
            pitch = 0.6
            legs = {"FN": (1.35, -1.5), "FB": (1.05, -1.25), "HN": (-1.05, -0.3), "HB": (-0.85, -0.5)}
            neck, head, ears, mouth = 0.1, -0.35, 0.05, True
            tail = [(-1.1, 0.0), (-0.2, 0.0), (-0.25, 0.0)]
        elif anim == "sleep":
            hide_legs, closed = True, True
            neck, head, ears = -0.75, 0.55, 1.5
            tail = [(0.85, -1.0), (-0.75, -1.35), (0.0, -1.0)]
        self.root.rotation_euler = (0, 0, YAW)
        self.root.location = (0, 0, 0)
        self.body.rotation_euler = (0, pitch, 0)
        self.body.location = (0, 0, 6.3 - (3.6 if hide_legs else 0.0))
        self.neck.rotation_euler = (0, neck, 0)
        self.head.rotation_euler = (0, head, 0)
        for k, (u, lo) in legs.items():
            top, knee = self.j[k]
            top.rotation_euler = (0, u, 0)
            knee.rotation_euler = (0, lo, 0)
        self.set_tail(tail, (1.6, 3.4, 3.6) if anim == "sleep" else (1.6, 3.0, 3.1))  # curled: wrap reaches the chin
        self.set_ears(ears)
        for o in self.legs:
            o.hide_render = hide_legs
        self.eye.scale = (1, 1, 0.2 if closed else 1.0)
        self.shine.hide_render = closed
        for o in self.mouth:
            o.hide_render = not mouth


def extents():
    """World bounds (x0, x1, z0, z1) of every visible mesh, before its outline shell."""
    bpy.context.view_layer.update()
    xs, zs = [], []
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH" and not ob.hide_render:
            for v in ob.data.vertices:
                p = ob.matrix_world @ v.co
                xs.append(p.x)
                zs.append(p.z)
    return min(xs), max(xs), min(zs), max(zs)


FRAMES = [("fox_walk_%d" % f, "walk", f) for f in range(6)] + [("fox_sit_0", "sit", 0), ("fox_sit_1", "sit", 1),
                                                                ("fox_jump", "jump", 0), ("fox_sleep", "sleep", 0)]


def build_fox():
    C.LIGHT_DIR = CREW_LIGHT
    C.OUTLINE = 0.55
    sc, cam = C.setup_scene(24)
    fox = Fox()
    w, h, base = CANVAS[0] / PX, CANVAS[1] / PX, BASE_PX / PX
    # Pass 1: drop each frame onto the baseline, and centre each animation as a group.
    group, drop = {}, {}
    for name, anim, f in FRAMES:
        fox.pose(anim, f)
        x0, x1, z0, z1 = extents()
        drop[name] = -z0
        g = group.get(anim, (x0, x1))
        group[anim] = (min(g[0], x0), max(g[1], x1))
    d = os.path.join(OUT, "pet")
    for name, anim, f in FRAMES:
        fox.pose(anim, f)
        fox.root.location = (-sum(group[anim]) / 2, 0, drop[name])
        x0, x1, z0, z1 = extents()
        pad = C.OUTLINE + 0.25
        assert abs(z0) < 1e-3 and -w / 2 < x0 - pad and x1 + pad < w / 2 and z1 + pad < h - base, (name, x0, x1, z1)
        print("FRAME", name, "x %.2f..%.2f top %.2f" % (x0, x1, z1))
        C.render_region(sc, cam, -w / 2, w / 2, -base, h - base, PX, os.path.join(d, name + ".png"))
    meta = {"canvas": list(CANVAS), "px_per_unit": PX, "world_size": [w, h], "feet": [CANVAS[0] / 2, CANVAS[1] - BASE_PX],
            "facing": "left", "frames": {"walk": 6, "sit": 2, "jump": 1, "sleep": 1}}
    with open(os.path.join(d, "pet.json"), "w") as fh:
        json.dump(meta, fh, indent=1)


# ---------------------------------------------------------------- livery trim

CAR_W, CAR_TOP, CAR_FLOOR = 232.0, 120.0, 32.0   # carriages.py W, TOP, FLOOR
WINDOW = (7.0, CAR_FLOOR, CAR_W - 7.0, CAR_TOP)   # cutaway opening; must stay clear
SKIRT = (0.0, 21.4, CAR_W, 24.2)                  # on the underframe band (z 20..26), over the tier-2 stripe
ROOF_LINE = (0.4, 123.0, CAR_W - 0.4, 124.8)       # just above the brass eave trim, over the tier-2 roof stripe
PLATE_Z, PLATE_R = 66.0, 2.9                      # end-wall plates on the bulkhead doors, between rivets


def build_livery():
    C.LIGHT_DIR = Vector((-0.5, -0.45, 0.75)).normalized()  # carriages.py light
    C.OUTLINE = 0.55
    sc, cam = C.setup_scene(16)
    white = toon("f4f4f4", 0.72, 1.08, ao=0.0)
    grey = toon("8c8c8c", 0.72, 1.15, ao=0.0)  # darker plate face so the white wheel emblem reads after tinting
    for name, (x0, z0, x1, z1) in (("skirt", SKIRT), ("roof_line", ROOF_LINE)):
        C.slab("liv_" + name, C.fillet([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], 0.5, 3), -6.9, -6.5, white, chamfer=0.22)
    for cx in (3.5, CAR_W - 3.5):
        C.ycyl("liv_plate", PLATE_R, 0.6, grey, cx, PLATE_Z, -6.6)
        C.ring_slab("liv_rim", cx, PLATE_Z, 2.25, 2.85, -7.3, -6.9, white, chamfer=0.2)
        C.ring_slab("liv_wheel", cx, PLATE_Z, 0.95, 1.4, -7.3, -6.9, white, chamfer=0.15)
        C.ycyl("liv_hub", 0.48, 0.4, white, cx, PLATE_Z, -7.1, outline=False)
        for k in range(4):
            C.box("liv_spoke", cx - 0.17, PLATE_Z - 1.05, cx + 0.17, PLATE_Z + 1.05, -7.05, -6.95, white, outline=False).rotation_euler = (0, k * math.pi / 4, 0)
    # Self-check: no trim piece (outline included) reaches into the cutaway window.
    bpy.context.view_layer.update()
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            ps = [ob.matrix_world @ v.co for v in ob.data.vertices]
            pad = C.OUTLINE if ob.modifiers else 0.0
            bx0, bx1 = min(p.x for p in ps) - pad, max(p.x for p in ps) + pad
            bz0, bz1 = min(p.z for p in ps) - pad, max(p.z for p in ps) + pad
            assert bx1 <= WINDOW[0] or bx0 >= WINDOW[2] or bz1 <= WINDOW[1] or bz0 >= WINDOW[3], (ob.name, bx0, bx1, bz0, bz1)
    C.render_region(sc, cam, -4, 236, 0, 164, PX, os.path.join(OUT, "train", "livery_trim.png"))


if __name__ == "__main__":
    if not ONLY or "fox" in ONLY:
        build_fox()
    if not ONLY or "livery" in ONLY:
        build_livery()
    print("DONE")

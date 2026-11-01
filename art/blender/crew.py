"""Railhaven crew sprites, built and rendered entirely in Blender.

Usage (headless):
  Blender -b --factory-startup --python art/blender/crew.py -- <out_dir> [preset ...]

Models a toon-shaded chibi survivor from primitives (per preset: role outfit, skin,
hair, headgear), poses an empty-joint rig per frame and renders each animation frame
with an orthographic side camera on a transparent background. art/build_sprites.py
packs the frames into sprite sheets for Godot.
"""
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/railhaven_crew"
ONLY = set(ARGS[1:])

FRAME_W, FRAME_H = 160, 200
SLEEP_W, SLEEP_H = 240, 120
PORTRAIT = 192
ORTHO = 1.30          # metres visible vertically in a crew frame
OUTLINE = 0.014       # inverted-hull thickness (m)
LIGHT_DIR = Vector((-0.45, -0.75, 0.65)).normalized()

SKIN = ["f3cba5", "dba578", "a8714b", "6b4630"]
HAIR = ["2b1d16", "6a4126", "b0672c", "e0bb73", "1d1d24", "9a9a9e"]
ROLES = {
    "Engineer":   {"shirt": "e8dcc4", "sleeve": "e8dcc4", "pants": "3d3a48", "extra": "apron", "accent": "8a5a34", "rolled": True},
    "Grower":     {"shirt": "d9cfa8", "sleeve": "d9cfa8", "pants": "5f8f3a", "extra": "overalls", "accent": "5f8f3a", "rolled": True},
    "Mechanic":   {"shirt": "4f86b0", "sleeve": "4f86b0", "pants": "3c6688", "extra": "coverall", "accent": "2f5878", "rolled": False},
    "Pilot":      {"shirt": "d9772e", "sleeve": "d9772e", "pants": "b8622a", "extra": "jumpsuit", "accent": "f0d060", "rolled": False},
    "Technician": {"shirt": "e8dcc4", "sleeve": "e8dcc4", "pants": "3d3a48", "extra": "vest", "accent": "2f9a90", "rolled": True},
    "Scientist":  {"shirt": "2f9a90", "sleeve": "eef0ec", "pants": "3d3a48", "extra": "labcoat", "accent": "eef0ec", "rolled": False},
    "Medic":      {"shirt": "4fb3a8", "sleeve": "4fb3a8", "pants": "3f9e94", "extra": "scrubs", "accent": "d83a32", "rolled": True},
}
# Two looks per role; survivors map onto these in Godot.
PRESETS = {
    "engineer_a":   ("Engineer", 0, 1, "short", "cap"),
    "engineer_b":   ("Engineer", 2, 4, "bun", "goggles"),
    "grower_a":     ("Grower", 1, 0, "ponytail", "cap"),
    "grower_b":     ("Grower", 3, 5, "short", "none"),
    "mechanic_a":   ("Mechanic", 2, 2, "short", "goggles"),
    "mechanic_b":   ("Mechanic", 0, 3, "bun", "none"),
    "pilot_a":      ("Pilot", 1, 4, "ponytail", "goggles"),
    "pilot_b":      ("Pilot", 3, 0, "short", "cap"),
    "technician_a": ("Technician", 0, 2, "bun", "none"),
    "technician_b": ("Technician", 2, 1, "short", "cap"),
    "scientist_a":  ("Scientist", 0, 5, "short", "glasses"),
    "scientist_b":  ("Scientist", 3, 4, "bun", "goggles"),
    "medic_a":      ("Medic", 1, 2, "ponytail", "cap"),
    "medic_b":      ("Medic", 2, 0, "short", "glasses"),
}
ANIMS = {  # name: frame count
    "idle": 6, "walk": 8, "carry": 8, "hammer": 8, "tend": 8, "panel": 6, "wrench": 6, "sit": 6,
}


# ---------------------------------------------------------------- materials

def lin(hexstr):
    c = [int(hexstr[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def shade(hexstr, f):
    c = [int(hexstr[i:i + 2], 16) for i in (0, 2, 4)]
    if f < 1.0:  # shadows drift warm-purple, like painted cel shading
        c = [c[0] * f + 18 * (1 - f), c[1] * f, c[2] * f + 22 * (1 - f)]
    else:
        c = [x + (255 - x) * (f - 1.0) for x in c]
    return "".join("%02x" % max(0, min(255, int(x))) for x in c)


_mats = {}


def toon(hexstr, shadow=0.62, light=1.16, glow=False):
    key = (hexstr, shadow, light, glow)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("toon_" + hexstr)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    if glow:
        emit.inputs["Color"].default_value = lin(hexstr)
        emit.inputs["Strength"].default_value = 1.6
    else:
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        dot.inputs[1].default_value = LIGHT_DIR
        nt.links.new(geo.outputs["Normal"], dot.inputs[0])
        rng = nt.nodes.new("ShaderNodeMapRange")
        rng.inputs["From Min"].default_value = -1.0
        rng.inputs["From Max"].default_value = 1.0
        nt.links.new(dot.outputs["Value"], rng.inputs["Value"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        els = ramp.color_ramp.elements
        els[0].position = 0.0
        els[0].color = lin(shade(hexstr, shadow))
        els[1].position = 0.44
        els[1].color = lin(hexstr)
        e = els.new(0.80)
        e.color = lin(shade(hexstr, light))
        nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    _mats[key] = m
    return m


def outline_mat():
    if "outline" in _mats:
        return _mats["outline"]
    m = bpy.data.materials.new("outline")
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = lin("1c120e")
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    m.use_backface_culling = True
    _mats["outline"] = m
    return m


# ---------------------------------------------------------------- geometry

def _finish(name, bm, mat, parent, loc, rot, scale, outline=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    if outline:
        ob.data.materials.append(outline_mat())
        mod = ob.modifiers.new("outline", "SOLIDIFY")
        mod.thickness = OUTLINE / max(0.2, min(scale))
        mod.offset = 1.0
        mod.use_flip_normals = True
        mod.material_offset = 1
    ob.scale = scale
    ob.rotation_euler = rot
    ob.location = loc
    if parent:
        ob.parent = parent
    return ob


def sphere(name, r, mat, parent=None, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), outline=True, seg=24):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
    return _finish(name, bm, mat, parent, loc, rot, scale, outline)


def rbox(name, size, mat, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.02, outline=True):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.verts) + list(bm.edges), offset=bevel, offset_type="OFFSET",
                        segments=3, profile=0.5, affect="EDGES", clamp_overlap=True)
    return _finish(name, bm, mat, parent, loc, rot, (1, 1, 1), outline)


def cylinder(name, r, depth, mat, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), outline=True, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=20, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    return _finish(name, bm, mat, parent, loc, rot, (1, 1, 1), outline)


def torus(name, major, minor, mat, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), outline=False, arc=1.0):
    bm = bmesh.new()
    seg_u, seg_v = 32, 10
    rings = []
    count = seg_u if arc >= 1.0 else seg_u + 1
    for i in range(count):
        a = 2 * math.pi * arc * i / seg_u
        ring = []
        for j in range(seg_v):
            b = 2 * math.pi * j / seg_v
            ring.append(bm.verts.new(((major + minor * math.cos(b)) * math.cos(a), (major + minor * math.cos(b)) * math.sin(a), minor * math.sin(b))))
        rings.append(ring)
    for i in range(count if arc >= 1.0 else count - 1):
        r0, r1 = rings[i], rings[(i + 1) % count]
        for j in range(seg_v):
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % seg_v], r0[(j + 1) % seg_v]))
    return _finish(name, bm, mat, parent, loc, rot, scale, outline)


def empty(name, parent=None, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    if parent:
        e.parent = parent
    return e


def on_head(az, el, r):
    """Point on the head sphere: az around Z from +X (face forward), el elevation."""
    return Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el))) * r


def _cut(bm, co, no):
    """Remove everything on the +normal side of a plane (clean straight edge)."""
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=Vector(no).normalized(), clear_outer=True)


def hair_cap(name, r, mat, parent, style):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=r)
    _cut(bm, (r * 0.18, 0, r * 0.12), (1.0, 0.0, -0.8))      # open the face, keep bangs on top
    _cut(bm, (0, 0, -r * (0.78 if style == "ponytail" else 0.5)), (0, 0, -1))
    _cut(bm, (r * 0.02, 0, -r * 0.1), (1.0, 0.0, -2.5))       # trim in front of the ears
    return _finish(name, bm, mat, parent, (-0.008, 0, 0.012), (0, 0, 0), (1, 1, 1), True)


# ---------------------------------------------------------------- character

class Crew:
    def __init__(self, role, skin, hair, style, hat):
        r = ROLES[role]
        self.role = role
        skin_m = toon(SKIN[skin])
        hair_m = toon(HAIR[hair], 0.55, 1.25)
        shirt = toon(r["shirt"])
        sleeve = toon(r["sleeve"])
        pants = toon(r["pants"])
        accent = toon(r["accent"])
        boot = toon("3a2a20", 0.6, 1.3)
        dark = toon("1c120e", 1.0, 1.0)

        self.root = empty("root")
        self.hips = empty("hips", self.root, (0, 0, 0.40))
        self.spine = empty("spine", self.hips, (0, 0, 0))
        self.neck = empty("neck", self.spine, (0, 0, 0.27))
        self.joints = {}
        for side, y in (("F", -0.135), ("B", 0.135)):
            sh = empty("shoulder" + side, self.spine, (0, y, 0.235))
            el = empty("elbow" + side, sh, (0, 0, -0.15))
            wr = empty("wrist" + side, el, (0, 0, -0.135))
            self.joints["shoulder" + side], self.joints["elbow" + side], self.joints["wrist" + side] = sh, el, wr
            hp = empty("hip" + side, self.hips, (0, y * 0.5, 0))
            kn = empty("knee" + side, hp, (0, 0, -0.19))
            an = empty("ankle" + side, kn, (0, 0, -0.17))
            self.joints["hip" + side], self.joints["knee" + side], self.joints["ankle" + side] = hp, kn, an
            dim = 0.82 if side == "B" else 1.0  # far limbs read slightly darker
            sl = toon(shade(r["sleeve"], dim)) if side == "B" else sleeve
            fa = toon(shade(SKIN[skin] if r["rolled"] else r["sleeve"], dim))
            pa = toon(shade(r["pants"], dim)) if side == "B" else pants
            sphere("upper" + side, 0.047, sl, sh, (0, 0, -0.075), (1, 1, 1.75))
            sphere("fore" + side, 0.04, fa, el, (0, 0, -0.065), (1, 1, 1.8))
            sphere("hand" + side, 0.04, toon(shade(SKIN[skin], dim)) if side == "B" else skin_m, wr, (0, 0, -0.01))
            sphere("thigh" + side, 0.058, pa, hp, (0, 0, -0.095), (1, 1, 1.75))
            sphere("shin" + side, 0.05, pa, kn, (0, 0, -0.085), (1, 1, 1.8))
            sphere("boot" + side, 0.05, boot, an, (0.03, 0, -0.005), (1.6, 1.0, 0.95))

        # Torso + outfit.
        rbox("torso", (0.17, 0.25, 0.29), shirt, self.spine, (0, 0, 0.135), bevel=0.06)
        ex = r["extra"]
        if ex not in ("labcoat", "scrubs"):  # coat covers the belt; scrubs have none
            torus("belt", 0.105, 0.022, toon("3a2a20"), self.spine, (0, 0, 0.015), scale=(0.88, 1.22, 1), outline=True)
            rbox("buckle", (0.02, 0.05, 0.035), toon("d8b060", 0.7, 1.3), self.spine, (0.098, 0, 0.015), bevel=0.006, outline=False)
        if ex == "apron":
            rbox("apron", (0.02, 0.2, 0.33), accent, self.spine, (0.095, 0, 0.05), bevel=0.008)
            rbox("strap", (0.012, 0.03, 0.12), toon(shade(r["accent"], 0.8)), self.spine, (0.088, 0, 0.24), rot=(0.5, 0, 0), bevel=0.004, outline=False)
        elif ex == "overalls":
            rbox("bib", (0.02, 0.16, 0.13), accent, self.spine, (0.094, 0, 0.12), bevel=0.01)
            for y in (-0.055, 0.055):
                rbox("strap", (0.012, 0.025, 0.16), accent, self.spine, (0.088, y, 0.21), bevel=0.004, outline=False)
            sphere("btn", 0.012, toon("e0c070"), self.spine, (0.106, -0.05, 0.17), outline=False)
        elif ex == "coverall":
            rbox("pocket", (0.016, 0.06, 0.05), accent, self.spine, (0.094, -0.06, 0.19), bevel=0.006)
            rbox("zip", (0.012, 0.01, 0.24), toon("cfd6dc"), self.spine, (0.094, 0.0, 0.13), bevel=0.003, outline=False)
        elif ex == "jumpsuit":
            torus("band", 0.1, 0.018, toon(r["accent"], 0.7, 1.2), self.spine, (0, 0, 0.19), scale=(0.9, 1.3, 1))
            torus("collar", 0.07, 0.024, toon(shade(r["shirt"], 1.15)), self.spine, (0, 0, 0.275), scale=(1, 1.1, 1), outline=True)
        elif ex == "vest":
            rbox("vest", (0.19, 0.27, 0.22), accent, self.spine, (0.0, 0, 0.15), bevel=0.05)
            torus("stripe", 0.103, 0.014, toon("e6f2a0", 0.8, 1.15), self.spine, (0, 0, 0.12), scale=(0.95, 1.35, 1))
        elif ex == "labcoat":  # open white coat over the shirt, hem past the hips
            rbox("coat", (0.186, 0.27, 0.35), accent, self.spine, (0, 0, 0.1), bevel=0.06)
            rbox("shirt_v", (0.02, 0.07, 0.13), shirt, self.spine, (0.094, 0, 0.2), bevel=0.008, outline=False)
            for y, a in ((-0.036, 0.3), (0.036, -0.3)):
                rbox("lapel", (0.016, 0.03, 0.15), toon(shade(r["accent"], 0.92)), self.spine, (0.099, y, 0.19), rot=(a, 0, 0), bevel=0.006, outline=False)
            rbox("coat_pocket", (0.014, 0.06, 0.05), toon(shade(r["accent"], 0.9)), self.spine, (0.096, -0.07, 0.02), bevel=0.006, outline=False)
            rbox("pen", (0.008, 0.008, 0.045), toon("2a5ad0"), self.spine, (0.1, -0.075, 0.2), bevel=0.002, outline=False)
        elif ex == "scrubs":  # V-neck, red-cross chest patch and armband
            rbox("vneck", (0.012, 0.05, 0.05), toon(SKIN[skin]), self.spine, (0.088, 0, 0.262), rot=(math.pi / 4, 0, 0), bevel=0.004, outline=False)
            rbox("patch", (0.012, 0.06, 0.06), toon("f4f4f0"), self.spine, (0.092, -0.055, 0.18), bevel=0.008)
            rbox("patch_v", (0.006, 0.014, 0.042), accent, self.spine, (0.1, -0.055, 0.18), bevel=0.0, outline=False)
            rbox("patch_h", (0.006, 0.042, 0.014), accent, self.spine, (0.1, -0.055, 0.18), bevel=0.0, outline=False)
            sh = self.joints["shoulderF"]
            torus("armband", 0.049, 0.013, toon("f4f4f0"), sh, (0, 0, -0.06), outline=True)
            rbox("arm_cross_v", (0.012, 0.006, 0.026), accent, sh, (0, -0.062, -0.06), bevel=0.0, outline=False)
            rbox("arm_cross_h", (0.026, 0.006, 0.012), accent, sh, (0, -0.062, -0.06), bevel=0.0, outline=False)

        # Head.
        self.head = empty("head", self.neck, (0, 0, 0.0))
        cylinder("neckm", 0.04, 0.06, toon(shade(SKIN[skin], 0.85)), self.neck, (0, 0, 0.02), outline=False)
        hc = Vector((0.01, 0, 0.19))
        R = 0.165
        sphere("headm", R, skin_m, self.head, hc, seg=32)
        sphere("ear", 0.035, skin_m, self.head, hc + Vector((-0.01, -0.15, -0.005)))
        hair_cap("hair", R * 1.08, hair_m, self.head, style)
        self.hair_parts = []
        if style == "bun":
            sphere("bun", 0.07, hair_m, self.head, hc + Vector((-0.13, 0, 0.11)))
        elif style == "ponytail":
            sphere("tail", 0.055, hair_m, self.head, hc + Vector((-0.19, 0, -0.04)), (1, 1, 2.1), rot=(0, -0.5, 0))
        # Face (front = +X).
        black = toon("1c120e", 1.0, 1.0)
        for az in (-0.42, 0.42):
            p = hc + on_head(az, -0.02, R * 0.97)
            sphere("eye", 0.024, black, self.head, p, (0.55, 0.8, 1.35), rot=(0, 0, az), outline=False)
            sphere("shine", 0.008, toon("ffffff", 1.0, 1.0), self.head, p + Vector((0.016, -0.004, 0.014)), outline=False)
            sphere("brow", 0.022, toon(shade(HAIR[hair], 0.7)), self.head, hc + on_head(az, 0.32, R * 0.99), (0.4, 1.3, 0.35), rot=(0, 0, az), outline=False)
            sphere("blush", 0.03, toon("f08a80", 1.0, 1.0), self.head, hc + on_head(az * 1.45, -0.3, R * 0.95), (0.3, 1.2, 0.7), rot=(0, 0, az * 1.45), outline=False)
        sphere("nose", 0.02, skin_m, self.head, hc + on_head(-0.05, -0.18, R * 0.99), outline=False)
        sphere("mouth", 0.016, toon("5a2018", 1.0, 1.0), self.head, hc + on_head(-0.12, -0.4, R * 0.97), (0.35, 1.1, 0.4), rot=(0, 0.45, -0.12), outline=False)
        if hat == "cap":
            cap_col = {"Grower": "4f7a32", "Medic": "3f9e94"}.get(role, "6e5a3c")
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=R * 1.12)
            _cut(bm, (0, 0, R * 0.25), (0, 0, -1))
            _finish("cap", bm, toon(cap_col), self.head, hc + Vector((-0.005, 0, 0.005)), (0, 0, 0), (1, 1, 1))
            if role != "Medic":  # medics wear a brimless scrub cap
                cylinder("brim", 0.11, 0.016, toon(shade(cap_col, 0.85)), self.head, hc + Vector((0.13, 0, 0.055)), rot=(0, -0.18, 0))
        elif hat == "glasses":
            frame = toon("3a2a2a", 0.7, 1.3)
            for az in (-0.42, 0.42):
                torus("glasses", 0.036, 0.0065, frame, self.head, hc + on_head(az, -0.02, R * 1.03), rot=(0, math.pi / 2, az), outline=False)
            a, b = hc + on_head(-0.2, -0.0, R * 1.04), hc + on_head(0.2, -0.0, R * 1.04)
            cylinder("bridge", 0.005, (b - a).length, frame, self.head, (a + b) / 2, rot=(b - a).to_track_quat("Z", "Y").to_euler(), outline=False)
            a, b = hc + on_head(-0.64, 0.0, R * 1.02), hc + Vector((-0.04, -0.158, 0.01))
            cylinder("temple", 0.005, (b - a).length, frame, self.head, (a + b) / 2, rot=(b - a).to_track_quat("Z", "Y").to_euler(), outline=False)
        elif hat == "goggles":
            torus("strap", R * 1.06, 0.016, toon("3a3230"), self.head, hc + Vector((0, 0, 0.06)), rot=(0, -0.25, 0), outline=False)
            for az in (-0.4, 0.4):
                p = hc + on_head(az, 0.38, R * 1.04)
                cylinder("lensrim", 0.042, 0.03, toon("c08a3a", 0.6, 1.3), self.head, p, rot=(0, math.pi / 2 - 0.38, az))
                cylinder("lens", 0.031, 0.034, toon("7fe0e8", 0.75, 1.3), self.head, p + on_head(az, 0.38, 0.004), rot=(0, math.pi / 2 - 0.38, az), outline=False)

        # Props (toggled per animation).
        wf = self.joints["wristF"]
        self.props = {}
        steel = toon("aeb6be", 0.6, 1.3)
        self.props["hammer"] = [
            cylinder("hhandle", 0.012, 0.2, toon("7a5230"), wf, (0.0, 0, -0.06), rot=(0, math.pi / 2, 0)),
            rbox("hhead", (0.04, 0.04, 0.09), toon("8a929a", 0.6, 1.3), wf, (0.09, 0, -0.06), bevel=0.008),
        ]
        self.props["can"] = [
            cylinder("can", 0.045, 0.07, toon("5aa0c8"), wf, (0.03, 0, -0.05)),
            cylinder("spout", 0.01, 0.09, toon("5aa0c8"), wf, (0.1, 0, -0.03), rot=(0, 1.0, 0)),
        ]
        self.props["wrench"] = [
            rbox("wh", (0.018, 0.012, 0.15), steel, wf, (0.0, 0, -0.08), bevel=0.004),
            torus("wr", 0.022, 0.009, steel, wf, (0, 0, -0.165), rot=(math.pi / 2, 0, 0), outline=True),
        ]
        self.props["pad"] = [
            rbox("pad", (0.012, 0.09, 0.07), toon("2a3a44"), wf, (0.02, 0, -0.03), bevel=0.006),
            rbox("screen", (0.004, 0.075, 0.055), toon("7ff0e0", glow=True), wf, (0.03, 0, -0.03), bevel=0.0, outline=False),
        ]
        self.props["cup"] = [cylinder("cup", 0.022, 0.05, toon("d8d0bc"), wf, (0.02, 0, -0.02))]
        self.props["crate"] = [rbox("crate", (0.16, 0.15, 0.12), toon("9a6a3a"), self.spine, (0.17, 0, 0.12), bevel=0.01),
                               rbox("crateband", (0.165, 0.155, 0.02), toon("6a4424"), self.spine, (0.17, 0, 0.12), bevel=0.0, outline=False)]
        self.root.rotation_euler = (0, 0, -0.62)  # three-quarter view toward the camera
        self.eyes = [o for o in bpy.data.objects if o.name.startswith("eye")]

    def show_prop(self, name):
        for k, objs in self.props.items():
            for o in objs:
                o.hide_render = (k != name)

    def limb(self, side, upper, lower, leg=False):
        # Forward swing = negative rotation about +Y for hanging limbs.
        a = self.joints[("hip" if leg else "shoulder") + side]
        b = self.joints[("knee" if leg else "elbow") + side]
        a.rotation_euler = (0, -upper, 0)
        b.rotation_euler = (0, lower if leg else -lower, 0)

    def pose(self, anim, f, n):
        ph = math.sin(2 * math.pi * f / n)
        co = math.cos(2 * math.pi * f / n)
        bob, lean, sit = 0.0, 0.0, False
        legs = [(0.0, 0.0), (0.0, 0.0)]
        arms = [(0.15, 0.25), (-0.1, 0.2)]
        prop = None
        if anim in ("walk", "carry"):
            legs = [(0.5 * ph, max(0.0, -ph) * 0.8), (-0.5 * ph, max(0.0, ph) * 0.8)]
            bob = abs(co) * 0.018
            if anim == "walk":
                arms = [(-0.55 * ph, 0.35), (0.55 * ph, 0.35)]
            else:
                arms = [(1.15, 0.55), (1.05, 0.55)]
                prop = "crate"
        elif anim == "idle":
            bob = ph * 0.004
            arms = [(0.12 + ph * 0.03, 0.25), (-0.08 - ph * 0.03, 0.2)]
        elif anim == "hammer":
            k = f / n
            swing = (1.0 - k / 0.7) if k < 0.7 else (k - 0.7) / 0.3
            swing = max(0.0, min(1.0, swing))
            arms = [(0.9 + 1.8 * swing, 0.5 - 0.9 * swing), (0.9, 0.6)]
            lean = 0.08
            prop = "hammer"
        elif anim == "tend":
            lean = 0.2 + ph * 0.08
            arms = [(0.95 + ph * 0.2, 0.3), (0.6, 0.3)]
            prop = "can"
        elif anim == "panel":
            arms = [(1.25 + ph * 0.08, 0.6), (1.05 - ph * 0.08, 0.7)]
            prop = "pad" if f < n // 2 else None
        elif anim == "wrench":
            arms = [(1.0 + ph * 0.35, 0.3), (0.7, 0.3)]
            lean = 0.1
            prop = "wrench"
        elif anim == "sit":
            sit = True
            legs = [(1.5, 1.5), (1.45, 1.45)]
            eat = f in (2, 3)
            arms = [(2.2, 1.4) if eat else (0.9, 0.4), (0.8, 0.4)]
            prop = "cup"
        self.hips.location = (0, 0, 0.40 + bob - (0.14 if sit else 0.0))
        self.spine.rotation_euler = (0, lean, 0)
        self.head.rotation_euler = (0, -lean * 0.5 + (0.06 if anim == "tend" else 0.0), 0)
        self.limb("F", *arms[0])
        self.limb("B", *arms[1])
        self.limb("F", *legs[0], leg=True)
        self.limb("B", *legs[1], leg=True)
        self.show_prop(prop)


# ---------------------------------------------------------------- scene / render

def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    try:
        sc.eevee.taa_render_samples = 24
    except Exception:
        pass
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.rotation_euler = (math.pi / 2, 0, 0)
    sc.camera = cam
    return sc, cam


def frame_camera(sc, cam, w, h, ortho, center):
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    cam.data.ortho_scale = ortho * max(w, h) / h
    cam.location = (center[0], -10.0, center[1])


def render(sc, path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def build_preset(name):
    role, skin, hair, style, hat = PRESETS[name]
    sc, cam = setup_scene()
    crew = Crew(role, skin, hair, style, hat)
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    # Feet sit 10 px above the frame bottom.
    frame_camera(sc, cam, FRAME_W, FRAME_H, ORTHO, (0.02, ORTHO * 0.5 - 0.081))
    for anim, n in ANIMS.items():
        for f in range(n):
            crew.pose(anim, f, n)
            render(sc, os.path.join(d, "%s_%02d.png" % (anim, f)))
    # Portrait: head and shoulders, turned a little more toward the camera.
    crew.pose("idle", 0, 6)
    crew.root.rotation_euler = (0, 0, -0.8)
    frame_camera(sc, cam, PORTRAIT, PORTRAIT, 0.62, (0.0, 0.76))
    render(sc, os.path.join(d, "portrait.png"))
    # Sleeping: lying on the back, eyes shut, under a blanket.
    crew.root.rotation_euler = (0, 0, 0)
    crew.pose("idle", 0, 6)
    for e in crew.eyes:
        e.scale = (0.55, 0.8, 0.25)
    for o in bpy.data.objects:
        if o.name.startswith("shine"):
            o.hide_render = True
    crew.root.rotation_euler = (0, -math.pi / 2, 0)
    crew.root.location = (0.42, 0.0, 0.12)
    blanket_col = {"Engineer": "4f7f8a", "Grower": "6f8a4a", "Mechanic": "5a6a9a", "Pilot": "8a5a4a", "Technician": "3f7a74",
                   "Scientist": "6f6a9a", "Medic": "8aa4ae"}[role]
    blanket = rbox("blanket", (0.66, 0.36, 0.2), toon(blanket_col), None, (-0.08, -0.02, 0.18), bevel=0.07)
    rbox("fold", (0.08, 0.37, 0.205), toon(shade(blanket_col, 1.2)), None, (-0.37, -0.02, 0.185), bevel=0.04)
    frame_camera(sc, cam, SLEEP_W, SLEEP_H, 0.62, (0.0, 0.27))
    for f in range(4):
        blanket.scale = (1.0, 1.0, 1.0 + 0.04 * math.sin(f * math.pi / 2))
        render(sc, os.path.join(d, "sleep_%02d.png" % f))


if __name__ == "__main__":
    for name in PRESETS:
        if ONLY and name not in ONLY:
            continue
        print("BUILD", name)
        build_preset(name)
    print("DONE")

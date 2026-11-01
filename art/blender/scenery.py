"""Railhaven scenery strips, modelled and rendered in Blender.

  Blender -b --factory-startup --python art/blender/scenery.py -- <out_dir> [only...]

Each parallax strip covers world x 0..720 and tiles seamlessly (objects near an edge
are duplicated one strip-width over). World y = -Blender Z; rails at 0, horizon at -70.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
from common import box, prism, toon, lin, shade  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/railhaven_scenery"
ONLY = set(ARGS[1:])
WIDTH = 720.0
HZ = 70.0  # horizon height (world y = -70)


# ---------------------------------------------------------------- materials

def _mat(name):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    for n in list(m.node_tree.nodes):
        m.node_tree.nodes.remove(n)
    return m


def _blend(m):
    for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
        try:
            setattr(m, attr, val)
        except Exception:
            pass


def gradient(stops, z0, z1, alpha=1.0):
    """Flat emissive vertical gradient: stops = [(t, hex)], t=0 at z0, 1 at z1."""
    m = _mat("grad")
    nt = m.node_tree
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = z0
    rng.inputs["From Max"].default_value = z1
    nt.links.new(sep.outputs["Z"], rng.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = stops[0][0], lin(stops[0][1])
    els[1].position, els[1].color = stops[-1][0], lin(stops[-1][1])
    for t, c in stops[1:-1]:
        e = els.new(t)
        e.color = lin(c)
    nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    if alpha < 1.0:
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        mix.inputs["Fac"].default_value = alpha
        nt.links.new(tr.outputs[0], mix.inputs[1])
        nt.links.new(emit.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
        _blend(m)
    else:
        nt.links.new(emit.outputs[0], out.inputs["Surface"])
    return m


def glow_mat(hexstr, alpha, radial=True):
    """Soft emissive disc fading to transparent at the edge (sun halo, dust, mist)."""
    m = _mat("glow")
    nt = m.node_tree
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = lin(hexstr)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL" if radial else "LINEAR"
    nt.links.new(tc.outputs["Object"], grad.inputs["Vector"])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = alpha
    nt.links.new(grad.outputs["Fac"], mul.inputs[0])
    nt.links.new(mul.outputs[0], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(emit.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    _blend(m)
    return m


def terrain(base, haze=0.0, haze_col="f2b070", strata=True):
    """Sandstone toon material: colour bands by height, 3 light bands, distance haze."""
    m = _mat("terrain")
    nt = m.node_tree
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = Vector((-0.7, -0.35, 0.62)).normalized()
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    light = nt.nodes.new("ShaderNodeValToRGB")
    light.color_ramp.interpolation = "CONSTANT"
    le = light.color_ramp.elements
    le[0].position, le[0].color = 0.0, (0.66, 0.6, 0.7, 1)
    le[1].position, le[1].color = 0.35, (1, 1, 1, 1)
    e = le.new(0.8)
    e.color = (1.22, 1.15, 1.05, 1)
    nt.links.new(dot.outputs["Value"], light.inputs["Fac"])
    col = nt.nodes.new("ShaderNodeRGB")
    col.outputs[0].default_value = lin(base)
    src = col.outputs[0]
    if strata:
        geo2 = nt.nodes.new("ShaderNodeNewGeometry")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo2.outputs["Position"], sep.inputs[0])
        wave = nt.nodes.new("ShaderNodeMath")
        wave.operation = "SINE"
        sc = nt.nodes.new("ShaderNodeMath")
        sc.operation = "MULTIPLY"
        sc.inputs[1].default_value = 0.35
        nt.links.new(sep.outputs["Z"], sc.inputs[0])
        nt.links.new(sc.outputs[0], wave.inputs[0])
        bands = nt.nodes.new("ShaderNodeValToRGB")
        bands.color_ramp.interpolation = "CONSTANT"
        be = bands.color_ramp.elements
        be[0].position, be[0].color = 0.0, lin(shade(base, 0.92))
        be[1].position, be[1].color = 0.5, lin(base)
        rng = nt.nodes.new("ShaderNodeMapRange")
        rng.inputs["From Min"].default_value = -1.0
        rng.inputs["From Max"].default_value = 1.0
        nt.links.new(wave.outputs[0], rng.inputs["Value"])
        nt.links.new(rng.outputs["Result"], bands.inputs["Fac"])
        src = bands.outputs["Color"]
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(src, mul.inputs["A"])
    nt.links.new(light.outputs["Color"], mul.inputs["B"])
    hz = nt.nodes.new("ShaderNodeMix")
    hz.data_type = "RGBA"
    hz.inputs["Factor"].default_value = haze
    hz.inputs["B"].default_value = lin(haze_col)
    nt.links.new(mul.outputs["Result"], hz.inputs["A"])
    nt.links.new(hz.outputs["Result"], emit.inputs["Color"])
    return m


# ---------------------------------------------------------------- shapes

def plane(name, x0, z0, x1, z1, y, mat):
    bm = bmesh.new()
    vs = [bm.verts.new((x0, y, z0)), bm.verts.new((x1, y, z0)), bm.verts.new((x1, y, z1)), bm.verts.new((x0, y, z1))]
    bm.faces.new(vs)
    return C.finish(name, bm, mat, outline=False, smooth=False)


def disc(name, cx, cz, r, y, mat):
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=48, radius=r)
    ob = C.finish(name, bm, mat, (cx, y, cz), (math.pi / 2, 0, 0), outline=False, smooth=False)
    return ob


def rock(name, x, z, w, h, y, mat, seed, depth=None, flat=0.0, outline=True, jag=0.18):
    """Noise-displaced boulder or mesa sitting on z (base); flat > 0 shaves a flat top."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    off = Vector((seed * 7.31, seed * 3.17, seed * 1.91))
    for v in bm.verts:
        n = noise.noise(v.co * 1.7 + off)
        v.co *= 1.0 + n * jag
        if v.co.z < 0:
            v.co.z *= 0.15
        if flat > 0 and v.co.z > 1.0 - flat:
            v.co.z = 1.0 - flat + (v.co.z - (1.0 - flat)) * 0.1
    sx, sy, sz = w, depth if depth else w * 0.6, h / (1.0 - flat * 0.9)
    return C.finish(name, bm, mat, (x, y, z), (0, 0, 0), (sx, sy, sz), outline, smooth=False)


def wrap_duplicates():
    """Copy every object one strip-width left and right so the render tiles."""
    for ob in list(bpy.data.objects):
        if ob.type in ("CAMERA",) or ob.get("nowrap"):
            continue
        for dx in (-WIDTH, WIDTH):
            c = ob.copy()
            c.location.x += dx
            bpy.context.scene.collection.objects.link(c)


def scrub(x, z, y, s, mat, seed):
    rnd = random.Random(seed)
    for k in range(5):
        a = rnd.uniform(-0.9, 0.9)
        length = s * rnd.uniform(1.2, 2.0)
        C.cylinder("twig", 0.25 * s / 3, length, mat, (x + math.sin(a) * length / 2, y, z + math.cos(a) * length / 2), rot=(0, a, 0), outline=False, seg=6)


# ---------------------------------------------------------------- layers

def sky():
    stops = [(0.0, "ffcf80"), (0.07, "ffc46c"), (0.24, "f39a45"), (0.34, "d8692b"), (0.46, "98401f"), (0.65, "441a0f"), (1.0, "1c0c09")]
    plane("sky", -300, -60, 900, 900, 50, gradient(stops, -60, 900))
    sun = (118, 172)
    disc("halo", sun[0], sun[1], 170, 40, glow_mat("ffb060", 0.45))
    disc("halo2", sun[0], sun[1], 80, 39, glow_mat("ffd890", 0.6))
    disc("sun", sun[0], sun[1], 38, 38, toon("ffd890", glow=1.0))
    disc("core", sun[0] - 4, sun[1] + 4, 31, 37, toon("ffe8b8", glow=1.0))
    rnd = random.Random(4)
    for i in range(7):
        x, z = rnd.uniform(-150, 750), 300 + i * 50 + rnd.uniform(-12, 12)
        ob = disc("cloud", x, z, rnd.uniform(60, 130), 30 - i * 0.1, glow_mat("ffd0a0", 0.12))
        ob.scale = (1.0, 0.16, 1.0)


def far():
    rnd = random.Random(11)
    city = terrain("c46a36", haze=0.35, strata=False)
    win = toon("9a4a26", ao=0.0)
    x = 0.0
    while x < WIDTH:
        w, h = rnd.uniform(8, 22), rnd.uniform(18, 64) + (rnd.uniform(30, 60) if rnd.random() < 0.3 else 0)
        box("bldg", x, HZ - 2, x + w, HZ + h, 40, 40 + w * 0.6, city, outline=False)
        if rnd.random() < 0.45:
            prism("broken", [(x, HZ + h), (x + w, HZ + h), (x + w * rnd.uniform(0.2, 0.8), HZ + h + rnd.uniform(6, 18))], 40, 40 + w * 0.6, city, outline=False)
        for k in range(int(h / 12)):
            if rnd.random() < 0.35:
                wx = x + 2 + rnd.uniform(0, w - 5)
                box("window", wx, HZ + h - 8 - k * 11, wx + 2, HZ + h - 5.5 - k * 11, 39.6, 40, win, outline=False)
        x += w + rnd.uniform(4, 36)
    mesa = terrain("bf5f2e", haze=0.28)
    for i in range(7):
        cx = rnd.uniform(0, WIDTH)
        top, half = rnd.uniform(60, 130), rnd.uniform(26, 70)
        rock("mesa", cx, HZ - 1, half, top, 20, mesa, i + 1, depth=half * 0.5, flat=0.25, outline=False, jag=0.12)
        for k in range(2):
            sx = cx + rnd.uniform(-half * 0.4, half * 0.4)
            rock("spire", sx, HZ + top * 0.7, 5, rnd.uniform(20, 40), 18, mesa, 50 + i * 3 + k, outline=False, jag=0.25)


def mid():
    rnd = random.Random(23)
    stone = terrain("93401d", haze=0.12, strata=False)
    dark = terrain("78331a", haze=0.1)
    vx, deck = 120.0, HZ + 58
    box("deck", vx, deck - 6, vx + 300, deck, 20, 30, stone)
    for i in range(8):
        px = vx + i * 38.0
        if i == 5:
            continue
        box("pier", px, HZ - 2, px + 7, deck - 6, 20, 30, stone)
        # Spandrel above each arch: deck underside down to the springing line, arch cut out.
        arch = [(px + 7, deck - 6), (px + 38, deck - 6), (px + 38, deck - 22)]
        arch += [(px + 22.5 + math.cos(a) * 15.5, deck - 22 + math.sin(a) * 12) for a in [k * math.pi / 8 for k in range(1, 8)]]
        arch += [(px + 7, deck - 22)]
        prism("arch", arch, 20, 30, stone)
    prism("collapse", [(vx + 190, deck - 6), (vx + 228, deck - 6), (vx + 222, HZ)], 20, 30, dark)
    for k in range(6):
        rock("rubble", vx + 200 + k * 7, HZ - 1, 5, rnd.uniform(4, 9), 16, dark, 100 + k)
    for i in range(5):
        tx = rnd.uniform(440, 700) if i < 3 else rnd.uniform(0, 110)
        th, lean = rnd.uniform(40, 95), rnd.uniform(-0.12, 0.12)
        t = box("tower", tx - 6, HZ - 2, tx + 6, HZ + th, 18, 28, dark)
        t.rotation_euler = (0, lean, 0)
        for k in range(4):
            box("tower_win", tx - 2.5, HZ + th * (k + 1) / 5.0, tx + 2.5, HZ + th * (k + 1) / 5.0 + 3, 17.4, 18, toon("4a1c0e", ao=0.0), outline=False)
    for i in range(9):
        rock("hill", rnd.uniform(0, WIDTH), HZ - 2, rnd.uniform(30, 80), rnd.uniform(6, 16), 24, dark, 200 + i, depth=20)


def near():
    rnd = random.Random(37)
    plane("ground", -40, -2, WIDTH + 40, HZ + 1, 40, gradient([(0.0, "a9532a"), (0.55, "c8692f"), (1.0, "d98444")], -2, HZ + 1))
    sand = terrain("bf6230", haze=0.05, strata=False)
    for i in range(6):
        dx, dz = rnd.uniform(0, WIDTH), rnd.uniform(14, HZ - 10)
        rock("dune", dx, dz, rnd.uniform(60, 140), rnd.uniform(4, 8), 30, sand, 300 + i, depth=10, jag=0.08, outline=False)
    stone = terrain("7a3418", strata=False)
    twig = toon("5a2412", ao=0.0)
    for i in range(30):
        x, z = rnd.uniform(0, WIDTH), rnd.uniform(6, HZ - 6)
        s = 1.5 + (HZ - z) / HZ * 4.0
        if rnd.random() < 0.55:
            rock("rock", x, z, s * 1.4, s, 20 - z * 0.1, stone, 400 + i)
        else:
            scrub(x, z, 20 - z * 0.1, s, twig, 500 + i)
    pole = toon("5a2412")
    for i in range(3):
        px = 80.0 + i * 240.0
        box("pole", px, HZ - 4, px + 2, HZ + 30, 25, 27, pole, outline=False)
        box("arm", px - 6, HZ + 27, px + 8, HZ + 28.6, 25, 27, pole, outline=False)
        cu = bpy.data.curves.new("wire", "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = 0.25
        sp = cu.splines.new("POLY")
        sp.points.add(16)
        for k in range(17):
            f = k / 16
            sp.points[k].co = (px + 1 + f * 240.0, 25, HZ + 27.5 - math.sin(f * math.pi) * 6.0, 1)
        wob = bpy.data.objects.new("wire", cu)
        bpy.context.scene.collection.objects.link(wob)
        wob.data.materials.append(toon("4a1c0e", ao=0.0))


def track():
    plane("ballast", -40, -12, WIDTH + 40, 6, 10, gradient([(0.0, "3a2216"), (0.7, "5a3522"), (1.0, "7a4a2c")], -12, 6))
    tie = toon("3a2618")
    for i in range(int(WIDTH / 12)):
        box("tie", i * 12.0, -5, i * 12.0 + 8, -1, 0, 6, tie)
    rnd = random.Random(5)
    stones = [toon("8a5a3a", ao=0.0), toon("2a1810", ao=0.0)]
    for i in range(160):
        x = rnd.uniform(0, WIDTH)
        C.sphere("gravel", rnd.uniform(0.4, 0.9), stones[i % 2], (x, -1, rnd.uniform(-11, -4)), scale=(1.4, 1, 0.8), outline=False, seg=6)
    box("rail", -40, -0.6, WIDTH + 40, 1.6, -2, 0, toon("7d8189", light=1.6), outline=False)
    box("rail_head", -40, 0.8, WIDTH + 40, 1.6, -2.2, -1.8, toon("e2e5ea", ao=0.0), outline=False)


def front():
    plane("ground", -40, -300, WIDTH + 40, -8, 60, gradient([(0.0, "2e1208"), (0.55, "5a2512"), (0.85, "86391a"), (1.0, "9c4a22")], -300, -8))
    rnd = random.Random(51)
    mid_rock = terrain("5a2412", strata=False)
    dark_rock = terrain("361408", strata=False)
    for i in range(14):
        x, z = rnd.uniform(0, WIDTH), -rnd.uniform(40, 260)
        s = 6 + (-z - 40) / 220 * 20
        rock("frock", x, z, s * 1.6, s * 1.1, 30, mid_rock if z > -120 else dark_rock, 600 + i)
    crate = toon("5a3a2a")
    for i in range(4):
        x, z = rnd.uniform(0, WIDTH), -rnd.uniform(30, 70)
        box("salvage", x, z, x + 14, z + 9, 28, 36, crate)
        box("salvage_band", x, z + 5.5, x + 14, z + 6.5, 27.6, 28, toon("8a5a3a", ao=0.0), outline=False)
    twig = toon("5a2412", ao=0.0)
    for i in range(22):
        scrub(rnd.uniform(0, WIDTH), -rnd.uniform(16, 120), 26, rnd.uniform(3, 5), twig, 700 + i)


def tower(restored):
    base = terrain("4a2416", strata=False) if not restored else terrain("3a4a52", strata=False)
    lit = toon("8a5a3a") if not restored else toon("6a8a96")
    for sd in (-1, 1):
        prism("pylon", [(sd * 62, 0), (sd * 34, 72), (sd * 27, 72), (sd * 48, 0)], -4, 4, base)
    C.cylinder("shaft", 19, 150, base, (0, 0, 75), r2=10, seg=24)
    for k in range(5):
        z = 150 * (0.18 + k * 0.17)
        r = 19 - (19 - 10) * z / 150 + 3
        C.cylinder("ring", r, 3.2, lit, (0, 0, z), seg=24)
    C.cylinder("crown", 16, 18, base, (0, 0, 159), r2=13, seg=24)
    C.cylinder("mast", 2, 24, base, (0, 0, 180), seg=12)
    C.torus("dish", 6, 1.2, base, (10, 0, 176), rot=(0, math.pi / 2, 0), outline=True)
    if restored:
        for k in range(3):
            C.cylinder("glowband", 15 - k, 1.8, toon("66ffe8", glow=1.6), (0, -0.5, 150 * (0.3 + k * 0.25)), seg=24, outline=False)
        C.sphere("beacon", 3, toon("b0ffff", glow=2.0), (0, -1, 194), outline=False)
    else:
        C.sphere("beacon", 2, toon("ff5a40", glow=1.6), (0, -1, 194), outline=False)


# ---------------------------------------------------------------- regions 2-5
# Each region swaps sky / far / mid; near, track and front stay shared (Godot tints them).

def haze_mat(hexstr, z0, z1, a0, a1):
    """Flat colour whose opacity runs from a0 at z0 to a1 at z1 (sea haze, mist banks, beams)."""
    m = _mat("haze")
    nt = m.node_tree
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = z0
    rng.inputs["From Max"].default_value = z1
    rng.inputs["To Min"].default_value = a0
    rng.inputs["To Max"].default_value = a1
    nt.links.new(sep.outputs["Z"], rng.inputs["Value"])
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = lin(hexstr)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(rng.outputs["Result"], mix.inputs["Fac"])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(emit.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    _blend(m)
    return m


def band(name, x0, z0, x1, z1, y, hexstr, a0, a1):
    """Full-width fading strip; nowrap because it already spans past both tile edges."""
    ob = plane(name, x0, z0, x1, z1, y, haze_mat(hexstr, z0, z1, a0, a1))
    ob["nowrap"] = True
    return ob


def soft(name, cx, cz, rx, rz, y, hexstr, alpha):
    """Glow ellipse: a unit disc scaled up, so the radial fade spans the whole shape."""
    ob = disc(name, cx, cz, 1.0, y, glow_mat(hexstr, alpha))
    ob.scale = (rx, rz, 1.0)
    return ob


def glint(x, z, y, r, col="ffffff"):
    pts = [(x + math.cos(i * math.pi / 4) * (r if i % 2 == 0 else r * 0.22),
            z + math.sin(i * math.pi / 4) * (r if i % 2 == 0 else r * 0.22)) for i in range(8)]
    prism("glint", pts, y - 0.3, y, toon(col, glow=1.6), outline=False)
    soft("glint_halo", x, z, r * 1.5, r * 1.5, y + 0.1, col, 0.55)


def rect(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


def tilt(pts, cx, cz, a):
    """Rotate 2D outline points counter-clockwise by a radians about (cx, cz)."""
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (z - cz) * s, cz + (x - cx) * s + (z - cz) * c) for x, z in pts]


def pivot(loc, rot):
    p = bpy.data.objects.new("pivot", None)
    bpy.context.scene.collection.objects.link(p)
    p.location, p.rotation_euler = loc, rot
    return p


def bake(p, parts):
    """Build parts around a rotated pivot, then freeze their world transforms (wrap-safe)."""
    for ob in parts:
        ob.parent = p
    bpy.context.view_layer.update()
    for ob in parts:
        mw = ob.matrix_world.copy()
        ob.parent = None
        ob.matrix_world = mw
    bpy.data.objects.remove(p, do_unlink=True)


def shard(name, x, z, w, h, y, mat, lean, outline=False, sides=4):
    """Faceted crystal spike: low-poly frustum leaning by `lean` radians, base buried at z."""
    return C.cylinder(name, w, h, mat, (x + math.sin(lean) * h / 2, y, z + math.cos(lean) * h / 2 - 2),
                      rot=(0, lean, math.pi / sides), r2=w * 0.18, seg=sides, outline=outline)


def dome(name, r, h, mat, x, z, y, outline=True):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=12, radius=r)
    for v in bm.verts:
        v.co.z *= h / r
    return C.finish(name, bm, mat, (x, y, z), outline=outline)


SKIES = {
    "coast": dict(stops=[(0.0, "f2b48a"), (0.11, "f0a27a"), (0.17, "e09c88"), (0.24, "c49aa8"), (0.33, "a08cb0"),
                         (0.45, "7a6c98"), (0.65, "463c62"), (1.0, "1e1830")],
                  sun=(430, 150, 26, "ffd6b0", "fff2e2"), halo="ffc8a8", haze="f8d0b8", cloud="f0d0dc", clouds=6),
    "glass": dict(stops=[(0.0, "fffdf2"), (0.12, "fff9e2"), (0.2, "fff1c0"), (0.3, "fbe6a4"), (0.42, "f2d08a"),
                         (0.6, "dcb070"), (1.0, "a8804a")],
                  sun=(300, 240, 40, "fff8d8", "ffffff"), halo="fff4c0", haze="fffbea", cloud="fffbe8", clouds=3),
    "city": dict(stops=[(0.0, "ffc27e"), (0.11, "ffa262"), (0.17, "f48660"), (0.24, "d0786c"), (0.31, "9c7c80"),
                        (0.39, "5f8288"), (0.5, "366a72"), (0.68, "1c444e"), (1.0, "0a1c24")],
                 sun=(520, 96, 30, "ff9a52", "ffc890"), halo="ff9a60", haze="ffb080", cloud="f0a088", clouds=5),
    "highland": dict(stops=[(0.0, "ffdcb6"), (0.11, "ffcfa8"), (0.17, "f6c8ac"), (0.24, "dcc4bc"), (0.31, "b8c4d2"),
                            (0.4, "94b2cc"), (0.52, "7096bc"), (0.7, "4a6c98"), (1.0, "223658")],
                     sun=(180, 190, 28, "ffe2b8", "fff8e8"), halo="ffdcb8", haze="ffe4cc", cloud="fff2ea", clouds=7),
}


def region_sky(r):
    s = SKIES[r]
    plane("sky", -300, -60, 900, 900, 50, gradient(s["stops"], -60, 900))
    x, z, rad, rim, core = s["sun"]
    soft("halo", x, z, rad * 5, rad * 5, 41, s["halo"], 0.4)
    soft("halo2", x, z, rad * 2.2, rad * 2.2, 40, core, 0.55)
    disc("sun", x, z, rad, 38, toon(rim, glow=1.0))
    disc("core", x - rad * 0.1, z + rad * 0.1, rad * 0.82, 37, toon(core, glow=1.0))
    band("haze", -300, -60, 900, HZ + 70, 44, s["haze"], 0.85, 0.0)
    rnd = random.Random(4)
    for i in range(s["clouds"]):
        cx, cz = rnd.uniform(-150, 750), HZ + 130 + i * 48 + rnd.uniform(-14, 14)
        soft("cloud", cx, cz, rnd.uniform(80, 160), rnd.uniform(7, 12), 30 - i * 0.1, s["cloud"], 0.4)


# --- Ash Coast: grey-violet ash dunes, a still dead sea, rusted hulks and broken piers

COAST_HAZE = "e8cfc8"


def far_coast():
    rnd = random.Random(61)
    sea_top = HZ + 24
    plane("sea", -40, HZ - 4, WIDTH + 40, sea_top, 30,
          gradient([(0.0, "86829c"), (0.45, "aca6ba"), (0.85, "d8cfd4"), (1.0, "efe4de")], HZ - 4, sea_top))["nowrap"] = True
    shine = toon("f4ecec", ao=0.0)
    for i in range(34):
        sx, sz = rnd.uniform(0, WIDTH), rnd.uniform(HZ + 2, sea_top - 2)
        box("shimmer", sx, sz, sx + rnd.uniform(8, 50) * (sz - HZ) / 24, sz + 0.5, 29.5, 29.7, shine, outline=False)
    head = terrain("7e7090", haze=0.38, haze_col=COAST_HAZE)
    for i, (cx, w, h) in enumerate(((60, 60, 16), (250, 44, 12), (430, 70, 22))):
        rock("headland", cx, sea_top - 4, w, h, 40, head, 70 + i, depth=30, flat=0.35, jag=0.1, outline=False)
    lh = toon("8c7e96", ao=0.0)
    prism("tanker", [(520, sea_top - 4), (590, sea_top - 4), (598, sea_top + 4), (518, sea_top + 4)], 31, 33, lh, outline=False)
    box("tanker_house", 522, sea_top + 3, 534, sea_top + 11, 31, 32, lh, outline=False)
    box("tanker_mast", 572, sea_top + 3, 573.5, sea_top + 16, 31, 32, lh, outline=False)
    band("sea_haze", -40, sea_top - 8, WIDTH + 40, sea_top + 30, 29, "f2d4c4", 0.6, 0.0)
    cliff = terrain("6e6080", haze=0.2, haze_col=COAST_HAZE)
    rock("cliff", 640, HZ - 2, 62, 58, 24, cliff, 75, depth=26, flat=0.3, jag=0.14, outline=False)
    rock("cliff2", 700, HZ - 2, 34, 34, 22, cliff, 76, depth=20, flat=0.2, jag=0.14, outline=False)
    lh = toon("5e5070", ao=0.0)
    box("lighthouse", 628, HZ + 50, 635, HZ + 96, 23, 25, lh, outline=False)
    prism("lh_top", [(626, HZ + 96), (637, HZ + 96), (634.5, HZ + 104), (628.5, HZ + 104)], 23, 25, lh, outline=False)
    box("lh_band", 628, HZ + 74, 635, HZ + 78, 22.6, 23, toon("8c7e96", ao=0.0), outline=False)
    ash = terrain("8a7a8c", haze=0.18, haze_col=COAST_HAZE)
    for i in range(5):
        rock("dune", 30 + i * 120 + rnd.uniform(-20, 20), HZ - 2, rnd.uniform(40, 80), rnd.uniform(4, 9), 15, ash, 80 + i, depth=10, jag=0.08, outline=False)


def ship(x0, b, length, a, y, hull, accent, dark):
    """Beached hull profile with a stern bridge, tilted by a about its keel centre."""
    L = length
    cx = x0 + L / 2
    T = lambda pts: tilt([(x0 + x, b + z) for x, z in pts], cx, b, a)  # noqa: E731
    prism("hull", T([(0, 0), (L * 0.86, 0), (L, L * 0.13), (L * 1.04, L * 0.22), (-4, L * 0.22), (-6, L * 0.17), (-2, L * 0.06)]), y, y + 20, hull)
    prism("hull_band", T([(-4, L * 0.19), (L * 1.03, L * 0.19), (L * 1.04, L * 0.22), (-4, L * 0.22)]), y - 0.4, y, accent, outline=False)
    prism("waterline", T([(1, L * 0.05), (L * 0.88, L * 0.05), (L * 0.92, L * 0.075), (1, L * 0.075)]), y - 0.4, y, dark, outline=False)
    for hx, hz, hw, hh in ((0.32, 0.07, 0.07, 0.06), (0.58, 0.04, 0.05, 0.09), (0.7, 0.11, 0.04, 0.04)):
        prism("hole", T([(L * hx, L * hz), (L * (hx + hw), L * (hz + 0.01)), (L * (hx + hw * 0.8), L * (hz + hh)), (L * (hx + 0.01), L * (hz + hh * 0.8))]), y - 0.5, y, dark, outline=False)
    for k in range(int(L / 14)):
        px, pz = T([(12 + k * 14, L * 0.15)])[0]
        C.ycyl("porthole", 1.3, 0.6, dark, px, pz, y - 0.4, outline=False, seg=10)
    top = L * 0.22
    prism("bridge", T(rect(4, top, L * 0.28, top + L * 0.13)), y + 3, y + 17, hull)
    prism("bridge2", T(rect(10, top + L * 0.13, L * 0.22, top + L * 0.2)), y + 5, y + 15, hull)
    prism("bridge_win", T(rect(12, top + L * 0.15, L * 0.2, top + L * 0.18)), y + 2.6, y + 3, dark, outline=False)
    prism("funnel", T([(L * 0.12, top + L * 0.2), (L * 0.19, top + L * 0.2), (L * 0.2, top + L * 0.29), (L * 0.13, top + L * 0.29)]), y + 7, y + 13, accent)
    prism("mast", T(rect(L * 0.72, top, L * 0.72 + 2.2, top + L * 0.27)), y + 9, y + 11, hull)
    prism("boom", T([(L * 0.72, top + L * 0.23), (L * 0.95, top + L * 0.1), (L * 0.95, top + L * 0.09), (L * 0.72 + 2, top + L * 0.21)]), y + 9.5, y + 10.5, hull)


def pier(x0, n, y, deck_to, mat, rnd):
    """Pilings every 13 units; the deck runs to deck_to then sags into the ash."""
    top = HZ + 22
    for i in range(n):
        px = x0 + i * 13
        ph = top - rnd.uniform(0, 3) if px < deck_to + 20 else HZ + rnd.uniform(6, 16)
        p = C.zcyl("piling", 1.7, HZ - 4, ph, px, y, mat, seg=10)
        p.rotation_euler = (0, rnd.uniform(-0.08, 0.08), 0)
    box("deck", x0 - 4, top - 1, deck_to, top + 3, y - 4, y + 4, mat)
    box("rail", x0 - 4, top + 7, deck_to - 6, top + 8, y - 3.5, y - 2.5, mat)
    for i in range(int((deck_to - x0) / 13)):
        box("post", x0 + i * 13 - 0.6, top + 3, x0 + i * 13 + 0.6, top + 8, y - 3.5, y - 2.5, mat)
    prism("sag", [(deck_to, top - 1), (deck_to, top + 3), (deck_to + 30, HZ + 4), (deck_to + 24, HZ)], y - 4, y + 4, mat)


def mid_coast():
    rnd = random.Random(71)
    rust = terrain("80402a", haze=0.1, haze_col=COAST_HAZE, strata=False)
    rust2 = terrain("6e3a2a", haze=0.1, haze_col=COAST_HAZE, strata=False)
    accent = toon("a8603a", ao=0.0)
    dark = toon("2a1a1c", ao=0.0)
    ship(80, HZ - 7, 175, 0.045, 14, rust, accent, dark)
    ship(520, HZ - 6, 84, -0.16, 18, rust2, accent, dark)
    wood = terrain("6a5a5c", haze=0.12, haze_col=COAST_HAZE, strata=False)
    pier(340, 9, 22, 410, wood, rnd)
    for i in range(5):
        px = 640 + i * 13
        C.zcyl("stub", 1.7, HZ - 4, HZ + rnd.uniform(5, 15), px, 22, wood, seg=10).rotation_euler = (0, rnd.uniform(-0.15, 0.15), 0)
    ash = terrain("7e6e82", haze=0.12, haze_col=COAST_HAZE, strata=False)
    for x, w in ((40, 40), (150, 60), (275, 45), (470, 50), (560, 40), (690, 50)):
        rock("drift", x + rnd.uniform(-10, 10), HZ - 2, w, rnd.uniform(6, 12), 8, ash, 90 + int(x), depth=12, jag=0.08)
    for i in range(6):
        rock("hill", rnd.uniform(0, WIDTH), HZ - 2, rnd.uniform(30, 70), rnd.uniform(5, 12), 26, ash, 120 + i, depth=20, jag=0.08)


# --- Glass Flats: white-gold fused sand, cracked crystal slabs, dead solar fields

GLASS_HAZE = "fff2d0"


def far_glass():
    rnd = random.Random(81)
    plane("flat", -40, HZ - 4, WIDTH + 40, HZ + 10, 30,
          gradient([(0.0, "e2c890"), (0.6, "f4e2b4"), (1.0, "fff6dc")], HZ - 4, HZ + 10))["nowrap"] = True
    for i in range(18):
        sx, sz = rnd.uniform(0, WIDTH), rnd.uniform(HZ + 2, HZ + 9)
        box("sheen", sx, sz, sx + rnd.uniform(10, 40), sz + 0.5, 29.5, 29.7, toon("fffcf0", ao=0.0), outline=False)
    mesa = terrain("caa468", haze=0.32, haze_col=GLASS_HAZE)
    for i in range(5):
        cx = 90 + i * 145 + rnd.uniform(-30, 30)
        rock("plateau", cx, HZ + 6, rnd.uniform(30, 64), rnd.uniform(26, 58), 40, mesa, 140 + i, depth=30, flat=0.45, jag=0.08, outline=False)
    crystal = toon("c4e2dc", shadow=0.78, light=1.2, ao=0.0)
    crystal2 = toon("eadaa8", shadow=0.78, light=1.2, ao=0.0)
    for c, cx in enumerate((20, 205, 380, 560)):
        cx += rnd.uniform(-20, 20)
        for k in range(rnd.randint(3, 5)):
            h = rnd.uniform(50, 95) if k == 0 else rnd.uniform(20, 55)
            lean = rnd.uniform(-0.12, 0.12) if k == 0 else (0.25 + rnd.uniform(0, 0.3)) * (1 if k % 2 else -1)
            shard("shard", cx + (k - 2) * rnd.uniform(3, 6), HZ + 6, rnd.uniform(5, 10) if k else 11, h, 34 + k * 0.3, crystal if (c + k) % 3 else crystal2, lean)
            if k == 0:
                glint(cx + math.sin(lean) * h * 0.9, HZ + 4 + math.cos(lean) * h * 0.9, 32, 4.0)
    band("heat", -40, HZ + 6, WIDTH + 40, HZ + 50, 29, "fff8e4", 0.6, 0.0)
    slab = toon("dcefe8", shadow=0.82, light=1.15, ao=0.0)
    for i in range(6):
        sx = rnd.uniform(0, WIDTH)
        s = box("slab", sx - rnd.uniform(14, 26), HZ - 4, sx + rnd.uniform(14, 26), HZ + rnd.uniform(5, 9), 18, 26, slab, outline=False)
        s.rotation_euler = (0, rnd.uniform(-0.25, 0.25), 0)
    for i in range(14):
        glint(rnd.uniform(0, WIDTH), rnd.uniform(HZ + 2, HZ + 8), 17, rnd.uniform(1.6, 3.2))


def solar_panel(x, z, y, tilt_x, roll, broken, rnd, mats, w=26.0, h=13.0):
    frame, cell, line, crack, post = mats
    h_post = 8 if tilt_x > -1.2 else 2
    box("post", x - 1.0, z, x + 1.0, z + h_post, y + 1, y + 2.6, post)
    p = pivot((x, y, z + h_post + h * 0.35), (tilt_x, roll, 0))
    parts = [box("frame", -w / 2, -h / 2, w / 2, h / 2, -0.4, 0.4, frame),
             box("cells", -w / 2 + 0.8, -h / 2 + 0.8, w / 2 - 0.8, h / 2 - 0.8, -0.7, -0.4, cell, outline=False)]
    for k in range(1, 6):
        lx = -w / 2 + k * w / 6
        parts.append(box("grid", lx - 0.2, -h / 2 + 0.8, lx + 0.2, h / 2 - 0.8, -0.8, -0.7, line, outline=False))
    parts.append(box("grid", -w / 2 + 0.8, -0.2, w / 2 - 0.8, 0.2, -0.8, -0.7, line, outline=False))
    if broken:
        cx = rnd.uniform(-4, 4)
        parts.append(prism("crack", [(cx - 3, h / 2 - 0.8), (cx + 4, h / 2 - 0.8), (cx + 1, -1.5), (cx + 2.5, -h / 2 + 0.8), (cx - 1, -0.5)], -0.9, -0.8, crack, outline=False))
    bake(p, parts)
    if not broken and rnd.random() < 0.5:
        glint(x + rnd.uniform(-w * 0.3, w * 0.3), z + h_post + h * 0.35 + rnd.uniform(0, 3), y - 3, rnd.uniform(1.8, 2.8))


def mid_glass():
    rnd = random.Random(91)
    mats = (toon("bcb6a6"), toon("2e4a76", light=1.25, ao=0.0), toon("7a9cc4", ao=0.0), toon("141a28", ao=0.0), toon("8a8274"))
    sand = terrain("dcc088", haze=0.1, haze_col=GLASS_HAZE, strata=False)
    for cx in (40, 300, 520):
        rock("ridge", cx, HZ - 2, rnd.uniform(70, 100), rnd.uniform(14, 18), 34, sand, 150 + cx, depth=16, jag=0.05)
    for cx, n in ((20, 4), (290, 5), (510, 4)):
        for row, (y, zb) in enumerate(((30, HZ + 10), (18, HZ - 1))):
            for k in range(n - 1 + row):
                x = cx + k * 30 - 45 + row * 14 + rnd.uniform(-3, 3)
                state = rnd.random()
                tx = -1.35 if state < 0.15 else -0.7 + rnd.uniform(-0.15, 0.15)
                roll = rnd.uniform(-0.35, 0.35) if state < 0.35 else rnd.uniform(-0.05, 0.05)
                solar_panel(x, zb, y, tx, roll, state < 0.45, rnd, mats)
    slab = toon("cfe8e0", shadow=0.78, light=1.18)
    slab2 = toon("eadcae", shadow=0.78, light=1.18)
    crack = toon("7e9e98", ao=0.0)
    for sx, sw, sh, a in ((160, 20, 9, 0.22), (420, 26, 8, -0.12), (660, 18, 7, 0.3)):
        p = pivot((sx, 0, HZ), (0, a, 0))
        bake(p, [box("slab", -sw, -6, sw, sh, 12, 18, slab),
                 prism("slab_crack", [(-3, sh), (1, sh), (2, 1), (-1, -2), (0, 2)], 11.4, 11.6, crack, outline=False)])
        lx, lz = sw * 0.45, sh  # glint on the top edge, rotated like the slab
        glint(sx + lx * math.cos(a) + lz * math.sin(a), HZ - lx * math.sin(a) + lz * math.cos(a), 10.5, 3.0)
    for cx in (175, 400):
        for k, (dx, w, h, lean) in enumerate(((0, 9, 52, -0.08), (-9, 6, 30, -0.45), (10, 7, 36, 0.35), (4, 4, 18, 0.7))):
            shard("monolith", cx + dx, HZ - 2, w, h, 22 - k, slab if k % 2 == 0 else slab2, lean, outline=True)
        glint(cx - 2, HZ + 44, 18, 4.0)
    for i in range(6):
        rock("dune", rnd.uniform(0, WIDTH), HZ - 2, rnd.uniform(30, 70), rnd.uniform(5, 9), 9, sand, 160 + i, depth=14, jag=0.08)


# --- Drowned City: ruined skyline, buried overpasses, flooded hollows at dusk

CITY_HAZE = "e89a78"


def ruin(name, x, w, base, h, y, mat, rnd, lean=0.0):
    """Skyscraper outline with a broken, jagged top."""
    top = base + h
    pts = [(x, base), (x + w, base), (x + w, top - rnd.uniform(0, h * 0.25))]
    for k in range(rnd.randint(2, 4)):
        pts.append((x + w * (0.8 - k * 0.22) + rnd.uniform(-2, 2), top - rnd.uniform(0, h * 0.18)))
    pts.append((x, top - rnd.uniform(0, h * 0.2)))
    if lean:
        pts = tilt(pts, x + w / 2, base, lean)
    prism(name, pts, y, y + w * 0.6, mat, outline=False)
    return min(z for _, z in pts[2:])


def far_city():
    rnd = random.Random(101)
    back = terrain("526278", haze=0.42, haze_col=CITY_HAZE, strata=False)
    front = terrain("3a4852", haze=0.22, haze_col=CITY_HAZE, strata=False)
    win = toon("2c3840", ao=0.0)
    lit = toon("ffb06a", glow=1.0)
    x = 0.0
    while x < WIDTH:
        w = rnd.uniform(14, 32)
        ruin("bldg_back", x, w, HZ - 2, rnd.uniform(60, 165), 40, back, rnd, rnd.choice((0, 0, 0, 0.06, -0.05)))
        x += w + rnd.uniform(2, 16)
    x = rnd.uniform(0, 20)
    while x < WIDTH:
        w, h = rnd.uniform(12, 28), rnd.uniform(36, 120)
        lean = rnd.choice((0, 0, 0, 0, 0.08, -0.1))
        roof = ruin("bldg", x, w, HZ - 2, h, 25, front, rnd, lean)
        if not lean:
            for row in range(int((roof - HZ - 8) / 7)):
                for col in range(int((w - 4) / 5)):
                    if rnd.random() < 0.5:
                        wx, wz = x + 3 + col * 5, HZ + 4 + row * 7
                        box("window", wx, wz, wx + 2.2, wz + 3, 24.6, 25, lit if rnd.random() < 0.06 else win, outline=False)
            if rnd.random() < 0.3:
                box("mast", x + w * 0.4, roof - 2, x + w * 0.4 + 1.2, roof + rnd.uniform(14, 30), 26, 27, front, outline=False)
            if rnd.random() < 0.4:
                box("slab", x - 3, roof - 6, x + w * 0.6, roof - 5, 24.5, 26, front, outline=False)
        x += w + rnd.uniform(6, 40)
    band("mist", -40, HZ - 4, WIDTH + 40, HZ + 46, 20, "f2a888", 0.65, 0.0)


def reflect(x0, x1, top, bottom, y, col, rnd):
    """Broken horizontal slices under an object standing on the far bank of a flood."""
    m = toon(col, ao=0.0)
    z, k = top, 0
    while z - 1.2 > bottom:
        inset = k * 0.6 + rnd.uniform(0, 1.2)
        if x1 - x0 - 2 * inset > 1:
            box("refl", x0 + inset + rnd.uniform(-1, 1), z - 1.2, x1 - inset + rnd.uniform(-1, 1), z, y, y + 0.2, m, outline=False)
        z -= 1.9
        k += 1


BANK = HZ + 18  # far edge of the flood water; things on the far bank stand here


def flood(x0, x1, y, rnd, objs):
    """Still water patch from HZ-4 to the far bank at BANK with reflections of objs = [(x0, x1, hex)]."""
    prism("water", [(x0, HZ - 4), (x1, HZ - 4), (x1 - 14, BANK), (x0 + 14, BANK)], y, y + 0.2, gradient([(0.0, "2a545c"), (0.45, "4f7a7e"), (0.8, "d8987c"), (1.0, "f6b48a")], HZ - 4, BANK), outline=False)
    for ox0, ox1, col in objs:
        reflect(max(x0 + 14, ox0), min(x1 - 14, ox1), BANK - 1, HZ + 1, y - 0.4, col, rnd)
    shine = toon("ffd2a8", ao=0.0)
    for i in range(int((x1 - x0) / 12)):
        sx, sz = rnd.uniform(x0 + 16, x1 - 34), rnd.uniform(HZ + 2, BANK - 2)
        box("ripple", sx, sz, sx + rnd.uniform(6, 18), sz + 0.5, y - 0.8, y - 0.6, shine, outline=False)


def mid_city():
    rnd = random.Random(111)
    conc = terrain("8a7672", haze=0.12, haze_col=CITY_HAZE, strata=False)
    conc2 = terrain("5e5462", haze=0.1, haze_col=CITY_HAZE, strata=False)
    win = toon("2a2630", ao=0.0)
    rebar = toon("3a2a24", ao=0.0)
    deck = HZ + 40
    # overpass: buried in a dune on the left, snapped at x=300, next span collapsed
    box("deck", 10, deck, 300, deck + 7, 22, 34, conc)
    box("barrier", 10, deck + 7, 296, deck + 10, 21.6, 23, conc)
    for i in range(int(286 / 8)):
        box("barrier_gap", 14 + i * 8, deck + 8, 16 + i * 8, deck + 9.5, 21.4, 21.6, conc2, outline=False)
    for px in (70, 140, 210, 270):
        box("pillar", px - 4, BANK - 3 if 100 < px < 250 else HZ - 2, px + 4, deck, 25, 31, conc)
        box("cap", px - 8, deck - 3, px + 8, deck, 24, 32, conc)
    prism("snap", [(300, deck), (306, deck + 3), (300, deck + 7)], 22, 34, conc)
    prism("fallen", tilt(rect(312, deck, 412, deck + 7), 412, HZ - 2, 0.4), 22, 34, conc)
    for k in range(5):
        C.cylinder("rebar", 0.4, rnd.uniform(6, 11), rebar, (302 + rnd.uniform(0, 3), 20.5, deck + rnd.uniform(1, 6)), rot=(0, math.pi / 2 + rnd.uniform(-0.6, 0.6), 0), outline=False, seg=6)
    flood(100, 250, 18, rnd, [(136, 144, "4a4450"), (206, 214, "4a4450")])
    # ruined blocks on the right, one sinking and tilted
    blocks = []
    for bx, bw, bh, a in ((440, 34, 52, 0.0), (488, 26, 72, -0.07), (560, 40, 38, 0.0), (630, 28, 60, 0.12)):
        pts = tilt([(bx, BANK - 3), (bx + bw, BANK - 3), (bx + bw, BANK + bh - 6), (bx + bw * 0.6, BANK + bh), (bx + bw * 0.3, BANK + bh - 9), (bx, BANK + bh - 3)], bx + bw / 2, BANK, a)
        prism("block", pts, 20, 32, conc if bh > 45 else conc2)
        for row in range(int((bh - 12) / 9)):
            for col in range(int((bw - 6) / 7)):
                wpts = tilt(rect(bx + 4 + col * 7, BANK + 6 + row * 9, bx + 8 + col * 7, BANK + 11 + row * 9), bx + bw / 2, BANK, a)
                prism("window", wpts, 19.6, 20, win, outline=False)
        blocks.append((bx + 2, bx + bw - 2, "4e4652"))
    flood(450, 700, 16, rnd, blocks)
    sand = terrain("a07c62", haze=0.12, haze_col=CITY_HAZE, strata=False)
    for x, w, h in ((30, 60, 26), (92, 18, 10), (262, 22, 9), (330, 40, 12), (430, 30, 10), (712, 20, 9)):
        rock("drift", x, HZ - 3, w, h, 10, sand, 170 + x, depth=12, jag=0.08)
    for i in range(5):
        rock("hill", rnd.uniform(0, WIDTH), HZ - 2, rnd.uniform(30, 60), rnd.uniform(5, 10), 34, sand, 200 + i, depth=16, jag=0.08)


# --- Green Highlands: hazy mountains, rolling hills with the first green, scrub trees

HIGH_HAZE = "e8d6cc"


def turbine(x, base, h, blade, y, mat, rnd, broken=None, outline=False):
    C.zcyl("mast", 1.2 * blade / 14, base, base + h, x, y, mat, r2=0.7 * blade / 14, seg=10, outline=outline)
    hub = (x, base + h)
    a0 = rnd.uniform(0, 2 * math.pi)
    for k in range(3):
        a = a0 + k * 2 * math.pi / 3
        L = blade * (0.45 if broken == k else 1.0)
        pts = [(0, -blade * 0.05), (L, -blade * 0.02), (L, blade * 0.015), (blade * 0.15, blade * 0.07)]
        pts = [(hub[0] + px * math.cos(a) - pz * math.sin(a), hub[1] + px * math.sin(a) + pz * math.cos(a)) for px, pz in pts]
        prism("blade", pts, y - 1.2, y - 0.6, mat, outline=outline)
    C.ycyl("hub", blade * 0.07, 1.6, mat, hub[0], hub[1], y - 1.4, outline=outline, seg=12)


def peak(name, x, z, w, h, y, mat, seed):
    """Faceted mountain: a noisy icosphere pinched to a ridge-line summit."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    off = Vector((seed * 5.3, seed * 2.1, seed * 3.7))
    for v in bm.verts:
        v.co *= 1.0 + noise.noise(v.co * 1.4 + off) * 0.28
        if v.co.z < 0:
            v.co.z *= 0.1
        else:
            k = max(0.0, 1.0 - v.co.z)
            v.co.x, v.co.y = v.co.x * (0.3 + 0.7 * k), v.co.y * (0.3 + 0.7 * k)
    return C.finish(name, bm, mat, (x, y, z), (0, 0, seed * 0.7), (w, w * 0.6, h), outline=False, smooth=False)


def far_highland():
    rnd = random.Random(121)
    back = terrain("8a8aa4", haze=0.36, haze_col="dcd4d8", strata=False)
    for i in range(7):
        cx = 20 + i * 108 + rnd.uniform(-20, 20)
        peak("peak", cx, HZ + 6, rnd.uniform(60, 95), rnd.uniform(70, 130), 44, back, 220 + i)
    band("mist", -40, HZ, WIDTH + 40, HZ + 70, 38, HIGH_HAZE, 0.7, 0.0)
    mid_r = terrain("6e6c80", haze=0.26, haze_col="dcd4d8", strata=False)
    for i in range(7):
        peak("ridge", 50 + i * 104 + rnd.uniform(-25, 25), HZ + 2, rnd.uniform(40, 70), rnd.uniform(40, 75), 34, mid_r, 240 + i)
    tm = toon("a4a6b2", ao=0.0)
    turbine(205, HZ + 30, 40, 13, 33, tm, rnd)
    turbine(240, HZ + 26, 36, 12, 33, tm, rnd, broken=1)
    band("mist2", -40, HZ, WIDTH + 40, HZ + 40, 28, HIGH_HAZE, 0.6, 0.0)
    hills = (terrain("8e8c5c", haze=0.28, haze_col=HIGH_HAZE, strata=False), terrain("74895a", haze=0.28, haze_col=HIGH_HAZE, strata=False))
    tree = toon("62704e", ao=0.0)
    for i in range(8):
        hx, hw, hh = rnd.uniform(0, WIDTH), rnd.uniform(70, 150), rnd.uniform(12, 30)
        rock("hill", hx, HZ - 2, hw, hh, 20, hills[i % 2], 260 + i, depth=20, jag=0.06, outline=False)
        for k in range(rnd.randint(0, 3)):
            tx = hx + rnd.uniform(-hw * 0.5, hw * 0.5)
            tz = HZ - 2 + hh * math.sqrt(max(0.0, 1 - ((tx - hx) / hw) ** 2)) - 1.5
            C.sphere("ftree", 2.2, tree, (tx, 12, tz + 2), scale=(1.2, 1, 1), outline=False, seg=8)


def tree(x, z, y, s, trunk, leaves, rnd, dead=False):
    """Scrubby heat-bitten tree: bent trunk, two or three lumpy canopy blobs."""
    lean = rnd.uniform(-0.25, 0.25)
    prism("trunk", tilt([(x - s * 0.18, z - 2), (x + s * 0.18, z - 2), (x + s * 0.08, z + s * 1.4), (x - s * 0.08, z + s * 1.4)], x, z, lean), y - 0.6, y + 0.6, trunk)
    tx, tz = x - math.sin(lean) * s * 1.4, z + math.cos(lean) * s * 1.4
    if dead:
        for a in (-0.7, 0.5, 1.1):
            C.cylinder("branch", s * 0.06, s * 0.9, trunk, (tx + math.sin(a) * s * 0.4, y, tz + math.cos(a) * s * 0.4), rot=(0, a, 0), outline=False, seg=6)
        return
    for k in range(rnd.randint(2, 3)):
        C.sphere("canopy", s * rnd.uniform(0.55, 0.8), leaves[k % len(leaves)], (tx + rnd.uniform(-s * 0.6, s * 0.6), y - 1 - k, tz + rnd.uniform(0, s * 0.4)), scale=(1.3, 1, 0.75), seg=12)


def mid_highland():
    rnd = random.Random(131)
    dry = terrain("a89a5e", haze=0.1, haze_col=HIGH_HAZE, strata=False)
    green = terrain("7e9452", haze=0.1, haze_col=HIGH_HAZE, strata=False)
    trunk = toon("4e3a28")
    leaves = (toon("5e7a3a"), toon("748e44"))
    grass = toon("6a8a3c", ao=0.0)
    stone = terrain("7a7064", strata=False)
    hills = []
    for i in range(8):
        hx = 45 + i * 90 + rnd.uniform(-25, 25)
        hw, hh, y = rnd.uniform(45, 90), rnd.uniform(20, 38), 26 if i % 2 else 18
        rock("hill", hx, HZ - 2, hw, hh, y, green if i % 3 == 1 else dry, 280 + i, depth=18, jag=0.05)
        hills.append((hx, hw, hh, y))
    for hx, hw, hh, y in hills:
        for k in range(rnd.randint(1, 3)):
            tx = hx + rnd.uniform(-hw * 0.6, hw * 0.6)
            tz = HZ - 2 + hh * math.sqrt(max(0.0, 1 - ((tx - hx) / hw) ** 2)) - 2.0
            if rnd.random() < 0.6:
                tree(tx, tz, y - 18 * 0.4, rnd.uniform(6, 10), trunk, leaves, rnd, dead=rnd.random() < 0.2)
            else:
                scrub(tx, tz, y - 18 * 0.5, rnd.uniform(3, 4.5), grass, 300 + k)
    for i in range(7):
        x = rnd.uniform(0, WIDTH)
        rock("boulder", x, HZ - 2, rnd.uniform(4, 9), rnd.uniform(3, 7), 6, stone, 320 + i)
        scrub(x + rnd.uniform(5, 9), HZ - 1, 5.5, rnd.uniform(2.5, 4), grass, 340 + i)


REGIONS = {
    "coast": (far_coast, mid_coast),
    "glass": (far_glass, mid_glass),
    "city": (far_city, mid_city),
    "highland": (far_highland, mid_highland),
}


# ---------------------------------------------------------------- landmarks 2-5
# Same frame as tower(): x -70..70, ground at z 0, top under z 200. Dormant = rust-dark,
# restored = slate with lights, matching the Climate Tower pair.

def lm_mats(restored):
    if restored:
        return dict(wall=terrain("3a4a52", strata=False), dark=terrain("2c383e", strata=False), trim=toon("6a8a96"),
                    win=toon("ffd890", glow=1.2), glow=toon("66ffe8", glow=1.6))
    return dict(wall=terrain("4a2a1c", strata=False), dark=terrain("361c12", strata=False), trim=toon("8a5a3a"),
                win=toon("24120c", ao=0.0), glow=toon("ff5a40", glow=1.6))


def desal(restored):
    m = lm_mats(restored)
    box("plinth", -68, -2, 68, 5, -8, 26, m["dark"])
    for cx, r, top in ((-47, 18, 62), (-14, 13, 46)):
        C.zcyl("tank", r, 4, top, cx, 8, m["wall"], seg=32)
        dome("tank_dome", r, r * 0.38, m["wall"], cx, top, 8)
        for z in (14, top - 10):
            C.zcyl("tank_band", r + 0.9, z, z + 2.4, cx, 8, m["trim"], seg=32)
        box("ladder", cx + r * 0.45, 5, cx + r * 0.45 + 1.0, top, -10.5, -9.5, m["trim"], outline=False)
    box("plant", 2, 4, 38, 40, -6, 18, m["wall"])
    box("plant_roof", 0, 40, 40, 44, -7, 19, m["trim"])
    for row in range(2):
        for col in range(4):
            box("window", 5 + col * 8, 14 + row * 12, 10 + col * 8, 21 + row * 12, -6.5, -6, m["win"], outline=False)
    box("door", 28, 4, 35, 11, -6.5, -6, m["dark"], outline=False)
    C.zcyl("stack", 3.2, 44, 116, 10, 6, m["wall"], r2=2.6, seg=16)
    C.zcyl("stack_cap", 3.6, 112, 117, 10, 6, m["trim"], seg=16)
    prism("intake", [(44, 4), (60, 4), (57, 144), (47, 144)], -4, 6, m["wall"])
    for k in range(5):
        z = 18 + k * 25
        prism("brace", [(45, z), (59, z + 18), (59, z + 21), (45, z + 3)], -4.6, -4, m["trim"], outline=False)
    box("intake_head", 40, 144, 64, 160, -6, 8, m["wall"])
    box("intake_rim", 38, 158, 66, 162, -7, 9, m["trim"])
    box("intake_mast", 51, 162, 53, 176, 0, 2, m["dark"])
    C.zcyl("intake_pipe", 2.6, 4, 146, 64, 0, m["trim"], seg=12)
    for xa, xb, z in ((-62, 2, 11), (-62, -6, 22), (38, 44, 26)):
        C.xcyl("pipe", 2.0, xa, xb, z, -14 if xb < 10 else 4, m["trim"], seg=12)
    for x in (-47, -14):
        C.zcyl("riser", 1.6, 11, 24, x + 6, -14, m["trim"], seg=10)
    if restored:
        for cx, r, z in ((-47, 18, 40), (-14, 13, 30)):
            C.zcyl("tank_glow", r + 0.4, z, z + 1.6, cx, 7.6, m["glow"], outline=False, seg=32)
        for x, z in ((-47, 70), (-14, 52), (52, 178), (39, 160), (65, 160)):
            C.sphere("lamp", 2.0, toon("b0ffff", glow=2.0), (x, -9, z), outline=False)
        steam = toon("eef2f0", shadow=0.82)
        for k, (dx, dz, r) in enumerate(((0, 124, 5), (-3, 133, 7), (-8, 145, 9), (-15, 159, 11), (-24, 174, 12), (-33, 186, 10))):
            C.sphere("steam", r, steam, (10 + dx, 6 - k * 0.5, dz), scale=(1.15, 1, 0.9), seg=16)
        box("roof_strip", 4, 41, 36, 42.6, -7.6, -7, m["glow"], outline=False)
    else:
        C.sphere("beacon", 2, m["glow"], (52, -1, 178), outline=False)
        box("pipe_break", -27, 8, -22, 14, -17, -11, m["dark"], outline=False)
        streak = toon("2e160c", ao=0.0)
        for x, z0, z1, r in ((-56, 30, 52, 18), (-41, 20, 44, 18), (-18, 26, 40, 13)):
            y = 8 - math.sqrt(r * r - (x - (-47 if r == 18 else -14)) ** 2) - 0.3
            box("streak", x, z0, x + 1.6, z1, y - 0.2, y, streak, outline=False)


def heliostat(x, y, post, face_rot, restored, m, s=1.0, state="ok"):
    """Mirror on a post, turned toward the tower; state 'fallen' or 'cracked' for the dormant ruin."""
    tilt_x = -1.25 if state == "fallen" else -0.5
    if state == "fallen":
        post = 2
    box("helio_post", x - 1.1, -2, x + 1.1, post + 2, y + 0.5, y + 2.5, m["dark"])
    p = pivot((x, y, post + 7 * s), (tilt_x, face_rot, 0))
    face = toon("c4ecff", light=1.3) if restored else toon("5a6072", shadow=0.8)
    w, h = 13 * s, 8 * s
    parts = [box("helio_frame", -w, -h, w, h, -0.7, 0.7, m["trim"]),
             box("helio_face", -w + 1.2, -h + 1.2, w - 1.2, h - 1.2, -1.1, -0.7, face, outline=False),
             box("helio_seam", -0.3, -h + 1.2, 0.3, h - 1.2, -1.2, -1.1, m["trim"], outline=False),
             box("helio_seam", -w + 1.2, -0.3, w - 1.2, 0.3, -1.2, -1.1, m["trim"], outline=False)]
    if state == "cracked":
        parts.append(prism("helio_crack", [(-w * 0.2, h - 1.2), (w * 0.35, h - 1.2), (w * 0.05, 0), (w * 0.3, -h + 1.2), (-w * 0.15, -h + 1.2), (-w * 0.05, 1)], -1.3, -1.2, m["dark"], outline=False))
    bake(p, parts)
    return (x, post + 7 * s)


def mirror(restored):
    m = lm_mats(restored)
    box("base", -22, -2, 22, 20, -10, 12, m["wall"])
    box("base_roof", -24, 20, 24, 23, -11, 13, m["trim"])
    box("base_door", -5, -2, 5, 11, -10.5, -10, m["dark"], outline=False)
    for wx in (-17, 10):
        box("base_win", wx, 9, wx + 7, 14, -10.5, -10, m["win"], outline=False)
    C.cylinder("shaft", 7.5, 124, m["wall"], (0, 0, 84), r2=4.8, seg=24)
    for z in (52, 88, 122):
        C.cylinder("ring", 7.5 - 2.7 * (z - 22) / 124 + 1.3, 2.4, m["trim"], (0, 0, z), seg=24)
    C.cylinder("rec_lip", 16, 3, m["trim"], (0, -1, 146), seg=24)
    rec = toon("fff0b0", glow=2.2) if restored else terrain("3a2418", strata=False)
    C.cylinder("receiver", 13, 26, rec, (0, -1, 160), seg=24)
    rib = toon("ffc850", glow=1.4) if restored else toon("24120c", ao=0.0)
    for k in range(-2, 3):
        box("rec_rib", k * 4.6 - 0.7, 148, k * 4.6 + 0.7, 172, -14.6, -14, rib, outline=False)
    C.cylinder("rec_cap", 10, 6, m["wall"], (0, 0, 176), r2=7, seg=24)
    box("mast", -1, 179, 1, 192, -1, 1, m["dark"])
    rows = ((-55, 14, 12, 0.75, "ok"), (-36, 14, 12, 0.75, "ok"), (36, 14, 12, 0.75, "cracked"), (55, 14, 12, 0.75, "ok"),
            (-50, -16, 4, 1.0, "fallen"), (-24, -16, 4, 1.0, "ok"), (24, -16, 4, 1.0, "cracked"), (50, -16, 4, 1.0, "ok"))
    spots = []
    for x, y, post, sc, state in rows:
        spots.append((heliostat(x, y, post, 0.42 if x < 0 else -0.42, restored, m, sc, "ok" if restored else state), y))
    if restored:
        soft("rec_halo", 0, 160, 38, 34, 6, "ffd870", 0.75)
        for (sx, sz), y in spots:
            dx, dz = -sx, 158 - sz
            n = math.hypot(dx, dz)
            ox, oz = -dz / n * 1.4, dx / n * 1.4
            bm = bmesh.new()
            vs = [bm.verts.new(v) for v in ((sx - ox, y - 3, sz - oz), (sx + ox, y - 3, sz + oz), (ox * 2.5, y - 3, 158 + oz * 2.5), (-ox * 2.5, y - 3, 158 - oz * 2.5))]
            bm.faces.new(vs)
            C.finish("beam", bm, haze_mat("fff2b8", sz, 158, 0.1, 0.5), outline=False, smooth=False)
        for (sx, sz), y in spots[4:]:
            glint(sx - 5, sz + 2, y - 5, 2.8)
        C.sphere("beacon", 2.4, toon("fff8e0", glow=2.0), (0, -1, 194), outline=False)
    else:
        C.sphere("beacon", 2, m["glow"], (0, -1, 194), outline=False)


def archive(restored):
    m = lm_mats(restored)
    rock_m = terrain("4a3a32", haze=0.0) if not restored else terrain("4a4a4c", haze=0.0)
    rock("outcrop", 0, -2, 50, 118, 12, rock_m, 7, depth=34, jag=0.22)
    rock("outcrop_l", -44, -2, 18, 46, -8, rock_m, 8, depth=16, jag=0.2)
    rock("outcrop_r", 45, -2, 17, 62, -6, rock_m, 9, depth=16, jag=0.2)
    conc = terrain("6a5e56", strata=False) if not restored else terrain("7e8c90", strata=False)
    prism("portal", [(-31, -2), (31, -2), (31, 58), (19, 70), (-19, 70), (-31, 58)], -46, -18, conc)
    box("lintel", -24, 58, 24, 62, -46.5, -46, m["trim"], outline=False)
    box("sign", -12, 62.5, 12, 67, -46.5, -46, m["dark"], outline=False)
    leaf = toon("7affaa", glow=1.4) if restored else toon("8a5a3a", ao=0.0)
    prism("emblem", [(0, 62.9), (2.6, 64.8), (0, 66.6), (-2.6, 64.8)], -46.9, -46.5, leaf, outline=False)
    for vx, vz, vh in ((-20, 96, 16), (-12, 104, 11)):
        C.zcyl("vent", 2.2, vz, vz + vh, vx, 4, m["trim"], seg=12)
        C.zcyl("vent_cap", 3.2, vz + vh, vz + vh + 2, vx, 4, m["dark"], seg=12)
    box("antenna", 17, 104, 18.4, 132, 6, 7.4, m["dark"])
    door_m = terrain("4e4038", strata=False) if not restored else terrain("56666c", strata=False)
    C.torus("door_rim", 23, 2.2, m["trim"], (0, -47, 28), rot=(math.pi / 2, 0, 0), outline=True)
    if restored:
        C.ycyl("opening", 21, 1, toon("0c1a12", ao=0.0), 0, 28, -46.6, outline=False, seg=40)
        C.ycyl("inner_glow", 15, 1, toon("6aff9a", glow=1.3), 0, 26, -47.0, outline=False, seg=40)
        soft("door_halo", 0, 28, 44, 40, -46.8, "7affaa", 0.55)
        soft("spill", 0, 1, 40, 6, -48.5, "7affaa", 0.6)
        d = C.ycyl("door", 21, 4, door_m, 0, 0, 0, seg=40)
        d.rotation_euler = (math.pi / 2, 0, 1.15)
        d.location = (23 + 21 * math.cos(1.15), -48 - 21 * math.sin(1.15), 28)
        rnd = random.Random(3)
        leaf = (toon("4f9a3a"), toon("6cbc4a"))
        for k, x in enumerate((-26, -20, -12, 13, 20, 27)):
            C.sphere("bush", rnd.uniform(2.6, 4.2), leaf[k % 2], (x, -50, 1.5), scale=(1.3, 1, 1), seg=12)
        twig = toon("4a8a34", ao=0.0)
        for k, x in enumerate((-35, -29, 33, 38, -8, 9)):
            scrub(x, 0, -51, 3.2, twig, 30 + k)
        for x, z in ((-12, 74), (14, 77), (-40, 46), (46, 60)):
            scrub(x, z, -30 if abs(x) < 20 else -18, 3.0, twig, 40 + x)
        C.sphere("lamp", 2.2, toon("b0ffc8", glow=2.0), (0, -47, 70), outline=False)
    else:
        C.ycyl("door", 21, 4, door_m, 0, 28, -48, seg=40)
        for k in range(12):
            a = k * math.pi / 6
            C.sphere("bolt", 1.2, m["trim"], (math.cos(a) * 17.5, -50.2, 28 + math.sin(a) * 17.5), outline=False, seg=8)
        C.torus("wheel", 6, 1.0, m["trim"], (0, -50.6, 28), rot=(math.pi / 2, 0, 0), outline=True)
        for a in (0, math.pi / 3, 2 * math.pi / 3):
            b = box("spoke", -6, -0.6, 6, 0.6, -51, -50.4, m["trim"], outline=False)
            b.location = (0, -50.7, 28)
            b.rotation_euler = (0, a, 0)
        box("streak", -14, 4, -11, 14, -50.4, -50.2, toon("6a3a22", ao=0.0), outline=False)
        C.sphere("lamp", 2.0, m["glow"], (0, -47, 70), outline=False)
        ash = terrain("5a4a44", strata=False)
        rock("drift", -24, -2, 16, 5, -52, ash, 11, depth=6, jag=0.1)
        rock("drift", 26, -2, 13, 4, -52, ash, 12, depth=6, jag=0.1)


def haven(restored):
    m = lm_mats(restored)
    rnd = random.Random(5)
    hill_m = terrain("4e6234", strata=False) if restored else terrain("6a5238", strata=False)
    W, H, D = 66, 54, 30
    rock("hill", 0, -2, W, H, 6, hill_m, 21, depth=D, flat=0.1, jag=0.05)

    def ground(x, y):
        return -2 + H * math.sqrt(max(0.0, 1 - (x / W) ** 2 - ((y - 6) / D) ** 2)) - 4

    wall = terrain("b89a76", strata=False) if restored else terrain("7e6650", strata=False)
    roof = toon("a0402a") if restored else toon("6e3626")
    for hx, hw, hh, y in ((-40, 20, 15, -8), (-15, 28, 20, -2), (15, 22, 16, -12), (39, 17, 13, -4)):
        z = ground(hx, y) - 1
        box("house", hx - hw / 2, z, hx + hw / 2, z + hh, y - 7, y + 7, wall)
        prism("roof", [(hx - hw / 2 - 2.5, z + hh), (hx + hw / 2 + 2.5, z + hh), (hx, z + hh + hw * 0.45)], y - 8, y + 8, roof)
        box("hdoor", hx - 2.5, z, hx + 2.5, z + 8, y - 7.4, y - 7, m["dark"], outline=False)
        for wx in (hx - hw / 2 + 2.5, hx + hw / 2 - 7):
            box("hwin", wx, z + hh * 0.42, wx + 4.5, z + hh * 0.42 + 4.5, y - 7.4, y - 7, m["win"], outline=False)
    tz = ground(46, 6)
    blade_m = toon("d8dcd6") if restored else m["wall"]
    C.zcyl("tower", 3.4, tz, 158, 46, 8, m["wall"], r2=2.0, seg=12)
    box("nacelle", 41, 155, 56, 163, 4, 10, m["wall"])
    hub = (46, 159)
    for k in range(3):
        a = math.radians(70 + k * 120)
        L = 30 * (0.42 if (not restored and k == 2) else 1.0)
        pts = [(0, -2.4), (L, -0.8), (L, 0.8), (6, 3.4)]
        pts = [(hub[0] + px * math.cos(a) - pz * math.sin(a), hub[1] + px * math.sin(a) + pz * math.cos(a)) for px, pz in pts]
        prism("blade", pts, 2, 3, blade_m)
    C.ycyl("hub", 2.2, 3, m["trim"], hub[0], hub[1], 1.6, seg=12)
    trunk = toon("4a3424") if restored else toon("3a2418")
    leaves = (toon("5e8a3a"), toon("78a44a"))
    for tx, y, s in ((-50, 4, 10), (-28, 10, 13), (25, 6, 10)):
        tree(tx, ground(tx, y) + 1, y, s, trunk, leaves, rnd, dead=not restored)
    pz = ground(-2, 4)
    box("flagpole", -3, pz, -1.8, pz + 46, 3, 4.2, m["dark"], outline=True)
    if restored:
        cloth = toon("2f9a90")
        prism("banner", [(-1.8, pz + 44), (20, pz + 42), (17, pz + 37), (21, pz + 32), (-1.8, pz + 33)], 3.2, 3.8, cloth)
        prism("banner_stripe", [(-1.8, pz + 39.5), (19, pz + 38), (19, pz + 36), (-1.8, pz + 37.5)], 2.9, 3.2, toon("f0b84a", ao=0.0), outline=False)
        grass = toon("6a9a3c", ao=0.0)
        for k in range(14):
            gx = rnd.uniform(-58, 58)
            scrub(gx, ground(gx, -14) + 3, -16, rnd.uniform(2.5, 3.5), grass, 60 + k)
        C.sphere("lamp", 1.6, m["glow"], (48, 3, 163), outline=False)
        for k, gx in enumerate((-28, -20, -12)):
            box("garden", gx - 3, ground(gx, -22) - 1, gx + 3, ground(gx, -22) + 2.5, -25, -21, leaves[k % 2], bevel=0.8)
    else:
        prism("rag", [(-1.8, pz + 44), (6, pz + 42), (4, pz + 39), (-1.8, pz + 40)], 3.2, 3.8, toon("5a4a3a"))


LANDMARKS = {"desal": desal, "mirror": mirror, "archive": archive, "haven": haven}


def job(name):
    return not ONLY or name in ONLY or any(name.endswith("_" + o) for o in ONLY)


if __name__ == "__main__":
    C.OUTLINE = 0.6
    sc, cam = C.setup_scene(samples=24)
    layers = {
        # name: (builder, x0, x1, z0, z1, px per unit, tiles)
        "sky": (sky, -300, 900, -60, 900, 1.0, False),
        "far": (far, 0, WIDTH, HZ - 2, HZ + 240, 2.0, True),
        "mid": (mid, 0, WIDTH, HZ - 4, HZ + 100, 2.0, True),
        "near": (near, 0, WIDTH, -2, HZ + 2, 3.0, True),
        "track": (track, 0, WIDTH, -12, 6, 4.0, True),
        "front": (front, 0, WIDTH, -300, -8, 1.5, True),
        "tower": (lambda: tower(False), -70, 70, -2, 200, 2.0, False),
        "tower_restored": (lambda: tower(True), -70, 70, -2, 200, 2.0, False),
    }
    for r, (far_b, mid_b) in REGIONS.items():
        layers["sky_" + r] = ((lambda r=r: region_sky(r)),) + layers["sky"][1:]
        layers["far_" + r] = (far_b,) + layers["far"][1:]
        layers["mid_" + r] = (mid_b,) + layers["mid"][1:]
    for lm, b in LANDMARKS.items():
        layers[lm] = ((lambda b=b: b(False)),) + layers["tower"][1:]
        layers[lm + "_restored"] = ((lambda b=b: b(True)),) + layers["tower"][1:]
    for name, (build, x0, x1, z0, z1, px, tiles) in layers.items():
        if not job(name):
            continue
        C.clear_objects()
        build()
        if tiles:
            wrap_duplicates()
        C.render_region(sc, cam, x0, x1, z0, z1, px, os.path.join(OUT, "scenery_%s.png" % name))
        print("RENDERED", name)
    print("DONE")

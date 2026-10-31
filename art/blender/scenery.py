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


def job(name):
    return not ONLY or name in ONLY


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

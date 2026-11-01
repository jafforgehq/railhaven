"""Shared Blender helpers for Railhaven art: toon materials, outlined primitives,
orthographic side-view rendering. Scene units are Railhaven world units
(Blender X = world x, Blender Z = -world y, camera looks along +Y)."""
import bpy
import bmesh
import math
import os
from mathutils import Vector

LIGHT_DIR = Vector((-0.5, -0.45, 0.75)).normalized()
OUTLINE = 0.9          # inverted-hull thickness in scene units (set per script)
_mats = {}


def lin(hexstr):
    c = [int(hexstr[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def shade(hexstr, f):
    c = [int(hexstr[i:i + 2], 16) for i in (0, 2, 4)]
    if f < 1.0:
        c = [c[0] * f + 18 * (1 - f), c[1] * f, c[2] * f + 22 * (1 - f)]
    else:
        c = [x + (255 - x) * (f - 1.0) for x in c]
    return "".join("%02x" % max(0, min(255, int(x))) for x in c)


def _new_mat(name):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    for n in list(m.node_tree.nodes):
        m.node_tree.nodes.remove(n)
    return m


def toon(hexstr, shadow=0.66, light=1.12, glow=0.0, ao=0.55):
    """Cel-shaded emission material: 3 constant bands from a fixed light direction,
    darkened in creases by ambient occlusion. glow > 0 makes a flat emissive colour."""
    key = (hexstr, shadow, light, glow, ao)
    if key in _mats:
        return _mats[key]
    m = _new_mat("toon_%s_%d" % (hexstr, len(_mats)))
    nt = m.node_tree
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    if glow > 0.0:
        emit.inputs["Color"].default_value = lin(hexstr)
        emit.inputs["Strength"].default_value = glow
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
        els[1].position = 0.40
        els[1].color = lin(hexstr)
        e = els.new(0.80)
        e.color = lin(shade(hexstr, light))
        nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
        if ao > 0.0:
            aon = nt.nodes.new("ShaderNodeAmbientOcclusion")
            aon.inputs["Distance"].default_value = 6.0
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = ao
            nt.links.new(ramp.outputs["Color"], mix.inputs["A"])
            nt.links.new(aon.outputs["AO"], mix.inputs["B"])
            nt.links.new(mix.outputs["Result"], emit.inputs["Color"])
        else:
            nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
    _mats[key] = m
    return m


def outline_mat():
    if "outline" in _mats:
        return _mats["outline"]
    m = _new_mat("outline")
    out = m.node_tree.nodes.new("ShaderNodeOutputMaterial")
    emit = m.node_tree.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = lin("140c0a")
    m.node_tree.links.new(emit.outputs[0], out.inputs["Surface"])
    m.use_backface_culling = True
    _mats["outline"] = m
    return m


def finish(name, bm, mat, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), outline=True, parent=None, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    if outline:
        ob.data.materials.append(outline_mat())
        mod = ob.modifiers.new("outline", "SOLIDIFY")
        mod.thickness = OUTLINE / max(0.05, min(scale))
        mod.offset = 1.0
        mod.use_flip_normals = True
        mod.material_offset = 1
    ob.scale = scale
    ob.rotation_euler = rot
    ob.location = loc
    if parent:
        ob.parent = parent
    return ob


def box(name, x0, z0, x1, z1, y0, y1, mat, bevel=0.0, outline=True):
    """Axis-aligned box from world-style extents (x right, z up, y depth)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.verts) + list(bm.edges), offset=min(bevel, min(sx, sy, sz) * 0.45),
                        offset_type="OFFSET", segments=3, profile=0.5, affect="EDGES", clamp_overlap=True)
    return finish(name, bm, mat, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), outline=outline, smooth=bevel > 0)


def sphere(name, r, mat, loc, scale=(1, 1, 1), rot=(0, 0, 0), outline=True, seg=20):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(6, seg // 2), radius=r)
    return finish(name, bm, mat, loc, rot, scale, outline)


def cylinder(name, r, depth, mat, loc, rot=(0, 0, 0), outline=True, r2=None, seg=24):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    return finish(name, bm, mat, loc, rot, (1, 1, 1), outline)


def ycyl(name, r, depth, mat, x, z, y, outline=True, r2=None, seg=24):
    """Cylinder whose axis points at the camera (wheels, dials, portholes)."""
    return cylinder(name, r, depth, mat, (x, y, z), (math.pi / 2, 0, 0), outline, r2, seg)


def xcyl(name, r, x0, x1, z, y, mat, outline=True, seg=20):
    """Horizontal pipe along X."""
    return cylinder(name, r, abs(x1 - x0), mat, ((x0 + x1) / 2, y, z), (0, math.pi / 2, 0), outline, seg=seg)


def zcyl(name, r, z0, z1, x, y, mat, outline=True, r2=None, seg=20):
    return cylinder(name, r, abs(z1 - z0), mat, (x, y, (z0 + z1) / 2), (0, 0, 0), outline, r2, seg)


def torus(name, major, minor, mat, loc, rot=(0, 0, 0), scale=(1, 1, 1), outline=False, seg_u=32, seg_v=10):
    bm = bmesh.new()
    rings = []
    for i in range(seg_u):
        a = 2 * math.pi * i / seg_u
        ring = []
        for j in range(seg_v):
            b = 2 * math.pi * j / seg_v
            ring.append(bm.verts.new(((major + minor * math.cos(b)) * math.cos(a), (major + minor * math.cos(b)) * math.sin(a), minor * math.sin(b))))
        rings.append(ring)
    for i in range(seg_u):
        r0, r1 = rings[i], rings[(i + 1) % seg_u]
        for j in range(seg_v):
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % seg_v], r0[(j + 1) % seg_v]))
    return finish(name, bm, mat, loc, rot, scale, outline)


def prism(name, pts, y0, y1, mat, outline=True):
    """Extrude a 2D outline (list of (x, z)) along Y: cowcatchers, mesas, ruins."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y0, z)) for x, z in pts]
    back = [bm.verts.new((x, y1, z)) for x, z in pts]
    n = len(pts)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, mat, outline=outline, smooth=False)


def lathe(name, prof, mat, loc=(0, 0, 0), rot=(0, 0, 0), outline=True, seg=64, smooth=True):
    """Spin a (radius, z) profile around the local Z axis: domed caps, rings, bottles."""
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0.0, z)) for r, z in prof]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(0, 0, 0), axis=(0, 0, 1), angle=2 * math.pi, steps=seg, use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, mat, loc, rot, (1, 1, 1), outline, smooth=smooth)


# ---------------------------------------------------------------- flat 2D shapes (emblems, glyphs)

def ccw(pts):
    a = sum(x0 * z1 - x1 * z0 for (x0, z0), (x1, z1) in zip(pts, pts[1:] + pts[:1]))
    return list(pts) if a > 0 else list(reversed(pts))


def offset_poly(pts, d, limit=2.2):
    """Grow a simple (x, z) polygon outward by d. Convex corners are mitred, or bevelled
    where the miter would spike past limit * d."""
    P = [Vector(p) for p in ccw(pts)]
    n = len(P)
    out = []
    for i in range(n):
        a, p, b = P[i - 1], P[i], P[(i + 1) % n]
        e1, e2 = (p - a).normalized(), (b - p).normalized()
        n1, n2 = Vector((e1.y, -e1.x)), Vector((e2.y, -e2.x))
        m = n1 + n2
        convex = e1.x * e2.y - e1.y * e2.x > 0
        if m.length < 1e-6:
            out.append(tuple(p + n1 * d))
            continue
        m.normalize()
        k = 1.0 / max(1e-3, m.dot(n1))
        if convex and k > limit:
            out += [tuple(p + n1 * d), tuple(p + n2 * d)]
        else:
            out.append(tuple(p + m * d * min(k, 6.0)))
    return out


def stroke_poly(path, w, seg=8):
    """Outline polygon of a round-capped polyline of width w."""
    P = [Vector(p) for p in path]
    h, n = w / 2.0, len(P)

    def normal(i):
        d1 = (P[max(i, 1)] - P[max(i, 1) - 1]).normalized()
        d2 = (P[min(i + 1, n - 1)] - P[min(i + 1, n - 1) - 1]).normalized()
        n1, n2 = Vector((-d1.y, d1.x)), Vector((-d2.y, d2.x))
        m = (n1 + n2).normalized()
        return m / max(0.35, m.dot(n1))

    def cap(p, nv):
        a0 = math.atan2(nv.y, nv.x)
        return [tuple(p + Vector((math.cos(a0 - math.pi * k / seg), math.sin(a0 - math.pi * k / seg))) * h) for k in range(1, seg)]

    left = [tuple(P[i] + normal(i) * h) for i in range(n)]
    right = [tuple(P[i] - normal(i) * h) for i in range(n)]
    return left + cap(P[-1], normal(n - 1)) + right[::-1] + cap(P[0], -normal(0))


def fillet(pts, r, k=5):
    """Round every corner of a polygon with radius r."""
    P = [Vector(p) for p in pts]
    out = []
    for i in range(len(P)):
        a, p, b = P[i - 1], P[i], P[(i + 1) % len(P)]
        u, v = (a - p).normalized(), (b - p).normalized()
        half = math.acos(max(-1.0, min(1.0, u.dot(v)))) / 2
        t = min(r / math.tan(half), (a - p).length * 0.45, (b - p).length * 0.45)
        rr = t * math.tan(half)
        c = p + (u + v).normalized() * (rr / math.sin(half))
        s, e = p + u * t, p + v * t
        a0, a1 = math.atan2(s.y - c.y, s.x - c.x), math.atan2(e.y - c.y, e.x - c.x)
        da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
        out += [(c.x + rr * math.cos(a0 + da * j / k), c.y + rr * math.sin(a0 + da * j / k)) for j in range(k + 1)]
    return out


def spline(pts, n=6, sharp=()):
    """Closed Catmull-Rom curve through pts; indices in sharp stay pointed corners."""
    P = [Vector(p) for p in pts]
    L = len(P)
    T = [Vector((0, 0)) if i in sharp else (P[(i + 1) % L] - P[i - 1]) * 0.5 for i in range(L)]
    out = []
    for i in range(L):
        p0, p1, m0, m1 = P[i], P[(i + 1) % L], T[i], T[(i + 1) % L]
        for j in range(n):
            t = j / n
            h00, h10, h01, h11 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t, -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
            q = p0 * h00 + m0 * h10 + p1 * h01 + m1 * h11
            out.append((q.x, q.y))
    return out


def slab(name, pts, y0, y1, mat, chamfer=0.0, outline=False):
    """Prism of an (x, z) outline from y0 (camera side) back to y1. chamfer > 0 raises a
    bevelled front face so the 3-band toon light picks out its edges (an embossed look)."""
    bm = bmesh.new()
    pts = ccw(pts)
    front = [bm.verts.new((x, y0, z)) for x, z in pts]
    back = [bm.verts.new((x, y1, z)) for x, z in pts]
    f = bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if chamfer > 0:
        bmesh.ops.inset_region(bm, faces=[f], thickness=chamfer, depth=chamfer, use_even_offset=True)
    return finish(name, bm, mat, outline=outline, smooth=False)


def ring_slab(name, cx, cz, r0, r1, y0, y1, mat, chamfer=0.0, outline=False, seg=48):
    """Flat washer facing the camera (annulus r0..r1), optionally with chamfered front edges."""
    c = min(chamfer, (r1 - r0) * 0.3)
    if c > 0:
        prof = [(r0, -y1), (r0, -y0 - c), (r0 + c, -y0), (r1 - c, -y0), (r1, -y0 - c), (r1, -y1), (r0, -y1)]
    else:
        prof = [(r0, -y1), (r0, -y0), (r1, -y0), (r1, -y1), (r0, -y1)]
    return lathe(name, prof, mat, (cx, 0, cz), (math.pi / 2, 0, 0), outline, seg, smooth=False)


def text(name, body, size, mat, loc, rot=(math.pi / 2, 0, 0)):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = 0.2
    cu.align_x = "CENTER"
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def setup_scene(samples=16):
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
        sc.eevee.taa_render_samples = samples
    except Exception:
        pass
    world = bpy.data.worlds.new("w")
    sc.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.clip_start = 0.1
    cam.data.clip_end = 5000
    cam.rotation_euler = (math.pi / 2, 0, 0)
    sc.camera = cam
    return sc, cam


def render_region(sc, cam, x0, x1, z0, z1, px_per_unit, path):
    """Render the world rectangle [x0,x1] x [z0,z1] at a fixed pixel density."""
    w = int(round((x1 - x0) * px_per_unit))
    h = int(round((z1 - z0) * px_per_unit))
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    cam.data.ortho_scale = max(x1 - x0, z1 - z0)
    cam.location = ((x0 + x1) / 2, -1000.0, (z0 + z1) / 2)
    sc.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)


def clear_objects():
    for ob in list(bpy.data.objects):
        if ob.type != "CAMERA":
            bpy.data.objects.remove(ob, do_unlink=True)

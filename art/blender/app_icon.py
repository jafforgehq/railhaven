"""Railhaven app icon (1024x1024, opaque, square corners as App Store requires).

  Blender -b --factory-startup --python art/blender/app_icon.py -- <out.png>
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
import carriages as K  # noqa: E402
import scenery as S  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/app_icon.png"


def placed(build, dx, dz):
    before = set(bpy.data.objects)
    build()
    for ob in set(bpy.data.objects) - before:
        if ob.parent is None:
            ob.location.x += dx
            ob.location.z += dz


if __name__ == "__main__":
    C.OUTLINE = 0.9
    sc, cam = C.setup_scene(samples=32)
    sc.render.film_transparent = False
    S.plane("sky", -200, -60, 400, 300, 60, S.gradient([(0.0, "ffc46c"), (0.35, "f39a45"), (0.7, "c0502a"), (1.0, "4a1c10")], 20, 250))
    S.disc("halo", 150, 150, 120, 58, S.glow_mat("ffb060", 0.5))
    S.disc("sun", 150, 150, 46, 57, C.toon("ffd890", glow=1.0))
    S.plane("ground", -200, -60, 400, 0, 20, S.gradient([(0.0, "5a2512"), (1.0, "a9532a")], -60, 0))
    C.box("rail", -200, -1, 400, 1.6, -30, -28, C.toon("e2e5ea", ao=0.0), outline=False)
    K.locomotive()
    placed(lambda: K.wheel(7.0, False), 30, 7)
    for wx in (60.0, 90.0, 120.0):
        placed(lambda: K.wheel(13.0, True), wx, 13)
    placed(lambda: K.wheel(8.0, False), 176, 8)
    placed(K.rod, 60, 13)
    C.render_region(sc, cam, -34, 214, -14, 234, 1024 / 248.0, OUT)
    print("DONE", OUT)

"""Pack Blender-rendered frames into Godot sprite sheets.

  python3 art/build_sprites.py <frames_dir> <out_dir>

Each crew preset becomes <preset>.png (rows = animations, 8 columns),
<preset>_sleep.png (4 frames in a row) and <preset>_portrait.png.
"""
import json
import os
import sys
from PIL import Image

ANIMS = ["idle", "walk", "carry", "hammer", "tend", "panel", "wrench", "sit"]
COLS = 8

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
meta = {"anims": ANIMS, "cols": COLS, "presets": []}
for preset in sorted(os.listdir(src)):
    d = os.path.join(src, preset)
    if not os.path.isdir(d):
        continue
    first = Image.open(os.path.join(d, "idle_00.png"))
    fw, fh = first.size
    sheet = Image.new("RGBA", (fw * COLS, fh * len(ANIMS)), (0, 0, 0, 0))
    counts = {}
    for row, anim in enumerate(ANIMS):
        n = 0
        while os.path.exists(os.path.join(d, "%s_%02d.png" % (anim, n))):
            sheet.paste(Image.open(os.path.join(d, "%s_%02d.png" % (anim, n))), (n * fw, row * fh))
            n += 1
        assert n > 0, (preset, anim)
        counts[anim] = n
    sheet.save(os.path.join(dst, preset + ".png"), optimize=True)
    sl = [Image.open(os.path.join(d, "sleep_%02d.png" % i)) for i in range(4)]
    sw, sh = sl[0].size
    sleep = Image.new("RGBA", (sw * 4, sh), (0, 0, 0, 0))
    for i, im in enumerate(sl):
        sleep.paste(im, (i * sw, 0))
    sleep.save(os.path.join(dst, preset + "_sleep.png"), optimize=True)
    Image.open(os.path.join(d, "portrait.png")).save(os.path.join(dst, preset + "_portrait.png"), optimize=True)
    meta["presets"].append(preset)
    meta["frame"] = [fw, fh]
    meta["sleep_frame"] = [sw, sh]
    meta["counts"] = counts
with open(os.path.join(dst, "crew.json"), "w") as f:
    json.dump(meta, f, indent=1)
print("packed", len(meta["presets"]), "presets ->", dst)

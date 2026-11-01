#!/bin/sh
# Rebuild every Blender-made asset for Railhaven and copy it into assets/sprites/.
# Usage: art/build_all.sh [path-to-Blender]   (Godot reimports the PNGs on next launch)
set -e
cd "$(dirname "$0")/.."
BLENDER="${1:-/Applications/Blender.app/Contents/MacOS/Blender}"
TMP="$(mktemp -d)"
run() { "$BLENDER" -b --factory-startup --python "art/blender/$1" -- "$TMP/$2" >/dev/null; }
run crew.py crew
python3 art/build_sprites.py "$TMP/crew" assets/sprites/crew
run carriages.py train && mkdir -p assets/sprites/train && cp "$TMP"/train/*.png assets/sprites/train/
run scenery.py scenery && mkdir -p assets/sprites/scenery && cp "$TMP"/scenery/*.png assets/sprites/scenery/
run icons.py icons && mkdir -p assets/sprites/icons && cp "$TMP"/icons/*.png assets/sprites/icons/
run puzzle.py puzzle && mkdir -p assets/sprites/puzzle && cp "$TMP"/puzzle/*.png assets/sprites/puzzle/
run puzzle2.py puzzle2 && cp "$TMP"/puzzle2/puzzle/*.png assets/sprites/puzzle/ && cp "$TMP"/puzzle2/icons/*.png assets/sprites/icons/
run pet.py pet && cp -R "$TMP"/pet/. assets/sprites/  # pet/fox_*.png + pet.json, train/livery_trim.png
run rescue.py rescue && mkdir -p assets/sprites/rescue && cp "$TMP"/rescue/*.png assets/sprites/rescue/
rm -rf "$TMP"
echo "art rebuilt"

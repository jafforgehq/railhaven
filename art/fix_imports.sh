#!/bin/sh
# Import new Blender PNGs into Godot with the project's texture settings:
# world sprites VRAM compressed (BPTC/ASTC) high quality, icons lossless; all with mipmaps.
# Usage: art/fix_imports.sh   (run after copying renders into assets/sprites/)
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
changed=0
for f in assets/sprites/*/*.png.import; do
	# Icons and portraits stay lossless (UI art); world sprites use VRAM compression.
	case "$f" in
		assets/sprites/icons/*|assets/sprites/puzzle/*|*_portrait.png.import) mode=0; hq=false ;;
		*) mode=2; hq=true ;;
	esac
	if ! grep -q "^compress/mode=$mode" "$f" || ! grep -q "^compress/high_quality=$hq" "$f" || ! grep -q "^mipmaps/generate=true" "$f"; then
		sed -i '' -e "s/^compress\/mode=.*/compress\/mode=$mode/" -e "s/^compress\/high_quality=.*/compress\/high_quality=$hq/" -e 's/^mipmaps\/generate=.*/mipmaps\/generate=true/' "$f"
		changed=$((changed + 1))
	fi
done
if [ "$changed" -gt 0 ]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi
echo "imports ok ($changed fixed)"

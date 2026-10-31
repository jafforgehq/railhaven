# Railhaven: Scorched Line — first playable

Portrait mobile idle colony game (Godot 4.7, GDScript, Mobile renderer with 4x MSAA 2D, falls back to OpenGL).
Outside it is 65 °C (78 °C in a heatwave); the colony lives aboard an armored train that never stops.
All art is made in **Blender** from Python scripts in `art/blender/`: toon-shaded, outlined models rendered
orthographically to sprites (crew animations and portraits, every carriage type at levels 1–5, the locomotive,
wheels and rods, drones, scenery strips, the Climate Tower, item icons). Godot only adds in-engine effects on top:
lamp light cones, glows, sparks, bubbles, smoke, dust and weather tints.

## Art pipeline (Blender only)

```bash
art/build_all.sh                       # rebuild every asset (≈3 min), output goes to assets/sprites/
```

| Script | Output |
|---|---|
| `art/blender/crew.py` + `art/build_sprites.py` | 10 crew presets × 8 animations (sheet), sleep pose, portrait |
| `art/blender/carriages.py` | `carriage_<type>_<level>.png`, `locomotive.png`, wheels, rod, fan rotor, drones |
| `art/blender/scenery.py` | sky, far/mid/near/track/front parallax strips (tile at 720 units), tower (dormant/restored) |
| `art/blender/icons.py` | resource / item icons (UI glyphs such as ✓ + × stay vector) |
| `art/blender/common.py` | shared toon material (3 light bands + AO), inverted-hull outlines, primitives, ortho render |

Sprite sheets import as VRAM-compressed (ASTC on mobile) with mipmaps.

## Run

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .          # play (450x800 window, 720x1280 design)
/Applications/Godot.app/Contents/MacOS/Godot --path . -e       # editor
```

Controls: drag horizontally to pan along the train (mouse wheel works on desktop), tap a carriage to manage it,
tap the dashed slot at the end of the train to add a carriage, bottom tabs switch Train / Crew / Journey.
Tap the goal card to jump to wherever the current goal is solved.

## Core loop

Drones salvage scrap automatically → the workshop turns scrap into parts (2:1) → build / upgrade carriages →
more beds, food and water → survivors arrive → more workers → more production → restore the Climate Tower.

| Carriage | Effect |
|---|---|
| Locomotive | Cargo hold (storage multiplier) and journey speed |
| Living Quarters | Beds (survivor capacity); resting crew sleep and eat here |
| Greenhouse | Food per worker |
| Water Recycler | Water per worker |
| Workshop | Converts scrap into parts per worker |
| Cooling Module | Raises how many carriages the train can support (+1 when staffed) |
| Drone Bay | Drones repeat salvage runs automatically; pilots add +25% yield each |

- Each survivor eats and drinks 0.6/min. Matching specialists (Engineer → Workshop, Grower → Greenhouse, …) work at 125%.
- **Automatic safe mode**: if food or water runs out, the crew rations (half upkeep, production −30%, growth paused). Nobody dies, online or offline.
- **Offline**: on launch / resume the sim fast-forwards up to 8 h in 5 s steps with the same rules (storage caps, upkeep, safe mode, drones, journey) and shows a "While you were away" report.
- **Events** (after the tutorial goals): Heatwave, Sandstorm, Distress Signal — each a two-option priority choice; no answer within 25 s picks the safe option.
- **Chapter 1**: 11 sequential goals ending with *Restore the Climate Tower*: once the train is within 120 km drone range, three drone expeditions consume parts and water. Completion unlocks the Ash Coast region (55 °C, +25% water, +1 cooling) and a cooler palette.

## Layout

```
scripts/data.gd                 balance + static definitions (class Data)
scripts/autoloads/game.gd       state owner: sim, actions, events, goals, JSON save, offline catch-up
scripts/autoloads/audio.gd      Music/SFX/Ambience buses, SFX pool, settings (ConfigFile)
scripts/main.gd                 root: half-res world SubViewport, HUD, bottom sheets, modals
scripts/world/                  parallax scenery, carriage + locomotive cutaways, drones, weather
scripts/world/crew_sprites.gd   draws Blender crew frames (lazy-loaded sheets)
scripts/ui/                     theme/kit, icons, HUD, portraits, popups, panels/
tests/test_sim.gd               headless economy checks
tests/bot_playthrough.gd        greedy bot plays chapter 1 headless (pacing check)
scripts/debug/shots.gd          dev-only screenshot tour (`-- --shots=<dir>`), soak (`-- --soak`)
```

Patterns (chosen / rejected):
- State + signals on one `Game` autoload, **not** a separate EventBus — one owner emits everything, fewer hops.
- JSON save in `user://` with a version field and atomic temp-file rename, **not** Resource `.tres` saves (user-writable files must not run code).
- Audio settings in `ConfigFile`, **not** inside the game save.
- `Parallax2D` layers with `autoscroll`, **not** the deprecated `ParallaxBackground/ParallaxLayer`.
- World lives in the main viewport (camera zoom 1.7–2.5, auto-fit between HUD and sheet) with UI in a CanvasLayer, **not** a low-res SubViewport: art stays sharp at any phone resolution.
- `canvas_items` stretch + `keep_width` aspect so tall phones get more world, not letterboxing.
- Panels build controls once and refresh values in place, **not** rebuild every tick (buttons would be recreated under the finger).

## Test

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path . -s tests/test_sim.gd          # economy self-check, prints PASS/FAILED
$G --headless --path . -s tests/bot_playthrough.gd   # pacing: minutes per goal
$G --path . -- --shots=/tmp/railhaven_shots              # screenshot every screen + simulated tap/drag checks
$G --path . -- --shots=/tmp/railhaven_shots --gallery    # every carriage type at Lv 1/3/5
$G --path . -- --shots=/tmp/railhaven_shots --chars      # every crew preset + portraits
```

The screenshot tour plays on the real save slot with autosave off. It never writes the save, except through `reset_game()`.

## Export (Android)

`export_presets.cfg` has an "Android" preset (arm64 + armv7, debug keystore from editor settings):

```bash
$G --headless --path . --export-debug "Android" export/Railhaven.apk
```

Release builds need a release keystore set in the preset (see Godot docs). The iOS preset is not set up yet: it needs a Team ID.

## Credits

Audio: see `assets/audio/CREDITS.md`. Every file is CC0 except two that need attribution:
- "Smooth Guitar Fanfare" by OwlishMedia (CC BY 4.0)
- "Wind Loop" by AntumDeluge, from a recording by InspectorJ (CC BY 3.0)

These two are also credited in the in-game Settings screen. Font: Barlow Condensed (SIL OFL, `assets/fonts/OFL.txt`).

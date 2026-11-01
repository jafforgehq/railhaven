# Railhaven: Scorched Line

Portrait mobile idle colony game (Godot 4.7, GDScript, Mobile renderer with 4x MSAA 2D, falls back to OpenGL).
Outside it is 60–68 °C depending on the region; the colony lives aboard an armored train that never stops.
The journey runs through five regions and takes roughly 20+ hours of game time (see Test).
All art is made in **Blender** from Python scripts in `art/blender/`: toon-shaded, outlined models rendered
orthographically to sprites (crew animations and portraits, every carriage type at levels 1–10, the locomotive,
wheels and rods, drones, scenery strips per region, five landmarks, item icons). Godot only adds in-engine effects on top:
lamp light cones, glows, sparks, bubbles, smoke, dust and weather tints.

## Art pipeline (Blender only)

```bash
art/build_all.sh                       # rebuild every asset (≈3 min), output goes to assets/sprites/
```

| Script | Output |
|---|---|
| `art/blender/crew.py` + `art/build_sprites.py` | 14 crew presets (7 roles) × 8 animations (sheet), sleep pose, portrait |
| `art/blender/carriages.py` | `carriage_<type>_<level>.png` (9 types × 10 levels), `locomotive.png`, wheels, rod, fan rotor, drones |
| `art/blender/scenery.py` | sky, far/mid/near/track/front parallax strips (tile at 720 units); sky/far/mid per region; 5 landmarks (dormant/restored) |
| `art/blender/icons.py` | resource / item icons (UI glyphs such as ✓ + × stay vector) |
| `art/blender/common.py` | shared toon material (3 light bands + AO), inverted-hull outlines, primitives, ortho render |

Sprite sheets import as VRAM-compressed (ASTC on mobile) with mipmaps; icons and portraits stay lossless.
After adding new renders run `art/fix_imports.sh` to import them with those settings.

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
more beds, food and water → survivors arrive → more workers → more production → restore the region's landmark →
depart for the next region.

| Carriage | Effect |
|---|---|
| Locomotive | Cargo hold (storage multiplier) and journey speed |
| Living Quarters | Beds (survivor capacity); resting crew sleep and eat here |
| Greenhouse | Food per worker |
| Water Recycler | Water per worker |
| Workshop | Converts scrap into parts per worker |
| Cooling Module | Raises how many carriages the train can support (+1 when staffed) |
| Drone Bay | Drones repeat salvage runs automatically; pilots add +25% yield each |
| Cargo Hold (ch 2) | Storage for every resource (grows ×2 per level, so costs always fit) |
| Research Lab (ch 2) | Scientists make data; data + parts buy research (one project at a time) |
| Med Bay (ch 3) | Medics give the whole train up to +60% efficiency and faster arrivals |

| Chapter | Region | Landmark | Temp | Level cap | Train | Region bonus |
|---|---|---|---|---|---|---|
| 1 | Scorched Desert | Climate Tower | 65 °C | 5 | 10 | – |
| 2 | Ash Coast | Desalination Works | 62 °C | 6 | 12 | +25% water |
| 3 | Glass Flats | Mirror Array | 68 °C | 7 | 15 | +20% parts |
| 4 | Drowned City | Seed Archive | 64 °C | 8 | 17 | +30% scrap |
| 5 | Green Highlands | Haven | 60 °C | 10 | 20 | +30% food |

- Each survivor eats and drinks 0.6/min. Matching specialists (Engineer → Workshop, Scientist → Lab, Medic → Med Bay, …) work at 125%.
- **Crew levels**: workers gain experience while working (Lv 1–10, +6% output per level).
- **Research**: 24 permanent projects (drone haul, output, storage, upkeep, cost, offline time, XP, …), unlocked by chapter.
- **Supply contracts**: three side tasks with rewards (after the tutorial); a claimed slot offers a new one after 30 min of play.
- **Achievements**: 22 milestones with automatic rewards (Journey → Achievements).
- **Overdrive**: tap in a producing carriage to double its output for 60 s (10 min cooldown).
- **Automatic safe mode**: if food or water runs out, the crew rations (half upkeep, production −30%, growth paused). Nobody dies, online or offline.
- **Offline**: on launch / resume the sim fast-forwards up to 8 h (more with research) in 5 s steps with the same rules and shows a "While you were away" report.
- **Events**: Heatwave, Sandstorm, Distress Signal, then Trader, Broken Rail, Ash Storm (ch 2+) and Raiders (ch 3+). Each is a two-option choice; costs scale per chapter; no answer within 25 s picks the safe option.
- **Saves**: JSON, versioned (v2). v1 saves load into chapter 1 and can depart for chapter 2.

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
$G --headless --path . -s tests/bot_playthrough.gd   # pacing of the whole journey (add "-- quiet" / "passive")
$G --path . -- --shots=/tmp/railhaven_shots --regions    # every region + landmark, research and crew sheets
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

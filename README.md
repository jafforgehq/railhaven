# Railhaven: Scorched Line

Portrait mobile **coolant-sort puzzle** game with a train-restoration meta (Godot 4.7, GDScript,
Mobile renderer with 4x MSAA 2D). The world is 60–68 °C; the colony lives on an armored train.
Every level is a carriage overheating: sort coloured coolant canisters into one-colour tanks before the
heat gauge reaches 70 °C. Wins earn parts that restore the train, region by region, and each region ends
by restoring a landmark. The idle colony version is preserved at git tag `v0.1-idle`.
All art is made in **Blender** from Python scripts in `art/blender/`.

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

Play a level → seal tanks to cool the carriage → win parts + scrap → RESTORE the next task on the train
(build or upgrade a carriage) → the last task restores the region's landmark → depart to the next region.

- **Puzzle rules** (`scripts/puzzle/board.gd`): tanks hold 4 canisters. Tap a tank to lift its top run
  of one colour, tap another tank to pour onto the same colour or into an empty tank. A full one-colour
  tank seals. Ash-covered canisters (from level 31) stay hidden until exposed.
- **Heat**: each pour heats the carriage by (70 − 30) / move budget; sealing a tank cools 2 °C, and
  seals chained within 3 s make a **cold snap** (3 °C more per link). At 70 °C the level is lost: pay
  scrap or watch an ad to cool 15 °C, or give up (costs a life). Every 10th level is a heatwave level
  (one more colour, double parts).
- **Levels**: 300 authored levels in `data/levels.json`, generated and proven solvable by
  `python3 tools/gen_levels.py` (deterministic). Past 300 they repeat with shuffled colours.
- **Boosters**: Undo, Spare Tank (adds an empty tank), Heat Flush (−12 °C). Bought with scrap.
- **Lives**: 5, one back every 20 min; refill with scrap or a rewarded ad.
- **Condenser** (dedicated offline carriage): turns cool night air into scrap while you are away,
  8 h cap rising to 24 h with upgrades; a full tank adds a booster; ad doubles the claim.
- **Cooling Core**: each level of it starts every puzzle 1 °C cooler.
- **Daily drop**, settings (music, SFX, vibration), how-to-play, a level-1 coach tutorial.
- **Ads**: `scripts/autoloads/ads.gd` is a stub that grants rewards in test builds; plug AdMob in there.
- **Saves**: JSON v3. Idle-version saves are kept as `railhaven_save.json.idle.bak`.

| Region | Landmark | Tasks | Parts |
|---|---|---|---|
| Scorched Desert | Climate Tower | 8 | 22 |
| Ash Coast | Desalination Works | 9 | 37 |
| Glass Flats | Mirror Array | 9 | 46 |
| Drowned City | Seed Archive | 9 | 55 |
| Green Highlands | Haven | 9 | 65 |

## Layout

```
scripts/data.gd                 economy, boosters, Condenser, regions + restoration tasks (class Data)
scripts/autoloads/game.gd       progress owner: tasks, lives, currencies, Condenser, levels, JSON save
scripts/autoloads/ads.gd        rewarded-ad facade (test stub until AdMob is linked)
scripts/autoloads/audio.gd      Music/SFX/Ambience buses, SFX pool, haptics, settings (ConfigFile)
scripts/puzzle/board.gd         pure sort rules (SortBoard): pour, ash reveal, undo, win/stuck
scripts/puzzle/puzzle_view.gd   draws tanks + canisters, tap input, pour arcs, seals
scripts/puzzle/puzzle_screen.gd one level: heat gauge, cold snaps, boosters, win/overheat flow
scripts/main.gd                 root: Home (HUD + home sheet) / Puzzle modes, modals, toasts, coach
scripts/ui/                     theme/kit, icons, HUD, home sheet, popups, coach
scripts/world/                  parallax scenery, carriage + locomotive cutaways, drones, heat glow
tools/gen_levels.py             level generator + solver -> data/levels.json
tests/test_puzzle.gd            headless rules / level data / progress checks
scripts/debug/shots.gd          dev-only screenshot tour (`-- --shots=<dir>` [--regions])
```

Patterns (chosen / rejected):
- State + signals on one `Game` autoload, **not** a separate EventBus — one owner emits everything, fewer hops.
- JSON save in `user://` with a version field and atomic temp-file rename, **not** Resource `.tres` saves (user-writable files must not run code).
- Audio settings in `ConfigFile`, **not** inside the game save.
- `Parallax2D` layers with `autoscroll`, **not** the deprecated `ParallaxBackground/ParallaxLayer`.
- World lives in the main viewport (camera zoom 1.7–2.5, auto-fit between HUD and sheet) with UI in a CanvasLayer, **not** a low-res SubViewport: art stays sharp at any phone resolution.
- `canvas_items` stretch + `keep_width` aspect so tall phones get more world, not letterboxing.
- Panels build controls once and refresh values in place, **not** rebuild every tick (buttons would be recreated under the finger).
- The puzzle board is one custom-drawn `Control` (hit-testing + tweened pours), **not** one node per tank in containers (flying canisters between containers is awkward).
- Levels are generated offline and proven solvable by a solver, **not** generated at runtime (deterministic, testable, no stalls on device).

## Test

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path . -s tests/test_puzzle.gd       # rules, level data, progress systems; PASS/FAILED
python3 tools/gen_levels.py                          # regenerate data/levels.json (all levels solved)
$G --path . --resolution 720x1280 -- --shots=/tmp/railhaven_shots             # home, puzzle and popup screens
$G --path . --resolution 720x1280 -- --shots=/tmp/railhaven_shots --regions   # every region
$G --path . -- --shots=/tmp/railhaven_shots              # screenshot every screen + simulated tap/drag checks
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

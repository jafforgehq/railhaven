# Railhaven expansion: 20+ hour playthrough

Goal: the greedy pacing bot (`tests/bot_playthrough.gd`) needs at least 20 h of game time
(online + offline) to finish all content, with no dead wall longer than ~45 min where
nothing can be bought, built, researched or launched.

## Decisions (made 2026-11-01, user said "do whatever you think is okay")

- **5 chapters** instead of 1, each a region with a landmark to restore in 3–4 stages.
  `Data.CHAPTERS` replaces the single `GOALS` / `TOWER_STAGES` lists.
  | # | Region | Landmark | Temp | Region perk | Unlocks | Level cap | Train length |
  |---|--------|----------|------|-------------|---------|-----------|--------------|
  | 1 | Scorched Desert | Climate Tower | 65°C | – | – | 5 | 10 |
  | 2 | Ash Coast | Desalination Works | 62°C | water +25% | Cargo Hold, Research Lab | 6 | 12 |
  | 3 | Glass Flats | Mirror Array | 68°C | parts +20% | Med Bay | 7 | 14 |
  | 4 | Drowned City | Seed Archive | 64°C | scrap +30% | – | 8 | 16 |
  | 5 | Green Highlands | Haven | 60°C | food +30% | – | 10 | 18 |
  Target bot time: ch1 ~1 h, ch2 ~2.5 h, ch3 ~4 h, ch4 ~5.5 h, ch5 ~7 h.
- **Data resource + Research Lab** (Scientist role). Research projects cost data (+parts)
  and run on a timer, one at a time. Permanent bonuses: drone haul, worker output,
  upkeep, storage, build cost, offline cap, crew XP, drone speed. Projects are gated by chapter.
  Data is not on the top bar (keeps HUD simple); it shows in the Research sheet.
- **Cargo Hold**: no workers, storage for all resources. Needed as costs climb.
- **Med Bay** (Medic role): train-wide efficiency bonus and faster arrivals.
- **Crew XP**: workers gain XP while working, level 1–10, +6% output per level.
- **New events**: raiders (ch3+), trader caravan (ch2+), broken rail (ch2+), ash storm (ch2+).
- **Save v2** with migration: v1 saves map to chapter 1 (or chapter 2 start if the tower was restored).
- **Art (Blender only)**: carriage levels 6–10 for all types, 3 new carriages × 10 levels,
  Scientist + Medic crew presets, new icons, 4 region scenery sets (sky/far/mid), 4 landmarks
  (normal + restored).

Rejected: prestige reset (would repeat ch1 instead of adding content), a 5th top-bar chip
(user found the UI too complex), separate full scenery per region for near/track/front
(tint is enough; saves renders).

## Milestones (check off as done, commit after each)

- [x] M1 Chapters refactor: Data.CHAPTERS, per-chapter goals/stages/distance/temp/perk, level cap,
      train length, chapter advance flow + popup, save v2 migration, tests, bot handles chapters
- [x] M2 New carriages: Cargo Hold, Research Lab (+data, research tree, sheet), Med Bay; roles Scientist, Medic
- [x] M3 Crew XP + levels in UI
- [x] M4 New events
- [x] M5 Art: levels 6–10, new carriages, crew presets, icons, region scenery, landmarks (Blender agent)
- [x] M6 Wire art: region scenery switch, landmarks per chapter, new icons
- [x] M7 Balance: bot ≥ 20 h, no wall > 45 min, chapter times near target
- [x] M8 Visual check with screenshot tour, fix layout
- [x] M9 README + memory update

## Extra features (user asked to add features that fit a mobile game)

- [x] Supply contracts (3 rotating side tasks), achievements (22), Overdrive tap boost, haptics

## Log

- 2026-11-01: plan written.
- 2026-11-01: M1–M4 in one pass (chapters, research, cargo/lab/medbay, crew XP, events, save v2).
  Bot found three dead ends, all fixed: nobody to staff a new carriage when everyone is busy
  (`pull_worker`, "+" moves a worker over); cargo storage growing slower than costs (now x2/level);
  one Living Quarters too small at the level cap (second-quarters goal, bigger beds at Lv 6+).
- 2026-11-01: M5/M6 Blender art from two agents (scenery/landmarks/icons; carriages Lv 6–10, 3 new
  types, Scientist/Medic). Shared ground strips use a desaturate+tint shader per region.
- 2026-11-01: M7 balance. Active bot (Overdrive + contracts, checks every 6 s) 20h09–21h07;
  passive bot 21–22h+. Longest wall 1h30 = the final Haven expedition timer.
- 2026-11-01: iOS export OK (exit 0). Pack is 135 MB (ASTC only; 90 carriage textures + 14 crew
  sheets at native 4 px/unit). Option if size matters: Basis Universal import for carriages.

# Railhaven – Audio Credits

All files are open-licensed: **CC0 1.0** (public domain dedication, no attribution required) or **CC BY 3.0 / 4.0** (attribution required, marked **[ATTRIBUTION REQUIRED]** below).
No NC, ND, GPL-only or "royalty free" assets are used. Each license was checked on the source page at download time (2026-10-31).

License URLs:
- CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/
- CC BY 3.0: https://creativecommons.org/licenses/by/3.0/
- CC BY 4.0: https://creativecommons.org/licenses/by/4.0/

Standard processing applied to every file unless the row says otherwise: converted to Ogg Vorbis (quality ~4, 44.1 kHz), metadata stripped. ffmpeg on this machine has no libvorbis, so the encoding was done with libsndfile (python-soundfile). Short sfx: leading silence trimmed (-50 dBFS) and trailing silence trimmed (-60 dBFS), with a 2 ms fade-in and a 10 ms fade-out to avoid clicks. Loudness: sfx normalized to -16 LUFS integrated, and music and ambience loops to -20 LUFS. Gain is always capped so the peak stays at or below -1 dBFS. Clips shorter than 0.4 s cannot be measured in LUFS, so they are peak-normalized to -3 dBFS instead.

## Music (`assets/audio/music/`)

| Base name | File | Title | Author | Source | License | Modifications |
|---|---|---|---|---|---|---|
| theme | theme.ogg | Lone Scavenger | vitalezzz | https://opengameart.org/content/lone-scavenger | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | MP3 (320 kbps) converted to OGG; normalized to -20 LUFS. Not cut. The track has a short fade-in and a ~5 s fade-out, so it loops end-to-start with a gentle dip. |
| tower_restored | tower_restored.ogg | Smooth Guitar Fanfare | OwlishMedia | https://opengameart.org/content/smooth-guitar-fanfare | **CC BY 4.0** (https://creativecommons.org/licenses/by/4.0/) **[ATTRIBUTION REQUIRED]** | WAV converted to OGG; trailing silence trimmed (7.18 s to 6.67 s); normalized to -18 LUFS. |

## SFX (`assets/audio/sfx/`)

| Base name | File | Title | Author | Source | License | Modifications |
|---|---|---|---|---|---|---|
| train_loop | train_loop.ogg | Стук колёс поезда ("Knocking wheels of train", recorded in a wagon) | Ural-66 | https://commons.wikimedia.org/wiki/File:%D0%A1%D1%82%D1%83%D0%BA_%D0%BA%D0%BE%D0%BB%D1%91%D1%81_%D0%BF%D0%BE%D0%B5%D0%B7%D0%B4%D0%B0.ogg | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | Excerpt from 160 s to 192 s of the 4-minute recording. The excerpt is made into a seamless 30 s loop with a 2 s equal-power crossfade from tail to head. Kept mono; normalized to -20 LUFS. |
| wind_loop | wind_loop.ogg | Wind Loop | AntumDeluge (loop edit); original wind recording by InspectorJ (https://freesound.org/people/InspectorJ/sounds/376415/) | https://opengameart.org/content/wind-loop | **CC BY 3.0** (https://creativecommons.org/licenses/by/3.0/) **[ATTRIBUTION REQUIRED]** | FLAC converted to OGG; normalized to -20 LUFS. Not trimmed, so the author's loop points are kept. |
| ui_click | ui_click.ogg | click_001 (from "Interface Sounds") | Kenney (www.kenney.nl) | https://opengameart.org/content/interface-sounds | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | Trimmed; peak-normalized to -3 dBFS. |
| ui_open | ui_open.ogg | drawKnife1 (from "50 RPG sound effects"), a short slide/whoosh | Kenney (www.kenney.nl) | https://opengameart.org/content/50-rpg-sound-effects | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | Trimmed (0.40 s to 0.20 s); +21 dB gain, peak-normalized to -3 dBFS. |
| build | build.ogg | Blacksmith's Hammer | VishwaJai | https://opengameart.org/content/blacksmiths-hammer | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | Two copies of the single anvil strike layered to make a "clank-clank" (second strike at +0.32 s and quieter); normalized to -16 LUFS. |
| upgrade | upgrade.ogg | Rise03 (from "Level up, power up, Coin get (13 Sounds)") | wobbleboxx | https://opengameart.org/content/level-up-power-up-coin-get-13-sounds | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | AIFF converted to OGG; trailing silence trimmed (1.56 s to 0.85 s); normalized to -16 LUFS. |
| collect | collect.ogg | handleCoins2 (from "50 RPG sound effects") | Kenney (www.kenney.nl) | https://opengameart.org/content/50-rpg-sound-effects | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | Trimmed; peak-normalized to -3 dBFS. |
| drone_launch | drone_launch.ogg | Propeller (Cartoon) Loop | Mish7913 | https://opengameart.org/content/propeller-cartoon-loop | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | Resampled from 192 kHz to 44.1 kHz. The loop is tiled and played with a rising speed ramp (0.75x to 1.5x) so the rotor spins up. A fade-in/fade-out envelope makes a ~2.1 s takeoff whir. Normalized toward -16 LUFS (limited by the -1 dBFS peak cap). |
| drone_return | drone_return.ogg | bfh1_hit_02 (from "75 CC0 breaking / falling / hit sfx") + metal_slam_01 (from "100 CC0 metal and wood SFX") | rubberduck | https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx and https://opengameart.org/content/100-cc0-metal-and-wood-sfx | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | The low thud and the metal slam are layered (slam at -8 dB) to make a crate landing; trimmed; normalized toward -16 LUFS (peak-capped). |
| alarm | alarm.ogg | Alarm | EZduzziteh | https://opengameart.org/content/alarm-1 | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | Normalized to -16 LUFS. |
| error | error.ogg | error_006 (from "Interface Sounds") | Kenney (www.kenney.nl) | https://opengameart.org/content/interface-sounds | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | Trimmed (0.50 s to 0.23 s); peak-normalized to -3 dBFS. |
| goal_complete | goal_complete.ogg | Level Up (from "7 Assorted Sound Effects (Menu, Level Up)") | Joth | https://opengameart.org/content/7-assorted-sound-effects-menu-level-up | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | MP3 converted to OGG; cut from 4.18 s to 3.0 s with a 0.6 s fade-out, then trailing silence trimmed (2.78 s); normalized to -16 LUFS. |
| whistle | whistle.ogg | Steam whistle (steamwhistle_0.wav, chord whistle) | bart | https://opengameart.org/content/steam-whistle | CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/) | Trimmed; normalized to -16 LUFS. |

## Required in-game attribution (CC BY)

Put these lines in the game's credits screen or store page:

- "Smooth Guitar Fanfare" by OwlishMedia (https://opengameart.org/content/smooth-guitar-fanfare), licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Trimmed and normalized.
- "Wind Loop" by AntumDeluge (https://opengameart.org/content/wind-loop), based on a recording by InspectorJ (https://freesound.org/people/InspectorJ/sounds/376415/), licensed CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/). Normalized and converted.

## Optional thanks (CC0, not required)

Kenney (www.kenney.nl), vitalezzz, Ural-66, VishwaJai, wobbleboxx, Mish7913, rubberduck, EZduzziteh, Joth, bart.

No files in this folder were synthesized from scratch. drone_launch, build and drone_return are edits or layers of the CC0 recordings listed above.

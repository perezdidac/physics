# Status

How the game is built and where we are. **Update this file in every commit.**

## Current state (2026-11-17)
- Phase 1 (faithful port) on branch `godot-port` (from `uridev`). Nothing committed yet.
- The whole original game runs in Godot: boot menu, custom-match lobby, combat with all 16 weapons, AI, wind, tide, supply drops, victory screen, rematch. English and Catalan texts.
- Checks: `bash tools/lint.sh` → 0 failures (100 scripts); `bash tools/run_tests.sh` → 16 tests, 0 failures (~35 s).
- A code review compared the sim with the JS line by line (all 16 weapons, explosions, FSM, AI): no behavioural mismatch. Its performance and sound-wiring findings are fixed.
- Web export works: `bash tools/export_web.sh` → `build/web/` (~52 MB: 39 MB wasm, 12 MB pck), single-threaded so it runs on any static host without special headers. Tested in Chromium: menu, quick match, firing, crater, turn change, clean console.
- **Campaign built (2026-11-19, not committed): all 7 stages, 30 levels + 7 bosses** (plan in `docs/story_mode.md` §8).
  | Stage | Levels | Mode | Code |
  |---|---|---|---|
  | Ou | egg_1–4 + wasp | real-time platformer | `platform/` |
  | Pelussa | larva_1–5 + tachinid fly | turn-based | `combat/` |
  | Cuca | cuca_1–6 + great tit | turn-based | `combat/` |
  | El Bolsó | nest_1–4 + forestry brigade | turn-based, defend the nest, with the hub and upgrades bought with silk (12 upgrades; silk per won level = 5 + 5 per star, + 15 on a boss; economy in `story_mode.md` section 9; platform upgrades EXTRA_HEART, FAST_DIG, LONG_FLIGHT work in the egg, pupa and moth levels) | `combat/` |
  | La Processó | proc_1–5 + cuckoo | turn-based convoy | `combat/` |
  | La Crisàlide | pupa_1–3 + hoopoe | real-time digging | `platform/` |
  | La Papallona | moth_1–3 + bat | real-time night flight | `platform/` |
  - **Generic boss framework** in `combat/sim/boss/`: intents, phases, attack handlers by data.
  - **Contracts:** `docs/*_contracts.md`.
  - **Checks:** lint 0 failures (250 scripts), 48 tests pass.
  - **Build:** version 0.7.0 exported (`build/android/cucs_debug.apk`) and installed on the owner's Pixel.
  - **Pass 0.6-0.7 (2026-11-19):**
    - Art layer `art/` (ArtKit, ThingArt, ArtRegistry by group, SpriteArt, CutoutRig; `docs/art_contracts.md`): every object, weapon, creature and boss drawn from hand-authored SVGs in `assets/sprites/`, old vector code kept as fallback.
    - Terrain structures drawn as SVG sprites over the terrain (`combat/view/terrain/terrain_overlay.*`), cut where the terrain is carved; smoothed terrain edges.
    - Aim guides and the held weapon only in the touch AIM phase (dashed direction line).
    - Ants: live nav map (`SimNav.sync`), no links through rock, climb on the wall face, fall without support, dig tunnels (`UnitDef.can_dig`); simple critters share one enemy turn.
    - Story levels 6-17 redesigned (smaller arenas, one goal per level: REACH, RESCUE, COLLECT, ONE_SHOT, anthill HP; twists; `combat/sim/sim_goals.gd`).
    - Stage cards explaining how each stage plays (`ui/story/stage_card.gd`, "?" on the map).
  - **Open:** real-phone performance of the overlay and nav not measured; tide in larva_4/cuca_6 now rises once per round (slower) and may need tuning.
  - **Pass 0.5.0 (2026-11-19, not committed):** UI scale from the physical screen for menus, story screens and top HUDs (`TouchMetrics.ui_scale`); smaller story arenas (below); touch controls in MOVE / AIM phases (arrows to walk, drag to aim, hold FIRE for power).
  - **Polish pass 0.4.0 (2026-11-19, not committed):**
    - 14 Gemini backgrounds (`assets/backgrounds/bg_*`, prompts in `docs/background_prompts.md`); `LevelDef.background_key` overrides the map picture in COMBAT levels.
    - Touch buttons sized in millimetres with a size option (see the BUTTONS line below); `HoldButton` labels grow with the button.
    - Closer story camera (`CameraRig.STORY_USER_ZOOM` 1.95), pinch/wheel zoom 0.5–2.5; closer platformer camera on touch devices.
    - Catalan-style music: 15 baked loops (`tools/bake_music*.gd`, `core/sound/music_table.gd`) chosen by screen, stage and boss.
    - Egg stomp: landing on an ant knocks it out (`docs/platform_contracts.md` §8).
    - Silk economy: 12 upgrades, 600 silk; a won level pays 5 + 5 per star (+ 15 on a boss), only for its best result (shop affordable at level 27 with 3 stars, 34 with 2); the results screen shows a "+N silk" chip with a count-up (or "no new silk" on a replay); the hub opens from the first star. The hub list drags from anywhere (cards, buy buttons; a drag never buys), wheel and focus scroll it (`tests/test_silk_shop.gd`).
    - Terrace stone drawn as masonry instead of the JS checkerboard; lighter clouds.
  - **Open:**
    - Balance is untested by humans. The CPU loses most turn-based boss levels because it doesn't use the vulnerable windows, while the defend levels are easy for it.
    - Music never heard by a human; button dpi on the real phone unverified.
    - The sounds for the new creatures are missing.
- **Story arenas (2026-11-19, not committed):** turn-based story levels play on a span of the terrain (`LevelDef.arena_width` 1400-2200 px, centred; the land outside is removed, the camera is limited to it), so fighters meet within 1-2 turns. Classic matches are unchanged. Details in `docs/story_contracts.md` section 6; the seeds of the levels were rescanned for the new spans.
- **Update 2026-11-19 (not committed).** These replace parts of the first test below.
  - **UI scale (UI-SCALE):** `TouchMetrics.ui_scale(vp)` (`ui/widgets/touch_metrics.gd`) = `max(1, mm(1.8) / 13) * button option`, capped at `MAX_UI_SCALE` 1.4 (medium scale: ~1.4 on a 2000x900 window at 440-490 dpi) and so the layout keeps 760x360 logical units; the level card is two columns (story + goal box | real life + tip cards) and the story map shows the 7 stage tabs and the stage's levels in one row each, both without scrolling at 1600x720; 1.0 on desktop. Menus and HUDs are built for `logical_size(vp)` and drawn with `Control.scale` (`TouchMetrics.scaled_root`, `fit_taps` = buttons at least 12 mm, capped at 14 % of the height). Applied to boot (2x2 entries on phones), lobby, `ui/story/*` (full-screen frames on phones, bigger stage tabs and level cards), TopHud (`is_narrow()` now by logical width 740) and PlatformHud. `TouchMetrics.force_dpi` and `CUCS_DPI`/`CUCS_SIZE`/`CUCS_TAG` in `tools/capture_ui.gd` simulate a phone. Test: `TestUiScale`. No new text keys.
  - **Touch buttons sized from the real screen (BUTTONS):** `TouchMetrics` (`ui/widgets/touch_metrics.gd`) converts millimetres to viewport units with `screen_get_dpi` and the window/viewport ratio (web 96 dpi → phone-height assumption); FIRE 17 mm, JUMP 14 mm, every other control at least 12 mm, never below the old pixel sizes. New option `Options.button_size` (small 0.85 / normal 1.0 / large 1.25, saved in `options.cfg`) cycled from the combat top HUD (touch only) and the platformer pause menu. Texts in `docs/i18n_keys_buttons.md`.
  - **Egg stage is now a real-time platformer** (`platform/`: `PlatformSim` + `PlatformScreen`, levels `egg_1..3` with hand-made `PlatformLayout`). `LevelDef.mode` routes PLATFORM or COMBAT.
  - **New touch controls in combat:** floating joystick, aim by dragging from the caterpillar, big hold-to-charge fire button (`combat/hud/touch_pad.gd`, `ui/widgets/touch_*`).
  - **Touch phases (2026-11-19, replaces the joystick and the drag from the caterpillar):** MOVE (start of the turn and the retreat): big walk arrows (hold), Salt (hold = thrust/glide), Mortal, weapon picker, Apunta, Cuc⇄/Passa/Centra; dragging the map pans, pinch zooms. AIM (entered by picking a weapon or Apunta): a relative drag anywhere turns the aim and flips the facing over the top (`CombatSim.set_facing`), FIRE appears (hold to charge, release to shoot; tap for weapons without power), Moure goes back. After the shot or a jetpack start the HUD returns to MOVE. A hint shows the phase. Phase state is `BottomHud.touch_aim`, mirrored in `CombatInput.touch_aim`. Texts in `docs/i18n_keys_touchphases.md`.
  - **Map fixes, also in classic:** a placement registry (`combat/sim/sim_placement.gd`) means no more overlapping or stacked objects, and ants climb walls gradually. A map checker test guards both.
  - **Builds:** the Android preset exports `build/android/cucs_debug.apk`, installed on the owner's Pixel by wireless adb.
  - **Checks:** lint 0 failures (129 scripts), 24 tests pass.
- **Story mode, first test (not committed):** STORY menu entry → campaign map (7 stages, only Egg open) → level intro card → combat → results, with progress saved in `user://story.cfg`. The egg stage has levels 1–2 playable and level 3 "coming soon".
  - Eggs crawl at 35 % speed, cannot jump and hide in needle tufts. Ants play a swarm turn (every ant acts) and bite; the goal is to survive N rounds.
  - Code: `combat/sim/sim_story.gd`, `ai_critter.gd`, `sim_nav.gd`; `combat/view/egg_art.gd`, `ant_art.gd`, `tuft_art.gd`; `ui/story/`; `data/units`, `data/levels`. Contracts in `docs/story_contracts.md`, plan in `docs/story_mode.md`.
  - Checks: lint 0 failures (118 scripts), 19 tests pass.
  - Open: difficulty is low (eggs that just pass still survive); ants have pool caterpillar names; no egg picture on the intro card yet.
- Not done yet: live world behind the boot menu, visual fine-tuning (see "Deviations"), testing on real phones.
- The original JS/canvas game is kept, untouched, in `reference/`.

## Layout
```
AGENTS.md / CLAUDE.md    agent rules (CLAUDE.md just imports AGENTS.md)
project.godot            Godot 4.7, GL Compatibility, 1280×720 landscape, stretch canvas_items/expand; translations en/ca
default_bus_layout.tres  Master (compressor) → Music, SFX, Wind (band-pass)
core/                    autoloads GameState, Options, Sound, ScreenRouter; static ArtCatalog, Palette; core/sound/sound_tables.gd
combat/sim/              battle logic, headless: CombatSim facade + terrain, noise, physics, combat, turns, setup, AI, entity classes
combat/view/             rendering (terrain shader, sky, atmosphere, water, caterpillars, items, weapons, aim HUD, fx), camera, input
combat/hud/              TopHud, BottomHud (weapon drawer, fuse picker), VictoryModal; HudFakeSim for tests
combat/CombatScreen.tscn owns the sim, the frame loop (JS loop() order), input, HUD, rotate overlay, audio wiring
ui/menus/                Boot (splash + main menu), Lobby, RotateOverlay; ui/widgets/ (chamfered panels/buttons); ui/theme.tres
data/types/ + data/      WeaponDef/MapDef resources: 16 weapons, 8 maps (+ ordered lists)
assets/                  backgrounds (8 JPG), fonts (Cinzel, JetBrains Mono, Plus Jakarta Sans, Noto Sans Math fallback),
                         sprites/weapon_icons (16 SVG from the JS), audio (120 baked WAV)
i18n/                    en.po, ca.po (276 keys) built by tools/build_po.py from docs/i18n_keys_*.md
tests/                   headless tests (TestName.tscn + test_name.gd)
tools/                   lint, run_tests, export_web, build_po.py, BakeAudio (regenerates assets/audio), Capture* (windowed screenshots)
reference/               original JS game (read-only)
```

## Key technical decisions
- **Terrain:** the sim generates only the collision mask (~145 ms per map, identical to the JS: noise verified to 1e-9, craters pixel-identical). `combat/view/terrain/terrain_baker.gd` bakes the colour layers once per match on the GPU (three persistent 3200×820 SubViewports: mask, front colour, back wall) with the JS noise formulas, stamps (trees, towers, terraces, girders) included. Each carve/build only repaints its rectangle and bakes the crater scorch permanently (exact JS gradient, using `TerrainSim.last_carve`). Changes are queued and flushed once per frame. The per-frame terrain shader composes the baked layers under a smoothed mask contour (0.5 iso-line of a 4-tap blurred mask, so the 1 px stair steps become diagonals; collision still reads the sim mask).
- **Structures as sprites:** the stamps (trees, tower, barraca, terrace, log, arch, monoliths, viaduct, truss, anthill, girders) are drawn by `combat/view/terrain/terrain_overlay.gd` as real SVG sprites (`assets/sprites/structures/`, art authored in world px, mapping in `TerrainStamps.overlay_pieces`) right after the terrain. The sim pixel mask stays their collision shape. A fourth bake viewport, the *structure mask* (R = stamp pixel solid at match start, G = enclosed void such as the tower chamber), lets the terrain shader hide its front layer under the sprite, and `terrain_overlay.gdshader` compares the live mask with it: mask 1 / struct 0 = ground in front (sprite hidden, so a trunk ends at the grass line), mask 0 / struct 1 = carved (sprite cut with a soft edge and scorched rim), so explosions still destroy the structures.
- **HUD updates:** `wind_changed` drives only the wind widget; `hud_changed` is for real state changes and HUD widgets update in place.
- **Real-time vs sim time:** `CombatSim.advance_real(raw_dt)` runs every frame (also during hit-stop) for the backflip double-press window and the barrel chain delay, which are real-time in the JS.
- **Effects pools** (`combat/view/fx/fx_pools.gd`) are capped (drop oldest) to protect the frame rate.
- **Audio:** the WebAudio synthesis is pre-rendered to WAV by `tools/BakeAudio.tscn`; `Sound` only plays files. Ambient wind is a noise loop through a band-pass bus following the wind.
- **Story music (2026-11-19, not committed):** 15 original cobla loops (menu, 7 stages, 7 boss variants) in `assets/audio/music/`, synthesized by `tools/bake_music.gd` from the scores in `tools/bake_music_data.gd` (`godot --headless --path . res://tools/BakeAudio.tscn -- --music-only`). `Sound` follows the screen through `core/sound/music_table.gd` (menus → menu, level → its stage track, boss level → its boss variant, classic match keeps `sardana_de_ferro`).
- **Text:** all player-facing text through `tr()`; key tables in `docs/i18n_keys_*.md`, regenerate the .po with `python3 -I tools/build_po.py`.
- **Export:** Godot 4.7.2 export templates live in `~/.local/share/godot/export_templates/4.7.2.stable/` (Web + Android installed). `rendering/textures/vram_compression/import_etc2_astc=true` is required by the Web preset (mobile VRAM compression).
- **Debug:** `CUCS_AUTOSTART=cpu godot --path .` starts a CPU vs CPU match directly (anything else: quick 1P vs CPU).

## Deviations from the original
- Terrain colours: shader + overlay instead of per-pixel canvas painting; stamp back-wall colours not painted; texture patterns look coarser than the JS strata.
- Clouds: GPU shader veil; lumpier than the JS flat discs. Lightened on purpose (9-12 small clouds in the upper sky, ~half the alpha, veil 0.16) so the painted backgrounds show.
- Stone masonry (terraces, viaducts, plain stone, stones): running-bond bricks with mortar joints (`masonry()` in terrain_bake.gdshader) instead of the JS two-tone checkerboard, which read as a missing texture on phones.
- Boot menu backdrop: static map JPG instead of the live simulated world.
- Audio: Godot compressor and band-pass approximate the WebAudio ones; turning sound effects off also mutes the wind.
- Custom faces: native file dialog on desktop/Android; not available on web yet.
- `map_seed` carries between matches as in the JS; explicit seeds make generation deterministic (tests).
- First match start hitches ~130 ms while the bake shaders compile; the terrain stays hidden for 2 frames meanwhile.

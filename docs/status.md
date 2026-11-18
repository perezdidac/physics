# Status

How the game is built and where we are. **Update this file in every commit.**

## Current state (2026-11-17)
- Phase 1 (faithful port) on branch `godot-port` (from `uridev`). Nothing committed yet.
- The whole original game runs in Godot: boot menu, custom-match lobby, combat with all 16 weapons, AI, wind, tide, supply drops, victory screen, rematch. English and Catalan texts.
- Checks: `bash tools/lint.sh` → 0 failures (100 scripts); `bash tools/run_tests.sh` → 16 tests, 0 failures (~35 s).
- A code review compared the sim with the JS line by line (all 16 weapons, explosions, FSM, AI): no behavioural mismatch. Its performance and sound-wiring findings are fixed.
- Web export works: `bash tools/export_web.sh` → `build/web/` (~52 MB: 39 MB wasm, 12 MB pck), single-threaded so it runs on any static host without special headers. Tested in Chromium: menu, quick match, firing, crater, turn change, clean console.
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
- **Terrain:** the sim generates only the collision mask (~145 ms per map, identical to the JS: noise verified to 1e-9, craters pixel-identical). `combat/view/terrain/terrain_baker.gd` bakes the colour layers once per match on the GPU (three persistent 3200×820 SubViewports: mask, front colour, back wall) with the JS noise formulas, stamps (trees, towers, terraces, girders) included. Each carve/build only repaints its rectangle and bakes the crater scorch permanently (exact JS gradient, using `TerrainSim.last_carve`). Changes are queued and flushed once per frame. The per-frame terrain shader is just three texture lookups.
- **HUD updates:** `wind_changed` drives only the wind widget; `hud_changed` is for real state changes and HUD widgets update in place.
- **Real-time vs sim time:** `CombatSim.advance_real(raw_dt)` runs every frame (also during hit-stop) for the backflip double-press window and the barrel chain delay, which are real-time in the JS.
- **Effects pools** (`combat/view/fx/fx_pools.gd`) are capped (drop oldest) to protect the frame rate.
- **Audio:** the WebAudio synthesis is pre-rendered to WAV by `tools/BakeAudio.tscn`; `Sound` only plays files. Ambient wind is a noise loop through a band-pass bus following the wind.
- **Text:** all player-facing text through `tr()`; key tables in `docs/i18n_keys_*.md`, regenerate the .po with `python3 -I tools/build_po.py`.
- **Export:** Godot 4.7.2 export templates live in `~/.local/share/godot/export_templates/4.7.2.stable/` (Web + Android installed). `rendering/textures/vram_compression/import_etc2_astc=true` is required by the Web preset (mobile VRAM compression).
- **Debug:** `CUCS_AUTOSTART=cpu godot --path .` starts a CPU vs CPU match directly (anything else: quick 1P vs CPU).

## Deviations from the original
- Terrain colours: shader + overlay instead of per-pixel canvas painting; stamp back-wall colours not painted; texture patterns look coarser than the JS strata.
- Clouds: GPU shader veil; lumpier than the JS flat discs. Not tuned.
- Boot menu backdrop: static map JPG instead of the live simulated world.
- Audio: Godot compressor and band-pass approximate the WebAudio ones; turning sound effects off also mutes the wind.
- Custom faces: native file dialog on desktop/Android; not available on web yet.
- `map_seed` carries between matches as in the JS; explicit seeds make generation deterministic (tests).
- First match start hitches ~130 ms while the bake shaders compile; the terrain stays hidden for 2 frames meanwhile.

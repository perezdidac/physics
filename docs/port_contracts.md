# Port contracts (phase 1)

The shared shapes every porting agent codes against. **Do not change a contract on your own**: ask the coordinator. Behaviour details live in `port_inventory_sim.md` (sim) and `port_inventory_view.md` (view/UI/audio); this file only fixes names and boundaries so agents can work in parallel.

## 0. General rules
- **Faithful port.** Same constants, formulas, update order and quirks as the JS (see inventory §7.3). Keep JS number semantics where they matter: implement `SimMath.clamp_js()` (returns `lo` for NaN/INF), `SimMath.round_js()` (ties up, `floor(x + 0.5)`), `SimMath.sign_js()` (0 for 0).
- **Naming.** Every JS field becomes a `snake_case` property with the same meaning (`linkedAllies` → `linked_allies`, `jetFuel` → `jet_fuel`, `WATER_Y` → `water_y`). Every JS constant keeps its value. So the view can be written against the inventory even before the sim exists.
- **Coordinates.** World pixels, y down, origin top-left of the 3200×820 terrain, radians with 0 = right (as in JS).
- **Text.** Player-facing strings are `tr()` keys. Key = upper snake case in English (`TAUNT_TURN_1`, `FT_SILK_WEB_WOVEN`, `MENU_QUICK_MATCH`). The Catalan original goes to `i18n/ca.po`, the English text to `i18n/en.po`. Text with values uses `tr("FT_DAMAGE_LABEL") % [label, dmg]` style placeholders.
- **Randomness.** The sim uses one `RandomNumberGenerator` owned by `CombatSim` (`sim.rng`), never the global `randf()`. Effects in the view may use their own RNG.
- **Time.** `CombatSim.step(dt)` receives the already-scaled sim dt (`min(real, 0.033)`, × 0.38 in slow-mo, 0 in hit-stop). The scaling is done by `CombatScreen`, from sim requests (signals `hit_stop` / `slow_mo`).

## 1. Ownership (who writes which folders)
| Agent | Owns (writes) | Reads |
|---|---|---|
| SIM | `combat/sim/**`, `data/types/**`, `data/weapons/`, `data/maps/`, `tests/test_sim_*`, `tests/TestSim*` | inventory sim |
| VIEW | `combat/view/**`, `combat/CombatScreen.tscn`, `combat/combat_screen.gd`, `tests/TestView*` | sim classes (read-only), inventory view |
| UI | `ui/**`, `combat/hud/**`, `core/palette.gd`, `core/screen_router.gd`, `core/game_state.gd`, `assets/fonts/`, `tests/TestUi*` | contracts, inventory view |
| AUDIO | `core/sound.gd`, `core/sound/**`, `assets/audio/**`, `tools/bake_audio.gd`, `tools/BakeAudio.tscn`, `default_bus_layout.tres`, `tests/TestSound*` | inventory view §7 |
| AI (second wave) | `combat/sim/ai_brain.gd`, `tests/TestAi*` | sim |
| DATA/I18N (second wave) | `i18n/**`, `data/hats/`, `data/names.tres`, `data/taunts.tres`, `assets/sprites/weapon_icons/` | all |

`project.godot` and `docs/status.md` are edited only by the coordinator; agents put what they need in their final report.

## 2. Sim API (`combat/sim/`)
`class_name CombatSim extends RefCounted` — the facade that replaces all JS globals of the match.

### State (public, read by the view/HUD; mutated only by the sim)
- `terrain: TerrainSim` — `W := 3200`, `H := 820`, `mask: PackedByteArray` (index `y*W+x`, 1 = solid), `water_y: float`, `map: MapDef`, `archetype_id: String`, `texture_style: String`, `tree_spots`, `valley_spots`, `is_solid(x, y) -> bool`, `surface_normal(x, y) -> Vector2`, `find_surface_y(x, from_y) -> float`.
  - **Generation split (decided for performance):** the sim generates the **mask** (height profile, archetypes, caverns, terraces, landmark/tree solids) in GDScript, with the cavern ellipse bounding-box pre-test. It does **not** paint colours. It also returns `stamps: Array[Dictionary]` describing every stamped structure (`{kind, x, y, w, h, style, ...}`: terraces, landmarks, trees, girders) so the view can paint them.
  - The view paints the colour layers (front and back) with a **canvas shader** that reproduces the JS colour formulas using the same noise (perm table passed as a 256×1 texture) and reads the mask as a texture. Visual result ≈ JS; gameplay identical.
  - Signal `terrain_changed(rect: Rect2i)` after `carve_crater` / `build_girder`, so the view updates the mask texture region.
- `fighters: Array[SimFighter]`, `projectiles: Array[SimProjectile]`, and the other entity arrays with the JS names in snake_case (`barrels`, `mines`, `crates`, `airstrike_planes`, `silk_webs`, `silk_nests`, `pine_nuts`, `larvae_swarms`, `updrafts`, `rovellons`, `caganers`, `escudelles`, `tombstones`, `surface_flora`). Entity classes are small typed classes (`SimFighter`, `SimProjectile`, …) or typed Dictionaries; fields as in inventory §2.4–2.6, snake_case.
- Match/turn: `turn_phase: int` (enum `Phase { TURN_PLAY, RETREAT, ACTION_WAIT, TURN_DELAY, GAME_OVER }`), `turn_timer`, `phase_timer`, `active_team`, `active_fighter`, `round_number`, `team_ammo: Array[Dictionary]`, `selected_weapon_idx`, `team_damage_dealt`, `winner: int`.
- Wind: `wind: int`, `wind_float`, `wind_target`, `wind_gust_flash`.
- Aim (also written by the AI so the view can show it): `aim_pitch`, `aim_angle`, `is_charging`, `charge_power`, `mouse_world: Vector2`, `custom_grenade_fuse`, `procession_convoy_enabled`.
- `playing: bool` — false for the splash/menu showcase (JS `appStage != 'PLAYING'`).

### Setup and stepping
- `func setup(cfg: MatchConfig) -> void` — JS `initMatch` (+ terrain generation). `MatchConfig` (in `combat/sim/match_config.gd`): `map_idx`, `game_mode` (`"1P_CPU"`, `"2P_LOCAL"`, `"CPU_CPU"`), `ai_difficulty` (`"ROOKIE"`, `"VETERAN"`, `"NIGHTMARE"`), `worms_per_team`, `team_names: Array`, `team_hats: Array`, `seed: int` (0 = random).
- `func step(dt: float) -> void` — wind update, AI, physics, turn state machine, in the JS order (inventory §7.2 item 12).
- `func is_current_turn_ai() -> bool`.

### Input commands (from the human controller; the AI calls the same internals)
`set_move(dir: int)` (-1/0/1), `set_aim_input(dir: int)` (-1 up / 0 / +1 down, applied in step), `jump_forward()`, `jump_backward()`, `begin_charge_or_fire()`, `release_charge()`, `select_weapon(idx: int) -> bool`, `set_fuse(seconds: int)`, `switch_fighter()`, `spin_silk_web()`, `toggle_convoy()`, `set_target(world_pos: Vector2)` (AIRSTRIKE), `set_glide(held: bool)` (W/up held for jetpack/glide).

### Events (signals) — replace every DOM/SND/camera write found in the JS
| Signal | Args | JS origin |
|---|---|---|
| `sfx` | `name: String, params: Dictionary` | every `SND.x(...)` call; `name` = the JS method name in snake_case |
| `float_text` | `pos: Vector2, text: String, color: Color, life: float` | `floatingTexts.push` (text already translated by the sim with `tr()`) |
| `speech_bubble` | `fighter: SimFighter, text: String, life: float` | `spawnSpeechBubble` |
| `effect` | `kind: String, params: Dictionary` | particle spawners (`explosion`, `water_plume`, `urticating_hairs`, `debris`, `smoke`, `fireball`, `shockwave`, `ripple`, `bubbles`, `flora_uproot`, …; one `kind` per JS spawner) |
| `camera_focus` | `pos: Vector2, fighter: SimFighter` | `impactCam` writes |
| `screen_shake` | `amount: float` | `shake = ...` |
| `flash` | `pos: Vector2, amount: float` | `flashLight`, `flashPos` |
| `hit_stop` | `seconds: float, use_max: bool` | `hitStopTimer` writes |
| `slow_mo` | `seconds: float, use_max: bool` | `slowMoTimer` writes |
| `terrain_changed` | `rect: Rect2i` | `carveCrater`, `buildDryStoneGirder` |
| `hud_changed` | — | `updateHUD()`, `buildWeaponBar()`, DOM label writes (real state changes only; HUDs refresh incrementally) |
| `wind_changed` | — | `updateWindHUD()`: every step while the wind updates; only the wind widget listens |
| `turn_started` | `team: int, fighter: SimFighter` | `startNextTurn` |
| `game_over` | `winner: int, stats: Dictionary` | `showVictoryModal` |

## 3. Data (`data/`)
- `data/types/weapon_def.gd` (`class_name WeaponDef extends Resource`): `id, key, name_key, default_ammo (-1 = infinite), type, wind_factor, fuse, has_custom_fuse, blast_r, max_dmg, knockback, reach, icon: Texture2D`. One `.tres` per weapon in `data/weapons/NN_id.tres`, plus `data/weapons/weapon_list.tres` (ordered array; order = JS index).
- `data/types/map_def.gd` (`class_name MapDef`): all MAPS fields; colours as `Color`; `background_key` for `ArtCatalog.background()`. `data/maps/NN_id.tres` + `map_list.tres`.
- Names, taunts, hats, palettes, difficulty jitter: `data/types/*.gd` + `.tres` (second wave), until then constants in `combat/sim/sim_tables.gd`.

## 4. Global state (`core/game_state.gd`, owned by UI)
Holds the lobby choices between screens: `game_mode`, `ai_difficulty`, `worms_per_team`, `team_names`, `team_hats`, `custom_faces`, `map_idx`, `has_custom_names`, `func make_match_config() -> MatchConfig`.

## 5. Screens
`ScreenRouter.go(name)` with names: `boot` (splash + main menu), `lobby` (custom match setup), `combat`. Overlays inside combat (HUD, weapon drawer, fuse picker, victory modal, rotate-device overlay, pause) are child Controls of `CombatScreen`, built by UI as scenes in `combat/hud/` and instanced by VIEW in `CombatScreen.tscn`.

## 6. Audio (`core/sound.gd`, autoload `Sound`)
`Sound.play(name: String, params: Dictionary = {})` for every JS `SND.*` method (snake_case name), `Sound.set_music(on)`, `Sound.set_sfx(on)`, `Sound.start_music(track)`, `Sound.unlock()` (first user tap). `CombatScreen` connects `sim.sfx` → `Sound.play`.

**Decided:** the procedural WebAudio synthesis is **pre-rendered** to `.wav` files by a headless bake tool (`tools/bake_audio.gd` + `tools/BakeAudio.tscn`, owned by AUDIO) into `assets/audio/` (sfx variants, worm voices, music). At runtime `Sound` only plays `AudioStreamWAV`s (pitch/volume variations through `params`). Ambient wind stays live (noise through a band-pass bus) if needed. AUDIO also owns `assets/audio/**` and `default_bus_layout.tres`.

# Contracts: egg platformer, touch controls, map fixes (2026-11-19)

Design: `docs/story_mode.md` §4, §4b, §4c. General rules: `docs/port_contracts.md` §0 and `AGENTS.md`.
**Hard rules**
- Never commit, merge or push.
- Every test must keep passing. Classic gameplay may change **only** where §4c says so (object placement, ant climbing).
- Stay inside your own files. If you need something elsewhere, say so in your report.

## 1. Ownership
| Agent | Owns |
|---|---|
| PLATFORM-SIM | `platform/sim/**`, `data/types/platform_layout.gd`, `data/types/level_def.gd` (only the `mode`/`layout` fields), `data/levels/egg_*.tres`, `data/units/egg.tres`, `tests/TestPlatformSim*`, `tests/test_platform_sim*`, `docs/i18n_keys_platform_sim.md` |
| PLATFORM-VIEW | `platform/PlatformScreen.tscn`, `platform/platform_screen.gd`, `platform/view/**`, `platform/hud/**`, `ui/story/**` (routing and results for platform levels), `tests/TestPlatformView*`, `tests/test_platform_view*`, `docs/i18n_keys_platform_view.md` |
| TOUCH-COMBAT | `combat/view/combat_input.gd`, `combat/hud/**`, `ui/widgets/touch_*` (new), `tests/TestTouch*`, `tests/test_touch*`, `docs/i18n_keys_touch.md` |
| MAP-FIX | `combat/sim/**`, `combat/view/ant_art.gd`, `combat/view/item_art.gd` (only if needed), `tests/TestMapCheck*`, `tests/test_map_check*` |

`project.godot`, `tools/**`, `core/screen_router.gd` and `docs/status.md` belong to the coordinator. The coordinator registers the `platform` screen in `ScreenRouter` (→ `res://platform/PlatformScreen.tscn`).

## 2. Data (already in place)
- `LevelDef.mode`: "COMBAT" or "PLATFORM".
- `LevelDef.layout: PlatformLayout`. See `data/types/platform_layout.gd`; PLATFORM-SIM may add fields and must document them there.
- Egg levels become `mode = "PLATFORM"`. Their texts (`LVL_EGG_*` in `docs/i18n_keys_story_levels.md`) must be rewritten for the platformer. PLATFORM-VIEW owns that file now.

## 3. `PlatformSim` (`platform/sim/platform_sim.gd`, `class_name PlatformSim extends RefCounted`)
Headless and deterministic. It may use its own physics; it must not use `CombatSim`.
- **Setup and stepping**
  - `func setup(level: LevelDef) -> void`
  - `func step(dt: float) -> void`: call with a fixed 1/60 s; the screen accumulates.
- **Input**
  - `func set_move(dir: int)`: -1, 0 or 1.
  - `func set_jump(held: bool)`: press = jump, with jump buffer and coyote time; hold = higher jump; early release cuts the jump.
- **State read by the view**
  - `layout: PlatformLayout`.
  - `player: PlatformBody`: `pos: Vector2` (centre), `vel`, `radius`, `on_ground`, `facing`, `hidden`, `hearts`, `max_hearts`, `invuln`, `walk_cycle`, `squash: Vector2`, `growth` (0..1 = nutrients taken / total).
  - `ants: Array[PlatformAnt]`: `pos`, `vel`, `facing`, `walk_cycle`, `state` ("PATROL", "CHASE", "LOST"), `bite`.
  - `nutrients_taken: Array[bool]` (same order as `layout.nutrients`).
  - `checkpoint_idx: int`, `time: float`, `finished: bool`, `won: bool`.
- **Signals**
  - `sfx(name: String, params: Dictionary)`: reuse the names in `core/sound/sound_tables.gd` where they fit.
  - `float_text(pos: Vector2, text: String, color: Color)`
  - `nutrient_taken(idx: int)`
  - `player_hurt(hearts: int)`
  - `checkpoint_reached(idx: int)`
  - `respawned()`
  - `level_finished(stats: Dictionary)`
- **Rules:** as in `story_mode.md` §4.
  - 3 hearts.
  - A hit costs one heart and gives knockback plus 1.2 s of invulnerability.
  - A pit costs one heart and respawns you at the last checkpoint (or the start).
  - 0 hearts loses the level.
  - Hidden means standing still on the ground inside a tuft; ants don't chase or bite a hidden egg.
  - Ants never walk off a ledge. They chase when they see the player within ~180 px (same platform or ±60 px in height), and go back to patrolling when they lose her.
- **Stats** for `level_finished`, using the same keys as the story results:
  - `level_id`, `won`
  - `stars`: 0 if lost; 1 goal; 2 at least half the nutrients; 3 all of them
  - `reason`: "REACHED_GOAL" or "LOST"
  - `nutrients`, `nutrients_total`, `hearts_left`, `time`
- **Feel.** Make it feel good: acceleration, friction, coyote time ~0.1 s, jump buffer ~0.12 s, variable jump height, a max fall speed. The egg is small (radius ~14) and a bit bouncy.

## 4. Platform screen (PLATFORM-VIEW)
- **`PlatformScreen`**:
  - Owns a `PlatformSim` and runs a fixed-step loop.
  - Camera follows Perleta with look-ahead, clamped to the world.
  - Background: `ArtCatalog.background(layout.background_key)` with parallax.
  - Draws the level procedurally: solids as earth/bark, one-way platforms as giant pine needles, slopes, tufts, nutrients (glowing sap drops), checkpoints and the goal (a sunny glow).
  - Reuses the egg and ant art of `combat/view/egg_art.gd` and `ant_art.gd`. Copy or wrap them, don't edit them.
- **HUD:** hearts, nutrients N/M, a pause/exit button (to `story_map`).
- **Touch:** big ◀ ▶ at bottom left and a big JUMP at bottom right. Multi-touch, semi-transparent, at least 96 px on phones. Shown on touch devices; keyboard (arrows/A-D, space/W/up) always works.
- **End:** on `level_finished`, set `GameState.story_result = stats` and go to `story_results` after ~1.5 s.
- **Story UI:**
  - `LevelIntro` "Play" routes by `level.mode` (`platform` or `combat`).
  - `StoryResults` shows nutrients instead of survivors for platform levels.
  - The level card texts describe the platformer.

## 5. Combat touch controls (TOUCH-COMBAT)
Redesign the touch layout of the turn-based battle (`story_mode.md` §4b):
- floating joystick where the left thumb lands, to move;
- aim by dragging from the active caterpillar (angle and power preview);
- a big fire button (hold to charge, release to fire), with the weapon picker next to it;
- jump and backflip buttons;
- two-finger pan and pinch zoom.

It is shown only on touch devices; desktop mouse and keyboard stay unchanged. The story Pass button still works. It must work at 844×390 (phone landscape) and 1280×720 with touch emulated.

## 6. Map fixes (MAP-FIX)
- **Placement registry** (`story_mode.md` §4c): one shared registry of occupied spots. Barrels, mines, rovellons, caganers, escudelles, flora, nests, crates, hiding spots and fighters must never overlap each other, and must not sit on stamped structures (trees, towers, terraces, girders) unless that object is meant to.
- **Ant climbing:** ants climb walls over time (and the art tilts them), or hop with an arc; never snap.
- **Map checker test:** generate many seeds for each of the 8 maps (classic) plus the story combat setup, and report overlaps, floating or buried objects, and unreachable spawns. It fails above a small threshold. Put the numbers before and after in the report.

## 7. Phase A: egg_4 and the wasp boss (2026-11-19)
Same ownership as §1 (PLATFORM-SIM / PLATFORM-VIEW). Design: `story_mode.md` §8, stage 1.

**Layout additions (PLATFORM-SIM, documented in `platform_layout.gd`):**
- `wind_zones: Array[Rect2]` plus `wind_force: Array[float]` (px/s², + = right), optionally gusting with a period. Also a global `storm: bool`.
- `rain`: falling drops spawned over the level. A drop that hits Perleta knocks her back but costs no heart. The view gets a warning shadow on the ground.
- `puddles: Array[Rect2]`: slow you down and splash.
- `boss: String` ("" or "WASP"), `boss_time: float` (seconds to survive), `arena: Rect2`.

**Sim:**
- `PlatformSim.boss: PlatformBoss` (null when there is no boss), with: `pos`, `vel`, `state` ("PATROL", "WARN", "DIVE", "RECOVER"), `target: Vector2`, `timer`, `facing`.
- **Wasp attack cycle:** it flies a figure-eight above the arena, picks Perleta's position, shows a 0.8 s warning, then dives in a straight line. Touching it costs a heart. After the dive it recovers for 1.2 s.
- **Hiding:** if Perleta is hidden when the dive starts, the wasp misses on purpose (it loses her).
- **Difficulty:** the attacks speed up as `time_left` shrinks.
- **Win:** reach `time_left <= 0` → `level_finished` with reason "HATCHED".
- **Stars:** by hearts left (3 hearts = 3 stars) plus sap if the arena has any.
- **New signals:** `boss_warn(target)`, `boss_dive()`, `storm_gust(dir)`.

**Levels:** `egg_4.tres` (storm, ~3200 px, two checkpoints, 10 sap, ants + wind zones + rain + puddles, ends in the sunny spot) and `egg_boss.tres` (one-screen arena about 1400×720, 4–5 tufts, 60 s). Both PLATFORM. Add them to `level_list.tres` after `egg_3`.

**View:** rain, wind streaks and lightning flashes; puddles; the wasp (procedural: yellow-black, translucent wings with a buzz blur, a stinger); a target marker during WARN; a dive trail; a boss bar "Eclosió en N s" / "Hatching in N s"; the boss intro banner. Results: reason HATCHED.

## 8. Stomp (egg levels)
Egg mode only (`PlatformSim` with no dig/fly state; the pupa and moth levels have no stomp).
- **Rule** (`PlatformSim._try_stomp`, checked before any ant damage, also while invulnerable): the egg is falling (`vel.y > 0`, not on the ground, not hidden), `|dx| < egg.radius + ant.radius - 3`, and her bottom is within `STOMP_DEPTH` (16 px) of the ant's top. Anything else (side contact, from below, rising, walking into it) hurts as before.
- **Effect:** the ant is knocked out; she bounces: `vel.y = -STOMP_BOUNCE` (420), or `-JUMP_SPEED * STOMP_HOLD_MULT` (about 544) when jump is held (then the jump can still be cut by releasing). Squash on the egg, `sfx` "bounce", `float_text` `FT_PLAT_STOMP` ("Knocked out!" / "Noquejada!").
- **Ant state** (`PlatformAnt`): `knocked` (stops walking, seeing and biting), `ko_age` (s since the stomp), `gone` (true after `KO_TIME` = 0.5 s). A knocked ant stays in `ants` so indexes and views stay valid; the view flattens it, fades it and hides it when `gone`.
- **Signal:** `ant_stomped(idx: int, pos: Vector2)`; `PlatformScreen` plays `PlatformFxView.poof(pos)` (dust and sparks).
- **Not stompable:** the wasp (`PlatformBoss`; touching it still costs a heart), the hoopoe, bats and nightjars (their own hurt rules are unchanged).
- **Texts:** new key `FT_PLAT_STOMP` in `docs/i18n_keys_stomp.md`. `LVL_EGG_2_TIP` mentions the stomp.
- **Tests:** `tests/test_platform_sim.gd` (`_stomp`, `_stomp_not_boss`). The level bot got a waypoint helper because stomping ants changes how it climbs.

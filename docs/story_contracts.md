# Story mode contracts (first test: egg stage)

The shared shapes for the story-mode agents. Design: `docs/story_mode.md` §4–5. General rules of `port_contracts.md` §0 still apply.

**Hard rule:** with `MatchConfig.level == null` (classic modes) the sim must behave exactly as before. All existing tests must keep passing, unchanged.

## 1. Data (done by the coordinator)
- `data/types/unit_def.gd` (**UnitDef**), `data/units/egg.tres`, `data/units/ant.tres`.
- `data/types/level_def.gd` (**LevelDef**), `data/types/level_list.gd` (**LevelList**), `data/levels/egg_1..3.tres`, `data/levels/level_list.tres`.
- `MatchConfig.level: LevelDef` (null = classic).
- The SIM agent may tune level values (seeds, counts, rounds) so that the levels play well. It reports what it changed.

## 2. Ownership
| Agent | Owns |
|---|---|
| SIM | `combat/sim/**`, `data/weapons/**` (new weapons), `data/units/`, `data/levels/` (tuning), `tests/test_story_sim*`, `tests/TestStorySim*`, `docs/i18n_keys_story_sim.md` |
| UI | `ui/**` (except the files listed for VIEW), `core/story_progress.gd`, `core/game_state.gd`, `core/screen_router.gd`, `tests/test_story_ui*`, `tests/TestStoryUi*`, `docs/i18n_keys_story_ui.md`, `docs/i18n_keys_story_levels.md` |
| VIEW (after SIM) | `combat/view/**`, `combat/hud/**`, `combat/combat_screen.gd`, `combat/CombatScreen.tscn`, `tests/TestStoryView*` |

`project.godot`, `tools/**` and `docs/status.md` belong to the coordinator.

## 3. Sim API additions
- **Weapons:** `EMPENTA` (Shove) and `MOSSEGADA` (Bite). Both are MELEE. They go at the **end** of `weapon_list.tres`, so the classic indices don't change.
  - EMPENTA: about 8 damage, reach ~34, strong knockback.
  - MOSSEGADA: 10 damage, reach ~36, small knockback.
  - New `WeaponDef.story_only: bool`. When `level == null`, `CombatSim` drops story-only weapons from `sim.weapons`, so the classic match sees exactly the original 16.
- **`CombatSim`:**
  - `level: LevelDef` (null in classic).
  - `hiding_spots: Array[Vector2]`: world points on the surface, i.e. where an egg's centre sits. Plus `const HIDING_SPOT_RADIUS := 34.0`.
  - `rounds_left: int`: rounds until the goal for SURVIVE_ROUNDS, -1 otherwise. It changes at the start of each round.
  - `func team_arsenal(team: int) -> Array[int]`: indices into `sim.weapons` the team may use, in list order. Classic: every weapon, as now.
  - `func end_turn() -> void`: the human or the AI ends the turn early (TURN_PLAY → ACTION_WAIT). Needed by units that may have no weapon.
- **`SimFighter`:**
  - `kind: String` ("CATERPILLAR" by default, else `unit.id`),
  - `unit: UnitDef` (null in classic),
  - `hidden: bool`.
  - HP, radius, speed and jumping come from `unit` when it is set.
- **Setup with a level:**
  - Team 0 = `player_unit` × `player_names.size()`, placed as a group on the left third.
  - Team 1 = `enemy_unit` × `enemy_count`, placed on the right half.
  - Ammo from the arsenals; any weapon not listed has 0 ammo.
  - `hazards`, `supply_drops` and `tide` switch those systems. `turn_time` replaces the 30 s.
  - The player (team 0) plays first. `game_mode` is "1P_CPU"; `ai_difficulty` comes from the level.
- **Hiding:**
  - When a unit with `unit.can_hide` ends its turn within `HIDING_SPOT_RADIUS` of a spot, it becomes `hidden`. Walking clears it.
  - CPU units never target hidden fighters.
  - An enemy that ends its move within ~40 px of a hidden fighter reveals it. The sim emits `float_text` with key `FT_SNIFFED` and the `sfx`.
  - Explosions still hurt hidden fighters.
- **AI `MELEE_CRITTER`** (in `ai_brain.gd` or a new `ai_critter.gd`):
  - Pick the nearest visible enemy, walk to it (jump over steps when `can_jump`), turn to face it and use its first melee weapon when in reach.
  - With no visible target, wander toward the last place it saw one, or towards the nearest hiding spot, then `end_turn()`.
  - It must always end its turn well before the timer runs out.
  - **Walking maps (`SimNav`):** surface tiers per 8-px column. They follow the terrain: every `TerrainSim` edit (`edit_log`: crater, girder, ramp, anthill) refreshes the touched columns before the next search, and critters replan when an edit touches their path. `sim.walk_nav()` is the strict map the critters walk on: a link between two columns exists only if a body can pass between the surface points without crossing rock (walk: segment at body height; climb: free corridor along the wall face and over the lip; drop: free lip and shaft), so no links through thin walls, slabs or ceilings. `sim.nav` stays the permissive map (`SimNav.new(terrain, false)`, height difference only) that the level seeds, the convoy road and the goal/nest checks were tuned with.
  - **Placement:** when the strict map's main ground (largest area walkable both ways) spans at least 60% of the arena width (`SimStory.MIN_MAIN_SHARE`, never less than `MIN_MAIN_SPAN` = 500 px), the eggs are moved onto it and the ants and hiding spots are placed by strict reachability (`sim.placement_nav`); on maps shattered by cliffs the permissive map decides as before and the ants dig their way to the eggs. All levels 6-17 are seeded so the strict placement applies (the seed scan rejects "permissive placement").
  - **Critter phase (shared enemy turn of the walking critters):** in a swarm enemy turn the units whose AI is `MELEE_CRITTER` (ants; not birds, boars or bosses) act together in ONE phase instead of one sub-turn each. `AiCritter.begin_group` (called by `SimTurns.start_next_turn` when it pops the first walker of the queue) takes every other walking critter still in `swarm_queue` into `sim.critter_group` (fighter index order) with one plan each in `sim.critter_plans` (by fighter id); a single walker keeps the old single-ant turn. `active_fighter` / `ai_plan` point at the leader (the first unit that is alive and has not finished) for the HUD ("Torn de ..."), the turn timer and the camera; `AiCritter.update` gives every unit its frame in fighter index order (it swaps `active_fighter` for the call, so bites and damage resolve in that order), `sim.critter_acting` lists the units still alive and not done. A unit that bites (once per phase) or ends its walk is `done`; the phase ends (`end_turn`) when all are done, dead or the sub-turn timer (`SWARM_TURN_TIME`, 6 s) runs out. A bite does not move the phase on while others act (the phase is put back to TURN_PLAY). `sim.is_actor(f)` / `sim.plan_of(f)` tell the physics which fighters the AI moves (climbing on a wall, no falling reset). `SimStory.on_turn_end` hides/sniffs for every unit of the group; `start_next_turn` applies itch/status ticks to all of them and emits one `turn_started` for the phase. The camera frames the middle of the acting units and zooms out when they are spread (`CameraRig._frame_critter_phase`). Test: `tests/test_critter_group.gd`.
  - **Movement** is kinematic but on the real floor: it walks to the foot of a wall (body against the face), climbs along the face, steps over the lip; going down it steps off the edge and lets itself down the face. When nothing supports it (no floor under the feet, face or lip gone) it stops being kinematic and falls with the normal fighter physics (fall damage as usual), then replans.
  - **Digging (`UnitDef.can_dig`, ants only):** when the target (or search destination) has no path, or the path is longer than `2.5 x direct distance + 160 px` while the rock in between is at most 120 px, the ant bites the rock in front of it (`carve_crater`, radius = body radius + 2, every 0.35 s, aimed at the target, slope at most 0.6), then walks into the hole. At most 6 bites per turn (about 35-50 px of tunnel), plays `spoon_scoop` and `debris`, and never digs under the water line or outside the arena. Tunnels go through the normal carve path, so the terrain view, structure overlay and nav update.
- **Win rule SURVIVE_ROUNDS:**
  - When round `survive_rounds + 1` would start and team 0 still has units alive, team 0 wins. Use `winner = 0` and the sfx "victory".
  - Elimination still ends the match either way.
- **`game_over` stats** with a level add these keys:
  - `level_id`,
  - `won: bool` (team 0 won),
  - `survivors: int` (team 0 alive),
  - `stars: int` (0 if lost; 1 + one per `star_survivors` threshold reached),
  - `reason: String` ("SURVIVED", "ELIMINATED_ENEMY", "LOST").
- New player-facing strings go through `tr()` keys in `docs/i18n_keys_story_sim.md`. Format: same table as the other key files, `KEY | Catalan | English`.

## 4. Screens and global state (UI)
- `ScreenRouter` screens:
  - `story_map` → `res://ui/story/StoryMap.tscn`
  - `level_intro` → `res://ui/story/LevelIntro.tscn`
  - `story_results` → `res://ui/story/StoryResults.tscn`
- **`GameState`:**
  - `story_level: LevelDef` (null outside story),
  - `story_result: Dictionary` (the `game_over` stats of the last story match).
  - `make_match_config()` copies `story_level` into `cfg.level` and fills `map_idx`, `seed`, `ai_difficulty`, `game_mode = "1P_CPU"` and `worms_per_team` from it.
  - Every classic entry point (quick match, lobby) sets `story_level = null`.
- **`StoryProgress`** autoload (`core/story_progress.gd`):
  - `levels() -> Array[LevelDef]` (from `level_list.tres`),
  - `is_unlocked(level) -> bool` (the first level is always unlocked; the next one once the previous is won),
  - `stars(level_id) -> int`,
  - `record_result(stats: Dictionary)`.
  - Saved in `user://story.cfg`.
- **Combat end in story** (VIEW): on `game_over` with a level, store the stats in `GameState.story_result`. Then, after a short delay (like the victory modal), call `ScreenRouter.go("story_results")`. The classic victory modal is not shown.

## 5. View and HUD (VIEW, after SIM)
- **Art** (procedural placeholders, drawn like the caterpillars):
  - **Egg:** a pale oval with a scale texture, eyes and a small wobble when it crawls.
  - **Ant:** dark red-brown, three body parts, six legs animated while walking, antennae.
  - **Hiding spots:** pine-needle tufts.
  - **Hidden** fighter: drawn faded (alpha ~0.45) with needles in front of it.
- **HUD:**
  - An objective widget near the turn timer: "Hatching in N turns" (`rounds_left`).
  - A **Pass** button for `end_turn()`, also on a key.
  - The weapon bar shows only `team_arsenal(active_team)`. When the arsenal is empty it shows a short line instead ("No weapons yet: hide!").
  - Name tags and HP bars as now.

## 6. Arena (COMBAT levels, 2026-11-19)
- **`LevelDef.arena_width`** (px, 0 = the whole `SimTables.TERRAIN_W`) and **`arena_center`** (world x, 0 = middle of the terrain). The arena is `[center - width / 2, center + width / 2]`, clamped to the terrain. Only COMBAT levels use it. The terrain arrays stay 3200 px wide.
- **Sim:** `SimSetup.init_match` calls `TerrainSim.set_arena(x0, x1)` right after `generate()`: the mask outside is cleared (no land, only water and void), and `tree_spots` / `valley_spots` outside are dropped. `TerrainSim` exposes `arena_x0`, `arena_x1`, `is_clipped()`, `arena_width()`, `arena_at(frac)`, `clamp_x(x, margin)` (placement clamp, the margin shrinks to 110 px in a clipped arena), `edge_margin(m)` and `clamp_hard(x, margin)` (movement limit). With the whole terrain these equal the old `clampf(x, m, W - m)`, so classic matches generate and play exactly as before.
- **Everything is placed inside the arena:** squads (`SimStory.spawn_span`: ant distance rules shrink with the arena, never below 420 px of walking), bosses (`BossDef.spawn_frac` is a fraction of the arena), anthill (`anthill_x` and `goal_x` are still **world** x: choose them inside the arena), hiding spots, convoy file, nest, boar bands, spore clouds (they bounce 120 px inside the edges), flyers, supply drops and hazards (mapped proportionally). Fighters, bosses and flyers cannot move outside it (invisible wall at the cliff edge).
- **Camera:** `CameraRig.bound_x0/bound_x1` (read from the sim terrain each frame, INF in classic matches) keep the visible span within the arena plus `ARENA_MARGIN` (60 px); an arena narrower than the screen is centred.
- **Widths:** larva_1 900, larva_2 1000, larva_3/4 1100, larva_5 1200, larva_boss 1800; cuca_1 1200, cuca_2/3 1300, cuca_4/5 1400, cuca_6 1500, cuca_boss 1900 (levels 6-17 were shrunk in the second pass, §7); nest_1 1600, nest_2 1700, nest_3/4 1800, nest_boss 2000; proc_1..5 and proc_boss 2200 (goal_x 2550, the walk to the goal is about 1500-2200 px). larva_boss uses `arena_center` 1800. Level seeds were re-chosen with the test scans (CUCS_CUCA_SCAN, CUCS_NEST_SCAN, CUCS_PROC_SCAN) because the terrain inside a span differs.

## 7. Second pass of levels 6-17: goals and twists (2026-11-19)
Levels larva_1..5 and cuca_1..6 got small arenas (§6), at most 3 enemies at the start and a goal each. The new rules live in `combat/sim/sim_goals.gd` (`SimGoals`, state in `sim.goals`, null in classic matches); `SimStory.place_hiding_spots` calls `SimGoals.setup` after the squads are placed. Win rules (`LevelDef.win_rule`):
- **Common to REACH, RESCUE, COLLECT and ONE_SHOT:** `survive_rounds` is a round limit (0 = none): when round `limit + 1` would start the level is lost (reason `TIME_UP`); `sim.rounds_left` counts down. Clearing every enemy still wins (`ELIMINATED_ENEMY`) as in ELIMINATE. Placement is deterministic (no RNG draw); the level seed is chosen with `CUCS_LVL2_SCAN=<id>:<base>` (tests/test_story_rules2.gd).
- **REACH:** `sim.goals.pos` is a ground point the squad can walk to (nearest to `goal_x`, or `goal_frac` of the way across the arena, preferring high ground, away from the enemies); a caterpillar within `goal_radius` px (feet within 70 px of the ground) wins (`REACHED`). Drawn as a pine branch with a sign (`StoryGoalArt`).
- **RESCUE:** same spot, drawn as a silk cocoon. A caterpillar reaching it frees the sister: she joins team 0 as a new unit (name "Brins", full HP) and the level is won at once (`RESCUED`); she counts as a survivor, so `star_survivors` = [3, 4] for a squad of 3.
- **COLLECT:** `collect_count` pine nuts (`SimNut`, life 1e9) lie on ground the squad can walk to, one per slice of the arena; only team 0 picks them up (heals 10 HP, no max HP bonus), `collect_need` of them win (`COLLECTED`). Lost when too few remain to reach the count (`NUTS_LOST`; a nut that falls in the water is gone) or on `TIME_UP`. Goal nuts are ringed in gold.
- **ONE_SHOT:** `enemy_still` keeps the enemies still (`AiBrain` ends their turn at once) and `_shelter_enemies` puts each one behind rock: ground the ants can reach whose straight line to the squad crosses at least 4 solid samples. The arsenal is `player_arsenal` with `use_unlocked = false`. When no shot is left, nothing is in the air (projectiles, pending blasts, planes) and an enemy stands for 1.4 s, the level is lost (`OUT_OF_AMMO`).
- **WAVES with `anthill_hp` > 0:** explosions hurt the anthill (`SimGoals.on_explosion`, from `SimCombat.trigger_explosion`: falloff damage, at least 14 %); at 0 HP the mound is blown away and the level is won at once (`ANTHILL_DESTROYED`); otherwise surviving the rounds still wins (`SURVIVED`). HP bar: top HUD (the nest bar) and over the mouth. `anthill_hp = 0` keeps the old indestructible anthill (cuca_6).
- **Barrels and mines (hazards stay off):** `barrels` explosive barrels (14 HP, so a neighbour up to 68 px away goes off) round the anthill (WAVES) or in rows beside the two enemies nearest to the squad (ELIMINATE); `mines` proximity mines between the squads.
- **Seeds (integration):** with the 60 % placement rule (§3) the seed scan also rejects `permissive placement`; cuca_1 moved 5203 -> 5227, cuca_4 5510 -> 5514 (arc check), cuca_5 5612 -> 5630, the other levels kept their seeds (all pass the scan, all placed on the strict main ground).
- **Integration fixes (review):** the tide rises once per round at round start in story levels (classic matches keep the per-turn JS rule); `SimNav.sync` rescans every column and drops its link cache when `water_y` changed, and `SimGoals.final_water_y` keeps goals and nuts above the water of the last round. Goal spots, nuts and the ONE_SHOT shelter use `sim.placement_nav` (the strict map); the shelter needs 4-14 cover samples and a free lob (`SimGoals._arc_hits`, also checked by the seed scan). REACH/RESCUE need a grounded caterpillar and follow the surface under the goal if it is dug away. A goal reached by the last dying caterpillar (blast, barrel chain) ends as a defeat (`LOST`). ONE_SHOT: the START_AMMO upgrade is ignored, OUT_OF_AMMO is decided at the start of a turn (`SimGoals.on_turn_start`, after the elimination check). `sim.schedule` events (barrel blasts) run from `step()` with simulation time. Mines keep `MINE_GAP` = 60 px from fighters. `SimNav` caches link passability per column (cleared around terrain edits). COLLECT falls back to any dry surface so all nuts are placed.
- **Twists:** `tide` + `tide_round` (first round the water rises, 14 px per round; 10 in classic matches), `wind_scale`, `supply_drops`.
- **Hide-and-seek (larva_5):** a level with `hiding_spots > 0` lets the whole squad hide even if its unit has `can_hide = false`.
- **Stats / reasons:** `reason` may be `REACHED`, `RESCUED`, `ANTHILL_DESTROYED`, `COLLECTED`, `TIME_UP`, `OUT_OF_AMMO`, `NUTS_LOST`; extra keys `anthill_hp`, `anthill_max_hp`, `nuts`, `nuts_needed`. Stars still come from `star_survivors` (survivors of team 0).
- **HUD (`TopHud._goal_text`):** "Arriba a la branca", "Salva la germana", "Pinyons: 2/4", "Munició: 3", each with "· Torns: N" when the level has a limit; WAVES with HP: "Formiguer: 60 % · Onades: 3" plus the bar. Level card: `LevelIntro.goal_lines()`; goal texts may use `{need}`, `{total}`, `{hp}` and `{shots}` (`StoryUi.level_text`). Keys: `docs/i18n_keys_levels2.md`.

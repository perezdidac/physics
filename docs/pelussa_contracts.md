# Contracts: Pelussa stage, turn-based story levels (phase B1, 2026-11-19)

**Design:** `docs/story_mode.md` §8, stage 2.
**Background contracts:** `docs/story_contracts.md` (combat story levels: hiding, swarm turns, `team_arsenal`, `end_turn`, stats) and `docs/platform_contracts.md` §6 (placement).

**Hard rules**
- Never commit.
- Every test must keep passing.
- Classic matches unchanged.
- Stay in your own files.

## 1. Ownership
| Agent | Owns |
|---|---|
| LEVELS-SIM | `combat/sim/**`, `data/types/level_def.gd` (new fields), `data/types/unit_def.gd` (new fields), `data/units/**`, `data/levels/larva_*.tres`, `data/levels/level_list.tres`, `core/game_state.gd` (arsenal from progression), `tests/test_story_sim*`, `tests/test_pelussa_sim*` + scenes, `docs/i18n_keys_story_sim.md` |
| LEVELS-VIEW | `combat/view/**`, `combat/hud/**`, `combat/combat_screen.gd`, `ui/story/**`, `tests/test_pelussa_view*` + scenes, `docs/i18n_keys_story_levels.md` (texts `LVL_LARVA_*`), `docs/i18n_keys_story_view.md` |

The coordinator owns `project.godot`, `tools/**` and `docs/status.md`.

## 2. Data
**New units** (`data/units/`):

| Unit | HP | Radius | Speed | Can jump | AI | Art |
|---|---|---|---|---|---|---|
| `larva_l1.tres` | 45 | 9 | 0.85 | yes | CATERPILLAR | small caterpillar, pale and fluffy |
| `larva_l2.tres` | 60 | 10.5 | 0.9 | yes | CATERPILLAR | a bit bigger, browner |
| `blue_tit.tres` (`id` BLUE_TIT) | 40 | 13 | — | flies | FLYER | blue tit (*mallerenga blava*) |

**New `UnitDef` fields:** `flies: bool` and `art_scale: float` (1 = caterpillar size).

**New weapon:** `PICOTADA` (peck), MELEE, story-only, 12 damage, reach 40, medium knockback.

**New `LevelDef` fields** (COMBAT levels):
- `enemy_units: Array[UnitDef]` and `enemy_counts: Array[int]`: a mixed enemy team. If empty, the old `enemy_unit` × `enemy_count` is used.
- `win_rule`: also "WAVES". An anthill at `anthill_x` spawns `wave_size` ants at the start of each enemy turn for `survive_rounds` rounds. Win = survive them all.
- `abilities: Array[String]`, e.g. "SILK_WEB": the existing silk web of the classic game, allowed in this level.
- `use_unlocked: bool` (default true): the player's arsenal = `player_arsenal` + every weapon unlocked by the levels won so far (`StoryProgress.unlocked_weapons()`). `GameState.make_match_config()` merges them into `MatchConfig.extra_arsenal: Dictionary` (weapon id → ammo, -1 = unlimited). The sim must not read autoloads.
- `wind_scale: float` (default 1): multiplies the random wind (larva_5 "September wind" uses 1.8).

**The 5 levels** (`larva_1..5.tres`, `mode` COMBAT): add them to `level_list.tres` after `egg_boss`. Ids, title keys `LVL_LARVA_N_*`, and fixed seeds chosen with the map checker so the spawns are good.

| Level | Map | Squad | Enemies | Rule | Arsenal / abilities | Unlocks |
|---|---|---|---|---|---|---|
| larva_1 *Germanes de seda* | 0 montserrat | 3 × L1 | 2 ants | ELIMINATE | URTICARIA −1 | — |
| larva_2 *El fil de seda* | 3 castellfollit | 3 × L1 | 4 ants | ELIMINATE | + SILK_WEB | FUET |
| larva_3 *El formiguer* | 1 cadaques | 3 × L1 | anthill, waves of 2 for 5 rounds | WAVES | — | CARQUINYOLI |
| larva_4 *La primera muda* | 1 cadaques | 3 × L2 | 3 ants + 1 blue tit | ELIMINATE | — | BAT |
| larva_5 *Vent de setembre* | 0 montserrat | 3 × L2 | 2 blue tits + 2 ants | ELIMINATE | wind_scale 1.8 | — |

The weapon of each "Unlocks" cell is added to the following levels by `use_unlocked`.

## 3. Sim
- **Mixed enemy teams.** Each enemy unit uses its own AI. All MELEE_CRITTER and FLYER enemies act in the swarm turn (each one acts once), as the ants already do.
- **FLYER AI** (blue tit):
  - It flies (no gravity while acting) from a perch (a tree top or a high point) to the nearest visible caterpillar, pecks with PICOTADA and flies back up to a perch.
  - **Telegraph:** before the swoop it hovers for 0.6 s with a `warn` state that the view can draw.
  - When hit by an explosion or knocked back, it falls with gravity until it lands, then flies normally on its next turn.
  - Its HP bar works like the others. If it falls in the water, it drowns, like a caterpillar.
- **WAVES:**
  - The anthill is a solid stamp the ants come out of. Spawned ants use the placement registry near `anthill_x`.
  - The HUD needs `waves_left` (like `rounds_left`) and `enemies_alive`.
  - Ants still alive after the last wave don't matter: surviving the last round wins.
- **SILK_WEB in levels:** `spin_silk_web()` allowed when the level lists it. Classic is unchanged.
- **Stats** (story results): `survivors` and `stars` as now (1 won, 2 and 3 by survivors); add `enemies_defeated`.

## 4. View and HUD
- **Larva art:** the caterpillar art scaled by `unit.art_scale`. L1 is pale cream with long white hairs (fluffy), L2 is browner; no hats; a cute face.
- **Blue tit:** procedural side-view bird with a blue cap, a yellow belly and a black eye stripe. Wing flaps while flying, a hop when perched, the `warn` hover with a small "!" and a dive trail.
- **Anthill:** an earth mound with a hole and a few ants around it; dust when a wave spawns, plus a "Wave N" banner.
- **HUD objective:**
  - ELIMINATE: "Enemics: N".
  - WAVES: "Onades: N".
  - SURVIVE: as now.
- **Weapons:** the weapon bar shows the merged arsenal; a "NEW!" badge on weapons unlocked by the last level won.
- **Level intro card:** enemies list, weapons list, abilities (silk web).
- **Story map:** the Pelussa stage opens once `egg_boss` is won. It has 5 nodes, plus a locked boss node "La Mosca Taquina" (coming soon, phase B2).
- **Texts:** `LVL_LARVA_1..5_TITLE/INTRO/GOAL/TIP`, short and affectionate, with real biology:
  - The L1 larvae hatch together in late summer and spin their first silk.
  - They eat pine needles in groups.
  - The urticating hairs appear in later instars (playful licence for L1: "your first tiny hairs").

# Contracts: La Processó, convoy levels (phase D1, 2026-11-19)

**Design:** `docs/story_mode.md` §8, stage 5. Turn-based, in `combat/sim`.

**Hard rules**
- Never commit.
- All tests pass.
- Classic matches unchanged. The classic convoy toggle and linked allies must keep working.

## Ownership
| Agent | Owns |
|---|---|
| PROC-SIM | `combat/sim/**`, `data/types/**` (fields), `data/units/**`, `data/bosses/cuckoo*.tres`, `data/levels/proc_*.tres`, `level_list.tres` (insert after `nest_boss` and before `pupa_1`), `tests/test_proc_sim*` + scene, `docs/i18n_keys_proc.md` |
| PROC-VIEW (later) | view, HUD, story UI |

## Rule `CONVOY`
- **The squad is a procession** of 5–6 caterpillars in single file. The **leader** is the first one, with `SimFighter.is_leader`. The others follow it automatically: when the leader walks, the line follows its path at a fixed spacing. The classic "linked allies" code can be reused if it fits.
- **The player controls only the leader** (move, jump, weapons). Followers never act on their own, but each one can be hit.
- **Win:** the leader reaches the goal zone (`LevelDef.goal_x`, soft soil to bury in). Lose if the leader dies.
- **Stars:** followers alive at the end, out of the starting count. 1 star = won, then thresholds.
- **Turn:** a player turn is a leader turn with a walk budget (`march_budget` px per turn, e.g. 420) instead of only the timer. The HUD needs `march_left`.
- **Breaking the line:** a follower knocked away more than 120 px from the line is "lost". It can rejoin only if the leader walks back near it (within 60 px). Lost followers at the end don't count for stars.

## Hazards and enemies
- **Wild boar** (`WILD_BOAR` unit, `ai` "CHARGER"):
  - It waits off-screen and is telegraphed one turn before.
  - Then it charges horizontally across a band, knocking everything back.
  - It is not killable and leaves after the charge (an environmental hazard).
- **Calosoma** (`CALOSOMA`, a beetle):
  - A fast melee critter with 120 HP.
  - It chases the line and bites followers (20 damage).
  - It is the mini-boss of proc_3 (ELIMINATE it or reach the goal).
- **Beauveria fungus clouds** (`spores: Array[Rect2]` in the level): static or drifting clouds that do 6 damage per turn to every fighter inside at its turn start.
- **Ants:** as before.

## Levels (stage "PROCESSION")
| Id | Map | Line | Hazards and enemies | Notes | Unlocks |
|---|---|---|---|---|---|
| proc_1 *En fila índia* | 0 montserrat | 5 × L5 | 2 ants | tutorial | — |
| proc_2 *El senglar* | 2 taull | 5 | 2 boar charges + ants | | — |
| proc_3 *El Calosoma* | 6 pedraforca | 5 | Calosoma + ants | | HOLY |
| proc_4 *Pluja de primavera* | 5 tarraco | 6 | spore clouds + ants + 1 blue tit | | — |
| proc_5 *Terra tova* | 1 cadaques | 6 | mixed: boar, spores, Calosoma, birds | long | — |
| proc_boss *El Cucut* | 7 montblanc | 6 | boss | the goal must be reached, or the cuckoo defeated | — |

## Boss `cuckoo_boss.tres`
**Biology:** the cuckoo is one of the few birds that eat hairy processionary caterpillars, and it arrives in spring.

- **Stats:** HP 240; it flies.
- **Attacks:**
  - `MELEE_TARGET` "SWOOP": marks 1 follower (2 in phase 2), 30 damage. Dodge by moving the line so the target moves.
  - `GUST`.
  - `MOVE` to a perch, with rest state "SATED" after eating: vulnerable for one turn.
- **Armour:** × 0.25 outside SATED.
- **Win rule `BOSS_OR_GOAL`:** defeat the boss or the leader reaches the goal.

Use the boss framework (`combat/sim/boss/**`); add handlers only if needed.

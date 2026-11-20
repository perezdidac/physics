# Contracts: Crisàlide (digging) and Papallona (night flight), real-time (phase D2, 2026-11-19)

**Design:** `docs/story_mode.md` §8, stages 6–7. Both stages reuse the egg platformer (`platform/`), with new modes.

**Hard rules**
- Never commit.
- All tests pass.
- The egg levels behave exactly as now.

## Ownership
| Agent | Owns |
|---|---|
| PLAT2-SIM | `platform/sim/**`, `data/types/platform_layout.gd`, `data/levels/pupa_*.tres`, `data/levels/moth_*.tres`, `level_list.tres` (append at the end; the NEST-SIM agent appends nest levels in parallel: re-read the file just before editing and keep both), `tests/test_plat2_sim*` + scene, `docs/i18n_keys_plat2.md` |
| PLAT2-VIEW | `platform/view/**`, `platform/hud/**`, `platform/platform_screen.gd`, `tests/test_plat2_view*` + scene, `docs/i18n_keys_plat2_view.md` |

The story map, cards and texts for these stages come later; they live in `ui/story/**`, owned by another agent now.

## 1. Pupa: dig mode (`layout.mode = "DIG"`)
- **The world** is a cross-section of soil: a diggable mask (a grid of 4 px cells, made from the layout's rect lists, with solid "rock" rects that can't be dug), roots, stones and air galleries.
- **Perleta as a pupa:** slow walking, a small hop, and **digging** by holding a direction into the soil. She digs at about 60 px/s and leaves a tunnel behind.
- **Falling stones** (`stones`): a stone sitting over a gallery falls when the soil under it is dug. It hurts.
- **Flood** (`flood_rate`): water rises from the bottom (or pours in from the top) at a set speed. Being underwater for more than 2 s costs a heart.
- **Goal:** reach the safe chamber (`goal`). Hearts, checkpoints and sap work as in the egg levels.
- **Boss "HOOPOE":**
  - The hoopoe walks on the surface (the top band).
  - **Noise:** digging or moving fast makes noise rings. If a noise ring reaches the surface, the hoopoe walks there and strikes down with its long beak: a fast vertical stab down to about 260 px into the soil, telegraphed by a 0.8 s shadow and dirt trickle.
  - **Staying still is silent.**
  - **Win:** survive `boss_time` (the pupa turns into a moth) → reason "METAMORPHOSIS".

## 2. Moth: flight mode (`layout.mode = "FLY"`)
- **Night level**, mostly open air with obstacles (trees, rocks, walls).
- **Flight:** each tap of JUMP is a wing flap (upward impulse). Holding it glides (slow fall); left and right steer. There is a max speed.
- **Lights** (`lights`): street lamps with a pull radius that drags the moth toward them. Touching a lamp stuns her for 1 s and costs a heart.
- **Pheromone traps** (`traps`): a sticky box. Touching one = lose a heart and respawn at the checkpoint.
- **Nightjar** (`nightjars`): a bird patrolling a path. It chases when it sees her within 220 px; contact costs a heart.
- **Shadows** (`shadows`): rects of shadow; hidden while inside.
- **Boss "BAT":**
  - Echolocation pulses: an expanding ring from the bat every few seconds.
  - If the ring passes over the moth while she is **not** in a shadow, the bat marks her (0.6 s warning) and swoops.
  - Shadows move or blink over time.
  - **Win:** survive `boss_time` → reason "EGGS_LAID". This is the ending; the cycle restarts.

## 3. Levels
| Id | Mode | Summary |
|---|---|---|
| pupa_1 *Sota terra* | DIG | tutorial: dig down to the chamber, sap in pockets |
| pupa_2 *Les arrels* | DIG | roots (undiggable) maze, falling stones |
| pupa_3 *Aiguats* | DIG | the flood rises; dig up and sideways fast |
| pupa_boss *La Puput* | DIG | boss, 75 s |
| moth_1 *Primer vol* | FLY | flight tutorial, a few lamps |
| moth_2 *Llums del poble* | FLY | many lamps and traps |
| moth_3 *L'enganyapastors* | FLY | nightjars and shadows |
| moth_boss *El Ratpenat* | FLY | final boss, 75 s |

- **Stages:** "PUPA" and "MOTH".
- **Backgrounds:** existing keys for now (`pedraforca`, `montserrat`); the night tint is drawn by the view.
- **Completable:** each level must be finished by a test bot.

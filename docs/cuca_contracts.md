# Contracts: Cuca stage (phase C1, 2026-11-19)

**Design:** `docs/story_mode.md` §8, stage 3.
**Builds on:** `docs/pelussa_contracts.md` (units, mixed teams, FLYER, WAVES, `use_unlocked`) and `docs/boss_contracts.md` (bosses as data).

**Hard rules**
- Never commit.
- All tests pass.
- Classic matches unchanged.

## Ownership
| Agent | Owns |
|---|---|
| CUCA-SIM | `combat/sim/**` (only if needed), `data/units/**`, `data/bosses/great_tit*.tres`, `data/levels/cuca_*.tres`, `level_list.tres`, `tests/test_cuca_sim*` + scene, `docs/i18n_keys_cuca.md` |
| BOSS-VIEW | `combat/view/**`, `combat/hud/**`, `combat/combat_screen.gd`, `ui/story/**`, `docs/i18n_keys_story_levels.md`, `docs/i18n_keys_boss_view.md`, `tests/test_boss_view*` |

## Units
| Unit | HP | Radius | art_scale | Notes |
|---|---|---|---|---|
| `larva_l3` | 70 | 11 | 0.95 | caterpillar look, CATERPILLAR AI |
| `larva_l4` | 85 | 11.5 | 1.0 | |
| `larva_l5` | 100 | 12 | 1.05 | |
| `great_tit` (*mallerenga carbonera*) | 60 | 15 | — | FLYER, `melee_weapon` PICOTADA, a stronger peck via its own weapon `PICOTADA_FORTA` (16 damage, reach 44, story-only, appended) |

## Levels
- **Squads:** 4 caterpillars from cuca_1.
- **Arsenal:** URTICARIA plus `use_unlocked`, `SILK_WEB`.
- **Unlocks:** each level unlocks the weapon in its row, available from the next level on.
- **Seeds:** fixed, checked with the map checker.

| Id | Map | Squad | Enemies | Rule | Unlocks |
|---|---|---|---|---|---|
| cuca_1 *L3: la colla creix* | 3 castellfollit | 4 × L3 | 3 blue tits | ELIMINATE | BAZOOKA |
| cuca_2 *Pinyes de Poblet* | 7 montblanc | 4 × L3 | 2 blue tits + 3 ants | ELIMINATE | GRENADE |
| cuca_3 *L4: pell nova* | 2 taull | 4 × L4 | 2 great tits | ELIMINATE | SHOTGUN |
| cuca_4 *Els cingles* | 6 pedraforca | 4 × L4 | 2 great tits + 1 blue tit | ELIMINATE | GANXO |
| cuca_5 *L5: la gran muda* | 5 tarraco | 4 × L5 | 2 great tits + 2 blue tits | ELIMINATE | CLUSTER |
| cuca_6 *Tardor a la vila* | 7 montblanc | 4 × L5 | mixed: 2 great tits, 2 blue tits, ants from an anthill (waves of 2 for 4 rounds) | WAVES | DYNAMITE |
| cuca_boss *La Mallerenga* | 3 castellfollit | 4 × L5 | boss | BOSS | — |

**Boss `great_tit_boss.tres`:**
- **Stats:** HP 260; it flies.
- **Attacks:**
  - `MOVE` to a high perch (tree or cliff). Rest state `PERCHED`: vulnerable, full damage, `rest_hits` 2.
  - `MELEE_TARGET` "PECK_DIVE" on one caterpillar from above: 18 damage, knockback 160, dodge 90.
  - `GUST` "WING_FLAP": a 220 px radius, knockback 200.
- **Phase 2 (at 50 %):**
  - `SUMMON` 2 blue tits once.
  - PECK_DIVE on 2 targets.
- **Armour:** × 0.25 when not perched.

## View (BOSS-VIEW also handles the art the Cuca levels need)
- **Bigger caterpillars:** `larva_l3/l4/l5` use the caterpillar art, story style (no hats), sized by `art_scale`.
- **Great tit:** a variant of the bird art. Bigger, with a black head, white cheeks, a yellow belly with a black stripe and a greenish back.
- **Story map, Cuca stage:** opens after `larva_boss`; 6 nodes plus a boss node.
- **Texts:** `LVL_CUCA_1..6_*` and `LVL_CUCA_BOSS_*`, with real biology. L3 to L5 grow and get more urticating hairs; in autumn they build their silk nests; great tits are their main predator.

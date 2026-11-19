# Contracts: El Bolsó, nest defense and hub (phase C2, 2026-11-19)

**Design:** `docs/story_mode.md` §8, stage 4.

**Hard rules**
- Never commit.
- All tests pass.
- Classic matches unchanged.

## Ownership
| Agent | Owns |
|---|---|
| NEST-SIM | `combat/sim/**`, `data/types/**` (new types), `data/units/**`, `data/bosses/brigade*.tres`, `data/upgrades/**`, `data/levels/nest_*.tres`, `level_list.tres`, `core/story_progress.gd` (silk and upgrades), `core/game_state.gd` (upgrades into MatchConfig), `tests/test_nest_sim*` + scene, `docs/i18n_keys_nest_sim.md` |
| NEST-VIEW (later) | view, HUD, `ui/story/**` including the hub screen |

## 1. Nest defense (sim)
- **The nest** is a big silk structure placed on the map: a stamp with HP (e.g. 300), drawn by the view.
  - Explosions, pecks and the pole damage it.
  - Squad caterpillars inside its area are sheltered: −50 % damage, and no cold.
- **Repair:** a caterpillar next to the nest can spend its action on "REPAIR" (+40 HP, the silk ability), via `repair_nest()`. `PONT_PEDRA` builds walls as now.
- **Win rule `DEFEND_NEST`:** survive `survive_rounds` with nest HP > 0. The nest at 0 HP loses, and so does losing the whole squad.
- **Cold** (`LevelDef.cold`): at the start of its turn, a caterpillar outside the nest loses 5 HP ("FT_COLD"), unless the WARM_SILK upgrade is owned.
- **Pole hazard** (`LevelDef.pole`): every 2 rounds a forestry pole sweeps a marked vertical band (an intent-like warning one turn before). It hits caterpillars there and damages the nest if the nest is in the band.
- **Enemies:** great tits and blue tits that also target the nest (FLYER target choice includes the nest; they peck it).

## 2. Upgrades and silk (hub data)
- **`UpgradeDef`** (`data/types/upgrade_def.gd`): `id`, `name_key`, `desc_key`, `cost` (silk), `effect`. Effects:

| Effect | Bonus |
|---|---|
| MAX_HP_PCT | squad max HP +X% |
| DAMAGE_PCT | weapon damage +X% |
| NEST_HP | nest HP +X |
| WARM_SILK | no cold |
| EXTRA_SILK_WEB | 2 webs per turn |
| START_AMMO | +1 ammo for limited weapons |

  The shop now has 12 upgrades with tiers and a `scope`, plus the platform effects EXTRA_HEART, FAST_DIG and LONG_FLIGHT: see `docs/story_mode.md` section 9.
- **Silk (currency):** each star earned the first time gives 6 silk (`SILK_PER_STAR`).
- **`StoryProgress`:** `silk() -> int`, `owned_upgrades() -> Array[String]`, `buy(id) -> bool`, `refund_all()` (for tests and debugging). Saved in `story.cfg`; old saves must keep loading.
- **Matches:** `GameState.make_match_config()` puts the owned upgrades into `MatchConfig.upgrades: Array[String]`, and the sim applies them to story matches only.

## 3. Levels
| Id | Map | Squad | Enemies | Rule | Special | Unlocks / upgrade |
|---|---|---|---|---|---|---|
| nest_1 *Teixint el bolsó* | 6 pedraforca | 4 × L5 | 2 great tits | DEFEND_NEST, 4 rounds | tutorial: repair | PONT_PEDRA |
| nest_2 *Nit de glaçada* | 6 pedraforca | 4 × L5 | 2 great tits + 1 blue tit | DEFEND_NEST, 5 | cold | — |
| nest_3 *Mallerengues d'hivern* | 2 taull | 4 × L5 | 3 great tits + 2 blue tits | DEFEND_NEST, 5 | cold | AIRSTRIKE |
| nest_4 *La perxa* | 2 taull | 4 × L5 | 2 great tits | DEFEND_NEST, 5 | cold + pole | — |
| nest_boss *La Brigada Forestal* | 7 montblanc | 4 × L5 | boss | BOSS (nest must survive too) | cold | — |

Stage id: "NEST". Fixed seeds, checked.

## 4. Boss: La Brigada Forestal (`brigade_boss.tres`)
A comic forestry squad: a walking boss, the **Capatàs** (foreman).
- **Stats:** HP 300; armour × 0.5 except when "WINDED".
- **Attacks:**
  - `SUMMON` 2 forestry workers (walking melee units with a branch-cutting pole, low HP).
  - `LINE` "POLE_SWEEP": a new handler. A vertical band in front of it, telegraphed; it damages caterpillars and the nest.
  - `AREA` "CARTRIDGE": a nest-shooting cartridge, an area hit on the nest.
- **WINDED:** after 2 attacks it rests for one turn as "WINDED" (vulnerable).
- **Phase 2 (at 50 %):** faster, and a second summon.

Tone: affectionate. These are workers doing their job, a little clumsy.

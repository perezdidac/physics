# Boss framework (turn-based combat bosses), phase B2 (2026-11-19)

**Design:** `docs/story_mode.md` §2 and §8.
- **Turn-based bosses:** Mosca Taquina, Mallerenga, Brigada Forestal, Cucut, and later the ones of the special modes.
- **The wasp is a platformer boss** (`platform/`) and is not part of this framework.

**Hard rules**
- Never commit.
- All tests keep passing.
- Classic matches unchanged.

## 1. Ownership
| Agent | Owns |
|---|---|
| BOSS-SIM (Opus) | `combat/sim/boss/**` (new), hook calls in `combat/sim/*.gd`, `data/types/boss_def.gd` (new), `data/bosses/**`, `data/levels/larva_boss.tres` and its entry in `level_list.tres`, `tests/test_boss_sim*` + scene, `docs/i18n_keys_boss_sim.md` |
| BOSS-VIEW (Sonnet, later) | `combat/view/**`, `combat/hud/**`, `combat/combat_screen.gd`, `ui/story/**`, `tests/test_boss_view*` |

## 2. Core idea: intents
The game is turn-based, so the boss must be **fair and readable**: it shows its **intent** for its next action. The player gets one turn to react (move away, hide, prepare), then the boss acts.

**A boss turn:**
1. Execute the intent announced last turn.
2. Move or reposition.
3. Pick and announce the next intent.

Intent targets are a fighter or an area.

## 3. Data
**`BossDef`** (`data/types/boss_def.gd`, Resource):
- `id`, `name_key`, `title_key`, `max_hp`, `radius`, `art`
- `flies: bool`
- `phases: Array[float]`: HP fractions where the phase changes, e.g. [0.5].
- `attacks: Array[Dictionary]`, each with:
  - `id`, `phase` (−1 = any), `weight`
  - `kind` ("MELEE_TARGET", "AREA", "SUMMON", "STATUS", "GUST", "MOVE")
  - `damage`, `radius`, `status`, `turns`, `cooldown`
- `vulnerable_states: Array[String]`: states where it takes full damage; elsewhere damage × `armored_mult` (e.g. 0.25).

**`LevelDef`:**
- `boss: BossDef`
- `win_rule` "BOSS": win by defeating the boss. The other enemies don't count, but they may still hurt you.

## 4. Sim API (for the view)
**`CombatSim`:**
- `boss: SimFighter` (null if there is none); the boss is a fighter of team 1 with `kind == BossDef.id`.
- `boss_def: BossDef`.
- `boss_phase: int`.
- `boss_state: String` ("IDLE", "INTENT", "ACT", "RECOVER", "STUNNED", plus custom per boss).
- `boss_intent: Dictionary` (`{}` when none), with:
  - `attack_id`, `kind`
  - `target_id` (fighter id or −1), `pos: Vector2`, `radius`
  - `turns_left` (usually 1)
  - `label_key` (translated short text, e.g. "La Mosca vol pondre en la Fileta!")

**Signals:**
- `boss_changed()`: hp, phase or state.
- `boss_intent_changed()`
- `boss_attack(attack_id, pos)`
- `boss_phase_changed(phase)`
- `boss_defeated()`

**Status effects:** generic per fighter, `SimFighter.statuses: Dictionary` (status id → turns left).
- First status: "PARASITE". It does 6 damage at the start of each of that caterpillar's turns, for 3 turns.
- Spinning the silk web while parasitised cleans it: `spin_silk_web()` removes PARASITE from the active fighter, uses its action and shows `FT_CLEANED`.

**Turn order:** the boss acts in the enemy swarm turn (its own sub-turn), after the other critters.

**Damage:** explosions and melee on the boss use the vulnerability multiplier. A float text shows "ARMORED" / "BLINDAT" when the damage is reduced.

## 5. First boss: Mosca Taquina (`data/bosses/tachinid_fly.tres`, level `larva_boss`)
**Biology:** the tachinid fly *Phryxe caudata* lays eggs on processionary caterpillars, and its larvae eat them from inside. Playful version: it lays eggs on you, and your silk cleans them.

**Stats:** HP 180. It flies; it hovers high and out of reach most of the time.

**Phase 1 (above 50 % HP):**
- **Intent "LAY_EGGS":** marks a caterpillar. Next turn it dives at that caterpillar and applies PARASITE, plus 8 contact damage, unless the target moved more than 90 px away or hid. Then it **lands for one turn** (state "RESTING", vulnerable, full damage). That is the window to hit it hard.
- **Intent "BUZZ":** a gust that pushes every caterpillar within 200 px. It always comes with a "move away" warning.

**Phase 2 (at or below 50 % HP):**
- It summons 2 small flies (FLYER units with low HP and a PICOTADA-like bite) once.
- LAY_EGGS targets two caterpillars.
- Shorter rests.

Outside RESTING it is armored (× 0.25). It never drowns, but if it is knocked into the water it loses 20 HP and flies out.

**Level `larva_boss`:**
- Map 1 (cadaques), a fixed seed with a good open area.
- Squad: 3 × L2. Arsenal: URTICARIA plus the unlocked weapons; SILK_WEB.
- Rule BOSS. Add it to `level_list.tres` after `larva_5`.
- Stars by survivors.

**Tests:**
- Intent announced, then executed the next turn.
- Dodging by moving or hiding avoids it.
- PARASITE ticks, and silk cleans it.
- The armored multiplier, and the RESTING window.
- Phase change and summons.
- Defeat → win stats.
- A headless CPU run of `larva_boss` finishes (report the win rate).
- The framework is generic: a tiny second dummy boss defined only by data works in a test.

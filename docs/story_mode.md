# Story mode — plan (draft, 2026-11-18)

Status: **proposal**, being reviewed with the authors. Once approved, the decided parts move to `bible.md`.

## 1. Idea
A Worms-style campaign mixed with **survival**: you live the whole life cycle of one processionary brood. Each life stage changes *how you play*, not only the enemies. You start almost helpless (an egg that can only crawl and hide) and grow into a full fighter, unlocking weapons as you moult.

Every level opens with an **intro card**:
- the stage and an affectionate nickname for the hero,
- 2–3 sentences of what is happening in the real life of the caterpillar,
- what you must do to survive,
- one tip.

The hero of the brood is **Perleta** ("little pearl"). Her siblings change with each squad.

## 2. Stages (decided 2026-11-19: 30 levels + 7 bosses)
| # | Stage (real season) | Nickname | Levels | How you play | Boss (real predator) |
|---|---|---|---|---|---|
| 1 | **Egg** (July–August) | *Ouet* | 4 + boss | Real-time platformer: run, jump, hide, collect sap | **La Vespa** (parasitoid wasp) |
| 2 | **L1–L2** (September) | *Pelussa* | 5 + boss | Small turn-based fights, first weapons | **La Mosca Taquina** (tachinid fly) |
| 3 | **L3–L5** (October–November) | *Cuca* | 6 + boss | Full Worms; each moult opens weapons | **La Mallerenga** (great tit) |
| 4 | **Winter nest** (December–February) | *El Bolsó* | 4 + boss | Defend the silk nest against waves; nest = hub with upgrades | **La Brigada Forestal** (pole and nest-shooting) |
| 5 | **Procession** (March–April) | *La Processó* | 5 + boss | Convoy: move the line, protect the leader | **El Cucut** (cuckoo) |
| 6 | **Pupa** (May–June) | *La Crisàlide* | 3 + boss | Underground: dig galleries, escape | **La Puput** (hoopoe) |
| 7 | **Moth** (summer night) | *La Papallona* | 3 + final boss | Night flight | **El Ratpenat** (bat), then the cycle restarts |

A boss closes each **stage**, not each level: bosses stay special, and each one gets its own attacks, AI and art. Ordinary levels may end with a small final challenge instead.

## 3. Campaign structure
- **Main menu**: a new first entry, **STORY**.
- **Campaign map**: a path of level nodes grouped by stage (later on a map of Catalonia). Nodes show stars (0–3) and lock state.
- **Level intro card** → **Combat** → **Results** (win/lose, stars, what you unlocked) → back to the map.
- **Save**: progress (unlocked levels, stars, unlocks) in `user://story.cfg`.
- **Stars**, by default: 1 = level won, 2 and 3 = level-specific (e.g. all eggs alive).

## 4. The egg stage in detail (decided 2026-11-19)
The egg stage is a **real-time platformer**, not turn-based. The first turn-based test (3 eggs vs ants) was replaced; its code (hiding, ant swarm turns) is kept for the caterpillar stages.

**Rules shared by all egg levels:**
- You play **Perleta alone**. She runs, **jumps** (hold for a higher jump) and dodges.
- **Maps are hand-designed and simple:** an almost flat ground, a few platforms (giant pine needles), a couple of gaps and slopes. They are stored as data (`PlatformLayout`), not made by the random generator.
- **Ants patrol** with normal physics. They chase you when they see you and never walk off a ledge. If one touches you, you lose a heart and bounce back.
- **3 hearts.** With 0 hearts the level is lost. Falling into a pit costs a heart and puts you back at the last checkpoint.
- **Needle tufts** are safe zones: standing still inside one hides you and ants walk past.
- **Nutrients** (sap drops) are spread over the level. Collecting them makes Perleta grow a little; real eggs don't eat, this is a playful licence.
- **Goal:** reach the sunny spot at the end of the level, where Perleta hatches.
- **Stars:** 1 = goal reached, 2 = at least half of the nutrients, 3 = all the nutrients.

**Levels:**
1. **"July eggs"** / *Ous de juliol*: a short, gentle level with 1–2 slow ants, many tufts and one gap. It teaches moving, jumping and hiding.
2. **"The ant patrol"** / *La patrulla de les formigues*: longer, with more ants, some patrolling on platforms, and higher jumps.
3. **"Before the shell cracks"** / *Abans de trencar la closca*: the hardest. Narrow platforms, ants guarding the nutrients, two checkpoints. (The parasitoid wasp comes later.)

## 4b. Touch controls (decided 2026-11-19)
- **Platformer:** big ◀ ▶ buttons at bottom left and a big JUMP button at bottom right. Multi-touch, plus keyboard.
- **Combat (Worms):**
  - a floating joystick where the thumb lands, to move;
  - aim by dragging from the caterpillar;
  - a big fire button (hold to charge);
  - two-finger camera pan and pinch zoom.

## 4c. Map generation fixes (decided 2026-11-19, also for the classic match)
- **One shared placement registry:** objects (barrels, mines, mushrooms, flora, nests, tufts, crates) never overlap each other or stamped structures (trees, towers, girders).
- **Ants climb visibly** (or jump with an arc) instead of snapping up cliffs.
- **Map checker:** an automated test that generates many maps and reports overlapping, floating, buried or unreachable objects.

## 4d. Arena size (decided 2026-11-19)
Turn-based (COMBAT) levels no longer use the whole 3200 px terrain: it took too long to walk to the enemy. `LevelDef.arena_width` (px, 0 = the whole terrain) keeps only a span of it, centred on the terrain by default (`arena_center` moves it); the land outside is removed down to the water, so nobody can stand or fall there. At the story zoom (about 800 world px on a phone) an arena is 1.1 to 2.5 screens wide: larva 900-1200 (boss 1800), cuca 1200-1500 (boss 1900), El Bolsó 1600-2000, La Processó 2200 (convoy, goal near the right edge). Everything is placed inside the arena and the camera never shows more than 60 px beyond its edges. Classic matches are unchanged.

## 5. Technical plan
The combat stays one single screen. Story levels configure it through data:
- `data/types/unit_def.gd` (**UnitDef**): kind (CATERPILLAR, EGG, ANT…), HP, radius, speed multiplier, can jump, can hide.
- `data/types/level_def.gd` (**LevelDef**): stage, order, text keys (title, intro, goal, tip), map and seed, both squads, both arsenals, win rule (ELIMINATE / SURVIVE_ROUNDS + rounds), hiding spots, hazards on/off, turn time, star rules.
- `MatchConfig.level`: null for the classic modes, so they stay exactly as now (tests prove it).
- **Sim**:
  - per-fighter `kind` and `unit`, per-team arsenal, win rule, hiding,
  - a simple **melee AI** for animals (walk + bite) next to the existing caterpillar AI,
  - two new weapons, *Shove* (EMPENTA) and *Bite* (MOSSEGADA).
- **View**:
  - procedural egg and ant art (placeholders until the art pipeline is decided),
  - needle tufts,
  - "hidden" look,
  - an objective widget in the HUD,
  - the weapon bar showing only the team's arsenal.
- **UI**: STORY menu entry, campaign map screen, level intro card, results screen, `core/story_progress.gd` (save).

## 6. Art and Meshy
- The caterpillars stay procedural, as in the original.
- **Meshy AI** (account works, 1,500 credits):
  - Useful for **enemies and props as 3D models rendered to 2D sprites** in Godot (a SubViewport renders the model from the side, at build time).
  - Its auto-rigging and animation target humanoids. Ants, birds and beetles would get procedural motion in Godot (legs, wings), as we do with the caterpillars.
  - Proposed test: one ant model (~30 credits) → side sprite → compare with the procedural ant of the first test.
- Alternative for flat 2D art: hand-made or AI-generated 2D sprites.

## 7. Delivery order
1. **First test (now)**: STORY entry, campaign map with the egg stage, intro card, egg levels 1–2 playable, results, save.
2. Egg level 3 (wasp), stage L1–L2.
3. The winter-nest hub and upgrades; stages 3–7 one by one; balancing with CPU-vs-CPU headless runs.
4. Art pass (Meshy or 2D), map of Catalonia for the campaign path.

## 8. Campaign levels (planned 2026-11-19)
Ids follow `<stage>_<n>`; boss levels end in `_boss`. Backgrounds: existing keys or new ones from `docs/background_prompts.md`.
The **weapons** column is what the level unlocks for the following levels. The 16 original weapons are spread over the campaign.

### Stage 1 — Ou (platformer; Perleta alone)
| Id | Title (ca / en) | Goal and new idea | Enemies | Background |
|---|---|---|---|---|
| egg_1 | Ous de juliol / July eggs | Tutorial: move, jump, hide, sap drops, reach the sun | 2 ants | pinar_montseny |
| egg_2 | La patrulla de les formigues / The ant patrol | Longer level, platforms, first checkpoint | 6 ants | pinar_montseny |
| egg_3 | Abans de trencar la closca / Before the shell cracks | Narrow platforms, ants guarding the sap | 8 ants | pinar_montserrat_tempesta |
| egg_4 | La tempesta d'estiu / Summer storm | Wind gusts push you, falling raindrops knock you back, puddles to avoid | ants + storm | pinar_montserrat_tempesta |
| egg_boss | La Vespa / The wasp | Small arena. The wasp flies in patterns, warns, then dives to sting; hide in tufts and dodge until the timer runs out and you hatch | parasitoid wasp | pinar_montserrat_capvespre |

### Stage 2 — Pelussa (turn-based, squad of 3 tiny caterpillars; small arsenal)
Second pass (2026-11-19): small arenas (900-1200 px) with 2-3 enemies, a different goal per level and one twist each, 3-5 minutes per level. Rules: `docs/story_contracts.md` §7.
| Id | Title (ca / en) | Goal | Enemies | Arena | Twist | Weapons | Background |
|---|---|---|---|---|---|---|---|
| larva_1 | Germanes de seda / Silk sisters | ELIMINATE (combat tutorial: aim, charge, fire) | 2 ants | 900 | none | URTICARIA (start) | collserola_barcelona |
| larva_2 | El fil de seda / The silk thread | REACH: one caterpillar gets to the branch within 8 rounds (silk web allowed) | 2 ants | 1000 | strong wind (x1.6) | silk web | collserola_barcelona |
| larva_3 | El formiguer / The anthill | WAVES with a destructible anthill (90 HP): destroy it, or survive 3 rounds | waves of 2 ants | 1100 | 4 explosive barrels round the anthill | FUET | collserola_barcelona |
| larva_4 | La germana atrapada / The trapped sister | RESCUE: reach the cocoon within 8 rounds, the sister joins, level won | 2 ants + blue tit | 1100 | rising tide from round 3 | CARQUINYOLI | costa_brava_pins |
| larva_5 | Amaga't! / Hide and seek | SURVIVE_ROUNDS 4 with 4 needle tufts to hide in | 3 ants (they dig) | 1200 | 3 mines | BAT | costa_brava_pins |
| larva_boss | La Mosca Taquina / The tachinid fly | It flies and lays eggs on you (damage every turn until cleaned with silk); hit it in the air | tachinid fly | 1800 | | — | costa_brava_pins |

### Stage 3 — Cuca (full Worms; moults L3, L4, L5)
Same second pass: arenas grow from 1200 (cuca_1) to 1500 (cuca_6), at most 3 enemies, rules alternate.
| Id | Title (ca / en) | Goal | Enemies | Arena | Twist | Weapons | Background |
|---|---|---|---|---|---|---|---|
| cuca_1 | L3: la colla creix / L3: the gang grows | ELIMINATE; moult to L3, squad of 4 | 2 blue tits | 1200 | strong wind (x2) | BAZOOKA | siurana_tardor |
| cuca_2 | Pinyes de Poblet / Poblet pine cones | COLLECT: 4 of the 5 pine nuts on the map within 8 rounds | 2 ants + blue tit | 1300 | supply crates | GRENADE | poblet_tardor |
| cuca_3 | L4: pell nova / L4: new skin | ELIMINATE with a BARREL CHAIN: wine barrels in rows beside the enemies | 3 ants | 1300 | barrels | SHOTGUN | castellfollit |
| cuca_4 | El millor tret / The one good shot | ONE_SHOT: kill the sheltered, motionless ant with 3 bazooka + 1 grenade | 1 ant | 1400 | strong wind (x1.8) | GANXO | siurana_tardor |
| cuca_5 | L5: la gran muda / L5: the big moult | ELIMINATE | 2 great tits + blue tit | 1400 | 3 mines | CLUSTER | montblanc |
| cuca_6 | Tardor a la vila / Autumn in town | WAVES, 3 rounds (indestructible anthill) | great tit + waves of 2 ants | 1500 | rising tide from round 2 | DYNAMITE | poblet_tardor |
| cuca_boss | La Mallerenga / The great tit | Giant bird: lands on trees, pecks from above, flies away when hit; hit it while it perches | great tit | 1900 | | — | castellfollit |

### Stage 4 — El Bolsó (winter; defend the nest; the nest is the hub)
| Id | Title (ca / en) | Goal and new idea | Enemies | Weapons / upgrades | Background |
|---|---|---|---|---|---|
| nest_1 | Teixint el bolsó / Weaving the nest | Build and repair the nest (silk walls); first upgrades | great tits | PONT_PEDRA | cerdanya_neu |
| nest_2 | Nit de glaçada / Frost night | Cold: losing HP outside the nest; quick sorties | great tits | upgrade: warm silk | cerdanya_neu |
| nest_3 | Mallerengues d'hivern / Winter tits | Waves of birds pecking the nest | great tits + blue tits | AIRSTRIKE | cerdanya_neu |
| nest_4 | La perxa / The pole | A forestry pole knocks branches and nests (an environmental hazard) | birds + pole | upgrade: double nest | cardona_glacada |
| nest_boss | La Brigada Forestal / The forestry brigade | A comic forestry squad with a pole and nest-shooting cartridges; protect the nest until spring | forestry brigade | — | cardona_glacada |

### Stage 5 — La Processó (spring; convoy)
| Id | Title (ca / en) | Goal and new idea | Enemies | Weapons | Background |
|---|---|---|---|---|---|
| proc_1 | En fila índia / Single file | Convoy tutorial: the line follows the leader; reach soft soil | ants | convoy abilities | garrotxa_volcans |
| proc_2 | El senglar / The wild boar | A boar charges across the path; time the crossings | wild boar | — | garrotxa_volcans |
| proc_3 | El Calosoma / The Calosoma beetle | Fast caterpillar-hunting beetle (mini-boss) | Calosoma | HOLY | garrotxa_volcans |
| proc_4 | Pluja de primavera / Spring rain | Fungus spore clouds (*Beauveria*) hurt; go around them | fungus + ants | — | emporda_sant_pere |
| proc_5 | Terra tova / Soft soil | Long convoy to the burial ground, mixed enemies | mixed | — | emporda_sant_pere |
| proc_boss | El Cucut / The cuckoo | It eats hairy caterpillars: swoops on the line; keep the leader alive | cuckoo | — | emporda_sant_pere |

### Stage 6 — La Crisàlide (underground digging)
| Id | Title (ca / en) | Goal and new idea | Enemies | Weapons | Background |
|---|---|---|---|---|---|
| pupa_1 | Sota terra / Underground | Dig galleries with spoon and drill; reach a safe chamber | ants | CULLERA, BARRINA | sota_terra_pedraforca |
| pupa_2 | Les arrels / The roots | Root maze, falling stones | ants + stones | — | sota_terra_pedraforca |
| pupa_3 | Aiguats / Flood | Rain water floods the galleries from above; dig upwards in time | water | — | sota_terra_pedraforca |
| pupa_boss | La Puput / The hoopoe | Its long beak digs down from the surface where it hears you; stay still and dig away | hoopoe | — | sota_terra_pedraforca |

### Stage 7 — La Papallona (night flight)
| Id | Title (ca / en) | Goal and new idea | Enemies | Weapons | Background |
|---|---|---|---|---|---|
| moth_1 | Primer vol / First flight | Flight tutorial (jetpack-like) | — | JETPACK | montserrat_nit |
| moth_2 | Llums del poble / Village lights | Street lights attract you; pheromone traps to avoid | traps | — | montserrat_nit |
| moth_3 | L'enganyapastors / The nightjar | A nightjar chases you through the pines | nightjar | — | tossa_nit |
| moth_boss | El Ratpenat / The bat | Final boss: it finds you by echolocation pulses; hide in the shadows between pulses, then lay eggs: the cycle restarts (credits) | bat | — | tossa_nit |

### Weapon order (all 16 originals)
URTICARIA → FUET → CARQUINYOLI → BAT → BAZOOKA → GRENADE → SHOTGUN → GANXO → CLUSTER → DYNAMITE → PONT_PEDRA → AIRSTRIKE → HOLY → CULLERA → BARRINA → JETPACK. The silk web is an ability from L1.

### Build order
1. Egg stage complete: egg_4 + the wasp boss.
2. Pelussa (turn-based combat with levels) and its boss.
3. Cuca, then El Bolsó with the hub and upgrades.
4. La Processó, La Crisàlide, La Papallona: each one has a new way to play (convoy, digging, flight), so each one gets its own design pass before building.
5. Backgrounds from Gemini as they arrive.


## 9. Silk economy and the upgrade shop (2026-11-19, agent SILK)
**Rule:** silk is earned only from stars (each best star counts once): `SILK_PER_STAR = 6`. 37 levels x 3 stars x 6 = **666 silk at most**. The shop has **12 upgrades costing 600 in all**: with 3 stars everywhere you buy everything (66 spare); with about 2 stars on average (444 silk) you must choose (about 3 in 4 of the shop). Silk is derived from the stars (earned minus the price of the owned upgrades), so an id that disappears from the shop is refunded by itself, and a tier II whose tier I is missing in a save is dropped.

**When silk can be spent:** the hub (El Bolsó) opens from the story map and from the results screen as soon as one star has been earned (`StoryProgress.silk_earned() > 0`), not only in the NEST stage, so the platform upgrades matter from the egg stage on and the combat ones are ready for Pelussa. After the 5 egg levels a player has 30 silk with 1 star each (60 with 2, 90 with 3), and the cheapest upgrades cost 30 (Thick skin, Silk heart, Thick walls).

### Shop
| Id | Tier | Cost | Effect | Works in |
|---|---|---|---|---|
| EXTRA_HEART | I | 30 | +1 heart (4 in all) | Egg, pupa and moth levels |
| TOUGH_SKIN | I | 30 | squad max HP +15 % | Combat levels |
| THICK_WALLS | I | 30 | nest +100 HP | Nest levels |
| SHARP_HAIRS | I | 40 | weapon damage +15 % | Combat levels |
| FULL_POUCH | I | 40 | +1 ammo for limited weapons | Combat levels |
| WARM_SILK | I | 40 | no cold outside the nest | Nest levels |
| FAST_DIG | I | 45 | pupa digs 30 % faster | Egg, pupa and moth levels (DIG) |
| DOUBLE_WEB | I | 50 | two silk webs per turn | Combat levels |
| LONG_FLIGHT | I | 55 | moth glide sinks 50 % slower | Egg, pupa and moth levels (FLY) |
| TOUGH_SKIN_2 | II (needs TOUGH_SKIN) | 60 | another +15 % max HP | Combat levels |
| SHARP_HAIRS_2 | II (needs SHARP_HAIRS) | 90 | another +15 % damage | Combat levels |
| EXTRA_HEART_2 | II (needs EXTRA_HEART) | 90 | another +1 heart (5 in all) | Egg, pupa and moth levels |
| **Total** | | **600** | | |

Platform levels read the owned ids through `PlatformScreen.upgrades` into `PlatformSim.setup(level, ids)` (`platform/sim/platform_upgrades.gd`). Boss stars ignore bonus hearts (stars = hearts left minus the bonus), so extra hearts help survive but do not hand out stars. Combat levels get the ids in `MatchConfig.upgrades` as before. Each hub card says where it works (`UpgradeDef.scope`: COMBAT, NEST or PLATFORM) and tier II cards say what they need.

### Economy table
Silk is the total at the end of each stage (cumulative levels, so cumulative silk). The shop price column is what a player who bought in the order of the table above would have spent by then if they could afford it.

| Stage | Levels | Cumulative levels | Silk with 1 star / 2 stars / 3 stars | Shop prices of what is useful so far |
|---|---|---|---|---|
| Egg | 5 | 5 | 30 / 60 / 90 | EXTRA_HEART 30, EXTRA_HEART_2 90 |
| Pelussa | 6 | 11 | 66 / 132 / 198 | + TOUGH_SKIN 30, SHARP_HAIRS 40, FULL_POUCH 40, DOUBLE_WEB 50 (cumulative 280) |
| Cuca | 7 | 18 | 108 / 216 / 324 | + TOUGH_SKIN_2 60, SHARP_HAIRS_2 90 (cumulative 430) |
| El Bolsó | 5 | 23 | 138 / 276 / 414 | + THICK_WALLS 30, WARM_SILK 40 (cumulative 500) |
| La Processó | 6 | 29 | 174 / 348 / 522 | (combat upgrades keep paying off) |
| La Crisàlide | 4 | 33 | 198 / 396 / 594 | + FAST_DIG 45 (cumulative 545) |
| La Papallona | 4 | 37 | 222 / 444 / 666 | + LONG_FLIGHT 55 (cumulative 600) |

Reading it: by the end of the egg stage even a 1-star player can buy a heart; by the end of Pelussa a 2-star player (132) has the first combat upgrades; the 3-star player never lacks silk, the 2-star player ends 156 short of the full shop. `tests/test_nest_sim.gd` (`_economy`) keeps these numbers honest (shop total versus maximum silk, 2-star shortfall, first prices versus the egg stage).

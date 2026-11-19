# i18n keys created by the NEST-VIEW agent (El Bolsó in combat, the hub, the new story-map texts)

Format: `KEY | Catalan original | English proposal`. `%d` is a placeholder (formatted with `UiUtil.fmt`).
`HUD_OBJECTIVE_DEFEND*` and `HUD_OBJECTIVE_NEST` are the objective line of the top HUD (with the nest bar under it); `HUD_REPAIR*` the REPAIR button (key T).
`STORY_RULE_*` and `STORY_MODE_*` are the rule lines of the level card; `STORY_ENEMY_*` the enemy line of the digging and flying levels;
`STORY_REASON_*` the end reasons of the results screen (the nest ones are tried first on a NEST level, `DIG` / `FLY` ones first on those platform levels).
The level texts (`LVL_*`) of the stages 4, 6 and 7 are in `docs/i18n_keys_story_levels.md`.

KEY | Catalan original | English proposal
--- | --- | ---
HUD_OBJECTIVE_DEFEND | Resisteix %d torns · Bolsó %d/%d | Hold out %d turns · Nest %d/%d
HUD_OBJECTIVE_DEFEND_1 | Resisteix 1 torn · Bolsó %d/%d | Hold out 1 turn · Nest %d/%d
HUD_OBJECTIVE_NEST | Bolsó %d/%d | Nest %d/%d
HUD_REPAIR | Repara | Repair
HUD_REPAIR_TOOLTIP | Teixeix seda nova al bolsó (tecla T) | Weave new silk into the nest (T key)
HUD_SQUAD_FORESTRY_WORKER | Forestals | Foresters
STORY_BTN_NEST | El Bolsó · seda %d | El Bolsó · silk %d
STORY_BTN_HUB | Gasta la seda | Spend the silk
STORY_RESULT_SILK | Seda guanyada: +%d | Silk earned: +%d
STORY_LABEL_RULES | Regles especials | Special rules
STORY_RULE_DEFEND | Defensa el bolsó: aguanta %d torns sense que es quedi sense vida (%d punts). | Defend the nest: hold out for %d turns without it running out of HP (%d points).
STORY_RULE_NEST_BOSS | El bolsó també compta: si es queda sense vida (%d punts), has perdut. | The nest counts too: if it runs out of HP (%d points), you lose.
STORY_RULE_REPAIR | Repara: al costat del bolsó, el botó Repara (tecla T) gasta l'acció i li dona 40 punts de vida. Dins del bolsó els cops piquen la meitat. | Repair: next to the nest, the Repair button (T key) uses your action and gives it 40 HP. Blows hurt half as much inside the nest.
STORY_RULE_COLD | Fred: a l'inici del teu torn, si ets fora del bolsó perds vida. La millora Seda càlida ho evita. | Cold: at the start of your turn, if you are outside the nest you lose HP. The Warm silk upgrade stops it.
STORY_RULE_POLE | Perxa: una franja taronja marca on caurà la perxa un torn després. Fereix qui hi sigui i també el bolsó. | Pole: an orange band shows where the pole will come down one turn later. It hurts anyone in it, and the nest too.
STORY_MODE_DIG | Cava: mantén premuda una direcció contra la terra. Els túnels que fas són el teu camí. | Dig: hold a direction against the soil. The tunnels you make are your path.
STORY_MODE_FLY | Vol: cada toc de salt és un batec d'ales; si el mantens premut, planeges. | Flight: each tap of jump is a wing flap; hold it to glide.
STORY_ENEMY_HOOPOE | La puput | The hoopoe
STORY_ENEMY_BAT | El ratpenat | The bat
STORY_ENEMY_STONES | Pedres que cauen × %d | Falling stones × %d
STORY_ENEMY_WATER | Aigua que puja | Rising water
STORY_ENEMY_LAMPS | Fanals × %d | Street lamps × %d
STORY_ENEMY_TRAPS | Paranys de feromones × %d | Pheromone traps × %d
STORY_ENEMY_NIGHTJARS | Enganyapastors × %d | Nightjars × %d
STORY_REASON_NEST_SURVIVED | Has aguantat l'hivern i el bolsó segueix dempeus. | You made it through the winter and the nest is still standing.
STORY_REASON_NEST_DESTROYED | El bolsó s'ha esquinçat del tot. Torna-ho a provar! | The nest was torn to pieces. Try again!
STORY_REASON_METAMORPHOSIS | Has aguantat sota terra i la pupa s'ha transformat en papallona. Quina meravella! | You held out underground and the pupa turned into a moth. How wonderful!
STORY_REASON_EGGS_LAID | Has post els ous entre les agulles del pi. El cicle torna a començar! | You laid your eggs among the pine needles. The cycle starts again!
STORY_REASON_DIG_REACHED_GOAL | Has arribat a la cambra segura. Ara, a descansar! | You reached the safe chamber. Time to rest!
STORY_REASON_FLY_REACHED_GOAL | Has creuat la nit sencera sense cap ensurt. | You crossed the whole night without a scare.
STORY_STAGE_NEST_FACT | Les processionàries passen l'hivern en un bolsó de seda blanca, teixit a la banda assolellada del pi. De nit en surten a menjar agulles, i si fa massa fred es queden a dins. Les mallerengues els obren a cops de bec i els forestals els treuen amb una perxa. | Processionaries spend the winter in a white silk nest woven on the sunny side of the pine. At night they come out to eat needles, and if it is too cold they stay inside. Tits peck them open and foresters take them down with a pole.
STORY_STAGE_PUPA_FACT | A la primavera les erugues baixen del pi en processó, s'enterren a uns quants centímetres de terra i es fan un capoll. Hi passen mesos convertides en pupa, i algunes hi poden estar fins i tot uns quants anys abans de sortir. | In spring the caterpillars come down the pine in procession, bury themselves a few centimetres deep and spin a cocoon. They spend months there as pupae, and some can even stay for a few years before coming out.
STORY_STAGE_MOTH_FACT | A l'estiu, de nit, les papallones surten de terra. Són grises, no mengen i només viuen un dia o dos. Les femelles ponen els ous al voltant de dues agulles de pi i els tapen amb les escates del cos. | In summer, at night, the moths come out of the ground. They are grey, they do not eat and they live only a day or two. The females lay their eggs around two pine needles and cover them with scales from their bodies.
STORY_HERO_NEST | La Cuca i la colla, ben arrecerades | Cuca and her gang, snug together
STORY_HERO_PUPA | Perleta, ja pupa | Perleta, now a pupa
STORY_HERO_MOTH | Perleta, ara papallona | Perleta, a moth at last
BOSS_BRIGADE_FACT | A l'hivern els forestals treuen els bolsons dels pins tallant la branca amb una perxa llarga, perquè les erugues urticants fan mal a la gent. No tenen mala fe: només fan la seva feina. | In winter foresters take nests down from the pines by cutting the branch with a long pole, because the stinging caterpillars hurt people. They mean no harm: they are just doing their job.
BOSS_BRIGADE_ATTACKS | Crida els seus homes, balanceja la perxa sobre una franja marcada i dispara cartutxos al bolsó. Cada dos atacs es queda sense alè i s'asseu: és el moment de fer-li mal. | He calls his crew, swings the pole over a marked band and fires cartridges at the nest. After every two attacks he runs out of breath and sits down: that is the time to hit him.
NEST_HUB_TITLE | El Bolsó | El Bolsó
NEST_HUB_SUB | Gasta la seda en millores per a la colla i per al niu. | Spend your silk on upgrades for the gang and the nest.
NEST_HUB_SILK | Seda: %d | Silk: %d
NEST_HUB_COST | %d de seda | %d silk
NEST_HUB_BUY | Teixeix | Weave
NEST_HUB_NEED | Falta seda | Need silk
NEST_HUB_OWNED | Teixida | Woven
NEST_HUB_HINT | Cada estrella guanyada per primera vegada dona 6 de seda. Cada millora diu en quins nivells funciona. | Every star won for the first time gives 6 silk. Each upgrade says which levels it works in.

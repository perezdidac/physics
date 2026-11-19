# i18n keys created by the PROC-VIEW agent (La Processó: convoy HUD, boar warning, goal sign, level card rules, results)

Format: `KEY | Catalan original | English proposal`. `%d` is a placeholder (formatted with `UiUtil.fmt`).
`HUD_OBJECTIVE_CONVOY` and `HUD_MARCH` are the objective line and the march bar of the top HUD; `HUD_SQUAD_CONVOY` / `HUD_SQUAD_WILD_BOAR` / `HUD_SQUAD_CALOSOMA` the squad titles.
`PROC_*` are texts drawn in the world (the goal sign, the boar warning). `STORY_RULE_*` are rule lines of the level card (`ui/story/level_intro.gd`) and
`STORY_RESULT_FOLLOWERS` / `STORY_REASON_PROCESSION_*` the results screen (the stage ones are tried first on a PROCESSION level).
The level texts (`LVL_PROC_*`), `STORY_HERO_PROCESSION` and `STORY_STAGE_PROCESSION_FACT` are in `docs/i18n_keys_story_levels.md`.

KEY | Catalan original | English proposal
--- | --- | ---
HUD_OBJECTIVE_CONVOY | Arriba a la terra tova · Seguidors %d/%d | Reach the soft soil · Followers %d/%d
HUD_MARCH | Marxa %d px | March %d px
HUD_SQUAD_CONVOY | La Processó | The Procession
HUD_SQUAD_WILD_BOAR | El Senglar | The Wild Boar
HUD_SQUAD_CALOSOMA | El Calosoma | The Calosoma
PROC_GOAL_SIGN | Terra tova | Soft soil
PROC_BOAR_WARN | El senglar embesteix! | The boar charges!
PROC_BOAR_WARN_N | El senglar embestirà d'aquí a %d torns! | The boar charges in %d turns!
STORY_RULE_CONVOY | Processó: només controles la cap de fila; les altres la segueixen soles. Guanyes quan la cap de fila arriba a la terra tova i perds si cau. | Procession: you only control the leader; the others follow her by themselves. You win when the leader reaches the soft soil and lose if she falls.
STORY_RULE_MARCH | Marxa: cada torn pots caminar fins a %d px (la barra de dalt). | March: each turn you can walk up to %d px (the bar at the top).
STORY_RULE_LOST | Si un cop envia una seguidora a més de 120 px de la fila, es perd (el «?»): torna-hi a prop perquè s'hi afegeixi. Les perdudes no compten per a les estrelles. | If a blow sends a follower more than 120 px from the line she gets lost (the "?"): walk back near her so she rejoins. Lost ones do not count for the stars.
STORY_RULE_BOAR | Senglar: una franja taronja i una fletxa avisen un torn abans d'on embestirà. No es pot fer fora. | Wild boar: an orange band and an arrow warn you one turn before where it will charge. It cannot be chased off.
STORY_RULE_SPORES | Fong: els núvols verds fereixen qui hi sigui a l'inici del seu torn i es mouen cada ronda. | Fungus: the green clouds hurt whoever is inside at the start of their turn and drift every round.
STORY_RULE_MINI_BOSS | També guanyes si fas fora l'enemic gran d'aquest nivell. | You also win if you chase off the big enemy of this level.
STORY_RESULT_FOLLOWERS | Seguidors salvats: %d de %d | Followers saved: %d of %d
STORY_REASON_PROCESSION_GOAL_REACHED | La processó ha arribat a la terra tova. Ja podeu enterrar-vos! | The procession reached the soft soil. Time to bury yourselves!
STORY_REASON_PROCESSION_LOST | La cap de fila ha caigut i la processó s'ha perdut. Torna-ho a provar! | The leader fell and the procession was lost. Try again!
STORY_REASON_PROCESSION_ELIMINATED_ENEMY | Has fet fora l'enemic i el camí queda lliure. | You chased off the enemy and the way is clear.
STORY_REASON_PROCESSION_BOSS_DEFEATED | Has fet fora el cucut! La processó pot seguir tranquil·la. | You chased off the cuckoo! The procession can go on in peace.
STORY_REASON_GOAL_REACHED | La processó ha arribat a la terra tova. Ja podeu enterrar-vos! | The procession reached the soft soil. Time to bury yourselves!
BOSS_CUCKOO_FACT | El cucut (Cuculus canorus) és una de les poques aus que mengen erugues peludes com les processionàries: arriba a la primavera i les empassa senceres, pèls inclosos. | The cuckoo (Cuculus canorus) is one of the few birds that eat hairy caterpillars like the processionaries: it arrives in spring and swallows them whole, hairs and all.
BOSS_CUCKOO_ATTACKS | Avisa abans de cada atac: un cercle vermell marca la seguidora que s'abalançarà a menjar (dues a la segona fase) i el cop d'ales empeny la fila. Quan s'afarta, queda sadollat un torn: només llavors és vulnerable. | It warns before every attack: a red circle marks the follower it will swoop on (two in the second phase) and its wing flap pushes the file. When it has stuffed itself it sits sated for a turn: only then is it vulnerable.

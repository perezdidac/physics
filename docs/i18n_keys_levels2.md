# i18n keys of the second pass of the levels 6-17 (larva_1..5 and cuca_1..6): new goals, twists and rules

Format: `KEY | Catalan original | English proposal`. This table is read after all the others (see `tools/build_po.py`), so the `LVL_*` rows below replace the first-pass texts of `docs/i18n_keys_story_levels.md`.
Level goal texts may use `%d` (the round limit, `LevelDef.survive_rounds`) and the placeholders `{need}` (pine nuts to gather), `{total}` (pine nuts on the map), `{hp}` (HP of the anthill) and `{shots}` (shots of the arsenal): see `StoryUi.level_text`.
`FT_*` are floating texts of the sim, `HUD_OBJECTIVE_*` the objective line of the top HUD, `STORY_RULE_*` the rule lines of the level card, `STORY_REASON_*` the end reason of the results screen.

KEY | Catalan | English
--- | --- | ---
LVL_LARVA_1_INTRO | A finals d'estiu les larves neixen totes juntes i es queden unides, com una colla de germanes. Sou petites, clares i molt peludes: els vostres primers pèls encara són de broma, però ja teixiu seda. Dues formigues curioses se us acosten al fons de la vall. | At the end of summer the larvae hatch all together and stay close, like a gang of sisters. You are small, pale and very hairy: your first hairs are still a joke, but you already spin silk. Two curious ants are coming your way along the valley.
LVL_LARVA_2_TITLE | El fil de seda | The silk thread
LVL_LARVA_2_INTRO | Allà dalt, a la punta d'una branca, hi ha les agulles més tendres del pi, i per arribar-hi cal travessar buits i pujar costers. Per sort ja sabeu teixir fil de seda! Dues formigues us segueixen i us piquen els talons. | Up there, at the tip of a branch, grow the tenderest needles of the pine, and to reach them you have to cross gaps and climb slopes. Luckily you can spin silk by now! Two ants follow you and nip at your heels.
LVL_LARVA_2_GOAL | Porta una cuca fins a la branca abans de %d rondes. | Get one caterpillar to the branch within %d rounds.
LVL_LARVA_2_TIP | Amb una sola cuca a la branca ja has guanyat: no cal lluitar, corre! El vent fa saltar els trets, així que millor teixir un fil de seda per amortir una caiguda o travessar un buit. | One caterpillar on the branch is enough to win: no need to fight, just run! The wind throws your shots off, so better spin a silk thread to soften a fall or cross a gap.
LVL_LARVA_3_TITLE | El formiguer | The anthill
LVL_LARVA_3_INTRO | Sota els pins hi ha un formiguer, i les formigues en surten a onades. Si en rebentes la cúpula, s'acabaran les onades! Al voltant hi ha uns barrils de vi del Priorat que no tenen gens de paciència: petarden a la mínima. | Under the pines there is an anthill, and ants pour out of it in waves. If you blow its dome apart, the waves stop! Around it stand a few Priorat wine barrels with no patience at all: they blow up at the slightest bump.
LVL_LARVA_3_GOAL | Destrueix el formiguer ({hp} punts de vida) o aguanta %d rondes. A cada ronda en surten dues formigues. | Destroy the anthill ({hp} HP) or hold out for %d rounds. Two new ants come out every round.
LVL_LARVA_3_TIP | Dispara a la cúpula del formiguer: la barra de dalt en mostra la vida. Els barrils fan molt més mal que un tret, i aparta't de la boca quan surti una onada. | Shoot the dome of the anthill: the bar at the top shows its health. The barrels hurt far more than a shot, and step away from the mouth when a wave comes out.
LVL_LARVA_4_TITLE | La germana atrapada | The trapped sister
LVL_LARVA_4_INTRO | Heu mudat la pell per primer cop: ara sou larves de segon estadi, més grans i més fortes. Però una germana ha quedat embolicada en un capoll de seda, allà al fons, i us crida! Dues formigues i una mallerenga blava us volen aigualir el rescat, i l'aigua puja. | You have moulted for the first time: now you are second-stage larvae, bigger and stronger. But a sister got wrapped up in a silk cocoon far away, and she is calling you! Two ants and a blue tit want to spoil the rescue, and the water is rising.
LVL_LARVA_4_GOAL | Arriba fins a la germana del capoll abans de %d rondes: s'afegirà a la colla. | Reach your sister in the cocoon within %d rounds: she joins the gang.
LVL_LARVA_4_TIP | La marea puja a poc a poc: no et quedis als llocs baixos. La mallerenga s'atura a l'aire i mostra un «!» abans de llançar-se: aparta't. | The tide rises slowly: do not linger on low ground. The blue tit stops in mid-air and shows a "!" before it dives: step aside.
LVL_LARVA_5_TITLE | Amaga't! | Hide and seek!
LVL_LARVA_5_INTRO | Les formigues us busquen amb l'olfacte, i són capaces de cavar per dins de la paret per atrapar-vos. Només us pot salvar una mata d'agulles de pi: si t'hi amagues, no et veuran fins que se t'acostin molt. Compte amb les mines: no fan distincions! | The ants hunt you by smell, and they can dig through the walls to catch you. Only a tuft of pine needles can save you: hide in it and they will not see you until they get really close. Watch out for the mines: they play no favourites!
LVL_LARVA_5_GOAL | Sobreviu %d rondes: amaga't a les mates d'agulles. | Survive %d rounds: hide in the needle tufts.
LVL_LARVA_5_TIP | Acaba el torn sobre una mata i t'amagaràs: s'ha acabat el joc si una formiga hi para a prop. Una mina pot fer volar també les formigues. | End your turn on a tuft and you hide: the game is up if an ant stops nearby. A mine can blow up the ants too.
LVL_CUCA_1_INTRO | Heu tornat a mudar la pell: ara sou larves de tercer estadi, més grosses i amb els primers pèls urticants de debò. La colla també ha crescut: sou quatre! Dues mallerengues blaves ja us han vist des de dalt, i fa un vent que gairebé tomba els pins. | You have moulted again: now you are third-stage larvae, bigger and with your first truly stinging hairs. The gang has grown too: there are four of you! Two blue tits have already spotted you from above, and the wind is so strong it nearly knocks the pines over.
LVL_CUCA_1_GOAL | Fes fora les dues mallerengues blaves. | Drive off the two blue tits.
LVL_CUCA_1_TIP | Vent molt fort: els trets es desvien un munt. Mira l'indicador de dalt i corregeix l'angle. Canvia de cuca amb el tabulador o tocant-ne una, i busca la que té el millor tret. | Very strong wind: your shots drift a lot. Look at the indicator at the top and correct your angle. Switch caterpillar with Tab or by tapping one, and find the one with the best shot.
LVL_CUCA_2_INTRO | Al bosc del monestir de Poblet cauen pinyes i pinyons per tot arreu, i del cel baixen caixes de provisions. Cal fer-ne reserva per a l'hivern! Dues formigues i una mallerenga blava hi volen fer cap també. | In the forest of the Poblet monastery pine cones and pine nuts fall everywhere, and supply crates drop from the sky. You must store up for the winter! Two ants and a blue tit want their share too.
LVL_CUCA_2_GOAL | Recull {need} pinyons dels {total} que hi ha al mapa abans de %d rondes. | Gather {need} of the {total} pine nuts on the map within %d rounds.
LVL_CUCA_2_TIP | Els pinyons brillen amb un anell daurat i només els pots recollir tu. No te'ls deixis per al final, i agafa les caixes que cauen: porten armes i vida. | The pine nuts glow with a golden ring and only you can pick them up. Do not leave them for the end, and grab the crates that fall: they carry weapons and health.
LVL_CUCA_3_TITLE | L4: pell nova | L4: new skin
LVL_CUCA_3_INTRO | Una altra muda, i ja sou de quart estadi: pell nova, més pèls i més força. Tres formigues s'han instal·lat vora uns barrils de vi del Priorat i us esperen amb cara de no haver trencat mai un plat. | Another moult, and now you are fourth-stage larvae: new skin, more hairs and more strength. Three ants have settled next to some Priorat wine barrels and wait for you looking like they never broke a plate.
LVL_CUCA_3_GOAL | Fes fora les tres formigues: aprofita els barrils! | Drive off the three ants: use the barrels!
LVL_CUCA_3_TIP | Un tret a un barril fa petar els veïns: encadena tota una fila! Ara tens bazuca i granada; les explosions fan forats al terra, vigila on poses els peus. | One shot at a barrel sets off its neighbours: chain a whole row! You have the bazooka and the grenade now; explosions dig holes in the ground, so watch your step.
LVL_CUCA_4_TITLE | El millor tret | The one good shot
LVL_CUCA_4_INTRO | Una formiga s'ha ficat darrere d'un cingle i no es mou d'allà. Només us queden unes poques municions de bazuca i una granada, i ja no n'hi ha més. Amb el sol baix, el vent no us ho posa fàcil. | An ant has dug in behind a cliff and will not move. You only have a few bazooka rounds and one grenade left, and there is no more. With the sun low, the wind is not making it easy.
LVL_CUCA_4_GOAL | Elimina la formiga amagada amb els {shots} trets que tens: no te'n queden més. | Take out the hidden ant with the {shots} shots you have: there are no more.
LVL_CUCA_4_TIP | La bazuca vola en arc: puja l'angle per passar per sobre del cingle. Camina per trobar un lloc millor abans de disparar i compta amb el vent. | The bazooka flies in an arc: raise the angle to clear the cliff. Walk to a better spot before you shoot, and allow for the wind.
LVL_CUCA_5_INTRO | L'última muda! Ara sou de cinquè estadi, les erugues més grosses i peludes de tot el cicle. Dues mallerengues carboneres i una de blava us vigilen, i el camí està sembrat de mines que no són gens amigues vostres. | The last moult! Now you are fifth-stage larvae, the biggest and hairiest caterpillars of the whole cycle. Two great tits and a blue one are watching you, and the path is dotted with mines that are no friends of yours.
LVL_CUCA_5_GOAL | Elimina les dues mallerengues carboneres i la blava. | Defeat the two great tits and the blue one.
LVL_CUCA_5_TIP | Les mines peten quan algú s'hi acosta: no hi passis i fes-hi caure els enemics. Fes servir el ganxo per canviar de lloc, i cada cuca compta: no en perdis cap! | Mines go off when someone comes near: stay away from them and make the enemies walk into them. Use the grapple to change places, and every caterpillar counts: do not lose any!
LVL_CUCA_6_INTRO | A finals de tardor les erugues s'acosten a les cases, perquè els pins dels jardins també els agraden. Una carbonera us vigila i el formiguer no para: les primeres pluges fan pujar l'aigua. Cal aguantar fins que arribi el fred. | At the end of autumn the caterpillars come close to the houses, because the pines in the gardens are tasty too. A great tit is watching you and the anthill never stops: the first rains make the water rise. Hold out until the cold arrives.
LVL_CUCA_6_GOAL | Aguanta %d rondes. A cada ronda surten dues formigues noves del formiguer. | Hold out for %d rounds. Two new ants come out of the anthill every round.
LVL_CUCA_6_TIP | L'aigua puja des de la segona ronda: busca terreny alt. Els ocells ataquen per l'aire i les formigues per terra: no et deixis encerclar. El clúster va molt bé contra una colla. | The water rises from the second round: look for high ground. The birds attack from the air and the ants on the ground: do not let them surround you. The cluster bomb works well against a crowd.
HUD_OBJECTIVE_REACH | Arriba a la branca | Reach the branch
HUD_OBJECTIVE_RESCUE | Salva la germana | Rescue your sister
HUD_OBJECTIVE_COLLECT | Pinyons: %d/%d | Pine nuts: %d/%d
HUD_OBJECTIVE_AMMO | Munició: %d | Ammo: %d
HUD_OBJECTIVE_HIDE | Amaga't · Rondes: %d | Hide · Rounds: %d
HUD_OBJECTIVE_HIDE_1 | Amaga't · Última ronda | Hide · Last round
HUD_OBJECTIVE_ANTHILL | Formiguer: %d%% · Onades: %d | Anthill: %d%% · Waves: %d
HUD_OBJECTIVE_TURNS_LEFT | · Torns: %d | · Rounds: %d
GOAL_BRANCH_SIGN | Branca | Branch
FT_BRANCH_REACHED | Has arribat a la branca! | You reached the branch!
FT_SISTER_FREED | %s s'ha alliberat! | %s is free!
FT_SISTER_SAFE | La colla torna a ser sencera! | The gang is whole again!
FT_ANTHILL_HIT | Formiguer -%d | Anthill -%d
FT_ANTHILL_DOWN | El formiguer s'ensorra! | The anthill collapses!
FT_NUT_COLLECTED | Pinyó %d/%d | Pine nut %d/%d
FT_NUTS_DONE | Magatzem ple! | Storeroom full!
FT_NUTS_LOST | S'han perdut massa pinyons | Too many pine nuts are lost
FT_OUT_OF_AMMO | No queden trets! | No shots left!
FT_TIME_UP | Se us ha acabat el temps! | You ran out of time!
STORY_REASON_REACHED | Una cuca ha arribat a la branca. Quin cim! | A caterpillar reached the branch. What a view!
STORY_REASON_RESCUED | La germana ja és amb vosaltres. La colla torna a ser sencera! | Your sister is with you. The gang is whole again!
STORY_REASON_ANTHILL_DESTROYED | Heu rebentat el formiguer: no en sortiran més formigues! | You blew up the anthill: no more ants will come out!
STORY_REASON_COLLECTED | Heu recollit prou pinyons per a l'hivern. | You gathered enough pine nuts for the winter.
STORY_REASON_TIME_UP | S'ha acabat el temps abans d'arribar-hi. Torna-ho a provar! | Time ran out before you made it. Try again!
STORY_REASON_OUT_OF_AMMO | Ja no teniu trets i la formiga encara hi és. Torna-ho a provar! | You have no shots left and the ant is still there. Try again!
STORY_REASON_NUTS_LOST | S'han perdut massa pinyons per arribar a la quantitat. Torna-ho a provar! | Too many pine nuts were lost to reach the amount. Try again!
STORY_RULE_REACH | Branca: guanyes quan una sola cuca hi arriba. Tens %d rondes; el fil de seda amorteix les caigudes i fa de pont. | Branch: you win when a single caterpillar gets there. You have %d rounds; silk softens falls and bridges gaps.
STORY_RULE_RESCUE | Rescat: quan una cuca toqui el capoll de la germana, s'afegirà a la colla i guanyaràs. Tens %d rondes. | Rescue: when a caterpillar touches your sister's cocoon she joins the gang and you win. You have %d rounds.
STORY_RULE_COLLECT | Pinyons: n'hi ha %d pel mapa i en necessites %d, en %d rondes. Els enemics no els poden recollir. | Pine nuts: there are %d on the map and you need %d, within %d rounds. Enemies cannot pick them up.
STORY_RULE_ONE_SHOT | Un sol tret: l'enemic està protegit pel terreny i no es mou. Si us quedeu sense trets i encara és viu, perds. | One good shot: the enemy is sheltered by the terrain and does not move. If you run out of shots while it is alive, you lose.
STORY_RULE_ANTHILL | Formiguer: té %d punts de vida. Les explosions el ferixen i, si arriba a 0, guanyes de seguida. | Anthill: it has %d HP. Explosions hurt it, and at 0 you win at once.
STORY_RULE_BARRELS_ANTHILL | Barrils: n'hi ha %d vora el formiguer. Una explosió propera els fa petar i ferir-lo. | Barrels: there are %d next to the anthill. A nearby blast sets them off and hurts it.
STORY_RULE_BARRELS | Barrils: n'hi ha %d vora els enemics. Si en peta un, encadena els veïns. | Barrels: there are %d next to the enemies. When one blows up it sets off its neighbours.
STORY_RULE_MINES | Mines: n'hi ha %d pel camí. Peten quan algú s'hi acosta, també els enemics. | Mines: there are %d on the way. They go off when anyone comes close, enemies included.
STORY_RULE_WIND | Vent fort: el vent és un %d %% més fort del normal i desvia els trets. | Strong wind: the wind is %d %% stronger than usual and throws your shots off.
STORY_RULE_TIDE | Marea: l'aigua puja cada ronda a partir de la ronda %d. | Tide: the water rises every round from round %d on.
STORY_RULE_SUPPLY | Subministraments: del cel cauen caixes amb armes i vida. | Supplies: crates with weapons and health drop from the sky.
STORY_RULE_HIDE | Amagatalls: acaba el torn sobre una mata d'agulles i t'amagaràs. Una formiga que s'hi aturi a prop et descobreix. | Hiding: end your turn on a needle tuft and you hide. An ant that stops close by finds you.

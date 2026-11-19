# i18n keys of the stage card (how each life stage plays)

Format: `KEY | Catalan | English`. Used in `ui/story/stage_card.gd`: shown the first time a level of a stage is opened, and again from the "?" button of the story map. Per stage `X` (EGG, LARVA_EARLY, LARVA, NEST, PROCESSION, PUPA, MOTH): `_KIND` (what kind of game), `_GOAL`, `_TIP1`-`_TIP3` and `_KEYS` (the keyboard line). The labels of the round buttons reuse the real touch-button keys (`PLAT_JUMP`, `PLAT_FLAP`, `HUD_JUMP`, `HUD_FLIP`, `TOUCH_AIM_BUTTON`, `FIRE_DEFAULT`, `HUD_PASS`, `HUD_SWITCH_WORM`, `HUD_REPAIR`).

KEY | Catalan | English
--- | --- | ---
STAGECARD_KICKER | Com es juga | How to play
STAGECARD_LABEL_GOAL | L'objectiu | The goal
STAGECARD_LABEL_CONTROLS | Controls | Controls
STAGECARD_LABEL_KEYS | Teclat | Keyboard
STAGECARD_LABEL_TIPS | Consells | Tips
STAGECARD_BTN_OK | Entesos! | Got it!
STAGECARD_HELP_TOOLTIP | Com es juga aquesta etapa | How this stage is played
STAGECARD_CAP_MOVE | Camina | Walk
STAGECARD_CAP_RUN | Corre | Run
STAGECARD_CAP_JUMP | Salta | Jump
STAGECARD_CAP_JUMP_FWD | Salta endavant | Jump ahead
STAGECARD_CAP_FLIP | Salt enrere | Backflip
STAGECARD_CAP_AIM | Passa a apuntar | Switch to aiming
STAGECARD_CAP_FIRE | Mantén i solta | Hold, then release
STAGECARD_CAP_PASS | Acaba el torn | End your turn
STAGECARD_CAP_SWITCH | Canvia de cuca | Next caterpillar
STAGECARD_CAP_REPAIR | Adoba el bolsó | Mend the nest
STAGECARD_CAP_MARCH | Marxa | March
STAGECARD_CAP_DIG | Mantén per cavar | Hold to dig
STAGECARD_CAP_HOP | Un saltet | A little hop
STAGECARD_CAP_STEER | Dirigeix | Steer
STAGECARD_CAP_FLAP | Batec; mantén per planar | Flap; hold to glide
STAGECARD_EGG_KIND | Plataformes en temps real | Real-time platformer
STAGECARD_EGG_GOAL | Arriba al racó de sol abans que les formigues t'atrapin. | Reach the sunny spot before the ants catch you.
STAGECARD_EGG_TIP1 | Amaga't dins d'una mata d'agulles: si et quedes quieta, les formigues no et veuen. | Hide in a needle tuft: stay still and the ants cannot see you.
STAGECARD_EGG_TIP2 | Recull gotes de saba pel camí: et fan créixer una mica. | Pick up sap drops on the way: they make you grow a little.
STAGECARD_EGG_TIP3 | Salta damunt d'una formiga i la deixaràs noquejada! | Jump on an ant and you knock it out!
STAGECARD_EGG_KEYS | Fletxes o A/D: córrer · Espai: saltar (mantén-lo per saltar més amunt) | Arrows or A/D: run · Space: jump (hold it to jump higher)
STAGECARD_LARVA_EARLY_KIND | Combat per torns | Turn-based battle
STAGECARD_LARVA_EARLY_GOAL | Cada nivell té el seu repte: fer fora formigues, arribar a una branca, rescatar una germana... | Every level has its own challenge: drive off ants, reach a branch, rescue a sister...
STAGECARD_LARVA_EARLY_TIP1 | Al teu torn, mou-te (Salt o Mortal per passar obstacles) i després prem Apunta. | On your turn, move (Jump or Backflip to cross obstacles), then tap Aim.
STAGECARD_LARVA_EARLY_TIP2 | Tria una arma, arrossega per apuntar i mantén FOC per carregar la força. Deixa anar per disparar! | Pick a weapon, drag to aim and hold FIRE to charge the power. Let go to shoot!
STAGECARD_LARVA_EARLY_TIP3 | El vent corba els trets. Passa acaba el torn, i Cuc ⇄ canvia de cuca. | The wind bends your shots. Pass ends your turn, and Caterpillar ⇄ switches caterpillar.
STAGECARD_LARVA_EARLY_KEYS | Fletxes: caminar i apuntar · Intro: salt · Retrocés: mortal · Espai (mantén): foc · Tab: canvia de cuca · N: passa | Arrows: walk and aim · Enter: jump · Backspace: backflip · Space (hold): fire · Tab: next caterpillar · N: pass
STAGECARD_LARVA_KIND | Combat per torns, més dur | Turn-based battle, tougher
STAGECARD_LARVA_GOAL | Fes fora els enemics, recull pinyons, encerta un sol tret o fes petar barrils... Al final t'espera la Mallerenga. | Drive off the enemies, gather pine nuts, land one good shot or blow up barrels... The Great Tit waits at the end.
STAGECARD_LARVA_TIP1 | Els mateixos controls de sempre, però amb pèls més urticants i armes noves. | The same controls as before, but with stingier hairs and new weapons.
STAGECARD_LARVA_TIP2 | Els ocells ataquen des del cel: s'aturen a l'aire abans de llançar-se. Aprofita-ho! | Birds attack from the sky: they hover for a moment before swooping. Use it!
STAGECARD_LARVA_TIP3 | Sou una colla: canvia de cuca i tria la que té el millor tret. | You are a gang: switch caterpillar and pick the one with the best shot.
STAGECARD_LARVA_KEYS | Fletxes: caminar i apuntar · Intro: salt · Retrocés: mortal · Espai (mantén): foc · Tab: canvia de cuca · N: passa | Arrows: walk and aim · Enter: jump · Backspace: backflip · Space (hold): fire · Tab: next caterpillar · N: pass
STAGECARD_NEST_KIND | Defensa del bolsó per torns | Turn-based nest defence
STAGECARD_NEST_GOAL | Protegeix el bolsó de seda: si es queda sense vida, has perdut. Al final, fes fora el Capatàs. | Keep the silk nest standing: if its HP runs out, you lose. At the end, send the Foreman away.
STAGECARD_NEST_TIP1 | Posa't al costat del bolsó i prem Repara: gasta l'acció i li dona vida. Dins del bolsó els cops piquen la meitat. | Stand next to the nest and tap Repair: it uses your action and gives it HP. Inside, blows hurt half as much.
STAGECARD_NEST_TIP2 | Fa fred! Fora del bolsó perds vida, tret que tinguis la millora Seda càlida. | It is cold! Outside the nest you lose HP, unless you own the Warm silk upgrade.
STAGECARD_NEST_TIP3 | La perxa dels forestals fereix una franja: una banda taronja avisa on caurà, un torn abans. | The foresters' pole hits a band: an orange stripe shows where it will land, one turn ahead.
STAGECARD_NEST_KEYS | Fletxes: caminar i apuntar · Intro: salt · Espai (mantén): foc · T: repara · Tab: canvia de cuca · N: passa | Arrows: walk and aim · Enter: jump · Space (hold): fire · T: repair · Tab: next caterpillar · N: pass
STAGECARD_PROCESSION_KIND | Marxa per torns, en fila | Turn-based march in a line
STAGECARD_PROCESSION_GOAL | Porta la cap de fila fins a la terra tova per enterrar-vos: allà guanyes. | Lead the front caterpillar to the soft soil to bury yourselves: you win there.
STAGECARD_PROCESSION_TIP1 | Només controles la cap de fila: les altres segueixen el seu fil de seda. | You only control the leader: the others follow her silk thread.
STAGECARD_PROCESSION_TIP2 | Cada torn pots caminar fins on diu la barra de dalt. Si una seguidora queda massa lluny, es perd: torna-hi a prop! | Each turn you can walk as far as the bar on top shows. A follower left too far behind gets lost: walk back near her!
STAGECARD_PROCESSION_TIP3 | Vigila el senglar, els núvols de fong i el calosoma. | Watch out for the boar, the fungus clouds and the calosoma.
STAGECARD_PROCESSION_KEYS | Fletxes: caminar · Intro: salt · Espai (mantén): foc · C: fil de seda · N: passa | Arrows: walk · Enter: jump · Space (hold): fire · C: silk thread · N: pass
STAGECARD_PUPA_KIND | Plataformes sota terra: cavar | Underground platformer: digging
STAGECARD_PUPA_GOAL | Cava el teu camí fins a la cambra segura. | Dig your way to the safe chamber.
STAGECARD_PUPA_TIP1 | Mantén una fletxa contra la terra: els túnels que fas són el teu camí. | Hold an arrow against the soil: the tunnels you dig are your path.
STAGECARD_PUPA_TIP2 | Les pedres cauen quan caves la terra que tenen sota: no hi passis per sota! | Stones fall when you dig the soil under them: do not walk under them!
STAGECARD_PUPA_TIP3 | Cavar fa soroll i la puput t'escolta: quieta no et sent. Si puja l'aigua, no t'aturis! | Digging is noisy and the hoopoe listens: stay still and it will not hear you. If water rises, keep moving!
STAGECARD_PUPA_KEYS | Fletxes o WASD: cavar · Espai: un saltet | Arrows or WASD: dig · Space: a little hop
STAGECARD_MOTH_KIND | Plataformes: vol de nit | Night-flight platformer
STAGECARD_MOTH_GOAL | Vola fins al final del camí, esquivant fanals, paranys i enganyapastors. | Fly to the end of the way, dodging lamps, traps and nightjars.
STAGECARD_MOTH_TIP1 | Cada toc de BATEC és un cop d'ales. Si el mantens premut, planeges i caus més a poc a poc. | Each tap of FLAP is a wing beat. Hold it down to glide and fall more slowly.
STAGECARD_MOTH_TIP2 | Els fanals t'atreuen: bat les ales en sentit contrari. Un parany et fa tornar a l'última bandera. | Lamps pull you in: flap the other way. A trap sends you back to the last flag.
STAGECARD_MOTH_TIP3 | Amaga't a les ombres: a dins no et veuen. | Hide in the shadows: nobody can see you inside.
STAGECARD_MOTH_KEYS | Fletxes: dirigir-te · Espai: batec (mantén-lo per planar) | Arrows: steer · Space: flap (hold it to glide)

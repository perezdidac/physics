# i18n keys created by the SIM agent

Format: `KEY | Catalan original | English proposal`. `%s` is a placeholder (use `%%` for a literal percent when the key takes arguments; `FT_CASTELL` takes none, so its `%` is literal). The sim formats with `tr(KEY) % args`; if a translation is missing it falls back to `KEY arg1 arg2`.
Names of caterpillars (`SimTables.NAMES_POOL_*`) are proper nouns and stay untranslated data.
Victory/turn-status/HUD strings are not produced by the sim (the game_over signal carries the numbers; map names via `MAP_*_NAME` keys).

KEY | Catalan original | English proposal
--- | --- | ---
FT_TURN_SWITCH | ¡TORN DE %s! [TAB] | TURN OF %s! [TAB]
FT_GUST_RIGHT | ¡RÀFEGA DE TRAMUNTANA! » | TRAMUNTANA GUST! »
FT_GUST_LEFT | « ¡VENT DE GARBÍ! | « GARBÍ WIND!
FT_TIDE | ¡MORT SOBTADA — PUJA LA MAREA! | SUDDEN DEATH — THE TIDE RISES!
FT_NEST_BURST | ¡BOSSA DE SEDA REBENTADA! +PINYONS I LARVES! | SILK NEST BURST! +PINE NUTS AND LARVAE!
FT_WEB_SPUN | ¡SEDA ELÀSTICA TEIXIDA! | ELASTIC SILK WOVEN!
FT_METAMORPHOSIS | ¡%s: METAMORFOSI ALADA! (MANTÉN W PER PLANAR) | %s: WINGED METAMORPHOSIS! (HOLD W TO GLIDE)
FT_ROVELLO_ROASTED | ¡ROVELLÓ A LA BRASA! | GRILLED MUSHROOM!
FT_WINE_SPLASH | ¡XOP DE VI DEL PRIORAT! | PRIORAT WINE SOAKING!
FT_ESCUDELLA_EXPLODE | ¡ESCUDELLA EXPLOSIVA! ¡PLUJA DE GALETS! | EXPLOSIVE STEW! RAIN OF PASTA SHELLS!
FT_DAMAGE | -%s | -%s
FT_DAMAGE_LABEL | %s -%s | %s -%s
FT_FALLEN | ¡%s CAIGUT! | %s HAS FALLEN!
FT_CASTELL | ¡CASTELL DE CUCS! +30% FORÇA ENXANETA! | CATERPILLAR TOWER! +30% TOP-CLIMBER STRENGTH!
FT_PROCESSION_FURY | ¡FÚRIA EN PROCESSÓ! +%s%% DANY | PROCESSION FURY! +%s%% DAMAGE
FT_CARQUINYOLIS | ¡CARQUINYOLIS TRENCADENTS! | TOOTH-BREAKING BISCUITS!
FT_BAT_DEFLECT | ¡REBOT DE MESTRE! | MASTER'S REBOUND!
FT_FUET_SLICE | ¡ZASCA DE FUET! | FUET SLICE!
FT_TIO | ¡CAGA TIÓ, CAGA TORRÓ! | POOP LOG, POOP NOUGAT!
FT_JETPACK | ¡ALES DE PINAR (W/A/D)! | PINE WINGS (W/A/D)!
FT_SPOON | ¡CULLERADA DE BOIX! ¡OBRINT PAS! | BOXWOOD SPOONFUL! MAKING WAY!
FT_DRILL | ¡BARRINA DE MINAIRE! ¡Brrrrr! | MINER'S DRILL! Brrrrr!
FT_GIRDER | ¡MARGE DE PEDRA SECA CONSTRUÏT! | DRY-STONE WALL BUILT!
FT_GRAPPLE | ¡GANXO DE PASTOR! ¡AMUNT! | SHEPHERD'S CROOK! UP WE GO!
FT_GRAPPLE_SHORT | ¡GANXO CURT! | CROOK TOO SHORT!
FT_MEDKIT | +35 PV ¡RESINA DE PI! | +35 HP PINE RESIN!
FT_CRATE_WEAPON | +1 %s! | +1 %s!
FT_MINE_ARMED | ¡CLIC! MINA ARMADA! | CLICK! MINE ARMED!
FT_HOLY_CHOIR | ♪ VIROLAI! AL·LELUIA! ♪ | ♪ VIROLAI! HALLELUJAH! ♪
FT_DYNAMITE_BOOM | ¡CAGA TIÓ! | POOP LOG!
FT_PARACHUTE_CUT | ¡PARACAIGUDES TRENCAT! | PARACHUTE BROKEN!
FT_WEB_RICOCHET | ¡REBOT EN SEDA! | SILK RICOCHET!
FT_CAGANER | ¡BENEDICCIÓ DEL CAGANER! +30 PV I +1 PORRÓ! | CAGANER'S BLESSING! +30 HP AND +1 PORRÓ!
FT_ESCUDELLA_BUFF | +25 PV ¡FORÇA DE LA PILOTA! (+25% DANY) | +25 HP MEATBALL POWER! (+25% DAMAGE)
FT_PINE_NUT | +20 PV ¡PINYÓ DAURAT! | +20 HP GOLDEN PINE NUT!
FT_WEB_BOING | ¡BOING DE SEDA! | SILK BOING!
FT_ROVELLO_BOING | ¡BOING DE ROVELLÓ! +8 PV | MUSHROOM BOING! +8 HP
FT_CARAMBOLA | ¡CARAMBOLA! | CAROM!
FT_DROWN | %s: Glu glu... XOF! | %s: Glub glub... SPLASH!
DMG_URTICARIA | ¡URTICÀRIA! | URTICARIA!
DMG_SILK_SHIELD | ESCUT DE SEDA | SILK SHIELD
DMG_ITCH | ¡PICOR URTICANT! | STINGING ITCH!
DMG_CRATE | ¡CAIXA AL CAP! | CRATE ON THE HEAD!
DMG_CARQUINYOLI_BITE | ¡CREC! TRENCADENTS! | CRUNCH! TOOTH-BREAKER!
DMG_FUET | ¡COP DE FUET DE VIC! | VIC FUET WHIP!
DMG_BAT | ¡BON COP DE FALÇ! | GOOD SICKLE BLOW!
DMG_HOOK | ¡GANXADA DE PASTOR! | SHEPHERD'S YANK!
DMG_SPOON | ¡CULLERADA! | SPOONFUL!
DMG_DRILL | ¡BARRINA! | DRILL!
DMG_LARVAE | ¡LARVES! | LARVAE!
DMG_SLAM | PATACADA! | THUD!
DMG_CARAMBOLA | ¡CARAMBOLA! | CAROM!
BUBBLE_CAGANER | ¡El Caganer de la Sort! | The Lucky Caganer!
BUBBLE_ESCUDELLA | ¡Quina Escudella més bona! | What a tasty Escudella!
BUBBLE_CASTELL | ¡Castell de Cucs! ¡Aleta! | Caterpillar tower! Aleta!
TAUNT_TURN_1 | A pel pi! | To the pine!
TAUNT_TURN_2 | En processó! | In procession!
TAUNT_TURN_3 | Prepara el trabuc! | Ready the blunderbuss!
TAUNT_TURN_4 | Tasta el fuet de Vic! | Taste the Vic fuet!
TAUNT_TURN_5 | Carquinyoli trencadents! | Tooth-breaking biscuit!
TAUNT_TURN_6 | Bon cop de falç! | A good sickle blow!
TAUNT_HIT_1 | Ai els meus pèls! | Ouch, my hairs!
TAUNT_HIT_2 | Quina picor! | How itchy!
TAUNT_HIT_3 | Mal llamp! | Blast it!
TAUNT_HIT_4 | El meu capoll! | My cocoon!
TAUNT_URTICARIA_1 | Pols urticant! | Stinging dust!
TAUNT_URTICARIA_2 | Grata, grata! | Scratch, scratch!
TAUNT_URTICARIA_3 | Al·lèrgia total! | Total allergy!
TAUNT_PROCESSION_1 | Columna unida! | United column!
TAUNT_PROCESSION_2 | Fúria processionària! | Processionary fury!
TAUNT_PROCESSION_3 | Seda i ferro! | Silk and iron!
TAUNT_METAMORPH_1 | METAMORFOSI! | METAMORPHOSIS!
TAUNT_METAMORPH_2 | Ales de Thaumetopoea! | Wings of Thaumetopoea!
TAUNT_METAMORPH_3 | Ja puc planar! | Now I can glide!
WPN_BAZOOKA | Trabuc | Blunderbuss
WPN_CARQUINYOLI | Carquinyolis | Carquinyolis
WPN_GRENADE | Pinya | Pine cone
WPN_CLUSTER | Calçotada | Calçotada
WPN_URTICARIA | Urticant | Urticating
WPN_SHOTGUN | Pedrenyal | Flintlock
WPN_FUET | El Fuet | The Fuet
WPN_BAT | La Falç | The Sickle
WPN_DYNAMITE | El Tió | The Tió
WPN_HOLY | Porró Sagrat | Holy Porró
WPN_AIRSTRIKE | Correfoc | Correfoc
WPN_JETPACK | Ales Pinar | Pine Wings
WPN_CULLERA | Cullera Boix | Boxwood Spoon
WPN_BARRINA | Barrina | Quarry Drill
WPN_PONT_PEDRA | Pedra Seca | Dry Stone
WPN_GANXO | Ganxo Pastor | Shepherd's Crook
MAP_MONTSERRAT_NAME | Massís de Montserrat | Montserrat Massif
MAP_MONTSERRAT_SUBTITLE | Monestir de Santa Maria, Agulles i Aeri (Bages) | Santa Maria Monastery, Needles and Cable Car (Bages)
MAP_MONTSERRAT_BADGE | BOIRA I PINARS | MIST AND PINE FORESTS
MAP_CADAQUES_NAME | Cadaqués i Cap de Creus | Cadaqués and Cap de Creus
MAP_CADAQUES_SUBTITLE | Església de Santa Maria, Llaguts i Feixes (Alt Empordà) | Santa Maria Church, Llaguts and Terraces (Alt Empordà)
MAP_CADAQUES_BADGE | TRAMUNTANA VIVA | LIVELY TRAMUNTANA
MAP_TAULL_NAME | Taüll i la Vall de Boí | Taüll and the Vall de Boí
MAP_TAULL_SUBTITLE | Sant Climent de Taüll i Aigüestortes (Alta Ribagorça) | Sant Climent de Taüll and Aigüestortes (Alta Ribagorça)
MAP_TAULL_BADGE | NEU DEL PIRINEU | PYRENEAN SNOW
MAP_CASTELLFOLLIT_NAME | Castellfollit de la Roca | Castellfollit de la Roca
MAP_CASTELLFOLLIT_SUBTITLE | Cinglera Basàltica i Fageda d'en Jordà (La Garrotxa) | Basalt Cliff and Fageda d'en Jordà beech forest (La Garrotxa)
MAP_CASTELLFOLLIT_BADGE | FULLES DE FAIG | BEECH LEAVES
MAP_DELTA_EBRE_NAME | Delta de l'Ebre i Buda | Ebre Delta and Buda
MAP_DELTA_EBRE_SUBTITLE | Arrossars, Barraques, Far del Fangar i Flamencs (Montsià) | Rice Fields, Barracas, Fangar Lighthouse and Flamingos (Montsià)
MAP_DELTA_EBRE_BADGE | FLAMENCS I DUNES | FLAMINGOS AND DUNES
MAP_TARRACO_NAME | Tàrraco Imperial | Imperial Tàrraco
MAP_TARRACO_SUBTITLE | Amfiteatre Romà, Pont del Diable i Mare Nostrum (Tarragonès) | Roman Amphitheatre, Devil's Bridge and Mare Nostrum (Tarragonès)
MAP_TARRACO_BADGE | PEDRA ROMANA | ROMAN STONE
MAP_PEDRAFORCA_NAME | Massís del Pedraforca | Pedraforca Massif
MAP_PEDRAFORCA_SUBTITLE | L'Enforcadura, Tartera i Serra del Cadí (Berguedà) | The Enforcadura, Scree and Serra del Cadí (Berguedà)
MAP_PEDRAFORCA_BADGE | CIM MÀGIC | MAGIC SUMMIT
MAP_MONTBLANC_NAME | Muralles de Montblanc | Walls of Montblanc
MAP_MONTBLANC_SUBTITLE | Torres Medievals, Llegenda de Sant Jordi i Prades (Conca) | Medieval Towers, Legend of Saint George and Prades (Conca)
MAP_MONTBLANC_BADGE | DRAC I ROSES | DRAGON AND ROSES
ARCH_FEIXES_TERRACED | Feixes de Pedra Seca | Dry-Stone Terraces
ARCH_AGULLES_SPIRES | Agulles i Cingles | Spires and Cliffs
ARCH_MULTI_DECK_GROTTO | Cova de Dos Nivells | Two-Level Cave
ARCH_FLOATING_BALCONIES | Balcons Sospesos | Hanging Balconies
ARCH_TWIN_MASSIFS | Doble Massís | Twin Massifs
ARCH_STEPPED_CANYONS | Congost Escalonat | Stepped Gorge
ARCH_CITADEL_CALDERA | Ciutadella Alta | High Citadel
ARCH_ARCHIPELAGO | Illes Escalonades | Stepped Islands

# UI translation keys

Keys used by the menus, lobby and combat HUD (`ui/`, `combat/hud/`). Base language is English (`i18n/en.po`); the Catalan original is the text of the JS game (`i18n/ca.po`). Placeholders (`%s`, `%d`) keep their order. `[b]...[/b]` in `MENU_HINT` and `ROTATE_BODY` marks the highlighted words (the UI turns it into brass/ivory colour). Some keys are built from a pattern (`LOBBY_COUNT_N_*`, `MAP_<ID>_*`, `WEAPON_<ID>`); they are listed in full.

Weapon and map **names** may also come from the sim data (`WeaponDef.name_key`, `MapDef`); the HUD uses these `WEAPON_<ID>` / `MAP_<ID>_*` keys, align if the data agent picks others.

| KEY | Catalan original | English proposal |
|---|---|---|
| `SPLASH_KICKER` | Thaumetopoea Pityocampa · Guerra Tàctica als Pinars de Catalunya | Thaumetopoea Pityocampa · Tactical War in the Pine Forests of Catalonia |
| `SPLASH_TITLE` | CUCS | CUCS |
| `SPLASH_SUBTITLE` | LA PROCESSÓ DE FERRO | THE IRON PROCESSION |
| `MENU_QUICK_TITLE` | Partida Ràpida contra la CPU | Quick Match vs the CPU |
| `MENU_QUICK_SUB` | Salta directament al camp de batalla contra la IA | Jump straight into battle against the AI |
| `MENU_2P_TITLE` | 2 Jugadors en Local | 2 Players, Local |
| `MENU_2P_SUB` | Jugueu per torns al mateix mòbil o ordinador | Take turns on the same phone or computer |
| `MENU_CUSTOM_TITLE` | Personalitza la Partida | Custom Match |
| `MENU_CUSTOM_SUB` | Indrets de Catalunya, dificultat, barrets, noms i cares d'amics | Places of Catalonia, difficulty, hats, names and friends' faces |
| `MENU_HINT` | [b]Toca[/b] o [b]↑/↓ + INTRO[/b] per Seleccionar  ·  100% Jugable amb Teclat o Mòbil Horitzontal | [b]Tap[/b] or [b]↑/↓ + ENTER[/b] to select  ·  100% playable with keyboard or a phone in landscape |
| `ROTATE_KICKER` | FORMAT APAÏSAT RECOMANAT | LANDSCAPE FORMAT RECOMMENDED |
| `ROTATE_TITLE` | GIRA EL MÒBIL EN HORITZONTAL | TURN YOUR PHONE SIDEWAYS |
| `ROTATE_BODY` | Per veure tot el camp de batalla i utilitzar còmodament els controls tàctils de [b]CUCS[/b], gira el telèfon en mode horitzontal. | To see the whole battlefield and use the touch controls of [b]CUCS[/b] comfortably, turn your phone to landscape. |
| `ROTATE_BTN_FULLSCREEN` | Pantalla Completa Horitzontal | Landscape Fullscreen |
| `ROTATE_BTN_CONTINUE` | Continua igualment | Continue anyway |
| `LOBBY_TITLE` | CUCS — Personalitza la Partida i els Escamots | CUCS — Customize the Match and the Squads |
| `LOBBY_SUBTITLE` | Tria el mode de combat, l'indret de Catalunya, el barret tradicional, els noms i les fotos. | Choose the combat mode, the place in Catalonia, the traditional hat, the names and the photos. |
| `LOBBY_KB_HINT` | Teclat: ↑↓←→ / Tab per navegar · Intro/Espai per canviar · Ctrl+Intro per desplegar | Keyboard: ↑↓←→ / Tab to move · Enter/Space to change · Ctrl+Enter to deploy |
| `LOBBY_BTN_BACK` | ← Menú Principal [Esc] | ← Main Menu [Esc] |
| `LOBBY_SEC_MODE` | 1. Mode de Combat | 1. Combat Mode |
| `LOBBY_SEC_DIFF` | 2. Intel·ligència Tàctica de la CPU | 2. CPU Tactical Intelligence |
| `LOBBY_SEC_COUNT` | 3. Nombre de Cucs per Escamot (1 a 6 Cucs) | 3. Caterpillars per Squad (1 to 6) |
| `LOBBY_SEC_MAP` | 4. Tria d'entre els 8 Indrets de Catalunya | 4. Choose one of the 8 Places of Catalonia |
| `LOBBY_SEC_SQUADS` | 5. Personalitza els Escamots de Cucs i Cares d'Amics | 5. Customize the Caterpillar Squads and Friends' Faces |
| `LOBBY_MODE_1P_TITLE` | 1J vs CPU | 1P vs CPU |
| `LOBBY_MODE_1P_SUB` | Campanya en Solitari vs IA | Solo Campaign vs AI |
| `LOBBY_MODE_2P_TITLE` | 2J en Local | 2P Local |
| `LOBBY_MODE_2P_SUB` | Dos Jugadors, Mateix PC | Two Players, Same PC |
| `LOBBY_MODE_CPU_TITLE` | CPU vs CPU | CPU vs CPU |
| `LOBBY_MODE_CPU_SUB` | Batalla d'Exhibició IA | AI Exhibition Battle |
| `LOBBY_DIFF_ROOKIE_TITLE` | Novell | Rookie |
| `LOBBY_DIFF_ROOKIE_SUB` | Punteria Benèvola | Forgiving Aim |
| `LOBBY_DIFF_VETERAN_TITLE` | Veterà | Veteran |
| `LOBBY_DIFF_VETERAN_SUB` | Tàctica Equilibrada | Balanced Tactics |
| `LOBBY_DIFF_NIGHTMARE_TITLE` | Malson | Nightmare |
| `LOBBY_DIFF_NIGHTMARE_SUB` | Càlcul Mortal del Vent | Deadly Wind Calculation |
| `LOBBY_COUNT_1_TITLE` | 1 Cuc | 1 Caterpillar |
| `LOBBY_COUNT_1_SUB` | Duel 1 vs 1 | 1 vs 1 Duel |
| `LOBBY_COUNT_2_TITLE` | 2 Cucs | 2 Caterpillars |
| `LOBBY_COUNT_2_SUB` | Parella Tàctica | Tactical Pair |
| `LOBBY_COUNT_3_TITLE` | 3 Cucs | 3 Caterpillars |
| `LOBBY_COUNT_3_SUB` | Escamot Lleuger | Light Squad |
| `LOBBY_COUNT_4_TITLE` | 4 Cucs | 4 Caterpillars |
| `LOBBY_COUNT_4_SUB` | Clàssic (4 vs 4) | Classic (4 vs 4) |
| `LOBBY_COUNT_5_TITLE` | 5 Cucs | 5 Caterpillars |
| `LOBBY_COUNT_5_SUB` | Columna Gran | Large Column |
| `LOBBY_COUNT_6_TITLE` | 6 Cucs | 6 Caterpillars |
| `LOBBY_COUNT_6_SUB` | Guerra Total (6 vs 6) | Total War (6 vs 6) |
| `LOBBY_SQUAD_1` | I. Brigada del Pinar (Or) | I. Pine Brigade (Gold) |
| `LOBBY_SQUAD_2` | II. Columna Tramuntana (Grana) | II. Tramuntana Column (Crimson) |
| `HAT_VARIED` | Barret: Variat (Cada Cuc Diferent!) | Hat: Varied (Every Caterpillar Different!) |
| `HAT_CATALAN` | Barret: Barretina Catalana | Hat: Catalan Barretina |
| `HAT_CASTELLER` | Barret: Casc de Casteller (Senyera) | Hat: Casteller Helmet (Senyera) |
| `HAT_BANDOLER` | Barret: Capell de Bandoler (Serrallonga) | Hat: Bandit Hat (Serrallonga) |
| `HAT_PAGES` | Barret: Barret de Palla de Pagès | Hat: Farmer's Straw Hat |
| `HAT_BRISTLES` | Barret: Plomall de Pèls Urticants | Hat: Urticating Hair Plume |
| `LOBBY_FACE_ADD` | + Cara | + Face |
| `LOBBY_FACE_READY` | ✓ Cara Llista | ✓ Face Ready |
| `LOBBY_FACE_TOOLTIP` | Puja la foto de la cara d'un amic per a aquest cuc | Upload a friend's face photo for this caterpillar |
| `LOBBY_BTN_RANDOM` | Noms Catalans Aleatoris | Random Catalan Names |
| `LOBBY_BTN_BACK_TO_GAME` | Torna a la Partida Actual | Back to the Current Match |
| `LOBBY_BTN_DEPLOY` | DESPLEGA AL CAMP DE BATALLA | DEPLOY TO THE BATTLEFIELD |
| `MAP_MONTSERRAT_NAME` | Massís de Montserrat | Montserrat Massif |
| `MAP_MONTSERRAT_SUB` | Monestir de Santa Maria, Agulles i Aeri (Bages) | Santa Maria Monastery, Needles and Cable Car (Bages) |
| `MAP_MONTSERRAT_BADGE` | BOIRA I PINARS | MIST AND PINES |
| `MAP_CADAQUES_NAME` | Cadaqués i Cap de Creus | Cadaqués and Cap de Creus |
| `MAP_CADAQUES_SUB` | Església de Santa Maria, Llaguts i Feixes (Alt Empordà) | Santa Maria Church, Fishing Boats and Terraces (Alt Empordà) |
| `MAP_CADAQUES_BADGE` | TRAMUNTANA VIVA | LIVELY TRAMUNTANA |
| `MAP_TAULL_NAME` | Taüll i la Vall de Boí | Taüll and the Vall de Boí |
| `MAP_TAULL_SUB` | Sant Climent de Taüll i Aigüestortes (Alta Ribagorça) | Sant Climent de Taüll and Aigüestortes (Alta Ribagorça) |
| `MAP_TAULL_BADGE` | NEU DEL PIRINEU | PYRENEAN SNOW |
| `MAP_CASTELLFOLLIT_NAME` | Castellfollit de la Roca | Castellfollit de la Roca |
| `MAP_CASTELLFOLLIT_SUB` | Cinglera Basàltica i Fageda d'en Jordà (La Garrotxa) | Basalt Cliff and Fageda d'en Jordà Beech Forest (La Garrotxa) |
| `MAP_CASTELLFOLLIT_BADGE` | FULLES DE FAIG | BEECH LEAVES |
| `MAP_DELTA_EBRE_NAME` | Delta de l'Ebre i Buda | Ebro Delta and Buda |
| `MAP_DELTA_EBRE_SUB` | Arrossars, Barraques, Far del Fangar i Flamencs (Montsià) | Rice Fields, Barracas, Fangar Lighthouse and Flamingos (Montsià) |
| `MAP_DELTA_EBRE_BADGE` | FLAMENCS I DUNES | FLAMINGOS AND DUNES |
| `MAP_TARRACO_NAME` | Tàrraco Imperial | Imperial Tarraco |
| `MAP_TARRACO_SUB` | Amfiteatre Romà, Pont del Diable i Mare Nostrum (Tarragonès) | Roman Amphitheatre, Devil's Bridge and Mare Nostrum (Tarragonès) |
| `MAP_TARRACO_BADGE` | PEDRA ROMANA | ROMAN STONE |
| `MAP_PEDRAFORCA_NAME` | Massís del Pedraforca | Pedraforca Massif |
| `MAP_PEDRAFORCA_SUB` | L'Enforcadura, Tartera i Serra del Cadí (Berguedà) | The Enforcadura, Scree and Serra del Cadí (Berguedà) |
| `MAP_PEDRAFORCA_BADGE` | CIM MÀGIC | MAGIC PEAK |
| `MAP_MONTBLANC_NAME` | Muralles de Montblanc | Walls of Montblanc |
| `MAP_MONTBLANC_SUB` | Torres Medievals, Llegenda de Sant Jordi i Prades (Conca) | Medieval Towers, Legend of Saint George and Prades (Conca de Barberà) |
| `MAP_MONTBLANC_BADGE` | DRAC I ROSES | DRAGON AND ROSES |
| `HUD_SQUAD_1` | I. Brigada del Pinar | I. Pine Brigade |
| `HUD_SQUAD_2` | II. Tramuntana | II. Tramuntana |
| `HUD_HP_TOTAL` | %d PV | %d HP |
| `HUD_TURN_OF` | Torn de %s | %s's turn |
| `HUD_ROUND_SUB` | Ronda %d · %s | Round %d · %s |
| `HUD_WIND` | VENT | WIND |
| `HUD_MUSIC_ON` | Música: Sí | Music: On |
| `HUD_MUSIC_OFF` | Música: No | Music: Off |
| `HUD_MUSIC_TOOLTIP` | Activa o silencia la música MIDI catalana | Turns the Catalan MIDI music on or off |
| `HUD_EXIT` | Sortir | Exit |
| `HUD_EXIT_TOOLTIP` | Surt de la partida actual i torna al menú principal | Leaves the current match and returns to the main menu |
| `HUD_PIP_OWN` | Toca abans de moure per jugar amb aquest cuc | Tap before moving to play with this caterpillar |
| `HUD_PIP_OTHER` | Toca per mirar on és aquest cuc | Tap to look where this caterpillar is |
| `HUD_END_WIN_0` | ¡Victòria de la Brigada del Pinar! | Victory for the Pine Brigade! |
| `HUD_END_WIN_1` | ¡Victòria de la Tramuntana! | Victory for the Tramuntana! |
| `HUD_END_DRAW` | ¡Destrucció Mútua — Empat! | Mutual Destruction — Draw! |
| `HUD_FUSE` | METXA [Q/E]: | FUSE [Q/E]: |
| `HUD_ARSENAL_OPEN` | ▲ Arsenal [B] | ▲ Arsenal [B] |
| `HUD_ARSENAL_CLOSE` | ▼ Tanca [B] | ▼ Close [B] |
| `HUD_WEAPON_PREV_TOOLTIP` | Arma anterior [Z o [ ] | Previous weapon [Z or [ ] |
| `HUD_WEAPON_NEXT_TOOLTIP` | Arma següent [X o ] ] | Next weapon [X or ] ] |
| `HUD_WEAPON_TOGGLE_TOOLTIP` | Toca o prem [B] per obrir les 16 armes catalanes (Z/X per canviar ràpid) | Tap or press [B] to open the 16 Catalan weapons (Z/X to switch quickly) |
| `HUD_SWITCH_WORM` | Cuc ⇄ | Worm ⇄ |
| `HUD_SWITCH_WORM_TOOLTIP` | Canvia quin cuc controles abans de moure [Tab] | Change which caterpillar you control before moving [Tab] |
| `HUD_MOVE_LEFT` | Moure a l'esquerra | Move left |
| `HUD_MOVE_RIGHT` | Moure a la dreta | Move right |
| `HUD_AIM_UP` | Apuntar amunt | Aim up |
| `HUD_AIM_DOWN` | Apuntar avall | Aim down |
| `HUD_JUMP` | Salt | Jump |
| `HUD_JUMP_TOOLTIP` | Salt endavant [Intro] | Jump forward [Enter] |
| `HUD_FLIP` | Mortal | Flip |
| `HUD_FLIP_TOOLTIP` | Salt mortal enrere [Retrocés] | Backflip [Backspace] |
| `HUD_ZOOM_OUT_TOOLTIP` | Allunya la càmera [AvPàg] | Zoom the camera out [PageDown] |
| `HUD_ZOOM_IN_TOOLTIP` | Apropa la càmera [RePàg] | Zoom the camera in [PageUp] |
| `HUD_CENTER` | Centra | Center |
| `HUD_CENTER_TOOLTIP` | Centra la càmera [V] | Center the camera [V] |
| `FIRE_HOLD` | MANTÉN: FOC! | HOLD: FIRE! |
| `FIRE_AIRSTRIKE` | CORREFOC! | CORREFOC! |
| `FIRE_CULLERA` | CULLERADA! | SPOON SMACK! |
| `FIRE_BARRINA` | BARRINA! | DRILL! |
| `FIRE_PONT_PEDRA` | PEDRA SECA! | DRY STONE! |
| `FIRE_GANXO` | GANXO! | HOOK! |
| `FIRE_MELEE` | ATACA! | ATTACK! |
| `FIRE_DROP` | DEIXA TIÓ! | DROP TIÓ! |
| `FIRE_JET` | ALES! | WINGS! |
| `FIRE_DEFAULT` | FOC! | FIRE! |
| `WEAPON_BAZOOKA` | Trabuc | Blunderbuss |
| `WEAPON_CARQUINYOLI` | Carquinyolis | Carquinyolis |
| `WEAPON_GRENADE` | Pinya | Pine Cone |
| `WEAPON_CLUSTER` | Calçotada | Calçotada |
| `WEAPON_URTICARIA` | Urticant | Urticating |
| `WEAPON_SHOTGUN` | Pedrenyal | Flintlock |
| `WEAPON_FUET` | El Fuet | The Fuet |
| `WEAPON_BAT` | La Falç | The Sickle |
| `WEAPON_DYNAMITE` | El Tió | The Tió |
| `WEAPON_HOLY` | Porró Sagrat | Holy Porró |
| `WEAPON_AIRSTRIKE` | Correfoc | Correfoc |
| `WEAPON_JETPACK` | Ales Pinar | Pine Wings |
| `WEAPON_CULLERA` | Cullera Boix | Boxwood Spoon |
| `WEAPON_BARRINA` | Barrina | Drill |
| `WEAPON_PONT_PEDRA` | Pedra Seca | Dry Stone |
| `WEAPON_GANXO` | Ganxo Pastor | Shepherd's Hook |
| `VICTORY_KICKER` | BATALLA COMARCAL COMPLETADA | DISTRICT BATTLE COMPLETE |
| `VICTORY_TITLE_0` | ¡VICTÒRIA DE LA BRIGADA DEL PINAR! | VICTORY FOR THE PINE BRIGADE! |
| `VICTORY_TITLE_1` | ¡VICTÒRIA DE LA COLUMNA TRAMUNTANA! | VICTORY FOR THE TRAMUNTANA COLUMN! |
| `VICTORY_TITLE_DRAW` | ¡DESTRUCCIÓ MÚTUA — EMPAT! | MUTUAL DESTRUCTION — DRAW! |
| `VICTORY_SUB_0` | La Processó Daurada conquereix %s! | The Golden Procession conquers %s! |
| `VICTORY_SUB_1` | La Processó Grana conquereix %s! | The Crimson Procession conquers %s! |
| `VICTORY_SUB_DRAW` | Tots els cucs han caigut en combat! | All the caterpillars have fallen in combat! |
| `VICTORY_STAT_MAP` | Indret: | Place: |
| `VICTORY_STAT_ROUNDS` | Rondes Totals: | Total Rounds: |
| `VICTORY_STAT_DMG_0` | Dany Brigada del Pinar: | Pine Brigade Damage: |
| `VICTORY_STAT_DMG_1` | Dany Tramuntana: | Tramuntana Damage: |
| `VICTORY_STAT_MVP` | Cuc Processionari MVP: | Processionary Caterpillar MVP: |
| `VICTORY_MVP_VALUE` | %s (%d punts de dany) | %s (%d damage points) |
| `VICTORY_BTN_LOBBY` | Canvia Indret / Escamot | Change Place / Squad |
| `VICTORY_BTN_REMATCH` | Torna a Jugar [Intro] | Play Again [Enter] |

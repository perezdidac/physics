# CUCS port inventory: simulation layer (world.js, state.js, physics.js)

Scope: `reference/js/world.js` (1108 lines), `reference/js/state.js` (1199 lines), `reference/js/physics.js` (2654 lines). Plus the minimum of `main.js` needed to understand who drives these (game loop, turn state machine, input-side physics such as jumping). `renderer.js` / `audio.js` are only referenced where they read/write our globals.

All line numbers refer to the reference JS files. "W" = world.js, "S" = state.js, "P" = physics.js, "M" = main.js, "R" = renderer.js.

Conventions of the source: Catalan UI text, `"use strict"`, global script scope (no modules), y axis points DOWN, units are pixels and seconds, angles in radians with `0 = right`, `-PI/2 = up` (screen coordinates; `sin(angle) < 0` means upward).

---------------------------------------------------------------------------

## 1. Overview

### world.js (W): noise, theatres, terrain generation, terrain queries
- Perlin-like `noise2D` with a fixed seeded permutation, `fbm`, `ridgedFbm`.
- `MAPS[]`: 8 Catalan theatres (colours, sky, friction, tree style, preferred rock texture, weather).
- Procedural 3200x820 destructible terrain: a `Uint8Array` collision mask (`terrainMask`) plus two offscreen canvases (`terrainFront` colour layer, `terrainBack` dark back wall) for rendering. Generation = height profile (noise + random hills + one of 8 archetypes + per-theatre tweak) -> per-pixel fill (grass/soil/rock with 6 texture styles, caverns) -> stamped terraces, landmarks, trees.
- Terrain queries: `isSolid`, `getSurfaceNormal`, `findSurfaceY`, `findAllWalkableSurfacesAtX`.
- Terrain edits: `carveCrater` (explosions/tools), `buildDryStoneGirder` (Pedra Seca weapon).
- Cloud layer texture generator (render only), background image loader (render only).

### state.js (S): weapon table, match state, spawning, wind, turn start
- `WEAPONS[]` table (16 entries, ids/keys/ammo/damage/radius/knockback + inline SVG icon strings).
- All global mutable game state (fighters, pickups, projectiles, effects arrays, team ammo, turn variables, camera, input flags).
- Name pools, hats, taunts, game modes, atmosphere generation (clouds, mountains, sky palette: render only).
- `initMatch` (spawns everything), `createFighter`, `spawnSupplyDrop`, wind model (`randomizeWind`, `updateDynamicWind`), `startNextTurn`, `isCurrentTurnAI`, victory modal text.

### physics.js (P): combat, physics, AI
- `triggerExplosion` (the central damage/knockback/crater routine), `damageFighter`, `checkMetamorphosis`.
- `fireWeapon` (dispatch for all weapons), `stepPhysics` (everything that moves: planes, crates, mines, projectiles, pickups, nests, barrels, tombstones, procession links, fighters, tools).
- Caterpillar segment follow (`updateOrugaSegments`, purely cosmetic but reads terrain).
- AI (`updateAI`, `simulateArc`), particle spawners (`spawn*`, render-only effects but part of the same arrays).

### Who drives the simulation (main.js, relevant parts)
- `loop(now)` (M:98-442): variable-dt loop, `dt = min(real, 0.033)`; hit-stop and slow-mo; calls `updateDynamicWind(dt)`, `updateAI(dt)`, `stepPhysics(dt)`, then the **turn state machine** (M:195-291) and camera and particle updates (M:353-438).
- Input handlers (M:540-580, 1470-1590) implement walking/jump/charge/weapon select; they write sim globals directly (see section 4.14).

---------------------------------------------------------------------------

## 2. Global state

Legend for access: R = read, W = write, RW. Files: W=world, S=state, P=physics, M=main, R=renderer, A=audio.

### 2.1 Constants / config

| Name | Value / type | Defined | Used by |
|---|---|---|---|
| `TERRAIN_W` | 3200 (world width px) | W:259 | everywhere |
| `TERRAIN_H` | 820 (mask/canvas height) | W:260 | W, S, P, R |
| `WATER_Y` | `let`, 700 at map gen; rises (see 4.12) | W:261, W (reset in generateDestructibleTerrain:565), S (startNextTurn:1114 decrements) | W,S,P,M,R |
| `GRAVITY` | 440 px/s^2 | P:6 | P (all falling things) |
| `PERM` | Uint8Array(512), seeded permutation | W:6 | noise2D |
| `MAPS` | array of 8 theatre configs | W:68 | W,S,P(slideFriction),M,R |
| `TEXTURE_STYLES` | 6 strings | W:526 | generateDestructibleTerrain |
| `WEAPONS` | array of 16 | S:6 | S,P,M,R,A(maybe) |
| `ORUGA_TAUNTS` | dict of string arrays | S:278 | S,P |
| `CATALAN_NAMES_POOL_0/1` | 30 names each | S:223,230 | S |
| `ALL_HAT_STYLES` | 5 strings | S:851 | S (createFighter) |
| `GAME_MODES`, `MODE_SHORT` | modes | S:264 | S,M |
| `TEXTURE/archetype` locals | see 3.x | W:616 | local |

### 2.2 Match / flow state (state.js unless noted)

| Name | Type/shape | Purpose | Writers | Readers |
|---|---|---|---|---|
| `appStage` | `'SPLASH'`/`'LOBBY'`/`'PLAYING'` | UI stage; sim gates many things on `=== 'PLAYING'` (hit-stop, SND, wind updates, splash showcase AI) | M | S,P,M,R |
| `gameMode` | `'1P_CPU'`/`'2P_LOCAL'`/`'CPU_CPU'` | who is AI | M | S (`isCurrentTurnAI`, initMatch) |
| `aiDifficulty` | `'ROOKIE'`/`'VETERAN'`/`'NIGHTMARE'`, default `'VETERAN'` | AI aim jitter only | M (lobby:1869) | P (updateAI) |
| `menuCursorIdx`, `hasStartedMatchOnce` | UI | menu | M | M |
| `wormsPerTeam` | int 1..6 default 4 | squad size | M (1877) | S (initMatch, 683/840) |
| `hasCustomLobbyNames` | bool | do not re-randomize names | S,M | S |
| `teamNames` | `[ [6 str], [6 str] ]` | caterpillar names | S (randomize), M (lobby) | S, M |
| `teamHats` | `['CATALAN','BANDOLER']` initial; values in `{VARIED,CATALAN,CASTELLER,BANDOLER,PAGES,BRISTLES}` | per-team hat (render only) | M | R |
| `customFaces` | `[[6 null],[6 null]]` (Image) | custom face image (render only) | M | S (createFighter), R |
| `turnPhase` | `'TURN_PLAY'`,`'RETREAT'`,`'ACTION_WAIT'`,`'TURN_DELAY'`,`'GAME_OVER'` | turn state machine | S,P,M | S,P,M,R |
| `turnTimer` | float, 30 at turn start | player time | S (reset), M (decrement) | M |
| `phaseTimer` | float | RETREAT / TURN_DELAY countdown | P (fireWeapon, tools), M | M |
| `actionWaitTimer` | float | time spent in ACTION_WAIT | M | M |
| `lastTurnTickSec` | int | audio tick tracker | S,M | M |
| `activeTeam` | 0/1 | | S | all |
| `activeFighter` | fighter object or null | | S (startNextTurn, switchActiveWormBeforeMove) | all |
| `teamTurnIdx` | `[int,int]` | rotation index per team | S | S |
| `roundNumber` | int, starts 1 | | S | S,M(HUD),R |
| `hasActedOrMovedThisTurn` | bool | blocks worm switch | S,P,M | S,M |
| `turnSpotlightTimer` | float (render only) | | S,M | R |
| `shotgunShotsLeft` | int (set but never read for gating) | | S,P | - |
| `silkWebUsedThisTurn` | bool | one web per turn | S,P | P |
| `processionConvoyEnabled` | bool default true | toggle F | M | P (walk) |
| `customGrenadeFuse` | int 1..5 default 3 | GRENADE/CLUSTER fuse | M (Q/E keys, fuse UI) | P |
| `selectedWeaponIdx` | int | current weapon index | S,P (AI, jetpack),M | S,P,M,R |
| `teamSelectedWeaponIdx` | `[int,int]` | remembered weapon per team | S,P,M | S |
| `teamAmmo` | `[{id:count},{...}]`, `Infinity` for unlimited | per-team ammo | S (init), P (decrement, crate rewards) | S,P,M |
| `teamDamageDealt` | `[int,int]` | stats | S (init), P (damageFighter) | S (victory) |
| `nextFighterId` | int | | S | S |

### 2.3 Wind

| Name | Meaning | Written by | Read by |
|---|---|---|---|
| `wind` | integer in [-100,100]; the "official" wind (px/s^2 scale factor) | S (randomizeWind:970, updateDynamicWind:1007) | P (projectiles, crates, glide, particles/smoke via M), M (particles), R, A (ambient), S (clouds, ribbons, birds) |
| `windFloat` | float smoothed value | S | S |
| `windTarget` | float target | S | S (HUD arrow) |
| `windGustTimer` | float | S | S |
| `windGustFlash` | float render flash | S | S (HUD) |
| `windRibbons` | 16 render ribbons | S | S, R |

### 2.4 Fighters and other entities (all arrays; reset in `initMatch` S:640-663)

| Array | Item shape | Spawned by | Updated in |
|---|---|---|---|
| `fighters` | see 2.5 | initMatch/createFighter | stepPhysics (P:1658-2383) |
| `barrels` | `{x,y,vx,vy,r:14,hp:20,grounded,_lastKnockTime?}` | initMatch (3..7) | P:1618, triggerExplosion |
| `mines` | `{x,y,vx,vy,grounded,triggered,fuse:1.8,beepTimer}` | initMatch (2..5) | P:1128 |
| `crates` | `{x,y:-30,vx:0,vy:55,parachuting,grounded,isMedkit,rewardWpn}` | spawnSupplyDrop | P:1056 |
| `projectiles` | see 2.6 | fireWeapon, triggerExplosion, airstrike | P:1175 |
| `airstrikePlanes` | `{x,y:58,vx:+-820,targetX,dropped[5],offsets[5]}` | fireWeapon AIRSTRIKE | P:1025 |
| `silkWebs` | `{x1,y1,x2,y2,hp:3,vibration,team}` | spinElasticSilkWeb | P (bounces); decay P:1435 |
| `silkNests` | `{anchorX,anchorY,x,y,r:13,hp:15,swayPhase,swingAngle,swingVel}` | initMatch (on trees) | P:1425 |
| `pineNuts` | `{x,y,vx,vy,r:6,grounded,life:18}` | burstSilkNest, rovello hit | P:1538 |
| `larvaeSwarms` | `{x,y,vx,vy,life:5.5,tickTimer:0.45}` | burstSilkNest | P:1579 |
| `updrafts` | `{x,y,w:42,h:230}` | initMatch | read in P (projectiles & fighters) |
| `rovellons` | `{x,y,r:17..21,squash,hp:25}` | initMatch (3..5) | P:1440 |
| `caganers` | `{x,y,r:11,bobPhase}` | initMatch (1..2) | P:1452 |
| `escudelles` | `{x,y,r:15,hp:25,steamPhase}` | initMatch (2) | P:1494 |
| `tombstones` | `{x,y,vy:-140,name,team}` | damageFighter | P:1641 |
| `surfaceFlora` | `{x,y,type:mapId,variant 0..2,scale,phase}` | initMatch | uprooted in triggerExplosion (render object but is removed by explosions: flora existence is cosmetic) |
| `floatingTexts` | `{x,y,text,color,life}` | everywhere | M:428 (y -= 26*dt) |
| `speechBubbles` | `{fighter,text,life}` | spawnSpeechBubble | M:435 |
| `particles`, `smokePuffs`, `fireballs`, `shockwaves`, `waterPlumes`, `waterRipples`, `bubbles`, `touchRipples` | pure effects | P spawners | M:353-433 (note: particles also collide with terrain via `isSolid` and react to wind) |
| `generatedTreeSpots` | `[{tx,crownY}]` | W (generate) | S (nest placement) |
| `generatedValleySpots` | `[x]` | W | S (updrafts) |

### 2.5 Fighter object (createFighter, S:853-927)

Core sim fields:
`id, team(0/1), memberIdx, name, x, y (centre), vx, vy, r:12, hp:100, maxHp:100, alive, drowning, drownTimer, grounded, sliding, slideAngle, jumpStartY, jumpStartX?, peakAirY, isVoluntaryJump (init true), wasBlasted, isMinorSlide, slideTimer, airTimer, facing(+1/-1), flipAngle, flipSpin, metamorphosed, linkedAllies[], castellTower, pilotaBuff, wineTipsy (set, never read in sim), spoonTimer/spoonAngle/spoonTick, drillTimer/drillAngle/drillTick, grapple (null or {startX,startY,targetX,targetY,hookX,hookY,progress}), jetFuel, batSwingTimer, lastMeleeId, dizzyTimer, hurtTimer, urticatingTicks, dmgDealt, lastAimPitch(-0.42), lastChargePower, segs[6] ({x,y}), _lastKnockTime`.
Render-only fields: `squashX/Y (also lerped back in physics), walkCycle (random start, also advanced by sim), bodyColors[3], dorsalColor, individualHat, hasMustache, customFaceImg`.

Spawn: `fy = min(WATER_Y-30, surfaceY-14)`; segs i=0..5 at `x - facing*(i+1)*5.2, y: fy+4`.
Palette pick: `palIdx = (memberIdx + floor(random*6)) % 6`; hat `ALL_HAT_STYLES[(memberIdx + team*2 + floor(random*2)) % 5]`; `hasMustache = random < 0.38`.

### 2.6 Projectile object

`{type, x,y,vx,vy,r, windFactor, bounces, blastR, maxDmg, knockback, age, [fuse], [lastSec], [choirPlayed], [clusters], [ang], [bouncesLeft], [isUrticating], [isGalet], [isFuetSlice], [trail], [_whistled], [_lastWebBounce], [_lastFighterHit]}`; types: `BAZOOKA, URTICARIA, CARQUINYOLI, GRENADE, CLUSTER, HOLY, DYNAMITE, BOMBLER`. (`trail` and `ang` are render hints; `ang` advanced in physics: `ang += vx*0.015*sdt`.)

### 2.7 Camera / render-coupled globals (written by sim code, but belong to the view)
`cam{x,y,targetX,targetY,panOffsetX/Y,zoom,targetZoom,mouseOffX/Y,smoothMouseX/Y}`, `impactCam{active,x,y,trackedWorm}`, `shake`, `flashLight`, `flashPos`, `hitStopTimer`, `slowMoTimer`, `tNow`, `userZoomMult`, `mobilePanMode`, `mouseWorld{x,y}`, `weatherParticles`, `cloudFlock`, `skyBirds`, `windRibbons`, `mountainRidgeFar/Near`, `currentCloudStyle`, `currentMountainStyle`, `currentSkyPalette`.
Caveat: the sim writes `impactCam`, `shake`, `flashLight`, `hitStopTimer`, `slowMoTimer` from inside physics (triggerExplosion, fireWeapon, tool updates) and the camera/turn logic reads `impactCam.trackedWorm` / `impactCam.active` to decide when the turn may end (M:236-258). In the port these should become "events/signals" or a `CombatSim.impact_focus` struct.

### 2.8 Aiming / input globals shared with sim

| Name | Meaning | Notes |
|---|---|---|
| `aimPitch` | -0.42 default, clamp [-1.48, 1.30]; pitch relative to facing | S:342 |
| `aimAngle` | absolute angle: `facing>=0 ? pitch : PI - pitch` | `syncAimAngleFromPitch` S:358 |
| `isCharging`, `chargePower`, `chargeDir`, `lastChargeTick` | charge bar; start 0.08, +0.92/s (player), +0.95/s (AI) | M:171, 512 |
| `mouseWorld` | aim target point (used by AIRSTRIKE, set by `syncAimAngleFromPitch` to a point 260 px along aim, clamped x[120,3080], y[60,WATER_Y-20]) | S:365 |
| `keys{left,right,up,down}` | held-key flags (P reads them in stepPhysics for jetpack/glide/spoon) | M writes |
| `lastJumpPressTime` | ms timestamp (performance.now) for double-press backflip | M |
| `aiPlan` | AI plan object or null (reset every turn) | P:2507 |

### 2.9 Terrain state (world.js)

| Name | Type | Notes |
|---|---|---|
| `terrainMask` | `Uint8Array(3200*820)`, index `y*3200+x`, 1=solid | THE collision truth. Written by generation, `carveCrater`, `buildDryStoneGirder`. |
| `terrainFront`, `tfCtx` | canvas 3200x820 (RGBA colour of solid pixels, alpha 0 where carved) | render only; `buildDryStoneGirder` reads it back with getImageData but only to write colours; collision never reads canvas pixels |
| `terrainBack`, `tbCtx` | canvas 3200x820 (dark rock back wall) | render only |
| `mapSeed` | float, starts 2.4, `+= 1.73 + random*3.8` per generation | offsets noise; accumulates across matches (not reset) |
| `currentMapIdx` | int, random at load | M picks random map for quick play |
| `currentTerrainArchetypeName` | string label (also written to DOM `#lbl-archetype`) | |
| `currentTextureStyle` | string | |
| `currentSkyMood` | unused (null) | |
| `BG_IMAGES`, `ASSETS` | image cache / cloud canvas | render only |

---------------------------------------------------------------------------

## 3. Data tables

### 3.1 WEAPONS (S:6-198)

Order matters (index = `selectedWeaponIdx`, drawer order, `WEAPONS.findIndex`). `key` = keyboard shortcut (`e.key` compared lowercase and raw). `defaultAmmo` `Infinity` = unlimited. Ammo is per TEAM (`teamAmmo[team][id]`). Weapon is selectable only if ammo > 0.

| # | id | key | name (Catalan) | defaultAmmo | type | windFactor | fuse | blastR | maxDmg | knockback | extras |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | BAZOOKA | 1 | Trabuc | inf | CHARGE | 1.0 | - | 50 | 50 | 470 | |
| 1 | CARQUINYOLI | 2 | Carquinyolis | inf | CHARGE | 0.25 | - | 32 | 26 | 360 | fires 3 |
| 2 | GRENADE | 3 | Pinya | inf | CHARGE | 0.0 | 3.0 (`hasCustomFuse:true`, uses customGrenadeFuse) | 48 | 45 | 440 | |
| 3 | CLUSTER | 4 | Calçotada | 3 | CHARGE | 0.0 | 3.0 (`hasCustomFuse:true`) | 36 | 30 | 350 | 5 bomblets |
| 4 | URTICARIA | 5 | Urticant | 3 | CHARGE | 0.35 | - | 34 | 28 | 310 | urticating |
| 5 | SHOTGUN | 6 | Pedrenyal | inf | INSTANT | - | - | 28 | 38 | 440 | hitscan |
| 6 | FUET | 7 | El Fuet | inf | MELEE | - | - | - | 38 | 780 | reach 68 |
| 7 | BAT | 8 | La Falç | inf | MELEE | - | - | - | 34 | 690 | reach 48 |
| 8 | DYNAMITE | 9 | El Tió | 2 | DROP | - | 4.0 | 74 | 75 | 610 | |
| 9 | HOLY | 0 | Porró Sagrat | 1 | CHARGE | 0.0 | 3.5 (fixed, no custom) | 94 | 90 | 720 | |
| 10 | AIRSTRIKE | - | Correfoc | 2 | TARGET_MAP | 0.4 | - | 42 | 40 | 420 | (windFactor/blastR/maxDmg of the table are NOT used for the bombs, see 4.8) |
| 11 | JETPACK | = | Ales Pinar | 2 | UTILITY_JET | - | - | - | - | - | |
| 12 | CULLERA | u | Cullera Boix | 3 | TOOL_AIM | - | - | - | 28 | 420 | (maxDmg/knockback not used) |
| 13 | BARRINA | i | Barrina | 3 | TOOL_AIM | - | - | - | 36 | 320 | (not used) |
| 14 | PONT_PEDRA | o | Pedra Seca | 3 | TOOL_AIM | - | - | - | - | - | |
| 15 | GANXO | p | Ganxo Pastor | 3 | TOOL_AIM | - | - | - | 22 | 380 | |

(16 entries, index 0..15; the "12-weapon" header comments in the source are outdated.)

Each entry also has an `svg` string (inline `<svg viewBox="0 0 36 22">` icon) at S lines: BAZOOKA 18, CARQUINYOLI 31, GRENADE 46, CLUSTER 61, URTICARIA 73, SHOTGUN 85, FUET 96, BAT 107, DYNAMITE 120, HOLY 134, AIRSTRIKE 146, JETPACK 154, CULLERA 165, BARRINA 176, PONT_PEDRA 185, GANXO 196. Treat as UI assets: extract verbatim by script into `.svg` files (they are plain SVG; Godot imports SVG as textures) rather than copying into the doc.

Effective weapon stats at fire time (P:501-509):
```
linkedCount = min(2, activeFighter.linkedAllies.length)
dmgBoost    = 1 + 0.25*linkedCount + (castellTower?0.30:0) + (pilotaBuff?0.25:0) + (metamorphosed?0.15:0)
radiusBoost = 1 + 0.12*linkedCount + (castellTower?0.15:0) + (pilotaBuff?0.10:0)
effDmg      = round((wpn.maxDmg||0) * dmgBoost)
effBlastR   = round((wpn.blastR||0)  * radiusBoost)
effKnockback= round((wpn.knockback||0) * (1 + pilotaBoost))   // only used by melee and nothing else
```
Projectile `knockback` field = raw `wpn.knockback` (boost NOT applied), except FUET slice (480 fixed) etc.

### 3.2 MAPS (W:68-205)

Fields: `id, name, subtitle, badge, bgPath, weather, slideFriction, sky[5 hex], waterTop, waterDeep, turfCol[rgb], soilCol[rgb], rockCol[rgb], treeStyle, preferredTexture`.

| id | name | subtitle | badge | bg | weather | slideFriction | treeStyle | preferredTexture |
|---|---|---|---|---|---|---|---|---|
| MONTSERRAT | Massís de Montserrat | Monestir de Santa Maria, Agulles i Aeri (Bages) | BOIRA I PINARS | assets/bg_montserrat.jpg | POLLEN | 0.964 | UMBRELLA_PINE | CONGLOMERATE_PEBBLES |
| CADAQUES | Cadaqués i Cap de Creus | Església de Santa Maria, Llaguts i Feixes (Alt Empordà) | TRAMUNTANA VIVA | assets/bg_cadaques.jpg | GULLS_BREEZE | 0.968 | CYPRESS | SLATE_FRACTURES |
| TAULL | Taüll i la Vall de Boí | Sant Climent de Taüll i Aigüestortes (Alta Ribagorça) | NEU DEL PIRINEU | assets/bg_taull.jpg | SNOW | 0.976 | DOUGLAS_FIR | STRATA_WAVES |
| CASTELLFOLLIT | Castellfollit de la Roca | Cinglera Basàltica i Fageda d'en Jordà (La Garrotxa) | FULLES DE FAIG | assets/bg_castellfollit.jpg | AUTUMN_LEAVES | 0.966 | UMBRELLA_PINE | BASALT_COLUMNS |
| DELTA_EBRE | Delta de l'Ebre i Buda | Arrossars, Barraques, Far del Fangar i Flamencs (Montsià) | FLAMENCS I DUNES | assets/bg_delta.jpg | POLLEN | 0.960 | PALM_DELTA | TERRACOTTA_DUNES |
| TARRACO | Tàrraco Imperial | Amfiteatre Romà, Pont del Diable i Mare Nostrum (Tarragonès) | PEDRA ROMANA | assets/bg_tarraco.jpg | GULLS_BREEZE | 0.965 | CYPRESS | ASHLAR_BLOCKS |
| PEDRAFORCA | Massís del Pedraforca | L'Enforcadura, Tartera i Serra del Cadí (Berguedà) | CIM MÀGIC | assets/bg_pedraforca.jpg | SNOW | 0.972 | DOUGLAS_FIR | SLATE_FRACTURES |
| MONTBLANC | Muralles de Montblanc | Torres Medievals, Llegenda de Sant Jordi i Prades (Conca) | DRAC I ROSES | assets/bg_montblanc.jpg | AUTUMN_LEAVES | 0.966 | UMBRELLA_PINE | ASHLAR_BLOCKS |

Colours:

| id | sky[0..4] | waterTop | waterDeep | turfCol | soilCol | rockCol |
|---|---|---|---|---|---|---|
| MONTSERRAT | #2a1e2e #593b4f #9c6352 #de9659 #fae6b1 | rgba(42,114,122,0.82) | rgba(12,36,44,0.98) | 92,118,52 | 134,84,58 | 148,128,122 |
| CADAQUES | #10355c #1f5a8f #4287bd #7eb8de #cbe6f7 | rgba(18,152,178,0.82) | rgba(6,42,68,0.98) | 88,108,56 | 92,76,62 | 74,80,92 |
| TAULL | #172b47 #2c4c73 #527ca6 #8eb3d4 #d9eaf7 | rgba(48,126,162,0.82) | rgba(10,32,52,0.98) | 64,126,56 | 78,58,42 | 98,106,116 |
| CASTELLFOLLIT | #2b1d1c #633c2e #a8673e #dea05a #f7d89c | rgba(44,106,112,0.82) | rgba(14,34,38,0.98) | 118,104,46 | 86,52,38 | 64,62,68 |
| DELTA_EBRE | #2d1b38 #733857 #c45d56 #f29f60 #ffebb3 | rgba(38,166,154,0.82) | rgba(10,52,56,0.98) | 112,142,54 | 168,122,74 | 184,152,108 |
| TARRACO | #162a4a #2e557c #6e7889 #d98a54 #fce0a2 | rgba(22,138,188,0.84) | rgba(8,36,68,0.98) | 96,120,48 | 148,76,48 | 182,146,98 |
| PEDRAFORCA | #1a1636 #382e63 #5c5b94 #8ea8cf #dbf0fa | rgba(54,142,176,0.82) | rgba(14,38,58,0.98) | 58,118,68 | 88,74,68 | 118,128,146 |
| MONTBLANC | #24111c #541e33 #8f3438 #cf6a44 #f7be79 | rgba(64,96,118,0.82) | rgba(18,26,40,0.98) | 104,112,44 | 128,54,44 | 152,82,72 |

Only gameplay-relevant per-map fields: `slideFriction` (P:1023), `id` (landmark/geology branches in terrain gen, flora type, bridge colour/style choice), `turfCol/soilCol/rockCol`, `treeStyle`, `preferredTexture`. Everything else is view.
`currentMapIdx` default random in `[0,8)` (W:207); quick-play re-randomizes (M:69,83). Lobby lets user pick a theatre (M:1814-1825: sets `currentMapIdx` and calls `generateDestructibleTerrain`).

### 3.3 Terrain archetypes (W:616-625; chosen uniformly at random each generation)

| id | label (Catalan, shown in `#lbl-archetype`) |
|---|---|
| FEIXES_TERRACED | Feixes de Pedra Seca |
| AGULLES_SPIRES | Agulles i Cingles |
| MULTI_DECK_GROTTO | Cova de Dos Nivells |
| FLOATING_BALCONIES | Balcons Sospesos |
| TWIN_MASSIFS | Doble Massís |
| STEPPED_CANYONS | Congost Escalonat |
| CITADEL_CALDERA | Ciutadella Alta |
| ARCHIPELAGO | Illes Escalonades |

`TEXTURE_STYLES = [STRATA_WAVES, BASALT_COLUMNS, ASHLAR_BLOCKS, CONGLOMERATE_PEBBLES, SLATE_FRACTURES, TERRACOTTA_DUNES]` (default `currentTextureStyle` initial `'STRATA_WAVES'`). Tree styles: `UMBRELLA_PINE, DOUGLAS_FIR, CYPRESS (the `else` branch), PALM_DELTA`. Landmark pool: `WATCHTOWER, HOLLOW_LOG, ROCK_ARCH, MONOLITHS, BRIDGE_SPAN, SECOND_TOWER, BARRACA_DELTA`. Weather values (`POLLEN, GULLS_BREEZE, SNOW, AUTUMN_LEAVES`) are render only.

### 3.4 Names, hats, difficulty, modes

```
CATALAN_NAMES_POOL_0 (30): Peluda, Serrallonga, Pinassa, Rovelló, Botifarra, Calçot,
  Gaudí, Garbí, Fuet, Escudella, Barretina, Porró, Senyera, Caganer, Timbaler, Casteller,
  Enxaneta, Gralla, Sardana, Ginesta, Romaní, Pinyó, Llobregat, Montseny, Carquinyoli,
  Crema, Allioli, Romesco, Cargol, Bolets
CATALAN_NAMES_POOL_1 (30): Urticària, Tramuntana, Boira, Espina, Tió, Fageda, Ratafia,
  Empordà, Canigó, Pedraforca, Bruixa, Drac, Correfoc, Diable, Mestral, Xaloc, Llevant,
  Pissarra, Basalt, Cingle, Falç, Trabuc, ' Bandoler' (leading space, .trim() applied), Gorg,
  Albera, Cadí, Priorat, Batea, 'Lo Riu', Garrotxa
Initial teamNames[0] = Peluda, Serrallonga, Pinassa, Rovelló, Botifarra, Calçot
Initial teamNames[1] = Urticària, Tramuntana, Boira, Espina, Ratafia, Canigó
   (both immediately replaced by randomizeSquadNames(true) at load, S:262)
randomizeSquadNames(force): if hasCustomLobbyNames && !force return;
   p0 = shuffle(pool0) via sort(()=>random-0.5); p1 likewise; teamNames[t][i] = p[i].trim() for i<6.
teamHats default: ['CATALAN','BANDOLER']
ALL_HAT_STYLES: CATALAN, CASTELLER, BANDOLER, PAGES, BRISTLES  (hat choices incl. 'VARIED' in menu: M:61)
GAME_MODES = ['1P_CPU','2P_LOCAL','CPU_CPU']
MODE_SHORT = {'1P_CPU':'1J vs CPU','2P_LOCAL':'2J Local','CPU_CPU':'CPU vs CPU'}
Difficulties: 'ROOKIE' | 'VETERAN' | 'NIGHTMARE'  -> only effect: aim jitter (see 4.13)
   ROOKIE 0.095, VETERAN 0.042 (also any other value), NIGHTMARE 0.012
bodyPalettes (6, [fur, mid, dark]):
  ['#424859','#252934','#111318'] ['#4f3d36','#2e221d','#16100d'] ['#364a45','#1e2b28','#0e1514']
  ['#483b54','#282030','#130f18'] ['#4d4738','#2b281f','#14120d'] ['#384556','#1f2733','#0e131a']
dorsalPalettes0 (team 0): #f58529 #ffb338 #e66030 #ff9442 #d99b26 #f26d3d
dorsalPalettes1 (team 1): #e03a2b #ff5263 #c92a42 #eb4d36 #d43559 #ff6938
Team colours in UI: team 0 '#f5b945', team 1 '#ea5648'.
```

### 3.5 ORUGA_TAUNTS (S:278-284) and in-game strings produced by sim code

```
TURN: 'A pel pi!', 'En processó!', 'Prepara el trabuc!', 'Tasta el fuet de Vic!', 'Carquinyoli trencadents!', 'Bon cop de falç!'
HIT: 'Ai els meus pèls!', 'Quina picor!', 'Mal llamp!', 'El meu capoll!'
URTICARIA: 'Pols urticant!', 'Grata, grata!', 'Al·lèrgia total!'
PROCESSION: 'Columna unida!', 'Fúria processionària!', 'Seda i ferro!'
METAMORPH: 'METAMORFOSI!', 'Ales de Thaumetopoea!', 'Ja puc planar!'
```
Floating texts / speech bubbles (verbatim; colour and life in parentheses). All floating text objects: `{x,y,text,color,life}`, and the view drifts them up at 26 px/s:

| Where | Text | colour | life |
|---|---|---|---|
| S:393 worm switch | `¡TORN DE ${NAME.toUpperCase()}! [TAB]` | team0 '#f5b945' / team1 '#ea5648' | 1.35 |
| S:989 gust (only if TURN_PLAY and activeFighter) | `¡RÀFEGA DE TRAMUNTANA! »` (dir>0) / `« ¡VENT DE GARBÍ!` | '#f6cf77' / '#8fd8f2' | 1.55 |
| S:1115 tide | `¡MORT SOBTADA — PUJA LA MAREA!` | '#ff6b5b' | 2.2 |
| P:31 | `¡BOSSA DE SEDA REBENTADA! +PINYONS I LARVES!` | '#ffe082' | 2.1 |
| P:93 | `¡SEDA ELÀSTICA TEIXIDA!` | '#fff6df' | 1.65 |
| P:118 | `¡${name}: METAMORFOSI ALADA! (MANTÉN W PER PLANAR)` | '#ffe082' | 2.4 |
| P:262 | `¡ROVELLÓ A LA BRASA!` | '#ff9e44' | 1.6 |
| P:357 | `¡XOP DE VI DEL PRIORAT!` | '#e85d75' | 1.7 |
| P:384 | `¡ESCUDELLA EXPLOSIVA! ¡PLUJA DE GALETS!` | '#ffe082' | 1.95 |
| P:453 damage | `-${dmg}` or `${label} -${dmg}` | '#d88aff' if label=='¡URTICÀRIA!' else '#ff6b5b' | 1.45 |
| P:464 death | `¡${name} CAIGUT!` | '#f6cf77' | 1.95 |
| P:515 | `¡CASTELL DE CUCS! +30% FORÇA ENXANETA!` | '#ffd966' | 1.75 |
| P:523 | `¡FÚRIA EN PROCESSÓ! +${round((dmgBoost-1)*100)}% DANY` | '#ffe082' | 1.6 |
| P:555 | `¡CARQUINYOLIS TRENCADENTS!` | '#f6cf77' | 1.65 |
| P:676 | `¡REBOT DE MESTRE!` | '#ffd966' | 1.5 |
| P:724 | `¡ZASCA DE FUET!` | '#f4eee1' | 1.3 |
| P:755 | `¡CAGA TIÓ, CAGA TORRÓ!` | '#ffe082' | 1.8 |
| P:802 | `¡ALES DE PINAR (W/A/D)!` | '#f6cf77' | 1.8 |
| P:819 | `¡CULLERADA DE BOIX! ¡OBRINT PAS!` | '#f6cf77' | 1.75 |
| P:838 | `¡BARRINA DE MINAIRE! ¡Brrrrr!` | '#ffae42' | 1.75 |
| P:855 | `¡MARGE DE PEDRA SECA CONSTRUÏT!` | '#e8e2d5' | 1.85 |
| P:955 | `¡GANXO DE PASTOR! ¡AMUNT!` | '#ffe082' | 1.55 |
| P:972 | `¡GANXO CURT!` | '#cbd5e1' | 1.2 |
| P:1105 | `+35 PV ¡RESINA DE PI!` | '#76e082' | 1.65 |
| P:1116 | `+1 ${WEAPON NAME.toUpperCase()}!` | '#f6cf77' | 1.65 |
| P:1152 | `¡CLIC! MINA ARMADA!` | '#ff6b5b' | 1.2 |
| P:1193 | `♪ VIROLAI! AL·LELUIA! ♪` | '#f6cf77' | 1.3 |
| P:1207 | `¡CAGA TIÓ!` | '#ffae42' | 1.4 |
| P:1265 | `¡PARACAIGUDES TRENCAT!` | '#ff9e44' | 1.5 |
| P:1296 | `¡REBOT EN SEDA!` | '#fff6df' | 1.1 |
| P:1481 | `¡BENEDICCIÓ DEL CAGANER! +30 PV I +1 PORRÓ!` | '#ffd966' | 2.2 |
| P:1526 | `+25 PV ¡FORÇA DE LA PILOTA! (+25% DANY)` | '#ffd966' | 2.1 |
| P:1565 | `+20 PV ¡PINYÓ DAURAT!` | '#ffe082' | 1.75 |
| P:1695 | `¡CASTELL DE CUCS! +30% FORÇA ENXANETA!` | '#ffd966' | 1.9 |
| P:2119 | `¡BOING DE SEDA!` | '#fff6df' | 1.0 |
| P:2152 | `¡BOING DE ROVELLÓ! +8 PV` | '#ff9e44' | 1.35 |
| P:2340 | `¡CARAMBOLA!` | '#ffe082' | 1.1 |
| P:2374 drown | `${name}: Glu glu... XOF!` | '#7ec8e3' | 2.2 |

Damage labels passed to `damageFighter(label)`: `'¡URTICÀRIA!'`, `'ESCUT DE SEDA'`, `'¡PICOR URTICANT!'`, `'¡CAIXA AL CAP!'`, `'¡CREC! TRENCADENTS!'`, `'¡COP DE FUET DE VIC!'`, `'¡BON COP DE FALÇ!'`, `'¡GANXADA DE PASTOR!'`, `'¡CULLERADA!'`, `'¡BARRINA!'`, `'¡LARVES!'`, `'PATACADA!'`, `'¡CARAMBOLA!'`. Displayed as `${label} -${dmg}`.
Speech bubbles (spawnSpeechBubble(f,text,duration)): `'¡El Caganer de la Sort!'` (2.4), `'¡Quina Escudella més bona!'` (2.3), `'¡Castell de Cucs! ¡Aleta!'` (2.4), taunts above (durations: TURN 2.2, HIT 1.8, URTICARIA 2.2, PROCESSION 2.0, METAMORPH 2.4).
Turn/UI strings in S: `Torn de ${name}`, `Ronda ${roundNumber} · ${mapName}`, `Teixir Seda [C]`, `Seda Teixida ✓`, victory strings (below).

Victory strings (S:1037-1079, startNextTurn 1085-1103):
```
GAME_OVER status: team0 wins '¡Victòria de la Brigada del Pinar!' (#f5b945); team1 '¡Victòria de la Tramuntana!' (#ea5648); none '¡Destrucció Mútua — Empat!' (#f2ecdf)
Modal title: 0 '¡VICTÒRIA DE LA BRIGADA DEL PINAR!', 1 '¡VICTÒRIA DE LA COLUMNA TRAMUNTANA!', -1 '¡DESTRUCCIÓ MÚTUA — EMPAT!'
Modal sub: 0 `La Processó Daurada conquereix ${mapName}!`, 1 `La Processó Grana conquereix ${mapName}!`, else 'Tots els cucs han caigut en combat!'
Stats: 'Indret:' mapName; 'Rondes Totals:' roundNumber; 'Dany Brigada del Pinar:' teamDamageDealt[0]+' PV'; 'Dany Tramuntana:' teamDamageDealt[1]+' PV';
       'Cuc Processionari MVP:' name + ` (${dmgDealt} punts de dany)` — MVP = fighter with max dmgDealt (ties -> first; init mvp=fighters[0]).
```

### 3.6 Misc numeric tables used by sim
- Crate reward pool (S:932): `HOLY, AIRSTRIKE, DYNAMITE, JETPACK, CLUSTER, URTICARIA, CULLERA, BARRINA, PONT_PEDRA, GANXO` (uniform). Medkit chance 0.42.
- Supply drop trigger: in startNextTurn, `roundNumber > 1 && random < 0.48 && crates.length < 3`.
- HP caps: medkit 150, caganer 160, escudella 165, pine nut `maxHp = min(160, maxHp+15)` and `hp = min(maxHp, hp+20)`, rovelló +8 up to maxHp.
- Phase timer values: see 4.12 (table).

---------------------------------------------------------------------------

## 4. Algorithms

### 4.1 Noise (W:6-65)
- `PERM`: p[i]=i (0..255); `seed=4219`; for i=255..1: `seed = (seed*16807) % 2147483647; j = seed % (i+1); swap p[i],p[j]`; `PERM[i] = p[i & 255]` for i in 0..511. (LCG Lehmer/MINSTD; products fit in 2^53 and in GDScript int64.) Deterministic; independent of Math.random.
- `fade(t)=t^3*(t*(6t-15)+10)`; `lerp(a,b,t)=a+t*(b-a)`; `clamp(v,lo,hi) = isFinite(v) ? max(lo,min(hi,v)) : lo` (NaN/inf become `lo`; GDScript `clampf` does not do this: reimplement).
- `grad2(hash,x,y)`: `h=hash&7; u = h<4 ? x : y; v = h<4 ? y : x; return ((h&1)?-u:u) + ((h&2)?-2v:2v)`.
- `noise2D(x,y)`: `X=floor(x)&255, Y=floor(y)&255 (works for negatives, two's complement)`; `x-=floor(x); y-=floor(y)`; `u=fade(x), v=fade(y)`; `A=PERM[X]+Y; B=PERM[X+1]+Y`; result `lerp(lerp(grad2(PERM[A],x,y),grad2(PERM[B],x-1,y),u), lerp(grad2(PERM[A+1],x,y-1),grad2(PERM[B+1],x-1,y-1),u), v)*0.5+0.5`. Output not clamped to [0,1] exactly (gradient scale 3 means values can exceed [0,1] slightly; callers sometimes clamp). Keep exactly.
- `fbm(x,y,oct=5)`: sum of `noise2D(x*freq,y*freq)*amp`, amp starts 0.5 and halves, freq starts 1 and multiplies by 2.04, divide by sum(amp).
- `ridgedFbm(x,y,oct=5)`: `n = 1 - |noise*2-1|; n=n*n*weight; weight=clamp(n*2,0,1)` (weight starts 1), `val += n*amp`; freq*=2.12; amp*=0.5; divide by sum(amp).
- Cloud layer texture (render only, W:225): 1600x320 RGBA built per pixel from `fbm(cos(angle)*1.6+5, y*0.012, 5)*sin(vy*PI)`; threshold 0.36, density `min(1,(n-.36)*2.6)`, alpha `floor(density*135)`, rim colour lerp(165..252, 155..234, 150..214). Seamless horizontally.

### 4.2 Terrain generation `generateDestructibleTerrain(mapIdx)` (W:563-949)

Order of RNG consumption matters only if you want to reproduce a given seed; the original uses `Math.random()` unseeded, so exact sequence cannot be matched. Stage list:

1. `WATER_Y = 700; mapSeed += 1.73 + random*3.8; terrainMask.fill(0); generatedTreeSpots=[]; generatedValleySpots=[]`.
2. Texture style: `if (preferredTexture && random<0.5) currentTextureStyle=preferred else random pick of TEXTURE_STYLES`.
3. Colour variation: `turfHueShift = [round((r-.5)*28), round((r-.5)*28), round((r-.5)*22)]`, `rockHueShift = [32,28,32]`-ranges (`(r-.5)*32, *28, *32`), `soilHueShift = [(r-.5)*24, *22, *20]` (each rounded). `matchTurf = clamp(turf+shift, [32,42,24] .. [210,215,175])`; `matchSoil = clamp(soil+shift, [35,30,22] .. [210,190,165])`; `matchRock = clamp(rock+shift, [42,42,42] .. [220,215,220])`.
4. `regenerateMatchAtmosphere(mCfg)` if defined (render atmosphere; see 4.15).
5. Archetype: uniform pick among 8 (section 3.3); writes `lbl-archetype` DOM label.
6. Randomized parameters: `freqScale = 0.82 + r*0.55`; `hillAmp = 260 + r*95`; `asymTilt = (r-0.5)*90`; `numPeaks = 3 + floor(r*4)` (3..6); for each peak p: `{cx: 340 + ((p + 0.15 + r*0.7)/numPeaks)*(TERRAIN_W-680), w: 130 + r*190, amp: (r<0.62 ? -1 : +1) * (55 + r*115)}`.
7. Height profile `surfaceY[x]` (Float32Array(3200)) for each x:
   - `edgeDist = min(x-120, 3200-120-x)`; if `<0`: `surfaceY = TERRAIN_H+80 (=900)`; continue (no terrain).
   - `islandEnv = clamp(edgeDist/190,0,1)`, `smoothEnv = smoothstep(islandEnv)` = `e*e*(3-2e)`.
   - `nLarge = fbm(x*0.0016*fs + mapSeed, mapSeed, 4)`, `nMed = fbm(x*0.0042*fs + mapSeed*1.7, mapSeed+1.9, 4)`, `nDetail = ridgedFbm(x*0.0065*fs + mapSeed*2.1, mapSeed+3.1, 3)`.
   - `h = 265 + (1 - (0.52*nLarge + 0.28*nMed + 0.20*nDetail)) * hillAmp`; `h += ((x/3200)-0.5)*asymTilt`; `for rh: h += exp(-((x-rh.cx)/rh.w)^2) * rh.amp`.
   - Archetype (g(c,w) = exp(-((x-c)/w)^2)):
     - ARCHIPELAGO: `h = round(h/28)*28 + 245*g(1080,110) + 245*g(2120,110)`.
     - TWIN_MASSIFS: `h += 265*g(1600,195) - 115*g(880,230) - 115*g(2320,230)`.
     - CITADEL_CALDERA: `h += 205*g(980,145) + 205*g(2220,145) - 110*g(1600,270)`.
     - FEIXES_TERRACED: `step=46; raw=round(h/46)*46; h = lerp(h,raw,0.82) + sin(x*0.025)*6`.
     - AGULLES_SPIRES: `spire = sin(x*0.011+mapSeed)*cos(x*0.0045-mapSeed*0.5); h += spire*115 - |sin(x*0.008)|*45`.
     - MULTI_DECK_GROTTO: `h += -95*g(1600,760)`.
     - FLOATING_BALCONIES: `h = lerp(h, round(h/38)*38, 0.65) + sin(x*0.0065+mapSeed)*55`.
     - else (STEPPED_CANYONS): `h = round(h/36)*36 + (nDetail-0.5)*26; h += 175*g(1600,145)`.
   - Theatre tweak:
     - MONTSERRAT: `h += sin(x*0.015)*28 * exp(-((x-1600)/980)^2)`.
     - CADAQUES: `h += cos(x*0.005)*28 + round(sin(x*0.012)*3)*7`.
     - TAULL: `h += -|sin(x*0.0045)|*42`.
     - CASTELLFOLLIT: `h = round(h/28)*28 + sin(x*0.008)*18`.
     - DELTA_EBRE: `dune = sin(x*0.007+mapSeed)*26 + cos(x*0.019)*12; h = lerp(h, 430+dune, 0.28)`.
     - TARRACO: `tier=round(h/32)*32; h = lerp(h,tier,0.55) + cos(x*0.009)*16`.
     - PEDRAFORCA: `h += 125*g(1600,210) - 95*g(1160,190) - 95*g(2040,190)`.
     - MONTBLANC: `h += round(sin(x*0.014)*2)*14`.
   - `surfaceY[x] = lerp(WATER_Y+95, clamp(h,165,WATER_Y+65), smoothEnv)`. Note `Math.round` in JS rounds .5 up (toward +inf); GDScript `round()` rounds half away from zero: differs for negative .5 only; values here are positive except `sin()*3` rounds: use `floor(v+0.5)` to be faithful.
8. Caverns: `cavernCount = (archetype==MULTI_DECK_GROTTO) ? 4 : 2 + floor(r*3)` (2..4). For c: `frac=(c+0.5)/count; cx = 520 + frac*(3200-1040) + (r-0.5)*220; topSurf = surfaceY[clamp(floor(cx),200,3000)]; cy = clamp(topSurf + 95 + r*85, 340, WATER_Y-55); rx = (MULTI_DECK ? 210 : 135) + r*95; ry = 36 + r*20`.
9. Per-column fill (for x in 0..3199; `sy=floor(surfaceY[x])`; `slope = (surfaceY[min(3199,x+3)] - surfaceY[max(0,x-3)])/6`; for y from sy to 819):
   - `depth = y - sy`.
   - `inCavern`: only if `depth > 32 && y < WATER_Y-24`: `cavN = fbm(x*0.018+mapSeed, y*0.018, 3)*0.32`; in cavern if for any cavern `((x-cx)/rx)^2 + ((y-cy)/ry)^2 < 0.88 + cavN`.
   - Rock texture (all computed even if cavern, because back layer uses `rockVal`): `n1 = fbm(x*0.014+mapSeed, y*0.014, 3)`, `n2 = ridgedFbm(x*0.028, y*0.028, 2)`, then by `currentTextureStyle` compute `strata, texMod`:
     - BASALT_COLUMNS: `colPhase = |((x + sin(y*0.02)*4) % 18) - 9|/9` (JS `%` keeps sign of dividend; operand can be negative only if sin term pushes x+..<0 at x<4: matters at x<5; use `fposmod`? NO: JS `%` of a negative gives negative; replicate with `fmod`), `joint = |((y + floor(x/18)*11) % 34) - 17| < 1.6 ? -18 : 0`; `strata=colPhase; texMod = (colPhase>0.78 ? -16 : colPhase<0.25 ? 12 : 0) + joint`.
     - ASHLAR_BLOCKS: `row=floor(y/16); bx=(x + (row%2)*19) % 38; by=y%16; isMortar = bx<1.8 || by<1.6; blockHash = (((row*13 + floor((x+(row%2)*19)/38)*7) & 7) - 3.5); strata = isMortar ? 0.15 : 0.65; texMod = isMortar ? -22 : blockHash*4.5`.
     - CONGLOMERATE_PEBBLES: `cellX=(x+sin(y*0.05)*6)*0.085; cellY=y*0.085; peb=sin(cellX*PI)*sin(cellY*PI); strata=peb*0.5+0.5; texMod = peb>0.45 ? 16 : peb<-0.45 ? -14 : 0`.
     - SLATE_FRACTURES: `diag = sin(x*0.09 + y*0.14 + n2*3.8); strata=diag*0.5+0.5; texMod = diag>0.65 ? 15 : diag<-0.68 ? -18 : 0`.
     - TERRACOTTA_DUNES: `ripple = sin(y*0.14 + sin(x*0.025+mapSeed)*3.2); strata=ripple*0.5+0.5; texMod=ripple*14`.
     - default STRATA_WAVES: `strata = sin(y*0.075 + n1*4.2 + cos(x*0.008)*1.5)*0.5+0.5; texMod = strata>0.72 ? 12 : strata<0.25 ? -8 : 0`.
   - `rockVal = n1*0.55 + n2*0.22 + strata*0.23`.
   - Back layer pixel (always written, even in caverns): `rgb = (matchRock[0]*0.48 + rockVal*22, matchRock[1]*0.48 + rockVal*20, matchRock[2]*0.48 + rockVal*24)`, alpha 255 (typed-array assignment truncates/saturates: Uint8ClampedArray rounds-to-nearest, clamps).
   - If in cavern: `continue` (mask stays 0; front stays transparent).
   - Else `terrainMask=1` and front colour:
     - `tuftWave = sin(x*0.22 + n1*6)*2.2 + cos(x*0.09)*1.6`; `grassThick = max(5, floor(14 - |slope|*2.8 + tuftWave))`.
     - depth <= grassThick: turf: `turfLight = clamp(0.88 - slope*0.18 + (n1-0.5)*0.18, 0.54, 1.24)`; rgb = clamp(matchTurf*turfLight, 24, 255); if depth<=2: `sunRim = clamp(1.32 - slope*0.16 - depth*0.09, 1.02, 1.48); r = clamp(r*sunRim+22,0,255); g = clamp(g*sunRim+24,0,255); b = clamp(b*sunRim+12,0,255)`; else if depth >= grassThick-1: `r*=0.76; g*=0.78; b*=0.76`.
     - else if depth <= grassThick+16 (soil): `ao = depth <= grassThick+4 ? 0.74 : 0.88; soil = (0.78 + rockVal*0.36)*ao; rgb = matchSoil*soil`.
     - else (rock): `depthFade = clamp(1 - (depth-20)*0.0009, 0.72, 1); sunShade = clamp(0.92 - slope*0.14, 0.62, 1.14)*depthFade; r=(matchRock[0] + rockVal*48 + texMod)*sunShade; g=(matchRock[1] + rockVal*45 + texMod)*sunShade; b=(matchRock[2] + rockVal*49 + texMod*1.1)*sunShade`.
     - alpha 255.
   - So under every non-cavern pixel from the surface down to y=819 (including below WATER_Y) the mask is 1. Cavern ellipses are only carved above y = WATER_Y-24.
10. Sky terraces (`stampSkyTerracePlatform`), after the base fill: `numTerraces = FLOATING_BALCONIES ? 5 : 2 + floor(r*3)`; for t: `tx = floor(460 + ((t + 0.2 + r*0.6)/num)*(3200-920)); groundY = surfaceY[clamp(tx,200,3000)]; halfW = floor(72 + r*68); deckY = clamp(groundY - (78 + r*95), 185, WATER_Y-120)`.
    Stamp (W:479): thickness 24; for dx in [-halfW..halfW]: `x=floor(cx+dx)`, skip if `x<140 || x>=3060`; `edgeFrac=|dx|/halfW; archCurve = round(edgeFrac^2.2 * 10); topWave = round(sin(x*0.06)*2.5); yTop = floor(deckY+topWave); yBot = floor(deckY + 24 - archCurve + cos(x*0.09)*3)`. **Clear 38 px of headroom** above yTop (`clearTerrainPixel` for y in [yTop-38, yTop)) then fill y in [yTop..yBot]: depth<=6 turf (`sun = depth<=2 ? 1.28 : 0.96`, rgb = turfCol*sun + (depth<=1 ? [18,20,10] : 0), back colour (34,42,28)); else dry-stone: `n = noise2D(x*.12,y*.12)*24; mortar = ((floor(x/13)+floor(y/6))%2==0) ? 1.06 : 0.90; rgb = (rockCol + [24,20,16] + n)*mortar`, back colour (52,46,42). NOTE: uses `mCfg` base colours (NOT the match-shifted `matchTurf/matchRock`).
11. Landmarks: `pool = shuffle(7 ids)` via `sort(()=>random-0.5)` (biased shuffle: replicating bias is not necessary); `chosen = pool.slice(0, 2 + floor(r*2))` (2 or 3); `zones=[680,1180,1600,2040,2520]` shuffled; for idx: `zx = floor(zones[idx] + (r-0.5)*140); zy = floor(surfaceY[clamp(zx,200,3000)])`.
    - BRIDGE_SPAN: `spanHalf = 190 + r*70; deckY = min(zy-45, 340 + r*60)`; if map in {MONTSERRAT, CASTELLFOLLIT, TARRACO, MONTBLANC} or `random<0.75`: `stampRomanesqueViaduct(zx-spanHalf, zx+spanHalf, deckY)` else `stampSteelTrussSpan(..., isOrange = (mapId=='MONTSERRAT'))` (that branch can only be reached for maps not in the first set, so isOrange is effectively always false).
    - else only if `zy < WATER_Y - 45`: if `lm=='BARRACA_DELTA' || mapId=='DELTA_EBRE'` -> `stampBarracaDelta` (so on DELTA_EBRE every non-bridge landmark becomes a barraca); `WATCHTOWER/SECOND_TOWER` -> `stampStoneWatchtower`; `HOLLOW_LOG` -> `stampHollowFallenLog` (tilt `(r-0.5)*0.14`); `ROCK_ARCH` -> `stampNaturalRockArch(.., mCfg)`; `MONOLITHS` -> `stampAncientMonoliths`.
    - Stamp geometry (all write via `setTerrainPixel` which sets mask=1, writes front rgb(+alpha 255) and back rgb):
      - Watchtower (W:369): w=34,h=84; y in [sy-84, sy+12], x in [cx-34, cx+34]; crenelation: skip if `y < sy-h+10 && |x-cx|%14 > 7`; `brick = (floor(x/14)+floor(y/8))%2==0 ? 1.07 : 0.93; n = noise2D(x*.15,y*.15)*24; rgb=((148+n)*brick, (132+n)*brick, (114+n)*brick)`, back (62,54,46). Then clears (x in cx±18, y in [sy-52, sy-16]) = hollow chamber.
      - Hollow log (W:389): halfLen=78; for dx: `ly = sy - 14 + dx*tilt`; for dy -16..12: `|dy|>=9` -> bark solid `(92,58,36)*bark` where `bark=0.78+noise2D(x*.2,y*.2)*0.35`, back (44,28,18); else clear (tunnel).
      - Rock arch (W:410): span=115, archH=74; for dx in ±115: `normX=dx/115; topY = sy - 74*cos(normX*PI*0.5); botY = sy - (74-24)*max(0, cos(normX*PI*0.68))`; fill y in [floor(topY), floor(botY)] with rockCol (base mCfg.rockCol + n, n=noise2D(.08)*35), default back (38,32,28).
      - Monoliths (W:429): pillars at cx±42, x±9, y in [sy-58, sy+10], rgb (128,124,118)+n(noise .12*28), back (54,52,48); lintel y in [sy-68, sy-54], dx ±56, rgb (136,130,122)+n.
      - Viaduct (W:449): for x in [x1..x2]: `localX=x-x1; archDist=|(localX%130)-65|; maxY = deckY + 14 + ((65-archDist)/65)^2 * 44`; fill y in [floor(deckY), floor(maxY)], `brick = (floor(x/18)+floor(y/9))%2==0 ? 1.08 : 0.94`, rgb ((162+n)*brick,(126+n)*brick,(92+n)*brick) n=noise2D(.08)*26, back (68,52,38). (Note: fills a solid band whose lower edge arches; arch holes are the space below maxY... actually it fills from deck DOWN to maxY, i.e. pillar-like where archDist small.)
      - Steel truss (W:463): y in [deckY, deckY+18]; `truss = (x+y)%14<3 || (x-y+1000)%14<3 || y <= deckY+4 || y >= deckY+15`; skip pixel if `!truss && x%28 > 4`; shade = truss ? 1.08 : 0.85; orange rgb(198,68,44)*shade back (82,28,18) or grey (102,114,124)*shade back (44,50,56).
      - Barraca (W:536): w=36, wallH=30, roofH=38; whitewashed walls rgb (236,230,216)+n (noise*18 centered), back (92,86,78), y in [sy-30, sy+10]; triangular reed roof `span = round(((38-dy)/38)*(36+8))`, y = sy-30-dy, rgb ((158+n)*reed, (124+n)*reed, (74+n)*reed), `reed = (x+dy)%4==0 ? 1.08 : 0.92`, back (68,52,32); doorway clear x cx±12, y [sy-22, sy-2].
12. Trees: `treeCount = 5 + floor(r*5)` (5..9); `sectorW = (3200-560)/count`; `tx = floor(280 + i*sectorW + (r-0.5)*sectorW*0.55); ty = floor(surfaceY[clamp(tx,100,3100)])`; only if `ty < WATER_Y-50 && !isSolid(tx, ty-25)`: `scale = 0.82 + r*0.42`; style = `random<0.72 ? mCfg.treeStyle : pool[random]` where pool = `[treeStyle, treeStyle, UMBRELLA_PINE, CYPRESS, DOUGLAS_FIR, PALM_DELTA]`; `stampDestructibleTree` returns `{tx, crownY}` pushed in `generatedTreeSpots`. Stamp: trunk (base heights DOUGLAS_FIR 76 / UMBRELLA_PINE 64 / other 58, `*scale` rounded), width halfW (5.5 near ground y>ty-16 else 4.0)*scale, UMBRELLA lean `sin((ty-y)*0.04)*6*scale`; bark rgb (82,54,36)*(0.8+noise*0.4), back (42,28,20). Crowns: UMBRELLA_PINE ellipse (rx 48, ry 25)*scale, DOUGLAS_FIR 3 tiers (cy = crownY - tier*round(18s) + 12, maxW (34-7*tier)*s), PALM_DELTA 7 fronds, default (CYPRESS) ellipse rx 40 ry 20. All are solid terrain (destructible). See W:296-366 for the pixel loops; they must be ported literally if visual parity is wanted; for gameplay only the silhouettes matter.
13. Valley spots: for vx in [880,1600,2320]: `generatedValleySpots.push(floor(vx + (r-0.5)*180))`.
14. `putImageData` front/back (render upload).

Output of generation consumed by initMatch: `terrainMask`, `generatedTreeSpots`, `generatedValleySpots`, `currentTerrainArchetypeName`, `WATER_Y=700`.

### 4.3 Terrain queries (W:951-997)
- `isSolid(x,y)`: `ix=floor(x), iy=floor(y)`; **returns false if out of bounds (including y<0 and y>=820 and x outside)**; else `mask[iy*3200+ix]==1`. Out-of-bounds below the map is empty (so nothing is solid at y>=820; worms are killed by water at 700 first).
- `getSurfaceNormal(x,y)`: sums over an 11x11 window (dx,dy in [-5,5], skip centre) `nx -= dx; ny -= dy` for every solid cell; `len=hypot`; if `len<1e-4` return (0,-1) else `(nx/len, ny/len)`. 120 isSolid calls per query. Points away from solid mass (so "up" on flat ground = (0,-1)). **x,y used with floor inside isSolid**, so non-integer positions are fine.
- `findSurfaceY(x, startY=40)`: column `ix=clamp(floor(x),0,3199)`; scan down from `max(0,floor(startY))` for first solid; returns 920 (`TERRAIN_H+100`) if none.
- `findAllWalkableSurfacesAtX(x)`: column scan y in [36, WATER_Y-22): count consecutive empty cells (`airRun`); at each solid cell, if `airRun >= 26` push y (the first solid cell under a 26+ px air gap); reset airRun=0 at every solid. Returns array ascending (top tier first). Uses the *current* WATER_Y.
- `carveCrater(cx,cy,radius)` (W:1056): mask: region x,y in [c - ceil(r) - 6, c + ceil(r) + 6] clamped; for each pixel `dist=hypot(dx,dy); jitter=(noise2D(x*0.09,y*0.09)-0.5)*4.5; if dist+jitter <= radius: mask=0`. Visual: front canvas `destination-out` of a 36-gon polygon with radius `radius + (noise2D(cx*0.07+cos(a)*1.5, cy*0.07+sin(a)*1.5)-0.5)*4.5` (smooth boundary differs slightly from the mask), then `source-atop` scorch radial gradient (centre inner radius `max(2,radius-3)` to outer `radius+18`; stops: 0 rgba(24,18,15,0.85), .35 rgba(92,48,26,0.52), .7 rgba(42,30,22,0.25), 1 rgba(32,24,18,0)) drawn over circle radius+18, then back canvas `destination-out` circle radius*0.68. Visual part is pure render; in Godot do the mask edit in sim and a separate texture update from the same mask delta. Craters are not clipped to terrain bottom: they carve below water as well. Note: the mask edit ignores `y >= WATER_Y` etc.
- `buildDryStoneGirder(cx,cy,angle,length=78,thickness=16)` (W:1000): bounding box radius `ceil(halfL+halfT+6)`; for each pixel: `along = dx*cos+dy*sin; perp = -dx*sin+dy*cos; roundCap = max(0,|along|-(halfL-5)); solid if |along|<=halfL && perp^2 + roundCap^2 <= halfT^2` -> mask=1, front colour: base (154,142,124)+stoneVar+n where `row=floor((perp+halfT)/5.5); col=floor((along+halfL+(row%2)*7)/14); stoneVar=((row*7+col*13)&3)*7-10; n=(noise2D(x*.16,y*.16)-0.5)*22`; if `perp < -halfT+3.2` mossy top rgb (142+n,168+n,96+n); else if mortar `*0.68`; back pixel (64,58,50). Called with `(gx,gy,angle,82,16)` (so used length is 82, thickness 16). Girder overwrites existing terrain colours only inside shape; it never clears. It can solidify water zone? No limit except bounds: yes may build below water.

### 4.4 Spawning / match init (`initMatch(regenerateMap=true)`, S:637-848)
Called with `true` always. Sequence:
1. `generateDestructibleTerrain(currentMapIdx)` (resets `WATER_Y=700`).
2. Clear all entity arrays; `roundNumber=1; hitStopTimer=0; slowMoTimer=0; teamDamageDealt=[0,0]; teamSelectedWeaponIdx=[0,0]; selectedWeaponIdx=0`. **Note: `nextFighterId` is not reset; `silkWebUsedThisTurn`, `customGrenadeFuse`, `processionConvoyEnabled`, `aiPlan` not reset here.**
3. `teamAmmo[t][w.id] = w.defaultAmmo` for all weapons, both teams.
4. If `!hasCustomLobbyNames` -> `randomizeSquadNames(false)`.
5. Fighters: `count = clamp(wormsPerTeam,1,6)`; `usableSpan = 3200-760 = 2440`; for i<count: `frac1 = count==1 ? 0.22+r*0.18 : (i+0.15+r*0.35)/count; frac2 = count==1 ? 0.60+r*0.18 : (i+0.50+r*0.35)/count; prefX = 380 + frac*2440`; `s1 = findMultiLevelSpawnSpot(prefX1, 260, preferLower = i%2==1)`; `s2 = findMultiLevelSpawnSpot(prefX2, 260, preferLower = i%2==0)`; push `createFighter(0,i,teamNames[0][i],s1.x,+1,s1.y)` then `createFighter(1,i,teamNames[1][i],s2.x,-1,s2.y)` (so `fighters` interleaves t0,t1). Team 0 faces right (+1), team 1 faces left (-1).
6. `findMultiLevelSpawnSpot(preferredX, maxRadius=260, preferLower=false)` (S:618): for r=0,18,36,... <=maxRadius, for d in ([0] if r==0 else [-1,+1]): `testX = clamp(round(preferredX + d*r), 240, 2960)`; `tiers = findAllWalkableSurfacesAtX(testX)`; if non-empty: `chosenY = tiers[0]`; if `tiers.length>1 && (preferLower || random<0.52)` -> `chosenY = tiers[last]`; return `{x:testX, y:chosenY}`. Fallback: `fallbackX = findValidLandX(...)` -> `{x, y: findSurfaceY(x,40)}`. `findValidLandX` (S:605): same ring search with `sy=findSurfaceY(testX,40) < WATER_Y-28` returns testX; else `clamp(round(pref),260,2940)`. `Math.round` JS semantics (half up).
7. Barrels: `n = 3 + floor(r*5)` (3..7); for b: `rawX = 360 + ((b+0.3+r*0.4)/n)*(3200-720)`; `spot = findMultiLevelSpawnSpot(rawX,180, b%2==1)`; only if `spot.y < WATER_Y-22` and no fighter within 42 px of `(spot.x, spot.y)`: push `{x, y: spot.y-14, vx:0, vy:0, r:14, hp:20, grounded:true}`.
8. Mines: `n = 2 + floor(r*4)` (2..5); `rawX = 440 + ((m+0.25+r*0.5)/n)*(3200-880)`; `preferLower = m%2==0`; range 180; require `spot.y < WATER_Y-22` and no fighter within 58 px; mine `{x, y: spot.y-5, vx:0, vy:0, grounded:true, triggered:false, fuse:1.8, beepTimer:0}`.
9. Silk nests: `treeSubset = generatedTreeSpots.filter(random<0.68)`; `chosen = treeSubset.length>=2 ? subset : generatedTreeSpots.slice(0,3)`; per spot: `anchorX = tx-18; anchorY = max(85, crownY+4)`; nest `{anchorX, anchorY, x:anchorX, y:anchorY+28, r:13, hp:15, swayPhase:r*2PI, swingAngle:0, swingVel:0}`.
10. Surface flora (render objects but affects nothing in sim except removal on explosion): for `fx = 240; fx < 2960; fx += 44 + floor(r*38)`: for each tier sy from `findAllWalkableSurfacesAtX(fx)`: if `sy < WATER_Y-22 && !isSolid(fx, sy-10)` and `|getSurfaceNormal(fx,sy).x| < 0.62`: push `{x:fx, y:sy, type:mapId, variant:floor(r*3), scale:0.78+r*0.45, phase:r*2PI}`.
11. Updrafts: `shuffled = shuffle(generatedValleySpots)`; `count = 1 + floor(r*min(3,len))`; for u<count: `ux = shuffled[u]; uy = min(WATER_Y-12, findSurfaceY(ux,140))`; push `{x:ux,y:uy,w:42,h:230}`. Active region (used by P): `|x-u.x| < w && y < u.y && y > u.y-h`.
12. Rovellons: `n = 3 + floor(r*3)` (3..5); `rawX = 480 + ((r_+0.2+r*0.6)/n)*(3200-960)`; `spot = find...(rawX,160, r_%2==1)`; require `spot.y < WATER_Y-25`, no fighter within 44, no barrel within 36; push `{x, y: spot.y, r: 17 + r*4, squash:1, hp:25}`.
13. Caganers: `n = 1 + floor(r*2)`; `rawX = 620 + c*1450 + (r-0.5)*420`; `find(rawX, 200, preferLower=true)`; require `spot.y < WATER_Y-30`, no fighter within 55; push `{x, y: spot.y-8, r:11, bobPhase}`.
14. Escudelles: 2; `rawX = 920 + e*1280 + (r-0.5)*320`; `find(rawX,180, e==1)`; require `y < WATER_Y-28`, no fighter within 52; push `{x, y: spot.y-12, r:15, hp:25, steamPhase}`.
15. DOM updates (map label, victory modal close) [view].
16. `startIdx0/1 = floor(r*max(1,wormsPerTeam))`; `teamTurnIdx=[startIdx0,startIdx1]`; `activeTeam = (gameMode=='1P_CPU') ? 1 : (random<0.5 ? 0 : 1)`; then `startNextTurn()` flips `activeTeam` so **in 1P_CPU the human (team 0) starts; otherwise the first team is `1 - random choice`** (random anyway).
17. `updateHUD(); buildWeaponBar()` [view].

Gotcha: `startNextTurn` increments `roundNumber` whenever `activeTeam` becomes 0, so in a game where team 0 starts, the first turn is already "round 2" and a supply drop can spawn on turn 1 (`roundNumber>1 && random<0.48 && crates.length<3`). Keep this.

### 4.5 Turn flow (state machine)

Phases: `TURN_PLAY -> (ACTION_WAIT | RETREAT) -> ACTION_WAIT -> TURN_DELAY -> startNextTurn() -> TURN_PLAY`, or `GAME_OVER`.

`startNextTurn()` (S:1081-1190):
1. `t0Alive/t1Alive = fighters.filter(team, alive && !drowning)`. If either empty: `turnPhase='GAME_OVER'`, winner = the other team (or -1 if both empty), `SND.victory()`, `showVictoryModal(winner)`; return.
2. `activeTeam = 1 - activeTeam; if activeTeam==0: roundNumber++`.
3. Supply drop: `if roundNumber>1 && random<0.48 && crates.length<3: spawnSupplyDrop()`.
4. Tide: `if roundNumber >= 10 && WATER_Y > 460: WATER_Y -= 14` + floating text at `(activeFighter ? activeFighter.x : 1600, WATER_Y-30)` (activeFighter here is the previous one). This runs at **every** turn start (both teams) once round >= 10: 700 -> 448 in 18 steps, then stops (since `WATER_Y > 460` fails at 448).
5. Pick fighter: `teamAlive = active team's alive list (in fighters array order)`; `pickIdx = teamTurnIdx[team] % teamAlive.length; teamTurnIdx[team]++; activeFighter = teamAlive[pickIdx]`; `activeFighter.jetFuel=0; silkWebUsedThisTurn=false`.
6. Urticating itch: if `urticatingTicks>0`: `ticks--; damageFighter(f, 8, '¡PICOR URTICANT!'); spawnUrticatingHairs(...)`; if it died (`!alive`): `activeTeam = 1 - activeTeam; startNextTurn(); return` (recursion; flips back to the same team; `roundNumber` may increment again if that team is 0; **quirk: double round increment**). Note `damageFighter` sees `activeFighter === f`, so no damage credit.
7. 65%: speech bubble with random `ORUGA_TAUNTS.TURN`, 2.2s.
8. Reset: `turnPhase='TURN_PLAY'; turnTimer=30; lastTurnTickSec=30; hasActedOrMovedThisTurn=false; turnSpotlightTimer=1.9; actionWaitTimer=0; shotgunShotsLeft=1; isCharging=false; chargePower=0; aiPlan=null; cam.pan=0; impactCam.active=false; impactCam.trackedWorm=null`.
9. Aim restore: `aimPitch = f.lastAimPitch ?? -0.42; syncAimAngleFromPitch(); mouseWorld = {x: clamp(f.x + facing*260, 200, 3000), y: max(180, f.y-95)}`.
10. Weapon restore: `selectedWeaponIdx = teamSelectedWeaponIdx[team] ?? 0; if ammo(selected) <= 0: selected = 0 (and team memory = 0)`.
11. `randomizeWind()` (every turn): `windFloat = (r*2-1)*85; windTarget = clamp(windFloat + (r-0.5)*65, -100, 100); windGustTimer = 3.6 + r*2.8; wind = round(windFloat)`.
12. UI strings.

Main-loop per-frame turn FSM (M:195-291) after `updateAI` + `stepPhysics`:
```
t0Alive/t1Alive counts (alive && !drowning)
TURN_PLAY:
  actionWaitTimer=0; turnTimer -= dt (unless rotate overlay)
  tick sound at ceil(turnTimer) in 5..1
  if turnTimer<=0 || !activeFighter || !alive || drowning || t0Alive==0 || t1Alive==0: isCharging=false; turnPhase='ACTION_WAIT'
RETREAT:
  actionWaitTimer=0; phaseTimer -= dt
  if phaseTimer<=0 || activeFighter dead/drowning || any team dead: turnPhase='ACTION_WAIT'
ACTION_WAIT:
  actionWaitTimer += dt
  anyMovingFighter = any f alive && (drowning || !grounded || sliding || spoonTimer>0 || drillTimer>0 || grapple)
  anyArmedMine = any mine.triggered
  waitTimeout = (no projectiles && no planes && actionWaitTimer>3.6) || actionWaitTimer>6.2
  if (no projectiles && no planes && !anyMovingFighter && !anyArmedMine) || waitTimeout:
      if waitTimeout: projectiles=[]; planes=[]; for alive non-drowning f: vx=vy=0, sliding=false, spoonTimer=drillTimer=0, grapple=null, grounded=true
      actionWaitTimer=0; turnPhase='TURN_DELAY'; phaseTimer=2.0
TURN_DELAY:
  phaseTimer -= dt; if <=0: startNextTurn()
```
`GAME_OVER` has no timer; restart by rematch/lobby buttons or Space (M:600-650).
Where phases are set from sim code:
- `fireWeapon`: `ACTION_WAIT` for BAZOOKA, URTICARIA, CARQUINYOLI, GRENADE/CLUSTER/HOLY, SHOTGUN, AIRSTRIKE, CULLERA, BARRINA, FUET with hit/miss-slice, BAT/FUET hit, GANXO hook enemy/terrain; `RETREAT` with `phaseTimer`: BAT miss 2.2, DYNAMITE 4.0, PONT_PEDRA 2.8, GANXO barrel 2.4, GANXO miss 2.0. JETPACK does not change the phase (remains TURN_PLAY, the turn timer keeps running and the player flies).
- `triggerExplosion`: if `turnPhase==='RETREAT'` -> `ACTION_WAIT` (explosion during retreat ends retreat).
- Tools ending (`spoonTimer<=0`/`drillTimer<=0` while ACTION_WAIT) -> `RETREAT` with `phaseTimer=1.8`; grapple finished -> `RETREAT` 2.4.
- Significant fall of the active fighter during TURN_PLAY/RETREAT -> `ACTION_WAIT` (ends turn).
- AI (`updateAI`) can set `ACTION_WAIT` when no enemies or safeguard timeout.

Note that `dt` includes the slow-mo factor, so all timers (including `turnTimer` and `phaseTimer`) run slower during slow-mo (0.38x for up to `slowMoTimer` real-seconds).

### 4.6 Wind (S:965-1035)
- `randomizeWind()` at each turn start (above). `updateDynamicWind(dt)` each frame (even in menus for cloud drift):
  - `windGustFlash` decays `-= dt*1.8` (min 0).
  - Only if `appStage=='PLAYING' && turnPhase in (TURN_PLAY, RETREAT, ACTION_WAIT)`:
    - `windGustTimer -= dt`; at <=0: `strong = random<0.28`: strong: `dir = ±1 (50%)`, `windTarget = clamp(dir*(62 + r*38), -100,100)`, `windGustTimer = 4.8 + r*3.0`, `windGustFlash=1.0`, and if `turnPhase=='TURN_PLAY' && activeFighter`: sound + floating text. Else: `windTarget = clamp(windTarget + (r-0.5)*78, -96, 96); windGustTimer = 3.2 + r*2.8`.
    - `gustOsc = sin(tNow*1.75)*5.5 + cos(tNow*0.92)*3.5`; `windFloat = lerp(windFloat, windTarget, min(1, dt*0.62))`; `wind = round(clamp(windFloat + gustOsc, -100, 100))`.
  - Clouds/ribbons/birds update every frame (render only; formulas at S:1011-1034).
- Effects of `wind` in sim:
  - Projectiles: `vx += wind * 2.4 * p.windFactor * sdt` (per substep).
  - AI simulateArc: same with its own dt.
  - Parachuting crates: `vx = lerp(vx, wind*0.45, dt*3)`.
  - Moth glide: `vx = lerp(vx, facing*125 + wind*0.55, dt*3.5)`.
  - Hair particles, smoke, steam, nest torque (see P:1426), clouds etc.
- Note: JS `Math.round` for negative .5 rounds toward +inf; negligible.

### 4.7 Damage, HP, death (P:128-481)

`triggerExplosion(ex,ey,radius,maxDmg,knockback,spawnClusters=0,isUrticating=false)` (P:128-436). In order:
1. Effects/sounds (view): smoke/sparks/embers counts scaled by radius, fireball `{r:max(8,radius*.35), maxR:max(20,radius*1.45), life 1, decay 2.35}`, two shockwaves (`maxR radius*3.2` / `radius*1.95`), `shake = max(shake, radius*0.38)`, `flashLight=1`, `flashPos`.
2. `impactCam.active=true; x=ex; y=ey`; if `turnPhase=='RETREAT'` -> `ACTION_WAIT`.
3. `if radius >= 65 && appStage=='PLAYING': hitStopTimer = 0.055; slowMoTimer = 0.45` (assigned directly, not max).
4. `carveCrater(ex,ey,radius)`; `spawnRockDebris(radius*0.46)`.
5. Uproot flora: any flora with `dist <= radius*1.45` or `!isSolid(fl.x, fl.y+3)` is removed (3 debris particles each) (gameplay-irrelevant).
6. If `|ey - WATER_Y| < radius*1.5`: water plunge effect (`scale clamp(radius/55, .5, 1.35)`).
7. `hitRadius = radius * (isUrticating ? 2.1 : 1.68)`.
8. Silk nests (reverse iteration): `d <= hitRadius + nest.r` -> remove, `burstSilkNest(nest)`; else if `d <= radius*4.2` -> `nest.swingVel += sign(nest.x-ex)||1 * (1 - d/(radius*4.2)) * 12`.
9. Crates: `if d < hitRadius*1.35 && d>1: f = 1 - d/(hitRadius*1.35); vx += ((c.x-ex)/d)*220*f; vy -= 160*f; grounded=false`. (parachuting flag untouched.)
10. Mines: `d < hitRadius*1.25 && d>1: f = 1 - d/(hitRadius*1.25); vx += (dx/d)*240*f; vy -= 175*f; grounded=false; triggered=true` (blast arms mines).
11. Rovellons: `hypot(rv.x-ex, (rv.y-8)-ey) <= hitRadius + rv.r` -> removed; spawns 2 pine nuts `{x: rv.x±8, y: rv.y-14, vx: ±(55 + r*55), vy: -135 - r*55, r:6, grounded:false, life:18}`.
12. Fighters (alive && !drowning): `dx = f.x-ex; dy = (f.y-4)-ey; dist = hypot`; if `dist < hitRadius`:
    - `falloff = clamp(1 - dist/hitRadius, 0.14, 1.0)`.
    - `shieldMult = linkedAllies.length>0 ? 0.80 : 1.0`.
    - `dmg = max(1, round(maxDmg * falloff * shieldMult))`.
    - slow-mo/hit-stop if `(dmg >= 35 || f.hp <= dmg) && PLAYING`: `hitStopTimer = max(hitStopTimer, 0.045); slowMoTimer = max(slowMoTimer, 0.35)`.
    - Urticating: `f.urticatingTicks = 3` and urticaria taunt; else `random<0.55` hit taunt (1.8s).
    - `damageFighter(f, dmg, label)` with label `'¡URTICÀRIA!'` if urticating, `'ESCUT DE SEDA'` if shielded, else none.
    - Knockback: `nx = dist>1 ? dx/dist : (r-0.5); ny = dist>1 ? dy/dist : -1; imp = knockback*falloff; f.vx += nx*imp; f.vy = min(f.vy, 0) + ny*imp - 155*falloff`; `grounded=false; sliding=false; isVoluntaryJump=false; wasBlasted=true; jumpStartY=y; peakAirY=y; hurtTimer=1.0; squashX=0.68; squashY=1.42`; `impactCam.trackedWorm = f` unless it is the active fighter and one is already tracked.
    - Self damage applies: shooter can hurt himself. Allies take damage (no friendly-fire gating).
13. Barrels (reverse): `dist < hitRadius`: `b.hp -= maxDmg*(1 - dist/hitRadius)` (no falloff clamp); if `hp<=0`: remove; 22 wine particles; all alive fighters within 115 px get `wineTipsy=2` + text; **`setTimeout(70 ms)` -> `triggerExplosion(b.x,b.y,58,55,500,0,false)`** (wall-clock timer, unaffected by dt/slow-mo/hit-stop; in the port use a sim-time delayed event queue of 0.07s). Else: push: `vx += ((b.x-ex)/max(1,dist))*240; vy -= 210; grounded=false`.
14. Escudelles: `hypot <= hitRadius + ol.r`: removed, 3 "galet" CARQUINYOLI projectiles: `angle = -PI/2 + (g-1)*0.36 + (r-0.5)*0.12; speed = 210 + r*80; r:6, windFactor 0.15, bounces:true, bouncesLeft:2, fuse: 2.0 + g*0.15, lastSec:0, blastR:28, maxDmg:22, knockback:320, isGalet:true, ang:g`.
15. Clusters: `spawnClusters` BOMBLER projectiles: `spread = (i - (n-1)*0.5)*0.32 + (r-0.5)*0.12; speed = 210 + r*90; vx = sin(spread)*speed; vy = -cos(spread)*speed; pos (ex, ey-6); r:4.5, windFactor:0, bounces:false, blastR:32, maxDmg:24, knockback:310`.
16. `updateHUD()`.

`damageFighter(f,dmg,label)` (P:438):
```
if !f.alive return
actual = min(f.hp, dmg); f.hp = max(0, f.hp - dmg)
if activeFighter && activeFighter.team != f.team:   // enemy damage credit (also for fall damage/crates/larvae etc.)
    activeFighter.dmgDealt += actual; teamDamageDealt[activeFighter.team] += actual; checkMetamorphosis(activeFighter)
floating text (see table)
if f.hp<=0 && !f.drowning: f.alive=false; text; smoke; hairs; tombstone {x,y-6,vy:-140,name,team}
else checkMetamorphosis(f)
```
Self-kill and friendly damage are not credited. Dying by drowning does not go through damageFighter (hp set to 0 directly).
`checkMetamorphosis(f)`: if alive, !drowning, !metamorphosed and `(0 < hp <= 35) || dmgDealt >= 75`: `metamorphosed=true` (permanent), effects/text/bubble. Effects in sim: +15% damage in `fireWeapon`; allows glide (hold up while falling).

### 4.8 Weapons (fireWeapon, P:483-983)
Common preamble: `hasActedOrMovedThisTurn=true`; if human and `type==='CHARGE'`: `f.lastAimPitch=aimPitch; f.lastChargePower=power`; ammo `-1` (`max(0)`) unless Infinity; `dir=(cos,sin)(angle)`; `facing = dirX>=0 ? 1 : -1`; boosts (3.1); linked/castell text; `muzzle = (f.x + dirX*18, (f.y-4) + dirY*18)`.
Power in `[0,1]` (charge). Human min power on release 0.12; charge starts 0.08, grows 0.92/s, auto-fire at 1.0. Non-CHARGE weapons fire with power 1.0.

1. **BAZOOKA / URTICARIA** (Trabuc/Urticant): speed `180 + power*760`; projectile `r:5.5, windFactor: wpn.windFactor (1.0 / 0.35), bounces:false, isUrticating: id==URTICARIA, blastR:effBlastR, maxDmg:effDmg, knockback:wpn.knockback`; explodes on impact with terrain/fighter (within `f.r + p.r` of `(f.x, f.y-4)`, after age>0.06) or nest. `ACTION_WAIT`.
2. **CARQUINYOLI**: 3 projectiles, `angle + (k-1)*0.085`, speed `(210 + power*680) * (1 - |k-1|*0.06)`, `r:5.5, windFactor:0.25, bounces:true, bouncesLeft:3, fuse: 2.3 + k*0.16, blastR/maxDmg effective, knockback 360, ang:k*1.1`. Bounce/behaviour below. Each carquinyoli hits a fighter without exploding: `damageFighter(f,12,'¡CREC! TRENCADENTS!')`, `vx += sign(p.vx||1)*165; vy=min(vy,-110)`, `wasBlasted`, rebounds the projectile `(-0.65 vx, -|vy|*0.65 - 60)`, cooldown 0.16 s. After `bouncesLeft<=0` (checked on terrain contact: decrement first, explode when 0) or fuse expiry -> explosion (when exploding from bounce uses `spawnClusters 0, urticating false`). `ACTION_WAIT`.
3. **GRENADE / CLUSTER / HOLY**: speed `150 + power*680`; `r: HOLY?8:6`, `windFactor:0`, `bounces:true`, `fuse = hasCustomFuse ? customGrenadeFuse : wpn.fuse (3.5 for HOLY)`, `lastSec: ceil(fuse)`, `clusters: CLUSTER?5:0`. `ACTION_WAIT`.
   Detonation = fuse expiry only (they bounce off terrain; also explode if far OOB / water kills). They do not explode on fighter contact (bounces=true: fighter contact ignored unless CARQUINYOLI). Silk-nest contact does explode (p.blastR*0.75).
4. **SHOTGUN (Pedrenyal)**: hitscan: for `d = 4; d < 920; d += 3`: point `(muzzle + dir*d)`; hit if `isSolid`, or any alive non-drowning fighter != shooter within `f.r+4` of `(f.x, f.y-4)`, any barrel within `b.r+3`, any nest within `nest.r+3`; stop at first hit; `triggerExplosion(hitX,hitY,effBlastR,effDmg,wpn.knockback,0,false)`; beam particle; `shotgunShotsLeft=0`; `ACTION_WAIT`. If nothing is hit within 920 px the explosion still happens at the endpoint `(muzzle + dir*917)`.
5. **FUET / BAT (melee)**: `batSwingTimer=0.48`; reach = 68 (fuet) / 48 (bat). (a) Every projectile within `reach+18` of the fighter centre is deflected: `vx = dirX*640; vy = dirY*640 - 115; if fuse defined: fuse = max(fuse, 1.8)`, "REBOT DE MESTRE", counts as a hit. (b) Every other alive fighter (including allies) within `reach` of the centre: `damageFighter(f, effDmg, label)`, `vx = dirX*effKnockback; vy = min(isFuet?-185:-210, dirY*effKnockback - (isFuet?95:120))`, `grounded=sliding=false; isVoluntaryJump=false; wasBlasted=true; jumpStartY/peakAirY=y; dizzyTimer=2.8; squash (0.52,1.65)`, impactCam on target, shockwave. (c) If any hit: `hitStopTimer=0.068; slowMoTimer=0.52` (PLAYING only), `shake=15`, `ACTION_WAIT`. Else if FUET: spawns a "slice" projectile CARQUINYOLI `{isFuetSlice:true, vx: dirX*520, vy: dirY*520 - 40, r:5.5, windFactor:0.2, bounces:false, blastR:26, maxDmg: round(effDmg*0.75), knockback:480}` -> `ACTION_WAIT`. Else (BAT miss): `RETREAT`, `phaseTimer=2.2`.
6. **DYNAMITE (El Tió)**: single drop projectile at `(f.x + facing*12, f.y-6)`, `vx=facing*28; vy=-40`, `r:7, windFactor:0, bounces:true, fuse:4.0, lastSec:4, blastR/maxDmg effective, knockback 610`; `RETREAT` `phaseTimer=4.0` (the turn timer is replaced by a retreat countdown; an explosion while in RETREAT forces `ACTION_WAIT`). It ignores the aim angle (uses facing).
7. **AIRSTRIKE (Correfoc)**: `tx = targetPt ? targetPt.x : 1600; fromLeft = tx >= 1600; plane {x: fromLeft ? tx-720 : tx+720, y:58, vx: fromLeft ? 820 : -820, targetX:tx, dropped:[5 false], offsets:[-105,-52,0,52,105]}`; in `stepPhysics`: plane `x += vx*dt`; for each unreleased bomb k, when plane passes `targetX + offsets[k]`: push projectile `{type:'BAZOOKA', x:pl.x, y:pl.y+14, vx:pl.vx*0.22, vy:140, r:5, windFactor:0.4, bounces:false, blastR:42, maxDmg:38, knockback:390}` (fixed values, **no boosts, not the table's 40 dmg**). Plane removed when `|x - targetX| > 820 || x<-300 || x>3500`. Human target `mouseWorld.x` (chosen with up/down keys: `mouseWorld.x -= pitchInput*facing*420*dt`, clamped [120,3080]). `ACTION_WAIT`.
8. **JETPACK (Ales Pinar)**: `jetFuel=100; grounded=false; isVoluntaryJump=true; jumpStartY=y; vy=-150`; `selectedWeaponIdx=0` (and team memory 0 if human); no phase change. While `jetFuel>0` and controllable: up: `vy = max(-240, vy - 760*dt)`; left/right: `vx` ±420*dt capped ±190 and sets facing; if any thrust: `jetFuel -= 28*dt`, `grounded=false`, `isVoluntaryJump=true`, `jumpStartY=peakAirY=y` (no fall damage while thrusting). Lasts ~3.57 s of thrust. The weapon uses 1 ammo even if never thrusted. `startNextTurn` zeroes jetFuel.
9. **CULLERA (Cullera Boix)**: `spoonTimer=2.15; spoonAngle = clamp(angle, -0.85PI, 0.85PI); spoonTick=0`; `ACTION_WAIT`. Per frame in stepPhysics (P:1738): the fighter moves `+= (cos*64, sin*42)*dt` (clamped x[28,3172], y[38,WATER_Y-18]), steering `spoonAngle -= 0.9*dt*facing` (up) / `+=` (down) for human-active; `grounded = isSolid(x, y+r+2)`; every 0.085 s: `carveCrater(f + dir*15, f.y-2 + sinDir*10, 19)`; fling enemies/allies within 28 px: `damageFighter(14,'¡CULLERADA!')`, `vx = sDirX*320; vy=-210; wasBlasted...`; barrels within 28: `vx = sDirX*280; vy=-190`. After end -> `RETREAT` 1.8 (only if `turnPhase==ACTION_WAIT`). While active, the rest of the fighter physics is skipped (`continue`), so no gravity; at the end it falls normally.
10. **BARRINA**: `dAng = angle; if sin(dAng) < 0.22: dAng = facing>=0 ? 1.05 : PI-1.05`; `drillTimer=1.95`; per frame: `f += (cos*52, max(0.25,sin)*56)*dt` (clamps x[28,3172], y[38,WATER_Y-22]); every 0.08 s `carveCrater(f + dir*14, 16)`; hurts others within 26 px: `damageFighter(7,'¡BARRINA!'); vx = (dDirX||0.4)*160; vy=-120`. `shake = max(shake, 3.5)` each frame. End -> `RETREAT` 1.8.
11. **PONT_PEDRA**: `buildDryStoneGirder(f.x + dirX*52, (f.y-4) + dirY*52, angle, 82, 16)`; `RETREAT` `phaseTimer=2.8`.
12. **GANXO**: ray `d=12..480 step 4` from muzzle; abort if `ry >= WATER_Y-6 || rx<20 || rx>3180`; first hit among enemies (alive non-drowning, != shooter, within `f.r+8` of `(x,y-4)`), then barrels (`b.r+6`), then terrain. Enemy hit: `damageFighter(effDmg,'¡GANXADA DE PASTOR!')`, `vx = -dirX*360; vy = min(-160, -dirY*280 - 95)`, `dizzyTimer=2.0`, ACTION_WAIT. Barrel hit: `vx=-dirX*310; vy=-170`; `RETREAT 2.4`. Terrain hit: `carveCrater(hit - dir*10, 15)`, grapple `{startX,startY=f pos, targetX: clamp(hitX - dirX*14, 28, 3172), targetY: clamp(hitY - dirY*14, 42, WATER_Y-28), hookX/Y, progress:0}`; ACTION_WAIT. Miss: beam 260 px, `RETREAT 2.0`. Grapple update (P:1846): `progress = min(1, progress + dt*2.6)`; `ease = 1 - (1-progress)^2.2`; `x = lerp(startX,targetX,ease); y = lerp(startY,targetY,ease) - sin(progress*PI)*18`; v=0; no gravity; at progress>=1: `grapple=null; grounded = isSolid(x, y+r+2)`; `RETREAT 2.4` if ACTION_WAIT.

Note unused table values: `AIRSTRIKE.maxDmg/blastR/knockback/windFactor`, tool maxDmg/knockback (CULLERA/BARRINA/GANXO damage numbers are hard-coded in stepPhysics: 14, 7; GANXO uses `effDmg` = 22 boosted). `effKnockback` only used by melee.

### 4.9 Projectile physics (stepPhysics P:1175-1422)
Per frame for each projectile (reverse iteration):
1. `age += dt`.
2. Cleanup: if `age > 8 || x < -380 || x > 3580 || y > WATER_Y + 60`: remove; if it has a `fuse` and `x in [-100,3300] && y < WATER_Y`: explode there (`triggerExplosion(p.x,p.y,blastR,maxDmg,knockback,clusters||0,!!isUrticating)`). (Non-fuse projectiles are silently removed.)
3. Fuse: `fuse -= dt`; HOLY choir at `fuse <= 1.35` (once; text + sound); tick sound when `ceil(fuse) < lastSec && >0`; at `fuse <= 0` -> remove and explode (DYNAMITE also text `¡CAGA TIÓ!`).
4. 4 substeps (`SUBS=4, sdt=dt/4`), each:
   - `vx += wind*2.4*(windFactor||0)*sdt`.
   - Updraft: for each updraft with `|p.x-u.x| < u.w && p.y < u.y && p.y > u.y-u.h`: `vy -= 145*sdt`.
   - `vy += GRAVITY*sdt; x += vx*sdt; y += vy*sdt; if ang defined: ang += vx*0.015*sdt`.
   - Water: `y >= WATER_Y`: plunge effect (`scale 0.75`), `impactCam` at `(x, WATER_Y-24)`, remove (no explosion), stop.
   - Silk nests: `hypot <= nest.r + p.r + 2`: nest removed + `burstSilkNest`; projectile removed; `triggerExplosion(p.x,p.y,p.blastR*0.75,p.maxDmg,p.knockback,clusters||0,urticating)`.
   - Crate parachute snipe: crates with `parachuting && hypot(p.x - c.x, p.y - (c.y-20)) <= 18` -> `c.parachuting=false` (does not remove projectile).
   - Silk web ricochet (after age>0.08): closest point on segment; `dist <= p.r + 5` and `(_lastWebBounce||0) < age - 0.12`: normal `(-dy/len, dx/len)` flipped to oppose motion; reflect `v - 2(v.n)n`, scaled 0.92; `w.vibration=1; w.hp--; remove web if hp<=0`; break out of web loop (doesn't stop the substep).
   - Fighter contact (age>0.06): any alive non-drowning fighter (including the shooter and allies) with `hypot(f.x-p.x, (f.y-4)-p.y) <= f.r + p.r`: if `!p.bounces` -> explode at p; else if CARQUINYOLI (cooldown) -> bite behaviour (4.8-2). Other bouncing types ignore fighters.
   - Terrain: `isSolid(p.x,p.y)`: if `!bounces` -> remove + explode at `(p.x,p.y)` (impact point inside the solid pixel). Else: step back (`p.x -= vx*sdt; p.y -= vy*sdt`); for CARQUINYOLI with bouncesLeft: decrement, debris; if <=0: remove, explode with `clusters=0, urticating=false`; normal `n = getSurfaceNormal(p.x,p.y)` (at the pre-collision position); `vn = v . n`; if `vn < 0`: restitution `CARQUINYOLI 0.82 / DYNAMITE 0.15 / HOLY 0.42 / else 0.62`, friction `CARQUINYOLI 0.94 / DYNAMITE 0.35 / else 0.88`; tangent `t=(-n.y, n.x)`; `v = (-vn*rest)*n + (vt*fric)*t`. If the step-back leaves the projectile still embedded the next substep can re-trigger; a stuck fuse-based item will eventually detonate at fuse expiry.
5. After substeps: record `trail` (14 points, render), whistle sound, smoke/sparks (render).
Explosion triggers pass the projectile's own `blastR` etc.

Mines (P:1128): if not grounded: `vy += G*dt; pos += v*dt`; remove at `y >= WATER_Y` (no splash); `isSolid(x, y+5)` -> climb out `while isSolid(x,y+4) && y>0: y--`, grounded. If grounded and `!isSolid(x, y+7)`: ungrounded. Trigger: any alive non-drowning fighter within 38 px of `(f.x, f.y)` -> `triggered=true, beepTimer=0`; then `fuse -= dt` (1.8 s), beep interval `max(0.12, fuse*0.28)`; at `fuse <= 0`: remove + `triggerExplosion(m.x, m.y, 50, 48, 480, 0, false)`. A mine triggered by a blast is blown away and also armed. Mines count in "anyArmedMine" for turn-wait.

Crates (P:1056): spawn at `(300 + r*2600, -30)`, `vy=55`. Parachuting: `vx = lerp(vx, wind*0.45, dt*3); vy = 62`. Not parachuting (sniped) free-fall `vy += G*dt`. `y >= WATER_Y` -> splash + remove. Landing `isSolid(x, y+11)` -> climb `while isSolid(x,y+10)`, grounded, `parachuting=false`. Grounded and `!isSolid(x,y+13)` -> falls again. Pickup (every frame): alive fighter within 24 px of `(c.x,c.y)`; if the crate is in free-fall with `vy > 140` it first deals 18 damage `'¡CAIXA AL CAP!'` (and if that kills, crate removed w/o reward); medkit: `hp = min(150, hp+35); urticatingTicks=0`; else `teamAmmo[f.team][rewardWpn] += 1` (`(x||0)+1`). Crates also pushed by explosions (4.7-9).

Rovellons / caganers / escudelles / pine nuts / barrels / tombstones / larvae: see lines P:1440-1651. Key numbers: rovelló/caganer/escudella fall at 140 px/s when unsupported (`!isSolid(x, y+3)`, `y+10`, `y+13` respectively) and vanish at `y >= WATER_Y`; caganer pickup radius `f.r + cg.r + 10 = 33`: `hp = min(160, hp+30); urticatingTicks=0; ammo HOLY +1, DYNAMITE +1`; escudella pickup radius `f.r + ol.r + 8 = 35`: `hp = min(165, hp+25); pilotaBuff=true (permanent for the match, never cleared!); urticatingTicks=0`; pine nuts pickup radius `f.r + 6 + 6 = 24`: `maxHp = min(160, maxHp+15); hp = min(maxHp, hp+20)`; nut physics: gravity, bounce `vy*=-0.38, vx*=0.65`, grounded when `|vy|<22`, lifetime 18 s. Barrel: gravity when not grounded, lands with `vy=0, vx*=0.4; grounded if |vx|<5`; splash on water. Larvae swarm: seeks nearest alive fighter horizontally (`vx = lerp(vx, sign*88, dt*5)`), hops on ground (`vy=-55`, climbs out of terrain), falls with `vy` capped 260, lives 5.5 s, `tickTimer 0.65` damage 4 to nearest if within 22 px. Tombstone: falls with gravity (cap 350) and bounces 0.25.

Silk nests: pendulum: `windTorque = wind*0.0045 + sin(tNow*2.4 + swayPhase)*(0.14 + |wind|*0.002)`; `swingVel = (swingVel + (windTorque - swingAngle*6.5)*dt) * 0.28^dt`; `swingAngle = clamp(swingAngle + swingVel*dt, -0.95, 0.95)`; `x = anchorX + sin(angle)*28; y = anchorY + cos(angle)*28`. Burst: 3 pine nuts + larvae swarm + hairs (P:27-61): nuts at `(nest.x+(k-1)*10, nest.y)`, `vx=(k-1)*65 + (r-0.5)*35`, `vy = -120 - r*55`; swarm `{x:nest.x, y:nest.y+8, vx:0, vy:40, life:5.5, tickTimer:0.45}`.
Silk web: `spinElasticSilkWeb` (P:63): once per turn (human key C/button; `phase TURN_PLAY or RETREAT`): centre `(f.x + cos(aim)*46, (f.y-6) + sin(aim)*46)`, perpendicular half-span 38; `hp:3, vibration:1, team`. Webs persist until broken (3 bounces) or match end; vs projectiles (`p.r+5`), vs falling fighters (4.10). Hair particle count 12.

Airstrike: see 4.8-7.

### 4.10 Caterpillar physics (stepPhysics fighter loop, P:1658-2383)
Per frame, sequence:
1. **Links/castell** (all fighters): dead/drowning -> clear. `linkedAllies = allies alive within 52 px (hypot of f.x,f.y)`; speech bubble `PROCESSION` if active fighter gained links; `castellTower = exists ally with |dx| <= 20 && f.y < other.y - 4 && other.y - f.y <= 34`.
2. For each `alive` fighter: `squash` lerp to 1 (`dt*11`), `hurtTimer/dizzyTimer/batSwingTimer` decay.
3. **Drowning branch**: `drownTimer -= dt; vx *= 0.92; vy = 42; x += vx*dt; y += vy*dt; walkCycle += dt*18; bubbles`; when `drownTimer <= 0 || y > 855`: `alive=false; drowning=false`; continue (skips everything else).
4. Tool branches (spoon, drill, grapple) each `continue`.
5. Grounded check: if `grounded` and none of `isSolid(x, y+r+2)`, `(x-4, y+r+2)`, `(x+4, y+r+2)`: `grounded=false; sliding=false; slideAngle=0; jumpStartY=peakAirY=y; isVoluntaryJump=false` (walked off a ledge).
6. `if grounded && !sliding: vx=vy=0; slideTimer=0; airTimer=0; peakAirY=y`.
7. **Jetpack** (4.8-8).
8. **Walking** (active fighter, grounded, not sliding, and `canControl` or `(AI && aiPlan.walkDir != 0)`): `canControl = PLAYING && phase in (TURN_PLAY,RETREAT) && activeFighter alive && !drowning && !AI turn`. moveDir = left/right keys (left wins) or `aiPlan.walkDir`. If `moveDir != 0 && !isCharging`: facing update; `walkCycle += dt*12`; `stepX = clamp(x + moveDir*78*dt, 30, 3170)`; search `dy` from -9 to 10 for first `dy` where `!isSolid(stepX, y+dy) && isSolid(stepX, y+r+dy)`: if found: `x=stepX; y = y+dy` (slope climbing up to 9 px/step... per frame!, 10 down), reset jumpStartY/peakAirY; else if `!isSolid(stepX, y)` (cliff): `x=stepX; grounded=false; isVoluntaryJump=false; ...` (walk off edge); else blocked (wall) -> no movement. Procession convoy (if `processionConvoyEnabled` and links): allies in `linkedAllies` order follow: `desiredX = leaderX - moveDir*30`; if `|diff|>4`: `allyStepX = ally.x + sign*min(|diff|, 74*dt)`; slope search same dy range; `leaderX = ally.x` each. Only grounded non-sliding allies. Note: `hasActedOrMovedThisTurn = true` set when human moves.
9. **Sliding** (grounded && sliding): `slideTimer += dt; frictionBase = isMinorSlide ? 0.90 : map.slideFriction; vx *= frictionBase^(dt*60); stepX = clamp(x + vx*dt, 24, 3176); facing = sign(vx)`; find slope y as in walking with dy -10..12; found: `x=stepX; y=foundSlopeY; vx += dySlope*(minor?10:18)*dt; slideAngle = clamp(dySlope*0.12,-0.5,0.5)`; elif air: leave ground (`grounded=false, sliding=false...`); else (wall) `vx = -vx*0.4`. End: `|vx| < (minor?24:18) || slideTimer > (minor?0.42:2.2)`: `vx=vy=0; sliding=false; squash(0.88,1.14)`.
10. **Airborne** (`!grounded`): `airTimer += dt; peakAirY = min(peakAirY, y)`; glide (metamorphosed && active && canControl && keys.up && vy>25): `vy = lerp(vy,48,dt*9); vx = lerp(vx, facing*125 + wind*0.55, dt*3.5); jumpStartY=peakAirY=y; isVoluntaryJump=true`; updraft lift: `vy -= (metamorphosed&&keys.up ? 620 : 240)*dt` if inside; flip spin: `flipAngle += flipSpin*dt`; `vy += 440*dt`; then **4 substeps**: `x = clamp(x + vx*dt/4, 18, 3182); y += vy*dt/4; peakAirY = min(...)`; and inside each (in order):
    - if `vy>0`: silk web trampoline (closest point to `(x, y + 0.6r)` within 10 px): `vy = -max(215, min(310, |vy|*0.95)); vx = clamp(vx*1.08, ±190); jumpStartY=peakAirY=y; isVoluntaryJump=true; wasBlasted=false; squash; web hp--` -> break substeps; rovelló trampoline (`|x - rv.x| <= rv.r+5 && |(y + 0.7r) - (rv.y-10)| <= 13`): `vy = -max(255, min(340, |vy|*1.15 + 120)); vx = clamp(vx*1.12 + facing*35, ±210); +8 hp (cap maxHp); urticatingTicks=0; rv.squash=0.42` -> break.
    - **Landing**: `isSolid(x, y+r)`: `while isSolid(x, y+r-1) && y>0: y--` (pop out), then compute `vertSpeed=|vy|, horizSpeed=|vx|, totalSpeed=hypot, fallDrop = y - jumpStartY, dropFromPeak = y - peakAirY, n = getSurfaceNormal(x, y+r), t = (-n.y, n.x), tangentSpeed = v.t, slopeSteepness=|n.x|`. 
      ```
      isSignificantFall = (fallDrop >= 88 || dropFromPeak >= 126) || (wasBlasted && (vertSpeed > 235 || totalSpeed > 285))
      isLittleFall = !isSignificantFall && !wasBlasted && (fallDrop >= 12 || dropFromPeak >= 54 || (vertSpeed > 155 && slopeSteepness > 0.22))
      if isSignificantFall && (vertSpeed > 210 || totalSpeed > 260 || fallDrop >= 88):
          shake = max(shake, clamp((totalSpeed-210)*0.038, 3, 14))
          squashMag = clamp((totalSpeed-200)/340, 0.25, 0.62)
          excessDrop = max(dropFromPeak - 115, fallDrop - 78, 0)
          fallDmg = clamp(round(6 + excessDrop*0.22 + max(0, totalSpeed-250)*0.06), 6, 45)
          damageFighter(f, fallDmg, 'PATACADA!'); dizzyTimer = 2.8
          if totalSpeed > 360 || dropFromPeak > 150: carveCrater(x, y+r-2, 14); while !isSolid(x,y+r) && y < WATER_Y: y++
          if f is activeFighter && phase in (TURN_PLAY,RETREAT): isCharging=false; chargePower=0; jetFuel=0; impactCam focus; turnPhase='ACTION_WAIT'   // fall ends the turn
      flipAngle=flipSpin=0; airTimer=0; peakAirY=y
      if isLittleFall: slideDir = horizSpeed>8 ? sign(vx) : (|tangentSpeed|>12 ? sign(tangentSpeed) : (n.x!=0 ? sign(n.x) : facing));
           v = slideDir*clamp(horizSpeed*0.68 + max(0,fallDrop)*0.95 + slopeSteepness*48, 46, 128); vy=0; grounded; sliding; isMinorSlide=true; slideTimer=0
      elif isSignificantFall || wasBlasted:
           slideMag = horizSpeed*0.82 + max(0, vertSpeed-195)*(0.45 + slopeSteepness*0.6)
           if slideMag > 44 || horizSpeed > 85: slideDir = |tangentSpeed|>18 ? sign(tangentSpeed) : (horizSpeed>5 ? sign(vx) : (n.x!=0 ? sign(n.x) : facing)); vx = slideDir*clamp(slideMag,52,380); sliding=true; isMinorSlide=false
           else stand still (grounded, not sliding)
      else clean landing: v=0, grounded, no slide, squash(1.14,0.88)
      wasBlasted=false; isVoluntaryJump=false; jumpStartY=y; break
      ```
      (Note: fall damage can occur while `wasBlasted` and not just a fall; it happens only through the `isSignificantFall && (...)` condition. Note a falling fighter's `sign(0)=0` for n.x==0 case: JS `Math.sign(0)` returns 0 -> velocity 0 slide.)
    - Ceiling: `isSolid(x, y-r) && vy<0` -> `vy = -vy*0.35`. Wall: `isSolid(x + sign(vx)*r, y)` -> `vx = -vx*0.55` (when `vx==0` sign=0 -> checks centre cell).
    - After the loop: if still airborne and `airTimer > 4.5 && jetFuel<=0`: force `vx=vy=0; grounded=true; sliding=false; airTimer=0` (stuck safeguard).
11. `grounded && !sliding -> vx=vy=0`.
12. **Billiards** (`sliding || wasBlasted || (!grounded && speed>155)) && speed > 95`): for other alive non-drowning fighter with `0 < d < f.r + other.r - 2 (=22)` and cooldown `_lastKnockTime < tNow - 0.28`: `other.vx = nx*max(125, |f.vx|*0.78) + f.vx*0.25; other.vy = min(-95, f.vy*0.45 - 80)`; other `grounded=sliding=false; wasBlasted=true`; `f.vx *= 0.48`; if `fSpeed > 195 && enemy team`: `damageFighter(other, 6, '¡CARAMBOLA!')` else text only. Barrels within `f.r + b.r`: `b.vx += (dx/d)*max(95, fSpeed*0.55); b.vy=-85; f.vx *= 0.55` (cooldown 0.25).
13. `updateOrugaSegments(f, dt)` (cosmetic, see 4.11).
14. **Water**: `y >= WATER_Y && !drowning`: `drowning=true; drownTimer=1.85; hp=0; vy=45` + plunge + text; the fighter stays `alive` for 1.85 s but counts as not alive for team counts. No tombstone; no `damageFighter`.

### 4.11 Segments (`updateOrugaSegments`, P:988)
6 trailing segments chain: `leadX=f.x; leadY=f.y+3; spacing 5`; per i: `targetX = leadX - facing*5`; `wave = (grounded && !sliding) ? sin(walkCycle*1.35 - i*0.95)*2.2 : sin(tNow*14 - i*0.8)*1.5`; `seg.x = lerp(seg.x, targetX, min(1, dt*(18 - i*1.4)))`; `desiredY = leadY + wave*0.45`; if grounded & !drowning: first `dy in [-6,8]` with `!isSolid(seg.x, f.y+dy) && isSolid(seg.x, f.y+10+dy)` -> `desiredY = f.y + 3 + dy + min(0, wave)`; `seg.y = lerp(seg.y, desiredY, min(1, dt*16))`; next lead = this seg. Purely visual (not used for collisions/damage); reads terrain. Fully replaceable by a view-side node, but needs `isSolid`.

### 4.12 Timers and numeric summary
Turn: 30 s play; RETREAT 1.8-4.0 (by weapon); ACTION_WAIT up to 6.2 s (3.6 s if nothing flying); TURN_DELAY 2.0 s. Tide starts at round 10. Water: `WATER_Y` 700 (`TERRAIN_H` 820). Fighter death: HP<=0 via damage, or drown. Urticating: `urticatingTicks` 3 after urticating blast; each of that fighter's own turn starts costs 8 HP and decrements; cured (set 0) by any health pickup (medkit, caganer, escudella, pine nut, rovelló bounce).

### 4.13 AI (`updateAI(dt)`, P:2504-2636)
Runs each frame before `stepPhysics` when `appStage=='PLAYING'` (also during splash when stage != PLAYING? no: only called when PLAYING; but `isCurrentTurnAI()` returns true whenever not PLAYING, which makes the physics treat everything as AI-controlled in menus). Guard: returns unless `isCurrentTurnAI() && turnPhase=='TURN_PLAY' && activeFighter alive && !drowning`.

Plan creation (once per turn, `aiPlan==null`):
1. `enemies = alive non-drowning fighters of the other team`; none -> `ACTION_WAIT`.
2. Sort enemies by distance to active fighter (centre to centre). `target = enemies[random<0.75 ? 0 : floor(random*len)]` (75% nearest + 25% uniform over all, incl. nearest).
3. `distToNearest = distance to enemies[0]` (nearest, not target).
4. Weapon: `r = random()`. if `distToNearest < 64`: `FUET` (60%) or `BAT` (40%) (consumes the `random()` call separately: `Math.random()<0.6`). Else: `r<0.14 && ammo[HOLY]>0 -> HOLY; r<0.26 && AIRSTRIKE>0 -> AIRSTRIKE; r<0.40 && URTICARIA>0 -> URTICARIA; r<0.54 && CLUSTER>0 -> CLUSTER; r<0.70 -> CARQUINYOLI; r<0.84 -> GRENADE; else BAZOOKA`. (Falls through to later branches if ammo is 0, e.g. r=0.1 with no HOLY goes to `r<0.70` -> CARQUINYOLI.) AI never uses DYNAMITE, SHOTGUN, JETPACK, tools. Ammo is consumed as normal by `fireWeapon` (AI team uses `teamAmmo` too; crates reward AI).
5. Sets `selectedWeaponIdx` (the global) to the chosen weapon (UI side effect; note it does not change `teamSelectedWeaponIdx`).
6. Plan: `{target, wpn, angle: target.x>=f.x ? -0.28PI : -0.72PI, power:0.65, walkDir: distToNearest<45 ? 0 : (random<0.5 ? 1 : -1), walkTime: distToNearest<45 ? 0.08 : (0.45 + r*0.40), aimComputed:false, aimTime:0.55, totalTime:0, executed:false}`.
Execution (every frame): `totalTime += dt`;
- while `walkTime > 0`: `walkTime -= dt; return` (walking is performed by stepPhysics at 78 px/s through `aiPlan.walkDir`; slope/edge rules identical to human; AI can walk off cliffs/into water — no check).
- then `walkDir = 0`.
- Aim compute (once, after walking): target revalidated (if dead, first alive enemy; none -> `ACTION_WAIT`). Default angle `target.x>=f.x ? -0.32PI : -0.68PI`, power 0.65. If `wpn.type=='CHARGE'` (BAZOOKA, CARQUINYOLI, GRENADE, CLUSTER, URTICARIA, HOLY): brute force search: `dir = target.x>=f.x ? +1 : -1`; for `aDeg = 18..78 step 4` (16 values) with `ang = dir>0 ? -aDeg*PI/180 : -PI + aDeg*PI/180`; for `pwr = 0.28 .. 0.98 step 0.05` (accumulated float, ~15 values; loop condition `pwr <= 0.98` with float accumulation: 0.28,0.33,...,0.98 -> probably 15 values, last one 0.98 or 0.9799999 passes; replicate by accumulating), `sim = simulateArc(f.x, f.y-6, ang, pwr, wpn.windFactor||0)`; `d = dist(sim, target.x/target.y)`; `selfD = dist(sim, f.x/f.y)`; accept if `selfD > 75 && d < bestDist` (strict `<`, first best wins). Then jitter `bestAngle += (r-0.5)*J; bestPower = clamp(bestPower + (r-0.5)*J, 0.22, 0.98)` with `J = ROOKIE 0.095, NIGHTMARE 0.012, else 0.042`. Non-CHARGE weapons: `angle = atan2(target.y - f.y, target.x - f.x)`; power stays 0.65.
- Aim phase: while `aimTime > 0`: `aimTime -= dt; aimAngle = lerp(aimAngle, plan.angle, dt*7); facing = cos(aimAngle)>=0 ? 1 : -1; return`. (Writes the global `aimAngle`, which the view uses to draw the aim guide; the fired angle is `plan.angle`.) Note: `aimAngle` is not reset by `syncAimAngleFromPitch` during AI turns (that call is gated by `!isCurrentTurnAI()`).
- Fire: if CHARGE and `totalTime < 3.2`: `isCharging=true; chargePower += dt*0.95;` when `chargePower >= plan.power`: `isCharging=false; executed=true; fireWeapon(wpn, plan.angle, plan.power, null)` (note: fired power is `plan.power`, not the charge bar value; `chargePower` is **not reset** after firing in AI path (reset happens at next `startNextTurn`)). Else AIRSTRIKE: `fireWeapon(wpn, 0, 1, {x: target.x, y: target.y})`. Else (melee etc., or a CHARGE weapon after 3.2 s): `fireWeapon(wpn, plan.angle, plan.power||0.7, {target pos})`.
- After execution, if still `TURN_PLAY` and `totalTime > 3.5`: `isCharging=false; turnPhase='ACTION_WAIT'` (safeguard).
- Note `fireWeapon` for AI does not set `lastAimPitch`; `hasActedOrMovedThisTurn=true`. `turnTimer` still counts down in TURN_PLAY.

`simulateArc(sx,sy,angle,power,windFactor)` (P:2638): `speed = 180 + power*760`; start `(sx + cos*18, sy + sin*18)`; `dt=0.025`; up to 160 steps: `vx += wind*2.4*windFactor*dt; vy += 440*dt; x += vx*dt; y += vy*dt; break if y >= WATER_Y || isSolid(x,y)`; returns the last `(x,y)`. Differences from the real projectile (faithful-port gotcha: keep AI's inaccuracies): real BAZOOKA/URTICARIA use the same speed formula but 4 substeps with small dt; GRENADE/CLUSTER/HOLY speed `150+680p`, CARQUINYOLI `210+680p` (3 pellets spread), grenades bounce rather than stop; muzzle in the real shot is `(x, y-4)+dir*18` vs `(x, y-6)+dir*18` in the sim; real shot has `windFactor` 0 for GRENADE etc. (matches wpn table 0), BAZOOKA 1.0.

AI timeline per turn (no timers other than dt): walk 0.45-0.85 s (or 0.08), aim 0.55 s, charge `power/0.95` s (0.28-0.98 -> 0.3-1.03 s). Total ~1.5-2.5 s. The AI turn can also be the splash showcase (`appStage != PLAYING` -> `updateAI` not called; physics only).

### 4.14 Input-driven sim code that lives in main.js (must be ported into the sim/controller)
- Walking: handled in stepPhysics via `keys.left/right` (78 px/s).
- Forward jump (`triggerForwardJump`, M:540): only if `grounded && !sliding`: `vx = facing*92; vy = -178; grounded=false; jumpStartX/Y=pos; peakAirY=y; isVoluntaryJump=true; wasBlasted=false; flip=0; squash(0.82,1.22)`; `hasActedOrMovedThisTurn=true`; `lastJumpPressTime=now`.
- Backward jump (`triggerBackwardsJump`, M:563): `grounded=sliding=false; vx = -facing*34; vy=-212; flipSpin = -facing*PI*2.35`, squash (0.76,1.30). Double-press forward within 360 ms while airborne: `x = lerp(x, jumpStartX, 0.72)` then backward jump. Disabled while `jetFuel > 0`.
- Aim: `aimPitch += (down-up)*1.55*dt` clamp [-1.48,1.30]; AIRSTRIKE uses `mouseWorld`.
- Charge: `beginChargeOrFireCurrentAim` (CHARGE: `isCharging=true; chargePower=0.08`; else fire at power 1.0), loop increments `chargePower += dt*0.92` (human, `TURN_PLAY` only), auto-fire at 1.0; release `power = max(0.12, charge)`.
- Weapon select (`selectWeaponByIndex`) requires `!AI && ammo > 0`; sets `teamSelectedWeaponIdx`. Q/E change `customGrenadeFuse` in [1,5].
- Worm switch (`switchActiveWormBeforeMove`, S:373): before moving/acting, Tab cycles to next alive team member; resets pan; `aimPitch = lastAimPitch`.
- Particles (M:353): collide with terrain if `collidesTerrain`; `p.vy += (hair?95:420)*dt`; wind affects hair `vx + wind*0.8`.

### 4.15 Atmosphere (render only; skip in sim) `regenerateMatchAtmosphere` (S:465-570)
Picks cloud style (4), sky palette shift (`+-14, +-11, +-15` per channel), 24-28 clouds with lobes, mountain style (6) and two 97-sample ridge arrays (`mountainRidgeFar/Near`). Called inside `generateDestructibleTerrain` and at load. Pure view data; port to the renderer layer.

---------------------------------------------------------------------------

## 5. Function index

### world.js
| Line | Function | Purpose | Depends on |
|---|---|---|---|
| 7 | `initNoise` (IIFE) | build PERM | - |
| 19 | `fade` | quintic ease | - |
| 20 | `lerp` | linear interpolation | - |
| 21 | `clamp` | clamp with non-finite->lo | - |
| 23 | `grad2` | gradient | - |
| 30 | `noise2D` | 2D gradient noise [~0..1] | PERM |
| 42 | `fbm` | fractal sum | noise2D |
| 53 | `ridgedFbm` | ridged fractal sum | noise2D, clamp |
| 221 | `buildBackgroundAssets` | builds cloud layer (view) | renderCloudLayer |
| 225 | `renderCloudLayer` | cloud texture (view) | fbm, DOM canvas |
| 276 | `setTerrainPixel` | set mask+front+back pixel | terrainMask |
| 288 | `clearTerrainPixel` | clear mask + front alpha | terrainMask |
| 296 | `stampDestructibleTree` | stamp tree solid | setTerrainPixel, noise2D |
| 369 | `stampStoneWatchtower` | landmark | " |
| 389 | `stampHollowFallenLog` | landmark (uses Math.random) | " |
| 410 | `stampNaturalRockArch` | landmark | " |
| 429 | `stampAncientMonoliths` | landmark | " |
| 449 | `stampRomanesqueViaduct` | landmark | " |
| 463 | `stampSteelTrussSpan` | landmark | " |
| 479 | `stampSkyTerracePlatform` | elevated walkable platform | clear/setTerrainPixel |
| 536 | `stampBarracaDelta` | landmark | " |
| 563 | `generateDestructibleTerrain` | complete terrain generation | all above, `regenerateMatchAtmosphere`, DOM `lbl-archetype`, `isSolid` |
| 951 | `isSolid` | mask lookup | terrainMask |
| 957 | `getSurfaceNormal` | 11x11 kernel normal | isSolid |
| 973 | `findSurfaceY` | first solid downwards | terrainMask |
| 982 | `findAllWalkableSurfacesAtX` | walkable tiers | terrainMask, WATER_Y |
| 1000 | `buildDryStoneGirder` | build solid capsule | canvas get/putImageData (view), noise2D |
| 1056 | `carveCrater` | destroy terrain | noise2D, canvas ops (view) |

### state.js
| Line | Function | Purpose | Depends on |
|---|---|---|---|
| 209 | `resizeCanvas` | view | DOM |
| 251 | `randomizeSquadNames` | shuffle names | pools |
| 358 | `syncAimAngleFromPitch` | pitch -> aimAngle + mouseWorld | activeFighter, WEAPONS |
| 373 | `switchActiveWormBeforeMove` | Tab worm switch | fighters, SND, updateHUD, DOM |
| 454 | `hexToRgbArr` / 460 `rgbArrToHex` | colour helpers (view) | - |
| 465 | `regenerateMatchAtmosphere` | sky/clouds/mountains (view) | fbm |
| 596 | `spawnSpeechBubble` | speech bubble list | speechBubbles |
| 605 | `findValidLandX` | land x near preferred | findSurfaceY |
| 618 | `findMultiLevelSpawnSpot` | spawn tier chooser | findAllWalkableSurfacesAtX |
| 637 | `initMatch` | new match | most of the above, DOM, startNextTurn |
| 853 | `createFighter` | fighter factory | findSurfaceY, customFaces |
| 929 | `spawnSupplyDrop` | crate spawn | crates |
| 946 | `updateWindHUD` | HUD wind bar (view) | DOM |
| 965 | `randomizeWind` | per-turn wind init | clamp |
| 973 | `updateDynamicWind` | wind evolution + sky drift | SND, floatingTexts |
| 1037 | `showVictoryModal` | victory UI | DOM, MAPS |
| 1081 | `startNextTurn` | turn rotation | damageFighter, spawnSupplyDrop, randomizeWind, DOM, SND |
| 1192 | `isCurrentTurnAI` | AI gate | appStage, gameMode |

### physics.js
| Line | Function | Purpose | Depends on |
|---|---|---|---|
| 8 | `spawnUrticatingHairs` | hair particles (view) | particles |
| 27 | `burstSilkNest` | nest burst -> nuts + larvae | spawnSmoke, pineNuts, larvaeSwarms |
| 63 | `spinElasticSilkWeb` | create web | silkWebs, DOM label |
| 102 | `checkMetamorphosis` | wing unlock | speech/text |
| 128 | `triggerExplosion` | explosion damage/crater/knockback | carveCrater, damageFighter, burstSilkNest, setTimeout, spawn* |
| 438 | `damageFighter` | apply damage/death | checkMetamorphosis, tombstones, updateHUD |
| 483 | `fireWeapon` | all weapons | triggerExplosion, carveCrater, buildDryStoneGirder, damageFighter, SND |
| 988 | `updateOrugaSegments` | trailing segments | isSolid |
| 1020 | `stepPhysics` | whole world update | all |
| 2386 | `spawnWaterPlunge` | water splash effect | waterPlumes, waterRipples, particles |
| 2425 | `spawnEmbers`, 2444 `spawnRockDebris`, 2465 `spawnSparks`, 2483 `spawnSmoke` | effects | particles/smokePuffs |
| 2504 | `updateAI` | AI turn | simulateArc, fireWeapon |
| 2638 | `simulateArc` | ballistic estimator | isSolid, wind |

Functions in other files that sim code calls (must be provided by view/controller): `updateHUD`, `buildWeaponBar` (M), `SND.*` (A), `showVictoryModal`/DOM label updates (S), `render()`.

---------------------------------------------------------------------------

## 6. Randomness, determinism, timing, units

### Randomness
- All randomness is unseeded `Math.random()`. Only `PERM` (noise table) is deterministic. `mapSeed` is a float offset that accumulates `+= 1.73 + random*3.8` per generation (initial 2.4).
- Random uses (gameplay-affecting): map pick, archetype/params/caverns/landmarks/trees, spawn positions and counts, who starts, wind per turn and gusts, crate drop (42% medkit, 48% per turn), AI target/weapon/aim jitter/walk, taunt probabilities (not gameplay, but they consume RNG), explosion knockback tie-break (dist<=1), hit taunts, hasMustache, palettes.
- `Array.sort(() => Math.random() - 0.5)` is used as shuffle (biased). A port may use `shuffle()`; the bias is not gameplay critical.
- For testing: in Godot use a single `RandomNumberGenerator` instance owned by the sim and seedable; keep per-system calls in the same order only if replaying a recorded seed (not needed for parity since the original is unseeded).
- `Math.round` = floor(x+0.5); `Math.sign(0)=0`; `%` follows the dividend sign; typed array assignment (`Uint8ClampedArray` for ImageData) rounds to nearest and clamps, but `Uint8Array` (mask) assigned only 0/1.

### Timing
- Variable dt: `dt = min(realDelta, 0.033)`; slow-mo multiplies by 0.38 while `slowMoTimer > 0` (itself decremented by raw dt); hit-stop freezes the sim entirely (only `render()` runs, `hitStopTimer -= rawDt`). All sim timers (turn timer, fuses, AI, tide) are scaled by dt.
- Substepping: projectiles 4 substeps (`dt/4`); airborne fighters 4 substeps; everything else single Euler step with the full dt. Behaviour is therefore **dt-dependent** (e.g., friction `pow(f, dt*60)`, `lerp(a,b,min(1,dt*k))`). A fixed 60 Hz or 1/30 s step would be fine, but note the original max step is 33 ms; the faithful approach is to run the sim with the same clamped variable dt (Godot `_process(delta)` clamp 0.033) or accept small deviations with a fixed `1/60` step.
- Real-time (wall clock) uses: barrel `setTimeout(70ms)`; double-jump window 360 ms (`performance.now()`); `lastChargeTick` uses `tNow`. `tNow` accumulates sim dt (scaled).
- Camera and render timers are separate (`rawDt` used for camera lerp and shift-pan).

### Units / world
- World 3200 x 820 px (play area x in ~[120,3080], terrain exists only there; water line `WATER_Y=700`, falls to 448; sky/top at y=0; `isSolid` false for y<0). Fighter radius 12 (centre-based, feet at `y + r`), barrel r 14, mine ~5 high, crate ~11 half-height.
- Speeds in px/s; gravity 440 px/s^2; wind unit: `wind` in [-100,100] times 2.4 gives px/s^2 for `windFactor=1`.
- Angles radians; `aimAngle` 0 = right, negative = up. `aimPitch` is relative to facing.

---------------------------------------------------------------------------

## 7. Porting notes

### 7.1 Suggested Godot file split (pure logic in `combat/sim/`, no nodes/drawing)

```
combat/sim/
  sim_constants.gd      GRAVITY=440, TERRAIN_W/H, WATER_Y_START, substeps, caps (HP caps etc.), phase enum
  noise.gd              PERM, noise2d, fbm, ridged_fbm, fade/lerp/clamp_safe (faithful, no FastNoiseLite)
  terrain_sim.gd        mask (PackedByteArray 3200*820), is_solid, surface_normal, find_surface_y,
                        walkable_tiers, carve_crater (mask only, emits dirty rect), build_girder (mask),
                        stamps + generate(map_cfg, rng) -> TerrainGenResult {mask, front_rgba, back_rgba, trees, valleys, archetype}
  ballistics.gd         projectile stepping (4 substeps), bounce/restitution table, wind application,
                        simulate_arc (AI), web reflection, hitscan ray (shotgun/ganxo)
  wind.gd               wind, wind_float, target, gust timer, randomize_wind(), update(dt, playing, phase) (+ tNow)
  damage.gd             damage_fighter, explosion falloff/knockback, fall damage, metamorphosis, boosts (dmgBoost, radiusBoost)
  weapons/              weapon_defs loaded from data/weapons/*.tres; weapon_fire.gd (fire dispatch),
                        optionally one script per behaviour type (charge_projectile, melee, hitscan, tool_spoon, tool_drill, tool_grapple, tool_girder, jetpack, airstrike)
  fighter_sim.gd        fighter state + stepping (walk, slide, air, landing, drowning, segments optional)
  pickups_sim.gd        crates, mines, barrels, rovellons, caganers, escudelles, nests, nuts, larvae, tombstones
  turn_manager.gd       phases (TURN_PLAY/RETREAT/ACTION_WAIT/TURN_DELAY/GAME_OVER), start_next_turn, timers, tide, supply drops, win check
  ai_brain.gd           plan, weapon choice, brute force aim, walk/aim/charge timeline
  match_setup.gd        init_match (spawn logic: find_multi_level_spawn_spot etc.)
  combat_sim.gd         facade: owns all sim state (replaces the JS globals), `step(dt)`, input commands (walk dir, jump, aim, charge/fire, select weapon, silk web, toggle convoy), emits signals/events
data/
  weapons/*.tres        WeaponDef (id,key,name,default_ammo,type,wind_factor,fuse,has_custom_fuse,blast_r,max_dmg,knockback, icon svg path)
  maps/*.tres           MapDef (id,name,subtitle,badge,bg_path,weather,slide_friction,sky[5],water_top,water_deep,turf/soil/rock Color or Vector3i,tree_style,preferred_texture)
  names.tres            two pools of 30 + defaults; taunts.tres (5 arrays); body/dorsal palettes; hats
  difficulty.tres       ROOKIE 0.095, VETERAN 0.042, NIGHTMARE 0.012
```
Keep every constant in code or a Resource exactly as above (they are all in sections 3/4).

### 7.2 Separating logic from drawing / DOM / audio (couplings found)
1. **Terrain: two representations.** `terrainMask` is the only collision source (good). `terrainFront/Back` canvases are pure view but written in the same loops (`setTerrainPixel`, per-pixel colour at generation, `carveCrater` visual part, `buildDryStoneGirder`). In Godot: generate `front_rgba`/`back_rgba` PackedByteArrays alongside the mask inside `terrain_sim.gd` (or a `terrain_visuals.gd` that consumes `TerrainGenResult`), create `Image`/`ImageTexture` (3200x820 RGBA; keep as one texture or tile it) and update with `Image.fill_rect`/`blend_rect` or `ImageTexture.update`. `carveCrater`'s visual: destination-out polygon + `source-atop` scorch gradient + back-canvas cut radius*0.68; replicate in the view using the mask delta (or write alpha/scorch to the front image with the same radius formula). The visual polygon radius differs slightly from the mask test (`jitter` formulas) — harmless.
2. **No canvas pixel reads for collision.** The only `getImageData` is in `buildDryStoneGirder` to patch colours; no gameplay logic reads pixels. Good: the mask replaces everything.
3. **Performance trap (biggest): terrain generation.** Per pixel below the surface (about 1.9-2.3 million) the generator evaluates `fbm(3 oct)` + `ridgedFbm(2 oct)` (+ cavern `fbm(3 oct)` for depth>32) = ~5-8 `noise2D` calls per pixel, i.e. ~15 million noise calls plus colour math. In GDScript that will take tens of seconds. Options (decide with the team; faithful result needs identical noise): run generation in a worker `Thread`, or implement the per-pixel stage in a GDExtension/C#/compute shader, or generate the **mask** (cheap: only caverns need noise `cavN`, and only for depth>32 inside cavern ellipses can be pre-tested with a bounding box test first) synchronously and the **colour layers** lazily (shader that recomputes colour from the mask + noise textures) — this deviates visually but keeps gameplay identical. Pre-test `inCavern` with the ellipse bounding rectangle (`|dx|<=1.2`, `|dy|<=1.2`) before computing `cavN` to skip most noise calls (identical result since `0.88+cavN <= 0.88+0.32*... ` check max: cavN max ~0.32 => radius^2 < 1.2 -> bounding by 1.1 per axis safe).
4. **`isSolid` hot path**: called thousands of times per frame (`getSurfaceNormal` = 120 calls; segment hugging 6 segs x up to 15 calls; flora/projectile). Use `PackedByteArray` with inline arithmetic; avoid Vector2 allocations; consider caching `getSurfaceNormal` results only per call (not across frames, terrain mutates).
5. **DOM coupling in sim code** (must be turned into signals/events): `#lbl-archetype` (W:629), `#lbl-silk-web` text (P:68, S:1130), `#turn-status`, `#round-sub` (S:1185-1189), `#lbl-map`, `#victory-modal` and `showVictoryModal` DOM (S:1037+), `#wind-bar/#wind-label` (`updateWindHUD`), `updateHUD()`, `buildWeaponBar()` (called from fireWeapon/damage/pickups: replace by `ammo_changed`/`hp_changed` signals), `SND.*` calls (replace by `sfx(name, args)` events), `speechBubbles`, `floatingTexts` (view effects fed by event `float_text(x,y,text,color,life)`), `document.getElementById('victory-modal')` in `initMatch`.
6. **Effects arrays inside the sim loop**: particles, smoke, fireballs, shockwaves, waterPlumes, waterRipples, bubbles, flora debris, `trail`, `squashX/Y`, `walkCycle`, `flipAngle`, `hurtTimer`, `batSwingTimer`, `slideAngle` are cosmetic; keep the **gameplay-relevant** fields in the sim (`dizzyTimer` and `hurtTimer` are not read by sim logic; `wineTipsy` never read; `squash` never affects physics) and emit effect events (`explosion(x,y,radius,urticating)`, `water_plunge(x,scale)`, `spawn_hairs`, `debris` ...) for the view to translate to particles. Note particles that touch terrain (`collidesTerrain`) and respond to wind: they use `isSolid`, so the view needs read-only access to `terrain_sim`.
7. **Camera/time-scale couplings**: `impactCam`, `shake`, `flashLight`, `hitStopTimer`, `slowMoTimer` are written inside physics; the turn FSM reads `impactCam.trackedWorm` only for camera focus (not for deciding turn end), but hit-stop/slow-mo alter dt for the whole sim. Port as events `camera_focus(x,y,worm)`, `screen_shake(amount)`, `hit_stop(t)`, `slow_mo(t)`; the main loop applies `Engine.time_scale`-like dt scaling (only to sim dt, not to camera lerp). Hit-stop assigned directly in some places (`= 0.055` / `= 0.45`) and with `max` in others.
8. **`appStage` coupling**: `isCurrentTurnAI()` returns true when not PLAYING (splash showcase: a match is generated and simulated behind the menu with `updateAI` not running, only physics + wind decor). Gate in Godot: `sim.playing` flag.
9. **`setTimeout` barrel chain explosion** -> sim-time `delayed_events` queue (0.07 s).
10. **Input/state shared in globals** (`keys`, `isCharging`, `chargePower`, `aimPitch/Angle`, `mouseWorld`, `selectedWeaponIdx`): sim should receive an `InputState` struct for the active human fighter. AI writes to the same globals (`isCharging`, `chargePower`, `aimAngle`, `selectedWeaponIdx`) so the view can display the AI's aim: keep these as sim outputs.
11. **Mutating arrays while iterating** (reverse loops with `splice`, spawn inside loops): in GDScript iterate backwards with index and `remove_at` the same way; newly pushed projectiles (clusters, galets) must not be processed in the frame they are created, exactly as in the original (pushed to the end while iterating backwards from the old end: unprocessed this frame). Same for nested `break` semantics (e.g., crate pickup loop `break`s after removing).
12. **Order of updates in `stepPhysics` matters** (planes, crates, mines, projectiles, nests, webs, rovellons, caganers, escudelles, nuts, larvae, barrels, tombstones, links, fighters) and `updateAI` runs before `stepPhysics`, wind update before AI, the turn FSM after physics, particles last. Preserve it.
13. `fireWeapon` is called from both input and AI; it reads `isCurrentTurnAI()` and globals `aimPitch`, `selectedWeaponIdx`; port with explicit `by_ai` argument.

### 7.3 Tricky / faithful-port hazards (flagged)
- `clamp()` returns `lo` for NaN/Infinity (GDScript `clampf` would not). Several callers rely on it only incidentally; implement the same helper.
- JS number semantics: `Math.round` ties up, `Math.sign(0)=0` (used as slide direction when a normal is vertical and speed 0 -> slide of 0), `%` with negative operands, integer ops `&` on floats (`floor(x) & 255`), typed array clamping/rounding for pixel writes.
- `noise2D` result is not strictly within [0,1] (gradient amplitude up to ~3 -> after `*0.5+0.5` may exceed). `fbm` thresholds like `n > 0.36` are tuned on this range; do not "normalize".
- `terrainMask` exists below `WATER_Y` down to y=819; `isSolid` is false at y>=820. `carveCrater` can excavate below water; worms never get there because `y >= WATER_Y` -> drowning.
- Shooting point: muzzle offset uses `y-4` while the character centre is `y` and grenade/AI use `y-6`; keep all offsets exactly.
- Unused table fields: `AIRSTRIKE.blastR/maxDmg/knockback/windFactor`, `CULLERA/BARRINA/PONT_PEDRA` damage, `windFactor` for GRENADE etc. (projectile forced 0). Port the *behaviour*, not the table.
- `pilotaBuff` is never cleared (persists whole match); `wineTipsy` is set but has no effect; `shotgunShotsLeft` has no gating effect (a human can fire only once because the phase changes to ACTION_WAIT).
- JETPACK consumption: uses 1 ammo and does not end the turn; `selectedWeaponIdx` is forced to 0 afterwards.
- Dynamite uses `RETREAT` so the thrower can walk away for up to 4 s; `turnTimer` stops (not decremented in RETREAT); an explosion in RETREAT forces `ACTION_WAIT`.
- The first-turn `roundNumber` quirk (starts counting at 2 if team 0 opens) and the double increment in the urticating-death recursion; round >= 10 tide applies every turn start.
- `startNextTurn` after a game over: `turnPhase='GAME_OVER'` stays until restart; `initMatch` regenerates the terrain (always `regenerateMap=true`) and resets `WATER_Y`.
- AI arc estimator mismatch (see 4.13) is intentional inaccuracy; keep.
- `damageFighter` credits `activeFighter` for any damage to an enemy even from falls/larvae/barrels/mines; in `startNextTurn` the urticating itch is applied after `activeFighter` is replaced.
- `triggerExplosion` when `appStage != 'PLAYING'` (splash showcase) skips hit-stop only; other effects still run.
- `findAllWalkableSurfacesAtX` depends on the **current** `WATER_Y` and mask: it is used at init only (and flora). During play, tide rise does not respawn.
- Floating point accumulation loops (`pwr += 0.05`) in AI must be reproduced with the same accumulation (`for pwr=0.28; pwr<=0.98; pwr+=0.05`), otherwise the last iteration may differ.
- Processing `fighters` includes dead ones (alive=false) in links/loops: guards use `alive`; dead fighters are kept in the array forever (tombstones are separate objects).
- Weapon `key` lookup: `WEAPONS.findIndex(w => w.key === e.key.toLowerCase() || w.key === e.key)`; keys `-` and `=` are for AIRSTRIKE and JETPACK; `u,i,o,p` tools; `0` HOLY.
- The turn timer does not run during RETREAT and the HUD displays the retreat timer instead.
- `hasActedOrMovedThisTurn` only blocks worm switching; it is not a hard limit on actions (a human can still act after moving: firing ends the turn through the phase change, not through that flag).
- Water: crates/projectiles/mines/barrels/nuts/larvae/flora vanish at `y >= WATER_Y` (the projectile check uses `p.y >= WATER_Y` per substep; cleanup uses `WATER_Y + 60`).

### 7.4 Suggested verification checkpoints for the port
1. `noise2d(x,y)` for a handful of coordinates matches the JS output (record values from the browser console: e.g. `noise2D(0.5,0.5)`, `fbm(1.3,2.7,4)`, `ridgedFbm(...)`).
2. Mask statistics for a given RNG replay are impossible (unseeded), so validate structurally: surface height range [165, 765], no terrain at x<120 and x>=3080, caverns above y=676, tiers, spawn positions all on `findAllWalkableSurfacesAtX`.
3. Physics: drop a fighter from heights (jump -> land) and check outcomes: fallDrop 12 -> minor slide; 88 -> PATACADA damage `clamp(round(6 + ... ), 6, 45)`; explosion knockback numbers (radius 50, dmg 50, kb 470 at distance 0 -> `falloff 1`, `imp 470`, `vy = -155 + ny*470`).
4. Turn flow: ACTION_WAIT -> TURN_DELAY (2.0 s) -> next team; tide steps; supply drops; GAME_OVER detection when a team has no alive non-drowning fighters.
5. AI: verify plan timeline and brute-force search produce shots that land near target on flat ground.

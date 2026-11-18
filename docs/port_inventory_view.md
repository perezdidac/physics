# CUCS port inventory: view, UI, input, main loop and audio

Scope: `reference/js/renderer.js` (2846 lines), `reference/js/main.js` (2004), `reference/js/audio.js` (831), `reference/index.html` (325), `reference/css/styles.css` (1852), and `reference/assets/*.jpg`.
Simulation/state/world (`state.js`, `physics.js`, `world.js`) are inventoried elsewhere (`docs/port_inventory_sim.md`); they are only referenced here for the globals the view/UI reads.

All line numbers refer to the files in `reference/`. Strings are quoted verbatim (Catalan, with the original accents, inverted `¡` and punctuation). "key" suggestions are proposals for `i18n/ca.po` / `tr()` keys; the base language of the Godot project is English (AGENTS.md rule 1), so every string below needs an English msgid plus this Catalan msgstr.

Contents
1. File overview
2. Screens and flow
3. UI strings, fonts and CSS look
4. Rendering
5. Input
6. Main loop
7. Audio
8. Function index
9. Porting notes

---

## 1. File overview

| File | Lines | Role |
|---|---|---|
| `index.html` | 325 | One page, one `<canvas id="canvas">` plus absolutely positioned DOM overlays inside `#viewport`. Loads Google Fonts (Cinzel 600-900, JetBrains Mono 600/700, Plus Jakarta Sans 500-800), `css/styles.css`, then classic scripts in order `world.js, audio.js, state.js, physics.js, renderer.js, main.js` sharing globals. `lang="ca"`. Title: `CUCS — Guerra Tàctica de la Processionària a Catalunya`. Viewport meta: `width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover`. |
| `css/styles.css` | 1852 | All look and feel: dark "obsidian + brass" palette, clip-path chamfered panels, glassmorphic HUD, mobile gamepad, portrait/landscape responsive rules. |
| `js/renderer.js` | 2846 | Pure drawing on a 2D canvas. `getCameraTransform`, `screenToWorld`, `render()` (the whole frame), and about 25 `draw*` helpers (parallax sky, clouds, flora, fighters, hats, held weapons, aiming HUD, projectiles, crates, water). Reads globals only and mutates no game state. Uses `Math.random()` inside draw for flicker (flames, drill jitter, screen shake). |
| `js/main.js` | 2004 | The `loop(now)` frame (timing, turn-phase state machine, camera targeting, particle/effect updates, then `render()`), all input (mouse, touch gestures, on-screen gamepad buttons, keyboard), menu/lobby/victory navigation, DOM HUD building (`updateHUD`, `buildWeaponBar`), lobby form logic, boot (`initMatch(true); requestAnimationFrame(loop)`). |
| `js/audio.js` | 831 | Global `SND`: WebAudio procedural synthesis. One master compressor, a tiny delay "room" send, a pre-built 1.5 s pink-ish noise buffer, an ambient wind loop, a 64-step looping 5-voice MIDI-style score ("La Sardana de Ferro") and about 40 sound effects plus a formant "cartoon worm voice" engine. |
| `assets/bg_*.jpg` | 8 files | 8 regional panorama backgrounds, each 1376x768 JPEG (about 0.8-1.0 MB each), one per map: `bg_montserrat, bg_cadaques, bg_taull, bg_castellfollit, bg_delta, bg_montblanc, bg_pedraforca, bg_tarraco`. Referenced from `MAPS[i].bgPath` (`world.js:78-205`). Used in two places: the full-screen parallax image in `render()` (renderer.js:67-91) and the thumbnail `<img>` of each map card in the lobby (main.js:1816, `object-fit: cover`, card 112 px high). |

Globals the view/UI consumes (defined in `state.js`/`world.js`/`physics.js`): `canvas, ctx, viewW, viewH, canvasDpr` (state.js:203-218), `cam` (state.js:407-420), `tNow, shake, flashLight, flashPos, hitStopTimer, slowMoTimer, userZoomMult (=1.22 default)`, `appStage` (`'SPLASH'|'LOBBY'|'PLAYING'`), `turnPhase`, `activeFighter, activeTeam, fighters, projectiles, ...entity arrays`, `wind`, `MAPS[], currentMapIdx, BG_IMAGES, ASSETS.cloudLayer` (a 1600x320 procedural canvas texture built by `renderCloudLayer` in world.js:222+, called from `buildBackgroundAssets`), `TERRAIN_W=3200, TERRAIN_H=820, WATER_Y` (700 initially, rises in sudden death), `GRAVITY=440`, `terrainBack/terrainFront` (offscreen canvases), `WEAPONS[]` (16 entries, each with an inline SVG icon string), `teamHats, teamNames, customFaces`.

Not present in the JS: there is **no gamepad/Gamepad API code at all**. "Gamepad" in the HTML/CSS means the *on-screen touch buttons* (`.mc-*`). A joypad mapping in Godot would be a new feature (record in `docs/pending_decisions.md`).

---

## 2. Screens and flow

### 2.1 Inventory of DOM layers (all inside `#viewport`, z-index ascending)

| Layer | id / selector | z | Shown by | Hidden by |
|---|---|---|---|---|
| Canvas | `#canvas` | 0 | always (full screen, `touch-action:none`, `cursor:crosshair`) | never |
| Top HUD | `#top-hud` | 20 | always in DOM (pointer-events none, children re-enable) | **never hidden**; it is visible under the splash/lobby too (they are semi-opaque overlays above) |
| Bottom HUD | `#bottom-hud` | 20 | always in DOM | never hidden |
| Victory modal | `#victory-modal` | 65 | `.open` added by `showVictoryModal` (state.js:1038-1075) only if `appStage==='PLAYING'` | `.open` removed by buttons, `initMatch` (state.js:838), `exitCurrentMatchToMenu` |
| Campaign lobby (customise) | `#campaign-lobby` | 75 | `.open` (opacity 0->1, visibility, 0.3 s) | `.open` removed |
| Splash / main menu | `#splash-screen` | 90 | default visible; `.hidden` removed | `.hidden` added (opacity 0, visibility hidden, 0.35 s) |
| Rotate-device overlay | `#rotate-device-overlay` (position:fixed) | 120 | `.open` -> `display:flex` | `.open` removed |

Because the top/bottom HUD sit at z 20 under splash (90) and lobby (75), they are covered by the semi-transparent dark radial gradients of those overlays; the splash gradient is only `rgba(14,18,26,.38)` at centre to `rgba(5,7,10,.88)` at the edge, so the HUD is faintly visible behind the main menu. In Godot, hide the HUD while the menu is shown (visual difference acceptable; note it as a deviation) or keep it faithfully dimmed. The canvas keeps rendering the live 3D-ish world behind the menus (see 2.4).

### 2.2 Screen tree / flow

```
Boot  (main.js:2002-2004)
 initMatch(true) with a random map, appStage = 'SPLASH', loop starts
 │
 ├─ SPLASH  "Menú Principal" (#splash-screen, appStage 'SPLASH')
 │    background: live world, camera auto-pans (sin/cos drift), + animated procession silhouette on a pine branch (renderer.js:583)
 │    title block: kicker / "CUCS" / subtitle
 │    menu (3 items, cursor menuCursorIdx 0..2, wraps):
 │      0  "Partida Ràpida contra la CPU"  -> SND.titleFanfare(); gameMode='1P_CPU'; random hats for both teams;
 │                                            random map; hasCustomLobbyNames=false; hide splash; appStage='PLAYING'; initMatch(true)
 │      1  "2 Jugadors en Local"           -> same with gameMode='2P_LOCAL'
 │      2  "Personalitza la Partida"       -> SND.tick(); hide splash; openLobbyModal()
 │    input: ↑/↓ or W/S move, Enter/Space activate, hover (mouseenter) moves cursor, click activates
 │
 ├─ LOBBY  "Personalitza la Partida i els Escamots" (#campaign-lobby, appStage 'LOBBY')
 │    header: title + subtitle + keyboard hint chip; button "← Menú Principal [Esc]"
 │    1. Mode de Combat (3 cards)   2. Intel·ligència Tàctica de la CPU (3 cards)
 │    3. Nombre de Cucs per Escamot (6 cards)
 │    4. Map picker (8 theatre cards built in JS with the bg jpg thumbnails)
 │    5. Two squad boxes: hat <select> + N rows (index, name <input maxlength 16>, face upload label)
 │    footer: "Noms Catalans Aleatoris" | ["Torna a la Partida Actual" (only if a match was started)] "DESPLEGA AL CAMP DE BATALLA"
 │    exits:
 │      Esc / "← Menú Principal [Esc]"     -> readLobbyCustomization(); if hasStartedMatchOnce: back to PLAYING else back to SPLASH (the header button ALWAYS goes to SPLASH, see quirk)
 │      "Torna a la Partida Actual"        -> readLobbyCustomization(); appStage='PLAYING' (match continues, no reset)
 │      "DESPLEGA AL CAMP DE BATALLA" / Ctrl+Enter -> readLobbyCustomization(); hasCustomLobbyNames=true; hasStartedMatchOnce=true;
 │                                            hide splash; appStage='PLAYING'; initMatch(true)
 │    opened from: splash item 2, in-game btn-roster (hidden button, no visible entry point), victory "Canvia Indret / Escamot"
 │
 ├─ PLAYING (appStage 'PLAYING')  turn-based match, HUD visible, see §6 for phases
 │    top HUD: team panels, chronometer, wind meter, command strip (Música, Sortir)
 │    bottom HUD: fuse picker (only for fuse weapons), arsenal drawer (16 slots), control row
 │        left cluster (touch only):  ◀ ▶ ▲ ▼
 │        centre: ◀  [weapon pill: icon, name, ammo, "▲ Arsenal [B]"]  ▶  [Cuc ⇄ (conditional)]
 │        right cluster (touch only): Salt, Mortal, −, +, Centra, FOC! (charge bar)
 │    ├─ Weapon drawer open (class .open on #weapon-bar): arrow/WASD navigation of an 8x2 grid, Enter/Space selects, Esc/B closes
 │    ├─ Esc (drawer closed) or "Sortir" button  -> exitCurrentMatchToMenu() -> SPLASH (match is discarded: hasStartedMatchOnce=false)
 │    └─ GAME_OVER -> Victory modal (#victory-modal)
 │          "Canvia Indret / Escamot" -> close modal, openLobbyModal()
 │          "Torna a Jugar [Intro]"   -> close modal, initMatch(true)  (same settings, new map terrain of currentMapIdx)
 │          keys: ←/→/A/D/Tab swap focus (victoryFocusIdx, default 1 = rematch); Enter/Space activate; Esc -> exitCurrentMatchToMenu()
 │          click/tap/Space on canvas while GAME_OVER (modal not blocking) -> initMatch(true)
 │
 └─ Rotate-device overlay (orthogonal, any stage): shown when portrait phone, see 2.3
```

Quirks to keep (faithful port):
- `btn-back-menu` onclick (main.js:1929) always returns to SPLASH even if a match was started; the Esc key (main.js:1232-1247) returns to PLAYING when `hasStartedMatchOnce`. In the SPLASH-return case the match state is kept in memory but `hasStartedMatchOnce` stays true.
- `exitCurrentMatchToMenu` (main.js:42) resets `hasStartedMatchOnce=false`, clears keys and charge, closes drawer and victory modal, shows splash, sets `appStage='SPLASH'`. It does not call `initMatch`; the background world is whichever match was running (the fighters keep acting as a "background showcase AI" because `isCurrentTurnAI()` returns true whenever `appStage !== 'PLAYING'`).
- The 3 command-strip buttons `btn-reroll-map`, `btn-map` and the 4 buttons `btn-silk-web, btn-procession, btn-mode, btn-roster` are `style="display:none"` in the HTML and never shown by any code. Only `btn-music` and `btn-exit-game` are visible. `btn-reroll-map` and `btn-map` have no click handler at all. The hidden buttons' labels are still written by code (`lbl-map`, `lbl-archetype`, `lbl-mode`, `lbl-procession`, `lbl-silk-web`), so the port can skip them but the hotkeys remain (C = silk web, F = procession toggle, see §5).
- `#mc-switch-worm` and the two `.mc-cluster` are hidden by default and shown on touch devices (class `body.touch-device`, or media query `(pointer: coarse), (max-width: 920px), (max-height: 560px)`).

### 2.3 Rotate-device overlay (`#rotate-device-overlay`)

- Logic `updateRotateDeviceOverlay()` (main.js:20-31), run every frame from `loop` (line 132) and on `resize` / `orientationchange` (+140 ms).
- `isPortrait = viewH > viewW * 1.04 && viewW <= 880`; shown iff `isPortrait && isMobilePhoneDevice() && !rotateOverlayDismissed`. `isMobilePhoneDevice()` (main.js:14) = `body.touch-device` OR `(pointer: coarse)` OR user agent matches `/Android|iPhone|iPod|Mobile/i`.
- Dismissal flag is reset whenever the viewport is not portrait, so rotating back to portrait reminds again.
- While the overlay is open the turn timer does NOT count down (main.js:202, `if (!rotatePromptOpen) turnTimer -= dt`).
- Content: animated phone SVG (rotates 0 -> -90 deg keyframes `tiltToLandscape` 2.2 s infinite: 0-15% 0 deg, 55-80% -90 deg, 100% 0 deg), kicker, title, text, two buttons.
- Buttons: `btn-lock-landscape` ("Pantalla Completa Horitzontal"): `requestFullscreen()` on the document element if not fullscreen, then `screen.orientation.lock('landscape')`, errors swallowed, then dismiss. `btn-dismiss-rotate` ("Continua igualment"): dismiss. Keyboard: Esc/Enter/Space dismisses (main.js:1189-1197).
- Godot: on the web export use `DisplayServer.window_set_mode(FULLSCREEN)` / `JavaScriptBridge.eval("screen.orientation.lock('landscape')")`; on Android set `display/window/handheld/orientation=sensor_landscape` and the overlay is only a web concern. Portrait detection can use `DisplayServer.window_get_size()`.

### 2.4 Background behaviour behind menus

- SPLASH/LOBBY camera (main.js:340-344): `targetX = TERRAIN_W*0.5 + sin(tNow*0.24)*580`, `targetY = 380 + cos(tNow*0.2)*30`, `targetZoom = 0.96` (a slow cinematic drift over the map).
- SPLASH only: `drawSplashProcessionSilhouette` (renderer.js:583) draws a foreground pine branch and 6 marching caterpillars (see §4.7).
- The sim keeps running (AI-driven demo match, `updateAI` is only called when `appStage==='PLAYING'`, but `stepPhysics` runs every frame regardless; see main.js:190-193).

### 2.5 Navigation by input type

**Keyboard**
- SPLASH: ↑/W and ↓/S, Enter/Space (main.js:1206-1224). `M` toggles music in every stage (main.js:1200).
- LOBBY: a roving "kb-focus" cursor over a flattened list of focusable elements (`getLobbyFocusableItems`, main.js:1119) in DOM order: `#btn-back-menu`, mode cards, difficulty cards, count cards, map cards, `#hat-t0`, team-1 name inputs, `#hat-t1`, team-2 name inputs, `#btn-random-names`, `#btn-close-setup` (if visible), `#btn-restart-match`. Rules (main.js:1227-1357):
  - Esc: if a text input has focus, blur it; else leave the lobby (see tree).
  - Ctrl/Cmd+Enter anywhere: click Deploy.
  - Tab / Shift+Tab: next/previous focus (wrapping), tick sound.
  - Input focused: ↓ or Enter -> `readLobbyCustomization()` and focus next; ↑ -> previous; other keys type text.
  - ↓/S: if on a grid member, jump past the last sibling of the same grid (to the next group); otherwise +1. ↑/W: symmetric.
  - →/D: on a `<select>` cycles hat option +1 (`activateLobbyFocusedItem(el, 1)`, wraps over `HAT_OPTIONS = VARIED, CATALAN, CASTELLER, BANDOLER, PAGES, BRISTLES`; note the HTML option order differs between the two selects but the cycle order is always this array); else +1 focus and, if the newly focused item is a card, it is auto-clicked (selected). ←/A symmetric.
  - Enter/Space: activate: card -> click, select -> +1 hat, button -> click. Every action plays `SND.tick()`.
  - On open (`openLobbyModal`): `lobbyFocusIdx = (deploy button found) ? 1 : 0`, i.e. index 1 = first mode card (index 0 is the back button). The scroll uses `scrollIntoView({block:'nearest', behavior:'smooth'})`.
- Victory modal: see tree.
- In-game: see §5.

**Mouse**: hover and click on cards/buttons; menu items follow hover (`mouseenter` sets `menuCursorIdx`). Map cards have a "lift" hover (translateY -2 px) and image zoom 1.05.

**Touch**: the same DOM buttons work with taps. The lobby scrolls vertically (`touch-action: pan-y`, `-webkit-overflow-scrolling: touch`). In-game touch gestures: §5.

**Gamepad**: none in the original.

### 2.6 Lobby form logic

- `renderLobbySquadInputs` (main.js:1761): rebuilds `#t1-inputs` and `#t2-inputs` with `wormsPerTeam` rows (clamped 1-6). Row = `0N` index label, text input `inp-t{team}-{i}` (value `teamNames[team][i]`, `maxlength=16`), file label (`+ Cara` or `✓ Cara Llista`, tooltip `Puja la foto de la cara d'un amic per a aquest cuc`) wrapping a hidden `<input type=file accept="image/*">`.
- `handleFaceUpload(team, idx, input)` (main.js:1840): FileReader -> Image -> `customFaces[team][idx] = img` and applied live to existing fighters (`f.customFaceImg`); label text becomes `✓ Cara Llista`. In the head it is drawn clipped to a circle (see §4.5). Godot: `FileDialog` (web: native `<input type=file>` via `JavaScriptBridge` or the `FileAccessWeb` file dialog) and `Image.load_from_buffer`; in the head draw as a circle-clipped texture.
- Card selections: mode (`data-mode` 1P_CPU/2P_LOCAL/CPU_CPU -> `gameMode`, also updates hidden `lbl-mode`, clears `aiPlan`); difficulty (`data-diff` ROOKIE/VETERAN/NIGHTMARE -> `aiDifficulty`); count (`data-count` 1..6 -> first `readLobbyCustomization()` to save typed names, then `wormsPerTeam`, then re-render inputs); map card click -> `currentMapIdx = idx; generateDestructibleTerrain(idx)` immediately regenerates the terrain behind the lobby (background changes live).
- `readLobbyCustomization()` (main.js:1883): copies non-empty trimmed input values into `teamNames`, hats from the selects into `teamHats`, renames live fighters, refreshes `#turn-status` and HUD.
- `btn-random-names`: `randomizeSquadNames(true)`, `hasCustomLobbyNames=true`, fills inputs (6 per team).
- Defaults when entering lobby fresh: mode 1P_CPU selected, difficulty VETERAN, count 4 (these are the HTML `selected` classes, overwritten by `openLobbyModal` from live variables `gameMode, aiDifficulty, wormsPerTeam, currentMapIdx, teamHats`).
- Team hats default `teamHats = ['CATALAN', 'BANDOLER']` (state.js). The two `<select>`s have different first-after-VARIED options only in DOM order.

---

## 3. UI strings, fonts and CSS look

### 3.1 Fonts

- **Cinzel** (serif display, weights 600-900): splash title/kicker/subtitle, menu item titles, lobby h1, squad names, theatre name, deploy button, timer digits, rotate title, victory title, fire button.
- **JetBrains Mono** (600/700, used up to 800): hints, section labels, badges, wind label, HP total, ammo counters, hotkey tags, fuse buttons, `▲ Nm` tracker pill, elevation degree badge in canvas.
- **Plus Jakarta Sans** (500-800): body text, buttons, HUD names, all canvas text (names, speech bubbles, damage numbers).
- Fallbacks: `Georgia, serif` for Cinzel; `-apple-system, BlinkMacSystemFont, sans-serif` for body; `monospace` for mono.
- Godot: ship the three families as `.ttf` (OFL) in `assets/fonts/`, load through a `Theme` with `FontVariation` for weights (Plus Jakarta Sans variable font weights 500/600/700/800; Cinzel 600-900 variable). Canvas text in world uses `Font.draw_string` with the same font; sizes below are CSS px at scale 1 in world space (they scale with the camera).

### 3.2 Colour palette (CSS variables, styles.css:1-13)

| Name | Value | Use |
|---|---|---|
| `--bg-obsidian` | `#090b0f` | |
| page / viewport bg | `#06070a` | body, `#viewport` |
| `--slate-panel` | `#141820` | |
| `--slate-inner` | `#1b202b` | |
| `--brass-trim` | `#d4a153` | borders, section labels, selected fuse btn bg |
| `--brass-bright` | `#f6cf77` | highlight text/borders, timer digits |
| `--brass-dim` | `rgba(212,161,83,.34)` | |
| `--ivory` | `#f2ecdf` | primary text |
| `--ivory-muted` | `rgba(242,236,223,.64)` | secondary text |
| `--amber-team` | `#f5b945` | team 0 ("Brigada del Pinar", gold) |
| `--crimson-team` | `#ea5648` | team 1 ("Tramuntana", crimson) |
| `--poison-violet` | `#c678ff` | (unused in CSS; violet `#d88aff` used in canvas for urticating effects) |
| kicker orange | `#e6883a` | `.splash-kicker` |
| low-time red | `#ff5247` | timer <= 5 s |
| retreat yellow | `#ffd966` | timer during RETREAT |
| wind bar | `#7ec8e3` (left, blue) / `#f5b945` (right, gold); gust flash `#b8f0ff` / `#ffe899` | |
| victory draw colour | `#f2ecdf` | |
| kb-focus | outline `#ffd966`, border `#ffe49e`, ring `rgba(246,207,119,.28)` | |

### 3.3 Key styles (what to rebuild in a Godot Theme)

- **Chamfered panels** (clip-path polygon): `.updown-item` 12 px cut top-right and bottom-left; `.lobby-frame` 18 px; `.tactical-card` 7 px top-right; `.theatre-card` 10 px both diagonal corners; `.squad-box` 8 px top-right; `.btn-gold-deploy` 8 px; `.victory-card` 16 px. Godot: `StyleBoxFlat` cannot chamfer; use `StyleBoxTexture` with a 9-patch of a chamfered corner, or a `Polygon2D`/`Panel` with a custom `_draw` (`draw_colored_polygon`). Decide one approach for all (suggest: small custom `ChamferPanel` Control drawing the polygon + border with `draw_polyline`).
- **Glass HUD**: `rgba(14,18,26,.72)` background + `backdrop-filter: blur(12px)`, 1 px `rgba(240,195,110,.28)` border, radius 14 (squad panels), 999 (pills). Godot: no backdrop blur in Compatibility renderer without a shader (screen texture reading is supported in GL Compatibility via `hint_screen_texture`, but costly on web); recommended: drop blur and use slightly higher opacity (`.82`). Document as a visual deviation.
- **Splash**: background `radial-gradient(circle at 50% 38%, rgba(14,18,26,.38) 0%, rgba(5,7,10,.88) 100%)`; content centred, gap 28; padding 36/24/64.
  - kicker: Cinzel 12.5/700, letter-spacing 4.5, `#e6883a`, uppercase, text-shadow.
  - title: Cinzel `clamp(40px, 6vw, 72px)`/900, letter-spacing 4, vertical gradient text `#fff6df -> #f3c46b (48%) -> #b8742a`, drop-shadow `0 12px 32px rgba(0,0,0,.95)`.
  - subtitle: Cinzel `clamp(13px,1.7vw,18px)`/700, letter-spacing 5, ivory, padding 5/24, top and bottom 1 px `--brass-dim` borders, horizontal gradient `transparent -> rgba(20,24,32,.85) -> transparent`.
  - menu: column, gap 10, width 440 (max 92vw). Item: padding 15/22, gradient `rgba(20,25,34,.92) -> rgba(11,14,20,.96)`, border `rgba(212,161,83,.32)`, shadow `0 12px 32px rgba(0,0,0,.75)`. Active/hover: translateX(6 px), background `90deg rgba(212,161,83,.28) -> rgba(22,27,38,.96)`, border `#f6cf77`, glow `0 0 22px rgba(246,207,119,.22)`; arrow `▶` (JetBrains Mono 16/800, `#f6cf77`) opacity .18 inactive, 1 active (+2 px shift); title Cinzel 15.5/800 letter-spacing 1.2 uppercase (ivory, brass-bright when active); sub 11.5 muted; transitions 0.14 s.
  - hint: JetBrains Mono 11, letter-spacing 1, `rgba(242,236,223,.72)`, `<b>` in `#f6cf77`.
- **Lobby frame**: 1120 px wide (max 96vw, max-height 94vh, scroll), gradient `#161a23 -> #0e1117`, 1 px `#d4a153` border, padding 24/28. Overlay bg `radial-gradient(circle at 50% 20%, rgba(18,23,33,.88), rgba(6,8,12,.96))` + blur 14. Header: h1 Cinzel 22/800 letter-spacing 2 `#f6cf77` uppercase; p 11.5 muted; bottom border `rgba(212,161,83,.26)`. Section labels JetBrains Mono 10.5/700 uppercase letter-spacing 1.4 `#d4a153`. Top bar grid `1.35fr 1fr` gap 16 (1 col under 820 px). Mode/diff grids 3 columns, count grid 6 columns (3 under 820 px), gap 8. Theatre grid 4 columns (2 under 820), gap 10, card 112 px tall (104 portrait, 88 landscape mobile). Squad grid 2 columns (1 under 820).
  - `.tactical-card`: padding 10, bg `rgba(255,255,255,.025)`, border `rgba(242,236,223,.14)`; hover bg `rgba(212,161,83,.1)`, border `rgba(212,161,83,.45)`; selected gradient `rgba(212,161,83,.24) -> .08`, border `#f6cf77`, title colour `#f6cf77`. Title 12/800 uppercase; sub 10 muted.
  - `.theatre-card`: image `brightness(.84) saturate(1.08)`, hover/selected `brightness(1) saturate(1.15)` and scale 1.05; selected border 2 px `#f6cf77` + glow `0 8px 26px rgba(246,207,119,.25)`; overlay gradient `rgba(6,8,12,.15) -> .88` bottom-aligned; badge top-right JetBrains Mono 9/700 brass; name Cinzel 14/800 white; landmarks 10.5 `rgba(242,236,223,.78)`.
  - `.squad-box` bg `rgba(0,0,0,.34)`; head with h3 (Cinzel 13.5, team colour) and select (bg `#141821`, border `--brass-dim`, 11/700); rows gap 8, margin 7; index JetBrains Mono 10.5 w 22; input bg `rgba(255,255,255,.05)` border `rgba(242,236,223,.18)` 12.5/700, focus border `#f6cf77`; face label height 29, 10/700.
  - `.btn-gold-deploy`: gradient `#f3be5c -> #c48224`, border `#ffe094`, text `#0b0d12`, Cinzel 13/900 uppercase letter-spacing 1.4, padding 11/28; hover brightness 1.08.
  - `.cmd-btn`: height 27, padding 0 11, bg `rgba(16,20,28,.78)`, border `rgba(240,195,110,.32)`, radius 999, 10/700 uppercase, hover bg `rgba(34,42,58,.92)` + border/text `#f6cf77`; svg icons 12 px stroke currentColor width 2.
- **Top HUD** (grid `1fr auto 1fr`, padding 10/16): squad panel (max-width 245, right panel min-width 225): header (Cinzel 11.5/800 uppercase team colour, HP total JetBrains Mono 11/800), pips grid 4 columns gap 5. Pip: name 9/700 muted (white if active), bar 4 px high radius 99 bg `rgba(255,255,255,.12)`, fill width = hp%, colour = team colour, transition width .25 s; `.dead` opacity .22; cursor pointer if alive. Chronometer: pill bg `rgba(14,18,26,.78)`, border `rgba(240,195,110,.42)`; timer Cinzel 22/900 `#f6cf77` min-width 28; 1x20 divider; status 12.5/800; sub 9.5/700 uppercase muted. Anemometer pill: label `VENT`, track 82x5 (bg `rgba(0,0,0,.55)`, border `rgba(255,255,255,.14)`), centre tick 1 px `#d4a153`, bar anim .25 s, numeric label. Command strip under the right panel, right aligned, gap 5.
- **Bottom HUD** (absolute, bottom 10, centred, column gap 6): fuse picker pill (`display:none` unless `.visible`), arsenal drawer `.ordnance-rack` (grid 8 columns of 62 px, gap 5, bg `rgba(14,18,26,.94)`, border `rgba(240,195,110,.52)` 1.5, radius 16, pop animation `drawerPop` 0.16 s: from `opacity 0, translateY(8px) scale(.97)` to identity), slot (62x54, radius 10; `.active` brass gradient + inner glow; `.kb-cursor` white 2 px outline, lift `translateY(-2px) scale(1.04)`; `.depleted` opacity .26, no pointer events), slot contents: hotkey top-left (8.5 px, `rgba(242,236,223,.45)`), ammo top-right (9 px `#f6cf77`), icon (32x22 SVG), label (9/700 uppercase). Row `#bottom-bar-row`: centre-justified on desktop, `space-between` on touch. Weapon pill: nav buttons 36x40 round, toggle 44 high pill with 30x20 icon, name 12/800 uppercase white, ammo chip (JetBrains Mono 11/800 `#f6cf77` on `rgba(240,184,73,.14)`), chevron text 9/800 muted (hidden in landscape-mobile CSS).
- **Mobile buttons** `.mc-btn`: 44 high, min-w 46, gradient `rgba(24,30,42,.94) -> rgba(12,15,22,.97)`, border `rgba(212,161,83,.52)` 1.5, radius 8, 12/800 uppercase; pressed: scale .94, brass gradient, text `#f6cf77`. Arrow variant 48 wide, 17 px glyph; util variant 36 high, 11 px; fire button 50x108, gradient `#f5be58 -> #d46528 (55%) -> #9e261b`, border 2 `#ffe49e`, text white Cinzel 14/900 with shadow, overflow hidden, containing `.mc-fire-fill` (absolute left 0, width = charge%, `rgba(255,255,255,.28)`, transition .04 s linear).
- **Victory card**: width 540 (max 92vw), gradient `#181d27 -> #0e1117`, border `#f6cf77`, padding 28/32, title Cinzel 28/900 coloured by winner (`#f5b945`, `#ea5648`, `#f2ecdf`), stats box 2-col grid bg `rgba(0,0,0,.35)` border `rgba(255,255,255,.08)` 12 px; overlay `rgba(6,8,12,.82)` + blur 8.
- **Rotate card**: 390 max width, radius 18, border 1.5 `#f6cf77`, gradient `rgba(24,29,39,.96) -> rgba(12,15,22,.98)`.
- Transitions/animations: opacity+visibility 0.3-0.35 s fades for overlays; `drawerPop` 0.16 s; `tiltToLandscape` 2.2 s loop; hover transforms 0.12-0.16 s.

### 3.4 Responsive / mobile rules (styles.css)

- Touch detection: `body.touch-device` is added on first canvas `touchstart` or gamepad `pointerdown`; CSS media `(pointer: coarse), (max-width: 920px), (max-height: 560px)` also enables clusters and the switch-worm button.
- **Portrait (`max-width: 820px`)**: splash/lobby compaction; lobby single column, theatre grid 2 columns, hats full width, footer stacked, buttons full width; **top HUD becomes a 3-row grid** (`"chrono chrono" / "t1 t2" / "cmds cmds"`), chronometer row layout with timer pill flexing; smaller fonts; command strip centred and wrapped; bottom HUD width `calc(100vw - 12px)`; arsenal drawer 5 columns, slot 44 high, hotkeys hidden.
- **Landscape phone (`max-height: 540px` and landscape)**: compact splash (title 34 px), lobby padding 12/16, theatre cards 88 px, top HUD columns `minmax(160px,215px) auto minmax(160px,235px)`, smaller pills/buttons (cmd 22 px high, mc buttons 36, fire 40x88, weapon pill 36), chevron hidden, arsenal 8 columns `minmax(48px,1fr)` width `min(94vw, 520px)`, hotkeys hidden.
- Safe-area insets via `env(safe-area-inset-*)` in portrait and landscape rules. In Godot use `DisplayServer.get_display_safe_area()`.
- Camera base scale also depends on orientation (see §4.2).

### 3.5 UI strings (verbatim)

Key naming proposal `SCREEN_ELEMENT`. Entities such as `&Ograve;` are shown decoded. HTML escapes decoded: `&middot;` = `·`, `&rarr;` etc.

**Page**
- `PAGE_TITLE` (title): `CUCS — Guerra Tàctica de la Processionària a Catalunya`

**Splash (#splash-screen)**
- `SPLASH_KICKER`: `Thaumetopoea Pityocampa · Guerra Tàctica als Pinars de Catalunya`
- `SPLASH_TITLE`: `CUCS`
- `SPLASH_SUBTITLE`: `LA PROCESSÓ DE FERRO`
- `MENU_QUICK_TITLE` (#menu-opt-quick): `Partida Ràpida contra la CPU`; `MENU_QUICK_SUB`: `Salta directament al camp de batalla contra la IA`
- `MENU_2P_TITLE` (#menu-opt-2p): `2 Jugadors en Local`; `MENU_2P_SUB`: `Jugueu per torns al mateix mòbil o ordinador`
- `MENU_CUSTOM_TITLE` (#menu-opt-custom): `Personalitza la Partida`; `MENU_CUSTOM_SUB`: `Indrets de Catalunya, dificultat, barrets, noms i cares d'amics`
- `MENU_HINT` (markup: bold on "Toca" and "↑/↓ + INTRO"): `Toca o ↑/↓ + INTRO per Seleccionar  ·  100% Jugable amb Teclat o Mòbil Horitzontal` (the `↑/↓` glyphs are `&uarr;/&darr;`)

**Rotate overlay**
- `ROTATE_KICKER`: `FORMAT APAÏSAT RECOMANAT`
- `ROTATE_TITLE`: `GIRA EL MÒBIL EN HORITZONTAL`
- `ROTATE_BODY` (bold "CUCS"): `Per veure tot el camp de batalla i utilitzar còmodament els controls tàctils de CUCS, gira el telèfon en mode horitzontal.`
- `ROTATE_BTN_FULLSCREEN`: `Pantalla Completa Horitzontal`
- `ROTATE_BTN_CONTINUE`: `Continua igualment`

**Lobby (#campaign-lobby)**
- `LOBBY_TITLE`: `CUCS — Personalitza la Partida i els Escamots`
- `LOBBY_SUBTITLE`: `Tria el mode de combat, l'indret de Catalunya, el barret tradicional, els noms i les fotos.`
- `LOBBY_KB_HINT` (chip): `Teclat: ↑↓←→ / Tab per navegar · Intro/Espai per canviar · Ctrl+Intro per desplegar`
- `LOBBY_BTN_BACK` (#btn-back-menu): `← Menú Principal [Esc]`
- `LOBBY_SEC_MODE`: `1. Mode de Combat`
  - card `1P_CPU`: title `1J vs CPU`, sub `Campanya en Solitari vs IA`
  - card `2P_LOCAL`: `2J en Local` / `Dos Jugadors, Mateix PC`
  - card `CPU_CPU`: `CPU vs CPU` / `Batalla d'Exhibició IA`
- `LOBBY_SEC_DIFF`: `2. Intel·ligència Tàctica de la CPU`
  - `ROOKIE`: `Novell` / `Punteria Benèvola`
  - `VETERAN`: `Veterà` / `Tàctica Equilibrada`
  - `NIGHTMARE`: `Malson` / `Càlcul Mortal del Vent`
- `LOBBY_SEC_COUNT`: `3. Nombre de Cucs per Escamot (1 a 6 Cucs)`
  - `1 Cuc` / `Duel 1 vs 1`; `2 Cucs` / `Parella Tàctica`; `3 Cucs` / `Escamot Lleuger`; `4 Cucs` / `Clàssic (4 vs 4)`; `5 Cucs` / `Columna Gran`; `6 Cucs` / `Guerra Total (6 vs 6)`
- `LOBBY_SEC_MAP`: `4. Tria d'entre els 8 Indrets de Catalunya`
- `LOBBY_SEC_SQUADS`: `5. Personalitza els Escamots de Cucs i Cares d'Amics`
- Squad headers: `I. Brigada del Pinar (Or)` (colour `#f5b945`); `II. Columna Tramuntana (Grana)` (colour `#ea5648`)
- Hat options (value -> label; the same labels in both selects, differing only in order):
  - `VARIED`: `Barret: Variat (Cada Cuc Diferent!)`
  - `CATALAN`: `Barret: Barretina Catalana`
  - `CASTELLER`: `Barret: Casc de Casteller (Senyera)`
  - `BANDOLER`: `Barret: Capell de Bandoler (Serrallonga)`
  - `PAGES`: `Barret: Barret de Palla de Pagès`
  - `BRISTLES`: `Barret: Plomall de Pèls Urticants`
  - option order in `#hat-t0`: VARIED, CATALAN, CASTELLER, BANDOLER, PAGES, BRISTLES; in `#hat-t1`: VARIED, BANDOLER, CATALAN, CASTELLER, PAGES, BRISTLES.
- Row tooltips/labels: `+ Cara`, `✓ Cara Llista`, tooltip `Puja la foto de la cara d'un amic per a aquest cuc`; index labels `01`..`06`.
- `LOBBY_BTN_RANDOM`: `Noms Catalans Aleatoris`
- `LOBBY_BTN_BACK_TO_GAME` (#btn-close-setup, only if a match exists): `Torna a la Partida Actual`
- `LOBBY_BTN_DEPLOY`: `DESPLEGA AL CAMP DE BATALLA`
- Map cards (name, subtitle, badge) come from `MAPS` (world.js:78-205), see 3.6.

**Top HUD**
- Team 1 title: `I. Brigada del Pinar` (`#f5b945`), HP text `400 PV` initial; format `${hp} PV` (main.js:1672)
- Team 2 title: `II. Tramuntana` (`#ea5648`), `400 PV`
- Timer: initial `30`; during ACTION_WAIT shows `—`
- `#turn-status` initial `Torn de Peluda`; runtime `Torn de ${name}` (state.js:402,1186, main.js:1898; colour `#f5b945` team 0, `#ea5648` team 1)
- `#round-sub` initial `Ronda 1 · Massís de Montserrat`; runtime `Ronda ${roundNumber} · ${MAPS[currentMapIdx].name}` (state.js:1188). CSS uppercases it.
- Wind: label `VENT`; numeric label `0`; runtime `(wind>0?'+':'') + wind + (' »' | ' «' | '')` (state.js:962; trend arrow when |windTarget-windFloat| > 14).
- Pip tooltips (`title`): own team alive: `Toca abans de moure per jugar amb aquest cuc`; other team alive: `Toca per mirar on és aquest cuc`; dead: none.
- Command strip: `Música: Sí` / `Música: No` (`#lbl-music`; tooltip `Activa o silencia la música MIDI catalana`), `Sortir` (tooltip `Surt de la partida actual i torna al menú principal`). Hidden buttons (labels never visible): `Teixir Seda [C]`, `Seda Teixida ✓` (physics.js:69), `Processó: Auto [F]` / `Processó: Sol [F]`, `1J vs CPU` / `2J Local` / `CPU vs CPU` (`MODE_SHORT`, state.js:265), archetype label (see 3.6), `Opcions`, map name.

**Bottom HUD**
- Fuse picker: `METXA [Q/E]:` and buttons `1s 2s 3s 4s 5s` (3s active by default).
- Weapon pill: nav tooltips `Arma anterior [Z o [ ]`, `Arma següent [X o ] ]`; toggle tooltip `Toca o prem [B] per obrir les 16 armes catalanes (Z/X per canviar ràpid)`; chevron `▲ Arsenal [B]` (open: `▼ Tanca [B]`); initial name `Trabuc`, ammo `∞`; switch-worm button `Cuc ⇄` tooltip `Canvia quin cuc controles abans de moure [Tab]`.
- Gamepad aria-labels: `Moure a l'esquerra`, `Moure a la dreta`, `Apuntar amunt`, `Apuntar avall`. Right cluster: `Salt` (tooltip `Salt endavant [Intro]`), `Mortal` (`Salt mortal enrere [Retrocés]`), `−` (`Allunya la càmera [AvPàg]`), `+` (`Apropa la càmera [RePàg]`), `Centra` (`Centra la càmera [V]`), fire label `FOC!`.
- Fire label by weapon (`buildWeaponBar`, main.js:1719-1731): type CHARGE -> `MANTÉN: FOC!`; AIRSTRIKE -> `CORREFOC!`; CULLERA -> `CULLERADA!`; BARRINA -> `BARRINA!`; PONT_PEDRA -> `PEDRA SECA!`; GANXO -> `GANXO!`; type MELEE -> `ATACA!`; type DROP -> `DEIXA TIÓ!`; type UTILITY_JET -> `ALES!`; otherwise `FOC!`.

**Victory (#victory-modal)**
- Kicker `BATALLA COMARCAL COMPLETADA`
- Titles (state.js:1044-1055): team 0 `¡VICTÒRIA DE LA BRIGADA DEL PINAR!` (colour `#f5b945`) sub `La Processó Daurada conquereix ${map name}!`; team 1 `¡VICTÒRIA DE LA COLUMNA TRAMUNTANA!` (`#ea5648`) sub `La Processó Grana conquereix ${map name}!`; draw `¡DESTRUCCIÓ MÚTUA — EMPAT!` (`#f2ecdf`) sub `Tots els cucs han caigut en combat!`. (HTML placeholders: `VICTÒRIA DE LA BRIGADA DEL PINAR`, `La processó conquista el pinar!`.)
- Stats (state.js:1062-1070): `Indret:` map name; `Rondes Totals:` roundNumber; `Dany Brigada del Pinar:` `${n} PV` (gold); `Dany Tramuntana:` `${n} PV` (crimson); full-width row (top border `rgba(255,255,255,.1)`): `Cuc Processionari MVP:` name + ` (${dmg} punts de dany)`; MVP name fallback `—`. MVP = fighter with highest `dmgDealt` (first wins ties starting from fighters[0]).
- Buttons: `Canvia Indret / Escamot`, `Torna a Jugar [Intro]`.
- In-HUD end text (state.js:1091-1098, `#turn-status`): `¡Victòria de la Brigada del Pinar!`, `¡Victòria de la Tramuntana!`, `¡Destrucció Mútua — Empat!`.

**In-canvas strings (also i18n)**
- Aiming HUD: `OBJECTIU CORREFOC`, `↑/↓ o TOCA: MOU OBJECTIU · ESPAI/FOC: ATACA` (renderer.js:2193-2196), `TAB / TOCA CUC: CANVIA` (2226), touch ripples (main.js:820-843): `OBJECTIU CORREFOC`, `¡SALT!`, `¡MORTAL ENRERE!`, and the tapped ally's name in uppercase.
- Off-screen tracker pill: `▲ ${n}m` (renderer.js:544).
- Tombstone: fallen worm name `slice(0,7).toUpperCase()` (renderer.js:1913).
- Floating texts and speech bubbles (created in sim, rendered by view): see `docs/port_inventory_sim.md`; the ones seen in the view-adjacent state/physics code: `¡TORN DE ${NAME}! [TAB]`, `¡MORT SOBTADA — PUJA LA MAREA!`, `¡RÀFEGA DE TRAMUNTANA! »`, `« ¡VENT DE GARBÍ!`, `¡BOSSA DE SEDA REBENTADA! +PINYONS I LARVES!`, `¡SEDA ELÀSTICA TEIXIDA!`, `¡${name}: METAMORFOSI ALADA! (MANTÉN W PER PLANAR)`, `¡ROVELLÓ A LA BRASA!`, `¡XOP DE VI DEL PRIORAT!`, `¡ESCUDELLA EXPLOSIVA! ¡PLUJA DE GALETS!`, `¡${name} CAIGUT!`, `¡CASTELL DE CUCS! +30% FORÇA ENXANETA!`, `¡FÚRIA EN PROCESSÓ! +N% DANY`, `¡CARQUINYOLIS TRENCADENTS!`, `¡REBOT DE MESTRE!`, `¡ZASCA DE FUET!`, `¡CAGA TIÓ, CAGA TORRÓ!`, `¡ALES DE PINAR (W/A/D)!`, `¡CULLERADA DE BOIX! ¡OBRINT PAS!`, `¡BARRINA DE MINAIRE! ¡Brrrrr!`, `¡MARGE DE PEDRA SECA CONSTRUÏT!`, `¡GANXO DE PASTOR! ¡AMUNT!`, `¡GANXO CURT!`, `+35 PV ¡RESINA DE PI!`, `+1 ${WEAPON}!`, `¡CLIC! MINA ARMADA!`, `♪ VIROLAI! AL·LELUIA! ♪`, `¡CAGA TIÓ!`, `¡PARACAIGUDES TRENCAT!`, `¡REBOT EN SEDA!`, `¡BENEDICCIÓ DEL CAGANER! +30 PV I +1 PORRÓ!`, `+25 PV ¡FORÇA DE LA PILOTA! (+25% DANY)`, `+20 PV ¡PINYÓ DAURAT!`, `¡BOING DE SEDA!`, `¡BOING DE ROVELLÓ! +8 PV`, `¡CARAMBOLA!`, `${name}: Glu glu... XOF!`, `¡El Caganer de la Sort!`, `¡Quina Escudella més bona!`, `¡Castell de Cucs! ¡Aleta!`. Authoritative list: sim inventory (grep `text:` in physics.js/state.js).
- Taunts (`ORUGA_TAUNTS`, state.js:278): TURN `A pel pi!`, `En processó!`, `Prepara el trabuc!`, `Tasta el fuet de Vic!`, `Carquinyoli trencadents!`, `Bon cop de falç!`; HIT `Ai els meus pèls!`, `Quina picor!`, `Mal llamp!`, `El meu capoll!`; URTICARIA `Pols urticant!`, `Grata, grata!`, `Al·lèrgia total!`; PROCESSION `Columna unida!`, `Fúria processionària!`, `Seda i ferro!`; METAMORPH `METAMORFOSI!`, `Ales de Thaumetopoea!`, `Ja puc planar!`.
- Worm names (data): `CATALAN_NAMES_POOL_0` (30) and `_1` (30) and default `teamNames` (state.js:~215-246); belongs to `data/` in the port.

**Weapons (names shown in the drawer, pill and fire label; key = hotkey)**

| idx | id | key | name | ammo | type | fuse |
|---|---|---|---|---|---|---|
| 0 | BAZOOKA | 1 | Trabuc | ∞ | CHARGE | |
| 1 | CARQUINYOLI | 2 | Carquinyolis | ∞ | CHARGE | |
| 2 | GRENADE | 3 | Pinya | ∞ | CHARGE | yes |
| 3 | CLUSTER | 4 | Calçotada | 3 | CHARGE | yes |
| 4 | URTICARIA | 5 | Urticant | 3 | CHARGE | |
| 5 | SHOTGUN | 6 | Pedrenyal | ∞ | INSTANT | |
| 6 | FUET | 7 | El Fuet | ∞ | MELEE | |
| 7 | BAT | 8 | La Falç | ∞ | MELEE | |
| 8 | DYNAMITE | 9 | El Tió | 2 | DROP | |
| 9 | HOLY | 0 | Porró Sagrat | 1 | CHARGE | |
| 10 | AIRSTRIKE | - | Correfoc | 2 | TARGET_MAP | |
| 11 | JETPACK | = | Ales Pinar | 2 | UTILITY_JET | |
| 12 | CULLERA | u | Cullera Boix | 3 | TOOL_AIM | |
| 13 | BARRINA | i | Barrina | 3 | TOOL_AIM | |
| 14 | PONT_PEDRA | o | Pedra Seca | 3 | TOOL_AIM | |
| 15 | GANXO | p | Ganxo Pastor | 3 | TOOL_AIM | |

(`hasCustomFuse: true` only for GRENADE (state.js:40) and CLUSTER (state.js:55); it drives the fuse picker visibility, main.js:1706. Each weapon has an inline SVG icon string `w.svg` in state.js, 36x22 viewBox; port as small `Texture2D` (SVG import) or procedural `_draw`.)

### 3.6 Maps (view-relevant fields; source world.js:78-205)

8 maps, id / name / subtitle / badge / weather / slideFriction / sky palette (5 stops) / waterTop / waterDeep:

| id | name | subtitle | badge | weather | sky stops |
|---|---|---|---|---|---|
| MONTSERRAT | Massís de Montserrat | Monestir de Santa Maria, Agulles i Aeri (Bages) | BOIRA I PINARS | POLLEN | `#2a1e2e #593b4f #9c6352 #de9659 #fae6b1` |
| CADAQUES | Cadaqués i Cap de Creus | Església de Santa Maria, Llaguts i Feixes (Alt Empordà) | TRAMUNTANA VIVA | GULLS_BREEZE | `#10355c #1f5a8f #4287bd #7eb8de #cbe6f7` |
| TAULL | Taüll i la Vall de Boí | Sant Climent de Taüll i Aigüestortes (Alta Ribagorça) | NEU DEL PIRINEU | SNOW | `#172b47 #2c4c73 #527ca6 #8eb3d4 #d9eaf7` |
| CASTELLFOLLIT | Castellfollit de la Roca | Cinglera Basàltica i Fageda d'en Jordà (La Garrotxa) | FULLES DE FAIG | AUTUMN_LEAVES | `#2b1d1c #633c2e #a8673e #dea05a #f7d89c` |
| DELTA_EBRE | Delta de l'Ebre i Buda | Arrossars, Barraques, Far del Fangar i Flamencs (Montsià) | FLAMENCS I DUNES | POLLEN | `#2d1b38 #733857 #c45d56 #f29f60 #ffebb3` |
| TARRACO | Tàrraco Imperial | Amfiteatre Romà, Pont del Diable i Mare Nostrum (Tarragonès) | PEDRA ROMANA | GULLS_BREEZE | `#162a4a #2e557c #6e7889 #d98a54 #fce0a2` |
| PEDRAFORCA | Massís del Pedraforca | L'Enforcadura, Tartera i Serra del Cadí (Berguedà) | CIM MÀGIC | SNOW | `#1a1636 #382e63 #5c5b94 #8ea8cf #dbf0fa` |
| MONTBLANC | Muralles de Montblanc | Torres Medievals, Llegenda de Sant Jordi i Prades (Conca) | DRAC I ROSES | AUTUMN_LEAVES | `#24111c #541e33 #8f3438 #cf6a44 #f7be79` |

(HTML says "8 Indrets"; a code comment says "4". There are 8 entries.) Water colours, turf/soil/rock colours and treeStyle are in the world inventory; `waterTop`/`waterDeep` are used by the view (renderer.js:2768-2770). The sky `currentSkyPalette` is the map palette with a per-match random RGB shift (r +-14, g +-11, b +-15) computed by `regenerateMatchAtmosphere` (state.js:466-478).

Terrain archetype labels written to `#lbl-archetype` (hidden): `Feixes de Pedra Seca`, `Agulles i Cingles`, `Cova de Dos Nivells`, `Balcons Sospesos`, `Doble Massís`, `Congost Escalonat`, `Ciutadella Alta`, `Illes Escalonades` (world.js:617-624).

---

## 4. Rendering

### 4.1 Canvas, DPR and screen vs world space

- Canvas backing store: `canvasDpr = min(devicePixelRatio, 2)`; `canvas.width = floor(innerWidth*dpr)`, `canvas.height = floor(innerHeight*dpr)` (state.js:209-215). CSS size 100% of `#viewport`. Resize and orientationchange (+120 ms) re-run it.
- `viewW/viewH` are CSS pixels; `W/H = canvas.width/height` (device px) inside `render()`. Camera `scale` already includes `canvasDpr` (see 4.2). Every screen-space element drawn with raw numbers multiplies by `canvasDpr` explicitly (tracker pill, touch ripples, renderer.js:527-565); parallax layers use `tr.scale` which includes dpr.
- Godot mapping: use the logical viewport (stretch mode `canvas_items`, aspect `expand`), draw in logical px, set `scale = cssBaseScale * cam.zoom * userZoomMult` (no dpr factor), and remove all `* canvasDpr`. All numbers in the parallax layers that are literal screen px (e.g. `340*tr.scale` sun radius, 140/65/35/55 px ray offsets) are multiplied by `tr.scale` in the JS, so they scale with zoom; keep that.

### 4.2 Camera (renderer.js:6-40, main.js:340-351)

State `cam = {x, y, targetX, targetY, panOffsetX, panOffsetY, zoom, targetZoom, mouseOffX, mouseOffY, smoothMouseX, smoothMouseY}`, `userZoomMult` (clamp 0.50..2.25, default 1.22, changed by wheel (-sign*0.08), pinch (multiplicative), PageUp/PageDown (+-0.14), `+`/`-` buttons (+-0.16)).

`getCameraTransform()`:
```
isPortrait        = viewW < viewH && viewW <= 820
isLandscapeMobile = viewH <= 540 && viewW > viewH
cssBaseScale = isPortrait        ? clamp(viewW/600, 0.56, 0.86)
             : isLandscapeMobile ? clamp(min(viewW/1220, viewH/580), 0.54, 0.88)
             :                     clamp(min(viewW/1620, viewH/760), 0.85, 1.45)
scale = cssBaseScale * canvasDpr * cam.zoom * userZoomMult
portraitOffsetY = (isPortrait && appStage==='PLAYING') ? 42 : 0
cx = cam.x + cam.smoothMouseX
cy = cam.y + cam.smoothMouseY + portraitOffsetY
```
World -> screen: `screen = (W/2, H/2) + (world - (cx,cy)) * scale`. `screenToWorld(clientX, clientY)` inverts it using `getBoundingClientRect` (client CSS px -> canvas px ratio).

Per-frame smoothing (main.js:346-351): `camLerp = 1 - 0.015^rawDt` (frame-rate independent, rawDt = unscaled dt capped 33 ms) applied to `cam.x, cam.y, cam.zoom, smoothMouseX/Y`. Note `rawDt`, not slowed `dt`, so slow-motion does not slow the camera.

Mouse parallax (main.js:496-501): `cam.mouseOffX = (clientX/viewW - 0.5)*36`, `mouseOffY = (clientY/viewH - 0.5)*18` -> smoothed -> shifts the camera centre by up to +-18/+-9 world px (which also shifts the background by more, see 4.3). On touch devices mousemove is ignored while a touch is dragging; touch never updates it.

Camera targets (main.js:293-339), evaluated in this priority order while PLAYING:
1. A projectile exists (`projectiles.length > 0`): pan offset zeroed; `impactCam.active=true`, impact pos = last projectile; `target = (clamp(p.x,220,W-220), clamp(p.y,160,560))`, `targetZoom = slowMo ? 1.16 : 1.00`.
2. Airstrike plane: target `(clamp(plane.targetX,...), 360)`, zoom 0.96.
3. Drowning worm: target `(clamp(x,220,W-220), clamp(WATER_Y-40, 240, 580))`, zoom 1.14.
4. `impactCam.active` and phase ACTION_WAIT/TURN_DELAY: hold at `impactCam` (clamped like 1), zoom `slowMo ? 1.18 : 1.08`.
5. Active fighter: `target = (clamp(f.x + panOffsetX, 200, W-200), clamp(f.y - 35 + panOffsetY, 150, 580))`, zoom `slowMo ? 1.20 : 1.08`. If left/right (or up while not aiming the airstrike) keys are held, `panOffset` decays `lerp(.., 0, 0.14)` per frame.
Pan offsets are clamped to X +-TERRAIN_W*0.85, Y -360..+320. SPLASH/LOBBY: drift (see 2.4). `impactCam` is also actively re-pointed at nearby moving fighters during ACTION_WAIT (main.js:236-258, radius 520).

`impactCam` object (state.js:424): `{active, x, y, trackedWorm}`; resetting presumably in `startNextTurn`/`initMatch` (sim).

Camera pan input: shift+arrows (`panKeys`, speed 560 px/s X and 420 px/s Y in world units, uses rawDt), mouse drag (`panMapByScreenDelta`, `worldPerCssPx = canvasDpr/scale`), two-finger touch, clicking a pip or `V/Home/Centra` resets (`panOffset = 0`).

Screen shake: `shake *= 0.04^dt` per frame (main.js:117), and `render()` translates the whole canvas by `(rand-0.5)*shake*1.4` px when `shake > 0.2` (random each frame; applies to the whole screen incl. backgrounds). In Godot apply via `Camera2D.offset` or a root `Node2D.position` jitter. `hitStopTimer` freezes the simulation but still renders (see §6). `flashLight` decays `-2.6/s`.

### 4.3 `render()` pipeline, in order (renderer.js:42-581)

Screen space first (device px, no camera), then the world plane (camera transform), then screen-space overlays.

| # | Layer | Lines | Space | What |
|---|---|---|---|---|
| 0 | Shake | 48-51 | screen | `ctx.save()`, random translate if `shake>0.2` |
| 1 | Sky gradient | 56-65 | screen | Vertical linear gradient over full height with stops at 0, 0.32, 0.64, 0.86, 1.0 using the 5 colours of `currentSkyPalette` (fallback `MAPS[i].sky`) |
| 2 | Background JPG | 67-91 | screen | See 4.4. Followed by an atmospheric grade gradient `rgba(8,10,15,.12)` at 0, `rgba(10,14,20,.08)` at 0.65, `rgba(6,10,16,.38)` at 1 (only when the image is loaded) |
| 2b | Mountain ridges | 94 -> 640-686 | screen | Two procedural silhouettes (`mountainRidgeFar`, `mountainRidgeNear`, 97 samples each in 0..1 of H), see 4.7 |
| 3 | Sky atmosphere | 97 -> 688-825 | screen | Sun glow, 5 god rays (screen blend), tiled cloud veil, 12 sky birds, cloud flock (24-28 clouds, 3 tiers) |
| 4 | World plane | 102-517 | world | `translate(W/2,H/2); scale(s); translate(-cx,-cy)` |
| 4.1 | Water back | 107 -> 2746 | world | Dark translucent water strip behind the terrain |
| 4.2 | Terrain back (rock wall) | 109-112 | world | `drawImage(terrainBack, perspX, perspY)`; `perspX = clamp((TERRAIN_W/2 - cx)*0.018, -14, 14)`, `perspY = -9 + clamp((400 - cy)*0.02, -6, 6)` (fake 2.5D extrusion, the back layer shifts opposite to the camera) |
| 4.3 | Terrain front | 115 | world | `drawImage(terrainFront, 0, 0)` (destructible bitmap incl. trees/nests baked by world.js) |
| 4.4 | Surface flora | 118 -> 827-995 | world | per-biome plants, sway |
| 4.5 | Ground contact shadows | 121 -> 997-1030 | world | ellipses under entities |
| 4.6 | Updrafts | 124-145 | world | gradient column + 3 flowing streaks |
| 4.7 | Silk nests | 148-201 | world | |
| 4.8 | Silk webs | 204-234 | world | |
| 4.9 | Pine nuts | 237-256 | world | |
| 4.10 | Larvae swarms | 259-274 | world | |
| 4.11 | Rovellons, caganers, escudelles, tombstones, mines, crates, barrels | 276-282 | world | per-entity `draw*` helpers (order as listed) |
| 4.12 | Grapple ropes | 285-303 | world | |
| 4.13 | Procession tethers | 306-321 | world | dashed golden/crimson curve between linked allies (`f.memberIdx < ally.memberIdx` to draw once) |
| 4.14 | Fighters | 324-326 | world | `drawFighter` for each alive fighter (dead ones are tombstones) |
| 4.15 | Aiming HUD | 329-331 | world | only `appStage==='PLAYING' && turnPhase==='TURN_PLAY' && active alive & not drowning && !AI` |
| 4.16 | Airstrike planes, projectiles | 333-334 | world | |
| 4.17 | Fireballs | 337-358 | world | `screen` blend radial gradients (normal vs urticating purple) |
| 4.18 | Smoke puffs | 361-372 | world | radial gradient from `s.color` to transparent |
| 4.19 | Shockwaves | 375-384 | world | stroked circles, width 3.2, alpha*0.68 |
| 4.20 | Water plumes | 387-406 | world | gradient quadratic spout + foam ellipse ring |
| 4.21 | Particles | 409-451 | world | beam / ember / hair / spark / debris rect variants |
| 4.22 | Explosion flash light | 454-466 | world | `screen` radial gradient radius 360 at `flashPos`, alpha `flashLight*0.82` / `*0.38` |
| 4.23 | Water front | 468 -> 2765-2845 | world | animated wave polygon, foam crest, sun column reflection, fireball reflections, caustic glints |
| 4.24 | Bubbles | 470-480 | world | |
| 4.25 | Speech bubbles | 483-502 | world | |
| 4.26 | Floating texts | 505-515 | world | |
| 5 | Weather layer | 520 -> 1207-1293 | screen | wind ribbons + snow / sea mist / autumn leaves / pollen particles |
| 5b | Off-screen projectile pill + touch ripples | 523-566 | screen (dpr px) | |
| 6 | Splash procession | 569-571 | screen | only when `appStage === 'SPLASH'` |
| 7 | Vignette | 574-578 | screen | radial gradient centre `rgba(0,0,0,0)`, inner radius `min(W,H)*0.4`, outer `max(W,H)*0.76`, edge `rgba(5,6,9,.58)` |

Godot layer mapping: a `CanvasLayer` stack with `follow_viewport_enabled` off for screen-space layers (sky/bg/ridges/clouds/weather/vignette), and a `Node2D` world root with `Camera2D` for 4.x. 4.x z-order with `z_index`/child order. The two screen blends (`screen`) map to `CanvasItemMaterial.blend_mode = BLEND_MODE_ADD` (or a custom `blend_screen` shader; ADD is a close approximation, document the difference).

### 4.4 Background JPGs and parallax (renderer.js:67-91)

- Each map has one 1376x768 JPG (aspect 1.7917). It is drawn full-screen, not tiled:
  ```
  drawW = W*1.28; drawH = drawW/aspect
  if drawH < H*1.22: drawH = H*1.22; drawW = drawH*aspect
  parX = -dxCam*0.14*scale - cam.smoothMouseX*1.6        // dxCam = cx - TERRAIN_W/2
  parY = -dyCam*0.16*scale - cam.smoothMouseY*1.3        // dyCam = cy - 400
  bx = (W-drawW)/2 + clamp(parX, -(drawW-W)*0.48, +(drawW-W)*0.48)
  by = (H-drawH)/2 + clamp(parY, -(drawH-H)*0.48, +(drawH-H)*0.48)
  ```
  i.e. the image overscans 28% (or 22% vertically) and slides at 14% / 16% of the camera speed with clamping so edges never show. Image is not flipped or tinted; the grade gradient above is overlaid.
- If the image is not loaded yet the sky gradient alone is shown (no loading screen; images start loading at boot in world.js:209-214).
- Godot: `Sprite2D` (or `TextureRect`) under a `CanvasLayer` (layer -10) with `texture = ArtCatalog.map_background(id)`, repositioned in `_process` using the formulas; or a `ParallaxBackground` is not suitable because the offsets depend on `scale` and clamping. In web builds, import JPGs as `Lossy` / VRAM-compressed disabled, mipmaps off; total about 7 MB of JPG.
- Lobby thumbnails: same JPG, `object-fit: cover` in a 112 px card (no tint besides CSS filters, see 3.3).

### 4.5 Fighter rendering (`drawFighter`, renderer.js:1298-1566; head 1568-1712; hats 1714-1803; held weapon 1931-2174)

Data read from the fighter: `x,y,r(12),facing(+-1),hp,maxHp,team,id,name,walkCycle,squashX/Y,flipAngle,slideAngle,sliding,grounded,vx,vy,drowning,dizzyTimer,hurtTimer,urticatingTicks,jetFuel,metamorphosed,castellTower,linkedAllies[],segs[] (6 trail segments {x,y}),bodyColors[3],dorsalColor,individualHat,hasMustache,customFaceImg,batSwingTimer,spoonTimer,drillTimer,lastChargePower`.

Colours: `teamCol = team0 '#f5b945' : team1 '#ea5648'`; `dorsalCol = f.dorsalColor` (fallback `#e87a24`/`#d93b2b`); `bodyCols` (fallback `#3a3f4d,#22252e,#111318`); six body palettes and dorsal palettes are in state.js:865-874; bristles `rgba(245,236,215,.82)` or `#d88aff` when `urticatingTicks > 0`.

1. **Body segments** (draw order: tail i=5 to neck i=0, so the neck is on top):
   - If `grounded && !drowning`: a silk thread polyline from `(x, y+8)` through every `(seg.x, seg.y+5)` colour `rgba(245,242,235,.28)` width 1.4.
   - For each segment: radius `segR = 6.8 - i*0.45`; `stepWave = sin(walkCycle*1.5 - i*0.9)`.
     - prolegs (unless drowning): two small `#d98a4e` circles r 1.7 at `(-1.2, segR - 0.5 + max(0, stepWave*1.4))` and `(1.5, segR - 0.5 + max(0, -stepWave*1.4))`.
     - 7 bristles `b=-3..3`: angle `-PI/2 + b*0.34 + sin(tNow*6 + i + b)*0.08`, from radius `segR-1` to `segR + (b even ? 4.8 : 3.2)`, width 1.1.
     - body: radial gradient centre (-1,-2) r1 -> (0,0) r segR: stops `bodyCols[0]`, 0.65 `bodyCols[1]`, 1 `bodyCols[2]` (drowning: `#6a9ab8` -> `#263e52`), stroke `#0d0e12` 1.5.
     - dorsal patch (not drowning): ellipse `(0, -segR*0.42)` radii `(segR*0.62, segR*0.32)` colour `dorsalCol`; spiracle dot `teamCol` r 1.3 at `(0,1.2)`.
   - Segment positions come from the sim (trail follow in physics.js:~990; the view only draws).
2. **Head group** at `(f.x, f.y)`: `bob = grounded ? sin(walkCycle)*1.8 : 0`. Rotation rule: `flipAngle` if non-zero; else if sliding && grounded `slideAngle + facing*0.32`; else if airborne and speed > 210 `sin(tNow*14)*0.35` (wobble). Then `scale(facing*squashX, squashY)`.
   - Wings/jetpack (`metamorphosed || jetFuel > 0`): two ellipses (-8,-8) r(11,5.2) rotation `-0.45 + flap` fill `rgba(246,207,119,.76)` (metamorphosed) or `#c89b52` (jetpack), stroke `#fff5df`; second ellipse (-10,-4) r(7.5,3.5) fill `rgba(232,122,36,.58)`. `flap = airborne ? sin(tNow*32)*0.38 : sin(tNow*5)*0.12`.
   - Thorax collar: 7 forward bristles `b=-4..2`, angle `-PI*0.55 + b*0.28`, from r 6 to 13.5, width 1.25.
   - Thorax ellipse centre (-1, 1+bob) r (7.8, 8.2) fill `#252934` stroke `#0e1015` 1.7; team stripe ellipse (-1, -4+bob) r (5.5, 2.5) `teamCol`.
   - Head translate `(2, -8+bob)` (`drawFighterHead`):
     - custom face: circle r 10.5 clip, image drawn at (-11,-11) 22x22, ring stroke `teamCol` width 2.0 (no eyes/hat details except the hat below).
     - default head: radial gradient (2,-3,1)->(0,0,10), stops `#4f5666`, 0.55 `#252932`, 1 `#0f1116` (drowning `#7ab4d6 / #3d6987 / #1d3547`); circle r 9.2 stroke `#090a0d` 1.8; specular arc r 7.6 from -0.78PI to -0.18PI `rgba(255,250,235,.34)`; antennae: curves `(2,-8)->(5,-14)->(8+w,-13)` and `(-2,-8)->(-1,-14)->(2-w,-14)` with `w = sin(tNow*8 + f.x)*1.4`, stroke `#1b1e26` 1.5, tips `teamCol` circles r 1.7 / 1.5.
     - Eyes: blink `((tNow*0.9 + id*1.73) % 4.2) > 4.04` and not dizzy/hurt. `isNearDanger` = any projectile within 115 or any triggered mine within 115. `isFiringSquint = f===activeFighter && isCharging`. `eyeScaleY`: blink 0.12, danger 1.22, squint 0.78, else 1. Eye whites `#fff8e7`: ellipses (3.4,-1.2) r(2.7, 3.3*s) and (7.1,-1.2) r(2.2, 2.8*s). If `dizzyTimer>0 || hurtTimer>0.2`: X marks (strokes `#181412` 1.3) at the two eyes. Else if not blinking: pupils `#141110` r 1.35 (0.82 if sliding/drowning/danger) at (4.2,-1.2) and (7.7,-1.2) (second r*0.85); highlights white r .65/.55 at (3.7,-2.0), (7.3,-1.9); brow line in `teamCol` width 1.6: danger (1.0,-3.6)->(8.4,-5.0); squint (0.8,-5.0)->(8.8,-2.5); normal (1.0,-4.6)->(8.6,-3.2).
     - mandibles: triangle `(5.5,4.2),(8.5,5.5),(5.0,6.2)` `#d48a46`.
     - mustache (if `hasMustache`): two quadratic curves `#181412` 1.4: `(4.5,3)->(1,3.5)->(-1.5,1)` and `(5.5,3)->(9,3.2)->(10.8,0.8)`.
     - hat: `teamHats[team] === 'VARIED' ? (f.individualHat || 'CATALAN') : teamHats[team]`, drawn in head space (below).
3. **Urticating itch sparks** (not rotated/flipped group): 3 short strokes `#d88aff` 1.5 around `(cos a*13, -8 + sin a*8)` to radius 18/11, `a = tNow*9 + i*2.1`.
4. **Dizzy stars**: 3 circles r 2.6 orbit at `(cos a*14, -24 + sin a*4.5)`, `a = tNow*6.5 + i*2PI/3`, alternating `#ffe066` / `#ffffff`.
5. **Held weapon**: `isCurrent && !sliding && !drowning && phase in (TURN_PLAY, RETREAT)`: `drawHeldWeapon` (translate (0,-3), rotate `aimAngle + swing`) in non-flipped worldspace relative to the fighter origin (note it is drawn after the `ctx.restore()` of the flipped group, so `aimAngle` already encodes facing). `swing = batSwingTimer>0 ? sin(batSwingTimer*18)*1.8 : 0`. Per-weapon pictograms listed in 4.9.
6. **Nameplate / pill**: golden aura circle (`castellTower` dashed `rgba(255,217,102,.72)` w 2.2; `linkedAllies>0` `rgba(245,200,105,.38)` w 1.5, radius `19 + sin(tNow*6)*1.5`, centre (0,-5)). `showFullCard = isCurrent || hurtTimer>0 || dizzyTimer>0 || mouseWorld within 62 of f`:
   - full card: font `800 12px Plus Jakarta Sans`, name pill centred at `y=-36`, rounded rect `tw = textW + 18`, h 18, radius 9, fill `rgba(11,14,22,.84)`, stroke `teamCol` (current, 1.6) or `rgba(240,195,110,.38)` (1.1), text `#fff8eb`; HP bar 38x4.5 (+2 px frame `rgba(0,0,0,.72)`) fill `teamCol`, min width 2; jet fuel bar 3 px at +14 (`#5ad2f4`) if `jetFuel>0`; bobbing triangle arrow above (current and TURN_PLAY): `arrowY = labelY - 21 + sin(tNow*6)*3`, `teamCol`.
   - else compact pill at `y=-28`: 28x4 bar, frame `rgba(9,12,18,.72)`, fill `teamCol`.

Notes for `caterpillar_body.gd`: segments are procedural, drawn each frame from the sim `segs`; use `_draw()` with `draw_circle`, `draw_arc`, `draw_polyline`, `draw_set_transform`. Radial gradients: pre-bake a small `GradientTexture2D` (fill `FILL_RADIAL`) per palette and draw as a textured quad, or approximate with 3 concentric circles. Names/pills: `Font.draw_string` + `draw_style_box`/`draw_rect` rounded via `StyleBoxFlat.draw`.

### 4.6 Hats (renderer.js:1714-1803), in head space (origin at head centre, y up negative)

- `CATALAN` (barretina): band rect (-8,-9.5,15x2.8) `#16181f`; cap path `M(-7.5,-9.5) Q(-2,-19,-12,-14) Q(-6,-11,6.5,-9.5)` fill `#d93228` stroke `#16181f` 1.2.
- `CASTELLER`: half disc centre (-0.5,-8.2) r 8.2 (upper half) fill `#f5c23b` stroke `#14161d` 1.3; four red stripes `#d92b22` 1.5 from `(s,-8.5)` to `(s*0.75,-15.8)` for `s = -4.5, -1.5, 1.5, 4.5`; band rect (-8.5,-9.2,16x2.4) `#181b22`.
- `BANDOLER`: crown quad `(-6,-8.5)(-4,-17)(3,-17)(5,-8.5)` `#241e1a` stroke `#0e0b09`; red band (-5.5,-11,10x2.2) `#d93228`; buckle (-1,-11.3,2.6x2.6) `#f5b945`; brim ellipse (-0.5,-8.5) r(11.5,2.3) rot -0.05 `#2b231e`.
- `PAGES`: half disc (-0.5,-8.5) r 7.6 `#e8c168` stroke `#5c3d14`; red band (-7.8,-10.5,14.6x2) `#d93228`; brim ellipse (-0.5,-8.2) r(12.2,2.4) rot -0.04 `#f0cf7b`.
- default (`BRISTLES`): 7 strokes `#ffae42` 1.4 from `(i*1.8,-8)` to `(i*2.8, -15 - (i even ? 2 : 0))`, `i=-3..3`.
- Hat choice list for VARIED: `ALL_HAT_STYLES = CATALAN, CASTELLER, BANDOLER, PAGES, BRISTLES` (state.js:851).

### 4.7 Other draw routines

**Parallax sky**
- `drawParallaxMountainRidges` (640-686): far ridge parallax `(-dxCam*0.065*s - smoothMouseX*0.8, -dyCam*0.08*s)`, span `W*1.48`, clamp +-48% of overscan; fill gradient from `H*0.25` to `H`: `skyPal[1]+'44'` (hex alpha 0x44) to `rgba(10,14,22,.34)`. Near ridge: parallax `(-dxCam*0.115*s - smoothMouseX*1.3, -dyCam*0.13*s)`, gradient from `H*0.38`: `skyPal[0]+'52'` to `rgba(8,10,16,.42)`. Polyline of 97 points `y = H*ridge[i] + parY`. Ridge data generated in `regenerateMatchAtmosphere` (state.js:543-571) from `fbm` and per-style shaping (sim/world inventory).
- `drawSkyAtmosphereAndClouds` (688-825):
  - Sun position `sunX = W * k - dxCam*0.04*s` with `k`: 0.68 MONTSERRAT/DELTA_EBRE, 0.30 CADAQUES/TARRACO, 0.44 TAULL/PEDRAFORCA, else 0.62; `sunY = H*0.19 - dyCam*0.04*s`. Sun colour `r,g,b` string: DELTA `255,175,135`; MONTBLANC `255,165,105`; PEDRAFORCA `215,210,255`; warm maps (MONTSERRAT, CASTELLFOLLIT, DELTA, MONTBLANC, TARRACO) `255,205,115`; CADAQUES `255,232,165`; TAULL `210,235,255`. Radial glow radius `340*s` (inner 8*s): alpha .42 / .16 (at .35) / 0.
  - 5 god rays (screen blend): `phase = tNow*0.28 + r*1.35`, `alpha = (0.045 + sin(phase)*0.02) * (TAULL ? 0.78 : 1)`, base `rx = sunX + (r-2)*140*s`, `spread = (65 + (r%2)*35)*s`, `slant = (wind*0.9 + (r-1.5)*55)*s`, quad from the sun row down to `H*0.92`, linear gradient alpha*1.4, *0.55 (at .65), 0.
  - Cloud veil: `ASSETS.cloudLayer` tiled horizontally with alpha 0.34 (TAULL 0.48), tile width `max(400, texW*s)`, drift `(tNow*(10 + wind*0.25)) % texW`, parallax `dxCam*0.14`, y offset `(MONTSERRAT ? H*0.14 : H*0.04) - dyCam*0.10*s`.
  - 12 sky birds: stroke width `1.6*s`, colour `rgba(42,26,22,.58)` (MONTSERRAT, CASTELLFOLLIT) else `rgba(28,38,48,.55)`; position `W/2 + (b.x - TERRAIN_W/2 - dxCam*b.z)*s`, `y = H/2 + (b.y - 400 - dyCam*b.z + sin(tNow*2.5 + wingPhase)*6)*s`, flap `sin(tNow*8.5+wingPhase)*size*0.65*s`; shape two quadratics (wing tips at `+-span`, `span=size*s`). Bird motion update is in `updateDynamicWind` (state.js:~1000-1010, wraps at -350 / TERRAIN_W+350).
  - Cloud flock (24 clouds, 28 for CIRRUS_STREAKS; tiers by index: <8 tier 0 (z .09), <17 tier 1 (z .20), else tier 2 (z .36)): each cloud draws 3 passes of ellipse lobes (shadow `rgba(98,64,84,.42)` for MONTSERRAT/CASTELLFOLLIT/DELTA/MONTBLANC else `rgba(64,80,108,.42)` at +7 y and 0.98x/0.88y; mid colour; rim colour at -4 y x0.92/0.82), `globalAlpha` tier0 .52, tier1 .76, tier2 .46, wind shear `transform(1,0,clamp(wind*0.0018,-.18,.18),1,0,0)`, bob `sin(tNow*0.9 + bobPhase)*4`; skipped when `cx` is outside `[-320s, W+320s]`. Colours by map: rim `DELTA #ffe5dc, MONTBLANC #ffe0c8, PEDRAFORCA #eee8ff, MONTSERRAT/CASTELLFOLLIT/TARRACO #fff0d4, CADAQUES #fff9eb, else #ebf5ff`; mid `DELTA #f2b6b0, MONTBLANC #de9e8b, PEDRAFORCA #c8bfe8, warm trio #f0cbb0, CADAQUES #dce6f0, else #c4d6e8`.
  - Cloud drift (position update) is in sim `updateDynamicWind` (state.js:973-1010).
- Procedural cloud texture: `renderCloudLayer(1600, 320)` in world.js (noise-based, generated once at boot). In Godot, bake an `Image`/`NoiseTexture2D` at startup (or ship a PNG generated offline with the same algorithm).

**Weather (`drawWeatherLayer`, 1207-1293)**, screen space, 110 particles `weatherParticles` (state.js:436) + 16 `windRibbons` (state.js:575):
- Wind ribbons only if `|wind| > 4`: colour `255,226,155` (wind>=0) / `165,228,255` (wind<0); length `r.len*(0.45 + |wind|*0.011)*s*dir`, wave `sin(tNow*4.5 + phase)*amp*s`, alpha `r.alpha * clamp(|wind|/55, .22, .95)`, horizontal gradient transparent-colour-transparent, width `(1.3 + |wind|/100*1.2)*s`, bezier `M(sx-len/2, sy - wave*0.4) C(sx-len*0.15, sy+wave)(sx+len*0.15, sy-wave)(sx+len/2, sy+wave*0.3)`; culled outside screen +-220/60 px; parallax `x/y - dxCam*z`.
- Per weather: SNOW (x drifts `m.vx*1.1 + wind*0.85`, y falls 95/s modulo 800, dot r `m.r*1.15*m.z*s`, `rgba(242,248,255,.72)`), GULLS_BREEZE (sea mist `rgba(235,248,255,.36)` r `m.r*1.5*s`, drift `vx*1.5 + wind*0.6`, y bob `sin(tNow*1.8+phase)*10`), AUTUMN_LEAVES (rotating ellipses r(1.7,0.95)*m.r*s, `rgba(230,118,45,.68)` if phase > 3.14 else `rgba(245,182,66,.68)`, fall 48/s, drift `vx*1.2 + wind*0.75`), default POLLEN (`rgba(255,224,150,.48)`, dot r `m.r*m.z*s`, drift `vx + wind*0.45`, bob `sin(tNow*1.5+phase)*12`). Wrapping modulo `TERRAIN_W`.

**Flora (827-995)**: `surfaceFlora` entries `{x,y,type,variant,scale,phase}`: transform translate, scale, rotate by `sway = sin(tNow*2.8 + phase)*(0.08 + |wind|*0.0028) + wind*0.0035`. Per biome type MONTSERRAT rosemary/ginesta (5 curved stems `#3b5c34` + dots `#ffd54f`/`#b39ddb`), CADAQUES (agave `#4e7a6b`/`#254238` or prickly pear `#5c8c46` + `#ff7043` dots), TAULL edelweiss (`#f4f9ff` petals), DELTA_EBRE reeds + cattail (`#6c8f3f`, `#5c381e`), TARRACO poppies (`#e53935`), PEDRAFORCA gentians (`#448aff`), MONTBLANC roses (`#d50000`), default autumn ferns (`#d9531e/#e89b2d/#6e8c3a`). Generation in sim/world (spawn rules).

**Ground shadows (997-1030)**: `findSurfaceY(x, y-4)`, draws only if `-6 <= (surfaceY - y) <= 54` and above water; ellipse offset by `sunShift*(0.4 + (1-falloff)*0.8)` where `sunShift = -3.5` (MONTSERRAT, CASTELLFOLLIT), `3.5` (CADAQUES), else `1.0`; `falloff = clamp(1 - dist/54, .15, 1)`; fill `rgba(6,8,14, alpha*falloff)`. Fighter: (x, y+r) rx 12.5 ry 3.8 alpha .44; every second segment `(7.5 - i*0.5, 2.5, .32)`; barrels (14,4.2,.48), crates (12,3.6,.45), mines (9,2.8,.42), rovellons (`r*0.9`, 3.8, .44), caganers (10,3.2,.44), tombstones (11,3.4,.46). Uses sim query `findSurfaceY` so the view needs a terrain query interface.

**Entities**: `drawRovello` (1032-1084; squash `scale(2 - squash, squash)`; warm glow gradient; stalk `#f2d8bd`; cap path with gradient `#ff8833 / #d9531e / #8c2d10`; green spots `#4e8c45`), `drawCaganer` (1086-1147; bobbing `sin(tNow*3.5+bobPhase)*1.5`; golden aura r 20; red barretina; black trousers; red sash `#d93226`; white shirt `#f7f3e8`; head `#f2c199`), `drawEscudella` (1149-1205; embers flicker `sin(tNow*9 + steamPhase)>0 ? '#ff7b29' : '#e03e1a'`; black pot `#23262e`; broth `#f2b949`; pilota `#a86438` + galet `#fff5df` bobbing), `drawTombstone` (1872-1929; stone gradient `#888590 / #6c6a72 / #49474f`, cross, mossy base `#4e7c3e`, name text 5.5 px `700 Plus Jakarta Sans` `#e2dfd7` 7 chars uppercase; mini barretina `#d93228` for team 0, `#3b82f6` for team 1), `drawMine` (1853-1870; body `#3b424c`, light flashes `sin(tNow*32)>0` when triggered else `sin(tNow*3)>0.7`, `#ff3b30` / `#6e1c18`), `drawCrate` (1805-1851; parachute when `parachuting`: sway `sin(tNow*3.5 + x*0.05)*0.16`, canopy semicircle r 19 `#d9483b` (medkit) / `#d99b43`; box 20x20 `#7a5434` or medkit `#e8e4dc` + red cross `#d93829`), `drawBarrel` (2409-2437; horizontal gradient `#591c15 / #a63427 / #3b110c`, bands `#2d3138`, diamond `#f3c66f`), `drawAirstrikePlane` (2711-2744; flip when `vx<0`; body `#2b3038`; exhaust flame random length `58 + rand*10`).
- Silk nest (148-201), silk web (204-234), pine nut (237-256), larvae (259-274), updraft (124-145) per the code at those lines; all procedural, colours given inline (nest cocoon `#f5f0e6`/`#d4a153`, pulse `1 + sin(tNow*5 + swayPhase)*0.05`; web strands `rgba(255,248,225,.95)` centre and `rgba(245,185,69,.55)` sides, vibration `sin(tNow*42)*vibration*9`; nut `#f6cf77`/`#6e471b`; larvae `#252934`/`#ffae42`).

**Projectiles** (`drawProjectile`, 2439-2709): trail ribbon (`p.trail` points, per-segment alpha `frac*0.55` HOLY gold, `0.52` URTICARIA violet `216,138,255`, `0.48` BAZOOKA/BOMBLER orange `255,165,75`, else `0.34` white `245,238,220`; width `max(1, frac * 7.5/6/4.2)`), then per type:
- CARQUINYOLI (spin `ang + tNow*14`; fuet slice variant `isFuetSlice` r 6.2 `#8a2434` ring `#f4eee1`; biscotti 15x8 `#c87d32` with two almonds `#fff5df`),
- BAZOOKA (ball r 6 `#282d34` rim `#d99b43`, flame triangle `#ff9b3b` random length 9-15 behind), BOMBLER (calçot with `#ff6b2b` ember), URTICARIA (ellipse 14x9 `#7a2eb0` + `#d88aff` tail),
- GRENADE (pine cone ellipse r x r*1.15 `#7c4d2b`), CLUSTER (calçot bundle), HOLY (porró with halo gradient r 19, `#f0b849`, wine `#a81c1c`, cross), each rotated by `p.ang` with fuse number text `700 12px` at (0,-14) (`Math.ceil(p.fuse)`),
- DYNAMITE (Tió de Nadal log 18x10 `#8c5830`, blanket `#d93829`, face, barretina `#e03228`, fuse spark `sin(tNow*35)>0 ? '#ffee77' : '#ff6622'`, fuse number at (0,-15) `#ffeb99`).

**Water**: `drawWaterBack` (2746): polygon from x=-4800 to TERRAIN_W+4800, step 32, `y = WATER_Y - 4 + sin(x*0.018 + tNow*2.1)*4`, fill `rgba(18,38,52,.72)`, bottom `TERRAIN_H + 3600`. `drawWaterFront` (2765): gradient `waterTop -> waterDeep` from `WATER_Y` to `TERRAIN_H+220`; wave y `WATER_Y + sin(x*0.022 - waveSpeed)*4.5 + cos(x*0.05 + tNow*1.6)*2` with `waveSpeed = tNow*(2.8 + wind*0.025)` plus ripple displacement `sin(dist*0.09 - rp.phase*14) * rp.amp * (1 - dist/260) * rp.life` for ripples within 260; crest stroke 2.4 (`rgba(255,224,170,.58)` MONTSERRAT/CASTELLFOLLIT else `rgba(235,248,255,.56)`); sun column (screen blend): 7 bars `y = WATER_Y + 8 + band*11`, width `(95 - band*9) + sin(tNow*3.2 + band*1.4)*18`, centred at `TERRAIN_W*0.68 + sin(tNow*2.1 + band)*10`, h 4.5, `rgba(255,195,110,.14)` or `rgba(200,235,255,.13)`; fireball reflections; 3 rows of shimmer dashes (every 110 px, length `28 + sin(...)*14`).

**Splash silhouette (583-638)**: branch quadratic `(0, 0.74H+18) -> ctrl (W/2, 0.74H-12) -> (W, 0.74H+10)` stroke `#12151c` width 14; 6 caterpillars, `headX = ((tNow*48 + c*92) % (W+400)) - 200`, each 6 round segments spaced 11 px with sine wobble `sin(tNow*9 - s*0.9 + c)*2.4`, radius `s==0 ? 7.5 : 6.5 - s*0.35`, bristles `rgba(246,207,119,.55)`, body `#252934` (head `#16181f`), orange back `#e6772e`, eye `#f5b945`.

### 4.8 Aiming HUD (`drawAimingHUD`, renderer.js:2176-2407; world space, current fighter only)

Origin `(f.x, f.y - 4)`, direction `(cos aimAngle, sin aimAngle)`.
- AIRSTRIKE: target reticle at `mouseWorld`: circle r `16 + sin(tNow*8)*3` plus cross +-24, stroke `#ff6b5b` 2.2; labels `800 11px` `#ffe082` at y-34 and `700 9.5px` `rgba(255,245,220,.88)` at y-22.
- DYNAMITE and JETPACK: no reticle.
- Others: turn-start spotlight ring (while `turnSpotlightTimer > 0`, set to 1.6 on manual worm switch (state.js:388) and 1.9 at turn start (state.js:1155)): dashed (6,4) circle radius `31 + (1-a)*18` colour team alpha `a*0.65`, `a = timer/1.9`; text `TAB / TOCA CUC: CANVIA` if not yet moved and `a > .25`.
- Elevation badge: `elevDeg = round(-aimPitch*180/PI)` text `+N°`/`-N°` in `800 9.5px JetBrains Mono` on a 32x13 rounded rect `rgba(11,14,22,.78)`, at `origin + dir*34 + (0,-11)`, text colour `#ffd966` while charging else `rgba(255,244,214,.92)`.
- CHARGE weapons: trajectory preview of 11 steps (`dt 0.028`): start `origin + dir*18`; `speed = 180 + previewPower*760` with `previewPower = isCharging ? max(.22, chargePower) : .56`; each step `vx += wind*2.4*windFactor*dt; vy += GRAVITY*dt` then integrate; dashed (5,6) polyline width 2.4 with gradient alpha .82/.42/0 tinted `255,200,95` (wind > 18 and weapon windFactor>0), `135,215,245` (wind < -18), else `248,224,168`; pearl dots every 2nd point radius `3.0 - i*0.16`. Radial power ring r 24 around the origin: idle `rgba(245,208,138,.22)` w 1.5; charging `rgba(255,255,255,.22)` w 4.5; previous power marker (blue dot `#7ec8e3` r 3.3 at angle `-PI/2 + lastChargePower*2PI`); charging arc from -PI/2 sweeping `chargePower*2PI`, width 4.8, round cap, shadow blur 10, colour `#ffd966` (<0.5), `#ff8b3d` (<0.82), `#ff3b30`.
- PONT_PEDRA: ghost wall 82x16 rounded rect (radius 5) at `origin + dir*52`, rotated by aim, dashed (4,3), fill `rgba(210,200,182,.36)`, stroke `#ffe082`.
- GANXO: raycast from 14 to 480 px step 5 for solid terrain or another alive fighter (`other.r + 8`), stops at `WATER_Y - 6`; dashed line green `rgba(134,239,172,.72)` (latch) or red `rgba(248,113,113,.45)`, latch circle r `7 + sin(tNow*10)*1.5` `#86efac`.
- Other (melee/instant/tools): dashed short line to `origin + dir*44` and a ring r 6.5 `#ffe082`.
Needs sim queries `isSolid(x, y)`, plus `GRAVITY`, `windFactor` (data).

### 4.9 Held weapons (`drawHeldWeapon`, 1931-2174), translate (0,-3), rotate `aimAngle + swing`
BAZOOKA Trabuc (brown stock, grey barrel 14x5, brass bell), CARQUINYOLI (biscotti `#c87d32`), URTICARIA (violet orb `#8b3eb8` r 5.5 at x=12), SHOTGUN Pedrenyal (stock + barrel `#8d96a3` + hammer), FUET (quad curve: dark core `#7a1f2d` w 5.4 + dashed white crust `#f4eee1` w 4.2; `whipBend = batSwingTimer>0 ? sin(batSwingTimer*26)*7 : -2.5`), BAT La Falç (sickle bezier `#dce3ec`, handle `#b87430`), GRENADE (pine cone ellipse), CLUSTER (calçots), HOLY (porró trapezoid `#f0b849`), DYNAMITE (log `#8c5830` + `#d93829`), AIRSTRIKE (red box + antenna), CULLERA (spoon, wobble `sin(tNow*28)*0.28` while `spoonTimer>0`), BARRINA (drill `#d97b29`, jitter `(rand-0.5)*3` while `drillTimer>0`), PONT_PEDRA (stone block `#a8a298` with green top `#82a858`), GANXO (crook). JETPACK draws nothing extra. All with colours inline at the given lines.

### 4.10 Effects timings summary (updated in `loop`, main.js:115-438)

| Effect | Update rule | Draw (see table) |
|---|---|---|
| `shake` | `*= 0.04^dt`; set by sim (`max(shake, radius*0.38)`, 15 for big events, etc.) | random offset `shake*1.4` px |
| `flashLight` | `-= 2.6*dt` | alpha `flashLight*0.82` |
| `turnSpotlightTimer` | `-= dt` | ring |
| `touchRipples` | `r += 75*dt; life -= 2.1*dt` | ring + label |
| particles | `vy += (isHair ? 95 : 420)*dt`; hair particles move with `vx + wind*0.8` (wind is added to the displacement only, `vx` itself is unchanged); terrain-colliding debris/embers bounce: ember restitution 0.52, debris 0.42, `vx*=0.74`, side hit `vx = -vx*0.55`, `vrot *= 0.65`; water: embers die, debris `vy*=0.35, vx*=0.5`; `life -= decay*dt` | alpha = life |
| fireballs | `r += (maxR - r)*10*dt; y -= 18*dt; life -= (decay||2.35)*dt` | |
| waterRipples | `phase += dt; life -= 0.85*dt` | |
| smokePuffs | `x += (vx + wind*0.25)*dt; y += vy*dt; r += vr*dt; life -= decay*dt`; alpha `life*0.72` | |
| shockwaves | `r += (maxR - r)*9*dt; alpha -= 2.4*dt` | |
| waterPlumes | `h = sin((1-life)*PI)*maxH; ringR += (maxRingR - ringR)*5*dt; life -= 1.65*dt` | |
| bubbles | `y += vy*dt`; removed when `y <= WATER_Y + 2` | |
| floatingTexts | `y -= 26*dt; life -= dt`; alpha `clamp(life,0,1)`; font `800 13.5px`, black 1 px drop shadow | |
| speechBubbles | `life -= dt`; alpha `clamp(life*1.5,0,1)`; `700 11px`; box at `(f.x, f.y-54)` rounded rect (radius 4) h 20, fill `rgba(15,18,25,.92)`, stroke `#f6cf77` 1.3, text `#fff5df` | |
| winds/clouds/birds | sim `updateDynamicWind` | |

Off-screen projectile pill (5b): when a projectile's screen y < `14*dpr`: pill 62x20 at `y = 58*dpr`, x clamped `[48*dpr, W-48*dpr]`, fill `rgba(11,14,22,.88)`, stroke `#ffd966` (HOLY) / `#d88aff` (urticating) / `#ff8b3d`, text `▲ ${max(1, round((cy - H/2/scale - p.y)*0.12))}m` (`800 10.5px JetBrains Mono`, `#fff8eb`).

---

## 5. Input

All handlers are registered in `main.js`. `SND.init()` is called inside the first user gesture handlers (mousedown, touchstart, pointerdown on gamepad buttons, key presses while PLAYING, menu activation) because browsers need a gesture to start audio. In Godot web export audio also needs the first tap/key; call `Sound.unlock()` from `_input` on first event.

### 5.1 Keyboard (`keydown` main.js:1187-1596, `keyup` 1598-1614)

Order of evaluation inside the single keydown handler (order matters because several branches `return`):

1. Rotate overlay open: Esc/Enter/Space dismisses and returns.
2. `M`/`m` (not repeat, not typing in an INPUT): `SND.init(); SND.toggleMusic()`. Works in every stage and does not return (falls through; harmless).
3. `appStage === 'SPLASH'`: menu navigation, return (see 2.5).
4. `appStage === 'LOBBY'`: lobby navigation, return.
5. `appStage !== 'PLAYING'`: return. Then `SND.init()`.
6. GAME_OVER with victory modal open: ←/→/A/D/Tab swap focus; Enter/Space activate focused button; Esc exits to menu; everything else swallowed (return).
7. `Shift` down: `shiftHeld = true; keys.left = keys.right = false`.
8. `B`/`R` (not repeat): toggle arsenal drawer (`drawerCursorIdx = selectedWeaponIdx`, `buildWeaponBar`), return.
9. Drawer open: →/D +1, ←/A -1, ↓/S +8, ↑/W -8 (`moveDrawerCursor` wraps over 16; plays tick; also *selects* the weapon immediately if it has ammo and it is not an AI turn, so the pill and aim preview change while browsing); Enter/Space `selectWeaponByIndex(drawerCursorIdx, true)` closes drawer; Esc closes drawer. Other keys fall through (so movement keys etc. act while drawer is open except those four branches; but `keys.up/down` pitch input is suppressed while the drawer is open by the loop condition `!isWeaponDrawerOpen()`).
10. `Z`/`[`/`,` previous available weapon; `X`/`]`/`.` next (`cycleAvailableWeapon`, skips weapons with 0 ammo, plays tick). Not repeat.
11. `PageUp` zoom +0.14, `PageDown` -0.14 (clamp .50-2.25). `V`/`Home` reset pan offsets.
12. Movement: `A`/`ArrowLeft`: if shift held `panKeys.left`, else `keys.left = true` and, if active fighter alive, not AI, phase TURN_PLAY or RETREAT: `facing = -1; syncAimAngleFromPitch()`. `D`/`ArrowRight` symmetric. `W`/`ArrowUp`: `shiftHeld ? panKeys.up : keys.up`. `S`/`ArrowDown` same for down.
13. `Space` (preventDefault): GAME_OVER -> `initMatch(true)`; else if not repeat -> `beginChargeOrFireCurrentAim()`. Release (`keyup`) -> `releaseChargedShot()`.
14. `Enter`/`J` (not repeat): forward jump if grounded and not sliding (`triggerForwardJump`); if airborne and `performance.now() - lastJumpPressTime < 360` converts the hop into a backflip (first `activeFighter.x = lerp(x, jumpStartX, 0.72)`, then `triggerBackwardsJump`, `lastJumpPressTime = 0`). Conditions: phase TURN_PLAY/RETREAT, fighter alive, not drowning, `jetFuel <= 0`, not AI.
15. `Backspace` (not repeat): `triggerBackwardsJump` if grounded && !sliding (same conditions).
16. `Escape`: `exitCurrentMatchToMenu()`, return.
17. `Tab` (not repeat): `switchActiveWormBeforeMove()` (cycles to next alive team member; only before moving; see state.js:362-399).
18. `C`: `spinElasticSilkWeb()` (if not AI). `F`: toggle `processionConvoyEnabled` (label update on hidden button).
19. `Q`: `customGrenadeFuse = max(1, fuse-1)`, `E`: `min(5, fuse+1)`, both tick + `updateFuseUI()`.
20. Weapon hotkeys: `WEAPONS.findIndex(w => w.key === e.key.toLowerCase() || w.key === e.key)`: `1 2 3 4 5 6 7 8 9 0 - = u i o p` (see weapon table); `selectWeaponByIndex(idx,false)` then tick if accepted (not AI turn, ammo > 0).

`keyup`: Shift releases `shiftHeld` and all `panKeys`; A/D/W/S/arrows release both `keys.*` and `panKeys.*`; Space releases the charge (`releaseChargedShot`).

Known interplay to keep: pressing `E` while `Enter`... none. `R` is the arsenal key (not reload). `M` toggles music during the lobby too.

Godot InputMap suggestion (names are proposals, one `InputMap` action per row; do not set Godot UI defaults for the same keys inside gameplay): `move_left` (A, Left), `move_right` (D, Right), `aim_up` (W, Up), `aim_down` (S, Down), `fire` (Space), `jump` (Enter, J), `backflip` (Backspace), `weapon_prev` (Z, BracketLeft, Comma), `weapon_next` (X, BracketRight, Period), `drawer_toggle` (B, R), `switch_worm` (Tab), `silk_web` (C), `procession_toggle` (F), `fuse_dec` (Q), `fuse_inc` (E), `zoom_in` (PageUp), `zoom_out` (PageDown), `center_cam` (V, Home), `pan_modifier` (Shift), `music_toggle` (M), `back` (Escape), `weapon_slot_1..16` for the hotkeys (1..9,0,-,=,U,I,O,P). Because `A/D/W/S` double as menu navigation and drawer navigation, handle them contextually in the screens, not with separate actions.

### 5.2 Aiming, power and firing mechanics

State: `aimPitch` (-1.48 up .. +1.30 down; initial -0.42), `aimAngle` (derived: `facing>=0 ? pitch : PI - pitch`), `mouseWorld` (the aim target used by sim `fireWeapon`: set to `fighter + dir*260` for every non-airstrike weapon by `syncAimAngleFromPitch`, state.js:~365-376), `chargePower`, `chargeDir`, `isCharging`.
- **Keyboard/button pitch** (main.js:152-169): while `!shiftHeld`, drawer closed, not AI, phase TURN_PLAY/RETREAT: `pitchInput = down - up`; non-airstrike: `aimPitch = clamp(aimPitch + pitchInput*1.55*dt, -1.48, 1.30)`; AIRSTRIKE instead moves the target: `mouseWorld.x = clamp(x - pitchInput*facing*420*dt, 120, TERRAIN_W-120)`, `mouseWorld.y = clamp(findSurfaceY(x, 220) - 24, 90, WATER_Y-40)`, and the camera pan offset eases toward `(mouseWorld.x - fighter.x)*0.75` with lerp 0.16.
- **Charge**: `beginChargeOrFireCurrentAim` (main.js:503): only if not AI, phase TURN_PLAY, fighter alive/not drowning, and `teamAmmo[activeTeam][id] > 0`; zeros pan offsets; `syncAimAngleFromPitch()`; for weapons of type `CHARGE`: `isCharging = true; chargePower = 0.08; chargeDir = 1` (if not already); for any other type: `fireWeapon(wpn, aimAngle, 1.0, mouseWorld)` immediately.
- **Per frame while charging** (main.js:171-182): `chargePower += chargeDir*dt*0.92` (so 0 -> 1 in about 1.09 s; `chargeDir` never changes in the JS, no ping-pong); every 0.06 s `SND.charge(chargePower)`; at `>= 1.0` it auto-fires at full power (`isCharging=false; fireWeapon(..., 1.0, ...)`).
- **Release** (`releaseChargedShot`, main.js:523): `pwr = max(0.12, chargePower)`; resets charge; fires if ammo > 0.
- `mc-fire-fill` width = `round(chargePower*100)%` while charging a human turn.
- Weapon selection: `selectWeaponByIndex(idx, closeDrawer)` (main.js:1058): rejects AI turns and zero ammo; sets `selectedWeaponIdx`, `drawerCursorIdx`, `teamSelectedWeaponIdx[activeTeam]`; for AIRSTRIKE places `mouseWorld` at `clamp(x + facing*220, 200, TERRAIN_W-200)` on the surface; rebuilds the bar. Per-team remembered weapon is restored at turn start (state.js:1160-1166).
- Fuse: weapons with `hasCustomFuse` show the fuse picker; value `customGrenadeFuse` 1..5 (default 3), buttons set it directly (`onclick`), keys Q/E.
- Jumps: `triggerForwardJump` (main.js:540): if grounded and not sliding: `vx = facing*92, vy = -178`, squash (0.82, 1.22), `isVoluntaryJump`, `flipAngle=0`, `jumpStartX/Y`, `lastJumpPressTime = performance.now()`, `SND.jump()`, `hasActedOrMovedThisTurn = true`. `triggerBackwardsJump` (563): `vx = -facing*34, vy = -212`, `flipSpin = -facing*PI*2.35`, squash (0.76,1.30), `SND.backflip()`. These belong to the sim in Godot (they set fighter fields) but the *input rules* (double press within 360 ms, `x` lerp toward `jumpStartX` 0.72/0.75) are UI logic.
- Walking: `keys.left/right` consumed by `physics.js`; `facing` is set by the input handlers (and swipes) *only when* phase TURN_PLAY/RETREAT and human turn.

### 5.3 Mouse (desktop)

- `mousemove` (window): parallax update; if `mouseIsPanning` (button held on canvas) pans the camera by the delta (`panMapByScreenDelta`). Ignored while a touch drag is in progress (`isTouchDraggingCanvas`).
- `mousedown` on canvas (button 0, PLAYING): GAME_OVER -> `initMatch(true)`; else start pan, remember down position. The mouse never aims and never fires.
- `mouseup` (window): if it was a click (`<= 6` px movement), before the human has acted/moved this turn, phase TURN_PLAY, not AI: finds an allied alive fighter within 28 px of the click point `(f.x, f.y - 6)` and `switchActiveWormBeforeMove(ally)`.
- `wheel` (window, passive): `userZoomMult = clamp(userZoomMult - sign(deltaY)*0.08, .5, 2.25)` only while PLAYING (wheel up zooms in).
- `pointerdown` on canvas (any pointer): `setWeaponDrawerOpen(false)`.
- Hover/click on HUD pips: `updateHUD` builds one pip per fighter with click: `switchActiveWormBeforeMove(f)`; if it returns false and an active fighter exists: tick and `panOffset = target - active` (clamped) to peek at that worm.

### 5.4 Touch (canvas gestures, main.js:638-870)

Constants `LONG_PRESS_MS = 250`, `SWIPE_THRESHOLD_PX = 9`, `MULTI_TAP_WINDOW_MS = 360`. `touchstart` also adds `body.touch-device` and (PLAYING only) calls `preventDefault()`. `isTouchDraggingCanvas` is true from touchstart until 280 ms after the last touch ends (blocks synthetic mouse events).

State machine `touchGestureMode`: `NONE -> PENDING (1 finger down) -> SWIPE_AIM | SWIPE_WALK | SHOOT | PAN`.
- 1 finger down: record start; set PENDING; start a 250 ms timer; if the finger is still PENDING at the end => mode `SHOOT` and `beginChargeOrFireCurrentAim()` (long-press charges and fires along the current aim; releasing the finger fires: `releaseChargedShot`).
- Move while PENDING and total displacement > 9 px: cancels the long-press timer, cancels any charge, locks the gesture: `SWIPE_AIM` if `|dy| > |dx|*1.08`, else `SWIPE_WALK`.
- `SWIPE_AIM` (human turn, phase TURN_PLAY/RETREAT): pan offsets lerp to 0 (0.2/event), `aimPitch += dyScreen*0.0085` (down = increase) clamped, `syncAimAngleFromPitch()`. (Not a human turn: pans the map instead.)
- `SWIPE_WALK`: if AIRSTRIKE and `|dx| > 0.5`: moves target `mouseWorld.x += dxScreen*worldPerCssPx` (y snapped to surface - 24). Else, if the offset from the start is > 6 px: `keys.left = dir<0; keys.right = dir>0` (continuous walking while finger held beyond 6 px from the start; direction relative to the *touch start*), sets `facing`. Non-human: pans.
- `SHOOT`: vertical drag > 0.4 px fine-tunes `aimPitch += dy*0.0065`.
- 2 fingers (start or move): mode `PAN`; clears `keys.left/right` and charge; pinch: `userZoomMult *= dist/pinchLastDist` (only if previous dist > 12 px); pan by midpoint delta.
- `touchend` (last finger up): mode reset; `keys.left/right = false`; if mode was SHOOT -> `releaseChargedShot()`; if PENDING (a tap): tap counter within 360 ms: count 1 on AIRSTRIKE (TURN_PLAY): moves the target to the tapped world point (`screenToWorld`), tick, ripple `OBJECTIU CORREFOC` colour `#ff6b5b`; count 1 otherwise and not acted: if the tap lands within 32 px of an allied worm `(f.y-6)`: switch worm, ripple with the worm's name, `canvasTapCount = 0`; count 2: forward jump + ripple `¡SALT!`; count >= 3: backflip (first `x = lerp(x, jumpStartX, 0.75)` if defined) + ripple `¡MORTAL ENRERE!` colour `#ff8b3d`, count reset. Preconditions for jump/air-strike/switch: phase TURN_PLAY or RETREAT, alive, not drowning, `jetFuel <= 0`, human turn. Else (any other mode): charge reset.
- `touchcancel`: resets everything.
- GAME_OVER + touchstart: `initMatch(true)`.
- Godot: use `InputEventScreenTouch`/`ScreenDrag` with a small gesture recogniser node (`ui/input/touch_gestures.gd`) that emits the same semantic signals (`walk(dir)`, `aim_delta(dy)`, `charge_started`, `charge_released`, `jump`, `backflip`, `target_tap(world_pos)`, `pan(delta)`, `zoom(factor)`, `ally_tap(world_pos)`). The "DPR" distinctions vanish; thresholds are CSS px: in Godot logical px with `canvas_items` stretch they match on most phones (document if `content_scale_factor` is used).

### 5.5 On-screen gamepad buttons (`bindHoldButton`, main.js:875-1000)

Pointer-event based (`pointerdown`/`pointerup`/`pointercancel`, with pointer capture, `preventDefault`/`stopPropagation`, class `pressed`, `body.touch-device` added). Mappings:
- `mc-left`/`mc-right`: set `keys.left/right` (and clear the other), set `facing` + `syncAimAngleFromPitch()` if the human can act. Release clears.
- `mc-aim-up`/`mc-aim-down`: `keys.up/down` (clear the other). The loop turns them into pitch changes.
- `mc-jump`: grounded -> forward jump; airborne within 360 ms of the last press -> backflip (same rules as Enter).
- `mc-backflip`: backflip if grounded and not sliding (same preconditions).
- `mc-fire`: PLAYING only; GAME_OVER -> `initMatch(true)`; else begin charge/fire; release -> `releaseChargedShot`.
- Click buttons: `mc-zoom-in` (+0.16), `mc-zoom-out` (-0.16), `mc-pan` (zero pan offsets), `mc-switch-worm` (`switchActiveWormBeforeMove()`), `weapon-prev-btn` / `weapon-next-btn` (`cycleAvailableWeapon(-1/+1)`), `weapon-toggle-btn` (toggle drawer; plays tick), `.fuse-btn` (set fuse), `btn-music` (toggle + tick), `btn-exit-game` (exit), arsenal slots (select + close drawer, only if ammo > 0 and human turn).
- `#mc-switch-worm` visibility (`can-switch` class) recomputed every frame: `PLAYING && TURN_PLAY && !hasActedOrMovedThisTurn && !AI && alive team members > 1` (main.js:134-140), but additionally only shown on touch layouts via CSS.

### 5.6 Landscape lock and fullscreen

See 2.3. No `fullscreenchange` handling; `rotateOverlayDismissed` is the only state.

### 5.7 Input gating summary

`isCurrentTurnAI()` (state.js:1195): true if `appStage !== 'PLAYING'`; false if GAME_OVER; true if `CPU_CPU`; true for team 1 in `1P_CPU`. All human input handlers early-return on it. In `2P_LOCAL` both teams are human and use the same controls. There are no per-player key maps.

---

## 6. Main loop

### 6.1 `loop(now)` (main.js:98-442), one call per `requestAnimationFrame`

```
rawDt = min((now - lastT)/1000, 0.033)         // 33 ms cap (about 30 fps floor)
if hitStopTimer > 0:                            // freeze frame: no sim, no tNow advance, but render
    hitStopTimer -= rawDt; render(); return
dt = rawDt; if slowMoTimer > 0: slowMoTimer -= rawDt; dt = rawDt*0.38
tNow += dt                                      // all animation clocks use slowed time
shake *= 0.04^dt ; flashLight -= 2.6dt ; turnSpotlightTimer -= dt ; touchRipples update
updateDynamicWind(dt)                           // sim: wind gusts, clouds/birds drift (state.js:973-1010)
SND.updateAmbient(wind, appStage==='PLAYING')   // schedules music + wind ambience
rotatePromptOpen = updateRotateDeviceOverlay()
update #mc-switch-worm visibility
keyboard camera pan when shift held
keyboard pitch aiming
charge update (human, TURN_PLAY)
mc-fire-fill width
if PLAYING: updateAI(dt)
stepPhysics(dt)                                  // sim, runs in every stage (also SPLASH/LOBBY for the demo world)
if PLAYING: turn-phase state machine (6.2) + camera targets (4.2)
else (SPLASH|LOBBY): camera drift
camera lerp
effect arrays update (particles, fireballs, ripples, smoke, shockwaves, plumes, bubbles, floating texts, speech bubbles)
render()
```
- `hitStopTimer` (e.g. 0.045-0.068 s) and `slowMoTimer` (0.35-0.52 s, factor 0.38) are set by the sim on big explosions/kills. Note hit-stop returns *before* `tNow += dt`, so water, clouds and animations also freeze (the whole picture freezes), and the frame still renders (the shake continues because `render()` re-randomises).
- The sim step `stepPhysics(dt)` receives the (possibly slowed) `dt`. Timers like `turnTimer` use the same slowed `dt` (so slow-mo pauses the clock slightly).
- Particle update details in 4.10.
- Godot: `_physics_process` with fixed 60 Hz is not equivalent to this variable dt. To stay faithful use `_process(delta)` with `delta = min(delta, 0.033)` and keep the same order. Web: `Engine.max_fps` uncapped; vsync on.

### 6.2 Turn phase state machine (`turnPhase`)

Phases: `TURN_PLAY`, `RETREAT`, `ACTION_WAIT`, `TURN_DELAY`, `GAME_OVER`.

```
startNextTurn (state.js:1078+)  ──►  TURN_PLAY  (turnTimer = 30, lastTurnTickSec = 30, turnSpotlightTimer = 1.9)
   TURN_PLAY:
      actionWaitTimer = 0; turnTimer -= dt (unless rotate prompt open)
      HUD timer = ceil(turnTimer), colour #ff5247 when <= 5; tick sound each new second 5..1
      -> ACTION_WAIT when: turnTimer <= 0, or active fighter dead/drowning, or either team has 0 alive;  also isCharging=false
      sim sets ACTION_WAIT after any weapon fires (physics.js:156, 551, 584, ...)
      sim sets RETREAT (phaseTimer 2.0-4.0 s) after movement-type tools (jetpack 4.0, jump-ish 2.2, grapple 2.0-2.8, ...)
   RETREAT:
      phaseTimer -= dt; HUD timer = ceil(phaseTimer) colour #ffd966
      -> ACTION_WAIT when phaseTimer <= 0 or fighter dead/drowning or a team has 0 alive
   ACTION_WAIT: (HUD timer shows '—')
      actionWaitTimer += dt
      impactCam keeps tracking a moving worm near the impact (radius 520)
      waitTimeout = (no projectiles && no planes && actionWaitTimer > 3.6) || actionWaitTimer > 6.2
      if (no projectiles, no planes, no moving fighter [drowning | !grounded | sliding | spoonTimer>0 | drillTimer>0 | grapple], no triggered mine) || waitTimeout:
           if waitTimeout: clear projectiles & planes, zero velocity of all alive non-drowning fighters, grounded = true, clear sliding/spoon/drill/grapple
           -> TURN_DELAY, phaseTimer = 2.0
   TURN_DELAY: phaseTimer -= dt; at <= 0 -> startNextTurn()
   startNextTurn: if a team is dead -> GAME_OVER: status text + colour, SND.victory(), showVictoryModal(winner)
   GAME_OVER: input restarts via click/space/button; the victory modal buttons.
```
`startNextTurn` (sim) also: flips `activeTeam`, increments `roundNumber` when team 0 starts, may spawn a supply drop (round > 1, 48%, < 3 crates), raises `WATER_Y` by 14 each turn from round 10 while `WATER_Y > 460` (floating text `¡MORT SOBTADA — PUJA LA MAREA!`), picks the fighter (rotating `teamTurnIdx`), skips dead, random wind (`randomizeWind`), `updateHUD()`, `buildWeaponBar()`, updates `#turn-status` colour, `#round-sub`, 65% chance of a TURN taunt speech bubble, resets `hasActedOrMovedThisTurn` etc.

HUD updates in the loop: timer text/colour each frame while PLAYING; `updateWindHUD()` is invoked from the sim wind code (state.js:947-963); `updateHUD()` (pips, HP totals) is invoked from the sim whenever HP/alive changes and at turn start (`updateHUD`, main.js:1629: rebuilds both pip lists with `innerHTML` each call; pip alive uses `f.alive && !f.drowning`; team HP total sums alive fighters' hp). `buildWeaponBar` is invoked on weapon/ammo/turn changes. In Godot: update labels only on signals (`hp_changed`, `turn_started`, `ammo_changed`), not per frame, except the timer.

### 6.3 Victory / defeat / restart

- Win condition: a team with no alive non-drowning fighters at `startNextTurn`, and also forced in the `TURN_PLAY` phase check (moves to ACTION_WAIT immediately which flows to the same check). Draw if both are empty.
- `showVictoryModal(winningTeam)` (state.js:1038): sets title/sub/colour, stats grid, opens modal only if `appStage === 'PLAYING'`, `victoryFocusIdx = 1`. Victory modal keyboard in 5.1 (6).
- Restart: "Torna a Jugar [Intro]" -> `initMatch(true)` with the same settings (new terrain generation on the same map, new random positions, names kept, `activeTeam` re-rolled except 1P_CPU where `activeTeam = 1` before `startNextTurn` flips it so the human (team 0) starts). `Canvia Indret / Escamot` opens the lobby with the match still loaded. Clicking the canvas / Space / fire button during GAME_OVER also restarts.
- Exit to menu: Esc, "Sortir", Esc on victory. `exitCurrentMatchToMenu` as in 2.2.
- Boot: `initMatch(true)` + `requestAnimationFrame(loop)` (main.js:2003-2004); `appStage` starts as `'SPLASH'`, so the demo world plays behind the main menu (AI-driven because `isCurrentTurnAI()` is true outside PLAYING).

### 6.4 Quirks worth preserving or consciously dropping

- Turn timer pauses while the rotate overlay is open.
- `lastTurnTickSec` tick only fires when the remaining whole second decreases to 5..1 (`ceilSec < lastTurnTickSec`).
- `hasActedOrMovedThisTurn` blocks worm switching and ripples; set by jump functions and by the sim on movement/fire.
- `userZoomMult` persists across matches (not reset in `initMatch`; verify in sim inventory).
- `mouseWorld` defaults `(1600, 360)` and is used by the nameplate "near the aim target" rule (62 px) for every fighter.
- All timers are in seconds of slowed game time except the multi-tap windows and long press, which use wall-clock `performance.now()` / `setTimeout`.

---

## 7. Audio (`audio.js`)

### 7.1 Architecture

Global singleton `SND` (audio.js:6-830). No audio files. `init()` (65-112) lazily creates the `AudioContext` on first call (user gesture) and resumes it if suspended. Graph:

```
  voices ─► masterComp (DynamicsCompressor: threshold -14 dB, knee 18, ratio 4.5, attack 3 ms, release 180 ms) ─► destination
  lead voices (_playMidiLead only) ─► also fxSend (gain 0.075) ─► delay 0.11 s ─► lowpass 1800 Hz ─► masterComp
                                                                     ▲                    │
                                                                     └── feedback gain 0.12 ◄┘     (short room reflection)
  noise buffer: 1.5 s mono "pink-ish" noise built once (see formula)
  ambient wind: looping noise buffer ─► bandpass (260 Hz, Q 3.2) ─► gain (0.0001) ─► masterComp
```
Noise buffer formula (96-106): per sample `white = rand*2-1; b0 = .997*b0 + white*.029; b1 = .985*b1 + white*.032; b2 = .950*b2 + white*.048; out = clamp((b0+b1+b2+white*.18)*.55, -1, 1)`.

Common helpers:
- `_midiToFreq(m) = 440*2^((m-69)/12)`.
- `_osc(type, f1, dur, vol, f2, delay)`: one oscillator, frequency `f1` then exponential ramp to `max(16, f2)` over `dur` (if `f2` given), gain 0.001 -> `vol` linear in 8 ms, exponential to 0.0001 at `dur`.
- `_noiseBurst(dur, vol, freq, q, type, delay)`: noise buffer source from a random offset in 0..0.4 s, biquad of `type` (default lowpass), frequency `freq` exponentially swept to `max(60, freq*0.28)` over `dur`, gain 0.001 -> `vol` in 6 ms, exponential to 0.0001 at `dur`.
- `_speakSyllable(fStart, fEnd, dur, v1, v2, delay, vol, vibHz, vibDepth)` (430-490): the formant "worm voice". Sawtooth glottal oscillator `fStart -> max(80,fEnd)` exponential + triangle sub-harmonic at half pitch (`max(40, fEnd/2)`), vibrato LFO (`vibHz`, depth in Hz added to the sawtooth frequency; none if depth 0), two bandpass filters (F1 Q 4.2, F2 Q 5.5) swept from the start vowel's formants to the end vowel's over `dur`; the saw feeds F1 and F2, the sub only F1; gain `0.0001 -> vol` over `min(0.018, dur*0.25)`, step to `vol*0.85` at 72% of `dur`, exponential to 0.0001. Vowel formants Hz (F1, F2): A 920/1680, E 640/2320, I 420/2780, O 590/1120, U 430/940.
- Biquad semantics: WebAudio lowpass/highpass Q is in dB (resonance), bandpass Q is linear. Godot's `AudioEffectFilter` family has a `resonance` property (0..1) and no true Q; for pre-rendering in a script implement RBJ biquads with explicit Q (WebAudio uses Q linear for bandpass, `10^(Q/20)` for lowpass resonance).
- Scheduler: `updateAmbient(windVal, isPlaying)` (368-380) is called every frame; it calls `_scheduleMidiMusic()` then sets wind filter frequency `180 + |wind|*4.8 + sin(tNow*1.7)*35` (time constant 0.12 s) and gain `isPlaying ? clamp(0.004 + |wind|/100*0.022, 0.003, 0.028) : 0.002` (time constant 0.15 s). Both only after `init()`.
- Mute/music toggle: only music can be toggled: `toggleMusic()` flips `musicEnabled`, resets `_nextNoteTime`, and writes `Música: Sí` / `Música: No` to `#lbl-music`. SFX and wind are never muted (there is no master mute or volume). Triggers: `M` key and `btn-music`. Music is enabled by default and starts on the first user gesture (`init`); it plays on the splash/lobby too. There is no persistence of the setting.
- Rate limits use game time `tNow`: `crawlStep` 0.12 s, `skid` 0.055 s, `jetThrust` 0.05 s; `wormHurt` staggers the voice by 0.11 s if another hurt happened within 0.12 s of audio-clock time (implemented with `setTimeout`, wall-clock).

### 7.2 Music: "La Sardana de Ferro" (audio.js:30-62, 297-344)

- Loop of 64 steps; `stepDur = 0.225 s` (a "bar" = 4 steps = 0.9 s, so 16 bars = 14.4 s per loop). Scheduler runs when `musicEnabled` and the context is `running`: lookahead window `now + 0.14 s`; if `_nextNoteTime < now - 0.25` or `> now + 1.0` it resyncs to `now + 0.04` (so background-tab gaps just restart in time). First start `now + 0.08`. `_musicStep` persists across toggles (toggling off keeps it; toggling on only resets `_nextNoteTime` to `now + 0.05`), so the music resumes mid-loop.
- Data arrays (copy verbatim to `data/music/sardana_de_ferro.tres` or a const in `core/sound_music_data.gd`): `_MIDI_LEAD` (64 MIDI notes, 0 = rest), `_MIDI_HARMONY` (64), `_MIDI_CHORDS` (16 four-note arrays, one per bar, arpeggio index = `stepInBar % 4`), `_MIDI_BASS` (64). Exact arrays in audio.js:33-62.
- Per step, in this order, all at time `t`:

| Voice | Condition | Function | Duration | Volume | Synthesis |
|---|---|---|---|---|---|
| Lead (tenora/oboe) | `LEAD[s] > 0` | `_playMidiLead(note, t, dur, .032, false)` | `stepDur*(next step is rest ? 1.85 : 0.92)` | .032 | osc1 sawtooth at f; osc2 square at f*1.0025 through gain .28; vibrato LFO 5.6 Hz on osc1 only: depth ramps from 0.1 Hz to `f*0.0085` Hz at 65% of dur; lowpass: `f*2.2` -> `f*4.2` at +40 ms -> `f*2.5` at end (exponential), Q 2.1; envelope 0.0001 -> vol (linear, 18 ms), step to `vol*0.82` at 65% dur, exponential to 0.0001 at dur; also sent to the fx send |
| Harmony | `HARMONY[s] > 0` | `_playMidiLead(note, t, stepDur*0.88, .018, true)` | .88 step | .018 | same as lead but osc1 is triangle |
| Guitar | `CHORDS[bar]` | `_playMidiGuitar(chord[stepInBar%4], t, stepDur*0.90, .024)` | .90 step | .024 | saw at f + triangle at 2f via gain .25; lowpass `f*6.5` -> `f*1.4` at 85% dur (exp), Q 1.4; env 0.0001 -> vol (linear 6 ms) -> 0.0001 exponential at dur |
| Bass (pizzicato tuba) | `BASS[s] > 0` | `_playMidiBass(note, t, stepDur*1.45, .044)` | 1.45 step | .044 | triangle + saw both at f; lowpass 420 -> 135 Hz exp over dur; env linear 10 ms, exp decay |
| Percussion | every step | `_playMidiPerc(stepInBar, t)` | | | steps 0 and 2: sine kick, 115 Hz (step 0) / 98 Hz (step 2) exp-glide to 38 Hz over 0.13 s, gain peak .042 / .028 at 5 ms, decay to 0.0001 at .14 s, stop at .15 s. Steps 1,3: bandpass snare tap: noise buffer (start offset 0.1 s) bandpass 1850 Hz Q 1.5, dur .075, peak .018. Steps 0,2: tambourine: noise highpass 5200 Hz Q .8, dur .035, peak .008 (attack 3 ms linear) |

(Perc also plays noise on steps 0 and 2 as the highpass "tambourine" - the `isSnare` test is only for steps 1 and 3.)

### 7.3 Sound effects: triggers and synthesis

Notation: `N(dur, vol, freq, Q, type, delay)` = `_noiseBurst`; `O(wave, f1, dur, vol, f2, delay)` = `_osc`; `V(mood)` = `wormVoice(mood)`; `L(note, t, dur, vol)` = `_playMidiLead`; `B(...)` = `_playMidiBass`. Trigger line numbers are in `physics.js` unless noted (the sim inventory owns the semantic context).

| Function | Synthesis (audio.js line) | Triggered by |
|---|---|---|
| `tick()` (700) | O(tri 920 -> 640, .038, .075); N(.015, .04, 2800, 3.0, bp) | UI (menu, buttons, lobby, weapon change, worm switch (state.js:392), last 5 s of the turn (main.js:212), correfoc tap), physics 754, 1203 |
| `titleFanfare()` (591) | `init()`; 6 notes A4 440, C5 523.25, E5 659.25, A5 880, G5 783.99, A5 880 with durations .14,.14,.14,.26,.14,.48; each as L(midi, +off, dur, .065) plus B(midi-12, +off, dur*1.1, .055); offset advances `dur*0.85` | menu options 0 and 1 |
| `victory()` (822) | 4 L notes (A4, C#5 554.37, E5, A5) at +i*0.08, .42 s, vol .065 | `startNextTurn` GAME_OVER (state.js:1101) |
| `jump()` (613) | N(.045,.07,1100,1.8,bp); O(sine 165 -> 540, .19, .18); O(tri 240 -> 760, .15, .11, +.02); V(JUMP) | main.js:557, physics 91, 586, 749, 1866, 2118 |
| `backflip()` (621) | N(.09,.11,1600,1.6,bp); O(sine 190->520,.12,.18); O(tri 310->920,.22,.18,+.07); O(sine 460->1180,.16,.10,+.12); V(BACKFLIP) | main.js:579 |
| `charge(pct)` (630) | f = 190 + pct*480; O(tri f -> f*1.12, .055, .065); O(saw f*.5 -> f*.56, .045, .035); N(.02, .035, 1800 + pct*1400, 3.0, bp) | main.js:175, every 0.06 s while charging |
| `fireBazooka()` (638) | N(.28,.28,820,.85,lp); N(.14,.18,2200,1.4,bp,+.02); O(sine 155 -> 34, .28, .30); O(saw 210 -> 48, .22, .20); V(ATTACK) | 533, 1033 |
| `shotgun()` (647) | N(.025,.16,3800,2.5,bp); N(.24,.32,1450,.75,lp,+.015); O(saw 280->36,.19,.28,+.015); O(square 135->28,.16,.20,+.015); V(ATTACK) | 610 |
| `homeRun()` (656) | O(square 960->220,.06,.26); O(tri 420->95,.14,.26); V(ATTACK); 4 O(tri f -> f*1.01, .28, .11, +.07 + i*.04) for f in 523.25, 659.25, 783.99, 1046.5 | 675, 715 |
| `hallelujah()` (665) | for each chord note f: O(sine f -> f*1.001, .55, .11); O(tri f/2, .55, .07); O(sine f*1.122, .78, .12, +.56) | 1192 |
| `mineBeep()` (674) | O(sine 1320, .065, .12); O(tri 2640, .045, .05) | 1151, 1166 |
| `cratePickup()` (679) | for f in 587.33, 783.99, 987.77, 1174.66 at +i*.045: O(tri f -> f*1.01, .18, .12); O(sine 2f, .12, .05) | 106, 1100, 1517, 1561 |
| `jetThrust()` (686) | rate limit .05 s; N(.065,.08,720,1.2,bp); O(saw 110+rand*40 -> 58, .065, .09) | 1914 |
| `jet()` (751) | O(saw 120 -> 290, .32, .14) | 783, 796 |
| `bounce()` (693) | N(.045,.09,760,1.8,bp); O(tri 185->68,.085,.14); O(sine 290->120,.05,.08) | 1080, 1094, 1295, 1371, 2335, 2360 |
| `boom(scale=1)` (705) | `dur = clamp(.62*scale, .38, 1.15)`; N(.045, min(.38,.28s), 2400,1.2,bp); N(dur, min(.42,.32s), 640,.68,lp,+.01); N(dur*.75, min(.24,.18s), 1450,1.5,bp,+.03); O(sine 115->18, dur*.85, min(.45,.36s)); O(saw 135->22, dur*.55, min(.32,.24s)); O(tri 72->15, dur*.92, min(.38,.30s)) | 134 (`radius/45`), 380 (0.9) |
| `hardSlam(speed)` (717) | `i = clamp(speed/450, .45, 1.3)`; N(.14, .20i, 520,1.1,lp); O(tri 140->32,.18,.26i); O(saw 95->24,.14,.18i); V(OW); if speed > 360: 4 chirps O(sine f -> f*1.18, .09, .07, +.14 + i*.065) for 740, 980, 820, 1120 | 2192 |
| `skid(speed)` (731) | rate limit .055 s; N(.05, min(.08, speed*.00025), 980, 2.0, bp); f = 110 + min(200, speed*.45) + rand*45; O(tri f -> f*.7, .05, min(.09, speed*.0003)) | 2018, 2251 |
| `plunge()` (739) | N(.42,.28,1150,1.2,bp); N(.22,.18,2800,1.6,bp,+.04); O(saw 290->48,.28,.18); O(sine 460->90,.22,.16); 4 syllables V-style `_speakSyllable(340+55i, 580+65i, .10, U, O, 0.14 + .12 i, .22, 18, 35)` | 1069, 1235, 1625, 2372 |
| `fuetWhip()` (755) | N(.075,.26,2600,1.6,bp,+.035); O(saw 210->1120,.09,.20); O(square 980->130,.065,.22,+.045); O(tri 180->44,.15,.24,+.055); V(ATTACK) | 657 |
| `carquinyoliCrunch()` (764) | N(.05,.16,1850,2.0,bp); O(square 840->310,.05,.16); O(tri 1240->480,.045,.14,+.02) | 553, 1263, 1319, 1353 |
| `rovelloBoing()` (771) | O(sine 180->680,.28,.24); O(tri 270->920,.24,.18,+.025); V(JUMP) | 260, 2145 |
| `windGust()` (778) | N(.45,.08,520,2.6,bp); O(sine 240->360,.36,.055); O(tri 175->115,.38,.045,+.04) | state.js:988 |
| `caganerBlessing()` (785) | 4 L notes (C5,E5,G5,C6 as midi) at +i*.06, dur .22, vol .06 | 1463, 1690 |
| `spoonScoop()` (795) | N(.095,.16,580,1.6,bp); O(tri 155->260,.095,.16) | 814, 1766 |
| `drillBore()` (801) | N(.06,.18,1120,2.2,bp); O(saw 98->54,.065,.18); O(square 260->115,.045,.12) | 829, 1822 |
| `stoneBuild()` (808) | N(.12,.20,460,1.5,lp); O(tri 140->62,.18,.22); O(sine 392->523.25,.16,.12,+.05) | 848 |
| `grappleWhip()` (815) | N(.13,.16,1950,2.0,bp); O(sine 280->760,.19,.18); V(JUMP) | 866 |
| `shellWhistle()` (586) | O(sine 1120->290,.42,.055); O(tri 560->145,.42,.025) | 1385 |
| `urticatingBurst()` (606) | N(.28,.18,1650,1.8,bp); O(saw 680->160,.28,.15); O(tri 980->290,.22,.11,+.03); V(ITCH) | 28, 130 |
| `crawlStep()` (577) | rate limit .12 s (tNow); `pitch = 240 + rand*90`; O(sine pitch -> pitch*1.45, .045, .045); N(.035,.025,1200 + rand*350, 2.4, bp) | 1946 (every footstep) |
| `wormHurt(dmg, fatal)` (559) | `punch = clamp(dmg/40, .45, 1.25)`; N(.08, .18p, 950,1.4,bp); O(tri 175->42,.12,.24p); O(saw 260->68,.08,.16p); then (stagger) V(fatal ? DEATH : OW) | 443 |
| `wormVoice(mood)` (492) | `pick = floor(rand*4)`: see 7.4 | internal + state.js:1136 (`ITCH`) + physics 658, 815 (`ATTACK`) |

### 7.4 `wormVoice` moods (all via `_speakSyllable(fStart, fEnd, dur, vowel1, vowel2, delay, vol, vibHz, vibDepth)`)

- JUMP (4 random variants): (420,760,.13,U,A,0,.24,6,8) | (480,820,.11,I,E,0,.23,7,10)+(680,790,.09,E,A,.09,.18,6,8) | (390,710,.14,O,I,0,.24,8,12) | (450,620,.08,O,U,0,.22,5,6)+(580,860,.11,A,I,.07,.23,8,12).
- BACKFLIP (pick even / odd): (460,680,.10,I,A,0,.24,7,10)+(680,960,.22,U,O,.09,.26,11,24) | (440,640,.09,U,O,0,.22,6,8)+(620,780,.09,O,A,.08,.23,8,10)+(760,940,.16,A,I,.16,.25,10,20).
- ATTACK: (520,740,.09,O,A,0,.22,9,14)+(680,560,.11,A,E,.08,.20,8,12).
- OW (4 variants): [(780,520,.12,A,I,0,.28,14,28),(690,440,.12,I,E,.11,.25,14,26),(590,340,.15,I,U,.22,.22,12,22)] | [(660,840,.09,O,A,0,.28,10,18),(820,310,.24,A,U,.08,.27,15,32)] | [(540,860,.08,U,I,0,.26,9,14),(580,910,.08,U,I,.085,.26,9,14),(520,760,.11,U,E,.17,.24,11,18)] | [(840,480,.13,A,I,0,.28,13,25),(560,270,.17,O,U,.12,.26,11,20)].
- DEATH: (760,580,.14,A,E,0,.28,12,22)+(640,420,.16,E,U,.13,.27,11,20)+(520,210,.34,O,U,.28,.26,9,25) + four chime sines (523.25, 659.25, 783.99, 1046.5 -> *1.01, .22, .07) at `0.45 + i*0.055`.
- ITCH: (620,880,.07,A,I,0,.22,16,30) + N(.08,.14,2600,2.2,bp,+.06) + (740,490,.12,I,U,.11,.22,15,28).

### 7.5 What is needed in Godot, and the recommendation

Requirements: ~35 one-shot sounds of 0.04-1.2 s, voices with random variants, one 14.4 s music loop, a continuous wind bed with live filter/gain control, a master compressor, and a tiny room delay; web export target; no threads; audio only after first user gesture.

Options:
1. `AudioStreamGenerator` + runtime synthesis in GDScript: needs a per-frame buffer pump with a small buffer; on Web (single-thread) the audio mixer runs on the main/audio worklet and GDScript at ~1-2 M simple ops/s on mobile is not enough for 5-voice music with biquads plus overlapping SFX; underruns and latency are likely, and `AudioStreamGenerator` is poorly supported in Web exports without threads. Not recommended.
2. **Pre-render to `AudioStreamWAV` (recommended).** Write a one-off synthesis tool `tools/bake_audio.gd` (headless `godot --headless --script`) that ports `audio.js` formulas into sample-level code (oscillators, RBJ biquads with explicit Q, exponential/linear envelopes, noise buffer with fixed seed) and writes `.wav` files to `assets/audio/` (16-bit mono 22.05 kHz for SFX to keep size small, 44.1 kHz not needed because content is mostly < 8 kHz; music 22.05 kHz stereo-less ~ 0.63 MB, SFX total ~1-1.5 MB). Commit the baked files (deterministic, fast to load, zero runtime cost on web, no startup stall). Then `core/sound.gd` is a thin player: a pool of `AudioStreamPlayer` nodes, one per looping/long stream and a round-robin pool for one-shots, `play(name, volume_scale, pitch_scale)`. Variants (voice picks 0-3, pitch randoms) as separate files `voice_ow_0..3.wav`, or as `AudioStreamRandomizer` resources (random pitch ±, random volume) which are web-safe. Per-call parameters that cannot be baked: `charge(pct)` (use one base ramp and `pitch_scale = 1 + pct*...` or bake 8 steps), `boom(scale)` (bake 3 sizes: small <= 0.5, medium 0.9-1.0, large 1.5+, and scale volume), `hardSlam(speed)` (volume scale; the 4 chirps only if speed > 360: bake two clips), `skid(speed)` (volume scale), `wormHurt(dmg)` (volume/punch scale).
3. Runtime pre-render at startup (same code as option 2 executed during a loading screen, chunked across frames into `AudioStreamWAV`s): viable fallback if baked assets are not wanted, but costs several seconds on mobile web (about 50 voice-seconds of audio for the music alone) and violates "no heavy startup". Use only if the team insists on not committing generated assets.

Bus layout (`default_bus_layout.tres`): `Master` with `AudioEffectCompressor` (threshold -14 dB, ratio 4.5, `attack_us` 3000, `release_ms` 180; the 18 dB soft knee has no Godot equivalent), buses `Music` (`AudioEffectDelay` is not needed, bake the room into the lead voice instead), `SFX`, `Voices`, `Ambience`. The room send (0.075 gain, 0.11 s delay, 0.12 feedback, 1800 Hz damping) applies only to lead voices: bake it into the music file (and into the three fanfare sounds) rather than build a bus.
Wind ambience: bake a 1.5 s seamless bandpass-noise loop (or the raw noise buffer) and drive `AudioEffectBandPassFilter.cutoff_hz` (`180 + |wind|*4.8 + sin(t*1.7)*35`) and `AudioStreamPlayer.volume_db` (`linear_to_db(clamp(0.004 + |wind|/100*0.022, .003, .028))`; idle `0.002`) each frame with exponential smoothing (time constants 0.12 s / 0.15 s). Use a dedicated `Ambience` bus carrying the `AudioEffectBandPassFilter` (Godot's resonance param approximates Q 3.2).
Mute: `Sound.music_enabled` toggles the `Music` bus mute (or stops the music player, restarting the loop is not needed: the JS continues at the next scheduler step). Label `Música: Sí/No` is the HUD state. `M` key toggles. Also Godot web requires `AudioServer`/first-gesture unlock: no code needed in Godot 4.x (it handles `AudioContext.resume()` on first input) but keep the music start gated by the first tap to match the original (music starts only after the first gesture).
Loudness: sum of the JS gains is small (music voices .018-.048 peak, SFX .05-.45) before the compressor; when baking, keep the numeric amplitudes and apply the compressor offline or via the Master bus, otherwise the mix will be quiet or clip. Verify by ear against the JS page.
Mapping `setTimeout`-delayed voices: `wormHurt` delays the voice by 0.11 s only when two hurts overlap; reproduce with a timer in `Sound`.

---

## 8. Function index (line numbers)

### renderer.js
| Line | Function | Purpose |
|---|---|---|
| 6 | `getCameraTransform()` | scale/centre from viewport, camera, zoom, DPR |
| 31 | `screenToWorld(clientX, clientY)` | inverse transform |
| 42 | `render()` | whole frame (table in 4.3) |
| 583 | `drawSplashProcessionSilhouette(ctx, W, H)` | animated branch + 6 caterpillars on the main menu |
| 640 | `drawParallaxMountainRidges(...)` | far/near ridge polygons |
| 688 | `drawSkyAtmosphereAndClouds(...)` | sun glow, god rays, cloud veil, birds, cloud flock |
| 827 | `drawSurfaceFlora(ctx)` | per-biome plants with wind sway |
| 997 | `drawGroundContactShadows(ctx, mCfg)` | blob shadows under entities |
| 1032 | `drawRovello` | bouncy mushroom |
| 1086 | `drawCaganer` | lucky figurine |
| 1149 | `drawEscudella` | soup pot |
| 1207 | `drawWeatherLayer(...)` | wind ribbons + weather particles |
| 1298 | `drawFighter(ctx, f)` | segments, head group, wings, status, held weapon, nameplate |
| 1568 | `drawFighterHead(ctx, f, bob, teamCol)` | head, eyes, antennae, mustache, hat dispatch |
| 1714 | `drawOrugaHat(ctx, hatType, teamCol)` | 5 hats |
| 1805 | `drawCrate` | supply crate/medkit with parachute |
| 1853 | `drawMine` | mine with blinking light |
| 1872 | `drawTombstone` | tomb with name |
| 1931 | `drawHeldWeapon(ctx, f)` | 15 weapon pictograms |
| 2176 | `drawAimingHUD(ctx, f)` | reticle, trajectory, power ring, previews |
| 2409 | `drawBarrel` | explosive barrel |
| 2439 | `drawProjectile(ctx, p)` | trail + type sprites + fuse number |
| 2711 | `drawAirstrikePlane` | Correfoc plane |
| 2746 | `drawWaterBack` | back water band |
| 2765 | `drawWaterFront` | front water, ripples, reflections |

Inline blocks inside `render()` (not separate functions): updrafts 124-145, silk nests 148-201, silk webs 204-234, pine nuts 237-256, larvae swarms 259-274, grapple rope 285-303, procession tethers 306-321, fireballs 337-358, smoke 361-372, shockwaves 375-384, water plumes 387-406, particles 409-451, flash light 454-466, bubbles 470-480, speech bubbles 483-502, floating texts 505-515, tracker pill 523-547, touch ripples 549-565, vignette 573-578.

### main.js
| Line | Function / block | Purpose |
|---|---|---|
| 6-12 | globals | `lastT, rotateOverlayDismissed, shiftHeld, panKeys, drawerCursorIdx, lobbyFocusIdx, victoryFocusIdx` |
| 14 | `isMobilePhoneDevice()` | |
| 20 | `updateRotateDeviceOverlay()` | |
| 33-34 | listeners | resize / orientationchange |
| 36 | `updateMenuCursorUI()` | |
| 42 | `exitCurrentMatchToMenu()` | |
| 59 | `activateMenuOption(idx)` | |
| 98 | `loop(now)` | main frame |
| 447 | wheel listener | zoom |
| 465-467 | gesture constants | |
| 489 | `panMapByScreenDelta(dx, dy)` | |
| 496 | `updateParallaxFromPointer(x, y)` | |
| 503 | `beginChargeOrFireCurrentAim()` | |
| 523 | `releaseChargedShot()` | |
| 540 | `triggerForwardJump(f)` | |
| 563 | `triggerBackwardsJump(f)` | |
| 583-627 | mouse listeners | pan / ally click |
| 638-870 | touch listeners | start/move/end/cancel |
| 875 | `bindHoldButton(id, down, up)` | pointer-hold helper |
| 898-1000 | gamepad bindings | left, right, aim up/down, jump, fire, zoom, pan, backflip, switch worm |
| 1002-1048 | prev/next weapon, fullscreen, dismiss rotate | |
| 1053 | `isWeaponDrawerOpen()` | |
| 1058 | `selectWeaponByIndex(idx, closeDrawer)` | |
| 1080 | `cycleAvailableWeapon(step)` | |
| 1095 | `moveDrawerCursor(delta)` | |
| 1117 | `HAT_OPTIONS` | |
| 1119 | `getLobbyFocusableItems()` | |
| 1127 | `updateLobbyFocusUI(scroll)` | |
| 1147 | `activateLobbyFocusedItem(el, dir)` | |
| 1163 | `updateVictoryFocusUI()` | |
| 1187 | `keydown` handler | full keyboard map |
| 1598 | `keyup` handler | |
| 1616 | `updateFuseUI()` | |
| 1622 | fuse buttons onclick | |
| 1629 | `updateHUD()` | rebuild pips/HP |
| 1676 | `setWeaponDrawerOpen(isOpen)` | |
| 1687-1700 | toggle button, canvas pointerdown close drawer | |
| 1702 | `buildWeaponBar()` | pill, fire label, 16 slots |
| 1759 | `lobbyModal` | |
| 1761 | `renderLobbySquadInputs()` | |
| 1793 | `openLobbyModal()` | |
| 1840 | `window.handleFaceUpload(team, idx, input)` | |
| 1858-1881 | mode/diff/count card handlers | |
| 1883 | `readLobbyCustomization()` | |
| 1903 | random names button | |
| 1917-1927 | main menu hover/click | |
| 1929-1999 | button handlers | back, roster, silk, procession, close-setup, restart-match, vic-lobby, vic-rematch, mode, music, exit |
| 2003-2004 | boot | `initMatch(true); requestAnimationFrame(loop)` |

### audio.js
| Line | Function | |
|---|---|---|
| 6-20 | `SND` fields | `musicEnabled` etc. |
| 23-29 | `_VOWELS` | formant table |
| 33-62 | `_MIDI_LEAD/_HARMONY/_CHORDS/_BASS` | score |
| 65 | `init()` | |
| 114 | `_dest()` | |
| 118 | `_midiToFreq(m)` | |
| 122 | `toggleMusic()` | |
| 134 | `_playMidiLead` | |
| 186 | `_playMidiGuitar` | |
| 224 | `_playMidiBass` | |
| 257 | `_playMidiPerc` | |
| 297 | `_scheduleMidiMusic` | |
| 346 | `_ensureAmbientWind` | |
| 368 | `updateAmbient(windVal, isPlaying)` | |
| 382 | `_noiseBurst` | |
| 405 | `_osc` | |
| 430 | `_speakSyllable` | |
| 492 | `wormVoice(mood)` | |
| 559 | `wormHurt` | |
| 577 | `crawlStep` | |
| 586 | `shellWhistle` | |
| 591 | `titleFanfare` | |
| 606 | `urticatingBurst` | |
| 613 | `jump` | |
| 621 | `backflip` | |
| 630 | `charge` | |
| 638 | `fireBazooka` | |
| 647 | `shotgun` | |
| 656 | `homeRun` | |
| 665 | `hallelujah` | |
| 674 | `mineBeep` | |
| 679 | `cratePickup` | |
| 686 | `jetThrust` | |
| 693 | `bounce` | |
| 700 | `tick` | |
| 705 | `boom` | |
| 717 | `hardSlam` | |
| 731 | `skid` | |
| 739 | `plunge` | |
| 751 | `jet` | |
| 755 | `fuetWhip` | |
| 764 | `carquinyoliCrunch` | |
| 771 | `rovelloBoing` | |
| 778 | `windGust` | |
| 785 | `caganerBlessing` | |
| 795 | `spoonScoop` | |
| 801 | `drillBore` | |
| 808 | `stoneBuild` | |
| 815 | `grappleWhip` | |
| 822 | `victory` | |

### index.html / styles.css (structure)
- index.html: splash 20-56, rotate overlay 61-82, lobby 87-191, top HUD 196-251, bottom HUD 254-299, victory modal 302-313, scripts 318-323.
- styles.css: variables 1-13, reset/base 15-47, splash 52-202, lobby 207-555, HUD 560-855, weapon pill/drawer 856-1066, kb-focus 1053-1079, rotate overlay 1084-1164, arsenal slots 1166-1213, victory 1220-1271, mobile gamepad 1276-1378, portrait 1383-1635, landscape-phone 1640-1852.

---

## 9. Porting notes for the target layout

### 9.1 Mapping

| JS | Godot target | Notes |
|---|---|---|
| `render()` world plane | `combat/view/` `Node2D` scene with `Camera2D` (`camera_rig.gd`) | Cam math in 4.2 reproduced exactly; `Camera2D` with `zoom = Vector2(scale, scale)`, `position = (cx, cy)`; set `ignore_rotation`, `position_smoothing` OFF (smoothing is done by `1 - pow(0.015, rawDt)` in code). Screen shake via `Camera2D.offset`. |
| sky gradient, bg JPG, ridges, god rays, clouds, birds, weather, vignette | `combat/view/parallax_bg.gd` on a `CanvasLayer` (negative layer for sky/bg/ridges/clouds, positive layer for weather+vignette) | Reproduce parallax factors: bg 0.14/0.16, far ridge 0.065/0.08, near ridge 0.115/0.13, clouds 0.09/0.20/0.36 by tier, birds 0.16-0.32, weather particles `m.z` 0.5-1.5, ribbons 0.45-1.1. All of these use `dxCam = cx - TERRAIN_W/2`, `dyCam = cy - 400` and the *camera scale*; drawing in `_draw()` of a `Control`/`Node2D` that gets `cam_center`/`scale` each frame is the simplest faithful way (no `ParallaxBackground`). |
| terrainBack / terrainFront | `combat/view/terrain_view.gd`: two `Sprite2D`s fed by `ImageTexture.update()` from the sim's terrain image, back one offset by (perspX, perspY) | The perspective offset formulas are in 4.3 (4.2). Destruction updates should use `update()` on dirty rects, not recreating textures (web perf). |
| water back/front, plumes, ripples | `combat/view/water_view.gd` (`_draw` polylines every frame, or a `MeshInstance2D`/shader for the wave polygon: sample step 28/32 px over `TERRAIN_W + 9600` px = about 400 vertices, fine with `draw_colored_polygon`/`draw_polygon` and a gradient: use `draw_polygon` with per-vertex colours) | The fill gradient is vertical from `WATER_Y` to `TERRAIN_H+220`: per-vertex colours do it. |
| fighters | `combat/view/caterpillar_body.gd` (`Node2D`, `_draw`) one per fighter | Procedural segments from sim `segs`; see 4.5. Keep separate sub-draw functions: `_draw_segments`, `_draw_head`, `_draw_hat(hat_id)` reading `data/types/hat_data`, `_draw_nameplate`. Gradients: pre-create a few `GradientTexture2D` radial textures per palette. |
| held weapons, projectiles, aiming HUD | `combat/view/fx/` or `combat/view/weapon_view.gd`, `projectile_view.gd`, `aim_hud.gd` | One `_draw` function per weapon id; data-driven where it is a plain colour table. |
| particles, fireballs, smoke, shockwaves, plumes, bubbles, floating text, speech bubbles | `combat/view/fx/` (a single `FxLayer` Node2D drawing all pools in `_draw`, or `GPUParticles2D`/`CPUParticles2D` only where visually equal) | Counts are small (hundreds). A single `_draw` pass with `draw_*` calls is the closest to the JS; avoid per-particle nodes (web). `screen` blend for fireballs/flash: `CanvasItemMaterial.blend_mode = ADD`. |
| dynamic labels (floating text, speech, names, damage) | `Font.draw_string` with `draw_string_outline` not needed; the JS uses a 1 px black drop shadow offset by (+1,+1) | |
| splash silhouette | `ui/menus/splash_backdrop.gd` or part of `parallax_bg.gd` drawn on top of the world while `appStage == SPLASH` | |
| DOM HUD | `combat/hud/` | see 9.2 |
| splash / lobby / victory / rotate overlay | `ui/menus/` | see 9.2 |
| `SND` | `core/sound.gd` autoload | 7.5 |
| keyboard/mouse/touch handlers | `core/input_setup.gd` (registers InputMap actions at startup, because there is no project.godot editing by hand) + `combat/` input node `combat_input.gd` + `ui/input/touch_gestures.gd` | 5.1 |
| `loop()` | `combat/combat_screen.gd::_process(delta)` (calls sim step, state machine, camera, fx update, then `queue_redraw` on the views) | Keep the order of 6.1. The phase state machine (6.2) belongs to `combat/sim/turns` (view-free); the `loop` code mixes UI timer text with phase transitions: split into `TurnController` (sim, emits `timer_changed(sec, mode)` and `phase_changed`) and HUD. |

### 9.2 DOM/CSS-heavy parts and how to rebuild them

All of these are pure DOM; rebuild with `Control` nodes under a `CanvasLayer` and ONE shared `ui/theme.tres` (project rule: "one theme").

1. **Theme** (`ui/theme.tres`): define fonts (Cinzel title, Plus Jakarta Sans body, JetBrains Mono mono) via `FontVariation` and theme font-type variations (`Title`, `Mono`, `Body`), colours from `core/palette.gd` (brass, ivory, team colours in 3.2), a `StyleBoxFlat` set for: `CmdButton` (pill, radius 999, bg `rgba(16,20,28,.78)`, border `rgba(240,195,110,.32)`, hover/pressed variants, font 10 px bold uppercase), `GlassPanel` (radius 14, bg `rgba(14,18,26,.72..82)`, border `rgba(240,195,110,.28)`), `ChamferPanel` (custom drawn), `TacticalCard` (selected / normal / hover / focus), `MobileButton`, `FireButton`, `DeployButton` (gold gradient: `StyleBoxFlat` has no gradient; use `StyleBoxTexture` with a small `GradientTexture2D`, or a custom `Control`), `LineEdit` and `OptionButton` (`PopupMenu`) skins for the hat select and name inputs (these are native `<select>`/`<input>` in the JS; the select list popup in Godot is a `PopupMenu` styled by the theme).
2. **Focus ring** (`.kb-focus`): outline 2.5 px `#ffd966`, offset 2, glow ring `rgba(246,207,119,.28)` 4 px. In Godot use the theme's `focus` StyleBox for `Button`; but the JS moves a *virtual cursor* with arrows independent of Godot's focus system. Recommended: implement it as real Godot focus (`focus_neighbor_*` set so that ↑/↓ jumps between groups and ←/→ moves within rows) or keep a manual `lobby_focus_idx` and call `grab_focus()` on the element; keep the "auto-select card on ←/→" behaviour (selection follows focus within a card row).
3. **Splash menu** (`ui/menus/main_menu.tscn`): `VBoxContainer` with 3 `MenuItemButton` (custom Button subclass drawing the chamfered background, arrow glyph and two labels), logic: cursor index, hover sets cursor, active translateX 6 px (tween 0.14 s), keyboard ↑/↓/W/S + Enter/Space, hint label. Fade in/out `modulate.a` tween 0.35 s. The title uses a vertical gradient text: render with a `Label` + a canvas `shader` (vertical gradient mask) or draw the text through `RichTextLabel` with a `ShaderMaterial`, or pre-render the title as an image. The kicker/subtitle with letter-spacing: `FontVariation.spacing_glyph`.
4. **Lobby** (`ui/menus/lobby.tscn`): `ScrollContainer` > `VBoxContainer`; sections with `GridContainer` (columns 3/3/6/4/2; switch columns by viewport width < 820: use `get_viewport().size` signals). 8 map cards: `TextureRect` with `STRETCH_KEEP_ASPECT_COVERED` + overlay `ColorRect` gradient (a `GradientTexture2D` vertical) + labels; selected/hover tween scale 1.05. Squad box: `HBoxContainer` rows (`Label` index, `LineEdit` max_length 16, face button). Rebuild rows when the count changes. Hat select: `OptionButton` with the 6 items (order differs between teams, see 3.5).
5. **Top HUD** (`combat/hud/top_hud.tscn`): three-column layout (`GridContainer`/anchors); portrait uses the 2-row arrangement: implement with a `Container` that reflows in `_notification(NOTIFICATION_RESIZED)` or two scene variants chosen by viewport size. The pip rows: 4-column grid (`GridContainer columns=4`), each pip a small `Control` with `Label` + `ProgressBar`-like drawn bar (`StyleBoxFlat` radius 99); tween the fill width 0.25 s. Wind bar: custom draw (centred bar growing left/right, tween 0.25 s on x/width), colour switch gust flash. Timer label large Cinzel.
6. **Bottom HUD** (`combat/hud/bottom_hud.tscn`): fuse picker (hidden unless weapon has custom fuse), 8x2 arsenal `GridContainer` (5 columns in portrait), slot `Control` with hotkey/ammo/icon/label, `drawerPop` tween (0.16 s: alpha 0->1, y +8->0, scale .97->1, cubic-bezier(.2,.9,.3,1) => `Tween.TRANS_BACK`-ish or `TRANS_QUAD` ease out), weapon pill with nav buttons, the touch clusters (hidden on desktop unless touch: `DisplayServer.is_touchscreen_available()` or screen-size rules from 3.4), charge fill rectangle inside the fire button.
7. **Weapon icons** come from 16 inline SVG strings in `WEAPONS[i].svg` (state.js). Port to `assets/icons/weapons/*.svg` (Godot imports SVG as textures; keep `Image` scale param) or draw them procedurally; they appear at 32x22 (slot), 30x20 (pill), and 24x16 / 22x14 (mobile).
8. **Victory modal** (`ui/menus/victory.tscn`): overlay `ColorRect rgba(6,8,12,.82)` + chamfer card, 2-column stats `GridContainer`, two buttons with the keyboard focus toggle.
9. **Rotate overlay** (`ui/menus/rotate_overlay.tscn`): card with the animated phone icon (a `Control` with `_draw` of the SVG shapes and `rotation` tween looping: keyframes 0-15% 0, 55-80% -90 deg, 100% 0, 2.2 s), buttons, show/hide logic from 2.3. Only relevant on web touch/mobile; on Android lock orientation in export settings and skip.
10. **Backdrop blur**: skip or fake; see 3.3.
11. **Text-in-DOM markup**: bold segments in `MENU_HINT` and `ROTATE_BODY` => `RichTextLabel` with `[b]`; `&#9654;`/`&#9650;` glyphs need font coverage: Plus Jakarta Sans / JetBrains Mono do not include `▶ ▲ ▼ ◀ ⇄ ✓ ∞ ♪ ← → ↑ ↓` all; JetBrains Mono has arrows and geometric shapes, Plus Jakarta does not. Provide a fallback font (e.g. Noto Sans Symbols 2 or DejaVu Sans) in the theme's `fallbacks` or draw those glyphs as polygons.
12. **Safe areas**, `100dvh`: use `DisplayServer.get_display_safe_area()`; on web the canvas is the page.
13. **Touch detection**: replace `body.touch-device` + media queries with a `Options`/`InputMode` flag (`touch_ui`), set true on the first `InputEventScreenTouch` or when `DisplayServer.is_touchscreen_available()` and (viewport width <= 920 or height <= 560 or coarse pointer).

### 9.3 Things that need sim queries from the view (keep the view free of sim logic)

`findSurfaceY(x, from_y)`, `isSolid(x, y)` (aim HUD grapple raycast, ground shadows, particle bounce), `fighters`, `mines`, `projectiles` (eye "near danger" test: projectile or armed mine within 115 px), `WATER_Y`, `wind` and `windFactor`, `teamHats`, `teamAmmo`. The view should receive a read-only `CombatSnapshot`/the sim object, per AGENTS.md ("a module receives what it uses").

### 9.4 Deviations to flag in `docs/pending_decisions.md` (do not decide alone)

- Backdrop blur removed; chamfered corners approximated.
- Joypad support is absent in the original (a Godot port could add it; it would be a new feature).
- Web audio start: music begins after the first gesture, same as original.
- HUD behind splash (see 2.1): keep or hide.
- Hidden command buttons (`silk web`, `procession`, `mode`, `reroll map`, `map`, `roster`) are never visible; the port omits their UI, keeps the C/F hotkeys.
- Portrait phone layouts: confirm whether phone portrait is a supported target in Godot (the original shows a rotate overlay and still ships a full portrait HUD).
- English base strings and Catalan translation of the ~150 strings in 3.5 (key list above) go to `i18n/`.

### 9.5 Suggested implementation order for the view/UI

1. `core/palette.gd` + `core/art_catalog.gd` (colours of 3.2, `bg_*.jpg` paths) and `ui/theme.tres` + fonts.
2. `combat/view/camera_rig.gd` (4.2) with a unit test of `get_camera_transform`/`screen_to_world` against JS values (e.g. 1920x1080, DPR 1, `cam=(1600,400)`, `zoom=1.08`, `userZoomMult=1.22` -> `cssBaseScale = min(1920/1620, 1080/760) = 1.185`, scale = 1.185*1.08*1.22 = 1.5614).
3. `parallax_bg.gd` (sky/bg/ridges/sun/clouds), `terrain_view.gd`, `water_view.gd`.
4. `caterpillar_body.gd`, hats, weapons, aim HUD, projectiles, fx pool.
5. HUD scenes, menus, lobby, victory, rotate overlay.
6. `core/sound.gd` + the bake tool (7.5), `core/input_setup.gd`, touch gestures.
7. Verification: render the same camera/frame from the JS reference page and the Godot scene side by side (same map, same seed where possible) and compare layers one by one in the order of table 4.3.

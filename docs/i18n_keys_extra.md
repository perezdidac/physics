# i18n keys used in code but missing from the other tables

Keys read by the view code (`combat/view/aim_hud.gd`, `combat/view/view_util.gd`, `combat/view/combat_input.gd`, `combat/view/sky_painter.gd`) through `ViewUtil.tr_text()`, which falls back to `FALLBACK_TEXT` when a translation is missing. They were not in `docs/i18n_keys_sim.md` or `docs/i18n_keys_ui.md`.
The Catalan originals are the texts of the JS game (`reference/js/renderer.js`, `reference/js/main.js`).
`tools/build_po.py` reads this file together with the two other tables.

| KEY | Catalan original | English proposal |
|---|---|---|
| `AIM_AIRSTRIKE_TARGET` | OBJECTIU CORREFOC | CORREFOC TARGET |
| `AIM_AIRSTRIKE_HINT` | ↑/↓ o TOCA: MOU OBJECTIU · ESPAI/FOC: ATACA | UP/DOWN OR TAP: MOVE TARGET · SPACE/FIRE: ATTACK |
| `AIM_SWITCH_HINT` | TAB / TOCA CUC: CANVIA | TAB / TAP CATERPILLAR: SWITCH |
| `TRACKER_METERS` | ▲ %dm | ▲ %dm |
| `TOUCH_TARGET` | OBJECTIU CORREFOC | CORREFOC TARGET |
| `TOUCH_JUMP` | ¡SALT! | JUMP! |
| `TOUCH_BACKFLIP` | ¡MORTAL ENRERE! | BACKFLIP! |

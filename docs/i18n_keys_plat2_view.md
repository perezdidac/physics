# Platformer view texts, phase D2 (Crisàlide and Papallona)

Texts of the DIG (pupa) and FLY (moth) levels drawn by `platform/` (HUD, touch pad, banners). Format: `KEY | Catalan | English`.
`%d` is the number of seconds left. Add them to `tools/build_po.py`.

| KEY | Catalan | English |
|---|---|---|
| `PLAT_FLAP` | BATEC | FLAP |
| `PLAT_PAD_DIG` | Mantén per cavar | Hold to dig |
| `PLAT_HELP_DIG_KEYS` | Fletxes o WASD per cavar · Espai per fer un saltet | Arrows or WASD to dig · Space for a little hop |
| `PLAT_HELP_DIG_TOUCH` | Mantén una fletxa per cavar · SALTA per fer un saltet | Hold an arrow to dig · JUMP for a little hop |
| `PLAT_HELP_FLY_KEYS` | Espai per batre les ales, mantén-lo per planar · Fletxes per dirigir-te | Space to flap, hold it to glide · Arrows to steer |
| `PLAT_HELP_FLY_TOUCH` | BATEC per batre les ales, mantén-lo per planar · Fletxes per dirigir-te | FLAP to beat your wings, hold it to glide · Arrows to steer |
| `PLAT_BOSS_BAR_PUPA` | Metamorfosi en %d s | Metamorphosis in %d s |
| `PLAT_BOSS_BAR_MOTH` | Posta en %d s | Egg-laying in %d s |
| `PLAT_BOSS_INTRO_HOOPOE` | La Puput! | The hoopoe! |
| `PLAT_BOSS_INTRO_BAT` | El Ratpenat! | The bat! |
| `PLAT_BOSS_HINT_HOOPOE` | Queda't quieta i en silenci: la puput t'escolta | Stay still and quiet: the hoopoe is listening |
| `PLAT_BOSS_HINT_BAT` | Amaga't a l'ombra quan el ratpenat cridi | Hide in the shadows when the bat calls |
| `PLAT_BANNER_CHAMBER` | Ja ets a recer! Bona becaina, Perleta. | Safe at last! Sleep tight, Perleta. |
| `PLAT_BANNER_LANDED` | Un bon lloc per reposar les ales! | A lovely spot to rest your wings! |
| `PLAT_BANNER_METAMORPHOSIS` | Metamorfosi feta! Perleta ja té ales! | Metamorphosis done! Perleta has wings! |
| `PLAT_BANNER_EGGS_LAID` | Posta feta! Els ous ja són a recer. | Eggs laid! They are safe and sound. |
| `PLAT_BANNER_CYCLE` | I el cicle torna a començar… | And the cycle begins again… |
| `PLAT_REASON_METAMORPHOSIS` | Has aguantat en silenci i la crisàlide s'ha obert: ara tens ales! | You kept quiet and the chrysalis opened: now you have wings! |
| `PLAT_REASON_EGGS_LAID` | Has trobat l'amagatall, has post els ous i el cicle torna a començar. | You found shelter, laid your eggs, and the cycle begins again. |
| `PLAT_ENEMY_HOOPOE` | Puput | Hoopoe |
| `PLAT_ENEMY_BAT` | Ratpenat | Bat |

Notes
- `PLAT_REASON_*` are the fallbacks read by `ui/story/story_results.gd`; the story agent may add `STORY_REASON_DIG_METAMORPHOSIS` / `STORY_REASON_FLY_EGGS_LAID` that take precedence.
- `PLAT_ENEMY_HOOPOE` / `PLAT_ENEMY_BAT` are for the level card (`ui/story/level_intro.gd` now builds `STORY_ENEMY_<boss>` for them; either set of keys works).
- Until the keys are in the `.po`, the screen shows the key itself (the boss bar still counts the seconds).

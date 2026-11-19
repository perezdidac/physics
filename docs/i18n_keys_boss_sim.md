# i18n keys created by the BOSS-SIM agent (turn-based bosses, first boss: the Mosca Taquina)

Format: `KEY | Catalan original | English proposal`. `%s` is a placeholder; the sim formats with `tr(KEY) % args`. Larva names are proper nouns (level data) and stay untranslated.
`FT_*` are floating texts emitted by the sim, `DMG_*` are damage labels (shown as `FT_DAMAGE_LABEL`: "label -N"), `BOSS_INTENT_*` are the intent texts (`CombatSim.boss_intent.label`, already formatted with the target names; `%s` = one name, or several joined with `BOSS_NAMES_AND`).
The `LVL_LARVA_BOSS_*` level-card texts now live in `docs/i18n_keys_story_levels.md` (moved by the BOSS-VIEW agent: the build keeps the later table, so the two copies collided).

KEY | Catalan original | English proposal
--- | --- | ---
BOSS_TACHINID_NAME | Mosca Taquina | Tachinid Fly
BOSS_TACHINID_TITLE | La paràsita del pinar | The pinewood parasite
UNIT_SMALL_FLY | Mosqueta | Little fly
BOSS_NAMES_AND | %s i %s | %s and %s
BOSS_INTENT_LAY_EGGS | La Mosca vol pondre ous a %s! | The Fly wants to lay eggs on %s!
BOSS_INTENT_BUZZ | La Mosca brunzeix: aparteu-vos! | The Fly is buzzing: get away!
BOSS_INTENT_SUMMON | La Mosca crida les seves cosines! | The Fly is calling her cousins!
FT_ARMORED | BLINDAT | ARMORED
FT_DODGED | Esquivada! | Dodged!
FT_PARASITE | Ous a l'esquena de %s! | Eggs on %s's back!
FT_CLEANED | %s es neteja amb seda! | %s cleans up with silk!
FT_BOSS_LANDS | S'ha posat: ara, piqueu-la! | It landed: hit it now!
FT_BOSS_TAKEOFF | Torna a volar! | Back in the air!
FT_BOSS_PHASE | Ara s'ha enfadat de debò! | Now it's really angry!
FT_BOSS_SUMMON | Reforços! | Reinforcements!
FT_BOSS_SPLASH | Xof! Ales xopes! | Splash! Soggy wings!
FT_BOSS_DEFEATED | K.O.! | K.O.!
DMG_LAY_EGGS | Posta! | Egg-laying!
DMG_PARASITE | Larves! | Larvae!
DMG_BUZZ | Brunzit! | Buzz!
DMG_SPLASH | Remullada! | Dunked!
DMG_BOSS | Cop! | Whack!
STORY_REASON_BOSS_DEFEATED | Heu fet fora el gran enemic de l'etapa! | You chased off the stage's big enemy!

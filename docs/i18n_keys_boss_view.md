# i18n keys created by the BOSS-VIEW agent (boss UI, boss intro card, the Cuca units)

Format: `KEY | Catalan original | English proposal`. `%d` is a placeholder (formatted with `UiUtil.fmt`).
`BOSS_VULNERABLE`, `BOSS_BANNER_KICKER`, `BOSS_PHASE_BANNER` and `BOSS_DEFEATED_BANNER` are used by the boss HUD (`combat/hud/boss_hud.gd`) and the world overlay.
The level intro card (`ui/story/level_intro.gd`) shows, for a boss level, the boss name and title (from the BossDef) and two texts whose keys come from
`BossDef.name_key` without the `_NAME` suffix: `<prefix>_FACT` (one line of real biology) and `<prefix>_ATTACKS` (how it attacks), for example `BOSS_TACHINID_FACT`.

KEY | Catalan original | English proposal
--- | --- | ---
BOSS_VULNERABLE | Vulnerable! | VULNERABLE!
BOSS_BANNER_KICKER | Enemic de l'etapa | Stage boss
BOSS_PHASE_BANNER | Fase %d | Phase %d
BOSS_DEFEATED_BANNER | Fora de combat! | Out cold!
STORY_LABEL_BOSS | Enemic de l'etapa | Stage boss
STORY_LABEL_BOSS_ATTACKS | Com ataca | How it attacks
BOSS_TACHINID_FACT | Phryxe caudata és una mosca parasitoide: la femella posa els ous sobre les erugues de la processionària i, quan neixen, les seves larves se les mengen per dins. | Phryxe caudata is a parasitoid fly: the female lays her eggs on processionary caterpillars and, when they hatch, her larvae eat the caterpillar from inside.
BOSS_TACHINID_ATTACKS | Avisa abans de cada atac: un cercle vermell marca qui rebrà la posta d'ous, i el brunzit empeny tothom qui té a prop. Després de llançar-se, es posa a terra un torn. | It warns before every attack: a red circle marks who will get the eggs, and her buzz pushes everyone nearby. After her dive she lands for a turn.
BOSS_GREAT_TIT_FACT | La mallerenga carbonera (Parus major) és una de les poques aus que s'atreveixen amb les erugues processionàries: a l'hivern obre els nius de seda a cops de bec per menjar-se'n les larves. | The great tit (Parus major) is one of the few birds that dare to eat processionary caterpillars: in winter it pecks open the silk nests to eat the larvae.
BOSS_GREAT_TIT_ATTACKS | Avisa abans de cada atac: es llança a picar qui marca amb un cercle vermell, i el cop d'ales empeny tothom qui té a prop. Només és vulnerable quan s'atura dalt d'un arbre. | It warns before every attack: it dives to peck whoever it marks with a red circle, and its wing flap pushes everyone nearby. It is only vulnerable when it stops at the top of a tree.
HUD_SQUAD_LARVA_L3 | La Colla | The Gang
HUD_SQUAD_LARVA_L4 | La Colla | The Gang
HUD_SQUAD_LARVA_L5 | La Colla | The Gang
HUD_SQUAD_GREAT_TIT | Les Carboneres | The Great Tits
STORY_WEAPON_PICOTADA_FORTA | Picotada forta | Hard peck

## Which music track plays on which screen. Pure data and lookups, shared by the `Sound` autoload and the tests.
## Tracks are baked by tools/bake_music.gd into assets/audio/music/<name>.wav.
extends RefCounted

## Track of the classic (non-story) match: it keeps the original music.
const CLASSIC := "sardana_de_ferro"
const MENU := "menu"
## Screen scene file (without extension) -> track. Combat and platform screens depend on the level instead.
const SCREEN_TRACK: Dictionary = {
	"Boot": "menu", "Lobby": "menu", "StoryMap": "menu", "LevelIntro": "menu", "StoryResults": "menu",
	"NestHub": "nest",
}
const LEVEL_SCREENS: Array[String] = ["CombatScreen", "PlatformScreen"]
## LevelDef.stage -> track of its ordinary levels.
const STAGE_TRACK: Dictionary = {
	"EGG": "egg", "LARVA_EARLY": "larva", "LARVA": "cuca", "NEST": "nest", "PROCESSION": "procession",
	"PUPA": "pupa", "MOTH": "moth",
}
## LevelDef.stage -> track of its boss level (wasp, tachinid fly, great tit, forestry brigade, cuckoo, hoopoe, bat).
const BOSS_TRACK: Dictionary = {
	"EGG": "boss_wasp", "LARVA_EARLY": "boss_fly", "LARVA": "boss_tit", "NEST": "boss_brigade",
	"PROCESSION": "boss_cuckoo", "PUPA": "boss_hoopoe", "MOTH": "boss_bat",
}
const ALL_TRACKS: Array[String] = [
	"sardana_de_ferro", "menu", "egg", "larva", "cuca", "nest", "procession", "pupa", "moth",
	"boss_wasp", "boss_fly", "boss_tit", "boss_brigade", "boss_cuckoo", "boss_hoopoe", "boss_bat",
]


## Track of a story level: its stage track, or the boss variant for boss levels (a boss or an id ending in "_boss").
static func track_for_level(level: LevelDef) -> String:
	if level == null:
		return CLASSIC
	if level.boss != null or level.id.ends_with("_boss"):
		return BOSS_TRACK.get(level.stage, "boss_wasp")
	return STAGE_TRACK.get(level.stage, CLASSIC)


## Track for the screen whose scene file is `scene_path` (`level` = the story level being played, may be null).
static func track_for_screen(scene_path: String, level: LevelDef) -> String:
	var screen: String = scene_path.get_file().get_basename()
	if screen in LEVEL_SCREENS:
		return track_for_level(level)
	return SCREEN_TRACK.get(screen, CLASSIC)

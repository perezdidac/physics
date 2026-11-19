## Static tables shared by the audio baker (tools/bake_audio.gd) and the runtime `Sound` autoload.
## Everything that decides which baked file exists for a JS `SND.*` call lives here.
extends RefCounted

const MusicTable := preload("res://core/sound/music_table.gd")

const SFX_DIR := "res://assets/audio/sfx/"
const VOICE_DIR := "res://assets/audio/voices/"
const MUSIC_DIR := "res://assets/audio/music/"

## Sounds baked once: the play() name is also the file name in assets/audio/sfx/.
const SIMPLE: Array[String] = [
	"tick", "title_fanfare", "victory", "jump", "backflip", "fire_bazooka", "shotgun", "home_run",
	"hallelujah", "mine_beep", "crate_pickup", "jet_thrust", "jet", "bounce", "plunge", "fuet_whip",
	"carquinyoli_crunch", "rovello_boing", "wind_gust", "caganer_blessing", "spoon_scoop",
	"drill_bore", "stone_build", "grapple_whip", "shell_whistle", "urticating_burst", "crawl_step",
	"skid",
]

## boom(scale): one variant per entry, files boom_0 ... boom_N (nearest scale wins).
const BOOM_SCALES: Array[float] = [0.5, 0.8, 1.0, 1.3, 1.8, 2.4]
## charge(pct): files charge_0 ... charge_5 for pct 0, 0.2 ... 1.
const CHARGE_LEVELS: int = 6
## hard_slam(speed): intensity (clamp(speed/450, .45, 1.3)) and chirps flag of files hard_slam_0 ... 3.
const SLAM_SPEEDS: Array[float] = [200.0, 340.0, 450.0, 585.0]
## worm_hurt(dmg): punch (clamp(dmg/40, .45, 1.25)) of files worm_hurt_0 ... 3.
const HURT_PUNCH: Array[float] = [0.45, 0.75, 1.0, 1.25]

## Worm voices (assets/audio/voices/<mood>_<pick>.wav): mood -> number of random picks.
const VOICES: Dictionary = {"jump": 4, "backflip": 2, "attack": 1, "ow": 4, "death": 1, "itch": 1}

## Sounds whose JS version also calls wormVoice(mood) at the same moment.
const VOICE_OF: Dictionary = {
	"jump": "jump", "backflip": "backflip", "fire_bazooka": "attack", "shotgun": "attack",
	"home_run": "attack", "fuet_whip": "attack", "rovello_boing": "jump", "grapple_whip": "jump",
	"hard_slam": "ow",
}

## Every baked music loop (see music_table.gd).
const MUSIC_TRACKS: Array[String] = MusicTable.ALL_TRACKS
const WIND_FILE := "wind_loop"

## Every name accepted by Sound.play(): the snake_case of each JS SND.* method.
const PLAY_NAMES: Array[String] = [
	"tick", "title_fanfare", "victory", "jump", "backflip", "charge", "fire_bazooka", "shotgun",
	"home_run", "hallelujah", "mine_beep", "crate_pickup", "jet_thrust", "jet", "bounce", "boom",
	"hard_slam", "skid", "plunge", "fuet_whip", "carquinyoli_crunch", "rovello_boing", "wind_gust",
	"caganer_blessing", "spoon_scoop", "drill_bore", "stone_build", "grapple_whip", "shell_whistle",
	"urticating_burst", "crawl_step", "worm_hurt", "worm_voice", "toggle_music", "update_ambient", "init",
]


## All sfx file keys (without extension) that must exist.
static func sfx_keys() -> Array[String]:
	var keys: Array[String] = []
	keys.append_array(SIMPLE)
	for i in BOOM_SCALES.size():
		keys.append("boom_%d" % i)
	for i in CHARGE_LEVELS:
		keys.append("charge_%d" % i)
	for i in SLAM_SPEEDS.size():
		keys.append("hard_slam_%d" % i)
	for i in HURT_PUNCH.size():
		keys.append("worm_hurt_%d" % i)
	keys.append(WIND_FILE)
	return keys


## All voice file keys, e.g. "jump_2".
static func voice_keys() -> Array[String]:
	var keys: Array[String] = []
	for mood: String in VOICES:
		for i: int in VOICES[mood]:
			keys.append("%s_%d" % [mood, i])
	return keys

## Sound API: every JS SND.* name plays without error, unknown names only warn, toggles work.
##   godot --headless --path . res://tests/TestSoundApi.tscn
extends Node

const T := preload("res://core/sound/sound_tables.gd")
## Every SND.* method used by reference/js/*.js (grep "SND\."), in snake_case.
const JS_NAMES: Array[String] = [
	"backflip", "boom", "bounce", "caganer_blessing", "carquinyoli_crunch", "charge", "crate_pickup",
	"crawl_step", "drill_bore", "fire_bazooka", "fuet_whip", "grapple_whip", "hallelujah", "hard_slam",
	"home_run", "init", "jet", "jet_thrust", "jump", "mine_beep", "plunge", "rovello_boing",
	"shell_whistle", "shotgun", "skid", "spoon_scoop", "stone_build", "tick", "title_fanfare",
	"toggle_music", "update_ambient", "urticating_burst", "victory", "wind_gust", "worm_hurt", "worm_voice",
]
var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	var saved_music: bool = Options.music_on
	var saved_sfx: bool = Options.sound_on
	for n in JS_NAMES:
		_check(Sound.has_sound(n), "has_sound(%s)" % n)
		Sound.play(n)
	_check(not Sound.has_sound("nope"), "unknown name is not a sound")
	Sound.play("nope")
	_check(true, "play(unknown) does not crash")
	for mood in ["JUMP", "BACKFLIP", "ATTACK", "OW", "DEATH", "ITCH"]:
		Sound.play("worm_voice", {"kind": mood})
	Sound.play("boom", {"scale": 2.0})
	Sound.play("charge", {"power": 1.0})
	Sound.play("hard_slam", {"speed": 600.0})
	Sound.play("skid", {"speed": 120.0})
	Sound.play("worm_hurt", {"dmg": 50, "dead": true})
	Sound.play("update_ambient", {"wind": 30.0, "playing": true})
	_check(true, "parametrized sounds play")
	Sound.start_music("sardana_de_ferro")
	Sound.set_music(true)
	_check(Sound.is_music_playing(), "music playing when on")
	Sound.set_music(false)
	_check(not Sound.is_music_playing() and not Options.music_on, "music off pauses")
	_check(Sound.toggle_music() and Options.music_on, "toggle_music turns it back on")
	Sound.stop_music()
	_check(not Sound.is_music_playing(), "stop_music stops")
	Sound.set_sfx(false)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "set_sfx(false) mutes SFX bus")
	Sound.set_sfx(true)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "set_sfx(true) unmutes")
	Options.music_on = saved_music
	Options.sound_on = saved_sfx
	Options.save_options()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()

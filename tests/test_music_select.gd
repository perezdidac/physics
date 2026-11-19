## Music selection: every screen and every story level maps to a baked track; bosses get their own variant.
##   godot --headless --path . res://tests/TestMusicSelect.tscn
extends Node

const M := preload("res://core/sound/music_table.gd")
const T := preload("res://core/sound/sound_tables.gd")
var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	for track in M.ALL_TRACKS:
		_check(FileAccess.file_exists(T.MUSIC_DIR + track + ".wav"), "file " + track)
		var s := load(T.MUSIC_DIR + track + ".wav") as AudioStreamWAV
		_check(s != null and s.loop_mode == AudioStreamWAV.LOOP_FORWARD, "loops " + track)
		if s != null and track != "sardana_de_ferro":
			_check(s.get_length() > 40.0 and s.get_length() < 70.0, "%s length %.1f s" % [track, s.get_length()])
	_check(M.track_for_level(null) == M.CLASSIC, "no level -> classic music")
	_check(M.track_for_screen("res://ui/menus/Boot.tscn", null) == "menu", "boot -> menu")
	_check(M.track_for_screen("res://ui/story/StoryMap.tscn", null) == "menu", "story map -> menu")
	_check(M.track_for_screen("res://combat/CombatScreen.tscn", null) == M.CLASSIC, "classic combat keeps its music")
	var list := load("res://data/levels/level_list.tres")
	var levels: Array = list.levels if list != null and "levels" in list else []
	_check(levels.size() >= 37, "level list loaded (%d)" % levels.size())
	var boss_tracks: Dictionary = {}
	for lv: LevelDef in levels:
		var track: String = M.track_for_level(lv)
		_check(track in M.ALL_TRACKS, "%s -> %s" % [lv.id, track])
		if lv.id.ends_with("_boss"):
			_check(track.begins_with("boss_"), "%s is a boss track" % lv.id)
			boss_tracks[track] = true
		else:
			_check(not track.begins_with("boss_"), "%s is not a boss track" % lv.id)
	_check(boss_tracks.size() == 7, "7 distinct boss variants (%d)" % boss_tracks.size())
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()

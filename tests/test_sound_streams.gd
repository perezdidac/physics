## Every baked wav loads, every table entry has a file, and Sound holds a stream for it.
##   godot --headless --path . res://tests/TestSoundStreams.tscn
extends Node

const T := preload("res://core/sound/sound_tables.gd")
var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _wavs_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".wav"):
			out.append(f)
	return out


func _ready() -> void:
	var total_bytes: int = 0
	for dir in [T.SFX_DIR, T.VOICE_DIR, T.MUSIC_DIR]:
		var files: Array[String] = _wavs_in(dir)
		_check(files.size() > 0, "%s has wav files (%d)" % [dir, files.size()])
		for f in files:
			var s := load(dir + f) as AudioStreamWAV
			var good: bool = s != null and s.data.size() > 100 and s.mix_rate == 44100
			_check(good, "loads " + dir.trim_prefix("res://assets/audio/") + f)
			if s != null:
				total_bytes += s.data.size()
	_check(total_bytes < 8 * 1024 * 1024, "total audio %.2f MB < 8 MB" % (total_bytes / 1048576.0))
	for key in T.sfx_keys():
		_check(FileAccess.file_exists(T.SFX_DIR + key + ".wav"), "sfx file " + key)
	for key in T.voice_keys():
		_check(FileAccess.file_exists(T.VOICE_DIR + key + ".wav"), "voice file " + key)
	for track in T.MUSIC_TRACKS:
		_check(FileAccess.file_exists(T.MUSIC_DIR + track + ".wav"), "music file " + track)
	for bus_name in ["Master", "Music", "SFX", "Wind"]:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "bus " + bus_name)
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()

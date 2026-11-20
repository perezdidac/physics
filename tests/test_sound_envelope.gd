## Numeric sanity of the bake against the JS envelope parameters (duration, level, decay).
##   godot --headless --path . res://tests/TestSoundEnvelope.tscn
extends Node

const T := preload("res://core/sound/sound_tables.gd")
var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


## Reads the source wav (the imported resource may be QOA-compressed): 44-byte header, then s16 mono.
func _samples(path: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 100:
		return out
	var pos: int = 12
	while pos + 8 <= bytes.size():
		var chunk_size: int = bytes.decode_u32(pos + 4)
		if bytes.slice(pos, pos + 4).get_string_from_ascii() == "data":
			@warning_ignore("integer_division")
			var count: int = mini(chunk_size, bytes.size() - pos - 8) / 2
			out.resize(count)
			for i in count:
				out[i] = bytes.decode_s16(pos + 8 + i * 2) / 32768.0
			return out
		pos += 8 + chunk_size
	return out


func _rms(x: PackedFloat32Array, a: float, b: float) -> float:
	var i0: int = int(a * 44100.0)
	var i1: int = mini(int(b * 44100.0), x.size())
	var sum: float = 0.0
	for i in range(i0, i1):
		sum += x[i] * x[i]
	return sqrt(sum / maxf(1.0, i1 - i0))


func _peak(x: PackedFloat32Array) -> float:
	var p: float = 0.0
	for v in x:
		p = maxf(p, absf(v))
	return p


func _near(actual: float, expected: float, tol: float, what: String) -> void:
	_check(absf(actual - expected) <= tol, "%s: %.3f (expected %.3f +- %.3f)" % [what, actual, expected, tol])


func _ready() -> void:
	var looped := load(T.MUSIC_DIR + "sardana_de_ferro.wav") as AudioStreamWAV
	_check(looped != null and looped.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music imports as a forward loop")
	# tick: triangle osc 0.038 s, peak gain 0.075 (noise burst 0.015 s is shorter).
	var tick := _samples(T.SFX_DIR + "tick.wav")
	_near(tick.size() / 44100.0, 0.038, 0.012, "tick duration")
	_near(_peak(tick), 0.075, 0.02, "tick peak ~ osc vol 0.075")
	# boom(1.0): longest part is the lowpass noise 0.62 s delayed 0.01 s; decays to silence.
	var boom := _samples(T.SFX_DIR + "boom_2.wav")
	_near(boom.size() / 44100.0, 0.63, 0.2, "boom(1.0) duration")
	_check(_rms(boom, 0.02, 0.12) > 4.0 * _rms(boom, 0.45, 0.6), "boom decays (early rms >> late rms)")
	_check(_peak(boom) < 0.95, "boom does not clip")
	# Boom grows with scale (volume caps min(.42, .32*scale)).
	_check(_peak(_samples(T.SFX_DIR + "boom_4.wav")) > _peak(_samples(T.SFX_DIR + "boom_0.wav")), "bigger boom is louder")
	# mine_beep: sine 1320 Hz 0.065 s, gain 0.12 -> peak near 0.12 + 0.05 overtone.
	var beep := _samples(T.SFX_DIR + "mine_beep.wav")
	_near(beep.size() / 44100.0, 0.065, 0.02, "mine_beep duration")
	_check(_peak(beep) > 0.08 and _peak(beep) < 0.18, "mine_beep level")
	# Music: 64 steps * 0.225 s = 14.4 s loop.
	var music := _samples(T.MUSIC_DIR + "sardana_de_ferro.wav")
	_near(music.size() / 44100.0, 14.4, 0.01, "music loop length")
	_check(_rms(music, 0.0, 14.4) > 0.01 and _peak(music) < 0.9, "music audible, not clipping")
	# Worm voice jump_0: one syllable of 0.13 s, vol 0.24.
	var jump := _samples(T.VOICE_DIR + "jump_0.wav")
	_near(jump.size() / 44100.0, 0.13, 0.03, "jump voice duration")
	_check(_peak(jump) > 0.05 and _peak(jump) < 0.5, "jump voice level")
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()

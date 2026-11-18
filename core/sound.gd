## Sound effects, worm voices, music and ambient wind (autoload `Sound`).
## The original procedural WebAudio synthesis (reference/js/audio.js) is pre-rendered to .wav files by
## tools/bake_audio.gd; this node only plays them. API: play(name, params), set_music, set_sfx,
## start_music, stop_music, unlock, update_ambient. Honours Options.music_on / Options.sound_on.
extends Node

const T := preload("res://core/sound/sound_tables.gd")
const POOL_SIZE: int = 16
const DEFAULT_TRACK := "sardana_de_ferro"
## Minimum real-time gap between two plays of a rate-limited sound (seconds, as in audio.js).
const RATE_LIMIT: Dictionary = {"crawl_step": 0.12, "skid": 0.055, "jet_thrust": 0.05}

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _music_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _music_track: String = ""
var _unlocked: bool = false
var _last_play_ms: Dictionary = {}
var _last_hurt_ms: int = -1000
var _wind_gain: float = 0.0001
var _wind_freq: float = 260.0
var _ambient_ms: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for key in T.sfx_keys():
		_load_stream(key, T.SFX_DIR + key + ".wav")
	for key in T.voice_keys():
		_load_stream("voice/" + key, T.VOICE_DIR + key + ".wav")
	for track in T.MUSIC_TRACKS:
		_load_stream("music/" + track, T.MUSIC_DIR + track + ".wav")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = _bus("SFX")
		add_child(p)
		_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = _bus("Music")
	add_child(_music_player)
	_wind_player = AudioStreamPlayer.new()
	_wind_player.bus = _bus("Wind")
	_wind_player.stream = _streams.get(T.WIND_FILE)
	_wind_player.volume_db = linear_to_db(_wind_gain)
	add_child(_wind_player)
	_apply_sfx_mute()


## True when `sound_name` is a valid first argument of play().
func has_sound(sound_name: String) -> bool:
	return sound_name in T.PLAY_NAMES


## Starts audio after the first user gesture (SND.init): wind loop and, if enabled, the default music.
func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	if _wind_player.stream != null and not _wind_player.playing:
		_wind_player.play()
	if _music_track == "":
		start_music(DEFAULT_TRACK)


## Plays one of the JS SND.* sounds. `params` (all optional): boom {scale}, charge {power},
## hard_slam / skid {speed}, worm_hurt {dmg, dead}, worm_voice {kind}, update_ambient {wind, playing};
## any sound also accepts {pitch_scale, volume_db}.
func play(sound_name: String, params: Dictionary = {}) -> void:
	if not has_sound(sound_name):
		push_warning("Sound.play: unknown sound '%s'" % sound_name)
		return
	unlock()
	match sound_name:
		"init":
			return
		"toggle_music":
			toggle_music()
			return
		"update_ambient":
			update_ambient(float(params.get("wind", 0.0)), bool(params.get("playing", false)))
			return
	if not Options.sound_on or not _rate_ok(sound_name):
		return
	var pitch: float = float(params.get("pitch_scale", 1.0))
	var vol: float = db_to_linear(float(params.get("volume_db", 0.0)))
	match sound_name:
		"boom":
			_play_key("boom_%d" % _nearest(T.BOOM_SCALES, float(params.get("scale", 1.0))), pitch, vol)
		"charge":
			var idx: int = roundi(clampf(float(params.get("power", 0.0)), 0.0, 1.0) * (T.CHARGE_LEVELS - 1))
			_play_key("charge_%d" % idx, pitch, vol)
		"hard_slam":
			var speed: float = float(params.get("speed", 450.0))
			var variant: int = 0 if speed <= 270.0 else (1 if speed <= 360.0 else (2 if speed <= 520.0 else 3))
			_play_key("hard_slam_%d" % variant, pitch, vol)
			_play_voice("ow", pitch, vol)
		"skid":
			var sk: float = float(params.get("speed", 300.0))
			var f: float = 110.0 + minf(200.0, sk * 0.45) + _rng.randf() * 45.0
			_play_key("skid", pitch * f / 200.0, vol * minf(0.08, sk * 0.00025) / 0.08)
		"worm_hurt":
			_worm_hurt(float(params.get("dmg", 15.0)), bool(params.get("dead", false)), pitch, vol)
		"worm_voice":
			_play_voice(str(params.get("kind", "ow")).to_lower(), pitch, vol)
		"crawl_step":
			_play_key(sound_name, pitch * (1.0 + _rng.randf() * 0.375), vol)
		"jet_thrust":
			_play_key(sound_name, pitch * (1.0 + _rng.randf() * 0.36), vol)
		_:
			_play_key(sound_name, pitch, vol)
			if sound_name == "urticating_burst":
				_play_voice("itch", pitch, vol)
			elif T.VOICE_OF.has(sound_name):
				_play_voice(T.VOICE_OF[sound_name], pitch, vol)


## Music on/off (the M key and the music button). The track keeps its position while off.
func set_music(on: bool) -> void:
	Options.music_on = on
	Options.save_options()
	_music_player.stream_paused = not on


## Flips the music setting and returns the new state (SND.toggleMusic).
func toggle_music() -> bool:
	set_music(not Options.music_on)
	return Options.music_on


## Sound effects and wind on/off (Options.sound_on).
func set_sfx(on: bool) -> void:
	Options.sound_on = on
	Options.save_options()
	_apply_sfx_mute()


## Starts a looping music track from the beginning (paused if music is off).
func start_music(track: String = DEFAULT_TRACK) -> void:
	var stream: AudioStreamWAV = _streams.get("music/" + track)
	if stream == null:
		push_warning("Sound.start_music: unknown track '%s'" % track)
		return
	if track == _music_track and _music_player.playing:
		_music_player.stream_paused = not Options.music_on
		return
	_music_track = track
	_music_player.stream = stream
	_music_player.play()
	_music_player.stream_paused = not Options.music_on


## Stops the music and forgets the current track.
func stop_music() -> void:
	_music_player.stop()
	_music_track = ""


## True while a music track is loaded and not paused or stopped.
func is_music_playing() -> bool:
	return _music_player.playing and not _music_player.stream_paused


## Per-frame wind ambience (SND.updateAmbient): `wind_val` is the signed wind, `is_playing` the match state.
func update_ambient(wind_val: float, is_playing: bool) -> void:
	var now_ms: int = Time.get_ticks_msec()
	var dt: float = clampf(float(now_ms - _ambient_ms) / 1000.0, 0.0, 0.25) if _ambient_ms > 0 else 0.0
	_ambient_ms = now_ms
	var mag: float = absf(wind_val)
	var target_freq: float = 180.0 + mag * 4.8 + sin(float(now_ms) / 1000.0 * 1.7) * 35.0
	var target_gain: float = 0.002
	if is_playing:
		target_gain = clampf(0.004 + (mag / 100.0) * 0.022, 0.003, 0.028)
	_wind_freq += (target_freq - _wind_freq) * (1.0 - exp(-dt / 0.12))
	_wind_gain += (target_gain - _wind_gain) * (1.0 - exp(-dt / 0.15))
	_wind_player.volume_db = linear_to_db(_wind_gain)
	var bus: int = AudioServer.get_bus_index("Wind")
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0:
		var fx := AudioServer.get_bus_effect(bus, 0) as AudioEffectBandPassFilter
		if fx != null:
			fx.cutoff_hz = _wind_freq


func _load_stream(key: String, path: String) -> void:
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		push_warning("Sound: missing audio file " + path)
		return
	_streams[key] = stream


func _bus(bus_name: String) -> StringName:
	return bus_name if AudioServer.get_bus_index(bus_name) >= 0 else &"Master"


func _apply_sfx_mute() -> void:
	for bus_name in ["SFX", "Wind"]:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_mute(idx, not Options.sound_on)


func _rate_ok(sound_name: String) -> bool:
	if not RATE_LIMIT.has(sound_name):
		return true
	var now: int = Time.get_ticks_msec()
	if float(now - int(_last_play_ms.get(sound_name, -100000))) / 1000.0 < float(RATE_LIMIT[sound_name]):
		return false
	_last_play_ms[sound_name] = now
	return true


func _nearest(values: Array[float], x: float) -> int:
	var best: int = 0
	for i in values.size():
		if absf(values[i] - x) < absf(values[best] - x):
			best = i
	return best


func _worm_hurt(dmg: float, fatal: bool, pitch: float, vol: float) -> void:
	var punch: float = clampf(dmg / 40.0, 0.45, 1.25)
	_play_key("worm_hurt_%d" % _nearest(T.HURT_PUNCH, punch), pitch, vol)
	# Several hurt voices in a row are staggered by 0.11 s instead of clipping (audio.js:569-574).
	var now: int = Time.get_ticks_msec()
	var delay: float = 0.11 if now < _last_hurt_ms + 120 else 0.0
	_last_hurt_ms = now + int(delay * 1000.0)
	var mood: String = "death" if fatal else "ow"
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_play_voice.bind(mood, pitch, vol))
	else:
		_play_voice(mood, pitch, vol)


func _play_voice(mood: String, pitch: float, vol: float) -> void:
	if not T.VOICES.has(mood):
		push_warning("Sound: unknown worm voice mood '%s'" % mood)
		return
	var pick: int = _rng.randi() % int(T.VOICES[mood])
	_play_key("voice/%s_%d" % [mood, pick], pitch, vol)


func _play_key(key: String, pitch: float, vol: float) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		push_warning("Sound: no stream for '%s'" % key)
		return
	var player: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _pool[_next_player]
		_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = stream
	player.pitch_scale = maxf(pitch, 0.05)
	player.volume_db = linear_to_db(maxf(vol, 0.0001))
	player.play()

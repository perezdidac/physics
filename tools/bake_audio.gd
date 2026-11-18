## Offline renderer of the original WebAudio synthesis (reference/js/audio.js) to .wav files.
## Run: godot --headless --path . res://tools/BakeAudio.tscn   (takes a few minutes)
## Writes assets/audio/{sfx,voices,music}/*.wav (mono, 16 bit, 44.1 kHz) and default_bus_layout.tres.
## Loops (music, wind_loop) are looped by their .wav.import (edit/loop_mode=2), not by the wav file.
## The DSP mirrors WebAudio: oscillators (band-limited), exponential/linear gain ramps, RBJ biquads
## with WebAudio's Q conventions, the room-reflection send. The master compressor is NOT baked: it is
## an effect on the Master bus (see _write_bus_layout), exactly as in the JS graph.
extends Node

const T := preload("res://core/sound/sound_tables.gd")

const SR: int = 44100
const SET_AT: int = 0
const LINEAR: int = 1
const EXPO: int = 2
const SINE: int = 0
const SQUARE: int = 1
const SAW: int = 2
const TRI: int = 3
const LOWPASS: int = 0
const HIGHPASS: int = 1
const BANDPASS: int = 2
const TWO_PI: float = TAU
const STEP_DUR: float = 0.225
const FX_TAIL: float = 0.4

const VOWELS: Dictionary = {
	"A": [920.0, 1680.0], "E": [640.0, 2320.0], "I": [420.0, 2780.0],
	"O": [590.0, 1120.0], "U": [430.0, 940.0],
}

const MIDI_LEAD: Array[int] = [
	76, 81, 79, 76, 77, 74, 77, 81, 79, 71, 74, 79, 76, 72, 74, 76,
	77, 81, 79, 77, 74, 77, 76, 74, 76, 80, 83, 80, 81, 76, 81, 0,
	79, 84, 83, 79, 83, 79, 74, 79, 81, 76, 72, 76, 79, 77, 76, 74,
	77, 79, 81, 83, 84, 81, 77, 74, 76, 80, 83, 86, 81, 76, 81, 0,
]
const MIDI_HARMONY: Array[int] = [
	0, 76, 0, 72, 0, 69, 74, 77, 0, 67, 71, 74, 72, 0, 71, 72,
	0, 77, 0, 74, 0, 74, 72, 69, 71, 76, 80, 76, 76, 72, 76, 0,
	76, 79, 79, 76, 79, 74, 71, 74, 76, 72, 69, 72, 76, 74, 72, 71,
	74, 76, 77, 79, 81, 77, 74, 71, 71, 76, 80, 83, 76, 72, 76, 0,
]
const MIDI_CHORDS: Array = [
	[57, 60, 64, 69], [62, 65, 69, 74], [55, 59, 62, 67], [60, 64, 67, 72],
	[53, 57, 60, 65], [62, 65, 69, 74], [52, 56, 59, 64], [57, 60, 64, 69],
	[60, 64, 67, 72], [55, 59, 62, 67], [57, 60, 64, 69], [52, 55, 59, 64],
	[53, 57, 60, 65], [62, 65, 69, 74], [52, 56, 59, 64], [57, 60, 64, 69],
]
const MIDI_BASS: Array[int] = [
	45, 0, 52, 0, 50, 0, 57, 0, 43, 0, 50, 0, 48, 0, 55, 52,
	41, 0, 48, 0, 50, 0, 45, 0, 40, 0, 47, 52, 45, 52, 45, 0,
	48, 0, 55, 0, 43, 0, 50, 0, 45, 0, 52, 0, 40, 0, 47, 0,
	41, 0, 48, 0, 50, 0, 45, 0, 40, 44, 47, 52, 45, 52, 45, 0,
]

var _rng := RandomNumberGenerator.new()
var _noise := PackedFloat32Array()
## Current output buffer and reverb send buffer (filled by the voice builders).
var _buf := PackedFloat32Array()
var _send := PackedFloat32Array()
var _wrap: bool = false
var _report: Array[String] = []


func _ready() -> void:
	_rng.seed = 20260511
	_noise = _make_noise(1.5)
	var t0: int = Time.get_ticks_msec()
	_bake_sfx()
	_bake_voices()
	_bake_wind()
	_bake_music()
	_write_bus_layout()
	for line in _report:
		print(line)
	print("BAKE DONE in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit()


# ───────────────────────────── DSP primitives ─────────────────────────────

## WebAudio-style pink-ish noise buffer (audio.js:96-106).
func _make_noise(seconds: float) -> PackedFloat32Array:
	var n: int = int(SR * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	for i in n:
		var white: float = _rng.randf() * 2.0 - 1.0
		b0 = 0.997 * b0 + white * 0.029
		b1 = 0.985 * b1 + white * 0.032
		b2 = 0.950 * b2 + white * 0.048
		out[i] = clampf((b0 + b1 + b2 + white * 0.18) * 0.55, -1.0, 1.0)
	return out


## Evaluates a WebAudio AudioParam automation timeline per sample.
## events: Array of [kind, value, time_seconds] in time order (SET_AT / LINEAR / EXPO).
func _curve(events: Array, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var count: int = events.size()
	var kinds := PackedInt32Array()
	var vals := PackedFloat32Array()
	var times := PackedFloat32Array()
	for e: Array in events:
		kinds.append(e[0])
		vals.append(e[1])
		times.append(e[2])
	var idx: int = 0
	var pv: float = vals[0]
	var pt: float = times[0]
	for i in n:
		var t: float = float(i) / SR
		while idx < count and times[idx] <= t:
			pv = vals[idx]
			pt = times[idx]
			idx += 1
		if idx >= count or kinds[idx] == SET_AT:
			out[i] = pv
			continue
		var span: float = times[idx] - pt
		var u: float = (t - pt) / span if span > 0.0 else 1.0
		if kinds[idx] == LINEAR:
			out[i] = pv + (vals[idx] - pv) * u
		else:
			out[i] = pv * pow(vals[idx] / pv, u) if pv > 0.0 else vals[idx]
	return out


func _const(v: float, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(v)
	return out


func _polyblep(t: float, dt: float) -> float:
	if t < dt:
		var x: float = t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var y: float = (t - 1.0) / dt
		return y * y + y + y + 1.0
	return 0.0


## Oscillator following a per-sample frequency curve (band-limited saw/square).
func _wave(kind: int, fcurve: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = fcurve.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var p: float = 0.0
	for i in n:
		var f: float = maxf(fcurve[i], 0.0)
		var dt: float = f / SR
		match kind:
			SINE:
				out[i] = sin(TWO_PI * p)
			SQUARE:
				var s: float = 1.0 if p < 0.5 else -1.0
				out[i] = s + _polyblep(p, dt) - _polyblep(fposmod(p + 0.5, 1.0), dt)
			SAW:
				var p2: float = fposmod(p + 0.5, 1.0)
				out[i] = 2.0 * p2 - 1.0 - _polyblep(p2, dt)
			_:
				if p < 0.25:
					out[i] = 4.0 * p
				elif p < 0.75:
					out[i] = 2.0 - 4.0 * p
				else:
					out[i] = 4.0 * p - 4.0
		p += dt
		if p >= 1.0:
			p -= 1.0
	return out


## RBJ biquad with WebAudio conventions: q is in dB for lowpass/highpass and linear for bandpass.
func _biquad(x: PackedFloat32Array, ftype: int, fc: PackedFloat32Array, q: float) -> PackedFloat32Array:
	var n: int = x.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var qd: float = q if ftype == BANDPASS else pow(10.0, q / 20.0)
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	var a1: float = 0.0
	var a2: float = 0.0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	for i in n:
		if i % 8 == 0:
			var w0: float = TWO_PI * clampf(fc[i], 10.0, SR * 0.49) / SR
			var c: float = cos(w0)
			var alpha: float = sin(w0) / (2.0 * qd)
			var a0: float = 1.0 + alpha
			match ftype:
				LOWPASS:
					b0 = (1.0 - c) * 0.5
					b1 = 1.0 - c
					b2 = b0
				HIGHPASS:
					b0 = (1.0 + c) * 0.5
					b1 = -(1.0 + c)
					b2 = b0
				_:
					b0 = alpha
					b1 = 0.0
					b2 = -alpha
			a1 = -2.0 * c / a0
			a2 = (1.0 - alpha) / a0
			b0 /= a0
			b1 /= a0
			b2 /= a0
		var xi: float = x[i]
		var y: float = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = xi
		y2 = y1
		y1 = y
		out[i] = y
	return out


func _mul(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = a[i] * b[i]
	return out


func _add_sig(a: PackedFloat32Array, b: PackedFloat32Array, gain_b: float = 1.0) -> PackedFloat32Array:
	var out := a.duplicate()
	for i in mini(a.size(), b.size()):
		out[i] += b[i] * gain_b
	return out


## Adds a signal to the output (or send) buffer at `delay` seconds; wraps around when baking a loop.
func _mix(sig: PackedFloat32Array, delay: float, to_send: bool = false) -> void:
	var start: int = int(round(delay * SR))
	var target: PackedFloat32Array = _send if to_send else _buf
	var need: int = start + sig.size()
	if not _wrap and target.size() < need:
		target.resize(need)
	var size: int = target.size()
	for i in sig.size():
		var j: int = start + i
		if _wrap:
			j %= size
		target[j] += sig[i]
	if to_send:
		_send = target
	else:
		_buf = target


## Resets the buffers. `loop_len` > 0 makes a fixed-size circular buffer (seconds).
func _begin(loop_len: float = 0.0) -> void:
	_buf = PackedFloat32Array()
	_send = PackedFloat32Array()
	_wrap = loop_len > 0.0
	if _wrap:
		_buf.resize(int(round(loop_len * SR)))
		_send.resize(_buf.size())


# ───────────────────────────── audio.js building blocks ─────────────────────────────

func _mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## SND._osc: one oscillator, optional exponential glide f1 -> f2, 8 ms attack, exponential decay.
func _osc(type: String, f1: float, dur: float, vol: float, f2: float = 0.0, delay: float = 0.0) -> void:
	var n: int = int(round(dur * SR))
	var fev: Array = [[SET_AT, f1, 0.0]]
	if f2 > 0.0:
		fev.append([EXPO, maxf(16.0, f2), dur])
	var kind: int = {"sine": SINE, "square": SQUARE, "sawtooth": SAW, "triangle": TRI}[type]
	var sig: PackedFloat32Array = _wave(kind, _curve(fev, n))
	var g: PackedFloat32Array = _curve([[SET_AT, 0.001, 0.0], [LINEAR, vol, 0.008], [EXPO, 0.0001, dur]], n)
	_mix(_mul(sig, g), delay)


## SND._noiseBurst: noise slice through a swept biquad and a short envelope.
func _noise_burst(dur: float, vol: float, freq: float = 600.0, q: float = 1.2,
		ftype: String = "lowpass", delay: float = 0.0) -> void:
	var n: int = int(round(dur * SR))
	var offset: int = int(_rng.randf() * 0.4 * SR)
	_mix(_noise_env(offset, n, freq, q, ftype, dur, vol), delay)


func _noise_env(offset: int, n: int, freq: float, q: float, ftype: String, dur: float,
		vol: float) -> PackedFloat32Array:
	var src := PackedFloat32Array()
	src.resize(n)
	for i in n:
		src[i] = _noise[(offset + i) % _noise.size()]
	var kind: int = {"lowpass": LOWPASS, "highpass": HIGHPASS, "bandpass": BANDPASS}[ftype]
	var fc: PackedFloat32Array = _curve([[SET_AT, freq, 0.0], [EXPO, maxf(60.0, freq * 0.28), dur]], n)
	var flt: PackedFloat32Array = _biquad(src, kind, fc, q)
	var g: PackedFloat32Array = _curve([[SET_AT, 0.001, 0.0], [LINEAR, vol, 0.006], [EXPO, 0.0001, dur]], n)
	return _mul(flt, g)


## SND._speakSyllable: formant-filtered glottal sawtooth with vibrato.
func _speak(f_start: float, f_end: float, dur: float, v1: String, v2: String, delay: float,
		vol: float, vib_hz: float, vib_depth: float) -> void:
	var n: int = int(round((dur + 0.01) * SR))
	var fc: PackedFloat32Array = _curve([[SET_AT, f_start, 0.0], [EXPO, maxf(80.0, f_end), dur]], n)
	if vib_depth > 0.0:
		for i in n:
			fc[i] += sin(TWO_PI * vib_hz * float(i) / SR) * vib_depth
	var glottal: PackedFloat32Array = _wave(SAW, fc)
	var sub: PackedFloat32Array = _wave(TRI, _curve(
			[[SET_AT, f_start * 0.5, 0.0], [EXPO, maxf(40.0, f_end * 0.5), dur]], n))
	var fa: Array = VOWELS[v1]
	var fb: Array = VOWELS.get(v2, fa)
	var c1: PackedFloat32Array = _curve([[SET_AT, fa[0], 0.0], [EXPO, fb[0], dur]], n)
	var c2: PackedFloat32Array = _curve([[SET_AT, fa[1], 0.0], [EXPO, fb[1], dur]], n)
	var form1: PackedFloat32Array = _biquad(_add_sig(glottal, sub), BANDPASS, c1, 4.2)
	var form2: PackedFloat32Array = _biquad(glottal, BANDPASS, c2, 5.5)
	var g: PackedFloat32Array = _curve([[SET_AT, 0.0001, 0.0],
			[LINEAR, vol, minf(0.018, dur * 0.25)], [SET_AT, vol * 0.85, dur * 0.72],
			[EXPO, 0.0001, dur]], n)
	_mix(_mul(_add_sig(form1, form2), g), delay)


## SND.wormVoice(mood) for one specific random pick (0..3).
func _voice(mood: String, pick: int) -> void:
	match mood:
		"jump":
			match pick:
				0:
					_speak(420, 760, 0.13, "U", "A", 0.0, 0.24, 6, 8)
				1:
					_speak(480, 820, 0.11, "I", "E", 0.0, 0.23, 7, 10)
					_speak(680, 790, 0.09, "E", "A", 0.09, 0.18, 6, 8)
				2:
					_speak(390, 710, 0.14, "O", "I", 0.0, 0.24, 8, 12)
				_:
					_speak(450, 620, 0.08, "O", "U", 0.0, 0.22, 5, 6)
					_speak(580, 860, 0.11, "A", "I", 0.07, 0.23, 8, 12)
		"backflip":
			if pick % 2 == 0:
				_speak(460, 680, 0.10, "I", "A", 0.0, 0.24, 7, 10)
				_speak(680, 960, 0.22, "U", "O", 0.09, 0.26, 11, 24)
			else:
				_speak(440, 640, 0.09, "U", "O", 0.0, 0.22, 6, 8)
				_speak(620, 780, 0.09, "O", "A", 0.08, 0.23, 8, 10)
				_speak(760, 940, 0.16, "A", "I", 0.16, 0.25, 10, 20)
		"attack":
			_speak(520, 740, 0.09, "O", "A", 0.0, 0.22, 9, 14)
			_speak(680, 560, 0.11, "A", "E", 0.08, 0.20, 8, 12)
		"ow":
			match pick:
				0:
					_speak(780, 520, 0.12, "A", "I", 0.0, 0.28, 14, 28)
					_speak(690, 440, 0.12, "I", "E", 0.11, 0.25, 14, 26)
					_speak(590, 340, 0.15, "I", "U", 0.22, 0.22, 12, 22)
				1:
					_speak(660, 840, 0.09, "O", "A", 0.0, 0.28, 10, 18)
					_speak(820, 310, 0.24, "A", "U", 0.08, 0.27, 15, 32)
				2:
					_speak(540, 860, 0.08, "U", "I", 0.0, 0.26, 9, 14)
					_speak(580, 910, 0.08, "U", "I", 0.085, 0.26, 9, 14)
					_speak(520, 760, 0.11, "U", "E", 0.17, 0.24, 11, 18)
				_:
					_speak(840, 480, 0.13, "A", "I", 0.0, 0.28, 13, 25)
					_speak(560, 270, 0.17, "O", "U", 0.12, 0.26, 11, 20)
		"death":
			_speak(760, 580, 0.14, "A", "E", 0.0, 0.28, 12, 22)
			_speak(640, 420, 0.16, "E", "U", 0.13, 0.27, 11, 20)
			_speak(520, 210, 0.34, "O", "U", 0.28, 0.26, 9, 25)
			var chime: Array[float] = [523.25, 659.25, 783.99, 1046.5]
			for i in chime.size():
				_osc("sine", chime[i], 0.22, 0.07, chime[i] * 1.01, 0.45 + i * 0.055)
		"itch":
			_speak(620, 880, 0.07, "A", "I", 0.0, 0.22, 16, 30)
			_noise_burst(0.08, 0.14, 2600, 2.2, "bandpass", 0.06)
			_speak(740, 490, 0.12, "I", "U", 0.11, 0.22, 15, 28)


## SND._playMidiLead: saw/triangle + detuned square, vibrato, swept lowpass, sent to the room reverb.
func _lead(midi: int, t: float, dur: float, vol: float, harmony: bool) -> void:
	var f: float = _mtof(midi)
	var n: int = int(round((dur + 0.01) * SR))
	var vib_g: PackedFloat32Array = _curve([[SET_AT, 0.1, 0.0], [LINEAR, f * 0.0085, dur * 0.65]], n)
	var fc := PackedFloat32Array()
	fc.resize(n)
	for i in n:
		fc[i] = f + sin(TWO_PI * 5.6 * float(i) / SR) * vib_g[i]
	var o1: PackedFloat32Array = _wave(TRI if harmony else SAW, fc)
	var o2: PackedFloat32Array = _wave(SQUARE, _const(f * 1.0025, n))
	var mixed: PackedFloat32Array = _add_sig(o1, o2, 0.28)
	var cut: PackedFloat32Array = _curve([[SET_AT, f * 2.2, 0.0], [EXPO, f * 4.2, 0.04],
			[EXPO, f * 2.5, dur]], n)
	var flt: PackedFloat32Array = _biquad(mixed, LOWPASS, cut, 2.1)
	var g: PackedFloat32Array = _curve([[SET_AT, 0.0001, 0.0], [LINEAR, vol, 0.018],
			[SET_AT, vol * 0.82, dur * 0.65], [EXPO, 0.0001, dur]], n)
	var sig: PackedFloat32Array = _mul(flt, g)
	_mix(sig, t)
	_mix(sig, t, true)


## SND._playMidiGuitar: plucked arpeggio note.
func _guitar(midi: int, t: float, dur: float, vol: float) -> void:
	var f: float = _mtof(midi)
	var n: int = int(round((dur + 0.01) * SR))
	var mixed: PackedFloat32Array = _add_sig(_wave(SAW, _const(f, n)), _wave(TRI, _const(f * 2.0, n)), 0.25)
	var cut: PackedFloat32Array = _curve([[SET_AT, f * 6.5, 0.0], [EXPO, f * 1.4, dur * 0.85]], n)
	var flt: PackedFloat32Array = _biquad(mixed, LOWPASS, cut, 1.4)
	var g: PackedFloat32Array = _curve([[SET_AT, 0.0001, 0.0], [LINEAR, vol, 0.006],
			[EXPO, 0.0001, dur]], n)
	_mix(_mul(flt, g), t)


## SND._playMidiBass: pizzicato tuba.
func _bass(midi: int, t: float, dur: float, vol: float) -> void:
	var f: float = _mtof(midi)
	var n: int = int(round((dur + 0.01) * SR))
	var mixed: PackedFloat32Array = _add_sig(_wave(TRI, _const(f, n)), _wave(SAW, _const(f, n)))
	var cut: PackedFloat32Array = _curve([[SET_AT, 420.0, 0.0], [EXPO, 135.0, dur]], n)
	var flt: PackedFloat32Array = _biquad(mixed, LOWPASS, cut, 1.0)
	var g: PackedFloat32Array = _curve([[SET_AT, 0.0001, 0.0], [LINEAR, vol, 0.01],
			[EXPO, 0.0001, dur]], n)
	_mix(_mul(flt, g), t)


## SND._playMidiPerc: timbal kick on steps 0/2, snare tap on 1/3, tambourine hiss on 0/2.
func _perc(step_in_bar: int, t: float) -> void:
	if step_in_bar == 0 or step_in_bar == 2:
		var n: int = int(round(0.15 * SR))
		var f0: float = 115.0 if step_in_bar == 0 else 98.0
		var peak: float = 0.042 if step_in_bar == 0 else 0.028
		var sig: PackedFloat32Array = _wave(SINE, _curve([[SET_AT, f0, 0.0], [EXPO, 38.0, 0.13]], n))
		var g: PackedFloat32Array = _curve([[SET_AT, 0.001, 0.0], [LINEAR, peak, 0.005],
				[EXPO, 0.0001, 0.14]], n)
		_mix(_mul(sig, g), t)
	var snare: bool = step_in_bar == 1 or step_in_bar == 3
	var dur: float = 0.075 if snare else 0.035
	var vol: float = 0.018 if snare else 0.008
	var count: int = int(round((dur + 0.01) * SR))
	var src := PackedFloat32Array()
	src.resize(count)
	for i in count:
		src[i] = _noise[(int(0.1 * SR) + i) % _noise.size()] if i < int(dur * SR) else 0.0
	var fc: PackedFloat32Array = _const(1850.0 if snare else 5200.0, count)
	var flt: PackedFloat32Array = _biquad(src, BANDPASS if snare else HIGHPASS, fc, 1.5 if snare else 0.8)
	var g2: PackedFloat32Array = _curve([[SET_AT, 0.0001, 0.0], [LINEAR, vol, 0.003],
			[EXPO, 0.0001, dur]], count)
	_mix(_mul(flt, g2), t)


## Room reflection bus (audio.js:78-92): send * 0.075 -> delay 0.11 s (+ 0.12 feedback) -> lowpass 1800.
func _reverb_wet(send: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = send.size()
	var delay_n: int = int(round(0.11 * SR))
	var din := PackedFloat32Array()
	din.resize(n)
	var wet := PackedFloat32Array()
	wet.resize(n)
	var w0: float = TWO_PI * 1800.0 / SR
	var c: float = cos(w0)
	var alpha: float = sin(w0) / (2.0 * pow(10.0, 1.0 / 20.0))
	var a0: float = 1.0 + alpha
	var b0: float = (1.0 - c) * 0.5 / a0
	var b1: float = (1.0 - c) / a0
	var a1: float = -2.0 * c / a0
	var a2: float = (1.0 - alpha) / a0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	for i in n:
		var d: float = din[i - delay_n] if i >= delay_n else 0.0
		var y: float = b0 * d + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = d
		y2 = y1
		y1 = y
		wet[i] = y
		din[i] = send[i] * 0.075 + 0.12 * y
	return wet


# ───────────────────────────── output ─────────────────────────────

## Applies the reverb send, trims silence, soft-limits and writes the buffer as a 16-bit mono wav.
func _emit(path: String, loop: bool = false) -> void:
	var out: PackedFloat32Array = _buf
	var has_send: bool = false
	for v in _send:
		if v != 0.0:
			has_send = true
			break
	if has_send:
		if loop:
			var n: int = _send.size()
			var tiled := PackedFloat32Array()
			for k in 3:
				tiled.append_array(_send)
			var wet: PackedFloat32Array = _reverb_wet(tiled)
			for i in n:
				out[i] += wet[2 * n + i]
		else:
			var tail: int = int(FX_TAIL * SR)
			var sz: int = out.size()
			out.resize(sz + tail)
			_send.resize(sz + tail)
			var wet2: PackedFloat32Array = _reverb_wet(_send)
			for i in out.size():
				out[i] += wet2[i]
	var last: int = out.size()
	if not loop:
		last = 64
		for i in range(out.size() - 1, 63, -1):
			if absf(out[i]) > 0.00015:
				last = i + 64
				break
		last = mini(last, out.size())
	var bytes := PackedByteArray()
	bytes.resize(last * 2)
	var peak: float = 0.0
	var sum_sq: float = 0.0
	for i in last:
		var v: float = out[i]
		var a: float = absf(v)
		if a > 0.9:
			v = signf(v) * (0.9 + 0.1 * tanh((a - 0.9) / 0.1))
		peak = maxf(peak, absf(v))
		sum_sq += v * v
		bytes.encode_s16(i * 2, int(round(clampf(v, -1.0, 1.0) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = bytes
	var err: int = wav.save_to_wav(path)
	_report.append("%-62s %6.3f s  peak %.3f  rms %.4f  %s" % [path.trim_prefix("res://assets/audio/"),
			float(last) / SR, peak, sqrt(sum_sq / maxf(1.0, last)), "" if err == OK else "SAVE ERROR"])


# ───────────────────────────── sound definitions ─────────────────────────────

func _bake_sfx() -> void:
	var s: Dictionary = {
		"tick": _tick, "title_fanfare": _title_fanfare, "victory": _victory, "jump": _jump,
		"backflip": _backflip, "fire_bazooka": _fire_bazooka, "shotgun": _shotgun,
		"home_run": _home_run, "hallelujah": _hallelujah, "mine_beep": _mine_beep,
		"crate_pickup": _crate_pickup, "jet_thrust": _jet_thrust, "jet": _jet, "bounce": _bounce,
		"plunge": _plunge, "fuet_whip": _fuet_whip, "carquinyoli_crunch": _carquinyoli,
		"rovello_boing": _rovello, "wind_gust": _wind_gust, "caganer_blessing": _caganer,
		"spoon_scoop": _spoon, "drill_bore": _drill, "stone_build": _stone, "grapple_whip": _grapple,
		"shell_whistle": _shell_whistle, "urticating_burst": _urticating, "crawl_step": _crawl,
		"skid": _skid,
	}
	for key: String in T.SIMPLE:
		_begin()
		(s[key] as Callable).call()
		_emit(T.SFX_DIR + key + ".wav")
	for i in T.BOOM_SCALES.size():
		_begin()
		_boom(T.BOOM_SCALES[i])
		_emit(T.SFX_DIR + "boom_%d.wav" % i)
	for i in T.CHARGE_LEVELS:
		_begin()
		_charge(float(i) / (T.CHARGE_LEVELS - 1))
		_emit(T.SFX_DIR + "charge_%d.wav" % i)
	for i in T.SLAM_SPEEDS.size():
		_begin()
		_hard_slam(T.SLAM_SPEEDS[i])
		_emit(T.SFX_DIR + "hard_slam_%d.wav" % i)
	for i in T.HURT_PUNCH.size():
		_begin()
		_worm_hurt(T.HURT_PUNCH[i])
		_emit(T.SFX_DIR + "worm_hurt_%d.wav" % i)


func _bake_voices() -> void:
	for mood: String in T.VOICES:
		for pick: int in T.VOICES[mood]:
			_begin()
			_voice(mood, pick)
			_emit(T.VOICE_DIR + "%s_%d.wav" % [mood, pick])


## 1.5 s seamless loop of the pink-ish noise; the Wind bus band-pass is applied live at runtime.
func _bake_wind() -> void:
	var loop_n: int = _noise.size()
	var fade: int = int(0.15 * SR)
	var gen := PackedFloat32Array()
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	for i in loop_n + fade:
		var white: float = _rng.randf() * 2.0 - 1.0
		b0 = 0.997 * b0 + white * 0.029
		b1 = 0.985 * b1 + white * 0.032
		b2 = 0.950 * b2 + white * 0.048
		gen.append(clampf((b0 + b1 + b2 + white * 0.18) * 0.55, -1.0, 1.0))
	_begin(float(loop_n) / SR)
	for i in loop_n:
		var v: float = gen[i]
		if i < fade:
			var w: float = float(i) / fade
			v = gen[loop_n + i] * sqrt(w) + gen[i] * sqrt(1.0 - w)
		_buf[i] = v
	_emit(T.SFX_DIR + T.WIND_FILE + ".wav", true)


func _bake_music() -> void:
	_begin(64.0 * STEP_DUR)
	for s in 64:
		var t: float = s * STEP_DUR
		@warning_ignore("integer_division")
		var bar: int = (s / 4) % 16
		var in_bar: int = s % 4
		var lead: int = MIDI_LEAD[s]
		if lead > 0:
			var next_rest: bool = MIDI_LEAD[(s + 1) % 64] == 0
			_lead(lead, t, STEP_DUR * (1.85 if next_rest else 0.92), 0.032, false)
		if MIDI_HARMONY[s] > 0:
			_lead(MIDI_HARMONY[s], t, STEP_DUR * 0.88, 0.018, true)
		var chord: Array = MIDI_CHORDS[bar]
		_guitar(chord[in_bar % chord.size()], t, STEP_DUR * 0.90, 0.024)
		if MIDI_BASS[s] > 0:
			_bass(MIDI_BASS[s], t, STEP_DUR * 1.45, 0.044)
		_perc(in_bar, t)
	_emit(T.MUSIC_DIR + "sardana_de_ferro.wav", true)


func _tick() -> void:
	_osc("triangle", 920, 0.038, 0.075, 640)
	_noise_burst(0.015, 0.04, 2800, 3.0, "bandpass")


func _fanfare_note(freq: float, t: float, dur: float, vol: float, bass_vol: float) -> void:
	var m: int = int(round(69.0 + 12.0 * log(freq / 440.0) / log(2.0)))
	_lead(m, t, dur, vol, false)
	if bass_vol > 0.0:
		_bass(m - 12, t, dur * 1.1, bass_vol)


func _title_fanfare() -> void:
	var notes: Array[float] = [440, 523.25, 659.25, 880, 783.99, 880]
	var durs: Array[float] = [0.14, 0.14, 0.14, 0.26, 0.14, 0.48]
	var t_off: float = 0.02
	for i in notes.size():
		_fanfare_note(notes[i], t_off, durs[i], 0.065, 0.055)
		t_off += durs[i] * 0.85


func _victory() -> void:
	var notes: Array[float] = [440, 554.37, 659.25, 880]
	for i in notes.size():
		_fanfare_note(notes[i], i * 0.08, 0.42, 0.065, 0.0)


func _caganer() -> void:
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		_fanfare_note(notes[i], i * 0.06, 0.22, 0.06, 0.0)


func _jump() -> void:
	_noise_burst(0.045, 0.07, 1100, 1.8, "bandpass")
	_osc("sine", 165, 0.19, 0.18, 540)
	_osc("triangle", 240, 0.15, 0.11, 760, 0.02)


func _backflip() -> void:
	_noise_burst(0.09, 0.11, 1600, 1.6, "bandpass")
	_osc("sine", 190, 0.12, 0.18, 520)
	_osc("triangle", 310, 0.22, 0.18, 920, 0.07)
	_osc("sine", 460, 0.16, 0.10, 1180, 0.12)


func _charge(pct: float) -> void:
	var f: float = 190.0 + pct * 480.0
	_osc("triangle", f, 0.055, 0.065, f * 1.12)
	_osc("sawtooth", f * 0.5, 0.045, 0.035, f * 0.56)
	_noise_burst(0.02, 0.035, 1800.0 + pct * 1400.0, 3.0, "bandpass")


func _fire_bazooka() -> void:
	_noise_burst(0.28, 0.28, 820, 0.85, "lowpass")
	_noise_burst(0.14, 0.18, 2200, 1.4, "bandpass", 0.02)
	_osc("sine", 155, 0.28, 0.30, 34)
	_osc("sawtooth", 210, 0.22, 0.20, 48)


func _shotgun() -> void:
	_noise_burst(0.025, 0.16, 3800, 2.5, "bandpass")
	_noise_burst(0.24, 0.32, 1450, 0.75, "lowpass", 0.015)
	_osc("sawtooth", 280, 0.19, 0.28, 36, 0.015)
	_osc("square", 135, 0.16, 0.20, 28, 0.015)


func _home_run() -> void:
	_osc("square", 960, 0.06, 0.26, 220)
	_osc("triangle", 420, 0.14, 0.26, 95)
	var chord: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for i in chord.size():
		_osc("triangle", chord[i], 0.28, 0.11, chord[i] * 1.01, 0.07 + i * 0.04)


func _hallelujah() -> void:
	var chord: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for f in chord:
		_osc("sine", f, 0.55, 0.11, f * 1.001, 0.0)
		_osc("triangle", f * 0.5, 0.55, 0.07, f * 0.5, 0.0)
		_osc("sine", f * 1.122, 0.78, 0.12, f * 1.122, 0.56)


func _mine_beep() -> void:
	_osc("sine", 1320, 0.065, 0.12, 1320)
	_osc("triangle", 2640, 0.045, 0.05, 2640)


func _crate_pickup() -> void:
	var notes: Array[float] = [587.33, 783.99, 987.77, 1174.66]
	for i in notes.size():
		_osc("triangle", notes[i], 0.18, 0.12, notes[i] * 1.01, i * 0.045)
		_osc("sine", notes[i] * 2.0, 0.12, 0.05, notes[i] * 2.0, i * 0.045)


## Baked at the lowest pitch (110 Hz); runtime pitch_scale 1.0 .. 1.36 covers the random 110..150.
func _jet_thrust() -> void:
	_noise_burst(0.065, 0.08, 720, 1.2, "bandpass")
	_osc("sawtooth", 110, 0.065, 0.09, 58)


func _jet() -> void:
	_osc("sawtooth", 120, 0.32, 0.14, 290)


func _bounce() -> void:
	_noise_burst(0.045, 0.09, 760, 1.8, "bandpass")
	_osc("triangle", 185, 0.085, 0.14, 68)
	_osc("sine", 290, 0.05, 0.08, 120)


func _boom(scale: float) -> void:
	var dur: float = clampf(0.62 * scale, 0.38, 1.15)
	_noise_burst(0.045, minf(0.38, 0.28 * scale), 2400, 1.2, "bandpass")
	_noise_burst(dur, minf(0.42, 0.32 * scale), 640, 0.68, "lowpass", 0.01)
	_noise_burst(dur * 0.75, minf(0.24, 0.18 * scale), 1450, 1.5, "bandpass", 0.03)
	_osc("sine", 115, dur * 0.85, minf(0.45, 0.36 * scale), 18)
	_osc("sawtooth", 135, dur * 0.55, minf(0.32, 0.24 * scale), 22)
	_osc("triangle", 72, dur * 0.92, minf(0.38, 0.30 * scale), 15)


## Impact body only (the "ow" voice is a separate file); chirps only when speed > 360.
func _hard_slam(speed: float) -> void:
	var intensity: float = clampf(speed / 450.0, 0.45, 1.3)
	_noise_burst(0.14, 0.20 * intensity, 520, 1.1, "lowpass")
	_osc("triangle", 140, 0.18, 0.26 * intensity, 32)
	_osc("sawtooth", 95, 0.14, 0.18 * intensity, 24)
	if speed > 360.0:
		var chirps: Array[float] = [740, 980, 820, 1120]
		for i in chirps.size():
			_osc("sine", chirps[i], 0.09, 0.07, chirps[i] * 1.18, 0.14 + i * 0.065)


## Baked at the loudest setting (speed >= 320) and pitch f = 200 Hz; runtime volume/pitch follow speed.
func _skid() -> void:
	_noise_burst(0.05, 0.08, 980, 2.0, "bandpass")
	_osc("triangle", 200, 0.05, 0.09, 140)


func _plunge() -> void:
	_noise_burst(0.42, 0.28, 1150, 1.2, "bandpass")
	_noise_burst(0.22, 0.18, 2800, 1.6, "bandpass", 0.04)
	_osc("sawtooth", 290, 0.28, 0.18, 48)
	_osc("sine", 460, 0.22, 0.16, 90)
	var delays: Array[float] = [0.14, 0.26, 0.38, 0.50]
	for i in delays.size():
		_speak(340.0 + i * 55.0, 580.0 + i * 65.0, 0.10, "U", "O", delays[i], 0.22, 18, 35)


func _fuet_whip() -> void:
	_noise_burst(0.075, 0.26, 2600, 1.6, "bandpass", 0.035)
	_osc("sawtooth", 210, 0.09, 0.20, 1120)
	_osc("square", 980, 0.065, 0.22, 130, 0.045)
	_osc("triangle", 180, 0.15, 0.24, 44, 0.055)


func _carquinyoli() -> void:
	_noise_burst(0.05, 0.16, 1850, 2.0, "bandpass")
	_osc("square", 840, 0.05, 0.16, 310)
	_osc("triangle", 1240, 0.045, 0.14, 480, 0.02)


func _rovello() -> void:
	_osc("sine", 180, 0.28, 0.24, 680)
	_osc("triangle", 270, 0.24, 0.18, 920, 0.025)


func _wind_gust() -> void:
	_noise_burst(0.45, 0.08, 520, 2.6, "bandpass")
	_osc("sine", 240, 0.36, 0.055, 360)
	_osc("triangle", 175, 0.38, 0.045, 115, 0.04)


func _spoon() -> void:
	_noise_burst(0.095, 0.16, 580, 1.6, "bandpass")
	_osc("triangle", 155, 0.095, 0.16, 260)


func _drill() -> void:
	_noise_burst(0.06, 0.18, 1120, 2.2, "bandpass")
	_osc("sawtooth", 98, 0.065, 0.18, 54)
	_osc("square", 260, 0.045, 0.12, 115)


func _stone() -> void:
	_noise_burst(0.12, 0.20, 460, 1.5, "lowpass")
	_osc("triangle", 140, 0.18, 0.22, 62)
	_osc("sine", 392, 0.16, 0.12, 523.25, 0.05)


func _grapple() -> void:
	_noise_burst(0.13, 0.16, 1950, 2.0, "bandpass")
	_osc("sine", 280, 0.19, 0.18, 760)


func _shell_whistle() -> void:
	_osc("sine", 1120, 0.42, 0.055, 290)
	_osc("triangle", 560, 0.42, 0.025, 145)


func _urticating() -> void:
	_noise_burst(0.28, 0.18, 1650, 1.8, "bandpass")
	_osc("sawtooth", 680, 0.28, 0.15, 160)
	_osc("triangle", 980, 0.22, 0.11, 290, 0.03)


## Baked at pitch 240 Hz; runtime pitch_scale 1.0 .. 1.375 covers the random 240..330.
func _crawl() -> void:
	_osc("sine", 240, 0.045, 0.045, 348)
	_noise_burst(0.035, 0.025, 1200, 2.4, "bandpass")


## Hurt impact body only (the voice is picked separately at runtime).
func _worm_hurt(punch: float) -> void:
	_noise_burst(0.08, 0.18 * punch, 950, 1.4, "bandpass")
	_osc("triangle", 175, 0.12, 0.24 * punch, 42)
	_osc("sawtooth", 260, 0.08, 0.16 * punch, 68)


## Master compressor (as in the JS graph) plus the SFX / Music / Wind buses.
func _write_bus_layout() -> void:
	AudioServer.set_bus_count(1)
	while AudioServer.get_bus_effect_count(0) > 0:
		AudioServer.remove_bus_effect(0, 0)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -14.0
	comp.ratio = 4.5
	comp.attack_us = 2000.0
	comp.release_ms = 180.0
	comp.gain = 6.0  # approximates the automatic makeup gain of the WebAudio compressor
	AudioServer.add_bus_effect(0, comp)
	for bus_name in ["Music", "SFX", "Wind"]:
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
		if bus_name == "Wind":
			var bp := AudioEffectBandPassFilter.new()
			bp.cutoff_hz = 260.0
			bp.resonance = 0.7
			AudioServer.add_bus_effect(idx, bp)
	var err: int = ResourceSaver.save(AudioServer.generate_bus_layout(), "res://default_bus_layout.tres")
	_report.append("default_bus_layout.tres: %s" % ("ok" if err == OK else "ERROR %d" % err))

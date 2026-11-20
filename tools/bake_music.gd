## Offline cobla synthesizer used by tools/bake_audio.gd: renders the story music (compositions in
## tools/bake_music_data.gd) to seamless mono 22.05 kHz WAV loops plus their .import files.
## Voices: gralla, tible and tenora (double reeds: formant-filtered harmonic tables with a doubled,
## slightly detuned reed), flabiol (breathy 3-hole flute), contrabaix (plucked bass), tamborí and timbal (drums).
extends RefCounted

const SR: int = 22050
const TABLE: int = 256
const NOISE_LEN: int = 32768
const TARGET_RMS: float = 0.034
const SCALES: Dictionary = {
	"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10],
	"mixolydian": [0, 2, 4, 5, 7, 9, 10], "harmonic": [0, 2, 3, 5, 7, 8, 11], "phrygian": [0, 1, 3, 5, 7, 8, 10],
}
## Tonal voices. formants: [centre Hz, width in ln units, gain]; rolloff: harmonic k has amplitude k^-rolloff;
## pluck > 0: exponential decay time (s) instead of a sustained note; send: reverb send level.
const INSTS: Dictionary = {
	"gralla": {"rolloff": 0.5, "formants": [[1100.0, 0.5, 3.0], [2500.0, 0.4, 3.5]], "floor": 0.25, "even": 1.0,
		"attack": 0.014, "release": 0.06, "vib_rate": 0.0, "vib_depth": 0.0, "vib_delay": 0.0, "scoop": 0.05,
		"noise": 0.04, "detune": 0.004, "gain": 0.9, "pluck": 0.0, "send": 0.16},
	"tible": {"rolloff": 0.8, "formants": [[1500.0, 0.5, 2.5], [2800.0, 0.5, 1.5]], "floor": 0.2, "even": 0.9,
		"attack": 0.02, "release": 0.07, "vib_rate": 5.3, "vib_depth": 0.004, "vib_delay": 0.15, "scoop": 0.025,
		"noise": 0.02, "detune": 0.003, "gain": 0.8, "pluck": 0.0, "send": 0.2},
	"tenora": {"rolloff": 1.0, "formants": [[650.0, 0.6, 3.0], [1500.0, 0.5, 1.4]], "floor": 0.12, "even": 0.7,
		"attack": 0.035, "release": 0.1, "vib_rate": 4.7, "vib_depth": 0.005, "vib_delay": 0.2, "scoop": 0.02,
		"noise": 0.02, "detune": 0.0025, "gain": 0.9, "pluck": 0.0, "send": 0.24},
	"flabiol": {"rolloff": 2.2, "formants": [[1800.0, 0.8, 1.0]], "floor": 0.1, "even": 0.5,
		"attack": 0.03, "release": 0.09, "vib_rate": 5.0, "vib_depth": 0.003, "vib_delay": 0.12, "scoop": 0.012,
		"noise": 0.1, "detune": 0.0, "gain": 0.7, "pluck": 0.0, "send": 0.3},
	"contrabaix": {"rolloff": 1.4, "formants": [[160.0, 0.7, 2.5]], "floor": 0.15, "even": 0.9,
		"attack": 0.01, "release": 0.12, "vib_rate": 0.0, "vib_depth": 0.0, "vib_delay": 0.0, "scoop": 0.0,
		"noise": 0.01, "detune": 0.0, "gain": 1.0, "pluck": 0.35, "send": 0.08},
}
const HIT_VOL: Dictionary = {"X": 1.0, "x": 0.6, "g": 0.3}

var _buf := PackedFloat32Array()
var _send := PackedFloat32Array()
var _cache: Dictionary = {}
var _white := PackedFloat32Array()
var _soft := PackedFloat32Array()
var _warnings: Array[String] = []


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261119
	_white.resize(NOISE_LEN)
	_soft.resize(NOISE_LEN)
	var lp: float = 0.0
	for i in NOISE_LEN:
		_white[i] = rng.randf() * 2.0 - 1.0
		lp += (_white[i] - lp) * 0.25
		_soft[i] = lp * 2.0


## Renders `track` (see bake_music_data.gd) to `path`; returns one report line (plus warnings).
func bake(track: Dictionary, path: String) -> String:
	var spb: int = track["spb"]
	var step_dur: float = track["step"]
	var bars_total: int = 0
	for sec: Dictionary in track["sections"]:
		bars_total += int(sec["bars"])
	var n: int = int(round(bars_total * spb * step_dur * SR))
	_buf.resize(n)
	_buf.fill(0.0)
	_send.resize(n)
	_send.fill(0.0)
	_warnings.clear()
	for part: Dictionary in track["parts"]:
		var bar_off: int = 0
		for sec: Dictionary in track["sections"]:
			var layer: String = String(part["layer"])
			if (sec["layers"] as Dictionary).has(layer):
				_place_part(track, part, String(sec["layers"][layer]), bar_off, int(sec["bars"]))
			bar_off += int(sec["bars"])
	_reverb(float(track.get("reverb", 1.3)))
	var rms: float = _master()
	_write(path, n)
	_write_import(path)
	var line: String = "%-40s %6.2f s  %5.2f MB wav  rms %.4f" % [path.get_file(), float(n) / SR,
			float(n * 2) / 1048576.0, rms]
	for w in _warnings:
		line += "\n    WARNING " + w
	return line


# ───────────────────────────── score parsing ─────────────────────────────

func _place_part(track: Dictionary, part: Dictionary, text: String, bar_off: int, bars: int) -> void:
	var spb: int = track["spb"]
	var scale: Array = SCALES[track["mode"]]
	var base: int = int(track["tonic"]) + int(part.get("shift", 0))
	var deg_shift: int = int(part.get("deg", 0))
	var inst: String = part["inst"]
	var vol: float = part.get("vol", 0.5)
	var origin: int = bar_off * spb
	match String(part["kind"]):
		"notes":
			var pos: int = 0
			for tok in text.replace("|", " ").split(" ", false):
				var dur: int = 1
				var body: String = tok
				var colon: int = tok.find(":")
				if colon >= 0:
					dur = int(tok.substr(colon + 1))
					body = tok.substr(0, colon)
				if body != "r":
					_note(track, inst, base + _degree(body, deg_shift, scale), origin + pos, dur, vol)
				pos += dur
			if pos != bars * spb:
				_warnings.append("%s/%s: %d steps, expected %d" % [part["inst"], part["layer"], pos, bars * spb])
		"bass":
			var roots: PackedStringArray = text.split(" ", false)
			var pats: PackedStringArray = String(part["pat"]).split(" ", false)
			for b in mini(bars, roots.size()):
				var pat: String = pats[b % pats.size()]
				var root: int = _degree(roots[b], 0, scale)
				for i in pat.length():
					var c: String = pat[i]
					if c == ".":
						continue
					var hold: int = 1
					while i + hold < pat.length() and pat[i + hold] == ".":
						hold += 1
					var off: int = {"r": 0, "f": 7, "o": 12, "t": 3}.get(c, 0)
					_note(track, inst, base + root + off, origin + b * spb + i, hold, vol)
		"hits":
			var pats2: PackedStringArray = text.split(" ", false)
			for b in bars:
				var pat2: String = pats2[b % pats2.size()]
				for i in pat2.length():
					if HIT_VOL.has(pat2[i]):
						_hit(track, inst, origin + b * spb + i, vol * float(HIT_VOL[pat2[i]]))


## Scale degree token ("5", "#7,", "1'") to semitones above the tonic, shifted diatonically by `deg_shift`.
func _degree(tok: String, deg_shift: int, scale: Array) -> int:
	var acc: int = 0
	var i: int = 0
	if tok[0] == "#":
		acc = 1
		i = 1
	elif tok[0] == "b":
		acc = -1
		i = 1
	var idx: int = int(tok.substr(i, 1)) - 1 + deg_shift
	var octave: int = 0
	for c in tok.substr(i + 1):
		if c == "'":
			octave += 1
		elif c == ",":
			octave -= 1
	var oct_i: int = floori(float(idx) / 7.0)
	return int(scale[idx - oct_i * 7]) + 12 * (octave + oct_i) + acc


# ───────────────────────────── voices ─────────────────────────────

func _note(track: Dictionary, inst: String, midi: int, step: int, dur_steps: int, vol: float) -> void:
	var step_dur: float = track["step"]
	var dur: float = maxf(0.08, dur_steps * step_dur * 0.94)
	var key: String = "%s|%d|%d|%d" % [inst, midi, int(dur * 1000.0), int(step_dur * 1000.0)]
	if not _cache.has(key):
		_cache[key] = _render_tonal(inst, midi, dur)
	_add(_cache[key], int(round(step * step_dur * SR)), vol, float(INSTS[inst]["send"]))


func _hit(track: Dictionary, inst: String, step: int, vol: float) -> void:
	var key: String = "hit|" + inst
	if not _cache.has(key):
		_cache[key] = _render_tambori() if inst == "tambori" else _render_timbal()
	_add(_cache[key], int(round(step * float(track["step"]) * SR)), vol, 0.1)


## Adds `sig` into the circular loop buffers starting at sample `start`.
func _add(sig: PackedFloat32Array, start: int, gain: float, send: float) -> void:
	var size: int = _buf.size()
	var j: int = start % size
	for i in sig.size():
		var v: float = sig[i] * gain
		_buf[j] += v
		_send[j] += v * send
		j += 1
		if j >= size:
			j = 0


## One cycle of the reed spectrum for fundamental `f`: harmonics shaped by the instrument's formants.
func _table(p: Dictionary, f: float) -> PackedFloat32Array:
	var kmax: int = mini(48, int(SR * 0.45 / f))
	var amps := PackedFloat32Array()
	amps.resize(kmax + 1)
	var rolloff: float = p["rolloff"]
	for k in range(1, kmax + 1):
		var fr: float = f * k
		var g: float = p["floor"]
		for fm: Array in p["formants"]:
			var x: float = log(fr / float(fm[0])) / float(fm[1])
			g += float(fm[2]) * exp(-x * x)
		var a: float = pow(float(k), -rolloff) * g
		if k % 2 == 0:
			a *= float(p["even"])
		amps[k] = a
	var tab := PackedFloat32Array()
	tab.resize(TABLE + 1)
	var peak: float = 0.0001
	for t in TABLE:
		var s: float = 0.0
		for k in range(1, kmax + 1):
			s += amps[k] * sin(TAU * k * t / TABLE)
		tab[t] = s
		peak = maxf(peak, absf(s))
	for t in TABLE:
		tab[t] /= peak
	tab[TABLE] = tab[0]
	return tab


func _render_tonal(inst: String, midi: int, dur: float) -> PackedFloat32Array:
	var p: Dictionary = INSTS[inst]
	var f: float = 440.0 * pow(2.0, (midi - 69) / 12.0)
	var tab: PackedFloat32Array = _table(p, f)
	var rel: float = p["release"]
	var n: int = int((dur + rel) * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var inc: float = f * TABLE / SR
	var atk: float = p["attack"]
	var pluck: float = p["pluck"]
	var vib_depth: float = p["vib_depth"]
	var vib_rate: float = p["vib_rate"]
	var vib_delay: float = p["vib_delay"]
	var scoop: float = p["scoop"]
	var detune: float = 1.0 + float(p["detune"])
	var nz: float = p["noise"]
	var gain: float = p["gain"]
	var ph1: float = 0.0
	var ph2: float = float(TABLE) * 0.37
	var noff: int = midi * 311
	for i in n:
		var t: float = float(i) / SR
		var env: float = minf(1.0, t / atk)
		if pluck > 0.0:
			env *= exp(-t / pluck) * 0.85 + 0.15 * exp(-t / (pluck * 3.0))
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / rel)
		var bend: float = 1.0 - scoop * exp(-t / 0.03)
		if vib_depth > 0.0:
			bend *= 1.0 + vib_depth * sin(TAU * vib_rate * t) * clampf((t - vib_delay) / 0.25, 0.0, 1.0)
		var s: float = _lerp_tab(tab, ph1)
		ph1 += inc * bend
		if ph1 >= TABLE:
			ph1 -= TABLE
		if detune != 1.0:
			s = (s + 0.8 * _lerp_tab(tab, ph2)) / 1.8
			ph2 += inc * bend * detune
			if ph2 >= TABLE:
				ph2 -= TABLE
		var breath: float = _soft[(i + noff) & (NOISE_LEN - 1)] * nz
		if t < 0.04:
			breath *= 1.0 + 3.0 * (1.0 - t / 0.04)
		out[i] = (s + breath) * env * gain
	return out


func _lerp_tab(tab: PackedFloat32Array, ph: float) -> float:
	var i: int = int(ph)
	var fr: float = ph - i
	return tab[i] + (tab[i + 1] - tab[i]) * fr


## Tamborí: small snare-like drum, short and dry.
func _render_tambori() -> PackedFloat32Array:
	var n: int = int(0.2 * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph: float = 0.0
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / SR
		ph += TAU * (190.0 + 140.0 * exp(-t / 0.02)) / SR
		var w: float = _white[(i * 3 + 500) & (NOISE_LEN - 1)]
		lp += (w - lp) * 0.35
		out[i] = sin(ph) * exp(-t / 0.035) * 0.45 + (w - lp) * exp(-t / 0.045) * 0.55
	return out


## Timbal: big low drum of the castellers.
func _render_timbal() -> PackedFloat32Array:
	var n: int = int(0.7 * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph: float = 0.0
	for i in n:
		var t: float = float(i) / SR
		ph += TAU * (58.0 + 55.0 * exp(-t / 0.05)) / SR
		out[i] = (sin(ph) * exp(-t / 0.17) + 0.35 * sin(ph * 1.6) * exp(-t / 0.07)
				+ _soft[(i + 9000) & (NOISE_LEN - 1)] * exp(-t / 0.015) * 0.7) * 0.9
	return out


# ───────────────────────────── space and output ─────────────────────────────

## Adds a circular Schroeder reverb of the send bus (4 damped combs, 2 all-passes) to the loop.
## The send is tiled twice and the second copy is kept, so the tail wraps around seamlessly.
func _reverb(rt60: float) -> void:
	var n: int = _send.size()
	var size: int = 2 * n
	var tiled := PackedFloat32Array()
	tiled.append_array(_send)
	tiled.append_array(_send)
	var acc := PackedFloat32Array()
	acc.resize(size)
	for d: int in [1103, 1327, 1559, 1747]:
		var g: float = pow(0.001, float(d) / (rt60 * SR))
		var c := PackedFloat32Array()
		c.resize(size)
		var lp: float = 0.0
		for i in size:
			var y: float = tiled[i]
			if i >= d:
				y += g * c[i - d]
			lp += (y - lp) * 0.6
			c[i] = lp
			acc[i] += lp * 0.25
	for d: int in [225, 341]:
		var y2 := PackedFloat32Array()
		y2.resize(size)
		for i in size:
			var x: float = acc[i]
			if i >= d:
				y2[i] = -0.5 * x + acc[i - d] + 0.5 * y2[i - d]
			else:
				y2[i] = -0.5 * x
		acc = y2
	for i in n:
		_buf[i] += acc[n + i]


## Soft-limits and scales the loop to TARGET_RMS; returns the rms before the limiter.
func _master() -> float:
	var sum_sq: float = 0.0
	for v in _buf:
		sum_sq += v * v
	var rms: float = sqrt(sum_sq / maxf(1.0, _buf.size()))
	var k: float = TARGET_RMS / maxf(rms, 0.00001)
	for i in _buf.size():
		var v: float = _buf[i] * k
		var a: float = absf(v)
		if a > 0.5:
			v = signf(v) * (0.5 + 0.2 * tanh((a - 0.5) / 0.2))
		_buf[i] = v
	return TARGET_RMS


func _write(path: String, n: int) -> void:
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(round(clampf(_buf[i], -1.0, 1.0) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = bytes
	wav.save_to_wav(path)


## Music loops are looped by their import settings (forward loop, QOA compression), as sardana_de_ferro.
func _write_import(path: String) -> void:
	var imp: String = path + ".import"
	if FileAccess.file_exists(imp):
		return
	var f := FileAccess.open(imp, FileAccess.WRITE)
	f.store_string("[remap]\n\nimporter=\"wav\"\ntype=\"AudioStreamWAV\"\n\n[params]\n\n"
			+ "force/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\n"
			+ "edit/trim=false\nedit/normalize=false\nedit/loop_mode=2\nedit/loop_begin=0\nedit/loop_end=-1\n"
			+ "compress/mode=2\n")

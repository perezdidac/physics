## Original compositions of the story music, in a compact score notation read by tools/bake_music.gd.
## Melody tokens (space separated, "|" is only a bar mark): scale degree 1-7, optional "#"/"b" before it,
## "'" / "," after it for octave up / down, ":n" for n steps (default 1), "r" for a rest.
## Bass layers hold one chord root degree per bar (the part's `pat` says how it is played: r root, f fifth,
## o octave, t third, "." holds). Hit layers hold one pattern per bar (X accent, x normal, g ghost, "." rest).
## Every layer is a section; parts play the layer of the same name in every section that has it.
extends RefCounted

# ── menu: cobla sardana in G major, 6/8 (curts and llargs idiom) ──
const MENU_INTRO := "5,:2 1 3:2 5 | 1':3 7:2 5 | 6:2 5 4:2 3 | 2:3 5,:3"
const MENU_A := "5:3 3:2 4 | 5:3 1':3 | 6:2 5 4:2 3 | 2:3 5,:3 | 1:3 3:2 2 | 3:3 5:3 | 4:2 3 2:2 1 | 2:3 5,:3"
const MENU_A2 := "5:3 3:2 4 | 5:3 1':3 | 6:2 5 4:2 3 | 2:3 5,:3 | 1:3 3:2 2 | 3:3 5:3 | 4:2 3 2:2 7, | 1:6"
const MENU_B := "1':3 7:2 6 | 5:3 3:3 | 4:2 5 6:2 5 | 4:3 2:3 | 3:2 4 5:2 6 | 7:3 5:3 | 6:2 5 4:2 2 | 5:6"

# ── egg: soft flabiol lullaby, F major ──
const EGG_P := "1:3 3:3 | 5:3 3:2 1 | 2:3 4:3 | 3:6 | 5:3 3:3 | 6:3 5:2 3 | 4:2 3 2:2 1 | 1:6"
const EGG_Q := "3:3 5:3 | 6:3 5:3 | 4:3 6:3 | 5:6 | 5:2 4 3:2 2 | 3:3 1:3 | 2:2 3 4:2 2 | 1:6"

# ── larva (Pelussa): playful flabiol and tamborí, A mixolydian ──
const LARVA_1 := "1:2 2 3:2 1 | 5:3 3:3 | 4:2 5 6:2 4 | 5:3 5,:3 | 1:2 2 3:2 5 | 6:2 5 3:2 1 | 2:2 3 4:2 2 | 1:6"
const LARVA_2 := "5:2 6 5:2 3 | 4:2 5 4:2 2 | 3:2 4 3:2 1 | 2:3 5,:3 | 5:2 6 7:2 1' | 2':2 1' 7:2 5 | 6:2 5 4:2 2 | 5:6"

# ── cuca: lively sardana, D major ──
const CUCA_1 := "1:3 3:2 5 | 1':3 5:3 | 6:2 5 4:2 6 | 5:3 2:3 | 3:2 4 5:2 3 | 4:2 5 6:2 4 | 5:2 4 3:2 2 | 1:3 5,:3"
const CUCA_1X := "1:3 3:2 5 | 1':3 5:3 | 6:2 5 4:2 6 | 5:3 2:3 | 3:2 4 5:2 3 | 4:2 5 6:2 4 | 5:2 4 3:2 2 | 1:6"
const CUCA_2 := "3:2 3 5:2 3 | 4:2 4 6:2 4 | 5:2 5 7:2 5 | 1':6 | 7:2 6 5:2 4 | 3:2 4 5:2 3 | 2:2 3 4:2 2 | 5:6"

# ── nest (El Bolsó): slow winter tenora, A minor ──
const NEST_1 := "5:6 | 3:3 5:3 | 6:3 5:2 3 | 4:2 3 2:2 1 | 2:3 1:3 | #7,:3 1:3 | 2:3 3:2 2 | 1:6"
const NEST_2 := "6:3 5:3 | 3:3 1:3 | 2:3 3:3 | 5:6 | 6:3 5:2 6 | 1':3 6:3 | 5:3 #7,:3 | 1:6"

# ── procession: cercavila march, 2/4, E minor ──
const PROC_1 := "1:2 1 3 | 5:2 5 3 | 4:2 4 6 | 5:3 5, | 1:2 3 5 | 1':2 7 5 | 6:2 5 4 | 3:4"
const PROC_2 := "5:2 5 6 | #7:2 5 #7 | 1':2 1' 2' | 3':2 2' 1' | #7:2 6 5 | 6:2 5 4 | 5:2 4 3 | 2:4"

# ── pupa (Crisàlide): low and underground, E phrygian ──
const PUPA_1 := "1:6 | r:3 2:3 | 3:6 | 2:3 1:3 | 1:3 5:3 | 4:3 3:3 | 2:6 | 1:6"
const PUPA_2 := "5:6 | 4:3 2:3 | 1:6 | r:6 | 3:3 4:3 | 5:6 | 4:3 2:3 | 1:6"
const PUPA_DRIPS := "r:4 5':2 | r:6 | r:3 3':3 | r:6 | r:4 2':2 | r:6 | r:2 7:1 r:3 | r:6"
const PUPA_DRONE := "1,:12 6,:12 1,:12 2,:12"

# ── moth (Papallona): nocturnal tenora, D dorian ──
const MOTH_1 := "5:3 6:3 | 5:2 3 2:3 | 1:3 2:3 | 3:6 | 5:3 7:3 | 6:2 5 3:3 | 2:3 3:3 | 1:6"
const MOTH_2 := "1':3 7:3 | 6:3 5:3 | 3:2 4 5:3 | 6:6 | 7:3 6:3 | 5:3 3:3 | 4:3 2:3 | 1:6"
const MOTH_TWINKLE := "r:3 5':1 r:2 | r:6 | 3':1 r:5 | r:2 6':1 r:3 | r:6 | 5':1 r:2 3':1 r:2 | r:6 | 1':1 r:5"

# ── bosses: toc de castells style, 8 steps per bar ──
const BOSS_1 := "1:3 1 1:2 3 1 | 5:3 5 5:2 #7 5 | 1':3 7 6:2 5 3 | 4:4 3:2 2 1 | 1:3 1 1:2 3 1 | 5:3 5 5:2 6 #7 | 1':2 7 6 5:2 4 3 | 2:4 5,:4"
const BOSS_2 := "1':2 1' 1':2 7 6 5 | 5:2 5 5:2 4 3 2 | 4:2 4 4:2 5 6 #7 | 5:4 #7:4 | 1':2 1' 1':2 2' 3' 4' | 2':2 1' 7:2 6 5 4 | 6:2 5 4 3 2 1 #7, | 2:4 5,:4"
const BOSS_CHORDS_1 := "1 5 1 4 1 5 1 5"
const BOSS_CHORDS_2 := "1 5 4 5 1 5 4 5"


static func _sec(bars: int, layers: Dictionary) -> Dictionary:
	return {"bars": bars, "layers": layers}


static func _part(inst: String, layer: String, kind: String, vol: float, extra: Dictionary = {}) -> Dictionary:
	var p: Dictionary = {"inst": inst, "layer": layer, "kind": kind, "vol": vol}
	p.merge(extra)
	return p


## Music file name (without extension) -> track dictionary, in the order they are baked.
static func all_tracks() -> Dictionary:
	var out: Dictionary = {"menu": menu(), "egg": egg(), "larva": larva(), "cuca": cuca(), "nest": nest(),
			"procession": procession(), "pupa": pupa(), "moth": moth()}
	for variant: String in BOSS_VARIANTS:
		out["boss_" + variant] = boss(variant)
	return out


static func menu() -> Dictionary:
	var calm: Dictionary = {"tam": "X.gX.g"}
	var lively: Dictionary = {"tam": "XgxXgx"}
	var intro: Dictionary = {"fl": MENU_INTRO, "bass": "1 1 4 5"}
	intro.merge(calm)
	return {"tonic": 67, "mode": "major", "step": 0.18, "spb": 6,
		"sections": [
			_sec(4, intro),
			_sec(8, {"mel": MENU_A, "bass": "1 1 4 1 1 1 5 5"}.merged(lively)),
			_sec(8, {"mel": MENU_A2, "bass": "1 1 4 1 1 1 5 1"}.merged(lively)),
			_sec(8, {"mel": MENU_B, "bass": "1 1 4 4 6 5 4 5"}.merged(lively)),
			_sec(8, {"mel": MENU_B, "fl": MENU_B, "bass": "1 1 4 4 6 5 4 5"}.merged(lively)),
			_sec(8, {"mel": MENU_A2, "bass": "1 1 4 1 1 1 5 1"}.merged(lively)),
		],
		"parts": [
			_part("tible", "mel", "notes", 0.55, {"shift": 12}),
			_part("tenora", "mel", "notes", 0.4, {"deg": -2}),
			_part("flabiol", "fl", "notes", 0.5, {"shift": 12}),
			_part("contrabaix", "bass", "bass", 0.6, {"shift": -24, "pat": "r..f.."}),
			_part("tambori", "tam", "hits", 0.5),
		]}


static func egg() -> Dictionary:
	var pc: String = "1 1 5 1 1 6 5 1"
	var qc: String = "1 6 4 5 1 1 5 1"
	return {"tonic": 65, "mode": "major", "step": 0.26, "spb": 6, "reverb": 1.8,
		"sections": [
			_sec(8, {"fl": EGG_P, "bass": pc, "beat": "X.....  ......"}),
			_sec(8, {"fl": EGG_Q, "fl2": EGG_Q, "bass": qc, "beat": "X.....  ......"}),
			_sec(8, {"fl": EGG_P, "fl2": EGG_P, "bass": pc, "beat": "X.....  ......"}),
			_sec(8, {"fl": EGG_Q, "fl2": EGG_Q, "bass": qc, "beat": "X.....  ......"}),
		],
		"parts": [
			_part("flabiol", "fl", "notes", 0.55, {"shift": 12}),
			_part("flabiol", "fl2", "notes", 0.3, {"shift": 12, "deg": 2}),
			_part("contrabaix", "bass", "bass", 0.3, {"shift": -24, "pat": "r..... ...f.."}),
			_part("timbal", "beat", "hits", 0.18),
		]}


static func larva() -> Dictionary:
	var c1: String = "1 1 4 5 1 1 5 1"
	var c2: String = "1 4 1 5 1 5 4 5"
	var tam: String = "XgxXgx"
	return {"tonic": 69, "mode": "mixolydian", "step": 0.19, "spb": 6,
		"sections": [
			_sec(8, {"fl": LARVA_1, "bass": c1, "tam": tam}),
			_sec(8, {"fl": LARVA_2, "fl2": LARVA_2, "bass": c2, "tam": tam}),
			_sec(8, {"fl": LARVA_1, "fl2": LARVA_1, "bass": c1, "tam": tam}),
			_sec(8, {"fl": LARVA_2, "fl2": LARVA_2, "bass": c2, "tam": tam + " " + tam + " " + tam + " XxXxXx"}),
			_sec(8, {"fl": LARVA_1, "fl2": LARVA_1, "bass": c1, "tam": tam}),
		],
		"parts": [
			_part("flabiol", "fl", "notes", 0.6, {"shift": 12}),
			_part("flabiol", "fl2", "notes", 0.3, {"shift": 12, "deg": 2}),
			_part("contrabaix", "bass", "bass", 0.35, {"shift": -24, "pat": "r..f.."}),
			_part("tambori", "tam", "hits", 0.55),
		]}


static func cuca() -> Dictionary:
	var c1: String = "1 1 4 5 1 4 5 1"
	var c2: String = "1 4 5 1 5 1 5 5"
	var tam: String = "XgxXgx"
	return {"tonic": 62, "mode": "major", "step": 0.16, "spb": 6,
		"sections": [
			_sec(8, {"mel": CUCA_1, "bass": c1, "tam": tam}),
			_sec(8, {"mel": CUCA_1X, "bass": c1, "tam": tam}),
			_sec(8, {"mel": CUCA_2, "fl": CUCA_2, "bass": c2, "tam": tam}),
			_sec(8, {"mel": CUCA_1, "fl": CUCA_1, "bass": c1, "tam": tam}),
			_sec(8, {"mel": CUCA_1X, "fl": CUCA_1X, "bass": c1, "tam": tam}),
			_sec(8, {"mel": CUCA_2, "fl": CUCA_2, "bass": c2, "tam": tam + " " + tam + " " + tam + " XxXxXx"}),
		],
		"parts": [
			_part("tible", "mel", "notes", 0.55, {"shift": 12}),
			_part("tenora", "mel", "notes", 0.4, {"deg": -2}),
			_part("flabiol", "fl", "notes", 0.4, {"shift": 24}),
			_part("contrabaix", "bass", "bass", 0.6, {"shift": -24, "pat": "r..f.."}),
			_part("tambori", "tam", "hits", 0.5),
		]}


static func nest() -> Dictionary:
	var c1: String = "1 1 6 4 5 1 5 1"
	var c2: String = "6 1 5 1 6 4 5 1"
	var beat: String = "X..... ...x.."
	return {"tonic": 57, "mode": "minor", "step": 0.3, "spb": 6, "reverb": 2.4,
		"sections": [
			_sec(8, {"mel": NEST_1, "bass": c1}),
			_sec(8, {"mel": NEST_2, "bass": c2, "fl": NEST_2}),
			_sec(8, {"mel": NEST_1, "bass": c1, "beat": beat}),
			_sec(8, {"mel": NEST_2, "bass": c2, "fl": NEST_2, "beat": beat}),
		],
		"parts": [
			_part("tenora", "mel", "notes", 0.7, {"shift": 12}),
			_part("tenora", "mel", "notes", 0.3, {"shift": 12, "deg": -2}),
			_part("flabiol", "fl", "notes", 0.2, {"shift": 24}),
			_part("contrabaix", "bass", "bass", 0.4, {"shift": -24, "pat": "r..... ...f.."}),
			_part("timbal", "beat", "hits", 0.15),
		]}


static func procession() -> Dictionary:
	var c1: String = "1 1 4 1 1 1 4 5"
	var c2: String = "1 5 1 1 5 4 1 5"
	var tim: String = "X.xx"
	var tam: String = "xgxg"
	return {"tonic": 64, "mode": "minor", "step": 0.25, "spb": 4,
		"sections": [
			_sec(8, {"mel": PROC_1, "bass": c1, "tim": tim}),
			_sec(8, {"mel": PROC_2, "bass": c2, "tim": tim}),
			_sec(8, {"mel": PROC_1, "top": PROC_1, "bass": c1, "tim": tim, "tam": tam}),
			_sec(8, {"mel": PROC_2, "top": PROC_2, "bass": c2, "tim": tim, "tam": tam}),
			_sec(8, {"mel": PROC_1, "top": PROC_1, "bass": c1, "tim": tim, "tam": tam}),
			_sec(8, {"mel": PROC_2, "top": PROC_2, "bass": c2, "tim": tim + " " + tim + " " + tim + " XxXx", "tam": tam}),
		],
		"parts": [
			_part("gralla", "mel", "notes", 0.6),
			_part("gralla", "mel", "notes", 0.4, {"deg": -2}),
			_part("tible", "top", "notes", 0.35, {"shift": 12}),
			_part("contrabaix", "bass", "bass", 0.6, {"shift": -24, "pat": "r.f."}),
			_part("timbal", "tim", "hits", 0.7),
			_part("tambori", "tam", "hits", 0.45),
		]}


static func pupa() -> Dictionary:
	var c1: String = "1 1 1 1 1 1 1 1"
	var beat: String = "X..x.."
	return {"tonic": 52, "mode": "phrygian", "step": 0.32, "spb": 6, "reverb": 2.6,
		"sections": [
			_sec(8, {"mel": PUPA_1, "drone": PUPA_DRONE, "bass": c1, "beat": beat}),
			_sec(8, {"mel": PUPA_2, "drone": PUPA_DRONE, "bass": c1, "beat": beat}),
			_sec(8, {"mel": PUPA_1, "drone": PUPA_DRONE, "bass": c1, "beat": beat, "fl": PUPA_DRIPS}),
		],
		"parts": [
			_part("tenora", "mel", "notes", 0.6),
			_part("tenora", "drone", "notes", 0.35),
			_part("flabiol", "fl", "notes", 0.25, {"shift": 12}),
			_part("contrabaix", "bass", "bass", 0.5, {"shift": -24, "pat": "r....."}),
			_part("timbal", "beat", "hits", 0.3),
		]}


static func moth() -> Dictionary:
	var c1: String = "1 1 4 1 5 6 5 1"
	var c2: String = "6 4 5 6 5 1 4 1"
	return {"tonic": 62, "mode": "dorian", "step": 0.24, "spb": 6, "reverb": 2.2,
		"sections": [
			_sec(8, {"mel": MOTH_1, "bass": c1}),
			_sec(8, {"mel": MOTH_2, "bass": c2, "tw": MOTH_TWINKLE}),
			_sec(8, {"mel": MOTH_1, "bass": c1, "tw": MOTH_TWINKLE, "beat": "X..x.. ......"}),
			_sec(8, {"mel": MOTH_2, "bass": c2, "tw": MOTH_TWINKLE, "beat": "X..x.. ......"}),
		],
		"parts": [
			_part("tenora", "mel", "notes", 0.7, {"shift": 12}),
			_part("tenora", "mel", "notes", 0.25, {"deg": -2}),
			_part("flabiol", "tw", "notes", 0.35, {"shift": 24}),
			_part("contrabaix", "bass", "bass", 0.4, {"shift": -24, "pat": "r..... ...f.."}),
			_part("timbal", "beat", "hits", 0.12),
		]}


## Boss variants share the toc melodies: key, mode, tempo, voices and an optional animal call differ.
## lead / harm: reed of the main line and of its parallel third; top: octave doubling in the repeats;
## call: 8-bar layer string played by the call voice in every section.
const BOSS_VARIANTS: Array[String] = ["wasp", "fly", "tit", "brigade", "cuckoo", "hoopoe", "bat"]
const BOSS_SETUP: Dictionary = {
	"wasp": {"tonic": 69, "mode": "minor", "step": 0.115, "lead": "tible", "harm": "gralla", "top": "tible",
		"top_shift": 12, "tim_vol": 0.6, "call": "", "call_inst": "", "call_shift": 0, "mel_shift": 0},
	"fly": {"tonic": 62, "mode": "harmonic", "step": 0.14, "lead": "gralla", "harm": "tenora", "top": "tible",
		"top_shift": 12, "tim_vol": 0.9, "call": "", "call_inst": "", "call_shift": 0, "mel_shift": 0},
	"tit": {"tonic": 64, "mode": "dorian", "step": 0.125, "lead": "gralla", "harm": "tible", "top": "flabiol",
		"top_shift": 24, "tim_vol": 0.6, "call": "", "call_inst": "", "call_shift": 0, "mel_shift": 0},
	"brigade": {"tonic": 60, "mode": "minor", "step": 0.16, "lead": "gralla", "harm": "gralla", "top": "tenora",
		"top_shift": 0, "tim_vol": 1.0, "call": "", "call_inst": "", "call_shift": 0, "mel_shift": 0},
	"cuckoo": {"tonic": 67, "mode": "dorian", "step": 0.135, "lead": "gralla", "harm": "tenora", "top": "tible",
		"top_shift": 12, "tim_vol": 0.7, "call_inst": "flabiol", "call_shift": 24, "mel_shift": 0,
		"call": "r:2 5':1 3':2 r:3 r:8 r:2 5':1 3':2 r:3 r:8 r:2 5':1 3':2 r:3 r:8 r:2 5':1 3':2 r:3 r:8"},
	"hoopoe": {"tonic": 66, "mode": "harmonic", "step": 0.13, "lead": "gralla", "harm": "tenora", "top": "tible",
		"top_shift": 12, "tim_vol": 0.8, "call_inst": "tenora", "call_shift": -12, "mel_shift": 0,
		"call": "1,:1 r:1 1,:1 r:1 1,:1 r:3 r:8 1,:1 r:1 1,:1 r:1 1,:1 r:3 r:8 1,:1 r:1 1,:1 r:1 1,:1 r:3 r:8 1,:1 r:1 1,:1 r:1 1,:1 r:3 r:8"},
	"bat": {"tonic": 58, "mode": "phrygian", "step": 0.12, "lead": "tible", "harm": "gralla", "top": "tible",
		"top_shift": 12, "tim_vol": 0.7, "call_inst": "flabiol", "call_shift": 24, "mel_shift": -12,
		"call": "r:5 7':1 6':1 7':1 r:8 r:5 6':1 5':1 6':1 r:8 r:5 7':1 6':1 7':1 r:8 r:5 6':1 5':1 6':1 r:8"},
}


static func boss(variant: String) -> Dictionary:
	var v: Dictionary = BOSS_SETUP[variant]
	var tim: String = "X.x.X.xx X.x.X.xx X.x.X.xx XxXxXxXx"
	var tam: String = "xxgxxxgx"
	var plain: Dictionary = {"tim": tim, "tam": tam}
	var layers: Array[Dictionary] = [
		{"mel": BOSS_1, "bass": BOSS_CHORDS_1},
		{"mel": BOSS_1, "h": BOSS_1, "bass": BOSS_CHORDS_1},
		{"mel": BOSS_2, "bass": BOSS_CHORDS_2},
		{"mel": BOSS_2, "h": BOSS_2, "top": BOSS_2, "bass": BOSS_CHORDS_2},
		{"mel": BOSS_1, "h": BOSS_1, "top": BOSS_1, "bass": BOSS_CHORDS_1},
		{"mel": BOSS_2, "h": BOSS_2, "top": BOSS_2, "bass": BOSS_CHORDS_2},
	]
	var sections: Array[Dictionary] = []
	for l in layers:
		var d: Dictionary = l.merged(plain)
		if String(v["call"]) != "":
			d["call"] = v["call"]
		sections.append(_sec(8, d))
	var parts: Array[Dictionary] = [
		_part(v["lead"], "mel", "notes", 0.6, {"shift": v["mel_shift"]}),
		_part(v["harm"], "h", "notes", 0.4, {"deg": -2, "shift": v["mel_shift"]}),
		_part(v["top"], "top", "notes", 0.3, {"shift": v["top_shift"]}),
		_part("contrabaix", "bass", "bass", 0.7, {"shift": -24, "pat": "r.rr.rf."}),
		_part("timbal", "tim", "hits", float(v["tim_vol"])),
		_part("tambori", "tam", "hits", 0.4),
	]
	if String(v["call"]) != "":
		parts.append(_part(v["call_inst"], "call", "notes", 0.5, {"shift": v["call_shift"]}))
	return {"tonic": v["tonic"], "mode": v["mode"], "step": v["step"], "spb": 8, "reverb": 1.1,
		"sections": sections, "parts": parts}

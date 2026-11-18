## Noise port: values must match the JS functions of world.js (reference values computed with node).
##   godot --headless --path . res://tests/TestSimNoise.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _near(a: float, b: float, label: String) -> void:
	_check(absf(a - b) < 1e-9, "%s = %.12f (JS %.12f)" % [label, a, b])


func _ready() -> void:
	var p: PackedByteArray = SimNoise.perm
	_check(p.size() == 512, "perm has 512 entries")
	_check(p[0] == 125 and p[1] == 156 and p[2] == 206 and p[3] == 175 and p[4] == 46 and p[11] == 79, "perm starts like the JS table")
	_check(p[255] == 61 and p[256] == 125 and p[511] == 61, "perm wraps at 256")
	_near(SimNoise.noise2d(0.5, 0.5), 0.375, "noise2d(0.5, 0.5)")
	_near(SimNoise.noise2d(1.3, 2.7), -0.029231439519999958, "noise2d(1.3, 2.7)")
	_near(SimNoise.noise2d(-3.2, 7.9), 0.69858838015999969, "noise2d(-3.2, 7.9)")
	_near(SimNoise.noise2d(123.456, 78.9), -0.032847167901620344, "noise2d(123.456, 78.9)")
	_near(SimNoise.noise2d(255.9, 0.1), 0.34919529152000406, "noise2d(255.9, 0.1)")
	_near(SimNoise.noise2d(1000.25, -45.5), 0.13366699218750000, "noise2d(1000.25, -45.5)")
	_near(SimNoise.noise2d(0.0, 0.0), 0.5, "noise2d(0, 0)")
	_near(SimNoise.noise2d(17.75, -0.3), 0.51438093945312502, "noise2d(17.75, -0.3)")
	_near(SimNoise.noise2d(3.14159, 2.71828), 0.41034468640860122, "noise2d(3.14159, 2.71828)")
	_near(SimNoise.fbm(1.3, 2.7, 4), 0.092348126711384079, "fbm(1.3, 2.7, 4)")
	_near(SimNoise.fbm(100.5, 50.25, 3), 0.14707383100491972, "fbm(100.5, 50.25, 3)")
	_near(SimNoise.fbm(5.5, 3.3), 0.60432523115609027, "fbm(5.5, 3.3) default octaves")
	_near(SimNoise.fbm(-7.7, 12.1, 3), 0.32147801906056095, "fbm(-7.7, 12.1, 3)")
	_near(SimNoise.ridged_fbm(0.3, 0.7, 3), 0.34388470844870184, "ridged_fbm(0.3, 0.7, 3)")
	_near(SimNoise.ridged_fbm(12.5, 7.5), 0.046830517101240914, "ridged_fbm(12.5, 7.5) default octaves")
	_near(SimNoise.ridged_fbm(-4.4, 9.9, 2), 0.066439067548706807, "ridged_fbm(-4.4, 9.9, 2)")
	_near(SimNoise.ridged_fbm(300.1, 200.2, 3), 0.25070179775144041, "ridged_fbm(300.1, 200.2, 3)")

	# The proven range used by the optimisations must hold on a dense sample.
	var lo: float = 10.0
	var hi: float = -10.0
	for i in 20000:
		var v: float = SimNoise.noise2d(i * 0.7371, i * 1.1131)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	_check(lo >= SimNoise.NOISE_MIN and hi <= SimNoise.NOISE_MAX, "noise stays inside NOISE_MIN..NOISE_MAX (%.3f..%.3f)" % [lo, hi])

	# SimMath JS semantics
	_check(SimMath.clamp_js(NAN, 1.0, 5.0) == 1.0 and SimMath.clamp_js(INF, 1.0, 5.0) == 1.0, "clamp_js returns lo for NaN/INF")
	_check(SimMath.clamp_js(9.0, 1.0, 5.0) == 5.0 and SimMath.clamp_js(-9.0, 1.0, 5.0) == 1.0, "clamp_js clamps")
	_check(SimMath.round_js(2.5) == 3.0 and SimMath.round_js(-2.5) == -2.0 and SimMath.round_js(-0.4) == 0.0, "round_js ties go up")
	_check(SimMath.sign_js(0.0) == 0.0 and SimMath.sign_js(-3.0) == -1.0 and SimMath.sign_js(0.1) == 1.0, "sign_js(0) == 0")
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()

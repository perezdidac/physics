## Numeric helpers that reproduce JavaScript number semantics (see port_contracts.md section 0).
class_name SimMath
extends RefCounted


## JS `clamp()` of world.js: returns `lo` when `v` is NaN or infinite (GDScript clampf does not).
static func clamp_js(v: float, lo: float, hi: float) -> float:
	if is_nan(v) or is_inf(v):
		return lo
	return maxf(lo, minf(hi, v))


## JS `Math.round`: ties go up (toward +infinity).
static func round_js(x: float) -> float:
	return floorf(x + 0.5)


## JS `Math.sign`: 0 for 0.
static func sign_js(x: float) -> float:
	if x > 0.0:
		return 1.0
	if x < 0.0:
		return -1.0
	return 0.0


## Uniform random in [0, 1) like Math.random() (RandomNumberGenerator.randf() can return exactly 1.0).
static func rand01(rng: RandomNumberGenerator) -> float:
	var v: float = rng.randf()
	return v if v < 1.0 else 0.99999994

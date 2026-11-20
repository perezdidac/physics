## Port of the JS value noise (world.js noise2D / fbm / ridgedFbm) used by the view: ridges, the terrain
## overlay painter and the permutation table handed to the terrain shader. Same seed, same numbers as the original.
class_name ViewNoise
extends RefCounted

## 512-entry permutation table (PERM[i] = p[i & 255]).
static var _perm: PackedInt32Array = PackedInt32Array()


## Builds (once) and returns the permutation table.
static func perm() -> PackedInt32Array:
	if _perm.size() == 512:
		return _perm
	var p := PackedInt32Array()
	p.resize(256)
	for i in 256:
		p[i] = i
	var seed_v: int = 4219
	for i in range(255, 0, -1):
		seed_v = (seed_v * 16807) % 2147483647
		var j: int = seed_v % (i + 1)
		var t: int = p[i]
		p[i] = p[j]
		p[j] = t
	_perm.resize(512)
	for i in 512:
		_perm[i] = p[i & 255]
	return _perm


## The 256 base values as an Image (256x1, R8) for the terrain shader.
static func perm_image() -> Image:
	var pm: PackedInt32Array = perm()
	var data := PackedByteArray()
	data.resize(256)
	for i in 256:
		data[i] = pm[i]
	return Image.create_from_data(256, 1, false, Image.FORMAT_R8, data)


static func _fade(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _grad2(hash_v: int, x: float, y: float) -> float:
	var h: int = hash_v & 7
	var u: float = x if h < 4 else y
	var v: float = y if h < 4 else x
	return (-u if (h & 1) != 0 else u) + (-2.0 * v if (h & 2) != 0 else 2.0 * v)


## JS noise2D: roughly 0..1.
static func noise2d(px: float, py: float) -> float:
	var pm: PackedInt32Array = perm()
	var fx: float = floorf(px)
	var fy: float = floorf(py)
	var xi: int = int(fx) & 255
	var yi: int = int(fy) & 255
	var x: float = px - fx
	var y: float = py - fy
	var u: float = _fade(x)
	var v: float = _fade(y)
	var a: int = pm[xi] + yi
	var b: int = pm[xi + 1] + yi
	var l1: float = lerpf(_grad2(pm[a], x, y), _grad2(pm[b], x - 1.0, y), u)
	var l2: float = lerpf(_grad2(pm[a + 1], x, y - 1.0), _grad2(pm[b + 1], x - 1.0, y - 1.0), u)
	return lerpf(l1, l2, v) * 0.5 + 0.5


## JS fbm.
static func fbm(x: float, y: float, octaves: int = 5) -> float:
	var val: float = 0.0
	var amp: float = 0.5
	var freq: float = 1.0
	var mx: float = 0.0
	for i in octaves:
		val += noise2d(x * freq, y * freq) * amp
		mx += amp
		freq *= 2.04
		amp *= 0.5
	return val / mx


## JS ridgedFbm.
static func ridged_fbm(x: float, y: float, octaves: int = 5) -> float:
	var val: float = 0.0
	var amp: float = 0.5
	var freq: float = 1.0
	var weight: float = 1.0
	var mx: float = 0.0
	for i in octaves:
		var n: float = 1.0 - absf(noise2d(x * freq, y * freq) * 2.0 - 1.0)
		n = n * n * weight
		weight = clampf(n * 2.0, 0.0, 1.0)
		val += n * amp
		mx += amp
		freq *= 2.12
		amp *= 0.5
	return val / mx

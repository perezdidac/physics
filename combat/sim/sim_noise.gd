## Faithful port of the Perlin-like noise of world.js (PERM table, noise2D, fbm, ridgedFbm).
class_name SimNoise
extends RefCounted

## Proven range of noise2d() over the whole periodic lattice (measured: -0.2517 .. 1.2517, plus margin).
const NOISE_MIN: float = -0.27
const NOISE_MAX: float = 1.27

## The 512-entry permutation table (also uploaded to the terrain shader by the view).
static var perm: PackedByteArray = _build_perm()
## Gradient tables: grad2(hash) == GX[hash & 7] * x + GY[hash & 7] * y.
static var _gx: PackedFloat32Array = PackedFloat32Array([1.0, -1.0, 1.0, -1.0, 2.0, 2.0, -2.0, -2.0])
static var _gy: PackedFloat32Array = PackedFloat32Array([2.0, 2.0, -2.0, -2.0, 1.0, -1.0, 1.0, -1.0])


static func _build_perm() -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(256)
	for i in 256:
		p[i] = i
	var s: int = 4219
	for i in range(255, 0, -1):
		s = (s * 16807) % 2147483647
		var j: int = s % (i + 1)
		var t: int = p[i]
		p[i] = p[j]
		p[j] = t
	var out := PackedByteArray()
	out.resize(512)
	for i in 512:
		out[i] = p[i & 255]
	return out


## 2D gradient noise, roughly 0..1 (may slightly exceed it, like the JS).
static func noise2d(x: float, y: float) -> float:
	var flx: float = floorf(x)
	var fly: float = floorf(y)
	var xi: int = int(flx) & 255
	var yi: int = int(fly) & 255
	var xf: float = x - flx
	var yf: float = y - fly
	var u: float = xf * xf * xf * (xf * (xf * 6.0 - 15.0) + 10.0)
	var v: float = yf * yf * yf * (yf * (yf * 6.0 - 15.0) + 10.0)
	var a: int = perm[xi] + yi
	var b: int = perm[xi + 1] + yi
	var ha: int = perm[a] & 7
	var hb: int = perm[b] & 7
	var ha1: int = perm[a + 1] & 7
	var hb1: int = perm[b + 1] & 7
	var g00: float = _gx[ha] * xf + _gy[ha] * yf
	var g10: float = _gx[hb] * (xf - 1.0) + _gy[hb] * yf
	var g01: float = _gx[ha1] * xf + _gy[ha1] * (yf - 1.0)
	var g11: float = _gx[hb1] * (xf - 1.0) + _gy[hb1] * (yf - 1.0)
	var l0: float = g00 + u * (g10 - g00)
	var l1: float = g01 + u * (g11 - g01)
	return (l0 + v * (l1 - l0)) * 0.5 + 0.5


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


static func ridged_fbm(x: float, y: float, octaves: int = 5) -> float:
	var val: float = 0.0
	var amp: float = 0.5
	var freq: float = 1.0
	var weight: float = 1.0
	var mx: float = 0.0
	for i in octaves:
		var n: float = 1.0 - absf(noise2d(x * freq, y * freq) * 2.0 - 1.0)
		n = n * n * weight
		weight = SimMath.clamp_js(n * 2.0, 0.0, 1.0)
		val += n * amp
		mx += amp
		freq *= 2.12
		amp *= 0.5
	return val / mx

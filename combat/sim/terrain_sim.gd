## Destructible terrain: collision mask, procedural generation (mask only, no colours), queries and edits.
## The view paints the colours from `stamps`, `surface_y`, the noise table and the match colour shifts.
class_name TerrainSim
extends RefCounted

## Emitted after carve_crater / build_girder so the view can update its mask texture region.
signal terrain_changed(rect: Rect2i)

const W: int = 3200
const H: int = 820
## R8 colour that stores the byte 1 (0.004 * 255 = 1.02, truncated to 1).
## Width and height (px) of the anthill mound.
const ANTHILL_W: int = 72
const ANTHILL_HALF: int = 36
const ANTHILL_H: int = 24
## Height (px) of the rock a ramp removes above its line.
const _RAMP_CLEAR: int = 150
const _SOLID: Color = Color(0.004, 0.0, 0.0, 1.0)

## Largest and smallest jitter of carve_crater (derived from the proven noise range).
const _JIT_MAX: float = (SimNoise.NOISE_MAX - 0.5) * 4.5
const _JIT_MIN: float = (SimNoise.NOISE_MIN - 0.5) * 4.5
## Cavern ellipse threshold bounds: 0.88 + 0.32 * noise range.
const _CAV_LO: float = 0.88 + 0.32 * SimNoise.NOISE_MIN
const _CAV_HI: float = 0.88 + 0.32 * SimNoise.NOISE_MAX

## Carried between matches like the JS global `mapSeed` (used when the match seed is 0).
static var _carried_map_seed: float = 2.4

## 1 = solid, index y * W + x.
var mask: PackedByteArray = PackedByteArray()
## What the last terrain_changed was: "carve" or "build". The view reads it (and the two fields below) when the signal arrives.
var last_change_kind: String = ""
## Last carve_crater call: {x, y, r} (the exact centre and radius, for the permanent scorch).
var last_carve: Dictionary = {}
## Last build_girder call: {rect: Rect2i, added: PackedByteArray}; `added` is rect-sized, 1 where a pixel turned from air to solid.
var last_build: Dictionary = {}
## Every rectangle ever announced with terrain_changed, in order (SimNav reads the new entries to refresh its walking map).
var edit_log: Array[Rect2i] = []
var water_y: float = 700.0
var map: MapDef
var archetype_id: String = ""
var archetype_key: String = ""
var texture_style: String = "STRATA_WAVES"
var map_seed: float = 2.4
## [{tx, crown_y}] of generated trees (silk nest anchors).
var tree_spots: Array[Dictionary] = []
var valley_spots: Array[int] = []
## Every stamped structure in paint order: {kind, x, y, w, h, style, ...} (see the _stamp_* functions).
var stamps: Array[Dictionary] = []
## Height profile (float32 like the JS Float32Array); 900 outside the island.
var surface_y: PackedFloat32Array = PackedFloat32Array()
## Caverns carved under the surface: [{cx, cy, rx, ry}].
var caverns: Array[Dictionary] = []
## Per-match colour harmony (0..255 values) used by the view shader.
var match_turf: Vector3 = Vector3.ZERO
var match_soil: Vector3 = Vector3.ZERO
var match_rock: Vector3 = Vector3.ZERO

var _rng: RandomNumberGenerator
## Playable span (world x) of the match. The whole terrain for classic matches; a story level with `arena_width` removes the land outside it.
var arena_x0: float = 0.0
var arena_x1: float = float(W)


func _init() -> void:
	mask.resize(W * H)


## The 512-entry noise permutation table (for the view shader).
func noise_perm() -> PackedByteArray:
	return SimNoise.perm


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## True when the pixel under (x, y) is solid; false outside the 3200x820 area.
func is_solid(x: float, y: float) -> bool:
	var ix: int = int(floorf(x))
	var iy: int = int(floorf(y))
	if ix < 0 or ix >= W or iy < 0 or iy >= H:
		return false
	return mask[iy * W + ix] == 1


## Direction pointing away from the solid mass around (x, y): 11x11 kernel like the JS.
func surface_normal(x: float, y: float) -> Vector2:
	var cx: int = int(floorf(x))
	var cy: int = int(floorf(y))
	var nx: int = 0
	var ny: int = 0
	for dy in range(-5, 6):
		var iy: int = cy + dy
		if iy < 0 or iy >= H:
			continue
		var row: int = iy * W
		for dx in range(-5, 6):
			var ix: int = cx + dx
			if ix < 0 or ix >= W or (dx == 0 and dy == 0):
				continue
			if mask[row + ix] == 1:
				nx -= dx
				ny -= dy
	var len_sq: float = float(nx * nx + ny * ny)
	if len_sq < 1e-8:
		return Vector2(0.0, -1.0)
	var ln: float = sqrt(len_sq)
	return Vector2(nx / ln, ny / ln)


## First solid y in column x scanning down from start_y; H + 100 when none.
func find_surface_y(x: float, start_y: float = 40.0) -> float:
	var ix: int = int(SimMath.clamp_js(floorf(x), 0.0, float(W - 1)))
	for y in range(maxi(0, int(floorf(start_y))), H):
		if mask[y * W + ix] == 1:
			return float(y)
	return float(H + 100)


## All walkable tiers of column x (first solid cell under a 26+ px air gap), top tier first.
func find_all_walkable_surfaces_at_x(x: float) -> PackedInt32Array:
	var ix: int = int(SimMath.clamp_js(floorf(x), 0.0, float(W - 1)))
	var surfaces := PackedInt32Array()
	var air_run: int = 0
	var y_end: int = int(ceilf(water_y - 22.0))
	for y in range(36, y_end):
		if mask[y * W + ix] == 0:
			air_run += 1
		else:
			if air_run >= 26:
				surfaces.append(y)
			air_run = 0
	return surfaces


## Closest to an arena edge (px) that placement margins shrink to when the arena is narrower than the terrain.
const ARENA_MIN_MARGIN: float = 110.0


## True when the playable span is narrower than the terrain.
func is_clipped() -> bool:
	return arena_x0 > 0.0 or arena_x1 < float(W)


## Width of the playable span.
func arena_width() -> float:
	return arena_x1 - arena_x0


## World x at `frac` (0..1) of the playable span.
func arena_at(frac: float) -> float:
	return arena_x0 + (arena_x1 - arena_x0) * frac


## x clamped to the playable span, keeping `margin` px from its edges (the margin shrinks to ARENA_MIN_MARGIN in a clipped arena).
## For the whole terrain this is clampf(x, margin, W - margin).
func clamp_x(x: float, margin: float) -> float:
	var m: float = edge_margin(margin)
	return clampf(x, arena_x0 + m, arena_x1 - m)


## The placement margin `margin` of the whole terrain, shrunk in a clipped arena.
func edge_margin(margin: float) -> float:
	return minf(margin, ARENA_MIN_MARGIN) if is_clipped() else margin


## x clamped to the playable span with an exact `margin` (movement limits of fighters).
func clamp_hard(x: float, margin: float) -> float:
	return clampf(x, arena_x0 + margin, arena_x1 - margin)


## Restricts the match to the span [x0, x1]: the land outside it is removed (down to the water and the void, nobody can stand there),
## and the tree and valley spots outside are dropped. Call right after generate(), before anything is placed.
func set_arena(x0: float, x1: float) -> void:
	arena_x0 = clampf(x0, 0.0, float(W))
	arena_x1 = clampf(x1, arena_x0, float(W))
	for y in H:
		var row: int = y * W
		for x in range(0, int(ceilf(arena_x0))):
			mask[row + x] = 0
		for x in range(int(floorf(arena_x1)), W):
			mask[row + x] = 0
	var trees: Array[Dictionary] = []
	for t in tree_spots:
		if float(t["tx"]) >= arena_x0 and float(t["tx"]) <= arena_x1:
			trees.append(t)
	tree_spots = trees
	var valleys: Array[int] = []
	for v in valley_spots:
		if float(v) >= arena_x0 and float(v) <= arena_x1:
			valleys.append(v)
	valley_spots = valleys


# ---------------------------------------------------------------------------
# Edits
# ---------------------------------------------------------------------------

## Records the changed rectangle in `edit_log` and emits terrain_changed.
func _announce(rect: Rect2i) -> void:
	edit_log.append(rect)
	terrain_changed.emit(rect)


## Destroys a noisy disc of terrain (mask only); emits terrain_changed.
func carve_crater(cx: float, cy: float, radius: float) -> void:
	var r: int = int(ceilf(radius))
	var x0: int = maxi(0, int(floorf(cx - r - 6)))
	var x1: int = mini(W - 1, int(ceilf(cx + r + 6)))
	var y0: int = maxi(0, int(floorf(cy - r - 6)))
	var y1: int = mini(H - 1, int(ceilf(cy + r + 6)))
	var sure_in: float = radius - _JIT_MAX
	var sure_out: float = radius - _JIT_MIN
	var sure_in_sq: float = sure_in * sure_in if sure_in > 0.0 else -1.0
	var sure_out_sq: float = sure_out * sure_out if sure_out > 0.0 else -1.0
	for y in range(y0, y1 + 1):
		var dy: float = y - cy
		var dy2: float = dy * dy
		var row: int = y * W
		for x in range(x0, x1 + 1):
			var dx: float = x - cx
			var d2: float = dx * dx + dy2
			if d2 > sure_out_sq:
				continue
			if d2 <= sure_in_sq:
				mask[row + x] = 0
				continue
			var jitter: float = (SimNoise.noise2d(x * 0.09, y * 0.09) - 0.5) * 4.5
			if sqrt(d2) + jitter <= radius:
				mask[row + x] = 0
	if x1 >= x0 and y1 >= y0:
		last_change_kind = "carve"
		last_carve = {"x": cx, "y": cy, "r": radius}
		_announce(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))


## Cuts a straight ramp into the rock (the road of a procession level): it starts at the foot of a wall (x, ground y) and climbs `rise` px
## going `dir` (+1 right, -1 left) at `slope` px per px; all the rock above the ramp line is removed, so the walkers can climb it.
func cut_ramp(foot: Vector2, dir: int, rise: float, slope: float = 0.5) -> void:
	var length: int = int(ceilf(rise / slope))
	var x_a: int = clampi(int(foot.x), 0, W - 1)
	var x_b: int = clampi(int(foot.x) + dir * length, 0, W - 1)
	for t in range(0, length + 1):
		var x: int = int(foot.x) + dir * t
		if x < 0 or x >= W:
			continue
		var line_y: int = int(roundf(foot.y - slope * t))
		for y in range(maxi(0, line_y - _RAMP_CLEAR), mini(H, line_y)):
			mask[y * W + x] = 0
	var y_top: int = maxi(0, int(foot.y - rise) - _RAMP_CLEAR)
	_announce(Rect2i(mini(x_a, x_b), y_top, absi(x_b - x_a) + 1, int(foot.y) - y_top + 2))


## Builds a dry-stone girder (capsule) of solid terrain; emits terrain_changed and records a stamp.
func build_girder(cx: float, cy: float, angle: float, length: float = 78.0, thickness: float = 16.0) -> void:
	var cos_a: float = cos(angle)
	var sin_a: float = sin(angle)
	var half_l: float = length * 0.5
	var half_t: float = thickness * 0.5
	var bound_r: int = int(ceilf(half_l + half_t + 6.0))
	var x0: int = int(SimMath.clamp_js(floorf(cx - bound_r), 0.0, float(W - 1)))
	var x1: int = int(SimMath.clamp_js(ceilf(cx + bound_r), 0.0, float(W - 1)))
	var y0: int = int(SimMath.clamp_js(floorf(cy - bound_r), 0.0, float(H - 1)))
	var y1: int = int(SimMath.clamp_js(ceilf(cy + bound_r), 0.0, float(H - 1)))
	if x1 - x0 + 1 <= 0 or y1 - y0 + 1 <= 0:
		return
	var bw: int = x1 - x0 + 1
	var added := PackedByteArray()
	added.resize(bw * (y1 - y0 + 1))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx: float = x - cx
			var dy: float = y - cy
			var along: float = dx * cos_a + dy * sin_a
			var perp: float = -dx * sin_a + dy * cos_a
			var round_cap: float = maxf(0.0, absf(along) - (half_l - 5.0))
			if absf(along) <= half_l and perp * perp + round_cap * round_cap <= half_t * half_t:
				var mi: int = y * W + x
				if mask[mi] == 0:
					added[(y - y0) * bw + (x - x0)] = 1
				mask[mi] = 1
	stamps.append({"kind": "GIRDER", "x": cx, "y": cy, "angle": angle, "length": length, "thickness": thickness,
		"rect": Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)})
	last_change_kind = "build"
	last_build = {"rect": Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1), "added": added, "x": cx, "y": cy, "angle": angle, "length": length, "thickness": thickness}
	_announce(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))


## Anthill mound (story WAVES levels): a solid dome of ANTHILL_W px and ANTHILL_H px high on the ground at (cx, sy), recorded as an
## ANTHILL stamp ({x, y = ground y, w, h}). The hole the ants come out of is the top of the dome.
func stamp_anthill(cx: int, sy: int) -> void:
	var half: int = ANTHILL_HALF
	for dx in range(-half, half + 1):
		var h: int = int(roundf(ANTHILL_H * cos(float(dx) / half * PI * 0.5)))
		var y: int = sy - h
		while y < sy + 70:
			_set_px(cx + dx, y)
			if y >= sy and mask[mini(H - 1, y + 1) * W + clampi(cx + dx, 0, W - 1)] == 1:
				break
			y += 1
	stamps.append({"kind": "ANTHILL", "x": cx, "y": sy, "w": ANTHILL_W + 1, "h": ANTHILL_H + 8})
	_announce(Rect2i(cx - half, sy - ANTHILL_H, ANTHILL_W + 1, ANTHILL_H + 70))


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

func _r() -> float:
	return SimMath.rand01(_rng)


func _set_px(x: int, y: int) -> void:
	if x < 0 or x >= W or y < 0 or y >= H:
		return
	mask[y * W + x] = 1


func _clear_px(x: int, y: int) -> void:
	if x < 0 or x >= W or y < 0 or y >= H:
		return
	mask[y * W + x] = 0


func _gauss(x: float, c: float, w: float) -> float:
	var d: float = (x - c) / w
	return exp(-(d * d))


## Generates the whole terrain mask for `map_def` (JS generateDestructibleTerrain, without colours).
## With `deterministic` the map seed starts from 2.4 instead of the value carried between matches.
func generate(map_def: MapDef, rng: RandomNumberGenerator, deterministic: bool = false) -> void:
	_rng = rng
	map = map_def
	water_y = SimTables.WATER_Y_START
	if deterministic:
		map_seed = 2.4
	else:
		map_seed = _carried_map_seed
	map_seed += 1.73 + _r() * 3.8
	if not deterministic:
		_carried_map_seed = map_seed
	mask.fill(0)
	arena_x0 = 0.0
	arena_x1 = float(W)
	tree_spots = []
	valley_spots = []
	stamps = []
	caverns = []

	if map_def.preferred_texture != "" and _r() < 0.5:
		texture_style = map_def.preferred_texture
	else:
		texture_style = SimTables.TEXTURE_STYLES[int(_r() * SimTables.TEXTURE_STYLES.size())]

	# Per-match colour harmony (the view paints with these values).
	var turf_shift := Vector3(SimMath.round_js((_r() - 0.5) * 28.0), SimMath.round_js((_r() - 0.5) * 28.0), SimMath.round_js((_r() - 0.5) * 22.0))
	var rock_shift := Vector3(SimMath.round_js((_r() - 0.5) * 32.0), SimMath.round_js((_r() - 0.5) * 28.0), SimMath.round_js((_r() - 0.5) * 32.0))
	var soil_shift := Vector3(SimMath.round_js((_r() - 0.5) * 24.0), SimMath.round_js((_r() - 0.5) * 22.0), SimMath.round_js((_r() - 0.5) * 20.0))
	var turf: Vector3 = MapDef.rgb255(map_def.turf_col)
	var soil: Vector3 = MapDef.rgb255(map_def.soil_col)
	var rock: Vector3 = MapDef.rgb255(map_def.rock_col)
	match_turf = Vector3(
		SimMath.clamp_js(turf.x + turf_shift.x, 32.0, 210.0), SimMath.clamp_js(turf.y + turf_shift.y, 42.0, 215.0), SimMath.clamp_js(turf.z + turf_shift.z, 24.0, 175.0))
	match_soil = Vector3(
		SimMath.clamp_js(soil.x + soil_shift.x, 35.0, 210.0), SimMath.clamp_js(soil.y + soil_shift.y, 30.0, 190.0), SimMath.clamp_js(soil.z + soil_shift.z, 22.0, 165.0))
	match_rock = Vector3(
		SimMath.clamp_js(rock.x + rock_shift.x, 42.0, 220.0), SimMath.clamp_js(rock.y + rock_shift.y, 42.0, 215.0), SimMath.clamp_js(rock.z + rock_shift.z, 42.0, 220.0))

	var picked: Array = SimTables.ARCHETYPES[int(_r() * SimTables.ARCHETYPES.size())]
	archetype_id = picked[0]
	archetype_key = picked[1]

	var freq_scale: float = 0.82 + _r() * 0.55
	var hill_amp: float = 260.0 + _r() * 95.0
	var asym_tilt: float = (_r() - 0.5) * 90.0
	var num_peaks: int = 3 + int(_r() * 4.0)
	var hills: Array[Vector3] = []
	for p in num_peaks:
		var hcx: float = 340.0 + ((p + 0.15 + _r() * 0.7) / num_peaks) * (W - 680.0)
		var hw: float = 130.0 + _r() * 190.0
		var sign_v: float = -1.0 if _r() < 0.62 else 1.0
		var hamp: float = sign_v * (55.0 + _r() * 115.0)
		hills.append(Vector3(hcx, hw, hamp))

	_build_surface(freq_scale, hill_amp, asym_tilt, hills)
	_fill_mask_and_caverns()
	_stamp_terraces()
	_stamp_landmarks()
	_stamp_trees()
	for vx in [880.0, 1600.0, 2320.0]:
		valley_spots.append(int(floorf(vx + (_r() - 0.5) * 180.0)))


func _build_surface(freq_scale: float, hill_amp: float, asym_tilt: float, hills: Array[Vector3]) -> void:
	surface_y.resize(W)
	var wy: float = water_y
	var map_id: String = map.id
	for xi in W:
		var x: float = float(xi)
		var edge_dist: int = mini(xi - 120, W - 120 - xi)
		if edge_dist < 0:
			surface_y[xi] = H + 80
			continue
		var island_env: float = SimMath.clamp_js(edge_dist / 190.0, 0.0, 1.0)
		var smooth_env: float = island_env * island_env * (3.0 - 2.0 * island_env)

		var n_large: float = SimNoise.fbm(x * 0.0016 * freq_scale + map_seed, map_seed, 4)
		var n_med: float = SimNoise.fbm(x * 0.0042 * freq_scale + map_seed * 1.7, map_seed + 1.9, 4)
		var n_detail: float = SimNoise.ridged_fbm(x * 0.0065 * freq_scale + map_seed * 2.1, map_seed + 3.1, 3)

		var h: float = 265.0 + (1.0 - (n_large * 0.52 + n_med * 0.28 + n_detail * 0.20)) * hill_amp
		h += ((x / W) - 0.5) * asym_tilt
		for rh in hills:
			var d: float = (x - rh.x) / rh.y
			h += exp(-(d * d)) * rh.z

		match archetype_id:
			"ARCHIPELAGO":
				var ch1: float = _gauss(x, 1080.0, 110.0) * 245.0
				var ch2: float = _gauss(x, 2120.0, 110.0) * 245.0
				h = SimMath.round_js(h / 28.0) * 28.0 + ch1 + ch2
			"TWIN_MASSIFS":
				var fjord: float = _gauss(x, 1600.0, 195.0) * 265.0
				var peak_l: float = -_gauss(x, 880.0, 230.0) * 115.0
				var peak_r: float = -_gauss(x, 2320.0, 230.0) * 115.0
				h += fjord + peak_l + peak_r
			"CITADEL_CALDERA":
				var lagoon_l: float = _gauss(x, 980.0, 145.0) * 205.0
				var lagoon_r: float = _gauss(x, 2220.0, 145.0) * 205.0
				var citadel: float = -_gauss(x, 1600.0, 270.0) * 110.0
				h += lagoon_l + lagoon_r + citadel
			"FEIXES_TERRACED":
				var raw_step: float = SimMath.round_js(h / 46.0) * 46.0
				h = lerpf(h, raw_step, 0.82) + sin(x * 0.025) * 6.0
			"AGULLES_SPIRES":
				var spire_wave: float = sin(x * 0.011 + map_seed) * cos(x * 0.0045 - map_seed * 0.5)
				h += spire_wave * 115.0 - absf(sin(x * 0.008)) * 45.0
			"MULTI_DECK_GROTTO":
				h += -_gauss(x, 1600.0, 760.0) * 95.0
			"FLOATING_BALCONIES":
				h = lerpf(h, SimMath.round_js(h / 38.0) * 38.0, 0.65) + sin(x * 0.0065 + map_seed) * 55.0
			_:
				h = SimMath.round_js(h / 36.0) * 36.0 + (n_detail - 0.5) * 26.0
				h += _gauss(x, 1600.0, 145.0) * 175.0

		match map_id:
			"MONTSERRAT":
				h += sin(x * 0.015) * 28.0 * _gauss(x, 1600.0, 980.0)
			"CADAQUES":
				h += cos(x * 0.005) * 28.0 + SimMath.round_js(sin(x * 0.012) * 3.0) * 7.0
			"TAULL":
				h += -absf(sin(x * 0.0045)) * 42.0
			"CASTELLFOLLIT":
				h = SimMath.round_js(h / 28.0) * 28.0 + sin(x * 0.008) * 18.0
			"DELTA_EBRE":
				var dune: float = sin(x * 0.007 + map_seed) * 26.0 + cos(x * 0.019) * 12.0
				h = lerpf(h, 430.0 + dune, 0.28)
			"TARRACO":
				var tier: float = SimMath.round_js(h / 32.0) * 32.0
				h = lerpf(h, tier, 0.55) + cos(x * 0.009) * 16.0
			"PEDRAFORCA":
				h += _gauss(x, 1600.0, 210.0) * 125.0 - _gauss(x, 1160.0, 190.0) * 95.0 - _gauss(x, 2040.0, 190.0) * 95.0
			"MONTBLANC":
				h += SimMath.round_js(sin(x * 0.014) * 2.0) * 14.0

		surface_y[xi] = lerpf(wy + 95.0, SimMath.clamp_js(h, 165.0, wy + 65.0), smooth_env)


func _fill_mask_and_caverns() -> void:
	var wy: float = water_y
	# Caverns first (RNG order of the JS), carved after the solid fill.
	var cavern_count: int = 4 if archetype_id == "MULTI_DECK_GROTTO" else 2 + int(_r() * 3.0)
	for c in cavern_count:
		var frac: float = (c + 0.5) / cavern_count
		var cx: float = 520.0 + frac * (W - 1040.0) + (_r() - 0.5) * 220.0
		var top_surf: float = surface_y[int(SimMath.clamp_js(floorf(cx), 200.0, float(W - 200)))]
		var cy: float = SimMath.clamp_js(top_surf + 95.0 + _r() * 85.0, 340.0, wy - 55.0)
		var rx: float = (210.0 if archetype_id == "MULTI_DECK_GROTTO" else 135.0) + _r() * 95.0
		var ry: float = 36.0 + _r() * 20.0
		caverns.append({"cx": cx, "cy": cy, "rx": rx, "ry": ry})

	# Solid fill from the surface down to the bottom of the mask: one native column fill per x instead of ~2 M GDScript writes.
	var fill_img: Image = Image.create_from_data(W, H, false, Image.FORMAT_R8, mask)
	for x in W:
		var sy: int = int(floorf(surface_y[x]))
		if sy < H:
			fill_img.fill_rect(Rect2i(x, maxi(sy, 0), 1, H - maxi(sy, 0)), _SOLID)
	mask = fill_img.get_data()

	# Caverns: depth > 32 below the surface and above water_y - 24. The ellipse test needs the cavity noise
	# only inside the annulus where the noise range can matter (identical result to testing every pixel).
	var y_limit: int = int(ceilf(wy - 24.0))
	var reach: float = sqrt(_CAV_HI)
	for cav in caverns:
		var ccx: float = cav["cx"]
		var ccy: float = cav["cy"]
		var crx: float = cav["rx"]
		var cry: float = cav["ry"]
		var xa: int = maxi(0, int(floorf(ccx - reach * crx)))
		var xb: int = mini(W - 1, int(ceilf(ccx + reach * crx)))
		var ya: int = maxi(0, int(floorf(ccy - reach * cry)))
		var yb: int = mini(H - 1, int(ceilf(ccy + reach * cry)))
		for x in range(xa, xb + 1):
			var sy2: int = int(floorf(surface_y[x]))
			var ddx: float = (x - ccx) / crx
			var ddx2: float = ddx * ddx
			for y in range(ya, yb + 1):
				if y - sy2 <= 32 or y >= y_limit:
					continue
				var ddy: float = (y - ccy) / cry
				var d2: float = ddx2 + ddy * ddy
				if d2 >= _CAV_HI:
					continue
				if d2 < _CAV_LO:
					mask[y * W + x] = 0
					continue
				var cav_n: float = SimNoise.fbm(x * 0.018 + map_seed, y * 0.018, 3) * 0.32
				if d2 < 0.88 + cav_n:
					mask[y * W + x] = 0


func _stamp_terraces() -> void:
	var num_terraces: int = 5 if archetype_id == "FLOATING_BALCONIES" else 2 + int(_r() * 3.0)
	for t in num_terraces:
		var tx: int = int(floorf(460.0 + ((t + 0.2 + _r() * 0.6) / num_terraces) * (W - 920.0)))
		var ground_y: float = surface_y[int(SimMath.clamp_js(tx, 200.0, float(W - 200)))]
		var half_w: int = int(floorf(72.0 + _r() * 68.0))
		var deck_y: float = SimMath.clamp_js(ground_y - (78.0 + _r() * 95.0), 185.0, water_y - 120.0)
		_stamp_terrace(tx, deck_y, half_w)


func _stamp_terrace(cx: int, deck_y: float, half_w: int) -> void:
	var thickness: float = 24.0
	for dx in range(-half_w, half_w + 1):
		var x: int = int(floorf(cx + dx))
		if x < 140 or x >= W - 140:
			continue
		var edge_frac: float = absf(float(dx)) / half_w
		var arch_curve: float = SimMath.round_js(pow(edge_frac, 2.2) * 10.0)
		var top_wave: float = SimMath.round_js(sin(x * 0.06) * 2.5)
		var y_top: int = int(floorf(deck_y + top_wave))
		var y_bot: int = int(floorf(deck_y + thickness - arch_curve + cos(x * 0.09) * 3.0))
		for cy in range(y_top - 38, y_top):
			_clear_px(x, cy)
		for y in range(y_top, y_bot + 1):
			_set_px(x, y)
	stamps.append({"kind": "TERRACE", "x": cx, "y": deck_y, "w": half_w * 2 + 1, "h": 62, "half_w": half_w,
		"thickness": thickness})


func _shuffled(items: Array) -> Array:
	var a: Array = items.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j: int = int(_r() * (i + 1))
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
	return a


func _stamp_landmarks() -> void:
	var pool: Array = _shuffled(Array(SimTables.LANDMARK_POOL))
	var chosen: Array = pool.slice(0, 2 + int(_r() * 2.0))
	var zones: Array = _shuffled([680.0, 1180.0, 1600.0, 2040.0, 2520.0])
	var map_id: String = map.id
	for idx in chosen.size():
		var lm: String = chosen[idx]
		var zx: int = int(floorf(float(zones[idx]) + (_r() - 0.5) * 140.0))
		var zy: int = int(floorf(surface_y[int(SimMath.clamp_js(zx, 200.0, float(W - 200)))]))
		if lm == "BRIDGE_SPAN":
			var span_half: float = 190.0 + _r() * 70.0
			var deck_y: float = minf(zy - 45.0, 340.0 + _r() * 60.0)
			if map_id == "MONTSERRAT" or map_id == "CASTELLFOLLIT" or map_id == "TARRACO" or map_id == "MONTBLANC" or _r() < 0.75:
				_stamp_viaduct(zx - span_half, zx + span_half, deck_y)
			else:
				_stamp_truss(zx - span_half, zx + span_half, deck_y, map_id == "MONTSERRAT")
		elif zy < water_y - 45.0:
			if lm == "BARRACA_DELTA" or map_id == "DELTA_EBRE":
				_stamp_barraca(zx, zy)
			elif lm == "WATCHTOWER" or lm == "SECOND_TOWER":
				_stamp_watchtower(zx, zy)
			elif lm == "HOLLOW_LOG":
				_stamp_log(zx, zy)
			elif lm == "ROCK_ARCH":
				_stamp_arch(zx, zy)
			elif lm == "MONOLITHS":
				_stamp_monoliths(zx, zy)


func _stamp_watchtower(cx: int, sy: int) -> void:
	var w: int = 34
	var h: int = 84
	for y in range(sy - h, sy + 13):
		for x in range(cx - w, cx + w + 1):
			if y < sy - h + 10 and absi(x - cx) % 14 > 7:
				continue
			_set_px(x, y)
	for y in range(sy - 52, sy - 15):
		for x in range(cx - 18, cx + 19):
			_clear_px(x, y)
	stamps.append({"kind": "WATCHTOWER", "x": cx, "y": sy, "w": w * 2 + 1, "h": h + 13})


func _stamp_log(cx: int, sy: int) -> void:
	var half_len: int = 78
	var tilt: float = (_r() - 0.5) * 0.14
	for dx in range(-half_len, half_len + 1):
		var lx: float = cx + dx
		var ly: float = sy - 14 + dx * tilt
		for dy in range(-16, 13):
			var x: int = int(floorf(lx))
			var y: int = int(floorf(ly + dy))
			if absi(dy) >= 9:
				_set_px(x, y)
			else:
				_clear_px(x, y)
	stamps.append({"kind": "HOLLOW_LOG", "x": cx, "y": sy, "tilt": tilt, "half_len": half_len, "w": half_len * 2 + 1, "h": 29})


func _stamp_arch(cx: int, sy: int) -> void:
	var span: int = 115
	var arch_h: float = 74.0
	for dx in range(-span, span + 1):
		var norm_x: float = float(dx) / span
		var top_y: float = sy - arch_h * cos(norm_x * PI * 0.5)
		var bot_y: float = sy - (arch_h - 24.0) * maxf(0.0, cos(norm_x * PI * 0.68))
		for y in range(int(floorf(top_y)), int(floorf(bot_y)) + 1):
			_set_px(cx + dx, y)
	stamps.append({"kind": "ROCK_ARCH", "x": cx, "y": sy, "span": span, "w": span * 2 + 1, "h": 75})


func _stamp_monoliths(cx: int, sy: int) -> void:
	for px in [-42, 42]:
		for y in range(sy - 58, sy + 11):
			for dx in range(-9, 10):
				_set_px(cx + px + dx, y)
	for y in range(sy - 68, sy - 53):
		for dx in range(-56, 57):
			_set_px(cx + dx, y)
	stamps.append({"kind": "MONOLITHS", "x": cx, "y": sy, "w": 123, "h": 79})


func _stamp_viaduct(x1: float, x2: float, deck_y: float) -> void:
	for x in range(int(floorf(x1)), int(ceilf(x2)) + 1):
		var local_x: float = x - x1
		var arch_dist: float = absf(fmod(local_x, 130.0) - 65.0)
		var q: float = (65.0 - arch_dist) / 65.0
		var max_y: float = deck_y + 14.0 + q * q * 44.0
		for y in range(int(floorf(deck_y)), int(floorf(max_y)) + 1):
			_set_px(x, y)
	stamps.append({"kind": "VIADUCT", "x1": x1, "x2": x2, "deck_y": deck_y, "x": (x1 + x2) * 0.5, "y": deck_y,
		"w": int(x2 - x1) + 1, "h": 60})


func _stamp_truss(x1: float, x2: float, deck_y: float, is_orange: bool) -> void:
	for x in range(int(floorf(x1)), int(ceilf(x2)) + 1):
		for y in range(int(floorf(deck_y)), int(floorf(deck_y + 18.0)) + 1):
			var truss: bool = (x + y) % 14 < 3 or (x - y + 1000) % 14 < 3 or y <= deck_y + 4.0 or y >= deck_y + 15.0
			if not truss and x % 28 > 4:
				continue
			_set_px(x, y)
	stamps.append({"kind": "TRUSS", "x1": x1, "x2": x2, "deck_y": deck_y, "is_orange": is_orange, "x": (x1 + x2) * 0.5,
		"y": deck_y, "w": int(x2 - x1) + 1, "h": 19})


func _stamp_barraca(cx: int, sy: int) -> void:
	var w: int = 36
	var wall_h: int = 30
	var roof_h: int = 38
	for y in range(sy - wall_h, sy + 11):
		for x in range(cx - w, cx + w + 1):
			_set_px(x, y)
	for dy in range(0, roof_h + 1):
		var span: int = int(SimMath.round_js(float(roof_h - dy) / roof_h * (w + 8)))
		var y: int = sy - wall_h - dy
		for x in range(cx - span, cx + span + 1):
			_set_px(x, y)
	for y in range(sy - 22, sy - 1):
		for x in range(cx - 12, cx + 13):
			_clear_px(x, y)
	stamps.append({"kind": "BARRACA", "x": cx, "y": sy, "w": (w + 8) * 2 + 1, "h": wall_h + roof_h + 11})


func _stamp_trees() -> void:
	var styles_pool: Array = [map.tree_style, map.tree_style, "UMBRELLA_PINE", "CYPRESS", "DOUGLAS_FIR", "PALM_DELTA"]
	var tree_count: int = 5 + int(_r() * 5.0)
	for i in tree_count:
		var sector_w: float = (W - 560.0) / tree_count
		var tx: int = int(floorf(280.0 + i * sector_w + (_r() - 0.5) * (sector_w * 0.55)))
		var ty: int = int(floorf(surface_y[int(SimMath.clamp_js(tx, 100.0, float(W - 100)))]))
		if ty < water_y - 50.0 and not is_solid(tx, ty - 25.0):
			var sc: float = 0.82 + _r() * 0.42
			var style: String = map.tree_style if _r() < 0.72 else str(styles_pool[int(_r() * styles_pool.size())])
			var crown_y: int = _stamp_tree(tx, ty, style, sc)
			tree_spots.append({"tx": tx, "crown_y": crown_y})
			stamps.append({"kind": "TREE", "x": tx, "y": ty, "style": style, "scale": sc, "crown_y": crown_y,
				"w": int(110.0 * sc), "h": int(110.0 * sc)})


## Stamps a tree and returns its crown_y.
func _stamp_tree(tx: int, ty: int, style: String, sc: float) -> int:
	var base_trunk: float = 76.0 if style == "DOUGLAS_FIR" else (64.0 if style == "UMBRELLA_PINE" else 58.0)
	var trunk_h: int = int(SimMath.round_js(base_trunk * sc))
	for y in range(ty - trunk_h, ty + 11):
		var lean: float = sin((ty - y) * 0.04) * 6.0 * sc if style == "UMBRELLA_PINE" else 0.0
		var half_w: float = (5.5 if y > ty - 16 else 4.0) * sc
		for x in range(int(floorf(tx + lean - half_w)), int(ceilf(tx + lean + half_w)) + 1):
			_set_px(x, y)
	var crown_y: int = ty - trunk_h
	if style == "UMBRELLA_PINE":
		var rx: int = int(SimMath.round_js(48.0 * sc))
		var ry: int = int(SimMath.round_js(25.0 * sc))
		for dy in range(-ry - 4, 9):
			for dx in range(-rx, rx + 1):
				var nx: float = float(dx) / rx
				var ny: float = float(dy + 8) / ry
				if dy < 5 and (nx * nx + ny * ny) <= 1.0 + (SimNoise.noise2d((tx + dx) * 0.1, (crown_y + dy) * 0.1) - 0.5) * 0.35:
					_set_px(int(floorf(tx + dx)), int(floorf(crown_y + dy)))
	elif style == "DOUGLAS_FIR":
		for tier in 3:
			var cy: float = crown_y - tier * SimMath.round_js(18.0 * sc) + 12.0
			var max_w: float = (34.0 - tier * 7.0) * sc
			for dy in range(-int(SimMath.round_js(20.0 * sc)), 7):
				var span: float = ((dy + 20.0 * sc) / (26.0 * sc)) * max_w
				var dxf: float = -span
				while dxf <= span:
					_set_px(int(floorf(tx + dxf)), int(floorf(cy + dy)))
					dxf += 1.0
	elif style == "PALM_DELTA":
		for f in range(-3, 4):
			var angle: float = f * 0.42
			var ln: int = int(SimMath.round_js((36.0 - absi(f) * 3.0) * sc))
			for s in range(0, ln + 1):
				var fx: float = tx + sin(angle) * s * 1.15
				var fy: float = crown_y - cos(angle) * s * 0.45 + (s * s) * 0.016
				var leaf_w: int = int(maxf(2.0, SimMath.round_js((1.0 - float(s) / (ln + 4)) * 6.0 * sc)))
				for dy in range(-leaf_w, leaf_w + 1):
					for dx in range(-2, 3):
						_set_px(int(floorf(fx + dx)), int(floorf(fy + dy)))
	else:
		var rx2: int = int(SimMath.round_js(40.0 * sc))
		var ry2: int = int(SimMath.round_js(20.0 * sc))
		for dy in range(-ry2 - 4, 7):
			for dx in range(-rx2, rx2 + 5):
				var nx2: float = float(dx - 4) / rx2
				var ny2: float = float(dy + 6) / ry2
				if nx2 * nx2 + ny2 * ny2 <= 0.96:
					_set_px(int(floorf(tx + dx)), int(floorf(crown_y + dy)))
	return crown_y

## Shared placement registry of a match: the footprints of everything that stands on the ground (fighters, barrels, mines,
## mushrooms, flora, crates, hiding spots...) and the rectangles of the stamped structures (trees, towers, barracas...).
## Every spawner asks `find` / `is_free` before it puts something down, so objects never overlap each other, never sit on
## a tree crown or a tower, and never stand half-buried in rock. Deterministic: it never draws from the match RNG, the
## alternatives are tried in a fixed order (original x, then 8 px, 16 px... to either side).
##
## A footprint is a rectangle that rests on the surface point (x, sy): half width `hw`, height `h`.
class_name SimPlacement
extends RefCounted

## Extra space (px) kept between two objects.
const PAD: float = 3.0
## Distance between two tried x values.
const X_STEP: float = 8.0
const DEFAULT_SHIFT: float = 96.0
## An object whose footprint has more than this fraction inside rock counts as buried.
const BURIED_FRACTION: float = 0.25
## Scenery that is planted into a slope (grass, the wind column of a valley) may have more of its footprint in rock.
const SCENERY_BURIED_FRACTION: float = 0.6
## Half width and height of the footprint of each kind (size 1).
const SIZES: Dictionary = {
	"FIGHTER": Vector2(12.0, 24.0), "HIDE": Vector2(12.0, 24.0), "BARREL": Vector2(14.0, 28.0), "MINE": Vector2(9.0, 10.0),
	"ROVELLO": Vector2(19.0, 30.0), "CAGANER": Vector2(12.0, 30.0), "ESCUDELLA": Vector2(16.0, 26.0),
	"FLORA": Vector2(7.0, 18.0), "UPDRAFT": Vector2(14.0, 12.0), "CRATE": Vector2(14.0, 28.0),
}

## Fewest 8 px columns a fighter must be able to walk/leap to, else it is stranded on a pillar or in a pit.
const MIN_ROOM: int = 40

## Optional extra test (func(x: float, sy: float) -> bool) that `find` applies to every candidate that is otherwise free.
var extra_filter: Callable = Callable()
var _sim: CombatSim
var _terrain: TerrainSim
var _rects: Array[Rect2] = []
var _stamp_rects: Array[Rect2] = []


## Registry of the current state of `sim`: its terrain stamps and every object already on the ground.
func _init(sim: CombatSim) -> void:
	_sim = sim
	_terrain = sim.terrain
	_stamp_rects = stamp_rects(_terrain)
	for fp in footprints(sim):
		_rects.append(fp["rect"])


## Footprint rectangle of `kind` on the surface point (x, sy). `size` scales it (fighter radius / 12, mushroom radius / 21...).
static func footprint(kind: String, x: float, sy: float, size: float = 1.0) -> Rect2:
	var s: Vector2 = SIZES[kind]
	return Rect2(x - s.x * size, sy - s.y * size, s.x * 2.0 * size, s.y * size)


## Every footprint on the ground of `sim` as {kind, x, sy, rect}. Nests are left out: they hang from the trees on purpose.
static func footprints(sim: CombatSim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in sim.fighters:
		if f.alive and not f.drowning and not f.flying:
			out.append(_fp("FIGHTER", f.x, f.y + f.r + 2.0, f.r / 12.0))
	for b in sim.barrels:
		out.append(_fp("BARREL", b.x, b.y + b.r))
	for m in sim.mines:
		out.append(_fp("MINE", m.x, m.y + 5.0))
	for r in sim.rovellons:
		out.append(_fp("ROVELLO", r.x, r.y, r.r / 21.0))
	for c in sim.caganers:
		out.append(_fp("CAGANER", c.x, c.y + 8.0))
	for e in sim.escudelles:
		out.append(_fp("ESCUDELLA", e.x, e.y + 12.0))
	for fl in sim.surface_flora:
		out.append(_fp("FLORA", fl.x, fl.y, fl.scale))
	for u in sim.updrafts:
		out.append(_fp("UPDRAFT", u.x, u.y))
	var hide_r: float = 12.0 if sim.level == null or sim.level.player_unit == null else sim.level.player_unit.radius
	for s in sim.hiding_spots:
		out.append(_fp("HIDE", s.x, s.y + hide_r, hide_r / 12.0))
	for cr in sim.crates:
		out.append(_fp("CRATE", cr.x, sim.terrain.find_surface_y(cr.x, maxf(0.0, cr.y - 30.0))))
	return out


static func _fp(kind: String, x: float, sy: float, size: float = 1.0) -> Dictionary:
	return {"kind": kind, "x": x, "sy": sy, "rect": footprint(kind, x, sy, size)}


## Rectangles that objects must keep out of: trunks, crowns and the hanging-nest zone of the trees, towers, barracas,
## monoliths, arches and logs. Walkable decks (terraces, viaducts, trusses, girders) are not in the list.
static func stamp_rects(terrain: TerrainSim) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for st in terrain.stamps:
		var kind: String = st["kind"]
		var x: float = float(st["x"])
		var y: float = float(st["y"])
		match kind:
			"TREE":
				out.append_array(_tree_rects(st))
			"WATCHTOWER":
				out.append(Rect2(x - 35.0, y - 84.0, 70.0, 97.0))
			"BARRACA":
				out.append(Rect2(x - 44.0, y - 68.0, 88.0, 79.0))
			"MONOLITHS":
				out.append(Rect2(x - 56.0, y - 68.0, 112.0, 15.0))
				out.append(Rect2(x - 51.0, y - 58.0, 18.0, 69.0))
				out.append(Rect2(x + 33.0, y - 58.0, 18.0, 69.0))
			"ROCK_ARCH":
				out.append(Rect2(x - 115.0, y - 75.0, 230.0, 75.0))
			"ANTHILL":
				out.append(Rect2(x - 42.0, y - 30.0, 84.0, 36.0))
			"HOLLOW_LOG":
				out.append(Rect2(x - 78.0, y - 32.0, 156.0, 44.0))
	return out


static func _tree_rects(st: Dictionary) -> Array[Rect2]:
	var tx: float = float(st["x"])
	var ty: float = float(st["y"])
	var sc: float = float(st["scale"])
	var crown_y: float = float(st["crown_y"])
	var out: Array[Rect2] = [Rect2(tx - 12.0 * sc, crown_y, 24.0 * sc, ty - crown_y + 10.0)]
	match String(st["style"]):
		"UMBRELLA_PINE":
			out.append(Rect2(tx - 48.0 * sc, crown_y - 25.0 * sc - 4.0, 96.0 * sc, 25.0 * sc + 12.0))
		"DOUGLAS_FIR":
			out.append(Rect2(tx - 34.0 * sc, crown_y - 44.0 * sc, 68.0 * sc, 44.0 * sc + 19.0))
		"PALM_DELTA":
			out.append(Rect2(tx - 44.0 * sc, crown_y - 20.0 * sc, 88.0 * sc, 20.0 * sc + 28.0))
		_:
			out.append(Rect2(tx - 40.0 * sc, crown_y - 20.0 * sc - 4.0, 84.0 * sc, 20.0 * sc + 11.0))
	# the silk nests hang beside the trunk
	out.append(Rect2(tx - 34.0, crown_y + 14.0, 34.0, 36.0))
	return out


## True when `rect` touches one of the structure rectangles.
static func hits_stamp(stamps: Array[Rect2], rect: Rect2) -> bool:
	for s in stamps:
		if s.grow(2.0).intersects(rect):
			return true
	return false


## Fraction (0..1) of the middle of `rect` that is solid rock.
static func buried_fraction(terrain: TerrainSim, rect: Rect2) -> float:
	var hits: int = 0
	var total: int = 0
	var x: float = rect.position.x + rect.size.x * 0.12
	while x <= rect.end.x - rect.size.x * 0.12:
		var y: float = rect.position.y + 2.0
		while y <= rect.end.y - 5.0:
			total += 1
			if terrain.is_solid(x, y):
				hits += 1
			y += 3.0
		x += 3.0
	return 0.0 if total == 0 else float(hits) / total


## True when there is rock under (x, sy): the object stands on something.
static func supported(terrain: TerrainSim, x: float, sy: float) -> bool:
	for dy in range(-1, 9):
		if terrain.is_solid(x, sy + dy):
			return true
	return false


## How much of its footprint an object of `kind` may have inside rock.
static func buried_limit(kind: String) -> float:
	return SCENERY_BURIED_FRACTION if kind == "FLORA" or kind == "UPDRAFT" else BURIED_FRACTION


## Nothing registered nor stamped in the way, standing on rock, not buried.
func is_free(kind: String, x: float, sy: float, size: float = 1.0) -> bool:
	var rect: Rect2 = footprint(kind, x, sy, size)
	if not supported(_terrain, x, sy) or buried_fraction(_terrain, rect) > buried_limit(kind):
		return false
	if hits_stamp(_stamp_rects, rect):
		return false
	var padded: Rect2 = rect.grow(PAD)
	for r in _rects:
		if r.intersects(padded):
			return false
	return true


## Reserves the footprint.
func add(kind: String, x: float, sy: float, size: float = 1.0) -> void:
	_rects.append(footprint(kind, x, sy, size))


## The free surface spot nearest to (pref_x, pref_y): the preferred x first, then 8, 16... px to either side, on the tier closest
## to pref_y. `max_sy` keeps it out of the water, `fighter_gap` away from every fighter (distance to the fighter centre).
## Vector2.INF when nothing fits within `max_shift`.
func find(kind: String, pref_x: float, pref_y: float, max_sy: float, size: float = 1.0, fighter_gap: float = 0.0, max_shift: float = DEFAULT_SHIFT) -> Vector2:
	var k: int = 0
	while k * X_STEP <= max_shift:
		for d in ([0] if k == 0 else [-1, 1]):
			var x: float = _terrain.clamp_x(pref_x + d * k * X_STEP, 240.0)
			var sy: float = _tier_near(x, pref_y)
			if is_nan(sy) or sy >= max_sy:
				continue
			if fighter_gap > 0.0 and _near_fighter(x, sy, fighter_gap):
				continue
			if is_free(kind, x, sy, size) and (not extra_filter.is_valid() or extra_filter.call(x, sy)):
				return Vector2(x, sy)
		k += 1
	return Vector2.INF


## Where a crate dropped at x comes to rest: the first rock from the sky, as long as it is dry land.
## Tries 12 px steps to either side up to `max_shift`; the free drop x, or NAN when everything is taken.
func find_drop(x: float, max_shift: float = 360.0) -> float:
	var k: int = 0
	while k * 12.0 <= max_shift:
		for d in ([0] if k == 0 else [-1, 1]):
			var cx: float = _terrain.clamp_x(x + d * k * 12.0, 300.0)
			var sy: float = _terrain.find_surface_y(cx, 0.0)
			if sy < _terrain.water_y - 20.0 and is_free("CRATE", cx, sy):
				return cx
		k += 1
	return NAN


func _tier_near(x: float, y: float) -> float:
	var best: float = NAN
	for t in _terrain.find_all_walkable_surfaces_at_x(x):
		if is_nan(best) or absf(float(t) - y) < absf(best - y):
			best = float(t)
	return best


func _near_fighter(x: float, sy: float, gap: float) -> bool:
	for f in _sim.fighters:
		if Vector2(f.x - x, f.y - sy).length() < gap:
			return true
	return false

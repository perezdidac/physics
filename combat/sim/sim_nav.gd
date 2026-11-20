## Coarse walking map of the terrain for story-mode units: surface tiers per column and a breadth-first path search.
## Used to place squads and hiding spots on connected ground and by the melee AI to find its way around cliffs.
## The map follows the terrain: every rectangle the TerrainSim announces (craters, girders, ramps) refreshes the columns it touches before
## the next search. A link between two columns exists only when a body can really pass between the two surface points (free of rock).
class_name SimNav
extends RefCounted

const STEP: float = 8.0
const X_MIN: float = 240.0
const X_MAX: float = 2960.0
## Biggest rise a unit walks up between two columns, and the drop it will walk off (below ~88 there is no fall damage).
const MAX_CLIMB: float = 18.0
const MAX_DROP: float = 84.0
## Tallest wall a leaping unit (the ants) clears.
const MAX_LEAP: float = 80.0
## A surface step (px between two columns) above this is a wall: critters climb it (or let themselves down) instead of walking.
const WALL_STEP: float = 14.0
## Pixel rows above a surface point that must be free of rock for a body to pass (the lowest row is 10 px up: rough ground bumps higher than a body is tall do not count as walls).
const BODY_LOW: float = 10.0
const BODY_HIGH: float = 14.0
## Sampling distance (px) when checking a passage.
const PROBE: int = 2

## Per column: the y of every walkable surface (top to bottom).
var tiers: Array[PackedInt32Array] = []
## Number of terrain edits already applied to `tiers` (an index into TerrainSim.edit_log).
var edits_seen: int = 0

## False: the old permissive map (adjacent columns link by height difference alone, through rock if need be). Squad placement, goals and the
## level seeds rely on it; walkers that really move along the paths (AiCritter) use a strict one.
var strict_map: bool = true

var _terrain: TerrainSim
## Water level the tiers were scanned at (the tide lowers TerrainSim.water_y: flooded surfaces drop out of the map).
var _water_seen: float = 0.0
## Per column: {link key: bool}, the passability of the links that start in that column (a search asks for the same link many times).
## A terrain edit clears the columns it can touch.
var _links: Array[Dictionary] = []


func _init(terrain: TerrainSim, strict_links: bool = true) -> void:
	_terrain = terrain
	strict_map = strict_links
	edits_seen = terrain.edit_log.size()
	_water_seen = terrain.water_y
	for c in int((X_MAX - X_MIN) / STEP) + 1:
		tiers.append(_scan_column(c))
		_links.append({})


func _scan_column(c: int) -> PackedInt32Array:
	var dry := PackedInt32Array()
	for sy in _terrain.find_all_walkable_surfaces_at_x(X_MIN + c * STEP):
		if sy < _terrain.water_y - 22.0 and dry.size() < 8:
			dry.append(sy)
	return dry


## Applies the terrain edits made since the last call (only the touched columns are rescanned). Searches call it first.
func sync() -> void:
	if _terrain.water_y != _water_seen:
		# the tide rose: every surface is looked at again (and no cached link is trusted)
		_water_seen = _terrain.water_y
		for c in tiers.size():
			tiers[c] = _scan_column(c)
			_links[c].clear()
	var edits: Array[Rect2i] = _terrain.edit_log
	while edits_seen < edits.size():
		var rect: Rect2i = edits[edits_seen]
		edits_seen += 1
		var c0: int = maxi(0, ceili((rect.position.x - X_MIN) / STEP))
		var c1: int = mini(tiers.size() - 1, floori((rect.end.x - 1 - X_MIN) / STEP))
		for c in range(c0, c1 + 1):
			tiers[c] = _scan_column(c)
		for c in range(maxi(0, c0 - 2), mini(tiers.size() - 1, c1 + 2) + 1):
			_links[c].clear()


## True when a terrain edit made after `stamp` (a value of edits_seen / TerrainSim.edit_log.size()) touches the path (within a small margin).
func edits_hit_path(stamp: int, path: Array[Vector2]) -> bool:
	var edits: Array[Rect2i] = _terrain.edit_log
	for k in range(stamp, edits.size()):
		var rect: Rect2 = Rect2(edits[k]).grow(14.0)
		for i in path.size():
			var a: Vector2 = path[i]
			var b: Vector2 = path[maxi(0, i - 1)]
			if rect.intersects(Rect2(minf(a.x, b.x), minf(a.y, b.y) - BODY_HIGH, absf(a.x - b.x), absf(a.y - b.y) + BODY_HIGH), true):
				return true
	return false


func _col(x: float) -> int:
	return clampi(roundi((x - X_MIN) / STEP), 0, tiers.size() - 1)


## Tier index of column `col` whose surface is closest to `y` (-1 when the column has none).
func _tier(col: int, y: float) -> int:
	var best: int = -1
	for i in tiers[col].size():
		if best < 0 or absf(tiers[col][i] - y) < absf(tiers[col][best] - y):
			best = i
	return best


## Nodes reachable in one step from (or, when `reverse`, from which one can reach) node `cur`. A node is column * 8 + tier.
func _neighbors(cur: int, leap: bool, reverse: bool) -> Array[int]:
	var out: Array[int] = []
	var c: int = cur >> 3
	var y: float = tiers[c][cur & 7]
	for dc in LINK_DIRS:
		var c2: int = c + dc
		if c2 < 0 or c2 >= tiers.size():
			continue
		for t2 in tiers[c2].size():
			var d: float = tiers[c2][t2] - y
			if reverse:
				d = -d
			if d <= MAX_DROP and d >= -(MAX_LEAP if leap else MAX_CLIMB):
				var ok: bool
				if reverse:
					ok = _passable_cached(c2, tiers[c2][t2], c, int(y))
				else:
					ok = _passable_cached(c, int(y), c2, tiers[c2][t2])
				if ok:
					out.append(c2 * 8 + t2)
	return out


const LINK_DIRS: Array[int] = [-1, 1]


## `_passable` answered from the per-column cache.
func _passable_cached(ca: int, ya: int, cb: int, yb: int) -> bool:
	var cache: Dictionary = _links[ca]
	var key: int = (ya << 20) | (cb << 10) | yb
	if cache.has(key):
		return cache[key]
	var ok: bool = _passable(ca, ya, cb, yb)
	cache[key] = ok
	return ok


func _free(x: int, y: int) -> bool:
	return not _terrain.is_solid(x, y)


## True when a body can go from the surface point (column ca, y ya) to the one of the adjacent column cb without crossing rock:
## a walk (slope) is checked along the segment at body height, a climb up a wall along the vertical corridor of the wall face and over its lip,
## a drop along the lip of the upper surface and the vertical shaft of the lower column.
func _passable(ca: int, ya: int, cb: int, yb: int) -> bool:
	if not strict_map:
		return true
	var xa: int = int(X_MIN) + ca * int(STEP)
	var xb: int = int(X_MIN) + cb * int(STEP)
	var dx: int = signi(xb - xa)
	var d: int = yb - ya
	if absi(d) <= int(WALL_STEP):
		var x: int = xa
		while true:
			var t: float = float(x - xa) / float(xb - xa)
			var yl: int = ya + roundi(d * t)
			if not _free(x, yl - int(BODY_LOW)) or not _free(x, yl - int(BODY_HIGH)):
				return false
			if x == xb:
				break
			x = mini(xb, x + PROBE) if dx > 0 else maxi(xb, x - PROBE)
		return true
	if d < 0:
		# wall: the corridor in front of the face up to the lip, then the lip itself
		var y: int = ya - int(BODY_LOW)
		while y > yb - int(BODY_HIGH):
			if not _free(xa, y):
				return false
			y -= 3
		return _lip_free(xa, xb, yb)
	# drop: walk to the edge on the upper surface, then down the shaft of the lower column
	if not _lip_free(xa, xb, ya):
		return false
	var y2: int = ya - int(BODY_HIGH)
	while y2 < yb - int(BODY_LOW):
		if not _free(xb, y2):
			return false
		y2 += 3
	return true


## True when the rows a body occupies above the surface y between columns xa and xb are free.
func _lip_free(xa: int, xb: int, y: int) -> bool:
	var x: int = xa
	var dx: int = signi(xb - xa)
	while true:
		if not _free(x, y - int(BODY_LOW)) or not _free(x, y - int(BODY_HIGH)):
			return false
		if x == xb:
			return true
		x = mini(xb, x + PROBE) if dx > 0 else maxi(xb, x - PROBE)
	return true


## Start node for a search from `from`. `strict`: the surface must be within reach of a body standing there (a fighter's centre is ~8 px above its
## surface), so a critter inside a tunnel or hanging in the air gets no start rather than the nearest unrelated tier.
func _start_node(from: Vector2, strict: bool = false) -> int:
	sync()
	var col: int = _col(from.x)
	var tier: int = _tier(col, from.y + 10.0)
	if tier >= 0 and strict and (tiers[col][tier] < from.y - 12.0 or tiers[col][tier] > from.y + 40.0):
		return -1
	return -1 if tier < 0 else col * 8 + tier


func _point(node: int) -> Vector2:
	return Vector2((node >> 3) * STEP + X_MIN, tiers[node >> 3][node & 7])


## Waypoints (surface points) of a path from `from` to `to`, or empty when none exists.
## `leap`: the walker can also clear walls up to MAX_LEAP (ants); eggs cannot.
## `from`/`to` are points on or just above a surface (a fighter's centre works).
func find_path(from: Vector2, to: Vector2, leap: bool, reach: float = 24.0, strict: bool = false) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var start: int = _start_node(from, strict)
	if start < 0:
		return out
	var prev: Dictionary = {start: -1}
	var queue: Array[int] = [start]
	var head: int = 0
	var goal: int = -1
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		var p: Vector2 = _point(cur)
		if absf(p.x - to.x) <= reach and absf(p.y - (to.y + 10.0)) <= 46.0:
			goal = cur
			break
		for n in _neighbors(cur, leap, false):
			if not prev.has(n):
				prev[n] = cur
				queue.append(n)
	if goal < 0:
		return out
	var node: int = goal
	while node != -1:
		out.push_front(_point(node))
		node = prev[node]
	return out


## Distance (in columns) from `start` to every node it reaches (`reverse`: every node that reaches it).
func _bfs(start: int, leap: bool, reverse: bool) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var queue: Array[int] = [start]
	var head: int = 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		for n in _neighbors(cur, leap, reverse):
			if not dist.has(n):
				dist[n] = int(dist[cur]) + 1
				queue.append(n)
	return dist


## Every surface point a walker starting at `from` can reach (`reverse`: every point from which `from` can be reached),
## as Vector3(x, surface_y, walking distance in px). The start itself is included.
func reachable(from: Vector2, leap: bool, reverse: bool = false) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var start: int = _start_node(from)
	if start < 0:
		return out
	var dist: Dictionary = _bfs(start, leap, reverse)
	for n in dist:
		var p: Vector2 = _point(n)
		out.append(Vector3(p.x, p.y, int(dist[n]) * STEP))
	return out


## The node whose surface is the closest to (x, sy) within 16 px, -1 when there is none.
func node_at(x: float, sy: float) -> int:
	sync()
	var col: int = _col(x)
	var tier: int = _tier(col, sy)
	return -1 if tier < 0 or absf(tiers[col][tier] - sy) > 16.0 else col * 8 + tier


## Width (px) between the leftmost and the rightmost column of a set of nodes.
static func node_span(nodes: Dictionary) -> float:
	var lo: int = 1 << 30
	var hi: int = -1
	for n in nodes:
		lo = mini(lo, int(n) >> 3)
		hi = maxi(hi, int(n) >> 3)
	return 0.0 if hi < 0 else (hi - lo) * STEP


## The biggest stretch of ground (within the arena) that leaping walkers can cross both ways, as {node: true}: where squads belong.
## Caves and pockets that rock or cliffs close in are not part of it. Empty when the map has no ground at all.
func main_ground(arena_x0: float, arena_x1: float) -> Dictionary:
	var best: Dictionary = {}
	var seen: Dictionary = {}
	var total: int = 0
	for t in tiers:
		total += t.size()
	var c0: int = _col(arena_x0)
	var c1: int = _col(arena_x1)
	var mid: int = floori((c0 + c1) / 2.0)
	var cols: Array[int] = []
	var k: int = 0
	while mid - k * 12 >= c0 or mid + k * 12 <= c1:
		if mid + k * 12 <= c1:
			cols.append(mid + k * 12)
		if k > 0 and mid - k * 12 >= c0:
			cols.append(mid - k * 12)
		k += 1
	for col in cols:
		for t in tiers[col].size():
			var start: int = col * 8 + t
			if seen.has(start):
				continue
			var fwd: Dictionary = _bfs(start, true, false)
			for n in fwd:
				seen[n] = true
			var back: Dictionary = _bfs(start, true, true)
			var both: Dictionary = {}
			for n in fwd:
				if back.has(n):
					both[n] = true
			if both.size() > best.size():
				best = both
		if best.size() * 2 > total:
			break
	return best


## Length in pixels of a path found by find_path (INF when empty).
static func path_length(path: Array[Vector2]) -> float:
	return INF if path.is_empty() else path.size() * STEP

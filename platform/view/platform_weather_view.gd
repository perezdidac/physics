## Weather of the storm levels, drawn in world space in front of the actors: layered rain streaks that splash on the ground,
## warning shadows under the big falling drops, wind streaks and blowing leaves inside the wind zones and in gusts, and the
## white flash of lightning. Everything is cosmetic: the sim owns the wind, the drops and the damage.
class_name PlatformWeatherView
extends Node2D

const RAIN_COUNT: int = 150
const LEAF_COUNT: int = 7
const STREAKS_PER_ZONE: int = 9
const LEAF_COLORS: Array[String] = ["#8fa53a", "#b58a2e", "#6e8b34", "#a8662a"]
const GUST_TIME: float = 1.6

var sim: PlatformSim = null
var layout: PlatformLayout = null
var t_now: float = 0.0
var view_rect: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
## Lightning brightness 0..1 (also read by the backdrop).
var flash: float = 0.0
## True on levels with a storm: rain and lightning.
var storm: bool = false
## Camera nudge in pixels while a gust blows (read by the screen).
var nudge: Vector2 = Vector2.ZERO

var _drops: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []
var _gust_dir: int = 0
var _gust_t: float = 99.0
var _next_bolt: float = 6.0
var _flash_t: float = 99.0
var _rng := RandomNumberGenerator.new()
var _zones: Array[Rect2] = []
var _zone_phase: Array[float] = []
var _solid_tops: Array[Rect2] = []


## Binds the level: reads the storm flag and the wind zones, and scatters the rain.
func setup(p_sim: PlatformSim, p_layout: PlatformLayout) -> void:
	sim = p_sim
	layout = p_layout
	_rng.seed = 4242
	storm = layout.storm
	_zones = layout.wind_zones
	_zone_phase.clear()
	_zone_phase.resize(_zones.size())
	_zone_phase.fill(0.0)
	_solid_tops.clear()
	_solid_tops.append_array(layout.solids)
	_solid_tops.append_array(layout.platforms)
	_drops.clear()
	if storm:
		for i in RAIN_COUNT:
			_drops.append(_new_drop(true))
	_next_bolt = 5.0 + _rng.randf() * 5.0
	_flash_t = 99.0
	flash = 0.0
	_gust_t = 99.0
	queue_redraw()


## True when anything has to be drawn (storm, wind zones).
func is_active() -> bool:
	return storm or not _zones.is_empty()


## Starts a gust blowing to `dir` (-1 or 1): a burst of leaves and streaks, and a small camera nudge.
func gust(dir: int) -> void:
	_gust_dir = -1 if dir < 0 else 1
	_gust_t = 0.0


## Currently running splashes (for tests).
func splash_count() -> int:
	return _splashes.size()


## Gust in progress (for tests).
func gusting() -> bool:
	return _gust_t < GUST_TIME


## A splash from the sim at `pos`: "RAIN" (a big drop hit the ground), "PUDDLE" or "HIT" (a drop hit Perleta).
func add_splash(pos: Vector2, kind: String) -> void:
	_splashes.append({"p": pos, "life": 0.0, "big": true, "kind": kind})


## Starts a lightning flash now (tests and captures; the weather also does it by itself from time to time).
func lightning() -> void:
	_flash_t = 0.0


## Advances the weather by `dt` seconds.
func update(dt: float) -> void:
	if layout == null:
		return
	if storm:
		_update_rain(dt)
		_next_bolt -= dt
		if _next_bolt <= 0.0:
			_next_bolt = 7.0 + _rng.randf() * 9.0
			_flash_t = 0.0
	for i in _zones.size():
		_zone_phase[i] += dt * clampf(absf(sim.wind_strength(i)) / 400.0, 0.25, 1.6)
	_flash_t += dt
	# a double flash: a quick strong one, a pause, a softer one
	flash = maxf(_pulse(_flash_t, 0.0, 0.07, 0.22), _pulse(_flash_t, 0.17, 0.05, 0.3) * 0.6)
	_gust_t += dt
	if _gust_t < GUST_TIME:
		var k: float = sin(clampf(_gust_t / GUST_TIME, 0.0, 1.0) * PI)
		nudge = Vector2(float(_gust_dir) * 14.0 * k, -3.0 * k)
	else:
		nudge = Vector2.ZERO
	var live: Array[Dictionary] = []
	for s in _splashes:
		s["life"] = float(s["life"]) + dt
		if float(s["life"]) < 0.35:
			live.append(s)
	_splashes = live
	queue_redraw()


static func _pulse(t: float, start: float, rise: float, fall: float) -> float:
	if t < start or t > start + rise + fall:
		return 0.0
	var u: float = t - start
	return u / rise if u < rise else 1.0 - (u - rise) / fall


func _new_drop(anywhere: bool) -> Dictionary:
	var layer: int = _rng.randi() % 3
	var d: Dictionary = {
		"fx": _rng.randf(), "fy": _rng.randf() if anywhere else 0.0, "layer": layer,
		"len": 10.0 + 9.0 * float(layer) + _rng.randf() * 5.0,
		"speed": 520.0 + 230.0 * float(layer) + _rng.randf() * 90.0,
		"ground": -1.0, "x": 0.0, "y": 0.0,
	}
	d["x"] = view_rect.position.x + float(d["fx"]) * view_rect.size.x
	d["y"] = view_rect.position.y + float(d["fy"]) * view_rect.size.y
	d["ground"] = _ground_below(float(d["x"]), float(d["y"]))
	return d


## Top of the first solid or needle under (x, y), or -1 when there is none.
func _ground_below(x: float, y: float) -> float:
	var best: float = -1.0
	for r in _solid_tops:
		if x >= r.position.x and x <= r.end.x and r.position.y >= y - 4.0 and (best < 0.0 or r.position.y < best):
			best = r.position.y
	return best


func _slant() -> float:
	return 0.28 + 0.12 * float(_gust_dir) * (1.0 - clampf(_gust_t / GUST_TIME, 0.0, 1.0))


func _update_rain(dt: float) -> void:
	var slant: float = _slant()
	var vr: Rect2 = view_rect.grow(40.0)
	for i in _drops.size():
		var d: Dictionary = _drops[i]
		var sp: float = float(d["speed"])
		var x: float = float(d["x"]) + sp * slant * dt
		var y: float = float(d["y"]) + sp * dt
		var ground: float = float(d["ground"])
		var landed: bool = ground >= 0.0 and y >= ground
		var out_x: bool = x < vr.position.x or x > vr.end.x
		if landed and int(d["layer"]) > 0 and vr.has_point(Vector2(x, ground)):
			_splashes.append({"p": Vector2(x, ground), "life": 0.0, "big": int(d["layer"]) == 2})
		if landed or y > vr.end.y or out_x:
			var nd: Dictionary = _new_drop(false)
			nd["y"] = vr.position.y - _rng.randf() * 60.0
			nd["x"] = vr.position.x + _rng.randf() * vr.size.x
			nd["ground"] = _ground_below(float(nd["x"]), float(nd["y"]))
			_drops[i] = nd
		else:
			d["x"] = x
			d["y"] = y


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if layout == null:
		return
	var view: Rect2 = view_rect.grow(60.0)
	for i in _zones.size():
		if _zones[i].intersects(view):
			_draw_zone(i)
	if _gust_t < GUST_TIME:
		_draw_gust(view)
	if storm:
		_draw_rain()
		for dr in sim.drops:
			_draw_big_drop(dr)
		for s in _splashes:
			_draw_splash(s)
	if flash > 0.0:
		draw_rect(view_rect.grow(4.0), Color(0.88, 0.93, 1.0, 0.55 * flash))


func _draw_rain() -> void:
	var slant: float = _slant()
	var dir := Vector2(slant, 1.0).normalized()
	for d in _drops:
		var layer: int = int(d["layer"])
		var p := Vector2(float(d["x"]), float(d["y"]))
		var ground: float = float(d["ground"])
		var ln: float = float(d["len"])
		if ground >= 0.0 and p.y + ln * dir.y > ground:
			ln = maxf(0.0, ground - p.y) / dir.y
		if ln < 1.0:
			continue
		var alpha: float = 0.22 + 0.16 * float(layer)
		draw_line(p, p - dir * ln, Color(0.82, 0.9, 1.0, alpha), 1.0 + 0.5 * float(layer), true)


## A fat drop with its warning shadow growing on the surface it will hit.
func _draw_big_drop(dr: PlatformDrop) -> void:
	var p: Vector2 = dr.pos
	if not is_inf(dr.ground_y):
		var near: float = 1.0 - clampf((dr.ground_y - p.y) / 360.0, 0.0, 1.0)
		var gp := Vector2(p.x, dr.ground_y)
		ViewUtil.fill_ellipse(self, gp, 6.0 + 10.0 * near, 1.8 + 2.4 * near, Color(0.05, 0.1, 0.2, 0.18 + 0.35 * near))
		ViewUtil.stroke_ellipse(self, gp, 8.0 + 12.0 * near, 2.4 + 3.0 * near, Color(1.0, 0.45, 0.35, 0.25 + 0.5 * near), 1.2)
	var r: float = dr.radius
	draw_colored_polygon(_teardrop(p, r), Color(0.55, 0.78, 1.0, 0.85))
	draw_polyline(_closed_loop(_teardrop(p, r)), Color(0.9, 0.97, 1.0, 0.95), 1.4, true)
	ViewUtil.fill_ellipse(self, p + Vector2(-r * 0.35, r * 0.1), r * 0.22, r * 0.4, Color(1.0, 1.0, 1.0, 0.8), 0.3)


static func _teardrop(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 21:
		var a: float = float(k) / 20.0 * TAU
		var px: float = sin(a) * r
		var py: float = -cos(a) * r
		if py < 0.0:
			px *= 1.0 - (-py / r) * 0.85
			py *= 2.2
		pts.append(c + Vector2(px, py))
	return pts


static func _closed_loop(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out


func _draw_splash(s: Dictionary) -> void:
	var k: float = float(s["life"]) / 0.35
	var p: Vector2 = s["p"]
	var a: float = 1.0 - k
	var col := Color(0.85, 0.93, 1.0, 0.7 * a)
	var hit: bool = str(s.get("kind", "")) == "HIT"
	var r: float = (2.0 + 7.0 * k) * (2.2 if hit else 1.0)
	ViewUtil.stroke_ellipse(self, p, r, r * 0.3, col, 1.0)
	if bool(s["big"]):
		for sgn: float in [-1.0, 1.0]:
			var tip: Vector2 = p + Vector2(sgn * (3.0 + 6.0 * k) * (2.0 if hit else 1.0), -9.0 * sin(k * PI) * (1.8 if hit else 1.0))
			draw_line(p, tip, col, 1.2, true)


func _draw_zone(i: int) -> void:
	var zone: Rect2 = _zones[i]
	var force: float = sim.wind_strength(i)
	var base: float = layout.wind_force[i] if i < layout.wind_force.size() else 1.0
	var dir: float = 1.0 if base >= 0.0 else -1.0
	# a gusting zone is calm for part of its period: its streaks slow down and fade
	var power: float = clampf(absf(force) / 400.0, 0.25, 1.6)
	var calm: float = clampf(absf(force) / maxf(absf(base), 1.0), 0.15, 1.0)
	# a faint airy tint so the zone reads as a place, strongest at the edge the wind enters
	var tint := Color(0.85, 0.95, 1.0, 0.0)
	var tint2 := Color(0.85, 0.95, 1.0, 0.07 * calm)
	var left: Color = tint if dir > 0.0 else tint2
	var right: Color = tint2 if dir > 0.0 else tint
	draw_polygon(PackedVector2Array([zone.position, Vector2(zone.end.x, zone.position.y), zone.end, Vector2(zone.position.x, zone.end.y)]), PackedColorArray([left, right, right, left]))
	for k in STREAKS_PER_ZONE:
		var fk: float = float(k)
		var h1: float = fposmod(sin(fk * 12.9898 + float(i) * 4.1) * 43758.5453, 1.0)
		var h2: float = fposmod(sin(fk * 78.233 + float(i) * 1.7) * 24634.6345, 1.0)
		var spd: float = 160.0 + 220.0 * h2
		var x: float = zone.position.x + fposmod(h1 * zone.size.x + dir * _zone_phase[i] * spd, zone.size.x)
		var y: float = zone.position.y + zone.size.y * (0.08 + 0.84 * h2) + sin(t_now * 2.0 + fk) * 5.0
		var ln: float = (34.0 + 50.0 * h1) * power
		var edge: float = minf(minf(x - zone.position.x, zone.end.x - x) / 40.0, 1.0)
		_wind_line(Vector2(x, y), dir, ln, 0.38 * edge * calm)
	for k in LEAF_COUNT:
		_draw_leaf(zone, dir, k, i)


## A streak of wind: a soft tapering stroke with a gentle wave.
func _wind_line(p: Vector2, dir: float, ln: float, alpha: float) -> void:
	var n: int = 6
	for k in n:
		var u0: float = float(k) / float(n)
		var u1: float = float(k + 1) / float(n)
		var a0: Vector2 = p - Vector2(dir * ln * u0, sin(p.x * 0.04 + u0 * 4.0) * 3.0)
		var a1: Vector2 = p - Vector2(dir * ln * u1, sin(p.x * 0.04 + u1 * 4.0) * 3.0)
		draw_line(a0, a1, Color(0.95, 0.98, 1.0, alpha * (1.0 - u0)), 1.4, true)


func _draw_leaf(zone: Rect2, dir: float, k: int, zone_idx: int) -> void:
	var fk: float = float(k)
	var spd: float = 110.0 + 30.0 * fk
	var x: float = zone.position.x + fposmod(fk * 137.0 + float(zone_idx) * 59.0 + dir * _zone_phase[zone_idx] * spd, zone.size.x)
	var y: float = zone.position.y + zone.size.y * (0.2 + 0.6 * fposmod(fk * 0.37, 1.0)) + sin(t_now * 3.0 + fk * 2.0) * 16.0
	_leaf(Vector2(x, y), t_now * (3.0 + fk * 0.4) + fk, 1.0, LEAF_COLORS[k % LEAF_COLORS.size()], 0.9)


func _leaf(p: Vector2, rot: float, size: float, hex: String, alpha: float) -> void:
	var col: Color = ViewColors.h(hex)
	col.a = alpha
	ViewUtil.fill_ellipse(self, p, 5.0 * size, 2.4 * size, col, rot)
	draw_line(p - Vector2(cos(rot), sin(rot)) * 5.0 * size, p + Vector2(cos(rot), sin(rot)) * 5.0 * size, Color(0.2, 0.15, 0.05, alpha * 0.6), 0.8, true)


func _draw_gust(view: Rect2) -> void:
	var k: float = _gust_t / GUST_TIME
	var env: float = sin(clampf(k, 0.0, 1.0) * PI)
	var dir: float = float(_gust_dir)
	for n in 16:
		var fn: float = float(n)
		var h: float = fposmod(sin(fn * 12.9898) * 43758.5453, 1.0)
		var span: float = view.size.x + 300.0
		var x: float = view.position.x + fposmod(h * span + dir * _gust_t * 900.0 * (0.8 + 0.4 * fposmod(fn * 0.31, 1.0)), span) - 150.0
		var y: float = view.position.y + view.size.y * (0.1 + 0.8 * fposmod(fn * 0.173 + h, 1.0))
		_wind_line(Vector2(x, y), dir, 90.0 + 80.0 * h, 0.55 * env)
	for n in 12:
		var fn: float = float(n)
		var h: float = fposmod(sin(fn * 37.719) * 12345.678, 1.0)
		var x: float = view.position.x + fposmod(h * view.size.x + dir * _gust_t * 700.0 * (0.7 + 0.5 * h), view.size.x)
		var y: float = view.position.y + view.size.y * (0.15 + 0.7 * fposmod(fn * 0.211 + h * 0.5, 1.0)) + sin(_gust_t * 5.0 + fn) * 22.0
		_leaf(Vector2(x, y), _gust_t * (5.0 + fn * 0.3) + fn, 1.3, LEAF_COLORS[n % LEAF_COLORS.size()], env)

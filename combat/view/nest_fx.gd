## Effects of the NEST stage: the timers the nest art animates by (hit shake, repair strands, the HP the drawing shows), silk flakes when the
## nest is hit, the pole (the telegraphed band and the slam that sweeps it), and the cold of a frosty level (frost on the screen edges and
## falling snowflakes). Owned by CombatView; CombatScreen feeds it the nest_hit, pole_warn and pole_sweep signals.
class_name NestFx
extends RefCounted

const REPAIR_TIME: float = 1.5
const HIT_TIME: float = 0.45
const SWEEP_TIME: float = 1.1
## Seconds the pole needs to come down from the top of the screen.
const SLAM_TIME: float = 0.16
const POLE_WOOD: Color = Color("#8d5a2b")
const POLE_DARK: Color = Color("#4a2d14")
const HAZARD: Color = Color("#ff9a2e")

## Seconds left of the hit shake and of the repair animation.
var hit_t: float = 0.0
var repair_t: float = 0.0
## The nest HP fraction the drawing shows: it drops at once and climbs slowly while the repair strands are woven.
var shown_frac: float = 1.0
var flakes: Array[Dictionary] = []
## The slam that is playing: {band: Rect2, t: float}; empty when none.
var sweep: Dictionary = {}
var _last_hp: float = -1.0
var _rng := RandomNumberGenerator.new()


func clear() -> void:
	hit_t = 0.0
	repair_t = 0.0
	shown_frac = 1.0
	flakes.clear()
	sweep = {}
	_last_hp = -1.0


## The nest was hit at `pos`: it shakes and silk flakes fly off.
func on_hit(pos: Vector2, damage: int) -> void:
	hit_t = HIT_TIME
	for i in clampi(int(float(damage) / 6.0) + 3, 3, 14):
		var a: float = _rng.randf_range(-PI, 0.0)
		flakes.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * _rng.randf_range(30.0, 130.0), "t": 0.0, "life": _rng.randf_range(0.6, 1.3), "size": _rng.randf_range(2.0, 4.5)})


## The pole comes down on `band` (the level pole and the boss LINE attack).
func on_sweep(band: Rect2) -> void:
	sweep = {"band": band, "t": 0.0}
	for i in 14:
		var cx: float = band.position.x + band.size.x * 0.5
		flakes.append({"pos": Vector2(cx + _rng.randf_range(-band.size.x * 0.4, band.size.x * 0.4), 0.0), "vel": Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-130.0, -30.0)), "t": -SLAM_TIME, "life": 0.9, "size": _rng.randf_range(3.0, 6.0), "dust": true})


func update(dt: float, ctx: ViewCtx) -> void:
	hit_t = maxf(0.0, hit_t - dt)
	repair_t = maxf(0.0, repair_t - dt)
	if ctx.nest != null:
		var hp: float = ViewUtil.gf(ctx.nest, "hp")
		if _last_hp >= 0.0 and hp > _last_hp + 0.5:
			repair_t = REPAIR_TIME
		_last_hp = hp
		if ctx.nest_frac < shown_frac:
			shown_frac = ctx.nest_frac
		else:
			shown_frac = minf(ctx.nest_frac, shown_frac + dt / REPAIR_TIME * 0.4)
	else:
		_last_hp = -1.0
		shown_frac = 1.0
	if not sweep.is_empty():
		sweep["t"] = float(sweep["t"]) + dt
		if float(sweep["t"]) > SWEEP_TIME:
			sweep = {}
	for p in flakes:
		p["t"] = float(p["t"]) + dt
		if float(p["t"]) > 0.0:
			var v: Vector2 = p["vel"]
			v.y += 60.0 * dt
			p["vel"] = v
			p["pos"] = (p["pos"] as Vector2) + v * dt
	flakes = flakes.filter(func(p: Dictionary) -> bool: return float(p["t"]) < float(p["life"]))


# ---------------------------------------------------------------- world: the pole

func draw_world(ci: CanvasItem, ctx: ViewCtx) -> void:
	if ctx.pole_state == "WARN" and ctx.pole_band.size.x > 0.0:
		draw_band(ci, ctx, ctx.pole_band, ctx.t_now)
	if not sweep.is_empty():
		_draw_slam(ci, ctx)
	for p in flakes:
		if float(p["t"]) < 0.0:
			continue
		var k: float = float(p["t"]) / float(p["life"])
		var dust: bool = p.has("dust")
		var col: Color = Color(0.78, 0.66, 0.5, 0.8 * (1.0 - k)) if dust else Color(0.97, 0.97, 0.95, 0.9 * (1.0 - k))
		ci.draw_circle(p["pos"], float(p["size"]) * (1.0 + k * (1.5 if dust else 0.2)), col)


## The telegraphed band: a translucent orange column with warning stripes, dashed edges, a pole hanging at the top and chevrons pointing
## down. `ctx` gives the part of the world that is on screen so the stripes are only drawn there.
static func draw_band(ci: CanvasItem, ctx: ViewCtx, band: Rect2, t: float) -> void:
	var half_h: float = ctx.view_size.y * 0.5 / maxf(0.01, ctx.scale_px)
	var y0: float = maxf(band.position.y, ctx.cam_pos.y - half_h - 20.0)
	var y1: float = minf(band.end.y, ctx.cam_pos.y + half_h + 20.0)
	if y1 <= y0:
		return
	var pulse: float = 0.5 + 0.5 * sin(t * 7.0)
	var rect := Rect2(band.position.x, y0, band.size.x, y1 - y0)
	ci.draw_rect(rect, Color(HAZARD, 0.10 + 0.07 * pulse))
	var step: float = 40.0
	var y: float = floorf(y0 / step) * step
	while y < y1 + rect.size.x:
		ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y - rect.size.x * 0.6), Color(HAZARD, 0.3), 5.0, true)
		y += step
	for x in [rect.position.x, rect.end.x]:
		ViewUtil.dashed(ci, PackedVector2Array([Vector2(x, y0), Vector2(x, y1)]), 14.0, 9.0, Color(HAZARD, 0.95), 3.0)
	var cx: float = rect.get_center().x
	var cy: float = floorf(y0 / 90.0) * 90.0 + fmod(t * 60.0, 90.0)
	while cy < y1:
		if cy > y0:
			var a: float = 0.3 + 0.5 * pulse
			ci.draw_polyline(PackedVector2Array([Vector2(cx - 16.0, cy - 8.0), Vector2(cx, cy + 6.0), Vector2(cx + 16.0, cy - 8.0)]), Color(1.0, 0.55, 0.15, a), 4.0, true)
		cy += 90.0
	# the pole hovering above the band, ready to drop
	var top: float = y0 + (y1 - y0) * 0.3 + sin(t * 3.0) * 6.0
	draw_pole(ci, Vector2(cx, top), top - 600.0, 1.0)


## A forestry pole seen from the side: a long wooden shaft with rings and a heavy iron head at the lower end `tip`.
static func draw_pole(ci: CanvasItem, tip: Vector2, from_y: float, alpha: float) -> void:
	var w: float = 14.0
	ci.draw_rect(Rect2(tip.x - w * 0.5, from_y, w, tip.y - from_y - 18.0), Color(POLE_WOOD, alpha))
	ci.draw_rect(Rect2(tip.x - w * 0.5, from_y, 3.0, tip.y - from_y - 18.0), Color(1.0, 0.85, 0.6, 0.35 * alpha))
	ci.draw_rect(Rect2(tip.x + w * 0.5 - 3.0, from_y, 3.0, tip.y - from_y - 18.0), Color(POLE_DARK, 0.5 * alpha))
	var y: float = tip.y - 60.0
	while y > from_y:
		ci.draw_rect(Rect2(tip.x - w * 0.5 - 1.0, y, w + 2.0, 3.0), Color(POLE_DARK, 0.75 * alpha))
		y -= 70.0
	var head := PackedVector2Array([Vector2(tip.x - 20.0, tip.y - 22.0), Vector2(tip.x + 20.0, tip.y - 22.0), Vector2(tip.x + 15.0, tip.y), Vector2(tip.x - 15.0, tip.y)])
	ViewUtil.fill_poly(ci, head, Color("#7b8794", alpha))
	ci.draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[3], head[0]]), Color("#2a3038", alpha), 2.0, true)
	ci.draw_line(Vector2(tip.x - 10.0, tip.y - 16.0), Vector2(tip.x + 4.0, tip.y - 16.0), Color(1.0, 1.0, 1.0, 0.5 * alpha), 2.0, true)


func _draw_slam(ci: CanvasItem, ctx: ViewCtx) -> void:
	var band: Rect2 = sweep["band"]
	var t: float = float(sweep["t"])
	var cx: float = band.get_center().x
	var ground: float = _ground_y(ctx, cx)
	var half_h: float = ctx.view_size.y * 0.5 / maxf(0.01, ctx.scale_px)
	var top: float = ctx.cam_pos.y - half_h - 80.0
	var k: float = clampf(t / SLAM_TIME, 0.0, 1.0)
	var tip_y: float = lerpf(top, ground, k * k)
	var fade: float = clampf(1.0 - (t - SLAM_TIME - 0.45) / 0.5, 0.0, 1.0)
	if t > SLAM_TIME:
		var flash: float = clampf(1.0 - (t - SLAM_TIME) / 0.35, 0.0, 1.0)
		var rect := Rect2(band.position.x, maxf(band.position.y, top), band.size.x, ground - maxf(band.position.y, top))
		ci.draw_rect(rect, Color(1.0, 0.85, 0.5, 0.35 * flash))
		var r: float = band.size.x * (0.3 + 0.7 * clampf((t - SLAM_TIME) / 0.4, 0.0, 1.0))
		ci.draw_arc(Vector2(cx, ground), r, PI, TAU, 24, Color(1.0, 0.92, 0.7, 0.8 * flash), 4.0, true)
	draw_pole(ci, Vector2(cx, tip_y), top - 400.0, fade)


static func _ground_y(ctx: ViewCtx, x: float) -> float:
	if ctx.terrain != null and ctx.terrain.has_method("find_surface_y"):
		return float(ctx.terrain.call("find_surface_y", x, 0.0))
	return ctx.water_y - 120.0


# ---------------------------------------------------------------- screen: the cold

## Frost creeping in from the edges of the screen and snowflakes falling, in screen space. Only in cold levels.
func draw_overlay(ci: CanvasItem, ctx: ViewCtx) -> void:
	if not ctx.cold_active:
		return
	var vs: Vector2 = ctx.view_size
	var t: float = ctx.t_now
	var edge: float = minf(vs.x, vs.y) * 0.24
	var cold := Color(0.72, 0.9, 1.0, 0.42)
	var none := Color(0.72, 0.9, 1.0, 0.0)
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.55, 0.75, 1.0, 0.06))
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, edge), Vector2(0, edge)]), PackedColorArray([cold, cold, none, none]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, vs.y), Vector2(vs.x, vs.y), Vector2(vs.x, vs.y - edge), Vector2(0, vs.y - edge)]), PackedColorArray([cold, cold, none, none]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, vs.y), Vector2(edge, vs.y), Vector2(edge, 0)]), PackedColorArray([cold, cold, none, none]))
	ci.draw_polygon(PackedVector2Array([Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x - edge, vs.y), Vector2(vs.x - edge, 0)]), PackedColorArray([cold, cold, none, none]))
	var arm: float = minf(vs.x, vs.y) * 0.22
	_crystals(ci, Vector2(0, 0), Vector2(1, 1), arm)
	_crystals(ci, Vector2(vs.x, 0), Vector2(-1, 1), arm)
	_crystals(ci, Vector2(0, vs.y), Vector2(1, -1), arm * 0.8)
	_crystals(ci, vs, Vector2(-1, -1), arm * 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 46:
		var x0: float = rng.randf()
		var y0: float = rng.randf()
		var sp: float = rng.randf_range(0.05, 0.12)
		var sz: float = rng.randf_range(1.6, 3.8)
		var ph: float = rng.randf_range(0.0, TAU)
		var p := Vector2(fposmod(x0 + sin(t * 0.7 + ph) * 0.03 - t * 0.012, 1.0) * vs.x, fposmod(y0 + t * sp, 1.0) * vs.y)
		if sz > 3.0:
			NestArt._flake(ci, p, sz * 1.6, Color(1.0, 1.0, 1.0, 0.8))
		else:
			ci.draw_circle(p, sz * 0.6, Color(1.0, 1.0, 1.0, 0.75))


## Ice crystals growing from a screen corner: branching lines in the direction `dir` (a diagonal), thinner at each fork.
static func _crystals(ci: CanvasItem, corner: Vector2, dir: Vector2, arm: float) -> void:
	for b in 5:
		var a: float = lerpf(0.12, PI * 0.5 - 0.12, float(b) / 4.0)
		var d := Vector2(cos(a) * dir.x, sin(a) * dir.y)
		_branch(ci, corner, d, arm * (0.7 + 0.3 * float(b % 2)), 3, 2.4)


static func _branch(ci: CanvasItem, from: Vector2, d: Vector2, length: float, depth: int, w: float) -> void:
	var to: Vector2 = from + d * length
	ci.draw_line(from, to, Color(0.9, 0.97, 1.0, 0.7), w, true)
	if depth <= 0:
		return
	var n := Vector2(-d.y, d.x)
	for k in [0.45, 0.75]:
		var p: Vector2 = from.lerp(to, float(k))
		_branch(ci, p, (d + n * 0.7).normalized(), length * 0.36, depth - 1, w * 0.6)
		_branch(ci, p, (d - n * 0.7).normalized(), length * 0.36, depth - 1, w * 0.6)

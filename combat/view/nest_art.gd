## Art of El Bolsó, the big silk nest of the NEST stage: a white-grey silky bag woven between two pine branches, with the dark
## silhouettes of the sleeping caterpillars inside. The silk tears as the nest loses HP (holes with dangling strands), new bright strands
## grow over it while it is repaired, and a caterpillar outside the nest in a cold level gets a frozen tint. Pure drawing: it reads the
## ViewCtx and the NestFx timers. `draw_back` goes under the fighters, `draw_front` over them (a thin veil, so the sheltered ones show).
class_name NestArt
extends RefCounted

const SILK: Color = Color("#e9e7e1")
const SILK_SHADE: Color = Color("#a9aeb8")
const SILK_DARK: Color = Color("#5d6370")
const INSIDE: Color = Color("#9c8468")
const BARK: Color = Color("#5b3b24")
const BARK_LIGHT: Color = Color("#7d5535")
const NEEDLE: Color = Color("#2f5d3a")
const ICE: Color = Color("#bfe6ff")
## Where the tears go on the bag, as fractions of its half size (x, y) and their size; they appear in this order as the nest wears down.
const TEARS: Array[Vector3] = [Vector3(0.38, -0.12, 17.0), Vector3(-0.42, 0.22, 15.0), Vector3(0.05, 0.38, 19.0), Vector3(-0.22, -0.34, 13.0), Vector3(0.55, 0.30, 14.0), Vector3(-0.60, -0.05, 12.0)]
const SIDES: int = 28
## Sprites (assets/sprites/scene/): the bag is a 256 x 176 drawing whose body spans (8, 8)-(248, 168), stretched over the nest rectangle.
const SPRITE_BAG := Vector2(240.0, 160.0)
const SPRITE_SIZE := Vector2(256.0, 176.0)
## The branch drawing (256 x 128): the tip where it meets the bag and the root where it leaves the tree.
const BRANCH_SIZE := Vector2(256.0, 128.0)
const BRANCH_TIP := Vector2(16.0, 100.0)
const BRANCH_ROOT := Vector2(240.0, 28.0)

static var _textures: Dictionary = {}


## A scene sprite by file name (cached; null when missing so the vector drawing is used).
static func _tex(name: String) -> Texture2D:
	if not _textures.has(name):
		var p: String = "res://assets/sprites/scene/%s.svg" % name
		_textures[name] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _textures[name]


## Draws one bag sprite stretched over a body of `size` centred on `c`.
static func _bag_sprite(ci: CanvasItem, tex: Texture2D, c: Vector2, size: Vector2, mod: Color = Color.WHITE) -> void:
	ci.draw_set_transform_matrix(Transform2D(0.0, size / SPRITE_BAG, 0.0, c))
	ci.draw_texture_rect(tex, Rect2(-SPRITE_SIZE * 0.5, SPRITE_SIZE), false, mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- the bag

## Outline of the bag: narrow where it hangs from the branch, wide and round at the bottom, standing on the ground.
static func outline(c: Vector2, size: Vector2, wobble: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hw: float = size.x * 0.5
	var hh: float = size.y * 0.5
	for i in SIDES:
		var a: float = float(i) / float(SIDES) * TAU
		var py: float = sin(a)
		var u: float = (py + 1.0) * 0.5
		var wf: float = lerpf(0.38, 1.0, smoothstep(0.0, 0.62, u))
		var rag: float = 1.0 + 0.045 * sin(a * 7.0 + 1.3) + wobble * sin(a * 3.0)
		var y: float = py * hh * rag
		if py > 0.55:
			y = lerpf(y, hh * 0.98, 0.35)
		pts.append(c + Vector2(cos(a) * hw * wf * rag, y))
	return pts


static func _scaled(pts: PackedVector2Array, c: Vector2, k: float, off: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * k + off)
	return out


## The part of the nest that goes under the caterpillars.
static func draw_back(ci: CanvasItem, ctx: ViewCtx, fx: NestFx) -> void:
	if ctx.nest == null:
		return
	if ctx.nest_destroyed:
		_draw_fallen(ci, ctx)
		return
	var rect: Rect2 = ctx.nest_rect
	var t: float = ctx.t_now
	var shake: Vector2 = Vector2(sin(t * 63.0), cos(t * 51.0)) * 2.5 * fx.hit_t
	var c: Vector2 = rect.get_center() + shake
	_draw_branches(ci, rect, shake, ctx.cold_active)
	var frac: float = fx.shown_frac
	var sag: float = (1.0 - frac) * 0.06
	var body: PackedVector2Array = outline(c, rect.size * Vector2(1.0, 1.0 - sag * 0.5), sag * 0.4)
	# a soft shadow on the ground, then the dark inside that the silhouettes sit in
	ViewUtil.fill_ellipse(ci, Vector2(c.x, rect.end.y + 1.5), rect.size.x * 0.58, 6.0, Color(0.0, 0.0, 0.0, 0.22))
	var inside: Texture2D = _tex("nest_inside")
	var silk: Texture2D = _tex("nest_silk")
	var bsize: Vector2 = rect.size * Vector2(1.0, 1.0 - sag * 0.5)
	if inside != null and silk != null:
		_bag_sprite(ci, inside, c, bsize, Color.WHITE.lerp(Color(0.8, 0.78, 0.82), (1.0 - frac) * 0.6))
		_draw_sleepers(ci, c, rect.size, t, ctx.cold_active)
		_bag_sprite(ci, silk, c, bsize)
		if fx.hit_t > 0.0:
			ViewUtil.fill_poly(ci, body, Color(1.0, 0.35, 0.25, 0.32 * clampf(fx.hit_t * 2.0, 0.0, 1.0)))
		_draw_tears(ci, c, rect.size, frac)
	else:
		ViewUtil.fill_poly(ci, body, SILK_SHADE.lerp(SILK_DARK, 0.5 + (1.0 - frac) * 0.2))
		ViewUtil.fill_poly(ci, _scaled(body, c, 0.93), INSIDE)
		_draw_sleepers(ci, c, rect.size, t, ctx.cold_active)
		# the silk over them: translucent layers, lighter towards the upper left
		ViewUtil.fill_poly(ci, _scaled(body, c, 0.97), Color(SILK_SHADE, 0.46))
		ViewUtil.fill_poly(ci, _scaled(body, c, 0.88, Vector2(-3.0, -4.0)), Color(SILK, 0.3))
		ViewUtil.fill_poly(ci, _scaled(body, c, 0.66, Vector2(-9.0, -11.0)), Color(1.0, 1.0, 1.0, 0.1))
		if fx.hit_t > 0.0:
			ViewUtil.fill_poly(ci, body, Color(1.0, 0.35, 0.25, 0.32 * clampf(fx.hit_t * 2.0, 0.0, 1.0)))
		_draw_weave(ci, c, rect.size, body, 0.0, Color(1.0, 1.0, 1.0, 0.5))
		_draw_tears(ci, c, rect.size, frac)
		ci.draw_polyline(_closed(body), Color(SILK_DARK, 0.85), 1.6, true)
	_draw_repair(ci, c, rect.size, fx)


## The thin veil in front of the fighters and the snow cap on the top of the bag.
static func draw_front(ci: CanvasItem, ctx: ViewCtx) -> void:
	if ctx.nest == null or ctx.nest_destroyed:
		return
	var rect: Rect2 = ctx.nest_rect
	var c: Vector2 = rect.get_center()
	var body: PackedVector2Array = outline(c, rect.size)
	var veil: Texture2D = _tex("nest_veil")
	if veil != null:
		_bag_sprite(ci, veil, c, rect.size)
	else:
		ViewUtil.fill_poly(ci, _scaled(body, c, 0.94), Color(SILK, 0.13))
		_draw_weave(ci, c, rect.size, body, 1.7, Color(1.0, 1.0, 1.0, 0.42))
	if ctx.cold_active:
		_draw_snow_cap(ci, rect)


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out


## Criss-crossing strands over the bag, clipped to its outline by building each from points that lie inside it.
static func _draw_weave(ci: CanvasItem, c: Vector2, size: Vector2, body: PackedVector2Array, phase: float, col: Color) -> void:
	var hw: float = size.x * 0.5
	var hh: float = size.y * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 41 + int(phase * 10.0)
	for i in 15:
		var a0: float = rng.randf_range(0.0, TAU)
		var a1: float = a0 + rng.randf_range(1.1, 2.6)
		var arc := PackedVector2Array()
		var bend: float = rng.randf_range(0.45, 0.95)
		for k in 9:
			var a: float = lerpf(a0, a1, float(k) / 8.0)
			var q: Vector2 = c + Vector2(cos(a) * hw * bend * lerpf(0.55, 1.0, (sin(a) + 1.0) * 0.5), sin(a) * hh * bend)
			if Geometry2D.is_point_in_polygon(q, body):
				arc.append(q)
			elif arc.size() >= 2:
				ci.draw_polyline(arc, col, 0.9, true)
				arc = PackedVector2Array()
			else:
				arc = PackedVector2Array()
		if arc.size() >= 2:
			ci.draw_polyline(arc, col, 0.9, true)


## Dark caterpillar shapes (a chain of little blobs) curled up inside, slowly breathing; a pair of eyes peeks out of the biggest one.
static func _draw_sleepers(ci: CanvasItem, c: Vector2, size: Vector2, t: float, cold: bool) -> void:
	var specs: Array[Vector4] = [Vector4(-0.28, 0.05, 0.9, 0.0), Vector4(0.2, -0.05, -0.8, 1.7), Vector4(-0.05, 0.38, 0.6, 3.1), Vector4(0.34, 0.33, -1.0, 4.4), Vector4(-0.42, 0.36, 1.0, 5.3)]
	for sp in specs:
		var base := Vector2(c.x + sp.x * size.x * 0.5, c.y + sp.y * size.y * 0.5)
		var dir: float = signf(sp.z)
		var breath: float = sin(t * (1.3 if not cold else 3.2) + sp.w)
		for k in 5:
			var off := Vector2(float(k) * 8.0 * dir, sin(float(k) * 1.1 + sp.w) * 3.0 + breath * 0.8)
			ci.draw_circle(base + off, 5.6 - float(k) * 0.3 + breath * 0.25, Color(0.07, 0.07, 0.1, 0.9))
			ci.draw_circle(base + off + Vector2(-1.0, -2.0), 2.2, Color(0.28, 0.27, 0.34, 0.5))
	var head := Vector2(c.x - 0.28 * size.x * 0.5, c.y + 0.05 * size.y * 0.5)
	if fmod(t * 0.4, 6.0) > 0.25:
		ci.draw_circle(head + Vector2(-1.5, -1.5), 1.2, Color(1.0, 0.9, 0.55, 0.9))
		ci.draw_circle(head + Vector2(2.5, -1.5), 1.2, Color(1.0, 0.9, 0.55, 0.9))


## Holes in the silk: the torn edge, the dark inside, and strands hanging from the rim. More of them as the HP goes down.
static func _draw_tears(ci: CanvasItem, c: Vector2, size: Vector2, frac: float) -> void:
	var n: int = clampi(ceili((1.0 - frac) * float(TEARS.size()) - 0.05), 0, TEARS.size())
	for i in n:
		var sp: Vector3 = TEARS[i]
		var p := Vector2(c.x + sp.x * size.x * 0.5, c.y + sp.y * size.y * 0.5)
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + i * 17
		var ring := PackedVector2Array()
		for k in 11:
			var a: float = float(k) / 11.0 * TAU
			var rr: float = sp.z * 0.8 * rng.randf_range(0.55, 1.1)
			ring.append(p + Vector2(cos(a) * rr * 1.25, sin(a) * rr * 0.8))
		ViewUtil.fill_poly(ci, ring, Color(0.04, 0.04, 0.07, 0.94))
		ci.draw_polyline(_closed(ring), Color(0.95, 0.95, 0.93, 0.9), 1.6, true)
		for k in 5:
			var a2: float = rng.randf_range(0.0, TAU)
			var rim: Vector2 = p + Vector2(cos(a2) * sp.z * 1.1, sin(a2) * sp.z * 0.75)
			var droop := Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(9.0, 20.0))
			var mid: Vector2 = rim + droop * 0.5 + Vector2(sin(float(k)) * 3.0, 0.0)
			ci.draw_polyline(PackedVector2Array([rim, mid, rim + droop]), Color(0.96, 0.96, 0.94, 0.85), 1.1, true)


## Repair: new bright strands are woven across the bag from its rim to the middle, with sparkles where they cross.
static func _draw_repair(ci: CanvasItem, c: Vector2, size: Vector2, fx: NestFx) -> void:
	if fx.repair_t <= 0.0:
		return
	var p: float = 1.0 - fx.repair_t / NestFx.REPAIR_TIME
	var fade: float = clampf(fx.repair_t / 0.35, 0.0, 1.0)
	var hw: float = size.x * 0.5
	var hh: float = size.y * 0.5
	for i in 18:
		var a: float = float(i) / 18.0 * TAU + 0.3
		var start := Vector2(cos(a) * hw * 0.82, sin(a) * hh * 0.8)
		var end := Vector2(cos(a + 2.6) * hw * 0.55, sin(a + 2.6) * hh * 0.5)
		var local_p: float = clampf(p * 1.6 - float(i % 6) * 0.08, 0.0, 1.0)
		if local_p <= 0.0:
			continue
		var mid: Vector2 = start.lerp(end, 0.5) + Vector2(sin(float(i) * 2.0) * 10.0, cos(float(i) * 1.7) * 8.0)
		var pts := PackedVector2Array()
		for k in 8:
			var u: float = float(k) / 7.0 * local_p
			pts.append(c + start.lerp(mid, u).lerp(mid.lerp(end, u), u))
		ci.draw_polyline(pts, Color(1.0, 0.97, 0.8, 0.9 * fade), 2.0, true)
		ci.draw_circle(pts[pts.size() - 1], 2.6 * fade, Color(1.0, 0.95, 0.6, 0.9 * fade))
	var glow: float = sin(p * PI)
	ViewUtil.radial(ci, c, 6.0, size.x * 0.62, [[0.0, Color(1.0, 0.96, 0.7, 0.55)], [1.0, Color(1.0, 0.96, 0.7, 0.0)]], glow * fade, "nest_repair_glow")


## Two pine branches the bag is woven between: bark with needle tufts, one from each side, meeting above the bag.
static func _draw_branches(ci: CanvasItem, rect: Rect2, shake: Vector2, cold: bool) -> void:
	var top: float = rect.position.y - 6.0
	var cx: float = rect.get_center().x + shake.x
	for side in [-1.0, 1.0]:
		var s: float = side
		var root := Vector2(cx + s * (rect.size.x * 0.5 + 34.0), top - 30.0)
		var tip := Vector2(cx + s * 6.0, top + 2.0)
		var mid := Vector2(cx + s * rect.size.x * 0.28, top - 22.0)
		var br: Texture2D = _tex("nest_branch")
		if br != null:
			_branch_sprite(ci, br, root, tip, s, cold)
			continue
		var pts: PackedVector2Array = ViewUtil.quad_pts(root, mid, tip, 14)
		ci.draw_polyline(pts, BARK, 9.0, true)
		ci.draw_polyline(pts, BARK_LIGHT, 3.0, true)
		for k in range(1, pts.size() - 1, 2):
			var p: Vector2 = pts[k]
			for j in 4:
				var a: float = -PI * 0.5 + (float(j) - 1.5) * 0.55 + s * 0.3
				ci.draw_line(p, p + Vector2(cos(a), sin(a)) * 15.0, NEEDLE, 1.6, true)
				if cold:
					ci.draw_line(p + Vector2(cos(a), sin(a)) * 9.0, p + Vector2(cos(a), sin(a)) * 15.0, Color(ICE, 0.85), 1.6, true)
		var cone: Vector2 = pts[5] + Vector2(0.0, 11.0)
		ci.draw_line(pts[5], cone, BARK, 1.4, true)
		ViewUtil.ellipse_fs(ci, cone + Vector2(0.0, 6.0), 4.6, 7.0, Color("#7a4d2a"), Color("#3b2414"), 1.2, 0.2 * s)
	# the silk anchors: a few strands from the branches down to the top of the bag
	for k in 6:
		var x: float = cx + (float(k) - 2.5) * 9.0
		ci.draw_line(Vector2(x, top - 4.0), Vector2(x * 0.3 + cx * 0.7, rect.position.y + 14.0), Color(SILK, 0.8), 1.2, true)


## The branch sprite laid from `tip` to `root`; `side` -1 mirrors it.
static func _branch_sprite(ci: CanvasItem, tex: Texture2D, root: Vector2, tip: Vector2, side: float, cold: bool) -> void:
	var v_w: Vector2 = root - tip
	var v_s: Vector2 = (BRANCH_ROOT - BRANCH_TIP) * Vector2(side, 1.0)
	var k: float = v_w.length() / v_s.length()
	ci.draw_set_transform_matrix(Transform2D(v_w.angle() - v_s.angle(), Vector2(k * side, k), 0.0, tip))
	ci.draw_texture_rect(tex, Rect2(-BRANCH_TIP, BRANCH_SIZE), false, Color(0.82, 0.93, 1.0) if cold else Color.WHITE)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## A small cap of snow on the top of the bag and icicles of silk at its sides (cold levels).
static func _draw_snow_cap(ci: CanvasItem, rect: Rect2) -> void:
	var cx: float = rect.get_center().x
	var y: float = rect.position.y + 3.0
	var cap := PackedVector2Array([Vector2(cx - 34.0, y + 14.0), Vector2(cx - 22.0, y + 3.0), Vector2(cx - 6.0, y - 3.0), Vector2(cx + 8.0, y - 2.0), Vector2(cx + 24.0, y + 4.0), Vector2(cx + 36.0, y + 15.0), Vector2(cx + 16.0, y + 10.0), Vector2(cx, y + 13.0), Vector2(cx - 16.0, y + 9.0)])
	ViewUtil.fill_poly(ci, cap, Color(0.96, 0.98, 1.0, 0.95))
	ci.draw_polyline(_closed(cap), Color(0.62, 0.74, 0.88, 0.8), 1.2, true)


## What is left when the nest fell: a limp grey heap of silk with a few dark holes.
static func _draw_fallen(ci: CanvasItem, ctx: ViewCtx) -> void:
	var r: Rect2 = ctx.nest_rect
	var c := Vector2(r.get_center().x, r.end.y - 14.0)
	ViewUtil.fill_ellipse(ci, c, r.size.x * 0.52, 15.0, Color(SILK_SHADE, 0.9))
	ViewUtil.fill_ellipse(ci, c + Vector2(-6.0, -3.0), r.size.x * 0.36, 9.0, Color(SILK, 0.8))
	for k in 6:
		var x: float = c.x + (float(k) - 2.5) * 20.0
		ci.draw_line(Vector2(x, c.y), Vector2(x + sin(float(k)) * 12.0, c.y - 18.0 - float(k % 3) * 5.0), Color(SILK, 0.7), 1.4, true)


# ---------------------------------------------------------------- the cold on the caterpillars

## Frozen tint of a caterpillar outside the nest in a cold level: pale blue over its body, frost crystals and a shiver.
static func draw_frozen(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var p: Vector2 = ViewUtil.pos(f)
	var t: float = ctx.t_now
	var segs: Variant = ViewUtil.g(f, "segs", [])
	var r: float = ViewUtil.gf(f, "r", 10.0)
	ci.draw_circle(p + Vector2(0.0, 1.0), r + 2.0, Color(0.62, 0.86, 1.0, 0.32))
	for s in segs:
		ci.draw_circle(ViewUtil.pos(s), 8.5, Color(0.62, 0.86, 1.0, 0.3))
		ci.draw_circle(ViewUtil.pos(s) + Vector2(-2.0, -3.0), 2.2, Color(1.0, 1.0, 1.0, 0.45))
	var id: int = ViewUtil.gi(f, "id")
	for k in 3:
		var a: float = t * 1.8 + float(k) * 2.1 + float(id)
		var q: Vector2 = p + Vector2(cos(a) * (r + 6.0), -r - 6.0 + sin(a * 1.3) * 5.0)
		_flake(ci, q, 3.2, Color(0.9, 0.97, 1.0, 0.95))
	# the shiver: two short lines at each side of the head
	var sh: float = sin(t * 38.0 + float(id)) * 1.6
	ci.draw_line(p + Vector2(-r - 5.0 + sh, -4.0), p + Vector2(-r - 10.0 + sh, -6.0), Color(0.8, 0.93, 1.0, 0.8), 1.4, true)
	ci.draw_line(p + Vector2(r + 5.0 - sh, -4.0), p + Vector2(r + 10.0 - sh, -6.0), Color(0.8, 0.93, 1.0, 0.8), 1.4, true)


## A six-armed snowflake of radius `r`.
static func _flake(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	for i in 3:
		var a: float = float(i) * PI / 3.0
		var d := Vector2(cos(a), sin(a)) * r
		ci.draw_line(c - d, c + d, col, 1.0, true)

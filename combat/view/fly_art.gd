## Procedural art of the tachinid fly (the boss of larva_boss, art key "tachinid_fly") and its small fly minions (unit SMALL_FLY):
## a bristly grey-black fly with big red eyes, buzzing see-through wings and an ovipositor at the tail, side view facing right
## (mirrored by `facing`). The size follows the fighter radius. Poses come from the sim's `ai_state` and `flying`:
## hovering / flying (blurred buzzing wings, legs dangling), warn (ovipositor out, "!"), dive (tilted, wings back, speed streaks),
## rest (landed on its legs, wings folded: the vulnerable window), fall (knocked out of the air: tumbling, dizzy).
class_name FlyArt
extends RefCounted

## Radius (px) of the body at scale 1: the drawing is scaled by `r / BASE_R`.
const BASE_R: float = 11.0
const BODY_DARK: String = "#23262d"
const BODY_GREY: String = "#6d737c"
const EYE_RED: String = "#d8252b"
const OUTLINE: String = "#0c0d10"


static func draw(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	var st: String = BirdArt.state(f)
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", BASE_R)
	var s: float = r / BASE_R
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var seed_t: float = t + float(ViewUtil.gi(f, "id")) * 1.7
	var c := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y"))
	var vel: Vector2 = BirdArt.velocity(f, c, t)
	var rot: float = 0.0
	var buzz: float = 1.0
	var legs_down: float = 0.0
	match st:
		BirdArt.PERCHED:
			buzz = 0.0
			legs_down = 1.0
			c.y += sin(seed_t * 2.4) * 0.5 * s
		BirdArt.WARN:
			c.y += sin(seed_t * 11.0) * 1.2
			rot = 0.25
		BirdArt.DIVE:
			rot = clampf(atan2(vel.y, maxf(absf(vel.x), 1.0)), 0.5, 1.3) if vel.length() > 20.0 else 0.9
		BirdArt.FALL:
			rot = seed_t * 10.0
		_:
			c.y += sin(seed_t * 5.0) * 2.0 * s
			rot = clampf(vel.y * 0.0012, -0.3, 0.3)
	if drowning:
		c.y += 5.0
	if st == BirdArt.DIVE:
		BirdArt._trail(ci, c, vel, facing, s)
	ci.draw_set_transform_matrix(Transform2D(rot * facing, Vector2(facing * s, s), 0.0, c))
	var dark: Color = ViewColors.h(BODY_DARK)
	var grey: Color = ViewColors.h(BODY_GREY)
	var line: Color = ViewColors.h(OUTLINE)
	var eye: Color = ViewColors.h(EYE_RED)
	if drowning:
		dark = dark.lerp(ViewColors.h("#7ab4d6"), 0.5)
		grey = grey.lerp(ViewColors.h("#7ab4d6"), 0.5)
	var wing_ang: float = _wing_angle(st, seed_t, buzz)
	_legs(ci, seed_t, legs_down, st, line)
	_wings(ci, wing_ang, st, buzz, true)
	_abdomen(ci, dark, grey, line, st, seed_t)
	_thorax(ci, dark, grey, line)
	_wings(ci, wing_ang, st, buzz, false)
	_head(ci, dark, line, eye, st, hurt)
	if hurt > 0.0:
		ViewUtil.fill_ellipse(ci, Vector2.ZERO, 14.0, 9.0, Color(1.0, 0.25, 0.2, clampf(hurt, 0.0, 1.0) * 0.4))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if st == BirdArt.WARN:
		BirdArt._warn_mark(ci, c + Vector2(facing * 4.0, -24.0 * s), seed_t)
	if st == BirdArt.FALL:
		for k in 3:
			var a2: float = t * 6.5 + float(k) * TAU / 3.0
			ci.draw_circle(c + Vector2(cos(a2) * 13.0 * s, -18.0 * s + sin(a2) * 4.0), 2.0, ViewColors.h("#ffe066") if k % 2 == 0 else Color.WHITE)


## Angle (rad, from +x) at which the near wing points: swept back and up, flapping between two extremes (a still, folded wing when landed).
static func _wing_angle(st: String, t: float, buzz: float) -> float:
	if buzz <= 0.0:
		return PI + 0.06
	if st == BirdArt.DIVE:
		return PI + 0.35
	return PI + 0.3 + (0.5 + 0.5 * sin(t * 58.0)) * 0.95


static func _wings(ci: CanvasItem, ang: float, st: String, buzz: float, far: bool) -> void:
	var base := Vector2(1.5, -4.6)
	var fill := Color(0.86, 0.92, 1.0, 0.34 if far else 0.5)
	var edge := Color(0.62, 0.68, 0.78, 0.8 if not far else 0.5)
	var a: float = ang - (0.25 if far else 0.0) if buzz > 0.0 else ang + (0.07 if far else 0.0)
	if buzz > 0.0 and st != BirdArt.DIVE and not far:
		# motion blur: two ghost positions of the flapping wing
		for g in [-0.55, 0.55]:
			_wing(ci, base, ang + g, Color(fill, 0.16), Color(edge, 0.0))
	_wing(ci, base, a, fill, edge)


static func _wing(ci: CanvasItem, base: Vector2, a: float, fill: Color, edge: Color) -> void:
	var dir := Vector2(cos(a), sin(a))
	ViewUtil.ellipse_fs(ci, base + dir * 7.5, 8.8, 3.6, fill, edge, 1.0, a)
	if edge.a > 0.1:
		ci.draw_line(base + dir * 1.5, base + dir * 13.0, Color(0.35, 0.4, 0.5, 0.7), 0.8, true)


static func _legs(ci: CanvasItem, t: float, down: float, st: String, line: Color) -> void:
	for k in 3:
		var x0: float = -2.0 + float(k) * 4.2
		var top := Vector2(x0, 3.0)
		var foot: Vector2
		if down > 0.0:
			foot = Vector2(x0 + (float(k) - 1.0) * 3.2, BASE_R)
			var knee := Vector2(x0 + (float(k) - 1.0) * 5.4, 8.2 - float(k % 2) * 0.8)
			ci.draw_polyline(PackedVector2Array([top, knee, foot]), line, 1.2, true)
		else:
			var dangle: float = sin(t * 6.0 + float(k) * 1.3) * 1.2
			foot = Vector2(x0 + (float(k) - 1.0) * 1.6 + dangle - (4.0 if st == BirdArt.DIVE else 0.0), 11.0 + float(k % 2))
			ci.draw_polyline(PackedVector2Array([top, top.lerp(foot, 0.5) + Vector2(1.0, 0.0), foot]), line, 1.1, true)


## Tail half: bristly dark abdomen with pale dusty bands and the ovipositor (out when it is about to strike).
static func _abdomen(ci: CanvasItem, dark: Color, grey: Color, line: Color, st: String, t: float) -> void:
	var out: bool = st == BirdArt.WARN or st == BirdArt.DIVE
	var tip := Vector2(-16.5, 2.8)
	var ovi_end: Vector2 = tip + (Vector2(-0.5, 8.5) if out else Vector2(-2.6, 3.0))
	var ovi_col := ViewColors.h("#7c2a24")
	ci.draw_polyline(ViewUtil.quad_pts(tip, tip + Vector2(-2.0, 3.0), ovi_end, 6), line, 3.0 if out else 2.2, true)
	ci.draw_polyline(ViewUtil.quad_pts(tip, tip + Vector2(-2.0, 3.0), ovi_end, 6), ovi_col, 1.6 if out else 1.1, true)
	# bristles radiating from the abdomen
	for b in 9:
		var ba: float = PI * 0.62 + float(b) * 0.22
		var p0 := Vector2(-8.0, 0.8) + Vector2(cos(ba) * 8.0, sin(ba) * 5.6)
		var p1: Vector2 = p0 + Vector2(cos(ba), sin(ba)) * (3.6 + float(b % 3)) + Vector2(sin(t * 3.0 + float(b)) * 0.3, 0.0)
		ci.draw_line(p0, p1, line, 1.0, true)
	ViewUtil.ellipse_fs(ci, Vector2(-8.0, 0.8), 9.6, 6.4, dark, line, 1.4, 0.06)
	for band in 3:
		var bx: float = -12.0 + float(band) * 4.4
		ViewUtil.fill_ellipse(ci, Vector2(bx, 0.6), 1.5, 5.4, Color(grey, 0.55), 0.06)
	# short stiff hairs on the back
	for b in 6:
		var x: float = -14.0 + float(b) * 2.8
		ci.draw_line(Vector2(x, -5.2 + absf(float(b) - 2.5) * 0.35), Vector2(x - 0.6, -8.0 + absf(float(b) - 2.5) * 0.35), line, 1.0, true)


static func _thorax(ci: CanvasItem, dark: Color, grey: Color, line: Color) -> void:
	ViewUtil.ellipse_fs(ci, Vector2(2.6, -1.0), 6.8, 5.8, grey, line, 1.4)
	for k in 3:
		var x: float = -0.6 + float(k) * 2.5
		ci.draw_line(Vector2(x, -5.4), Vector2(x + 0.5, 3.6), Color(dark, 0.85), 1.5, true)
	for b in 5:
		var x2: float = -2.0 + float(b) * 2.4
		ci.draw_line(Vector2(x2, -5.6), Vector2(x2 + 0.4, -8.2), line, 1.0, true)


static func _head(ci: CanvasItem, dark: Color, line: Color, eye: Color, st: String, hurt: float) -> void:
	var hc := Vector2(10.4, -0.4)
	ViewUtil.circle_fs(ci, hc, 4.6, ViewColors.h("#4a4f58"), line, 1.3)
	# big compound red eye
	ViewUtil.ellipse_fs(ci, hc + Vector2(0.8, -1.4), 3.4, 3.7, eye, line, 1.0, -0.2)
	ci.draw_circle(hc + Vector2(-0.1, -2.6), 0.9, Color(1.0, 0.8, 0.75, 0.9))
	if hurt > 0.2:
		ci.draw_line(hc + Vector2(-0.8, -2.8), hc + Vector2(2.4, -0.2), line, 1.2, true)
		ci.draw_line(hc + Vector2(2.4, -2.8), hc + Vector2(-0.8, -0.2), line, 1.2, true)
	elif st == BirdArt.WARN or st == BirdArt.DIVE:
		ci.draw_line(hc + Vector2(-1.8, -4.6), hc + Vector2(3.6, -2.6), line, 1.5, true)
	# face, proboscis and antennae
	ViewUtil.fill_ellipse(ci, hc + Vector2(3.4, 2.0), 1.7, 2.3, Color(0.8, 0.82, 0.84, 0.9), 0.4)
	ci.draw_line(hc + Vector2(3.2, 3.6), hc + Vector2(4.8, 5.8), line, 1.2, true)
	ci.draw_polyline(PackedVector2Array([hc + Vector2(2.4, -3.8), hc + Vector2(4.8, -7.0), hc + Vector2(7.6, -7.4)]), line, 1.0, true)
	ci.draw_circle(hc + Vector2(7.8, -7.4), 0.9, dark)

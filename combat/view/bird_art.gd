## Procedural art of the blue tit (mallerenga blava) of the Pelussa stage, side view facing right (mirrored by `facing`):
## blue cap, white cheek, black eye stripe, yellow belly, blue wings and tail. The great tit (kind GREAT_TIT*, mallerenga carbonera)
## is the same body with a black head, white cheeks, a black stripe down the yellow belly and a greenish back; it is bigger because the
## drawing scales with the fighter radius. States read from the fighter: perched (hops, wings folded),
## flying (wing flaps), warning (hovering with a "!"), diving (tilted, wings back, speed trail), falling (tumbling).
class_name BirdArt
extends RefCounted

const PERCHED := "perch"
const FLYING := "fly"
const WARN := "warn"
const DIVE := "dive"
const FALL := "fall"


## Current pose of the bird from the sim's `ai_state` ("idle", "approach", "warn", "dive", "return", "fall") and `flying`.
static func state(f: Variant) -> String:
	match ViewUtil.gs(f, "ai_state", "idle"):
		"warn":
			return WARN
		"dive":
			return DIVE
		"fall":
			return FALL
		"approach", "return":
			return FLYING
	return FLYING if ViewUtil.gb(f, "flying") else PERCHED


## Last position, time and smoothed velocity of each bird: the sim moves flyers kinematically (vx and vy stay 0), so the view derives the motion.
static var _track: Dictionary = {}


## Velocity (px/s) of the bird: the sim's when it has one, else measured from the last frames.
static func velocity(f: Variant, pos: Vector2, t: float) -> Vector2:
	var sim_v := Vector2(ViewUtil.gf(f, "vx"), ViewUtil.gf(f, "vy"))
	var id: int = ViewUtil.gi(f, "id")
	var prev: Array = _track.get(id, [])
	var vel: Vector2 = sim_v
	if not prev.is_empty():
		var dt: float = t - float(prev[1])
		if dt > 0.0005 and dt < 0.3:
			if sim_v == Vector2.ZERO:
				vel = (prev[2] as Vector2).lerp((pos - (prev[0] as Vector2)) / dt, 0.5)
		elif dt >= 0.0005:
			vel = Vector2.ZERO
		else:
			return prev[2]
	_track[id] = [pos, t, vel]
	return vel


static func draw(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	var st: String = state(f)
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 13.0)
	var s: float = r / 13.0
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var seed_t: float = t + float(ViewUtil.gi(f, "id")) * 1.3
	var c := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y"))
	var vel: Vector2 = velocity(f, c, t)
	var vx: float = vel.x
	var vy: float = vel.y
	var rot: float = 0.0
	var flap: float = 0.0
	var fold: float = 0.0
	match st:
		PERCHED:
			# little hops: a quick up-down every second or so
			var ph: float = fmod(seed_t * 1.1, 2.4)
			c.y -= sin(ph / 0.5 * PI) * 4.5 if ph < 0.5 else 0.0
			c.y += r - 10.5 * s
			fold = 1.0
			rot = -0.1 + sin(seed_t * 2.0) * 0.04
		WARN:
			c.y += sin(seed_t * 9.0) * 1.0
			flap = sin(seed_t * 34.0)
			rot = -0.2
		DIVE:
			rot = clampf(atan2(vy, maxf(absf(vx), 1.0)), 0.3, 1.25) if vel.length() > 20.0 else 0.8
			fold = 0.8
		FALL:
			rot = seed_t * 11.0
			flap = sin(seed_t * 22.0) * 0.8
		_:
			flap = sin(seed_t * 26.0)
			rot = clampf(vy * 0.0016, -0.4, 0.4)
	if drowning:
		c.y += 5.0
	# dive trail: speed streaks behind the body (opposite to the motion)
	if st == DIVE:
		_trail(ci, c, Vector2(vx, vy), facing, s)
	ci.draw_set_transform_matrix(Transform2D(rot * facing, Vector2(facing * s, s), 0.0, c))
	var great: bool = ViewUtil.gs(f, "kind").begins_with("GREAT_TIT")
	var blue: Color = ViewColors.h("#6f86ab") if great else ViewColors.h("#3a6fc2")
	var blue_dark: Color = ViewColors.h("#475d80") if great else ViewColors.h("#1f4590")
	var yellow: Color = ViewColors.h("#f2cb2a") if great else ViewColors.h("#f4d238")
	var line: Color = ViewColors.h("#10131c") if great else ViewColors.h("#14213d")
	var back: Color = ViewColors.h("#7f9c3e") if great else ViewColors.h("#8ba85a")
	if drowning:
		blue = blue.lerp(ViewColors.h("#7ab4d6"), 0.5)
		yellow = yellow.lerp(ViewColors.h("#7ab4d6"), 0.5)
	# legs when perched
	if st == PERCHED:
		var lc := ViewColors.h("#3a3f4a")
		ci.draw_line(Vector2(-1.5, 6.0), Vector2(-1.0, 10.5), lc, 1.4, true)
		ci.draw_line(Vector2(2.0, 6.0), Vector2(2.5, 10.5), lc, 1.4, true)
		ci.draw_line(Vector2(-2.6, 10.8), Vector2(0.4, 10.8), lc, 1.3, true)
		ci.draw_line(Vector2(1.0, 10.8), Vector2(4.0, 10.8), lc, 1.3, true)
	# tail
	var tail_a: float = 0.28 + (sin(seed_t * 3.0) * 0.05 if st == PERCHED else 0.0) - fold * 0.1
	ViewUtil.ellipse_fs(ci, Vector2(-11.5, 1.6), 7.0, 2.6, blue_dark, line, 1.2, tail_a)
	# far wing (behind the body)
	if st != PERCHED:
		_wing(ci, flap, fold, blue_dark.darkened(0.15), line, true)
	# body: olive-green back, yellow belly
	ViewUtil.ellipse_fs(ci, Vector2(0.0, 0.0), 11.0, 8.0, back, line, 1.4, -0.08)
	ViewUtil.fill_ellipse(ci, Vector2(1.0, 2.6), 9.6, 5.2, yellow, -0.05)
	ViewUtil.fill_ellipse(ci, Vector2(0.0, 5.4), 7.0, 1.6, Color(0.55, 0.4, 0.05, 0.25), 0.0)
	# black belly stripe: thin on the blue tit, a bold one from the bib to the tail on the great tit
	if great:
		ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(6.4, 3.4), Vector2(0.0, 2.3), Vector2(-7.0, 2.4), Vector2(-7.0, 3.8), Vector2(0.0, 4.6), Vector2(6.4, 4.8)]), line)
	else:
		ci.draw_line(Vector2(-4.0, 1.5), Vector2(6.0, 4.6), Color(line, 0.55), 1.0, true)
	# near wing
	_wing(ci, flap, fold, blue, line, false)
	# head
	var hc := Vector2(8.6, -5.0)
	ViewUtil.circle_fs(ci, hc, 6.4, ViewColors.h("#fbfaf2"), line, 1.4)
	if great:
		# black head down to the throat, with a big white cheek patch
		ViewUtil.fill_ellipse(ci, hc + Vector2(-0.4, 1.4), 6.2, 5.8, line)
		ViewUtil.fill_ellipse(ci, hc + Vector2(0.8, 1.2), 4.6, 2.9, ViewColors.h("#fbfaf2"), 0.12)
		ViewUtil.fill_ellipse(ci, hc + Vector2(-5.0, 4.8), 3.2, 2.2, line)
	else:
		# blue cap
		var cap := ViewUtil.arc_pts(hc, 6.4, PI * 1.02, PI * 1.98, 12)
		cap.append(hc + Vector2(5.0, -2.6))
		cap.append(hc + Vector2(-4.0, -2.2))
		ViewUtil.fill_poly(ci, cap, blue)
		ci.draw_arc(hc, 6.4, PI * 1.02, PI * 1.98, 12, line, 1.4, true)
		# black eye stripe
		ci.draw_line(hc + Vector2(-5.6, -0.2), hc + Vector2(5.8, 0.9), line, 1.4, true)
	# the eye
	var eye: Vector2 = hc + Vector2(1.6, -0.4)
	if hurt > 0.2:
		ci.draw_line(eye + Vector2(-1.2, -1.2), eye + Vector2(1.2, 1.2), line, 1.2, true)
		ci.draw_line(eye + Vector2(1.2, -1.2), eye + Vector2(-1.2, 1.2), line, 1.2, true)
	else:
		var fierce: bool = st == WARN or st == DIVE
		if great:
			ci.draw_circle(eye, 2.3, Color.WHITE)
		ci.draw_circle(eye, 1.7, ViewColors.h("#0d0f14"))
		ci.draw_circle(eye + Vector2(-0.4, -0.5), 0.5, Color.WHITE)
		if fierce:
			ci.draw_line(eye + Vector2(-2.6, -2.8), eye + Vector2(2.4, -1.5), line, 1.5, true)
	# black bib and beak
	if not great:
		ViewUtil.fill_ellipse(ci, hc + Vector2(-0.6, 5.4), 2.6, 1.3, line)
	var open: float = 1.0 if (st == DIVE or st == WARN) else 0.0
	ViewUtil.fill_poly(ci, PackedVector2Array([hc + Vector2(5.4, -1.8), hc + Vector2(10.4, 0.2 + open * -0.8), hc + Vector2(5.6, 0.6)]), ViewColors.h("#8a8f9c"))
	if open > 0.0:
		ViewUtil.fill_poly(ci, PackedVector2Array([hc + Vector2(5.6, 1.0), hc + Vector2(9.6, 2.2), hc + Vector2(5.4, 2.6)]), ViewColors.h("#6f7482"))
	if hurt > 0.0:
		ViewUtil.fill_ellipse(ci, Vector2.ZERO, 12.0, 9.0, Color(1.0, 0.25, 0.2, clampf(hurt, 0.0, 1.0) * 0.4))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if st == WARN:
		_warn_mark(ci, c + Vector2(facing * 4.0, -26.0 * s), seed_t)
	if st == FALL:
		for k in 3:
			var a2: float = t * 6.5 + float(k) * TAU / 3.0
			ci.draw_circle(c + Vector2(cos(a2) * 13.0, -20.0 + sin(a2) * 4.0), 2.0, ViewColors.h("#ffe066") if k % 2 == 0 else Color.WHITE)


## The wing in body space: folded along the flank, or flapping up and down.
static func _wing(ci: CanvasItem, flap: float, fold: float, col: Color, line: Color, far: bool) -> void:
	if fold >= 0.75:
		var rot: float = 0.12 if fold >= 1.0 else 0.0
		ViewUtil.ellipse_fs(ci, Vector2(-3.0, -0.4) if fold >= 1.0 else Vector2(-6.0, -1.0), 8.2, 3.8, col, line, 1.2, rot)
		if not far:
			ci.draw_line(Vector2(-6.0, -2.4), Vector2(-1.0, -1.2), Color(1, 1, 1, 0.85), 1.5, true)
		return
	var base := Vector2(-1.0, -2.0)
	var ang: float = lerpf(-0.9 - flap * 0.85, 0.35, fold)
	if far:
		ang -= 0.35
	var tip: Vector2 = base + Vector2(cos(PI + ang), sin(PI + ang)) * 12.0
	var curve: PackedVector2Array = ViewUtil.quad_pts(base + Vector2(3.0, -1.4), base.lerp(tip, 0.6) + Vector2(0.0, -4.0), tip, 8)
	curve.append_array(ViewUtil.quad_pts(tip, base.lerp(tip, 0.5) + Vector2(0.0, 4.0), base + Vector2(-2.0, 2.4), 8))
	ViewUtil.fill_poly(ci, curve, col)
	curve.append(curve[0])
	ci.draw_polyline(curve, line, 1.2, true)
	ci.draw_line(base.lerp(tip, 0.45) + Vector2(0.0, -0.8), base.lerp(tip, 0.78) + Vector2(0.0, 0.2), Color(1, 1, 1, 0.8), 1.4, true)


## Speed streaks opposite to the direction of the dive.
static func _trail(ci: CanvasItem, c: Vector2, vel: Vector2, facing: float, s: float) -> void:
	var dir: Vector2 = vel.normalized() if vel.length() > 1.0 else Vector2(facing, 0.6).normalized()
	for k in 5:
		var off: Vector2 = Vector2(-dir.y, dir.x) * (float(k) - 2.0) * 3.4 * s
		var a: Vector2 = c - dir * (10.0 + float(k % 2) * 4.0) * s + off
		var b: Vector2 = a - dir * (16.0 + float(k % 3) * 6.0) * s
		ci.draw_line(a, b, Color(1.0, 1.0, 1.0, 0.5 - float(k % 2) * 0.15), 2.0 * s, true)


## A red "!" in a small round bubble above the bird, pulsing.
static func _warn_mark(ci: CanvasItem, p: Vector2, t: float) -> void:
	var pulse: float = 1.0 + sin(t * 14.0) * 0.12
	var r: float = 8.5 * pulse
	ci.draw_circle(p, r + 1.6, Color(0.1, 0.05, 0.05, 0.85))
	ci.draw_circle(p, r, ViewColors.h("#e23a2e"))
	ci.draw_rect(Rect2(p.x - 1.2, p.y - 5.2, 2.4, 6.0), Color.WHITE)
	ci.draw_circle(p + Vector2(0.0, 4.2), 1.4, Color.WHITE)

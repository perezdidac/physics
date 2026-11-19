## The cuckoo (el cucut, boss of the Processó stage), procedural, side view facing right: a slim grey bird with a long dark graduated tail dotted with
## white, long pointed wings, a pale belly barred with grey, a yellow eye ring and a slightly curved dark beak. States come from the boss state of the
## sim: flying (wing flaps), hovering to announce an attack (INTENT: a red "!"), diving (ACT: wings back, speed streaks) and SATED (it ate: it sits,
## the belly is round and full, the eyes are half shut and it is content; vulnerable, so the boss art adds the golden halo).
class_name CuckooArt
extends RefCounted

const GREY: Color = Color("#7c8794")
const GREY_DARK: Color = Color("#4d5663")
const GREY_LIGHT: Color = Color("#a9b3be")
const CREAM: Color = Color("#f2ecd9")
const BAR: Color = Color("#5d6672")
const LINE: Color = Color("#1a1f27")
const EYE_RING: Color = Color("#f0c63a")
const FEET: Color = Color("#e0a13a")


## The cuckoo: the sprite rig through the registry ("creature:CUCKOO"), the vector drawing below while a part SVG is missing.
static func draw(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	ArtRegistry.draw("creature:CUCKOO", ci, f, ArtContext.of(ctx))


static func draw_vector(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	var st: String = ctx.boss_state
	var sated: bool = st == "SATED"
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 22.0)
	var s: float = r / 14.0
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var seed_t: float = t + float(ViewUtil.gi(f, "id")) * 1.3
	var c := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y"))
	var vel: Vector2 = BirdArt.velocity(f, c, t)
	var flap: float = 0.0
	var rot: float = 0.0
	var fold: float = 0.0
	if sated:
		c.y += r - 15.0 * s + sin(seed_t * 1.6) * 0.8
		fold = 1.0
		rot = -0.05
	elif st == "ACT":
		rot = clampf(atan2(vel.y, maxf(absf(vel.x), 1.0)), 0.3, 1.2) if vel.length() > 20.0 else 0.7
		fold = 0.8
		_trail(ci, c, vel, facing, s)
	elif st == "INTENT":
		c.y += sin(seed_t * 9.0)
		flap = sin(seed_t * 30.0)
		rot = -0.15
	else:
		flap = sin(seed_t * 18.0)
		rot = clampf(vel.y * 0.0012, -0.3, 0.3)
	if drowning:
		c.y += 5.0
	ci.draw_set_transform_matrix(Transform2D(rot * facing, Vector2(facing * s, s), 0.0, c))
	if sated:
		_legs(ci)
	_tail(ci, sated, seed_t)
	if not sated:
		_wing(ci, flap, fold, GREY_DARK, true)
	_body(ci, sated)
	_wing(ci, flap, fold, GREY, false)
	_head(ci, sated, st == "ACT" or st == "INTENT", hurt)
	if hurt > 0.0:
		ViewUtil.fill_ellipse(ci, Vector2.ZERO, 16.0, 9.0, Color(1.0, 0.25, 0.2, clampf(hurt, 0.0, 1.0) * 0.4))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if st == "INTENT":
		BirdArt._warn_mark(ci, c + Vector2(facing * 4.0, -30.0 * s), seed_t)
	elif sated:
		_zzz(ci, c + Vector2(facing * 6.0 * s, -22.0 * s), seed_t)


static func _legs(ci: CanvasItem) -> void:
	for x in [-2.0, 3.0]:
		ci.draw_line(Vector2(x, 8.0), Vector2(x + 0.5, 13.0), FEET, 1.8, true)
		ci.draw_line(Vector2(x - 2.4, 13.4), Vector2(x + 2.4, 13.4), FEET, 1.6, true)


## Long graduated tail: dark feathers fanned a little, each tipped with a white spot.
static func _tail(ci: CanvasItem, sated: bool, t: float) -> void:
	var base := Vector2(-10.0, 0.6)
	var droop: float = 0.22 if sated else 0.06 + sin(t * 2.0) * 0.03
	for k in 3:
		var ang: float = PI + droop + (float(k) - 1.0) * 0.17
		var len_k: float = 27.0 - absf(float(k) - 1.0) * 5.0
		var dir := Vector2(cos(ang), sin(ang))
		var tip: Vector2 = base + dir * len_k
		var perp := Vector2(-dir.y, dir.x)
		var feather := PackedVector2Array([base + perp * 1.8, base.lerp(tip, 0.7) + perp * 2.6, tip + perp * 1.2, tip - perp * 1.2, base.lerp(tip, 0.7) - perp * 2.6, base - perp * 1.8])
		ViewUtil.fill_poly(ci, feather, GREY_DARK if k != 1 else GREY_DARK.darkened(0.2))
		var closed := feather.duplicate()
		closed.append(feather[0])
		ci.draw_polyline(closed, LINE, 1.0, true)
		ViewUtil.fill_ellipse(ci, tip - dir * 2.2, 2.0, 1.2, Color.WHITE, ang)
		ViewUtil.fill_ellipse(ci, base.lerp(tip, 0.5), 1.4, 0.9, Color(1, 1, 1, 0.8), ang)


static func _body(ci: CanvasItem, sated: bool) -> void:
	# a slim grey back, with the pale barred belly underneath (a big round one when sated)
	var belly := Vector2(1.5, 2.8)
	var rx: float = 11.0
	var ry: float = 3.5
	if sated:
		ViewUtil.ellipse_fs(ci, Vector2(1.0, 2.6), 13.8, 10.2, GREY, LINE, 1.4, 0.0)
		belly = Vector2(2.0, 5.0)
		rx = 11.6
		ry = 6.8
	else:
		ViewUtil.ellipse_fs(ci, Vector2(0.0, 0.0), 13.0, 6.0, GREY, LINE, 1.4, -0.06)
	ViewUtil.fill_ellipse(ci, belly, rx, ry, CREAM)
	var x: float = belly.x - rx * 0.88
	while x < belly.x + rx * 0.88:
		var half: float = ry * sqrt(maxf(0.04, 1.0 - pow((x - belly.x) / rx, 2.0)))
		ci.draw_line(Vector2(x, belly.y - half * 0.35), Vector2(x - 0.6, belly.y + half * 0.95), Color(BAR, 0.85), 1.0, true)
		x += 2.7
	if sated:
		ViewUtil.fill_ellipse(ci, belly + Vector2(-3.5, -1.8), 4.5, 2.2, Color(1, 1, 1, 0.3), -0.3)


static func _wing(ci: CanvasItem, flap: float, fold: float, col: Color, far: bool) -> void:
	if fold >= 0.75:
		var rot: float = 0.12 if fold >= 1.0 else 0.0
		var wy: float = -4.6 if fold >= 1.0 else -1.4
		ViewUtil.ellipse_fs(ci, Vector2(-4.0, wy), 10.0, 3.6, col, LINE, 1.2, rot)
		if not far:
			ci.draw_line(Vector2(-10.0, wy - 1.4), Vector2(-1.0, wy - 0.4), GREY_LIGHT, 1.5, true)
		return
	var base := Vector2(-1.0, -3.0)
	var ang: float = lerpf(-0.9 - flap * 0.9, 0.35, fold)
	if far:
		ang -= 0.35
	var tip: Vector2 = base + Vector2(cos(PI + ang), sin(PI + ang)) * 19.0
	var curve: PackedVector2Array = ViewUtil.quad_pts(base + Vector2(4.0, -1.4), base.lerp(tip, 0.6) + Vector2(0.0, -5.0), tip, 8)
	curve.append_array(ViewUtil.quad_pts(tip, base.lerp(tip, 0.5) + Vector2(0.0, 5.0), base + Vector2(-3.0, 2.4), 8))
	ViewUtil.fill_poly(ci, curve, col)
	curve.append(curve[0])
	ci.draw_polyline(curve, LINE, 1.2, true)
	ci.draw_line(base.lerp(tip, 0.4) + Vector2(0.0, -0.8), base.lerp(tip, 0.82) + Vector2(0.0, 0.2), GREY_LIGHT, 1.5, true)


static func _head(ci: CanvasItem, sated: bool, fierce: bool, hurt: float) -> void:
	var hc := Vector2(12.0, -7.0 if sated else -4.6)
	ViewUtil.circle_fs(ci, hc, 6.0, GREY, LINE, 1.3)
	ViewUtil.fill_ellipse(ci, hc + Vector2(-1.0, 2.6), 4.4, 2.6, GREY_LIGHT)
	# slightly curved dark beak
	var beak: PackedVector2Array = ViewUtil.quad_pts(hc + Vector2(4.6, -1.6), hc + Vector2(10.0, -1.4), hc + Vector2(11.4, 2.0), 8)
	beak.append_array(ViewUtil.quad_pts(hc + Vector2(11.4, 2.0), hc + Vector2(8.0, 1.4), hc + Vector2(4.8, 1.8), 6))
	ViewUtil.fill_poly(ci, beak, Color("#2c3038"))
	var eye: Vector2 = hc + Vector2(1.8, -1.0)
	if hurt > 0.2:
		ci.draw_line(eye + Vector2(-1.4, -1.4), eye + Vector2(1.4, 1.4), LINE, 1.3, true)
		ci.draw_line(eye + Vector2(1.4, -1.4), eye + Vector2(-1.4, 1.4), LINE, 1.3, true)
	elif sated:
		# happy shut eyes (a little upturned arc) and rosy cheek
		ci.draw_arc(eye + Vector2(0.0, 0.6), 1.9, PI * 1.1, PI * 1.9, 8, LINE, 1.4, true)
		ViewUtil.fill_ellipse(ci, hc + Vector2(0.8, 2.2), 1.7, 1.0, Color(1.0, 0.5, 0.5, 0.5))
	else:
		ci.draw_circle(eye, 3.0, EYE_RING)
		ci.draw_circle(eye, 1.8, Color("#0d0f14"))
		ci.draw_circle(eye + Vector2(-0.4, -0.5), 0.5, Color.WHITE)
		if fierce:
			ci.draw_line(eye + Vector2(-3.0, -3.2), eye + Vector2(2.8, -1.6), LINE, 1.6, true)


static func _trail(ci: CanvasItem, c: Vector2, vel: Vector2, facing: float, s: float) -> void:
	var dir: Vector2 = vel.normalized() if vel.length() > 1.0 else Vector2(facing, 0.6).normalized()
	for k in 5:
		var off: Vector2 = Vector2(-dir.y, dir.x) * (float(k) - 2.0) * 4.0 * s
		var a: Vector2 = c - dir * (14.0 + float(k % 2) * 5.0) * s + off
		var b: Vector2 = a - dir * (20.0 + float(k % 3) * 8.0) * s
		ci.draw_line(a, b, Color(1.0, 1.0, 1.0, 0.5 - float(k % 2) * 0.15), 2.2 * s, true)


## Little "z" bubbles over a content, sated bird.
static func _zzz(ci: CanvasItem, p: Vector2, t: float) -> void:
	for k in 2:
		var ph: float = fmod(t * 0.7 + float(k) * 0.5, 1.0)
		ViewUtil.text(ci, "z", p + Vector2(float(k) * 7.0 + ph * 4.0, -ph * 14.0), 10 + k * 3, Color(1, 1, 1, 1.0 - ph))

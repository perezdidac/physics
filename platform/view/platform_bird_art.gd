## Procedural birds of the new stages: the hoopoe (DIG boss) and the nightjar (FLY enemy). Both face +x in local space; the caller flips.
class_name PlatformBirdArt
extends RefCounted

const OUTLINE := "#2a1a10"
const HIDDEN := Vector2(0.001, 0.001)

## Nightjar sprite parts (assets/sprites/creatures_platform/nightjar/): 128 viewBox units = 80 art units, anchor = the body centre.
const NJ_PARTS: Array[String] = ["tail", "wing_far", "body", "eye", "eye_alert", "wing_near"]
const NJ_REST_PHI: float = 0.5
const NJ_SHOULDER_VB := Vector2(64.0 - 1.6, 64.0 - 6.4)
const NJ_TAIL_VB := Vector2(64.0 - 19.2, 64.0 + 1.6)

## Hoopoe sprite parts (assets/sprites/creatures_platform/hoopoe/, hoopoe_legs/). The body rig is anchored at the body origin (22 above
## the feet, at viewBox (72, 96), 1.2 viewBox units per art unit); the beak stays code (its length and pitch are animated).
const HP_BODY_PARTS: Array[String] = ["tail", "body", "neck", "crest_0", "crest_1", "crest_2", "crest_3", "crest_4", "crest_5", "crest_6", "crest_7", "crest_8", "head", "eye", "brow", "wing"]
const HP_ANCHOR := Vector2(72.0, 96.0)
const HP_K: float = 1.2
const HP_HEAD := Vector2(22.0, -34.0)
const HP_LEGS_ANCHOR := Vector2(60.0, 100.0)

static var _nj_rig: CutoutRig = null
static var _hp_rig: CutoutRig = null
static var _hp_legs: CutoutRig = null


static func _get_nj_rig() -> CutoutRig:
	if _nj_rig == null:
		_nj_rig = CutoutRig.new("creatures_platform", "nightjar", 80.0)
		for part in NJ_PARTS:
			var pivot := Vector2(64.0, 64.0)
			if part.begins_with("wing"):
				pivot = NJ_SHOULDER_VB
			elif part == "tail":
				pivot = NJ_TAIL_VB
			_nj_rig.add_part(part, pivot)
	return _nj_rig


static func _get_hp_rig() -> CutoutRig:
	if _hp_rig == null:
		_hp_rig = CutoutRig.new("creatures_platform", "hoopoe", 128.0 / HP_K)
		for part in HP_BODY_PARTS:
			var pivot: Vector2 = HP_ANCHOR
			if part == "wing":
				pivot = HP_ANCHOR + Vector2(6.0, -24.0) * HP_K
			elif part == "tail":
				pivot = HP_ANCHOR + Vector2(-14.0, -7.0) * HP_K
			elif part.begins_with("crest_"):
				var u: float = float(part.substr(6).to_int()) / 8.0
				pivot = HP_ANCHOR + (HP_HEAD + Vector2(-2.0 + u * 3.0, -6.0)) * HP_K
			elif part == "eye" or part == "brow":
				pivot = HP_ANCHOR + (HP_HEAD + Vector2(3.0, -1.5)) * HP_K
			_hp_rig.add_part(part, pivot)
	return _hp_rig


static func _get_hp_legs() -> CutoutRig:
	if _hp_legs == null:
		_hp_legs = CutoutRig.new("creatures_platform", "hoopoe_legs", 64.0)
		for part in ["leg_a", "leg_b"]:
			_hp_legs.add_part(part, Vector2(64.0, 56.0))
	return _hp_legs


static func _is_dead(r: CutoutRig) -> bool:
	return r != null and r.id == "__none__"


static func _dead_rig() -> CutoutRig:
	var r := CutoutRig.new("creatures_platform", "__none__", 1.0)
	r.add_part("x")
	return r


## Forces the vector drawing (false) or the sprite parts (true); for the contact sheet and the tests.
static func use_sprites(on: bool) -> void:
	if on == _is_dead(_nj_rig):
		_nj_rig = null if on else _dead_rig()
	if on == _is_dead(_hp_rig):
		_hp_rig = null if on else _dead_rig()


## Frees the cached sprite parts (call at shutdown).
static func release() -> void:
	_nj_rig = null
	_hp_rig = null
	_hp_legs = null


# ---------------------------------------------------------------- hoopoe

## The hoopoe standing on the surface; the origin is between its feet. `o` keys: base (Transform2D placing the art), crest (0 folded .. 1 fanned up), wing (0 folded ..
## 1 raised), beak_len (px of the beak; 38 normal, grows in the stab), beak_pitch (radians, 0 = forward-down at rest, positive
## points the tip further down), lean (radians the whole body bows forward), walk (phase), alarm (0..1 eye widening).
static func hoopoe(ci: CanvasItem, t: float, o: Dictionary) -> void:
	var crest: float = float(o.get("crest", 0.0))
	var wing: float = float(o.get("wing", 0.0))
	var beak_len: float = float(o.get("beak_len", 38.0))
	var beak_pitch: float = float(o.get("beak_pitch", 0.0))
	var lean: float = float(o.get("lean", 0.0))
	var walk: float = float(o.get("walk", 0.0))
	var alarm: float = float(o.get("alarm", 0.0))
	var base: Transform2D = o.get("base", Transform2D.IDENTITY)
	var rig: CutoutRig = _get_hp_rig()
	var legs: CutoutRig = _get_hp_legs()
	if rig.is_complete() and legs.is_complete():
		_hoopoe_rig(ci, rig, legs, t, o)
		return
	var line: Color = ViewColors.h(OUTLINE)
	ci.draw_set_transform_matrix(base)
	# legs
	for q in 2:
		var ph: float = walk + float(q) * PI
		var fx: float = sin(ph) * 5.0 * float(o.get("step", 1.0))
		var lift: float = maxf(0.0, cos(ph)) * 3.0 * float(o.get("step", 1.0))
		var foot := Vector2(fx + 2.0, -lift)
		ci.draw_polyline(PackedVector2Array([Vector2(2.0, -22.0), Vector2(fx * 0.5 + 3.0, -11.0), foot]), Color(0.55, 0.5, 0.48), 2.4, true)
		ci.draw_line(foot, foot + Vector2(5.0, 0.0), Color(0.55, 0.5, 0.48), 2.0, true)
	var body_t: Transform2D = base * Transform2D(lean, Vector2.ONE, 0.0, Vector2(0.0, -22.0))
	ci.draw_set_transform_matrix(body_t)
	var body_c := Vector2(0.0, -14.0)
	# tail: black with a white band
	var tail := PackedVector2Array([Vector2(-14.0, -12.0), Vector2(-42.0, -2.0 + wing * -6.0), Vector2(-44.0, 7.0 + wing * -6.0), Vector2(-14.0, -2.0)])
	ci.draw_colored_polygon(tail, Color(0.12, 0.1, 0.1))
	ci.draw_colored_polygon(PackedVector2Array([tail[0].lerp(tail[1], 0.45), tail[1].lerp(tail[0], 0.3), tail[2].lerp(tail[3], 0.3), tail[3].lerp(tail[2], 0.45)]), Color(0.96, 0.95, 0.9))
	ci.draw_polyline(_closed(tail), line, 1.4, true)
	# body: grey-brown back, orange-pink breast
	ViewUtil.fill_ellipse(ci, body_c + Vector2(-2.0, 0.0), 25.0, 15.5, ViewColors.h("#c98a52"), -0.12)
	ViewUtil.fill_ellipse(ci, body_c + Vector2(7.0, 5.0), 17.0, 10.5, ViewColors.h("#f0b27a"), -0.2)
	ViewUtil.stroke_ellipse(ci, body_c + Vector2(-2.0, 0.0), 25.0, 15.5, line, 1.6, -0.12)
	# neck and head
	var head := Vector2(22.0, -34.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(10.0, -22.0), Vector2(26.0, -26.0), head + Vector2(2.0, 4.0), head + Vector2(-8.0, 2.0)]), ViewColors.h("#e3a26a"))
	_crest(ci, head, crest, t)
	ViewUtil.fill_ellipse(ci, head, 10.0, 9.0, ViewColors.h("#e8ab74"))
	ViewUtil.stroke_ellipse(ci, head, 10.0, 9.0, line, 1.4)
	if not bool(o.get("hide_beak", false)):
		_beak(ci, head + Vector2(8.0, 2.0), beak_len, beak_pitch)
	# eye (a little cross when it is about to strike)
	var ec: Vector2 = head + Vector2(3.0, -1.5)
	ci.draw_circle(ec, 3.2 + alarm * 0.8, Color(1.0, 0.98, 0.9))
	ci.draw_circle(ec + Vector2(0.6, 0.3), 2.0 + alarm * 0.4, Color(0.12, 0.05, 0.03))
	ci.draw_circle(ec + Vector2(-0.2, -0.6), 0.7, Color.WHITE)
	if alarm > 0.1:
		ci.draw_line(ec + Vector2(-5.0, -5.5), ec + Vector2(4.0, -3.2), line, 2.0, true)
	# wing with black and white bars, folded along the flank or raised
	_wing(ci, body_t, wing)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Sprite hoopoe: legs walk, body bows by `lean`, the crest feathers fan one by one, the wing lifts, the tail follows it, the eye widens.
static func _hoopoe_rig(ci: CanvasItem, rig: CutoutRig, legs: CutoutRig, t: float, o: Dictionary) -> void:
	var crest: float = float(o.get("crest", 0.0))
	var wing: float = float(o.get("wing", 0.0))
	var beak_len: float = float(o.get("beak_len", 38.0))
	var beak_pitch: float = float(o.get("beak_pitch", 0.0))
	var lean: float = float(o.get("lean", 0.0))
	var walk: float = float(o.get("walk", 0.0))
	var alarm: float = float(o.get("alarm", 0.0))
	var step: float = float(o.get("step", 1.0))
	var base: Transform2D = o.get("base", Transform2D.IDENTITY)
	# legs: swing around the hip, shorten while lifted (the sprite leg is 22 art units long and hangs straight down)
	for q in 2:
		var ph: float = walk + float(q) * PI
		var fx: float = sin(ph) * 5.0 * step
		var lift: float = maxf(0.0, cos(ph)) * 3.0 * step
		var leg_len: float = Vector2(fx, 22.0 - lift).length()
		legs.set_pose("leg_a" if q == 0 else "leg_b", -atan2(fx, 22.0 - lift), Vector2.ZERO, Vector2(1.0, leg_len / 22.0))
	legs.draw(ci, base, HP_LEGS_ANCHOR)
	var body_t: Transform2D = base * Transform2D(lean, Vector2.ONE, 0.0, Vector2(0.0, -22.0))
	# the beak sits under the head sprite (its root is hidden by the bill base)
	if not bool(o.get("hide_beak", false)):
		ci.draw_set_transform_matrix(body_t)
		_beak(ci, HP_HEAD + Vector2(8.0, 2.0), beak_len, beak_pitch)
	rig.set_pose("tail", wing * 6.0 / 28.0)
	rig.set_pose("wing", lerpf(0.0, -1.05, wing))
	var n: int = 9
	for q in n:
		var u: float = float(q) / float(n - 1)
		var folded: float = -2.3 + u * 0.35
		var fanned: float = -2.75 + u * 2.35
		var ang: float = lerpf(folded, fanned, crest) + sin(t * 9.0 + float(q)) * 0.03 * crest
		var ln: float = lerpf(15.0, 24.0, crest) * (1.0 - absf(u - 0.5) * 0.35)
		rig.set_pose("crest_%d" % q, ang + PI * 0.5, Vector2.ZERO, Vector2(1.0, ln / 24.0))
	rig.set_pose("eye", 0.0, Vector2.ZERO, Vector2.ONE * (1.0 + alarm * 0.25))
	rig.set_pose("brow", 0.0, Vector2.ZERO, Vector2.ONE if alarm > 0.1 else HIDDEN)
	rig.draw(ci, body_t, HP_ANCHOR)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Where the beak starts (art space, origin between the feet) when the whole body is bowed forward by `lean` radians.
static func hoopoe_beak_root(lean: float) -> Vector2:
	return Vector2(0.0, -22.0) + Vector2(30.0, -32.0).rotated(lean)


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out


## The crest: a fan of orange feathers with black tips. Folded it lies back along the head; fanned it opens upwards.
static func _crest(ci: CanvasItem, head: Vector2, crest: float, t: float) -> void:
	var n: int = 9
	for q in n:
		var u: float = float(q) / float(n - 1)
		var folded: float = -2.3 + u * 0.35
		var fanned: float = -2.75 + u * 2.35
		var ang: float = lerpf(folded, fanned, crest) + sin(t * 9.0 + float(q)) * 0.03 * crest
		var ln: float = lerpf(15.0, 24.0, crest) * (1.0 - absf(u - 0.5) * 0.35)
		var d := Vector2(cos(ang), sin(ang))
		var base: Vector2 = head + Vector2(-2.0 + u * 3.0, -6.0)
		var tip: Vector2 = base + d * ln
		var mid: Vector2 = base + d * ln * 0.78
		var nrm := Vector2(-d.y, d.x) * 2.3
		ci.draw_colored_polygon(PackedVector2Array([base - nrm, mid - nrm, tip, mid + nrm, base + nrm]), ViewColors.h("#e8883a"))
		ci.draw_colored_polygon(PackedVector2Array([mid - nrm * 0.9, tip, mid + nrm * 0.9]), Color(0.1, 0.07, 0.07))
		ci.draw_polyline(PackedVector2Array([base - nrm, mid - nrm, tip, mid + nrm, base + nrm]), Color(ViewColors.h(OUTLINE), 0.8), 1.0, true)


## The long, thin, curved beak. It starts at `root`, points forward and curves down; `pitch` swings it towards straight down.
static func _beak(ci: CanvasItem, root: Vector2, ln: float, pitch: float) -> void:
	var a0: float = 0.35 + pitch
	var pts := PackedVector2Array()
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var steps: int = 12
	var curve: float = 0.8 * (38.0 / maxf(ln, 38.0))
	var p: Vector2 = root
	for i in steps + 1:
		var u: float = float(i) / float(steps)
		var a: float = a0 + curve * u * u
		var w: float = lerpf(3.4, 0.5, u)
		var nrm := Vector2(-sin(a), cos(a)) * w
		upper.append(p - nrm)
		lower.append(p + nrm)
		pts.append(p)
		p += Vector2(cos(a), sin(a)) * ln / float(steps)
	var poly := PackedVector2Array(upper)
	for i in range(steps, -1, -1):
		poly.append(lower[i])
	ci.draw_colored_polygon(poly, Color(0.2, 0.15, 0.13))
	ci.draw_polyline(pts, Color(0.5, 0.42, 0.38, 0.8), 1.0, true)


static func _wing(ci: CanvasItem, body_t: Transform2D, raise: float) -> void:
	var ang: float = lerpf(0.0, -1.05, raise)
	ci.draw_set_transform_matrix(body_t * Transform2D(ang, Vector2.ONE, 0.0, Vector2(6.0, -24.0)))
	var bars: int = 6
	for q in bars:
		var x0: float = -float(q) * 6.6
		var quad := PackedVector2Array([Vector2(x0 + 4.0, 0.0), Vector2(x0 - 3.0, 0.0), Vector2(x0 - 9.0 + float(q) * 0.0, 21.0 - float(q) * 1.0), Vector2(x0 - 1.0, 21.0 - float(q) * 1.0)])
		# bars run across the wing; alternate black and cream
		var col: Color = Color(0.1, 0.08, 0.08) if q % 2 == 0 else Color(0.97, 0.95, 0.88)
		ci.draw_colored_polygon(quad, col)
	var outline := PackedVector2Array([Vector2(5.0, 0.0), Vector2(-33.0, 0.0), Vector2(-42.0, 19.0), Vector2(-26.0, 22.0), Vector2(-2.0, 19.0), Vector2(6.0, 8.0)])
	ci.draw_polyline(_closed(outline), ViewColors.h(OUTLINE), 1.4, true)
	ci.draw_set_transform_matrix(body_t)


# ---------------------------------------------------------------- nightjar

## A nightjar in flight, origin at the body centre, facing +x. `o` keys: flap (-1..1, -9 = from t), alert (0..1), chase (bool).
static func nightjar(ci: CanvasItem, r: float, t: float, o: Dictionary) -> void:
	var k: float = r / 16.0
	var flap: float = float(o.get("flap", -9.0))
	if flap < -2.0:
		flap = sin(t * (11.0 if bool(o.get("chase", false)) else 6.5))
	var alert: float = float(o.get("alert", 0.0))
	var base: Transform2D = o.get("base", Transform2D.IDENTITY)
	var m: Transform2D = base * Transform2D(clampf(-float(o.get("vy", 0.0)) / 400.0, -0.4, 0.4), Vector2(k, k), 0.0, Vector2.ZERO)
	var rig: CutoutRig = _get_nj_rig()
	if rig.is_complete():
		var phi: float = lerpf(-0.45, 1.45, (1.0 - flap) * 0.5)
		rig.set_pose("wing_near", phi - NJ_REST_PHI)
		rig.set_pose("wing_far", phi - 0.1 - NJ_REST_PHI)
		rig.set_pose("tail", -flap * 0.07)
		rig.set_pose("eye", 0.0, Vector2.ZERO, HIDDEN if alert > 0.5 else Vector2.ONE)
		rig.set_pose("eye_alert", 0.0, Vector2.ZERO, Vector2.ONE if alert > 0.5 else HIDDEN)
		rig.draw(ci, m, Vector2(64.0, 64.0))
		return
	ci.draw_set_transform_matrix(m)
	var line: Color = ViewColors.h(OUTLINE)
	var brown: Color = ViewColors.h("#7a6048")
	var dark: Color = ViewColors.h("#3f3024")
	var pale: Color = ViewColors.h("#b99d7a")
	# tail
	var tail := PackedVector2Array([Vector2(-12.0, -2.0), Vector2(-36.0, -3.0 + flap * 1.5), Vector2(-37.0, 5.0 + flap * 1.5), Vector2(-12.0, 4.0)])
	ci.draw_colored_polygon(tail, dark)
	ci.draw_polyline(_closed(tail), line, 1.2, true)
	_nj_wing(ci, flap, true)
	ViewUtil.fill_ellipse(ci, Vector2(-1.0, 1.0), 17.0, 9.0, brown)
	ViewUtil.fill_ellipse(ci, Vector2(1.0, 4.0), 12.0, 4.5, pale)
	for q in 6:
		ci.draw_line(Vector2(-12.0 + float(q) * 4.0, -3.0), Vector2(-9.5 + float(q) * 4.0, 2.0), Color(dark, 0.7), 1.2, true)
	ViewUtil.stroke_ellipse(ci, Vector2(-1.0, 1.0), 17.0, 9.0, line, 1.4)
	# wide flat head with a huge dark eye and a gape
	var hc := Vector2(16.0, -2.0)
	ViewUtil.fill_ellipse(ci, hc, 8.5, 6.8, brown)
	ViewUtil.stroke_ellipse(ci, hc, 8.5, 6.8, line, 1.3)
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(6.0, 0.0), hc + Vector2(13.0, 1.5 + alert * 2.0), hc + Vector2(6.0, 3.8)]), dark)
	for q in 3:
		ci.draw_line(hc + Vector2(8.0, 1.0 + float(q) * 0.9), hc + Vector2(13.0, -1.0 + float(q) * 1.9), Color(dark, 0.8), 0.9, true)
	var ec: Vector2 = hc + Vector2(2.0, -1.5)
	ci.draw_circle(ec, 4.4, Color(0.97, 0.85, 0.4) if alert > 0.5 else Color(0.95, 0.9, 0.7))
	ci.draw_circle(ec + Vector2(0.8, 0.0), 2.9, Color(0.07, 0.05, 0.04))
	ci.draw_circle(ec + Vector2(0.0, -1.0), 0.9, Color.WHITE)
	if alert > 0.5:
		ci.draw_line(ec + Vector2(-5.0, -5.5), ec + Vector2(4.0, -3.5), line, 1.8, true)
	_nj_wing(ci, flap, false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _nj_wing(ci: CanvasItem, flap: float, far: bool) -> void:
	var shade: float = 0.7 if far else 1.0
	var sh := Vector2(-1.0, -4.0)
	var phi: float = lerpf(-0.45, 1.45, (1.0 - flap) * 0.5) - (0.1 if far else 0.0)
	var pts: PackedVector2Array = PlatformMothArt.leaf(sh, phi, 42.0, 5.0, 9.5)
	ci.draw_colored_polygon(pts, Color(0.52 * shade, 0.40 * shade, 0.29 * shade))
	var half: int = 12
	for q in 5:
		var u: int = 2 + q * 2
		ci.draw_line(pts[u], pts[pts.size() - 1 - u], Color(0.22, 0.16, 0.11, 0.75 * shade), 1.5, true)
	ci.draw_circle(pts[9].lerp(pts[pts.size() - 10], 0.5), 1.8, Color(0.96, 0.93, 0.86, 0.9 * shade))
	ci.draw_polyline(_closed(pts), Color(ViewColors.h(OUTLINE), shade), 1.3, true)
	ci.draw_line(sh, pts[half], Color(0.2, 0.14, 0.1, 0.6 * shade), 1.2, true)

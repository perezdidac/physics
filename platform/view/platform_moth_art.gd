## Perleta as a processionary moth (FLY mode), drawn procedurally: a furry grey-brown body, pale forewings with darker diagonal
## bands and a fringe, whitish hindwings, feathery antennae and big dark eyes. The wings flap (or stay spread while gliding).
## Local origin is the body centre; `r` is the body radius.
class_name PlatformMothArt
extends RefCounted

const FUR := "#9a8468"
const FUR_DARK := "#5f4f3b"
const FORE := "#c4bcae"
const HIND := "#ece6da"
const BAND := "#6d5f4e"
const OUTLINE := "#352b20"
## Sprite parts (assets/sprites/creatures_platform/moth/): 128 viewBox units = 80 art units, anchor = the body centre. The wings are
## authored at wing angle REST_PHI and rotate around the shoulder; the glow, the hurt tint and the stun spiral stay code-driven.
const PARTS: Array[String] = ["wing_far", "antenna_a", "antenna_b", "body", "wing_near", "head", "eye", "eye_stun"]
const REST_PHI: float = 0.3
const SHOULDER_VB := Vector2(64.0 - 3.2, 64.0 - 6.4)
const ANTENNA_VB := Vector2(64.0 + 12.8, 64.0 - 6.4)
const EYE_VB := Vector2(64.0 + 18.24, 64.0 - 2.24)
const HIDDEN := Vector2(0.001, 0.001)

static var _rig: CutoutRig = null


static func _get_rig() -> CutoutRig:
	if _rig == null:
		_rig = CutoutRig.new("creatures_platform", "moth", 80.0)
		for part in PARTS:
			var pivot := Vector2(64.0, 64.0)
			if part.begins_with("wing"):
				pivot = SHOULDER_VB
			elif part.begins_with("antenna"):
				pivot = ANTENNA_VB
			elif part.begins_with("eye"):
				pivot = EYE_VB
			_rig.add_part(part, pivot)
	return _rig


static func _is_dead(r: CutoutRig) -> bool:
	return r != null and r.id == "__none__"


static func _dead_rig() -> CutoutRig:
	var r := CutoutRig.new("creatures_platform", "__none__", 1.0)
	r.add_part("x")
	return r


## Forces the vector drawing (false) or the sprite parts (true); for the contact sheet and the tests.
static func use_sprites(on: bool) -> void:
	if on == _is_dead(_rig):
		_rig = null if on else _dead_rig()


## Frees the cached sprite parts (call at shutdown).
static func release() -> void:
	_rig = null


## Draws the moth facing `o.facing`. `o` keys: facing (-1/1), flap (wing angle -1 up .. 1 down; -9 = compute from `t`),
## glide (bool: wings spread), stun (0..1), hurt (0..1), vel (Vector2), glow (0..1 halo), base (Transform2D placing the art).
static func draw(ci: CanvasItem, r: float, t: float, o: Dictionary) -> void:
	var facing: float = float(o.get("facing", 1.0))
	var glide: bool = bool(o.get("glide", false))
	var stun: float = float(o.get("stun", 0.0))
	var hurt: float = float(o.get("hurt", 0.0))
	var vel: Vector2 = o.get("vel", Vector2.ZERO)
	var base: Transform2D = o.get("base", Transform2D.IDENTITY)
	var k: float = r / 13.0
	var flap: float
	if glide:
		flap = -0.4 + sin(t * 3.0) * 0.06
	elif stun > 0.0:
		flap = sin(t * 40.0) * 0.5
	else:
		flap = float(o.get("flap", -9.0))
		if flap < -2.0:
			flap = sin(t * 17.0 + clampf(-vel.y / 200.0, -1.0, 1.0))
	var tilt: float = clampf(vel.x / 260.0, -1.0, 1.0) * 0.18 + clampf(vel.y / 400.0, -1.0, 1.0) * 0.12
	if stun > 0.0:
		tilt = sin(t * 12.0) * 0.4
	var m: Transform2D = base * Transform2D(tilt * facing, Vector2(k * facing, k), 0.0, Vector2.ZERO)
	var rig: CutoutRig = _get_rig()
	if rig.is_complete():
		_draw_rig(ci, rig, m, t, flap, stun, hurt, float(o.get("glow", 0.0)))
		return
	ci.draw_set_transform_matrix(m)
	var halo: float = float(o.get("glow", 0.0))
	if halo > 0.0:
		ci.draw_circle(Vector2.ZERO, 34.0, Color(1.0, 0.95, 0.75, 0.05 * halo))
		ci.draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.95, 0.75, 0.07 * halo))
	_wing(ci, flap, true, hurt)
	_antennae(ci, t)
	_legs(ci)
	_body(ci, hurt)
	_wing(ci, flap, false, hurt)
	_head(ci, t, stun, hurt)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Sprite version of the same pose: the wing parts swing around the shoulder, the antennae sway, the eye swaps to a spinning spiral when stunned.
static func _draw_rig(ci: CanvasItem, rig: CutoutRig, m: Transform2D, t: float, flap: float, stun: float, hurt: float, halo: float) -> void:
	if halo > 0.0:
		ci.draw_set_transform_matrix(m)
		ci.draw_circle(Vector2.ZERO, 34.0, Color(1.0, 0.95, 0.75, 0.05 * halo))
		ci.draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.95, 0.75, 0.07 * halo))
	var phi: float = lerpf(-0.75, 1.4, (1.0 - flap) * 0.5)
	rig.set_pose("wing_near", phi - REST_PHI)
	rig.set_pose("wing_far", phi - 0.12 - REST_PHI)
	for q in 2:
		var wob: float = sin(t * 5.0 + float(q) * 1.5) * 1.5
		rig.set_pose("antenna_a" if q == 0 else "antenna_b", wob * 0.07 / (1.0 if q == 0 else 0.7))
	var stunned: bool = stun > 0.0
	rig.set_pose("eye", 0.0, Vector2.ZERO, HIDDEN if stunned else Vector2.ONE)
	rig.set_pose("eye_stun", t * 9.0, Vector2.ZERO, Vector2.ONE if stunned else HIDDEN)
	rig.draw(ci, m, Vector2(64.0, 64.0))
	if hurt > 0.0:
		ci.draw_set_transform_matrix(m)
		var tint := Color(1.0, 0.45, 0.4, hurt * 0.3)
		var shoulder := Vector2(-2.0, -4.0)
		for far in [true, false]:
			var ph: float = phi - (0.12 if far else 0.0)
			ci.draw_colored_polygon(leaf(shoulder, ph, 33.0, 7.5, 12.5), tint)
		ViewUtil.fill_ellipse(ci, Vector2(-1.0, 0.5), 8.8, 6.6, tint)
		ViewUtil.fill_ellipse(ci, Vector2(9.5, -1.0), 5.4, 5.0, tint)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## One pair of wings on one side (the far one is drawn first and a bit darker). `flap` -1 = wings straight up, 0 = spread, 1 = down.
static func _wing(ci: CanvasItem, flap: float, far: bool, hurt: float) -> void:
	var shade: float = 0.72 if far else 1.0
	var phi: float = lerpf(-0.75, 1.4, (1.0 - flap) * 0.5)
	if far:
		phi -= 0.12
	var shoulder := Vector2(-2.0, -4.0)
	var fore: Color = ViewColors.h(FORE).lerp(Color(1.0, 0.5, 0.45), hurt * 0.4)
	fore = Color(fore.r * shade, fore.g * shade, fore.b * shade, 1.0)
	var hind: Color = ViewColors.h(HIND)
	hind = Color(hind.r * shade, hind.g * shade, hind.b * shade, 1.0)
	# hindwing: shorter, swept further back and down
	var hpts: PackedVector2Array = leaf(shoulder + Vector2(0.0, 1.0), phi - 0.55, 22.0, 6.0, 9.0)
	ci.draw_colored_polygon(hpts, hind)
	ci.draw_polyline(_closed(hpts), Color(ViewColors.h(OUTLINE), 0.7 * shade), 1.0, true)
	# forewing with its dark bands, a spot and a fringe
	var fpts: PackedVector2Array = leaf(shoulder, phi, 33.0, 7.5, 12.5)
	ci.draw_colored_polygon(fpts, fore)
	var band: Color = Color(ViewColors.h(BAND), 0.85 * shade)
	var half: int = 12
	for q in 3:
		var u: int = 3 + q * 3
		var lead: Vector2 = fpts[u]
		var trail: Vector2 = fpts[fpts.size() - 1 - u]
		var mid: Vector2 = lead.lerp(trail, 0.5) + (fpts[half] - shoulder).normalized() * 3.0
		ci.draw_polyline(PackedVector2Array([lead, mid, trail]), band, 1.7 - float(q) * 0.25, true)
	ci.draw_circle(fpts[half].lerp(shoulder, 0.5).lerp(fpts[half - 3], 0.3), 1.4, band)
	ci.draw_polyline(_closed(fpts), ViewColors.h(OUTLINE), 1.3, true)
	for q in 4:
		var fi: int = half + 1 + q
		var fp: Vector2 = fpts[fi]
		var out: Vector2 = (fp - shoulder).normalized()
		ci.draw_line(fp, fp + out * 2.4, Color(ViewColors.h(FORE), 0.9 * shade), 1.0, true)


## Outline of a leaf-shaped wing growing from `root` at angle `phi` (0 = pointing back along the body, positive = turning up and
## forwards), `length` long, `w_lead` / `w_trail` wide on the front and rear side.
static func leaf(root: Vector2, phi: float, length: float, w_lead: float, w_trail: float) -> PackedVector2Array:
	var axis := Vector2(-cos(phi), -sin(phi))
	var nrm := Vector2(sin(phi), -cos(phi))
	var steps: int = 12
	var lead := PackedVector2Array()
	var trail := PackedVector2Array()
	for i in steps + 1:
		var u: float = float(i) / float(steps)
		var prof: float = pow(sin(PI * pow(u, 0.75)), 0.85)
		lead.append(root + axis * u * length + nrm * prof * w_lead)
		trail.append(root + axis * u * length - nrm * prof * w_trail * (1.0 - 0.15 * u))
	var out := PackedVector2Array(lead)
	for i in range(steps, -1, -1):
		out.append(trail[i])
	return out


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out


static func _body(ci: CanvasItem, hurt: float) -> void:
	var fur: Color = ViewColors.h(FUR).lerp(Color(1.0, 0.5, 0.45), hurt * 0.4)
	ViewUtil.fill_ellipse(ci, Vector2(-6.5, 1.5), 9.0, 5.6, ViewColors.h(FUR_DARK), -0.12)
	ViewUtil.fill_ellipse(ci, Vector2(-1.0, 0.5), 8.8, 6.6, fur)
	# fluffy scale tufts along the back and a pale belly
	for q in 7:
		var fx: float = -9.0 + float(q) * 2.8
		ci.draw_line(Vector2(fx, -5.0), Vector2(fx - 1.0, -7.6 - fmod(float(q) * 1.7, 2.0)), Color(ViewColors.h(FUR), 0.95), 1.4, true)
	ViewUtil.fill_ellipse(ci, Vector2(-1.5, 4.0), 6.0, 2.4, Color(0.93, 0.87, 0.76, 0.65))
	ViewUtil.stroke_ellipse(ci, Vector2(-1.0, 0.5), 8.8, 6.6, Color(ViewColors.h(OUTLINE), 0.8), 1.2)


static func _legs(ci: CanvasItem) -> void:
	var col: Color = ViewColors.h(OUTLINE)
	for q in 3:
		var x: float = -4.0 + float(q) * 3.2
		ci.draw_polyline(PackedVector2Array([Vector2(x, 5.0), Vector2(x + 1.0, 9.0), Vector2(x - 0.5, 11.5)]), col, 1.1, true)


static func _antennae(ci: CanvasItem, t: float) -> void:
	var col: Color = ViewColors.h(OUTLINE)
	for q in 2:
		var s: float = 1.0 if q == 0 else 0.7
		var wob: float = sin(t * 5.0 + float(q) * 1.5) * 1.5
		var pts := PackedVector2Array([Vector2(8.0, -4.0), Vector2(11.0 * s + 3.0, -10.0 * s + wob), Vector2(16.0 * s + 3.0, -13.0 * s + wob * 1.4)])
		ci.draw_polyline(pts, col, 1.3, true)
		for j in 4:
			var p: Vector2 = pts[1].lerp(pts[2], float(j) / 3.0)
			ci.draw_line(p, p + Vector2(-1.0, -2.4), Color(col, 0.7), 1.0, true)
			ci.draw_line(p, p + Vector2(1.6, 1.2), Color(col, 0.7), 1.0, true)


static func _head(ci: CanvasItem, t: float, stun: float, hurt: float) -> void:
	var hc := Vector2(9.5, -1.0)
	ViewUtil.fill_ellipse(ci, hc, 5.4, 5.0, ViewColors.h(FUR).lerp(Color(1.0, 0.5, 0.45), hurt * 0.4))
	ViewUtil.stroke_ellipse(ci, hc, 5.4, 5.0, ViewColors.h(OUTLINE), 1.1)
	for q in 4:
		ci.draw_line(hc + Vector2(-2.0 + float(q) * 1.6, -4.4), hc + Vector2(-1.0 + float(q) * 1.6, -6.4), Color(ViewColors.h(FUR), 0.95), 1.2, true)
	var ec: Vector2 = hc + Vector2(1.9, -0.4)
	if stun > 0.0:
		ViewUtil.fill_ellipse(ci, ec, 3.0, 3.2, Color.WHITE)
		var spiral := PackedVector2Array()
		for j in 12:
			var u: float = float(j) / 11.0
			var an: float = u * TAU * 1.5 + t * 9.0
			spiral.append(ec + Vector2(cos(an), sin(an)) * 2.6 * u)
		ci.draw_polyline(spiral, ViewColors.h(OUTLINE), 1.0, true)
		return
	ViewUtil.fill_ellipse(ci, ec, 3.0, 3.3, Color(0.09, 0.07, 0.06, 1.0))
	ci.draw_circle(ec + Vector2(-0.7, -1.0), 1.0, Color.WHITE)
	ci.draw_circle(ec + Vector2(0.8, 0.9), 0.45, Color(1.0, 1.0, 1.0, 0.6))
	# a tiny curled proboscis
	ci.draw_arc(hc + Vector2(5.0, 2.8), 1.7, -0.6, PI * 1.2, 6, ViewColors.h(OUTLINE), 1.0, true)

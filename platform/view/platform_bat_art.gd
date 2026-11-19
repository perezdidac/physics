## The bat, final boss of the moth stage, drawn procedurally: a furry dark body, big pointed ears, a leathery wing with finger bones that
## flaps, a small face with little fangs. Local origin is the body centre; the bat faces +x (the caller flips).
class_name PlatformBatArt
extends RefCounted

const FUR := "#4a3b52"
const FUR_LIGHT := "#6d5a73"
const MEMBRANE := "#5a4466"
const OUTLINE := "#1c1220"
## Sprite parts (assets/sprites/creatures_platform/bat/): 128 viewBox units = 128 art units, anchor = the body centre. The wings are
## authored at wing angle REST_ALPHA and swing / foreshorten around the shoulder; the sound arcs stay code.
const PARTS: Array[String] = ["wing_far", "body", "wing_near", "head", "mouth", "mouth_open", "fangs", "eyes", "eyes_marked"]
const REST_ALPHA: float = 0.9
const SHOULDER_VB := Vector2(61.0, 58.0)
const MOUTH_VB := Vector2(64.0 + 13.4, 64.0 + 1.8)
const HIDDEN := Vector2(0.001, 0.001)

static var _rig: CutoutRig = null


static func _get_rig() -> CutoutRig:
	if _rig == null:
		_rig = CutoutRig.new("creatures_platform", "bat", 128.0)
		for part in PARTS:
			var pivot := Vector2(64.0, 64.0)
			if part.begins_with("wing"):
				pivot = SHOULDER_VB
			elif part == "mouth_open":
				pivot = MOUTH_VB
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


## `o` keys: state ("PATROL", "PULSE", "MARK", "SWOOP"), scale (float), flap (-1..1, -9 = from t), open (0..1 mouth), angle (body tilt), base (Transform2D placing the art).
static func draw(ci: CanvasItem, t: float, o: Dictionary) -> void:
	var base: Transform2D = o.get("base", Transform2D.IDENTITY)
	var state: String = str(o.get("state", "PATROL"))
	var sc: float = float(o.get("scale", 1.6))
	var swoop: bool = state == "SWOOP"
	var flap: float = float(o.get("flap", -9.0))
	if flap < -2.0:
		flap = sin(t * (9.0 if state == "PATROL" else 14.0 if state == "MARK" else 6.0))
	if swoop:
		flap = -0.2 + sin(t * 20.0) * 0.1
	var m: Transform2D = base * Transform2D(float(o.get("angle", 0.0)), Vector2(sc, sc), 0.0, Vector2.ZERO)
	var rig: CutoutRig = _get_rig()
	if rig.is_complete():
		_draw_rig(ci, rig, m, t, state, flap, float(o.get("open", 0.0)), swoop)
		return
	ci.draw_set_transform_matrix(m)
	_wing(ci, flap, true, swoop)
	_body(ci, t, state, float(o.get("open", 0.0)))
	_wing(ci, flap, false, swoop)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Sprite version: both wings are one piece each (arm + membrane + fingers) swung and foreshortened exactly like the vector wing's arm.
static func _draw_rig(ci: CanvasItem, rig: CutoutRig, m: Transform2D, t: float, state: String, flap: float, open: float, swoop: bool) -> void:
	var fore0: float = 0.55 + 0.45 * sin(REST_ALPHA)
	for far in [true, false]:
		var alpha: float = lerpf(-2.0, 1.9, (flap + 1.0) * 0.5) + (0.12 if far else 0.0)
		if swoop:
			alpha = 2.65
		var fore: float = 0.55 + 0.45 * absf(sin(alpha))
		var fs: float = fore / fore0
		rig.set_pose("wing_far" if far else "wing_near", alpha - REST_ALPHA, Vector2.ZERO, Vector2(fs, fs * (0.85 if swoop else 1.0)))
	var marked: bool = state == "MARK" or state == "SWOOP"
	var mo: float = clampf(open + (0.5 if marked else 0.0), 0.0, 1.0)
	rig.set_pose("eyes", 0.0, Vector2.ZERO, HIDDEN if marked else Vector2.ONE)
	rig.set_pose("eyes_marked", 0.0, Vector2.ZERO, Vector2.ONE if marked else HIDDEN)
	rig.set_pose("mouth_open", 0.0, Vector2.ZERO, Vector2(1.0, 1.0 + mo * 2.2) if mo > 0.05 else HIDDEN)
	rig.set_pose("fangs", 0.0, Vector2(0.0, mo))
	rig.draw(ci, m, Vector2(64.0, 64.0))
	if state == "PULSE":
		ci.draw_set_transform_matrix(m)
		var hc := Vector2(9.0, -2.0)
		for q in 3:
			var ph: float = fposmod(t * 3.0 + float(q) * 0.33, 1.0)
			ci.draw_arc(hc + Vector2(8.0, 3.0), 5.0 + ph * 12.0, -0.7, 0.7, 8, Color(0.85, 0.9, 1.0, 0.7 * (1.0 - ph)), 1.3, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _wing(ci: CanvasItem, flap: float, far: bool, swept: bool) -> void:
	var shade: float = 0.65 if far else 1.0
	var sh := Vector2(-2.0, -3.0)
	var alpha: float = lerpf(-2.0, 1.9, (flap + 1.0) * 0.5) + (0.12 if far else 0.0)
	if swept:
		alpha = 2.65
	var arm := Vector2(cos(alpha), sin(alpha))
	var fore: float = 0.55 + 0.45 * absf(sin(alpha))
	var wrist: Vector2 = sh + arm * 20.0 * fore
	var offs: Array[float] = [-0.5, -0.12, 0.26, 0.62]
	var lens: Array[float] = [28.0, 34.0, 30.0, 22.0]
	var poly := PackedVector2Array([sh, wrist])
	var tips: Array[Vector2] = []
	for j in 4:
		var d := Vector2(cos(alpha + offs[j] * (0.6 if swept else 1.0)), sin(alpha + offs[j] * (0.6 if swept else 1.0)))
		tips.append(wrist + d * lens[j] * fore)
	for j in 4:
		poly.append(tips[j])
		if j < 3:
			poly.append(tips[j].lerp(tips[j + 1], 0.5).lerp(wrist, 0.3))
	poly.append(sh + Vector2(-13.0, 8.0))
	var mem: Color = ViewColors.h(MEMBRANE)
	var mcol := Color(mem.r * shade, mem.g * shade, mem.b * shade, 1.0)
	for k in range(2, poly.size() - 1):
		ci.draw_colored_polygon(PackedVector2Array([wrist, poly[k], poly[k + 1]]), mcol)
	ci.draw_colored_polygon(PackedVector2Array([sh, wrist, poly[poly.size() - 1]]), mcol)
	ci.draw_colored_polygon(PackedVector2Array([wrist, poly[2], poly[poly.size() - 1]]), mcol)
	var line := Color(ViewColors.h(OUTLINE), 0.9 * shade)
	ci.draw_line(sh, wrist, line, 2.0, true)
	for t in tips:
		ci.draw_line(wrist, t, line, 1.3, true)
	var loop: PackedVector2Array = poly.duplicate()
	loop.append(poly[0])
	ci.draw_polyline(loop, Color(ViewColors.h(OUTLINE), shade), 1.3, true)


static func _body(ci: CanvasItem, t: float, state: String, open: float) -> void:
	var line: Color = ViewColors.h(OUTLINE)
	ViewUtil.fill_ellipse(ci, Vector2(-4.0, 2.0), 11.0, 8.0, ViewColors.h(FUR), -0.2)
	ViewUtil.fill_ellipse(ci, Vector2(-1.0, 4.0), 7.0, 4.5, ViewColors.h(FUR_LIGHT), -0.2)
	ViewUtil.stroke_ellipse(ci, Vector2(-4.0, 2.0), 11.0, 8.0, line, 1.3, -0.2)
	ci.draw_line(Vector2(-14.0, 6.0), Vector2(-20.0, 11.0), line, 1.5, true)
	var hc := Vector2(9.0, -2.0)
	# ears
	for e: float in [-1.0, 1.0]:
		var base: Vector2 = hc + Vector2(-1.5 + e * 2.5, -4.0)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-2.5, 0.0), base + Vector2(e * 3.0 + 1.0, -13.0), base + Vector2(3.5, 0.0)]), ViewColors.h(FUR))
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-1.0, -1.0), base + Vector2(e * 3.0 + 1.0, -10.0), base + Vector2(2.0, -1.0)]), Color(0.85, 0.55, 0.62, 0.7))
	ViewUtil.fill_ellipse(ci, hc, 7.5, 6.5, ViewColors.h(FUR))
	ViewUtil.stroke_ellipse(ci, hc, 7.5, 6.5, line, 1.3)
	ViewUtil.fill_ellipse(ci, hc + Vector2(3.5, 2.2), 4.0, 3.0, ViewColors.h(FUR_LIGHT))
	# eyes: small and round; red while it has marked her
	var marked: bool = state == "MARK" or state == "SWOOP"
	for ex: float in [0.5, 4.8]:
		var ec: Vector2 = hc + Vector2(ex, -1.2)
		ci.draw_circle(ec, 2.0, Color(1.0, 0.25, 0.2) if marked else Color(0.97, 0.95, 0.85))
		ci.draw_circle(ec + Vector2(0.4, 0.2), 1.0, Color(0.05, 0.03, 0.05))
	if marked:
		ci.draw_line(hc + Vector2(-1.5, -4.2), hc + Vector2(3.5, -2.4), line, 1.6, true)
	# nose and mouth with fangs
	ci.draw_circle(hc + Vector2(7.2, 0.8), 1.3, Color(0.85, 0.5, 0.58))
	var mo: float = clampf(open + (0.5 if marked else 0.0), 0.0, 1.0)
	ci.draw_arc(hc + Vector2(4.2, 2.6), 2.8, 0.2, PI - 0.2, 6, line, 1.2, true)
	if mo > 0.05:
		ViewUtil.fill_ellipse(ci, hc + Vector2(4.4, 3.8), 2.8, 1.0 + mo * 2.2, Color(0.25, 0.04, 0.1))
	for fx: float in [2.6, 6.0]:
		ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(fx - 0.7, 3.1), hc + Vector2(fx + 0.7, 3.1), hc + Vector2(fx, 5.0 + mo)]), Color(1.0, 0.98, 0.9))
	if state == "PULSE":
		# a few small sound arcs from the mouth
		for q in 3:
			var ph: float = fposmod(t * 3.0 + float(q) * 0.33, 1.0)
			ci.draw_arc(hc + Vector2(8.0, 3.0), 5.0 + ph * 12.0, -0.7, 0.7, 8, Color(0.85, 0.9, 1.0, 0.7 * (1.0 - ph)), 1.3, true)

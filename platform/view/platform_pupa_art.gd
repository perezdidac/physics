## Perleta as a pupa (DIG mode), drawn procedurally: a glossy brown chrysalis with segmented rings, wing-sheath lines and two cute
## eyes. She leans towards the direction she digs and wiggles while she does. Local origin is the body centre; `r` is the body radius.
class_name PlatformPupaArt
extends RefCounted

const SHELL := "#8a5a34"
const SHELL_DARK := "#4e2f19"
const SHELL_LIGHT := "#c08a55"
const OUTLINE := "#2d1a0d"
## Sprite parts (assets/sprites/creatures_platform/pupa/): 128 viewBox units = 32 art units, anchor = the body centre.
const PARTS: Array[String] = ["body", "eyes", "pupils", "lids", "cheeks", "smile", "mouth_dig"]
const HIDDEN := Vector2(0.001, 0.001)

static var _rig: CutoutRig = null


static func _get_rig() -> CutoutRig:
	if _rig == null:
		_rig = CutoutRig.new("creatures_platform", "pupa", 32.0)
		for part in PARTS:
			_rig.add_part(part, Vector2(64.0, 64.0))
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


## Draws the pupa. `o` keys: facing (-1/1), dig (Vector2 direction being dug, ZERO when not digging), wiggle (0..1),
## hurt (0..1 flash), vel (Vector2), blink (0..1 eyes closed), base (Transform2D placing the art; the art restores it).
static func draw(ci: CanvasItem, r: float, t: float, o: Dictionary) -> void:
	var dig: Vector2 = o.get("dig", Vector2.ZERO)
	var wiggle: float = float(o.get("wiggle", 0.0))
	var facing: float = float(o.get("facing", 1.0))
	var vel: Vector2 = o.get("vel", Vector2.ZERO)
	var hurt: float = float(o.get("hurt", 0.0))
	var lean: float = clampf(vel.x / 120.0, -1.0, 1.0) * 0.45 + dig.x * 0.55
	var ang: float = lean + sin(t * 24.0) * 0.16 * wiggle
	if dig.y > 0.5:
		ang += sin(t * 24.0) * 0.1 * wiggle
	var base: Transform2D = o.get("base", Transform2D.IDENTITY)
	var k: float = r / 11.0
	var squash: float = 1.0 + sin(t * 30.0) * 0.05 * wiggle
	var m: Transform2D = base * Transform2D(ang, Vector2(k * (2.0 - squash), k * squash), 0.0, Vector2(sin(t * 33.0) * 0.8 * wiggle * k, 0.0))
	var rig: CutoutRig = _get_rig()
	if rig.is_complete():
		_draw_rig(ci, rig, m, t, facing, dig, float(o.get("blink", 0.0)), hurt)
		return
	ci.draw_set_transform_matrix(m)
	_body(ci, hurt)
	_rings(ci)
	_face(ci, t, facing, dig, float(o.get("blink", 0.0)), hurt)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Sprite version: the same states as the vector face (eyes follow the dig direction, blink, closed when hurt, "o" mouth while digging).
static func _draw_rig(ci: CanvasItem, rig: CutoutRig, m: Transform2D, t: float, facing: float, dig: Vector2, blink: float, hurt: float) -> void:
	var closed: bool = blink > 0.5 or fmod(t, 3.7) > 3.58 or hurt > 0.6
	var look := Vector2(facing * 0.7 + dig.x, dig.y * 0.8)
	var digging: bool = dig.length() > 0.1
	rig.set_pose("eyes", 0.0, Vector2.ZERO, HIDDEN if closed else Vector2.ONE)
	rig.set_pose("pupils", 0.0, look * 0.9 * 4.0, HIDDEN if closed else Vector2.ONE)
	rig.set_pose("lids", 0.0, Vector2.ZERO, Vector2.ONE if closed else HIDDEN)
	rig.set_pose("smile", 0.0, Vector2.ZERO, HIDDEN if digging else Vector2.ONE)
	rig.set_pose("mouth_dig", 0.0, Vector2.ZERO, Vector2.ONE if digging else HIDDEN)
	rig.draw(ci, m, Vector2(64.0, 64.0))
	if hurt > 0.0:
		ci.draw_set_transform_matrix(m)
		ci.draw_colored_polygon(_profile(14), Color(0.95, 0.4, 0.3, hurt * 0.42))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## The chrysalis profile: round at the head (top), tapering to a blunt tail (bottom). 22 units tall, 15 wide.
static func _profile(n: int) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n + 1:
		var u: float = float(i) / float(n)
		var y: float = lerpf(-12.0, 12.5, u)
		var e: float = 1.0 - pow(2.0 * u - 1.0, 2.0)
		var w: float = 7.6 * pow(maxf(e, 0.0), 0.62) * (1.0 - 0.38 * u)
		left.append(Vector2(-w, y))
		right.append(Vector2(w, y))
	var out := PackedVector2Array(left)
	for i in range(n, -1, -1):
		out.append(right[i])
	return out


static func _body(ci: CanvasItem, hurt: float) -> void:
	var shell: Color = ViewColors.h(SHELL).lerp(Color(0.95, 0.4, 0.3), hurt * 0.5)
	var dark: Color = ViewColors.h(SHELL_DARK)
	var light: Color = ViewColors.h(SHELL_LIGHT)
	var pts: PackedVector2Array = _profile(14)
	var cols := PackedColorArray()
	for p in pts:
		var s: float = clampf((p.x + 8.0) / 16.0, 0.0, 1.0)
		cols.append(light.lerp(shell, clampf(s * 2.0, 0.0, 1.0)).lerp(dark, clampf(s * 2.0 - 1.0, 0.0, 1.0) * 0.8))
	ci.draw_polygon(pts, cols)
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, ViewColors.h(OUTLINE), 1.6, true)
	ViewUtil.fill_ellipse(ci, Vector2(-2.6, -6.5), 2.0, 3.6, Color(1.0, 0.92, 0.75, 0.38), 0.25)


## Abdomen rings and the lines of the folded wing sheaths.
static func _rings(ci: CanvasItem) -> void:
	var dark := Color(ViewColors.h(SHELL_DARK), 0.85)
	for k in 6:
		var y: float = 0.5 + float(k) * 2.0
		var u: float = (y + 12.0) / 24.5
		var w: float = 7.6 * pow(maxf(1.0 - pow(2.0 * u - 1.0, 2.0), 0.0), 0.62) * (1.0 - 0.38 * u) * 0.94
		var pts := PackedVector2Array()
		for j in 9:
			var a: float = float(j) / 8.0
			pts.append(Vector2(lerpf(-w, w, a), y + sin(a * PI) * 1.3))
		ci.draw_polyline(pts, dark, 1.0, true)
	ci.draw_polyline(PackedVector2Array([Vector2(-5.5, -3.0), Vector2(-4.5, 3.0), Vector2(-2.0, 8.5)]), Color(dark, 0.6), 1.0, true)
	ci.draw_polyline(PackedVector2Array([Vector2(5.5, -3.0), Vector2(4.5, 3.0), Vector2(2.0, 8.5)]), Color(dark, 0.6), 1.0, true)


static func _face(ci: CanvasItem, t: float, facing: float, dig: Vector2, blink: float, hurt: float) -> void:
	var look := Vector2(facing * 0.7 + dig.x, dig.y * 0.8)
	var closed: bool = blink > 0.5 or fmod(t, 3.7) > 3.58 or hurt > 0.6
	for ex: float in [-3.1, 3.1]:
		var c := Vector2(ex, -6.0)
		if closed:
			ci.draw_arc(c, 2.3, 0.2, PI - 0.2, 8, ViewColors.h(OUTLINE), 1.4, true)
			continue
		ViewUtil.fill_ellipse(ci, c, 2.7, 3.1, Color(1.0, 1.0, 0.97, 1.0))
		ViewUtil.stroke_ellipse(ci, c, 2.7, 3.1, ViewColors.h(OUTLINE), 1.0)
		var pc: Vector2 = c + look * 0.9
		ci.draw_circle(pc, 1.5, Color(0.1, 0.06, 0.04, 1.0))
		ci.draw_circle(pc + Vector2(-0.5, -0.6), 0.55, Color.WHITE)
	# rosy cheeks and a little smile
	ViewUtil.fill_ellipse(ci, Vector2(-5.2, -2.6), 1.6, 1.0, Color(1.0, 0.55, 0.5, 0.5))
	ViewUtil.fill_ellipse(ci, Vector2(5.2, -2.6), 1.6, 1.0, Color(1.0, 0.55, 0.5, 0.5))
	if dig.length() > 0.1:
		ViewUtil.fill_ellipse(ci, Vector2(0.0, -2.0), 1.6, 1.2, Color(ViewColors.h(OUTLINE), 0.9))
	else:
		ci.draw_arc(Vector2(0.0, -3.4), 1.8, 0.4, PI - 0.4, 6, ViewColors.h(OUTLINE), 1.1, true)

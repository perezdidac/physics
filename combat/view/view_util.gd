## Small drawing toolkit that mirrors the canvas 2D calls used by the original renderer (ellipse, roundRect, quadratic and
## bezier curves, dashed strokes, radial gradients, text) on top of CanvasItem.draw_*. Also duck-typed sim field access.
class_name ViewUtil
extends RefCounted

const TAU_F: float = TAU

static var _grad_cache: Dictionary = {}
static var _font: Font = null
static var _font_checked: bool = false


# ---------------------------------------------------------------- sim field access (typed classes or Dictionaries)

## Reads `key` from a Dictionary or an Object property; returns `default` when it is missing or null.
static func g(e: Variant, key: String, default: Variant = null) -> Variant:
	if e == null:
		return default
	if e is Dictionary:
		return (e as Dictionary).get(key, default)
	if e is Object:
		var v: Variant = (e as Object).get(key)
		if v == null:
			return default
		return v
	return default


## Float field.
static func gf(e: Variant, key: String, default: float = 0.0) -> float:
	var v: Variant = g(e, key, default)
	if v is float or v is int:
		return float(v)
	return default


## Int field.
static func gi(e: Variant, key: String, default: int = 0) -> int:
	var v: Variant = g(e, key, default)
	if v is float or v is int:
		return int(v)
	return default


## Bool field.
static func gb(e: Variant, key: String, default: bool = false) -> bool:
	var v: Variant = g(e, key, default)
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	return default


## String field.
static func gs(e: Variant, key: String, default: String = "") -> String:
	var v: Variant = g(e, key, default)
	if v is String or v is StringName:
		return str(v)
	return default


## Position of an entity as a Vector2.
static func pos(e: Variant) -> Vector2:
	if e is Vector2:
		return e
	return Vector2(gf(e, "x"), gf(e, "y"))


# ---------------------------------------------------------------- drawing primitives (thin wrappers over ArtKit)


static func ellipse_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 24) -> PackedVector2Array:
	return ArtKit.ellipse_pts(c, rx, ry, rot, n)


static func fill_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ArtKit.fill_poly(ci, pts, col)


static func fill_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	ArtKit.fill_ellipse(ci, c, rx, ry, col, rot)


static func stroke_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float, rot: float = 0.0) -> void:
	ArtKit.stroke_ellipse(ci, c, rx, ry, col, w, rot)


static func ellipse_fs(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, stroke: Color, w: float, rot: float = 0.0) -> void:
	ArtKit.ellipse_fs(ci, c, rx, ry, fill, stroke, w, rot)


static func circle_fs(ci: CanvasItem, c: Vector2, r: float, fill: Color, stroke: Color, w: float) -> void:
	ArtKit.circle_fs(ci, c, r, fill, stroke, w)


static func arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int = 16) -> PackedVector2Array:
	return ArtKit.arc_pts(c, r, a0, a1, n)


static func round_rect_pts(rect: Rect2, radius: float, seg: int = 5) -> PackedVector2Array:
	return ArtKit.round_rect_pts(rect, radius, seg)


static func fill_round_rect(ci: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	ArtKit.fill_round_rect(ci, rect, radius, col)


static func stroke_round_rect(ci: CanvasItem, rect: Rect2, radius: float, col: Color, w: float) -> void:
	ArtKit.stroke_round_rect(ci, rect, radius, col, w)


static func round_rect_fs(ci: CanvasItem, rect: Rect2, radius: float, fill: Color, stroke: Color, w: float) -> void:
	ArtKit.round_rect_fs(ci, rect, radius, fill, stroke, w)


static func rect_fs(ci: CanvasItem, rect: Rect2, fill: Color, stroke: Color, w: float) -> void:
	ArtKit.rect_fs(ci, rect, fill, stroke, w)


static func quad_pts(p0: Vector2, p1: Vector2, p2: Vector2, n: int = 10) -> PackedVector2Array:
	return ArtKit.quad_pts(p0, p1, p2, n)


static func bezier_pts(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int = 14) -> PackedVector2Array:
	return ArtKit.bezier_pts(p0, p1, p2, p3, n)


static func dashed(ci: CanvasItem, pts: PackedVector2Array, dash: float, gap: float, col: Color, w: float) -> void:
	ArtKit.dashed(ci, pts, dash, gap, col, w)


static func dashed_circle(ci: CanvasItem, c: Vector2, r: float, dash: float, gap: float, col: Color, w: float) -> void:
	ArtKit.dashed_circle(ci, c, r, dash, gap, col, w)


static func vgrad_rect(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, stops: Array) -> void:
	ArtKit.vgrad_rect(ci, x0, x1, y0, y1, stops)


static func radial_tex(stops: Array, key: String) -> GradientTexture2D:
	return ArtKit.radial_tex(stops, key)


static func radial(ci: CanvasItem, c: Vector2, r0: float, r1: float, stops: Array, alpha: float = 1.0, key: String = "") -> void:
	ArtKit.radial(ci, c, r0, r1, stops, alpha, key)


static func gradient_disc(ci: CanvasItem, c: Vector2, r: float, gc: Vector2, r0: float, r1: float, stops: Array, key: String) -> void:
	ArtKit.gradient_disc(ci, c, r, gc, r0, r1, stops, key)


# ---------------------------------------------------------------- text

## Font for the battle text: Plus Jakarta Sans at weight 800 from assets/fonts if shipped, else the engine default.
static func font() -> Font:
	if _font_checked:
		return _font
	_font_checked = true
	var path: String = "res://assets/fonts/PlusJakartaSans.ttf"
	if ResourceLoader.exists(path):
		var base: Font = load(path) as Font
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {0x77676874: 800}
		_font = fv
	else:
		_font = ThemeDB.fallback_font
	return _font


## Width of `s` at `size`.
static func text_w(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Draws text with the baseline at `p` (canvas fillText); `center` aligns around p.x.
static func text(ci: CanvasItem, s: String, p: Vector2, size: int, col: Color, center: bool = true) -> void:
	var f: Font = font()
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = p.x - w * 0.5 if center else p.x
	ci.draw_string(f, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# ---------------------------------------------------------------- misc math

## JS clamp: returns lo for NaN / INF.
static func clamp_js(v: float, lo: float, hi: float) -> float:
	if is_nan(v) or is_inf(v):
		return lo
	return maxf(lo, minf(hi, v))


## Frame-rate independent smoothing factor used by the camera (1 - 0.015^dt).
static func cam_lerp(dt: float) -> float:
	return 1.0 - pow(0.015, dt)



## Converts an Image / Texture2D coming from the sim into a Texture2D (cached per instance).
static func as_texture(v: Variant) -> Texture2D:
	if v is Texture2D:
		return v
	if v is Image:
		var id: int = (v as Image).get_instance_id()
		var k: String = "img%d" % id
		if _grad_cache.has(k):
			return _grad_cache[k]
		var t: ImageTexture = ImageTexture.create_from_image(v)
		_grad_cache[k] = t
		return t
	return null


## Translated text through the engine (keys are the English upper-snake ids of docs/port_contracts.md); falls back to a
## readable English string if the key has no translation yet.
static func tr_text(key: String) -> String:
	var s: String = TranslationServer.translate(key)
	if s == key and FALLBACK_TEXT.has(key):
		return FALLBACK_TEXT[key]
	return s


const FALLBACK_TEXT: Dictionary = {
	"AIM_AIRSTRIKE_TARGET": "FIRE RAID TARGET",
	"AIM_AIRSTRIKE_HINT": "UP/DOWN OR TAP: MOVE TARGET · SPACE/FIRE: ATTACK",
	"AIM_SWITCH_HINT": "TAB / TAP WORM: SWITCH",
	"TRACKER_METERS": "▲ %dm",
	"TOUCH_TARGET": "FIRE RAID TARGET",
	"TOUCH_JUMP": "JUMP!",
	"TOUCH_BACKFLIP": "BACKFLIP!",
}

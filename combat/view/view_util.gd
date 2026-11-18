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


# ---------------------------------------------------------------- shape points

## Points of an ellipse (closed implicitly).
static func ellipse_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cr: float = cos(rot)
	var sr: float = sin(rot)
	for i in n:
		var a: float = TAU_F * float(i) / float(n)
		var lx: float = cos(a) * rx
		var ly: float = sin(a) * ry
		pts.append(c + Vector2(lx * cr - ly * sr, lx * sr + ly * cr))
	return pts


## Fills any polygon; self-intersecting outlines (which Godot cannot triangulate) fall back to a centroid fan.
static func fill_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		var c := Vector2.ZERO
		for p in pts:
			c += p
		c /= float(pts.size())
		for i in pts.size():
			ci.draw_colored_polygon(PackedVector2Array([c, pts[i], pts[(i + 1) % pts.size()]]), col)
		return
	ci.draw_colored_polygon(pts, col)


## Filled ellipse.
static func fill_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var n: int = 24 if maxf(rx, ry) < 40.0 else 40
	ci.draw_colored_polygon(ellipse_pts(c, rx, ry, rot, n), col)


## Stroked ellipse.
static func stroke_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float, rot: float = 0.0) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var n: int = 24 if maxf(rx, ry) < 40.0 else 40
	var pts: PackedVector2Array = ellipse_pts(c, rx, ry, rot, n)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, w, true)


## Filled + stroked ellipse (fill then stroke, like ctx.fill(); ctx.stroke()).
static func ellipse_fs(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, stroke: Color, w: float, rot: float = 0.0) -> void:
	fill_ellipse(ci, c, rx, ry, fill, rot)
	stroke_ellipse(ci, c, rx, ry, stroke, w, rot)


## Filled + stroked circle.
static func circle_fs(ci: CanvasItem, c: Vector2, r: float, fill: Color, stroke: Color, w: float) -> void:
	ci.draw_circle(c, r, fill)
	ci.draw_arc(c, r, 0.0, TAU_F, 24, stroke, w, true)


## Arc points from a0 to a1 (radians, canvas convention y down).
static func arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Points of a rounded rectangle.
static func round_rect_pts(rect: Rect2, radius: float, seg: int = 5) -> PackedVector2Array:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var x0: float = rect.position.x
	var y0: float = rect.position.y
	var x1: float = rect.end.x
	var y1: float = rect.end.y
	var centers: Array[Vector2] = [Vector2(x1 - r, y0 + r), Vector2(x1 - r, y1 - r), Vector2(x0 + r, y1 - r), Vector2(x0 + r, y0 + r)]
	for k in 4:
		var a0: float = -PI * 0.5 + float(k) * PI * 0.5
		for i in seg + 1:
			var a: float = a0 + (PI * 0.5) * float(i) / float(seg)
			pts.append(centers[k] + Vector2(cos(a), sin(a)) * r)
	return pts


## Filled rounded rectangle.
static func fill_round_rect(ci: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	ci.draw_colored_polygon(round_rect_pts(rect, radius), col)


## Stroked rounded rectangle.
static func stroke_round_rect(ci: CanvasItem, rect: Rect2, radius: float, col: Color, w: float) -> void:
	var pts: PackedVector2Array = round_rect_pts(rect, radius)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, w, true)


## Filled + stroked rounded rectangle.
static func round_rect_fs(ci: CanvasItem, rect: Rect2, radius: float, fill: Color, stroke: Color, w: float) -> void:
	fill_round_rect(ci, rect, radius, fill)
	stroke_round_rect(ci, rect, radius, stroke, w)


## Filled + stroked rectangle.
static func rect_fs(ci: CanvasItem, rect: Rect2, fill: Color, stroke: Color, w: float) -> void:
	ci.draw_rect(rect, fill, true)
	ci.draw_rect(rect, stroke, false, w)


## Points of a quadratic curve.
static func quad_pts(p0: Vector2, p1: Vector2, p2: Vector2, n: int = 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t: float = float(i) / float(n)
		var u: float = 1.0 - t
		pts.append(p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t))
	return pts


## Points of a cubic bezier.
static func bezier_pts(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t: float = float(i) / float(n)
		var u: float = 1.0 - t
		pts.append(p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t))
	return pts


## Draws a polyline split into dashes (canvas setLineDash([dash, gap])).
static func dashed(ci: CanvasItem, pts: PackedVector2Array, dash: float, gap: float, col: Color, w: float) -> void:
	if pts.size() < 2:
		return
	var draw_on: bool = true
	var remain: float = dash
	var cur := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var seg_len: float = a.distance_to(b)
		if seg_len < 0.0001:
			continue
		var dir: Vector2 = (b - a) / seg_len
		var walked: float = 0.0
		while seg_len - walked > remain:
			walked += remain
			var p: Vector2 = a + dir * walked
			if draw_on:
				cur.append(p)
				ci.draw_polyline(cur, col, w, true)
			cur = PackedVector2Array([p])
			draw_on = not draw_on
			remain = dash if draw_on else gap
		remain -= seg_len - walked
		if draw_on:
			cur.append(b)
	if draw_on and cur.size() >= 2:
		ci.draw_polyline(cur, col, w, true)


## Dashed circle.
static func dashed_circle(ci: CanvasItem, c: Vector2, r: float, dash: float, gap: float, col: Color, w: float) -> void:
	dashed(ci, arc_pts(c, r, 0.0, TAU_F, 48), dash, gap, col, w)


## Vertical linear gradient rectangle between y0..y1 with stops [[offset, Color], ...] (cut into horizontal bands).
static func vgrad_rect(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, stops: Array) -> void:
	for i in range(stops.size() - 1):
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		var ya: float = lerpf(y0, y1, float(a[0]))
		var yb: float = lerpf(y0, y1, float(b[0]))
		if yb <= ya:
			continue
		var pts := PackedVector2Array([Vector2(x0, ya), Vector2(x1, ya), Vector2(x1, yb), Vector2(x0, yb)])
		var cols := PackedColorArray([a[1], a[1], b[1], b[1]])
		ci.draw_polygon(pts, cols)


# ---------------------------------------------------------------- radial gradients

## Returns a cached radial GradientTexture2D for stops [[offset (0..1 of outer radius), Color], ...].
static func radial_tex(stops: Array, key: String) -> GradientTexture2D:
	if _grad_cache.has(key):
		return _grad_cache[key]
	var grad := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(clampf(float(s[0]), 0.0, 1.0))
		cols.append(s[1])
	grad.offsets = offs
	grad.colors = cols
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 96
	tex.height = 96
	_grad_cache[key] = tex
	return tex


## Radial gradient disc like ctx.createRadialGradient(c, r0, c, r1) filled over the circle of radius r1.
## stops are [[offset in 0..1 between r0 and r1, Color], ...]; `alpha` multiplies the whole thing.
static func radial(ci: CanvasItem, c: Vector2, r0: float, r1: float, stops: Array, alpha: float = 1.0, key: String = "") -> void:
	if r1 <= 0.5 or alpha <= 0.0:
		return
	var inner: float = clampf(r0 / r1, 0.0, 0.98)
	var rmp: Array = []
	if inner > 0.0:
		rmp.append([0.0, (stops[0] as Array)[1]])
	for s in stops:
		rmp.append([inner + float(s[0]) * (1.0 - inner), s[1]])
	var k: String = key
	if k == "":
		k = str(rmp)
	var tex: GradientTexture2D = radial_tex(rmp, k)
	ci.draw_texture_rect(tex, Rect2(c - Vector2(r1, r1), Vector2(r1, r1) * 2.0), false, Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))


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



## Disc of radius `r` at `c` filled with a radial gradient whose centre is `gc` (canvas createRadialGradient(gc, r0, c, r1)
## with the focal point approximated by the gradient centre). Stops: [[offset, Color], ...].
static func gradient_disc(ci: CanvasItem, c: Vector2, r: float, gc: Vector2, r0: float, r1: float, stops: Array, key: String) -> void:
	var inner: float = clampf(r0 / r1, 0.0, 0.98)
	var rmp: Array = []
	if inner > 0.0:
		rmp.append([0.0, (stops[0] as Array)[1]])
	for s in stops:
		rmp.append([inner + float(s[0]) * (1.0 - inner), s[1]])
	var tex: GradientTexture2D = radial_tex(rmp, key)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 20:
		var a: float = TAU_F * float(i) / 20.0
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * r
		pts.append(p)
		uvs.append((p - gc) / (2.0 * r1) + Vector2(0.5, 0.5))
	ci.draw_colored_polygon(pts, Color.WHITE, uvs, tex)


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

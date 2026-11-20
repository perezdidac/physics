## Shared drawing primitives of every art class: polygons with fill + stroke, ellipses, rounded rects, curves, dashes,
## gradients, soft ground shadows, transform helpers and the cached "#rrggbb" colour parser. Pure static, no state besides caches.
## ViewUtil / ViewColors keep their old names as thin wrappers over this class.
class_name ArtKit
extends RefCounted

static var _grad_cache: Dictionary = {}
static var _hex_cache: Dictionary = {}


# ---------------------------------------------------------------- colour

## "#rrggbb" (or any Color() string) parsed once and cached.
static func hex(s: String) -> Color:
	if _hex_cache.has(s):
		return _hex_cache[s]
	var c := Color(s)
	_hex_cache[s] = c
	return c


# ---------------------------------------------------------------- transforms

## Sets the item's draw transform to translate(p) * rotate(rot) * scale(sc).
static func place(ci: CanvasItem, p: Vector2, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	ci.draw_set_transform_matrix(Transform2D(rot, sc, 0.0, p))


## Back to the identity draw transform.
static func reset(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------- polygons

## Filled polygon with an optional closed outline of width `w` (0 = no outline).
static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, stroke: Color = Color.TRANSPARENT, w: float = 0.0) -> void:
	fill_poly(ci, pts, fill)
	if w > 0.0:
		var c: PackedVector2Array = pts.duplicate()
		c.append(pts[0])
		ci.draw_polyline(c, stroke, w, true)


## Soft contact shadow: a few stacked translucent ellipses centred at `c` (reads as a blurred disc without a shader).
static func soft_shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float, a: float = 0.4) -> void:
	for k in 4:
		var u: float = 1.0 - float(k) * 0.2
		fill_ellipse(ci, c, rx * u, ry * u, Color(0.0235, 0.0314, 0.0549, a * 0.3))


# ---------------------------------------------------------------- shape points

## Points of an ellipse (closed implicitly).
static func ellipse_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cr: float = cos(rot)
	var sr: float = sin(rot)
	for i in n:
		var a: float = TAU * float(i) / float(n)
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
	ci.draw_arc(c, r, 0.0, TAU, 24, stroke, w, true)


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
	dashed(ci, arc_pts(c, r, 0.0, TAU, 48), dash, gap, col, w)


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
		var a: float = TAU * float(i) / 20.0
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * r
		pts.append(p)
		uvs.append((p - gc) / (2.0 * r1) + Vector2(0.5, 0.5))
	ci.draw_colored_polygon(pts, Color.WHITE, uvs, tex)


# ---------------------------------------------------------------- tints

## `hex` darkened towards night blue by `night` (0 = unchanged, 1 = 60 % blue); the platformer levels' night look.
static func night_tint(hex_color: String, night: float) -> Color:
	return hex(hex_color).lerp(Color(0.05, 0.08, 0.2, 1.0), 0.6 * night)

## Helper that builds and draws the chamfered (diagonally cut corners) panels of the original CSS clip-path polygons.
class_name ChamferShape
extends RefCounted


## Polygon points of `rect` with each corner cut by `cuts` = (top-left, top-right, bottom-right, bottom-left) pixels.
static func points(rect: Rect2, cuts: Vector4) -> PackedVector2Array:
	var l: float = rect.position.x
	var t: float = rect.position.y
	var r: float = rect.end.x
	var b: float = rect.end.y
	var pts := PackedVector2Array()
	if cuts.x > 0.0:
		pts.append(Vector2(l, t + cuts.x))
		pts.append(Vector2(l + cuts.x, t))
	else:
		pts.append(Vector2(l, t))
	if cuts.y > 0.0:
		pts.append(Vector2(r - cuts.y, t))
		pts.append(Vector2(r, t + cuts.y))
	else:
		pts.append(Vector2(r, t))
	if cuts.z > 0.0:
		pts.append(Vector2(r, b - cuts.z))
		pts.append(Vector2(r - cuts.z, b))
	else:
		pts.append(Vector2(r, b))
	if cuts.w > 0.0:
		pts.append(Vector2(l + cuts.w, b))
		pts.append(Vector2(l, b - cuts.w))
	else:
		pts.append(Vector2(l, b))
	return pts


## Draws the filled chamfered shape (vertical gradient `top` to `bottom`) and its border on `item`.
static func draw(item: CanvasItem, rect: Rect2, cuts: Vector4, top: Color, bottom: Color, border: Color, border_width: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var inset: float = border_width * 0.5
	var inner := rect.grow(-inset)
	var pts: PackedVector2Array = points(inner, cuts)
	var colors := PackedColorArray()
	for p in pts:
		var k: float = clampf((p.y - inner.position.y) / maxf(inner.size.y, 1.0), 0.0, 1.0)
		colors.append(top.lerp(bottom, k))
	if top.a > 0.0 or bottom.a > 0.0:
		item.draw_polygon(pts, colors)
	if border_width > 0.0 and border.a > 0.0:
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		item.draw_polyline(loop, border, border_width, true)

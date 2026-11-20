## A shallow puddle on the ground: a muddy rim (puddle_rim.svg) and a few stones (puddle_stones.svg) are sprites; the sky-coloured water,
## shimmer, glints and rain ripples are code between them. State: {i: index, rect: Rect2(x, ground_y - h, w, h), storm: bool}.
class_name PuddleArt
extends ThingArt

const IDS: Array[String] = ["puddle_rim", "puddle_stones"]
var _fallback: ThingArt = PuddleVectorArt.new()


func vector_fallback() -> ThingArt:
	return _fallback


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	if not PlatformSprites.has_all(IDS):
		_fallback.draw(ci, state, ctx)
		return
	var i: int = ViewUtil.gi(state, "i")
	var r: Rect2 = state["rect"]
	var storm: bool = ViewUtil.gb(state, "storm")
	var t: float = ctx.t
	var c := Vector2(r.get_center().x, r.end.y + 1.0)
	var rx: float = r.size.x * 0.5
	var ry: float = clampf(r.size.y * 1.1, 6.0, 12.0)
	var sky: Color = Color(0.5, 0.62, 0.78) if storm else Color(0.7, 0.82, 0.9)
	# sprite rect: the 124 x 28 unit ellipse (centre 128, 34 of a 256 x 64 viewBox) lands on the rim ellipse (rx + 4, ry + 2.5)
	var sx: float = (rx + 4.0) / 124.0
	var sy: float = (ry + 2.5) / 28.0
	var rim := Rect2(c + Vector2(0.0, 1.0) - Vector2(128.0 * sx, 34.0 * sy), Vector2(256.0 * sx, 64.0 * sy))
	ci.draw_texture_rect(PlatformSprites.tex("puddle_rim"), rim, false)
	var pts: PackedVector2Array = ViewUtil.ellipse_pts(c, rx, ry)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(sky.lerp(Color(0.18, 0.26, 0.38), clampf((p.y - (c.y - ry)) / (2.0 * ry), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	ViewUtil.fill_ellipse(ci, c + Vector2(-rx * 0.15, -ry * 0.35), rx * 0.62, ry * 0.28, Color(1.0, 1.0, 1.0, 0.22))
	for k in 5:
		var fk: float = float(k)
		var gx: float = c.x + sin(t * 0.8 + fk * 2.1 + float(i)) * rx * 0.7
		var gy: float = c.y + (fk - 2.0) * ry * 0.3
		var gl: float = rx * (0.12 + 0.06 * sin(t * 1.7 + fk))
		ci.draw_line(Vector2(gx - gl, gy), Vector2(gx + gl, gy), Color(1.0, 1.0, 1.0, 0.35 + 0.25 * sin(t * 2.5 + fk * 1.3 + float(i))), 1.2, true)
	var speed: float = 1.1 if storm else 0.35
	for k in 3:
		var u: float = fposmod(t * speed + float(k) / 3.0 + float(i) * 0.37, 1.0)
		var h1: float = fposmod(sin(float(k * 7 + i * 13)) * 4375.85, 1.0)
		var rc := Vector2(c.x + (h1 - 0.5) * rx * 1.2, c.y + (fposmod(h1 * 7.0, 1.0) - 0.5) * ry * 0.7)
		ViewUtil.stroke_ellipse(ci, rc, 2.0 + u * rx * 0.22, (2.0 + u * rx * 0.22) * 0.3, Color(1.0, 1.0, 1.0, 0.55 * (1.0 - u)), 1.0)
	ViewUtil.stroke_ellipse(ci, c, rx, ry, Color(0.25, 0.3, 0.38, 0.9), 1.3)
	ci.draw_arc(c, rx, PI + 0.5, TAU - 0.5, 16, Color(1.0, 1.0, 1.0, 0.35), 1.2, true)
	ci.draw_texture_rect(PlatformSprites.tex("puddle_stones"), rim, false)


func sample_state() -> Variant:
	return {"i": 0, "rect": Rect2(-30.0, -4.0, 60.0, 4.0), "storm": false}


func sample_extent() -> Vector2:
	return Vector2(90.0, 30.0)

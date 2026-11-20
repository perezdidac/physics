## A silk thread stretched between two anchors; it vibrates when hit.
class_name SilkWebArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var w: Variant = state
	var t: float = ctx.t
	var p1 := Vector2(ViewUtil.gf(w, "x1"), ViewUtil.gf(w, "y1"))
	var p2 := Vector2(ViewUtil.gf(w, "x2"), ViewUtil.gf(w, "y2"))
	var mid: Vector2 = (p1 + p2) * 0.5
	var d: Vector2 = p2 - p1
	var ln: float = maxf(1.0, d.length())
	var n := Vector2(-d.y / ln, d.x / ln)
	var vib: float = sin(t * 42.0) * ViewUtil.gf(w, "vibration") * 9.0
	# soft halo along the strand, then the knots at both anchors
	ci.draw_polyline(ViewUtil.quad_pts(p1, mid + n * vib, p2, 12), Color(1.0, 0.95, 0.75, 0.16), 6.0, true)
	for e: Vector2 in [p1, p2]:
		ArtKit.circle_fs(ci, e, 3.6, ViewColors.h("#fff6df"), ViewColors.h("#b08a45"), 1.1)
		ci.draw_circle(e + Vector2(-1.0, -1.1), 1.1, Color(1, 1, 1, 0.9))
	for s in range(-1, 2):
		var col: Color = Color(1.0, 0.9725, 0.8824, 0.95) if s == 0 else Color(0.9608, 0.7255, 0.2706, 0.55)
		ci.draw_polyline(ViewUtil.quad_pts(p1, mid + n * (vib + float(s) * 4.0), p2, 12), col, 2.6 if s == 0 else 1.3, true)
	_dew(ci, p1, mid + n * vib, p2)


func _dew(ci: CanvasItem, p1: Vector2, mid: Vector2, p2: Vector2) -> void:
	for u: float in [0.3, 0.55, 0.78]:
		var q: Vector2 = ViewUtil.quad_pts(p1, mid, p2, 12)[int(u * 12.0)]
		ci.draw_circle(q + Vector2(0.0, 1.6), 1.1, Color(0.85, 0.95, 1.0, 0.8))


func sample_state() -> Variant:
	return {"x1": -30.0, "y1": -20.0, "x2": 30.0, "y2": -20.0, "vibration": 0.3}


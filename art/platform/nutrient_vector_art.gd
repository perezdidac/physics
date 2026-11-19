## (Vector fallback of the sprite art.) A sap drop (nutrient pickup): bobbing, glowing teardrop with a twinkle. State: {i: index, p: world position}.
class_name NutrientVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var i: int = ViewUtil.gi(state, "i")
	var p: Vector2 = state["p"]
	var t: float = ctx.t
	var bob: float = sin(t * 2.3 + float(i) * 1.7) * 3.0
	ci.draw_set_transform(p + Vector2(0.0, bob), 0.0, Vector2(1.4, 1.4))
	var c := Vector2.ZERO
	var pulse: float = 0.5 + 0.5 * sin(t * 3.0 + float(i))
	for k in 4:
		ci.draw_circle(c, 22.0 - float(k) * 4.5, Color(1.0, 0.72, 0.2, 0.07 + 0.03 * pulse + float(k) * 0.03))
	var pts := PackedVector2Array()
	for k in 21:
		var a: float = float(k) / 20.0 * TAU
		# teardrop: a circle whose top is pulled into a point
		var px: float = sin(a) * 6.5
		var py: float = -cos(a) * 6.5
		if py < 0.0:
			px *= 1.0 - (-py / 6.5) * 0.85
			py *= 1.7
		pts.append(c + Vector2(px, py + 2.0))
	ci.draw_colored_polygon(pts, ViewColors.h("#ffb938"))
	ci.draw_polyline(pts, ViewColors.h("#b8680f"), 1.5, true)
	ViewUtil.fill_ellipse(ci, c + Vector2(-2.2, 2.2), 1.8, 2.6, Color(1.0, 0.97, 0.78, 0.9), 0.3)
	# twinkle
	var tw: float = maxf(0.0, sin(t * 2.0 + float(i) * 2.1))
	if tw > 0.0:
		var s: float = 4.0 + 6.0 * tw
		var sp: Vector2 = c + Vector2(8.0, -10.0)
		var col := Color(1.0, 0.98, 0.8, tw)
		ci.draw_line(sp - Vector2(s, 0.0), sp + Vector2(s, 0.0), col, 1.3, true)
		ci.draw_line(sp - Vector2(0.0, s), sp + Vector2(0.0, s), col, 1.3, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func sample_state() -> Variant:
	return {"i": 0, "p": Vector2(0.0, -14.0)}

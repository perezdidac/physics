## The explosive barrel, drawn in code (fallback of the BarrelArt sprite).
class_name BarrelVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, _ctx: ArtContext) -> void:
	var b: Variant = state
	var r: float = ViewUtil.gf(b, "r", 14.0)
	ArtKit.place(ci, ViewUtil.pos(b))
	var rect := Rect2(-r * 0.85, -r, r * 1.7, r * 2.0)
	var pts: PackedVector2Array = ViewUtil.round_rect_pts(rect, 3.0)
	var cols := PackedColorArray()
	for p in pts:
		var tt: float = clampf((p.x + r) / (2.0 * r), 0.0, 1.0)
		cols.append(ViewColors.h("#591c15").lerp(ViewColors.h("#a63427"), clampf(tt / 0.4, 0.0, 1.0)).lerp(ViewColors.h("#3b110c"), clampf((tt - 0.4) / 0.6, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	ViewUtil.stroke_round_rect(ci, rect, 3.0, ViewColors.h("#1a1210"), 1.8)
	var band := ViewColors.h("#2d3138")
	ci.draw_line(Vector2(-r * 0.85, -r * 0.4), Vector2(r * 0.85, -r * 0.4), band, 2.5, true)
	ci.draw_line(Vector2(-r * 0.85, r * 0.4), Vector2(r * 0.85, r * 0.4), band, 2.5, true)
	ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)]), ViewColors.h("#f3c66f"))
	ArtKit.reset(ci)


func sample_state() -> Variant:
	return {"x": 0.0, "y": -14.0, "r": 14.0}

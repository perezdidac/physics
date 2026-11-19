## Surface plant of the remaining maps.
class_name FloraDefaultArt
extends FloraArt


func _draw_plant(ci: CanvasItem, _fl: Variant, variant: int, _sway: float, _sc: float) -> void:
	if _draw_sprite(ci, "default", variant, 3):
		return
	var col: Color = ViewColors.h("#d9531e") if variant == 0 else (ViewColors.h("#e89b2d") if variant == 1 else ViewColors.h("#6e8c3a"))
	for b in range(-1, 2):
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(0, 1), Vector2(float(b) * 4.0, -6), Vector2(float(b) * 6.0, -11), 6), ViewColors.h("#4a2e18"), 1.4, true)
		ViewUtil.fill_ellipse(ci, Vector2(float(b) * 5.0, -9), 3.4, 2.0, col, float(b) * 0.4)

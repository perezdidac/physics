## Surface plant of the "MONTBLANC" maps.
class_name FloraMontblancArt
extends FloraArt


func _draw_plant(ci: CanvasItem, _fl: Variant, variant: int, _sway: float, _sc: float) -> void:
	if _draw_sprite(ci, "montblanc", variant, 1):
		return
	ci.draw_polyline(ViewUtil.quad_pts(Vector2(0, 1), Vector2(1.5, -6), Vector2(0, -12), 6), ViewColors.h("#2e5928"), 1.6, true)
	ci.draw_circle(Vector2(0, -12.5), 3.0, ViewColors.h("#d50000"))
	ci.draw_arc(Vector2(0, -12.5), 1.4, 0.0, PI * 1.4, 8, ViewColors.h("#ff8a80"), 0.9, true)

## Surface plant of the "DELTA_EBRE" maps.
class_name FloraDeltaEbreArt
extends FloraArt


func _draw_plant(ci: CanvasItem, _fl: Variant, variant: int, _sway: float, _sc: float) -> void:
	if _draw_sprite(ci, "delta_ebre", variant, 1):
		return
	for b in range(-1, 2):
		var rx: float = float(b) * 3.5
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(rx * 0.4, 1), Vector2(rx, -8), Vector2(rx * 1.3, -15), 6), ViewColors.h("#6c8f3f"), 1.5, true)
	ViewUtil.fill_round_rect(ci, Rect2(-1.6, -13, 3.2, 5.5), 1.5, ViewColors.h("#5c381e"))

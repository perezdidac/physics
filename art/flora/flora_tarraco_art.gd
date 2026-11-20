## Surface plant of the "TARRACO" maps.
class_name FloraTarracoArt
extends FloraArt


func _draw_plant(ci: CanvasItem, _fl: Variant, variant: int, _sway: float, _sc: float) -> void:
	if _draw_sprite(ci, "tarraco", variant, 1):
		return
	for b in [-1, 1]:
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(0, 1), Vector2(float(b) * 3.0, -6), Vector2(float(b) * 4.5, -11), 6), ViewColors.h("#4e7332"), 1.4, true)
		ci.draw_circle(Vector2(float(b) * 4.5, -11), 2.6, ViewColors.h("#e53935"))
		ci.draw_circle(Vector2(float(b) * 4.5, -11), 0.9, ViewColors.h("#1c1816"))

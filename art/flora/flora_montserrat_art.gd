## Surface plant of the "MONTSERRAT" maps.
class_name FloraMontserratArt
extends FloraArt


func _draw_plant(ci: CanvasItem, _fl: Variant, variant: int, _sway: float, _sc: float) -> void:
	if _draw_sprite(ci, "montserrat", variant, 2):
		return
	for b in range(-2, 3):
		var bx: float = float(b) * 3.2
		var bh: float = 9.0 + float(2 - absi(b)) * 3.0
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(0, 1), Vector2(bx * 0.5, -bh * 0.5), Vector2(bx, -bh), 6), ViewColors.h("#3b5c34"), 1.6, true)
		ci.draw_circle(Vector2(bx, -bh), 1.6, ViewColors.h("#ffd54f") if variant == 0 else ViewColors.h("#b39ddb"))

## Surface plant of the "TAULL" maps.
class_name FloraTaullArt
extends FloraArt


func _draw_plant(ci: CanvasItem, _fl: Variant, variant: int, _sway: float, _sc: float) -> void:
	if _draw_sprite(ci, "taull", variant, 1):
		return
	ci.draw_line(Vector2(0, 1), Vector2(0, -10), ViewColors.h("#4a6b53"), 1.5, true)
	for p in 5:
		var a: float = float(p) / 5.0 * TAU
		ViewUtil.fill_ellipse(ci, Vector2(cos(a) * 3.2, -10.0 + sin(a) * 3.2), 2.2, 1.1, ViewColors.h("#f4f9ff"), a)
	ci.draw_circle(Vector2(0, -10), 1.5, ViewColors.h("#ffe082"))

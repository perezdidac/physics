## Surface plant of the "PEDRAFORCA" maps.
class_name FloraPedraforcaArt
extends FloraArt


func _draw_plant(ci: CanvasItem, _fl: Variant, variant: int, _sway: float, _sc: float) -> void:
	if _draw_sprite(ci, "pedraforca", variant, 1):
		return
	ci.draw_line(Vector2(0, 1), Vector2(-2, -9), ViewColors.h("#3b6952"), 1.5, true)
	ci.draw_line(Vector2(0, 1), Vector2(2.5, -10), ViewColors.h("#3b6952"), 1.5, true)
	ci.draw_circle(Vector2(-2, -9.5), 2.3, ViewColors.h("#448aff"))
	ci.draw_circle(Vector2(2.5, -10.5), 2.5, ViewColors.h("#448aff"))

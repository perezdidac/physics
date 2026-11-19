## A glowing pine nut that rolls in the wind.
class_name PineNutVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var pn: Variant = state
	var t: float = ctx.t
	var p: Vector2 = ViewUtil.pos(pn)
	ViewUtil.radial(ci, p, 1.0, 11.0, [[0.0, Color(1.0, 0.8824, 0.451, 0.85)], [1.0, Color(1.0, 0.7451, 0.2353, 0.0)]], 1.0, "nut_glow")
	ViewUtil.ellipse_fs(ci, p, 5.5, 3.8, ViewColors.h("#f6cf77"), ViewColors.h("#6e471b"), 1.4, sin(t * 4.0) * 0.3)


func sample_state() -> Variant:
	return {"x": 0.0, "y": -6.0}

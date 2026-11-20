## A swarm of four tiny larvae wriggling around a point.
class_name LarvaeSwarmVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var sw: Variant = state
	var t: float = ctx.t
	var p: Vector2 = ViewUtil.pos(sw)
	for k in 4:
		var lx: float = cos(t * 12.0 + float(k) * 1.6) * 7.0
		var ly: float = sin(t * 15.0 + float(k) * 2.1) * 4.0
		ViewUtil.ellipse_fs(ci, p + Vector2(lx, ly), 4.2, 2.2, ViewColors.h("#252934"), ViewColors.h("#ffae42"), 1.0)


func sample_state() -> Variant:
	return {"x": 0.0, "y": -6.0}

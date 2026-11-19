## The supply crate or medkit, drawn in code. It is the fallback of the CrateArt sprite and, for now, the art of the medkit variant.
class_name CrateVectorArt
extends ThingArt

var _parachute := ParachuteArt.new()


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var c: Variant = state
	var med: bool = ViewUtil.gb(c, "is_medkit")
	_parachute.draw(ci, c, ctx)
	ArtKit.place(ci, ViewUtil.pos(c))
	ViewUtil.rect_fs(ci, Rect2(-10, -10, 20, 20), ViewColors.h("#e8e4dc") if med else ViewColors.h("#7a5434"), ViewColors.h("#1b1612"), 1.8)
	if med:
		ci.draw_rect(Rect2(-2.5, -6.5, 5, 13), ViewColors.h("#d93829"))
		ci.draw_rect(Rect2(-6.5, -2.5, 13, 5), ViewColors.h("#d93829"))
	else:
		ci.draw_rect(Rect2(-7, -7, 14, 14), ViewColors.h("#c89b52"), false, 1.8)
		ci.draw_line(Vector2(-7, -7), Vector2(7, 7), ViewColors.h("#c89b52"), 1.8, true)
	ArtKit.reset(ci)


func sample_state() -> Variant:
	return {"x": 0.0, "y": -10.0, "is_medkit": false, "parachuting": false}

## The proximity mine: a dark disc with a blinking light (fast when triggered).
class_name MineVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var m: Variant = state
	var t: float = ctx.t
	ArtKit.place(ci, ViewUtil.pos(m))
	ViewUtil.ellipse_fs(ci, Vector2(0, 1), 8.0, 4.5, ViewColors.h("#3b424c"), ViewColors.h("#14161a"), 1.6)
	var on: bool = (sin(t * 32.0) > 0.0) if ViewUtil.gb(m, "triggered") else (sin(t * 3.0) > 0.7)
	ci.draw_circle(Vector2(0, -2.5), 2.6, ViewColors.h("#ff3b30") if on else ViewColors.h("#6e1c18"))
	ArtKit.reset(ci)


func sample_state() -> Variant:
	return {"x": 0.0, "y": -5.0, "triggered": false}

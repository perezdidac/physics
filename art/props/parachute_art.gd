## The parachute of a falling crate (ropes + dome), drawn in code over / behind both the vector crate and the crate sprite.
## State: the crate. Does nothing unless it is parachuting; leaves the draw transform at identity.
class_name ParachuteArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	if not ViewUtil.gb(state, "parachuting"):
		return
	var med: bool = ViewUtil.gb(state, "is_medkit")
	var sway: float = sin(ctx.t * 3.5 + ViewUtil.gf(state, "x") * 0.05) * 0.16
	ArtKit.place(ci, ViewUtil.pos(state), sway)
	var rope := Color(0.9373, 0.9098, 0.8549, 0.65)
	ci.draw_line(Vector2(-8, -8), Vector2(-18, -28), rope, 1.2, true)
	ci.draw_line(Vector2(8, -8), Vector2(18, -28), rope, 1.2, true)
	ci.draw_line(Vector2(0, -8), Vector2(0, -30), rope, 1.2, true)
	var dome: PackedVector2Array = ViewUtil.arc_pts(Vector2(0, -26), 19.0, PI, TAU, 14)
	ArtKit.poly(ci, dome, ViewColors.h("#d9483b") if med else ViewColors.h("#d99b43"), ViewColors.h("#181a20"), 1.6)
	ArtKit.reset(ci)


func sample_state() -> Variant:
	return {"x": 0.0, "y": -10.0, "is_medkit": false, "parachuting": true}

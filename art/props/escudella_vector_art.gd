## The pot of escudella over a fire, with a bobbing meatball.
class_name EscudellaVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var ol: Variant = state
	var t: float = ctx.t
	var sp: float = ViewUtil.gf(ol, "steam_phase")
	ArtKit.place(ci, ViewUtil.pos(ol))
	ViewUtil.fill_ellipse(ci, Vector2(0, 11), 11.0, 3.2, ViewColors.h("#ff7b29") if sin(t * 9.0 + sp) > 0.0 else ViewColors.h("#e03e1a"))
	var pot := ViewUtil.arc_pts(Vector2(0, 1), 13.0, 0.0, PI, 14)
	pot.append(Vector2(-11, -6))
	pot.append(Vector2(11, -6))
	var edge := ViewColors.h("#0e1014")
	ArtKit.poly(ci, pot, ViewColors.h("#23262e"), edge, 1.6)
	ci.draw_polyline(ViewUtil.arc_pts(Vector2(-12, -2), 3.2, PI * 0.5, PI * 1.5, 8), ViewColors.h("#3a3f4b"), 1.8, true)
	ci.draw_polyline(ViewUtil.arc_pts(Vector2(12, -2), 3.2, -PI * 0.5, PI * 0.5, 8), ViewColors.h("#3a3f4b"), 1.8, true)
	ViewUtil.ellipse_fs(ci, Vector2(0, -6), 10.5, 3.5, ViewColors.h("#f2b949"), edge, 1.6)
	var bob: float = sin(t * 4.5 + sp) * 1.1
	ViewUtil.ellipse_fs(ci, Vector2(-2, -7.2 + bob), 5.2, 3.6, ViewColors.h("#a86438"), ViewColors.h("#4a2810"), 1.1, -0.1)
	ci.draw_circle(Vector2(4.5, -6.5 - bob * 0.6), 2.8, ViewColors.h("#fff5df"))
	ArtKit.reset(ci)


func sample_state() -> Variant:
	return {"x": 0.0, "y": -11.0, "steam_phase": 0.0}

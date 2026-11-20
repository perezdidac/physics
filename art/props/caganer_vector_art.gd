## The caganer figurine, drawn in code (fallback of the CaganerArt sprite).
class_name CaganerVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var cg: Variant = state
	var t: float = ctx.t
	var bob: float = sin(t * 3.5 + ViewUtil.gf(cg, "bob_phase")) * 1.5
	ArtKit.place(ci, ViewUtil.pos(cg) + Vector2(0, bob))
	ViewUtil.radial(ci, Vector2(0, -4), 2.0, 20.0, [[0.0, Color(1.0, 0.8784, 0.4, 0.72)], [1.0, Color(1.0, 0.7647, 0.1961, 0.0)]], 1.0, "cag_glow")
	ViewUtil.ellipse_fs(ci, Vector2(-6, 5), 3.8, 2.2, ViewColors.h("#6e421c"), ViewColors.h("#ffd966"), 0.9)
	ViewUtil.fill_ellipse(ci, Vector2(-1, 3), 5.5, 3.8, ViewColors.h("#1d2028"))
	ci.draw_rect(Rect2(-4.5, -1, 8, 2.5), ViewColors.h("#d93226"))
	var edge := ViewColors.h("#241a14")
	ViewUtil.round_rect_fs(ci, Rect2(-4.5, -7, 8.5, 6.5), 2.5, ViewColors.h("#f7f3e8"), edge, 1.2)
	ViewUtil.circle_fs(ci, Vector2(0.5, -10.5), 4.2, ViewColors.h("#f2c199"), edge, 1.2)
	ci.draw_rect(Rect2(-3.5, -14, 8, 2), ViewColors.h("#181a20"))
	ArtKit.poly(ci, PackedVector2Array([Vector2(-3.5, -14), Vector2(1, -20), Vector2(6.5, -16), Vector2(4.5, -14)]), ViewColors.h("#e02f24"), edge, 1.2)
	ArtKit.reset(ci)


func sample_state() -> Variant:
	return {"x": 0.0, "y": -7.0, "bob_phase": 0.0}

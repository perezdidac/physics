## A silk nest hanging from its thread, with a glow and two wriggling larvae.
class_name SilkNestVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var nest: Variant = state
	var t: float = ctx.t
	var p: Vector2 = ViewUtil.pos(nest)
	ci.draw_line(Vector2(ViewUtil.gf(nest, "anchor_x"), ViewUtil.gf(nest, "anchor_y")), p, Color(0.9608, 0.9412, 0.902, 0.78), 1.8, true)
	var sway: float = ViewUtil.gf(nest, "sway_phase")
	var pulse: float = 1.0 + sin(t * 5.0 + sway) * 0.05
	ArtKit.place(ci, p, 0.0, Vector2(pulse, pulse))
	var r: float = ViewUtil.gf(nest, "r", 13.0)
	ViewUtil.radial(ci, Vector2.ZERO, 2.0, r * 1.6, [[0.0, Color(1.0, 0.9216, 0.6863, 0.65)], [1.0, Color(1.0, 0.9216, 0.6863, 0.0)]], 1.0, "nest_glow")
	ViewUtil.ellipse_fs(ci, Vector2.ZERO, r * 1.1, r * 0.85, ViewColors.h("#f5f0e6"), ViewColors.h("#d4a153"), 1.6)
	for w in [-1, 1]:
		var wx: float = float(w) * 3.5 + sin(t * 7.0 + float(w) + sway) * 2.2
		var wy: float = float(w) * 1.8 + cos(t * 6.0 + float(w)) * 1.5
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(wx - 3.5, wy), Vector2(wx, wy - 2.5), Vector2(wx + 3.5, wy + 0.5), 6), Color(0.2549, 0.2039, 0.1647, 0.42), 2.1, true)
	var web := Color(0.7059, 0.6471, 0.5686, 0.55)
	ci.draw_line(Vector2(-8, -4), Vector2(9, 3), web, 1.0, true)
	ci.draw_line(Vector2(-7, 4), Vector2(8, -4), web, 1.0, true)
	ArtKit.reset(ci)


func sample_state() -> Variant:
	return {"x": 0.0, "y": -20.0, "anchor_x": 0.0, "anchor_y": -50.0, "r": 13.0, "sway_phase": 0.0}

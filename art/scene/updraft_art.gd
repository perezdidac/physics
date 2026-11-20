## A rising column of warm air with drifting streaks.
class_name UpdraftArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var u: Variant = state
	var t: float = ctx.t
	var ux: float = ViewUtil.gf(u, "x")
	var uy: float = ViewUtil.gf(u, "y")
	var uw: float = ViewUtil.gf(u, "w", 42.0)
	var uh: float = ViewUtil.gf(u, "h", 230.0)
	var x0: float = ux - uw * 0.7
	var x1: float = ux + uw * 0.7
	var c0 := Color(0.9647, 0.8118, 0.4667, 0.22)
	var c1 := Color(0.7059, 0.9216, 1.0, 0.12)
	var c2 := Color(0.7059, 0.9216, 1.0, 0.0)
	ViewUtil.vgrad_rect(ci, x0, x1, uy - uh, uy, [[0.0, c2], [0.4, c1], [1.0, c0]])
	for s in range(-1, 2):
		var flow: float = fmod(t * 95.0 + float(s + 1) * 65.0, uh)
		var sx: float = ux + float(s) * 11.0 + sin(t * 5.0 + float(s)) * 4.0
		var sy: float = uy - flow
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(sx, sy), Vector2(sx + 4.0, sy - 14.0), Vector2(sx - 2.0, sy - 28.0), 6), Color(1.0, 0.9216, 0.6863, 0.36), 1.4, true)


func sample_state() -> Variant:
	return {"x": 0.0, "y": 0.0, "w": 42.0, "h": 120.0}

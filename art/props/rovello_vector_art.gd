## The rovelló mushroom (a healing pickup) with its warm glow.
class_name RovelloVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, _ctx: ArtContext) -> void:
	var rv: Variant = state
	var r: float = ViewUtil.gf(rv, "r", 18.0)
	var sq: float = ViewUtil.gf(rv, "squash", 1.0)
	ArtKit.place(ci, ViewUtil.pos(rv), 0.0, Vector2(2.0 - sq, sq))
	ViewUtil.radial(ci, Vector2(0, -10), 2.0, r * 1.5, [[0.0, Color(1.0, 0.647, 0.2941, 0.38)], [1.0, Color(1.0, 0.549, 0.1765, 0.0)]], 1.0, "rov_glow")
	var edge := ViewColors.h("#5c3118")
	ViewUtil.round_rect_fs(ci, Rect2(-5.5, -13, 11, 15), 3.0, ViewColors.h("#f2d8bd"), edge, 1.5)
	var cap := PackedVector2Array()
	cap.append_array(ViewUtil.bezier_pts(Vector2(-r, -11), Vector2(-r * 0.85, -23), Vector2(-4, -18), Vector2(0, -16), 10))
	cap.append_array(ViewUtil.bezier_pts(Vector2(0, -16), Vector2(4, -18), Vector2(r * 0.85, -23), Vector2(r, -11), 10))
	cap.append_array(ViewUtil.quad_pts(Vector2(r, -11), Vector2(0, -7), Vector2(-r, -11), 10))
	# cap gradient: 3 horizontal bands approximating the vertical linear gradient
	var cols := PackedColorArray()
	for p in cap:
		var tt: float = clampf((p.y + 22.0) / 13.0, 0.0, 1.0)
		cols.append(ViewColors.h("#ff8833").lerp(ViewColors.h("#d9531e"), clampf(tt / 0.6, 0.0, 1.0)).lerp(ViewColors.h("#8c2d10"), clampf((tt - 0.6) / 0.4, 0.0, 1.0)))
	ci.draw_polygon(cap, cols)
	var cl: PackedVector2Array = cap.duplicate()
	cl.append(cap[0])
	ci.draw_polyline(cl, edge, 1.5, true)
	ci.draw_arc(Vector2(0, -13), r * 0.58, PI * 1.1, PI * 1.9, 10, Color(1.0, 0.8431, 0.6471, 0.55), 1.1, true)
	ci.draw_circle(Vector2(-r * 0.45, -14), 1.8, ViewColors.h("#4e8c45"))
	ci.draw_circle(Vector2(r * 0.38, -13), 1.5, ViewColors.h("#4e8c45"))
	ArtKit.reset(ci)


func sample_state() -> Variant:
	return {"x": 0.0, "y": 0.0, "r": 18.0, "squash": 1.0}

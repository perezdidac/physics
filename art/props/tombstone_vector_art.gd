## A fallen fighter's tombstone with the team cap.
class_name TombstoneVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, _ctx: ArtContext) -> void:
	var tb: Variant = state
	ArtKit.place(ci, ViewUtil.pos(tb))
	var body := PackedVector2Array([Vector2(-9, 10), Vector2(-9, -4)])
	body.append_array(ViewUtil.arc_pts(Vector2(0, -4), 9.0, PI, TAU, 12))
	body.append(Vector2(9, 10))
	var cols := PackedColorArray()
	for p in body:
		var tt: float = clampf(((p.x + 9.0) * 0.5 + (p.y + 13.0) * 0.5) / 23.0, 0.0, 1.0)
		cols.append(ViewColors.h("#888590").lerp(ViewColors.h("#6c6a72"), clampf(tt / 0.5, 0.0, 1.0)).lerp(ViewColors.h("#49474f"), clampf((tt - 0.5) / 0.5, 0.0, 1.0)))
	ci.draw_polygon(body, cols)
	var bl: PackedVector2Array = body.duplicate()
	bl.append(body[0])
	ci.draw_polyline(bl, ViewColors.h("#222026"), 1.8, true)
	ViewUtil.fill_poly(ci, ViewUtil.arc_pts(Vector2(-6, 9.5), 2.4, PI, TAU, 6), ViewColors.h("#4e7c3e"))
	ViewUtil.fill_poly(ci, ViewUtil.arc_pts(Vector2(5, 9.5), 2.8, PI, TAU, 6), ViewColors.h("#4e7c3e"))
	var cross := ViewColors.h("#3b3940")
	ci.draw_line(Vector2(0, -9), Vector2(0, 1), cross, 1.5, true)
	ci.draw_line(Vector2(-3.5, -5.5), Vector2(3.5, -5.5), cross, 1.5, true)
	var nm: String = ViewUtil.gs(tb, "name")
	if nm != "":
		ViewUtil.text(ci, nm.substr(0, 7).to_upper(), Vector2(0, 6.8), 6, ViewColors.h("#e2dfd7"))
	var hat: Color = ViewColors.h("#d93228") if ViewUtil.gi(tb, "team") != 1 else ViewColors.h("#3b82f6")
	var cap := PackedVector2Array()
	cap.append_array(ViewUtil.quad_pts(Vector2(-5, -11.5), Vector2(0, -18), Vector2(7, -14), 6))
	cap.append_array(ViewUtil.quad_pts(Vector2(7, -14), Vector2(3, -11), Vector2(4, -11.5), 4))
	ArtKit.poly(ci, cap, hat, ViewColors.h("#18161b"), 1.0)
	ArtKit.reset(ci)


func sample_state() -> Variant:
	return {"x": 0.0, "y": -10.0, "team": 0, "name": "PERLETA"}

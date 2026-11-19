## The rope and hook of a fighter that is grappling.
class_name GrappleArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, _ctx: ArtContext) -> void:
	var f: Variant = state
	var g: Variant = ViewUtil.g(f, "grapple")
	if not (g is Dictionary) or (g as Dictionary).is_empty() or not ViewUtil.gb(f, "alive"):
		return
	var hook := Vector2(ViewUtil.gf(g, "hook_x"), ViewUtil.gf(g, "hook_y"))
	ci.draw_line(Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") - 4.0), hook, ViewColors.h("#d9b372"), 2.6, true)
	ci.draw_polyline(ViewUtil.arc_pts(hook, 6.0, 0.0, PI * 1.35, 12), ViewColors.h("#e2e8f0"), 3.0, true)


func sample_state() -> Variant:
	return {"x": 0.0, "y": 0.0, "alive": true, "grapple": {"hook_x": 30.0, "hook_y": -40.0}}

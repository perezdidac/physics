## Dashed silk tethers between linked allies. State: the Array of fighters.
class_name TethersArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, _ctx: ArtContext) -> void:
	var fighters: Array = state
	for f in fighters:
		if not ViewUtil.gb(f, "alive") or ViewUtil.gb(f, "drowning"):
			continue
		for ally in ViewUtil.g(f, "linked_allies", []):
			if ViewUtil.gi(f, "member_idx") < ViewUtil.gi(ally, "member_idx"):
				var col: Color = Color(0.9608, 0.7255, 0.2706, 0.78) if ViewUtil.gi(f, "team") == 0 else Color(0.9176, 0.3373, 0.2824, 0.78)
				var a := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + 2.0)
				var b := Vector2(ViewUtil.gf(ally, "x"), ViewUtil.gf(ally, "y") + 2.0)
				var ctrl := Vector2((a.x + b.x) * 0.5, minf(ViewUtil.gf(f, "y"), ViewUtil.gf(ally, "y")) - 6.0)
				ViewUtil.dashed(ci, ViewUtil.quad_pts(a, ctrl, b, 14), 5.0, 3.0, col, 2.4)


func sample_state() -> Variant:
	var a: Dictionary = {"x": -30.0, "y": -10.0, "alive": true, "team": 0, "member_idx": 0}
	var b: Dictionary = {"x": 30.0, "y": -10.0, "alive": true, "team": 0, "member_idx": 1}
	a["linked_allies"] = [b]
	return [a, b]

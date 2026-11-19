## (Vector fallback of the sprite art.) A row of pine-needle tufts (hiding spots of the platformer). While `left` > 0 the tufts are trampled: yellowed needles lying
## sideways that stand up again, plus a pulsing red cross. State: {rect: Rect2 of the row (ground at rect.end.y), left: seconds of
## flattening left, time: total flattening time}.
class_name PlatformTuftVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var r: Rect2 = state["rect"]
	var left: float = ViewUtil.gf(state, "left")
	var total: float = maxf(0.001, ViewUtil.gf(state, "time", 1.0))
	var t: float = ctx.t
	var n: int = maxi(1, roundi(r.size.x / 40.0))
	var ground_y: float = r.end.y
	for k in n:
		var x: float = r.position.x + r.size.x * (float(k) + 0.5) / float(n)
		if left > 0.0:
			_draw_flat_tuft(ci, Vector2(x, ground_y), left / total, k, ctx)
		else:
			TuftArt.draw(ci, Vector2(x, ground_y), t)
	if left > 0.0:
		# a pulsing red cross: nobody can hide here until the needles stand up again
		var c := Vector2(r.get_center().x, r.position.y - 4.0 + sin(t * 5.0) * 2.0)
		var a: float = clampf(left, 0.0, 1.0) * (0.6 + 0.3 * sin(t * 8.0))
		ci.draw_line(c + Vector2(-7, -7), c + Vector2(7, 7), Color(1.0, 0.3, 0.25, a), 3.0, true)
		ci.draw_line(c + Vector2(-7, 7), c + Vector2(7, -7), Color(1.0, 0.3, 0.25, a), 3.0, true)


## A trampled tuft: needles lying sideways and yellowed, slowly standing up again as `left` (1 -> 0) runs out.
func _draw_flat_tuft(ci: CanvasItem, ground: Vector2, left: float, seed_id: int, ctx: ArtContext) -> void:
	var up: float = pow(1.0 - left, 2.0)
	var wilt: Color = ViewColors.h("#a0924a").lerp(ArtKit.night_tint("#5f9236", ctx.night), up)
	for i in 14:
		var u: float = float(i) / 13.0 - 0.5
		var side: float = -1.0 if (i + seed_id) % 2 == 0 else 1.0
		var ang: float = lerpf(side * (PI * 0.5 - 0.18), u * 1.6, up)
		var ln: float = 20.0 - absf(u) * 8.0 + float((i * 7 + seed_id) % 5)
		var base := Vector2(u * 14.0, 0.0) + ground
		var dir := Vector2(sin(ang), -cos(ang))
		var mid: Vector2 = base + dir * ln * 0.5 + Vector2(0.0, 2.0 * (1.0 - up))
		ci.draw_polyline(PackedVector2Array([base, mid, base + dir * ln + Vector2(0.0, 3.0 * (1.0 - up))]), wilt, 1.4, true)


func sample_state() -> Variant:
	return {"rect": Rect2(-40.0, -20.0, 80.0, 20.0), "left": 0.0, "time": 8.0}

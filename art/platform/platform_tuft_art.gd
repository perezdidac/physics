## A row of pine-needle tufts (hiding spots of the platformer): each standing tuft is assets/sprites/platform_props/tuft.svg with a
## slight code sway. While `left` > 0 the tufts are trampled: yellowed needles lying sideways (code) that stand up again, plus a pulsing
## red cross. State: {rect: Rect2 of the row (ground at rect.end.y), left: seconds of flattening left, time: total flattening time}.
class_name PlatformTuftArt
extends SpriteArt

## Anchor of the tuft base inside the viewBox; 0.5 world px per unit: a tuft is ~ 38 px wide, ~ 27 px tall.
const BOX: float = 64.0
const FOOT_Y: float = 112.0


func _init() -> void:
	super("platform_props", "tuft", BOX, PlatformTuftVectorArt.new())
	anchor = Vector2(64.0, FOOT_Y)


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	if not has_sprite():
		fallback.draw(ci, state, ctx)
		return
	var r: Rect2 = state["rect"]
	var left: float = ViewUtil.gf(state, "left")
	var total: float = maxf(0.001, ViewUtil.gf(state, "time", 1.0))
	var n: int = maxi(1, roundi(r.size.x / 40.0))
	var ground_y: float = r.end.y
	for k in n:
		var x: float = r.position.x + r.size.x * (float(k) + 0.5) / float(n)
		if left > 0.0:
			_draw_flat_tuft(ci, Vector2(x, ground_y), left / total, k, ctx)
		else:
			_draw_standing(ci, Vector2(x, ground_y), ctx)
	if left > 0.0:
		var c := Vector2(r.get_center().x, r.position.y - 4.0 + sin(ctx.t * 5.0) * 2.0)
		var a: float = clampf(left, 0.0, 1.0) * (0.6 + 0.3 * sin(ctx.t * 8.0))
		ci.draw_line(c + Vector2(-7, -7), c + Vector2(7, 7), Color(1.0, 0.3, 0.25, a), 3.0, true)
		ci.draw_line(c + Vector2(-7, 7), c + Vector2(7, -7), Color(1.0, 0.3, 0.25, a), 3.0, true)


func _draw_standing(ci: CanvasItem, ground: Vector2, ctx: ArtContext) -> void:
	var sway: float = sin(ctx.t * 1.3 + ground.x) * 0.025
	var k: float = BOX / VIEWBOX
	ci.draw_set_transform_matrix(Transform2D(sway, Vector2.ONE, 0.0, ground))
	ci.draw_texture_rect(texture(), Rect2(-anchor * k, Vector2(VIEWBOX, VIEWBOX) * k), false, ArtKit.night_tint("#ffffff", ctx.night * 0.5))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## A trampled tuft: needles lying sideways and yellowed, slowly standing up again as `left` (1 -> 0) runs out.
func _draw_flat_tuft(ci: CanvasItem, ground: Vector2, left: float, seed_id: int, ctx: ArtContext) -> void:
	var up: float = pow(1.0 - left, 2.0)
	var wilt: Color = ViewColors.h("#a0924a").lerp(ArtKit.night_tint("#5f9236", ctx.night), up)
	var dark := Color(0.15, 0.12, 0.05, 0.55)
	for i in 14:
		var u: float = float(i) / 13.0 - 0.5
		var side: float = -1.0 if (i + seed_id) % 2 == 0 else 1.0
		var ang: float = lerpf(side * (PI * 0.5 - 0.18), u * 1.6, up)
		var ln: float = 20.0 - absf(u) * 8.0 + float((i * 7 + seed_id) % 5)
		var base := Vector2(u * 14.0, 0.0) + ground
		var dir := Vector2(sin(ang), -cos(ang))
		var mid: Vector2 = base + dir * ln * 0.5 + Vector2(0.0, 2.0 * (1.0 - up))
		var pl := PackedVector2Array([base, mid, base + dir * ln + Vector2(0.0, 3.0 * (1.0 - up))])
		ci.draw_polyline(pl, dark, 2.6, true)
		ci.draw_polyline(pl, wilt, 1.6, true)
	# the sheath that still stands
	var sheath := Rect2(ground + Vector2(-4.0, -5.0), Vector2(8.0, 6.0))
	ci.draw_rect(sheath, Color(0.45, 0.33, 0.18, 1.0))
	ci.draw_rect(sheath, Color(0.18, 0.12, 0.06, 1.0), false, 1.2)


func sample_state() -> Variant:
	return {"rect": Rect2(-40.0, -20.0, 80.0, 20.0), "left": 0.0, "time": 8.0}

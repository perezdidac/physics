## (Vector fallback of the sprite art.) A giant pine needle (a one-way platform), darkened by the night amount. State: its Rect2.
class_name NeedleVectorArt
extends ThingArt


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var r: Rect2 = state
	var x0: float = r.position.x
	var x1: float = r.end.x
	var th: float = clampf(r.size.y * 0.6, 6.0, 10.0)
	var y: float = r.position.y
	var steps: int = 14
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for k in steps + 1:
		var u: float = float(k) / float(steps)
		var taper: float = pow(sin(clampf(u, 0.0, 1.0) * PI), 0.8) if u > 0.04 else 0.0
		top.append(Vector2(lerpf(x0, x1, u), y + (1.0 - taper) * th * 0.5))
		bot.append(Vector2(lerpf(x0, x1, u), y + th * 0.5 + taper * th * 0.5))
	var poly := PackedVector2Array(top)
	for k in range(steps, -1, -1):
		poly.append(bot[k])
	ci.draw_colored_polygon(poly, ArtKit.night_tint("#5f9236", ctx.night))
	# second needle of the pair, a bit lower and darker
	var shade := PackedVector2Array()
	for k in steps + 1:
		shade.append(bot[k] + Vector2(0.0, 1.0))
	ci.draw_polyline(shade, ArtKit.night_tint("#3b6626", ctx.night), 2.0, true)
	ci.draw_polyline(top, ArtKit.night_tint("#a9d062", ctx.night), 2.0, true)
	var mid := PackedVector2Array()
	for k in steps + 1:
		mid.append(top[k].lerp(bot[k], 0.5))
	ci.draw_polyline(mid, Color(ArtKit.night_tint("#2f5420", ctx.night), 0.7), 1.0, true)
	# brown sheath where the pair joins the twig
	ci.draw_rect(Rect2(x0 - 3.0, y - 1.0, 12.0, th + 2.0), ArtKit.night_tint("#6f5230", ctx.night))
	ci.draw_line(Vector2(x0 + 2.0, y - 1.0), Vector2(x0 + 2.0, y + th + 1.0), ArtKit.night_tint("#3d2c18", ctx.night), 1.2)
	ci.draw_line(Vector2(x0 + 6.0, y - 1.0), Vector2(x0 + 6.0, y + th + 1.0), ArtKit.night_tint("#3d2c18", ctx.night), 1.2)


func sample_state() -> Variant:
	return Rect2(-60.0, -6.0, 120.0, 10.0)

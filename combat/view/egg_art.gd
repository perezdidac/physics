## Procedural art of the egg fighter of the story mode: a pale cream oval wearing the mother's scales, two small eyes,
## a wobble while it crawls and a red flash when hurt. Drawn in `ci` world space around the fighter centre.
class_name EggArt
extends RefCounted

const RX: float = 8.6
const RY: float = 11.0


## Draws the egg of fighter `f`. `alpha` < 1 fades it (hidden in a needle tuft).
static func draw(ci: CanvasItem, f: Variant, ctx: ViewCtx, alpha: float) -> void:
	var t: float = ctx.t_now
	var walk: float = ViewUtil.gf(f, "walk_cycle")
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 10.0)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var moving: float = clampf(absf(ViewUtil.gf(f, "vx")) * 0.04, 0.0, 1.0) if not ViewUtil.gb(f, "grounded", true) else 1.0
	# Wobble: rocks around the contact point and squashes in time with the crawl.
	var rock: float = sin(walk * 0.9) * 0.13 * moving
	var squash: float = sin(walk * 1.8) * 0.05 * moving
	var breathe: float = sin(t * 2.2 + ViewUtil.gf(f, "x") * 0.1) * 0.012
	var sx: float = ViewUtil.gf(f, "squash_x", 1.0) * (1.0 - squash + breathe)
	var sy: float = ViewUtil.gf(f, "squash_y", 1.0) * (1.0 + squash - breathe)
	var feet := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + r - 0.5)
	if drowning:
		feet.y -= 4.0
	ci.draw_set_transform_matrix(Transform2D(rock, Vector2(sx, sy), 0.0, feet))
	var c := Vector2(0.0, -RY + 0.5)
	var body: Color = ViewColors.h("#f3e5c1")
	var shade: Color = ViewColors.h("#cdb585")
	var line: Color = ViewColors.h("#7d6740")
	if drowning:
		body = body.lerp(ViewColors.h("#7ab4d6"), 0.55)
		shade = shade.lerp(ViewColors.h("#3d6987"), 0.55)
	ViewUtil.ellipse_fs(ci, c, RX, RY, _a(body, alpha), _a(line, alpha), 1.5)
	# Shading on the lower right and a soft highlight on the upper left.
	ViewUtil.fill_ellipse(ci, c + Vector2(2.6, 3.0), RX * 0.78, RY * 0.78, _a(shade, 0.42 * alpha))
	ViewUtil.fill_ellipse(ci, c + Vector2(-0.5, 0.0), RX * 0.8, RY * 0.8, _a(body, 0.85 * alpha))
	ViewUtil.fill_ellipse(ci, c + Vector2(-3.2, -4.8), 2.6, 4.0, Color(1, 1, 1, 0.55 * alpha), -0.5)
	_draw_scales(ci, c, alpha)
	ci.draw_arc(c, RX, 0.0, TAU, 28, _a(line, alpha), 1.5, true)
	_draw_face(ci, f, c, facing, t, hurt, alpha)
	if hurt > 0.0:
		ViewUtil.fill_ellipse(ci, c, RX, RY, Color(1.0, 0.25, 0.2, clampf(hurt, 0.0, 1.0) * 0.45 * alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Overlapping scale arcs (the mother's body scales), kept inside the oval.
static func _draw_scales(ci: CanvasItem, c: Vector2, alpha: float) -> void:
	var col: Color = _a(ViewColors.h("#9c8456"), 0.42 * alpha)
	var row: int = 0
	var y: float = -RY * 0.62
	while y <= RY * 0.82:
		var off: float = 2.3 if row % 2 == 1 else 0.0
		var x: float = -RX * 0.72 + off
		while x <= RX * 0.72:
			var p := Vector2(x, y)
			if (p.x * p.x) / (RX * RX * 0.62) + (p.y * p.y) / (RY * RY * 0.7) <= 1.0:
				ci.draw_arc(c + p, 2.3, PI * 0.12, PI * 0.88, 5, col, 0.9, true)
			x += 4.6
		y += 3.4
		row += 1


static func _draw_face(ci: CanvasItem, f: Variant, c: Vector2, facing: float, t: float, hurt: float, alpha: float) -> void:
	var blink: bool = fmod(t * 0.8 + float(ViewUtil.gi(f, "id")) * 1.37, 4.0) > 3.86
	var ink: Color = _a(ViewColors.h("#2a1f14"), alpha)
	var ex: Array[float] = [1.2 * facing, 5.4 * facing]
	var ey: float = c.y - 1.6
	if hurt > 0.2:
		for x in ex:
			ci.draw_line(Vector2(x - 1.5, ey - 1.5), Vector2(x + 1.5, ey + 1.5), ink, 1.3, true)
			ci.draw_line(Vector2(x + 1.5, ey - 1.5), Vector2(x - 1.5, ey + 1.5), ink, 1.3, true)
	elif blink:
		for x in ex:
			ci.draw_line(Vector2(x - 1.6, ey), Vector2(x + 1.6, ey), ink, 1.2, true)
	else:
		for i in 2:
			var rr: float = 2.0 if i == 0 else 1.7
			ViewUtil.fill_ellipse(ci, Vector2(ex[i], ey), rr, rr * 1.2, ink)
			ci.draw_circle(Vector2(ex[i] - 0.6, ey - 0.8), 0.7, _a(Color.WHITE, alpha))
		# tiny cheek and smile
		ci.draw_circle(Vector2(ex[0] - 2.4 * facing, ey + 3.2), 1.5, Color(1.0, 0.55, 0.5, 0.35 * alpha))
		ci.draw_arc(Vector2(3.3 * facing, ey + 2.4), 1.8, PI * 0.2, PI * 0.8, 6, _a(ViewColors.h("#6b4a30"), alpha), 0.9, true)


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)

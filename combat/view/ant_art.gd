## Procedural art of the ant enemy of the story mode: dark red-brown head, thorax and abdomen, six legs that follow the walk cycle,
## wiggling antennae and mandibles that snap shut on a bite. Drawn in `ci` world space around the fighter centre.
class_name AntArt
extends RefCounted


static func draw(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	var walk: float = ViewUtil.gf(f, "walk_cycle")
	var facing: float = ViewUtil.gf(f, "facing", -1.0)
	var r: float = ViewUtil.gf(f, "r", 9.0)
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var bite: float = clampf(ViewUtil.gf(f, "bat_swing_timer") / 0.48, 0.0, 1.0)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var grounded: bool = ViewUtil.gb(f, "grounded", true)
	var bob: float = absf(sin(walk * 0.5)) * 0.9 if grounded else 0.0
	var origin := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + (r - 4.0 if drowning else 0.0))
	# the critter AI tilts the ant nose-up along the slope or wall; facing left mirrors the angle
	var rot: float = ViewUtil.gf(f, "flip_angle") - facing * ViewUtil.gf(f, "climb")
	ci.draw_set_transform_matrix(Transform2D(rot, Vector2(facing * ViewUtil.gf(f, "squash_x", 1.0), ViewUtil.gf(f, "squash_y", 1.0)), 0.0, origin))
	var body: Color = ViewColors.h("#7a3322")
	var light: Color = ViewColors.h("#a34a30")
	var line: Color = ViewColors.h("#2b100a")
	var leg: Color = ViewColors.h("#5a2616")
	if drowning:
		body = body.lerp(ViewColors.h("#3d6987"), 0.5)
		light = light.lerp(ViewColors.h("#7ab4d6"), 0.5)
	var ground: float = r - 0.3
	_draw_legs(ci, walk, ground, bob, grounded, leg)
	# abdomen (gaster), thorax, waist and head
	var by: float = -1.0 - bob
	ViewUtil.ellipse_fs(ci, Vector2(-8.6, by + 0.6), 6.4, 5.2, body, line, 1.4, -0.08)
	ViewUtil.fill_ellipse(ci, Vector2(-9.6, by - 1.4), 3.6, 1.8, Color(light, 0.75), -0.12)
	ViewUtil.fill_ellipse(ci, Vector2(-8.6, by + 2.6), 4.4, 1.3, Color(line, 0.28))
	ViewUtil.ellipse_fs(ci, Vector2(-1.2, by - 0.4), 3.6, 3.1, body, line, 1.3, 0.1)
	ViewUtil.fill_ellipse(ci, Vector2(-1.8, by - 1.5), 2.0, 1.0, Color(light, 0.7))
	ViewUtil.ellipse_fs(ci, Vector2(5.2, by - 0.6), 4.4, 3.7, body, line, 1.4, 0.0)
	ViewUtil.fill_ellipse(ci, Vector2(4.4, by - 2.0), 2.4, 1.1, Color(light, 0.7))
	# eye
	var blink: bool = fmod(t * 0.7 + float(ViewUtil.gi(f, "id")) * 2.1, 5.0) > 4.88
	if hurt > 0.2:
		ci.draw_line(Vector2(5.0, by - 2.6), Vector2(7.2, by - 0.6), line, 1.2, true)
		ci.draw_line(Vector2(7.2, by - 2.6), Vector2(5.0, by - 0.6), line, 1.2, true)
	elif not blink:
		ci.draw_circle(Vector2(6.3, by - 1.6), 1.45, ViewColors.h("#0b0605"))
		ci.draw_circle(Vector2(5.9, by - 2.0), 0.5, Color.WHITE)
	_draw_antennae(ci, t, Vector2(8.2, by - 2.6), ViewUtil.gf(f, "x"), line)
	_draw_mandibles(ci, Vector2(8.9, by + 0.6), bite, t, line)
	if hurt > 0.0:
		ViewUtil.fill_ellipse(ci, Vector2(-1.5, by), 12.0, 5.5, Color(1.0, 0.25, 0.2, clampf(hurt, 0.0, 1.0) * 0.4))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Three pairs of two-segment legs on the thorax; the two sets of three step in antiphase (tripod gait).
static func _draw_legs(ci: CanvasItem, walk: float, ground: float, bob: float, grounded: bool, col: Color) -> void:
	var hip_y: float = -0.4 - bob
	for i in 3:
		var hip := Vector2(-3.0 + float(i) * 2.9, hip_y)
		for side in 2:
			var ph: float = walk + (PI if (i + side) % 2 == 0 else 0.0)
			var stride: float = sin(ph) * 3.4
			var lift: float = maxf(0.0, cos(ph)) * 2.4
			var spread: float = (float(i) - 1.0) * 3.4
			var foot := Vector2(hip.x + spread + stride, ground - lift - (0.0 if grounded else 3.0))
			var knee := Vector2(hip.x + spread * 0.9 + stride * 0.4 + (1.0 if side == 0 else -1.0) * 1.2, hip.y - 3.2 - float(side) * 0.8)
			var shade: Color = col if side == 0 else Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, 0.8)
			ci.draw_polyline(PackedVector2Array([hip, knee, foot]), shade, 1.5, true)


static func _draw_antennae(ci: CanvasItem, t: float, base: Vector2, seed_x: float, col: Color) -> void:
	for i in 2:
		var wig: float = sin(t * 5.0 + seed_x * 0.05 + float(i) * 1.7) * 1.2
		var mid := base + Vector2(3.4 + float(i) * 0.6, -3.6 + wig * 0.4)
		var tip := mid + Vector2(2.8, -1.0 + wig)
		ci.draw_polyline(PackedVector2Array([base, mid, tip]), col, 1.1, true)
		ci.draw_circle(tip, 0.7, col)


## Mandibles: slightly open, chewing a little; they slam shut at the start of a bite.
static func _draw_mandibles(ci: CanvasItem, base: Vector2, bite: float, t: float, col: Color) -> void:
	var open: float = 0.55 + sin(t * 4.0) * 0.08
	if bite > 0.0:
		open = 1.1 if bite > 0.7 else 0.0
	for s in [-1.0, 1.0]:
		var a: float = float(s) * open * 0.5
		var tip := base + Vector2(cos(a) * 3.6, sin(a) * 3.6 + float(s) * 0.4)
		var mid := base + Vector2(cos(a * 0.4) * 2.0, sin(a * 0.4) * 2.0 + float(s) * 1.4)
		ci.draw_polyline(ViewUtil.quad_pts(base, mid, tip, 5), col, 1.5, true)

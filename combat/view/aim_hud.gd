## Aiming overlay of the active human fighter: trajectory preview, power ring, elevation badge, airstrike reticle, spotlight ring
## (port of drawAimingHUD, renderer.js:2176-2407). World space.
class_name AimHud
extends RefCounted

const GRAVITY: float = 440.0
## Length (world px) of the dashed aim direction line.
const DIRECTION_LEN: float = 120.0


## Draws the HUD for fighter `f`. Texts go through tr() keys.
static func draw(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	var mw: Vector2 = ctx.mouse_world
	if ctx.weapon_id == "AIRSTRIKE":
		if not ctx.aim_shown:
			return
		var rr: float = 16.0 + sin(t * 8.0) * 3.0
		ci.draw_arc(mw, rr, 0.0, TAU, 28, ViewColors.AIM_CROSS, 2.2, true)
		ci.draw_line(mw + Vector2(-24, 0), mw + Vector2(24, 0), ViewColors.AIM_CROSS, 2.2, true)
		ci.draw_line(mw + Vector2(0, -24), mw + Vector2(0, 24), ViewColors.AIM_CROSS, 2.2, true)
		ViewUtil.text(ci, ViewUtil.tr_text("AIM_AIRSTRIKE_TARGET"), mw + Vector2(0, -34), 11, ViewColors.AIM_LABEL)
		ViewUtil.text(ci, ViewUtil.tr_text("AIM_AIRSTRIKE_HINT"), mw + Vector2(0, -22), 9, Color(1.0, 0.9608, 0.8627, 0.88))
		return
	if ctx.weapon_id == "DYNAMITE" or ctx.weapon_id == "JETPACK":
		return
	var dir := Vector2(cos(ctx.aim_angle), sin(ctx.aim_angle))
	var origin := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") - 4.0)
	var team: int = ViewUtil.gi(f, "team")

	if ctx.spotlight_timer > 0.0:
		var sa: float = clampf(ctx.spotlight_timer / 1.9, 0.0, 1.0)
		var sc: Color = Color(ViewColors.team(team), sa * 0.65)
		ViewUtil.dashed_circle(ci, origin, 31.0 + (1.0 - sa) * 18.0, 6.0, 4.0, sc, 2.4)
		if not ctx.has_acted and sa > 0.25:
			ViewUtil.text(ci, ViewUtil.tr_text("AIM_SWITCH_HINT"), origin + Vector2(0, 34), 9, Color(1.0, 0.9608, 0.8627, sa * 0.85))
	if not ctx.aim_shown:
		return # touch MOVE phase: no aiming guides at all

	var elev: int = int(floor(-ctx.aim_pitch * 180.0 / PI + 0.5))
	var deg_text: String = "%s%d°" % ["+" if elev >= 0 else "", elev]
	var bpos: Vector2 = origin + dir * 34.0 + Vector2(0, -11)
	ViewUtil.fill_round_rect(ci, Rect2(bpos.x - 16.0, bpos.y - 8.0, 32.0, 13.0), 5.0, Color(0.0431, 0.0549, 0.0863, 0.78))
	ViewUtil.text(ci, deg_text, Vector2(bpos.x, bpos.y + 1.5), 9, ViewColors.WARM_YELLOW if ctx.is_charging else Color(1.0, 0.9569, 0.8392, 0.92))

	if ctx.weapon_type == "CHARGE":
		if ctx.is_charging:
			_draw_charge(ci, f, ctx, origin, dir)
		else:
			_draw_direction(ci, origin, dir)
	elif ctx.weapon_id == "PONT_PEDRA":
		var g: Vector2 = origin + dir * 52.0
		ci.draw_set_transform_matrix(Transform2D(ctx.aim_angle, Vector2.ONE, 0.0, g))
		var rect_pts: PackedVector2Array = ViewUtil.round_rect_pts(Rect2(-41, -8, 82, 16), 5.0)
		ci.draw_colored_polygon(rect_pts, Color(0.8235, 0.7843, 0.7137, 0.36))
		var closed: PackedVector2Array = rect_pts.duplicate()
		closed.append(rect_pts[0])
		ViewUtil.dashed(ci, closed, 4.0, 3.0, ViewColors.AIM_LABEL, 1.8)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	elif ctx.weapon_id == "GANXO":
		_draw_ganxo(ci, f, ctx, origin, dir)
	else:
		_draw_direction(ci, origin, dir)


## Aim direction: a dashed line from the fighter with a small arrow head (no crosshair).
static func _draw_direction(ci: CanvasItem, origin: Vector2, dir: Vector2) -> void:
	var start: Vector2 = origin + dir * 16.0
	var tip: Vector2 = origin + dir * DIRECTION_LEN
	var shadow := Color(0.0431, 0.0549, 0.0863, 0.45)
	ViewUtil.dashed(ci, PackedVector2Array([start + Vector2(1, 1), tip + Vector2(1, 1)]), 7.0, 5.0, shadow, 3.2)
	ViewUtil.dashed(ci, PackedVector2Array([start, tip]), 7.0, 5.0, Color(1.0, 0.9216, 0.7059, 0.9), 2.2)
	var side := Vector2(-dir.y, dir.x)
	var head := PackedVector2Array([tip + dir * 8.0, tip - dir * 3.0 + side * 5.5, tip - dir * 3.0 - side * 5.5])
	ci.draw_colored_polygon(head, Color(1.0, 0.9216, 0.7059, 0.95))
	ci.draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), shadow, 1.2, true)


static func _draw_charge(ci: CanvasItem, f: Variant, ctx: ViewCtx, origin: Vector2, dir: Vector2) -> void:
	var preview: float = maxf(0.22, ctx.charge_power) if ctx.is_charging else 0.56
	var speed: float = 180.0 + preview * 760.0
	var wf: float = ctx.weapon_wind_factor
	var p: Vector2 = origin + dir * 18.0
	var v: Vector2 = dir * speed
	var step_dt: float = 0.028
	var pts := PackedVector2Array([p])
	for b in range(1, 12):
		v.x += (ctx.wind * 2.4 * wf) * step_dt
		v.y += GRAVITY * step_dt
		p += v * step_dt
		pts.append(p)
	var tint: Color = Color(0.9725, 0.8784, 0.6588)
	if wf > 0.0 and absf(ctx.wind) > 18.0:
		tint = Color(1.0, 0.7843, 0.3725) if ctx.wind > 0.0 else Color(0.5294, 0.8431, 0.9608)
	# dashed gradient arc: dashes coloured by their position along the path
	var seg_total: int = pts.size() - 1
	for i in seg_total:
		var f0: float = float(i) / float(seg_total)
		var a: float = lerpf(0.82, 0.42, clampf(f0 / 0.65, 0.0, 1.0)) if f0 < 0.65 else lerpf(0.42, 0.0, (f0 - 0.65) / 0.35)
		ViewUtil.dashed(ci, PackedVector2Array([pts[i], pts[i + 1]]), 5.0, 6.0, Color(tint, a), 2.4)
	var i2: int = 2
	while i2 < pts.size():
		var al: float = (1.0 - float(i2) / float(pts.size() + 1)) * 0.85
		ci.draw_circle(pts[i2], maxf(0.5, 3.0 - float(i2) * 0.16), Color(tint, al))
		i2 += 2
	var ring_r: float = 24.0
	ci.draw_arc(origin, ring_r, 0.0, TAU, 32, Color(1, 1, 1, 0.22) if ctx.is_charging else Color(0.9608, 0.8157, 0.5412, 0.22), 4.5 if ctx.is_charging else 1.5, true)
	var last: Variant = ViewUtil.g(f, "last_charge_power")
	if last != null and float(last) > 0.0:
		var pa: float = -PI * 0.5 + clampf(float(last), 0.04, 1.0) * TAU
		var m: Vector2 = origin + Vector2(cos(pa), sin(pa)) * ring_r
		ViewUtil.circle_fs(ci, m, 3.3, ViewColors.h("#7ec8e3"), ViewColors.h("#0c1017"), 1.2)
	if ctx.is_charging:
		var sa: float = -PI * 0.5
		var ea: float = sa + clampf(ctx.charge_power, 0.04, 1.0) * TAU
		var rc: Color = ViewColors.WARM_YELLOW if ctx.charge_power < 0.5 else (ViewColors.h("#ff8b3d") if ctx.charge_power < 0.82 else ViewColors.h("#ff3b30"))
		ci.draw_arc(origin, ring_r, sa, ea, 32, Color(rc, 0.28), 8.0, true)
		ci.draw_arc(origin, ring_r, sa, ea, 32, rc, 4.8, true)


static func _draw_ganxo(ci: CanvasItem, f: Variant, ctx: ViewCtx, origin: Vector2, dir: Vector2) -> void:
	var latch: Vector2 = origin + dir * 480.0
	var can: bool = false
	var terrain: Object = ctx.terrain
	var d: float = 14.0
	while d <= 480.0:
		var r: Vector2 = origin + dir * d
		if r.y >= ctx.water_y - 6.0:
			break
		var hit: bool = terrain != null and bool(terrain.call("is_solid", r.x, r.y))
		if not hit:
			for other in ctx.fighters:
				if other != f and ViewUtil.gb(other, "alive") and Vector2(ViewUtil.gf(other, "x") - r.x, ViewUtil.gf(other, "y") - 4.0 - r.y).length() <= ViewUtil.gf(other, "r", 12.0) + 8.0:
					hit = true
					break
		if hit:
			latch = r
			can = true
			break
		d += 5.0
	var col: Color = Color(0.5255, 0.9373, 0.6745, 0.72) if can else Color(0.9725, 0.4431, 0.4431, 0.45)
	ViewUtil.dashed(ci, PackedVector2Array([origin + dir * 18.0, latch]), 5.0, 5.0, col, 1.8)
	if can:
		ci.draw_arc(latch, 7.0 + sin(ctx.t_now * 10.0) * 1.5, 0.0, TAU, 16, ViewColors.h("#86efac"), 2.2, true)

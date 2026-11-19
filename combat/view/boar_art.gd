## The wild boar (senglar) of the Processó stage, procedural, side view facing right (mirrored by `facing`): a bristly dark brown barrel with a mane of
## stiff hairs along the back, a long snout, ivory tusks, a small angry eye and a tuft tail. It is an environmental hazard: it waits off-screen, the turn
## before it charges the sim announces it (`sim.boar_intents`: band = the x range it crosses, side = -1 from the left, +1 from the right) and the view
## draws the band with an arrow at the edge it comes from; while it charges (`ai_state` "charge") it runs with a dust trail.
class_name BoarArt
extends RefCounted

const FUR: Color = Color("#5a3b26")
const FUR_DARK: Color = Color("#2f1d12")
const FUR_LIGHT: Color = Color("#7d5535")
const IVORY: Color = Color("#f4ead2")
const DANGER: Color = Color("#ff9a2e")
const WORLD_W: float = 3200.0
const IDLE := "idle"
const CHARGE := "charge"


## True for a boar fighter.
static func is_boar(f: Variant) -> bool:
	return ViewUtil.gs(f, "kind") == "WILD_BOAR"


## "charge" while the boar runs, else "idle" (the sim's ai_state, or a `charging` flag).
static func phase(f: Variant) -> String:
	var st: String = ViewUtil.gs(f, "ai_state").to_lower()
	return CHARGE if st in ["charge", "charging", "dash", "run"] or ViewUtil.gb(f, "charging") else IDLE


# ---------------------------------------------------------------- the telegraph

## The band the boar will cross next turn, full height like the forestry pole band, with horizontal chevrons showing the way it runs and a big arrow
## at the edge it comes from (kept inside what the camera sees). `intent` is one of sim.boar_intents.
static func draw_warning(ci: CanvasItem, intent: Dictionary, ctx: ViewCtx) -> void:
	var b: Rect2 = intent.get("band", Rect2())
	if b.size.x < 1.0:
		return
	var side: int = int(intent.get("side", -1))
	var dir: float = -1.0 if side > 0 else 1.0
	var t: float = ctx.t_now
	var k: float = 1.0 / maxf(0.3, ctx.scale_px)
	var half_h: float = ctx.view_size.y * 0.5 * k
	var y0: float = maxf(b.position.y, ctx.cam_pos.y - half_h - 20.0)
	var y1: float = minf(b.end.y, ctx.cam_pos.y + half_h + 20.0)
	if y1 <= y0:
		return
	var pulse: float = 0.5 + 0.5 * sin(t * 6.0)
	var rect := Rect2(b.position.x, y0, b.size.x, y1 - y0)
	ci.draw_rect(rect, Color(DANGER, 0.09 + 0.07 * pulse))
	var step: float = 44.0
	var y: float = floorf(y0 / step) * step
	while y < y1 + rect.size.x:
		ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y - rect.size.x * 0.6), Color(DANGER, 0.2), 4.0, true)
		y += step
	for x in [rect.position.x, rect.end.x]:
		ViewUtil.dashed(ci, PackedVector2Array([Vector2(x, y0), Vector2(x, y1)]), 14.0, 9.0, Color(DANGER, 0.95), 3.0)
	# chevrons in rows, sliding the way the boar runs
	var vis: Vector2 = visible_x(ctx)
	var x_from: float = maxf(rect.position.x, vis.x)
	var x_to: float = minf(rect.end.x, vis.y)
	var row_y: float = floorf(y0 / 120.0) * 120.0 + 60.0
	while row_y < y1:
		if row_y > y0:
			var cx: float = x_from + fmod(t * 80.0 * dir + 4000.0, 110.0) - 110.0
			while cx < x_to:
				if cx > x_from:
					_chevron(ci, Vector2(cx, row_y), dir, 10.0, Color(DANGER, 0.35 + 0.35 * pulse))
				cx += 110.0
		row_y += 120.0
	# the side arrow and the label, near the ground height of the leader (or the camera centre)
	var ay: float = clampf(_ground_y(ctx) - 60.0 * k, y0 + 60.0, y1 - 60.0)
	var from_x: float = rect.position.x if dir > 0.0 else rect.end.x
	var edge_x: float = clampf(from_x, vis.x + 70.0 * k, vis.y - 70.0 * k)
	_side_arrow(ci, Vector2(edge_x, ay), dir, maxf(1.0, k), t)
	var turns: int = int(intent.get("turns_left", 1))
	var label: String = ViewUtil.tr_text("PROC_BOAR_WARN") if turns <= 1 else UiUtil.fmt("PROC_BOAR_WARN_N", [turns])
	BossOverlay.draw_bubble(ci, ctx, label, Vector2(edge_x + dir * 120.0 * k, ay - 40.0 * k), DANGER)


## y of the ground under the leader (or the camera centre when there is none).
static func _ground_y(ctx: ViewCtx) -> float:
	return ViewUtil.gf(ctx.leader, "y", ctx.cam_pos.y) if ctx.leader != null else ctx.cam_pos.y


## World x range of the screen (what the camera sees).
static func visible_x(ctx: ViewCtx) -> Vector2:
	var hw: float = ctx.view_size.x * 0.5 / maxf(0.01, ctx.scale_px)
	return Vector2(ctx.cam_pos.x - hw, ctx.cam_pos.x + hw)


static func _chevron(ci: CanvasItem, p: Vector2, dir: float, s: float, col: Color) -> void:
	ci.draw_polyline(PackedVector2Array([p + Vector2(-dir * s, -s), p + Vector2(dir * s * 0.3, 0.0), p + Vector2(-dir * s, s)]), col, 3.0, true)


static func _side_arrow(ci: CanvasItem, p: Vector2, dir: float, k: float, t: float) -> void:
	var bump: float = sin(t * 8.0) * 5.0 * k * dir
	var s: float = 20.0 * k
	var tip: Vector2 = p + Vector2(dir * s * 1.5 + bump, 0.0)
	var pts := PackedVector2Array([tip, tip + Vector2(-dir * s, -s * 0.9), tip + Vector2(-dir * s, -s * 0.38), tip + Vector2(-dir * s * 2.1, -s * 0.38),
		tip + Vector2(-dir * s * 2.1, s * 0.38), tip + Vector2(-dir * s, s * 0.38), tip + Vector2(-dir * s, s * 0.9)])
	var shadow := PackedVector2Array()
	for q in pts:
		shadow.append(q + Vector2(2.0, 2.0))
	ViewUtil.fill_poly(ci, shadow, Color(0.0, 0.0, 0.0, 0.4))
	ViewUtil.fill_poly(ci, pts, DANGER)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color("#6a2a00"), 2.0, true)
	ViewUtil.text(ci, "!", p + Vector2(-dir * s * 0.4 + bump, s * 0.4), roundi(s * 1.1), Color("#4a1c00"))


# ---------------------------------------------------------------- the animal

static func draw(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	var r: float = ViewUtil.gf(f, "r", 20.0)
	var s: float = r / 20.0
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	if facing == 0.0:
		facing = 1.0
	var st: String = phase(f)
	var charging: bool = st == CHARGE
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var feet := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + r)
	var run: float = t * (22.0 if charging else 4.0) + float(ViewUtil.gi(f, "id"))
	if charging:
		_dust(ci, feet, facing, s, t)
	var bob: float = (absf(sin(run)) * 2.6 * s) if charging else sin(run) * 0.5
	var xf := Transform2D(0.0, Vector2(facing * s, s), 0.0, feet + Vector2(0.0, -bob))
	ci.draw_set_transform_matrix(xf)
	var line: Color = FUR_DARK
	var lifted: Transform2D = xf * Transform2D(0.0, Vector2(0.0, -4.5))
	# far legs, body, near legs
	_legs(ci, run, charging, true, line)
	ci.draw_set_transform_matrix(lifted)
	ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(-28.0, -22.0), Vector2(-33.0, -30.0), Vector2(-26.0, -28.0), Vector2(-24.0, -24.0)]), FUR_DARK)
	# tail tuft
	var wag: float = sin(run * 0.8) * 3.0
	ci.draw_polyline(ViewUtil.quad_pts(Vector2(-28.0, -26.0), Vector2(-35.0, -32.0 + wag), Vector2(-33.0, -40.0 + wag), 8), line, 2.2, true)
	ViewUtil.fill_ellipse(ci, Vector2(-33.0, -41.0 + wag), 3.0, 4.0, FUR_LIGHT, 0.3)
	# body: a deep barrel, higher at the shoulders
	var body := PackedVector2Array([Vector2(-30.0, -18.0), Vector2(-27.0, -34.0), Vector2(-12.0, -41.0), Vector2(6.0, -45.0), Vector2(20.0, -38.0),
		Vector2(28.0, -26.0), Vector2(24.0, -12.0), Vector2(8.0, -8.0), Vector2(-14.0, -8.0), Vector2(-26.0, -10.0)])
	ViewUtil.fill_poly(ci, body, FUR)
	ViewUtil.fill_ellipse(ci, Vector2(-2.0, -33.0), 22.0, 9.0, Color(FUR_LIGHT, 0.55), -0.1)
	ViewUtil.fill_ellipse(ci, Vector2(-2.0, -12.0), 24.0, 4.5, Color(FUR_DARK, 0.55))
	# the mane: a row of stiff bristles along the back, shivering
	for i in 15:
		var u: float = float(i) / 14.0
		var bx: float = lerpf(-28.0, 16.0, u)
		var by: float = -34.0 - sin(u * PI) * 11.0 + (u * 4.0)
		var h: float = 7.0 + sin(float(i) * 2.3) * 2.0 + (4.0 if i % 3 == 0 else 0.0)
		var lean: float = -0.5 + u * 0.9 + sin(t * 9.0 + float(i)) * 0.07
		ci.draw_line(Vector2(bx, by + 2.0), Vector2(bx + sin(lean) * h, by - cos(lean) * h), FUR_DARK, 1.8, true)
	# fur tufts on the flank
	for i in 7:
		var fx: float = -22.0 + float(i) * 7.0
		ci.draw_line(Vector2(fx, -24.0 + float(i % 2) * 5.0), Vector2(fx - 3.0, -20.0 + float(i % 2) * 5.0), Color(FUR_DARK, 0.7), 1.3, true)
	ci.draw_polyline(_close(body), line, 2.0, true)
	ci.draw_set_transform_matrix(xf)
	_legs(ci, run, charging, false, line)
	ci.draw_set_transform_matrix(lifted)
	_head(ci, charging, hurt, t)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _close(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


## Four short legs: the far pair is drawn first and darker. Charging they gallop in a fast scissor.
static func _legs(ci: CanvasItem, run: float, charging: bool, far: bool, line: Color) -> void:
	var xs := PackedFloat32Array([-21.0, 16.0] if not far else [-13.0, 22.0])
	for i in 2:
		var ph: float = run + float(i) * PI + (0.0 if far else PI * 0.5)
		var sw: float = sin(ph) * (9.0 if charging else 1.5)
		var lift: float = maxf(0.0, cos(ph)) * (6.0 if charging else 0.0)
		var top := Vector2(xs[i], -14.0)
		var foot := Vector2(xs[i] + sw, -lift)
		var col: Color = FUR_DARK if far else FUR
		ci.draw_line(top, foot, line, 7.0, true)
		ci.draw_line(top, foot, col, 5.0, true)
		ViewUtil.fill_ellipse(ci, foot + Vector2(1.5, -1.0), 3.6, 2.6, Color("#1c1410"))


static func _head(ci: CanvasItem, charging: bool, hurt: float, t: float) -> void:
	var c := Vector2(28.0, -22.0 + (4.0 if charging else 0.0))
	var line: Color = FUR_DARK
	# ear and neck wedge
	ViewUtil.fill_poly(ci, PackedVector2Array([c + Vector2(-6.0, -16.0), c + Vector2(-9.0, -26.0), c + Vector2(-1.0, -18.0)]), FUR_DARK)
	var head := PackedVector2Array([c + Vector2(-9.0, -15.0), c + Vector2(4.0, -15.0), c + Vector2(20.0, -2.0), c + Vector2(24.0, 5.0), c + Vector2(18.0, 11.0),
		c + Vector2(4.0, 12.0), c + Vector2(-8.0, 10.0)])
	ViewUtil.fill_poly(ci, head, FUR_LIGHT)
	ci.draw_polyline(_close(head), line, 2.0, true)
	# snout disc and nostrils
	ViewUtil.ellipse_fs(ci, c + Vector2(22.0, 4.0), 4.6, 7.0, Color("#c79a86"), line, 1.6, 0.1)
	ci.draw_circle(c + Vector2(23.5, 1.5), 1.2, line)
	ci.draw_circle(c + Vector2(23.5, 6.0), 1.2, line)
	# tusks: two curved ivory horns from the lower jaw
	for tx in [10.0, 16.0]:
		var base: Vector2 = c + Vector2(tx, 9.0)
		var tusk: PackedVector2Array = ViewUtil.quad_pts(base, base + Vector2(5.0, 6.0), base + Vector2(4.0, -3.0) + Vector2(5.0, 2.0), 8)
		ci.draw_polyline(tusk, line, 4.6, true)
		ci.draw_polyline(tusk, IVORY, 2.8, true)
	# eye with a frown
	var eye: Vector2 = c + Vector2(6.0, -4.0)
	if hurt > 0.2:
		ci.draw_line(eye + Vector2(-2.0, -2.0), eye + Vector2(2.0, 2.0), line, 1.8, true)
		ci.draw_line(eye + Vector2(2.0, -2.0), eye + Vector2(-2.0, 2.0), line, 1.8, true)
	else:
		ci.draw_circle(eye, 3.0, Color("#f7ecd8"))
		ci.draw_circle(eye + Vector2(0.8, 0.0), 1.9, Color("#a8261c") if charging else Color("#1a1210"))
		ci.draw_circle(eye + Vector2(0.2, -0.8), 0.6, Color.WHITE)
	ci.draw_line(eye + Vector2(-4.0, -5.0), eye + Vector2(4.5, -1.6), line, 2.6, true)
	if charging:
		# steam from the nostrils
		for k in 2:
			var ph: float = fmod(t * 3.0 + float(k) * 0.5, 1.0)
			ci.draw_circle(c + Vector2(28.0 + ph * 10.0, 3.0 - ph * 6.0), 2.0 + ph * 3.0, Color(1.0, 1.0, 1.0, 0.45 * (1.0 - ph)))


## Dust kicked up behind a charging boar: puffs along the ground that fade and grow with the distance, plus a few flying clods.
static func _dust(ci: CanvasItem, feet: Vector2, facing: float, s: float, t: float) -> void:
	for k in 14:
		var u: float = float(k) / 13.0
		var wob: float = sin(t * 14.0 + float(k) * 1.7)
		var p: Vector2 = feet + Vector2(-facing * (24.0 + u * 130.0) * s, -4.0 - u * 14.0 * s + wob * 2.0)
		var rad: float = (7.0 + u * 20.0) * s
		ViewUtil.radial(ci, p, 0.0, rad, [[0.0, Color(0.82, 0.72, 0.58, 0.62)], [1.0, Color(0.82, 0.72, 0.58, 0.0)]], 1.0 - u * 0.8, "boar_dust")
	for k in 6:
		var ph: float = fmod(t * 2.2 + float(k) * 0.37, 1.0)
		var p2: Vector2 = feet + Vector2(-facing * (14.0 + ph * 55.0) * s, -ph * 26.0 * s + ph * ph * 26.0 * s)
		ci.draw_circle(p2, 1.8 * s, Color("#6b4a2f"))

## What makes a file of caterpillars look like a procession (La Processó stage): the silk thread that links neighbours head to tail, the little gold
## crown of the leader, the worried "?" and the dashed line back to the file of a lost follower, the march range under the leader and the goal
## zone (a patch of soft soil with a sign and sparkles). Everything is read from the ViewCtx; nothing is stored.
class_name ConvoyArt
extends RefCounted

const SILK: Color = Color(0.96, 0.95, 0.92)
const CROWN: Color = Color("#ffd24a")
const CROWN_DARK: Color = Color("#8a5a14")
const WORRY: Color = Color("#ffb347")
const SOIL: Color = Color("#6b4a2f")
const SOIL_DARK: Color = Color("#3f2a19")
const SOIL_LIGHT: Color = Color("#8f6a45")
const SPARKLE: Color = Color("#fff3b0")
const SIGN_WOOD: Color = Color("#a8743a")
const SIGN_TEXT: Color = Color("#2d1a0a")
const REACH: Color = Color("#9be28c")


# ---------------------------------------------------------------- thread

## The silk thread of the file under the fighters: a sagging line between each caterpillar and the one in front. A lost follower hangs a
## dashed, thinner line to the nearest member of the file instead.
static func draw_thread(ci: CanvasItem, ctx: ViewCtx) -> void:
	if not ctx.convoy or ctx.line.size() < 2:
		return
	var kept: Array = []
	for f in ctx.line:
		if not ViewUtil.gb(f, "lost"):
			kept.append(f)
	for i in range(1, kept.size()):
		_silk_between(ci, _anchor(kept[i - 1]), _anchor(kept[i]), ctx.t_now, 1.0)
	for f in ctx.line:
		if ViewUtil.gb(f, "lost"):
			var near: Variant = _nearest(f, kept)
			if near != null:
				_dashed_back(ci, _anchor(f), _anchor(near), ctx.t_now)


## Where the thread is tied: a bit above the ground under the body.
static func _anchor(f: Variant) -> Vector2:
	return Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + ViewUtil.gf(f, "r", 10.0) + 1.0)


static func _nearest(f: Variant, from: Array) -> Variant:
	var best: Variant = null
	var best_d: float = INF
	for o in from:
		var d: float = ViewUtil.pos(o).distance_to(ViewUtil.pos(f))
		if d < best_d:
			best_d = d
			best = o
	return best


## A thread hanging in a shallow curve between two tie points; the sag shrinks when they are far apart (the thread is taut).
static func _silk_between(ci: CanvasItem, a: Vector2, b: Vector2, t: float, alpha: float) -> void:
	var span: float = a.distance_to(b)
	if span < 3.0:
		return
	var sag: float = clampf(24.0 - span * 0.12, 6.0, 13.0) + sin(t * 2.2 + a.x * 0.03) * 0.8
	var mid: Vector2 = (a + b) * 0.5 + Vector2(0.0, sag)
	var pts: PackedVector2Array = ViewUtil.quad_pts(a, mid + Vector2(0.0, sag * 0.4), b, 14)
	ci.draw_polyline(pts, Color(0.0, 0.0, 0.0, 0.18 * alpha), 3.0, true)
	ci.draw_polyline(pts, Color(SILK, 0.85 * alpha), 1.6, true)


static func _dashed_back(ci: CanvasItem, from: Vector2, to: Vector2, t: float) -> void:
	var pts := PackedVector2Array([from, to])
	ViewUtil.dashed(ci, pts, 6.0, 6.0, Color(0.0, 0.0, 0.0, 0.3), 3.0)
	ViewUtil.dashed(ci, pts, 6.0, 6.0, Color(WORRY, 0.7 + 0.2 * sin(t * 5.0)), 1.6)


# ---------------------------------------------------------------- marks over the fighters

## Crown over the leader and the "?" over a lost follower (call it after the fighter itself is drawn).
static func draw_marks(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	if not ctx.convoy or ViewUtil.gi(f, "team") != 0 or ViewUtil.gb(f, "drowning"):
		return
	var s: float = LarvaArt.scale_of(f) if ViewUtil.gs(f, "kind").begins_with("LARVA") else 1.0
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 10.0)
	var head := Vector2(ViewUtil.gf(f, "x") + facing * 4.6 * s, ViewUtil.gf(f, "y") + r - 10.6 * s)
	if f == ctx.leader:
		_crown(ci, head + Vector2(0.0, -14.0 * s + sin(ctx.t_now * 3.0) * 0.6), maxf(0.8, s), facing)
	elif ViewUtil.gb(f, "lost"):
		_worry(ci, head + Vector2(facing * 2.0, -15.0 * s), maxf(0.8, s), ctx.t_now)


static func _crown(ci: CanvasItem, c: Vector2, s: float, facing: float) -> void:
	var w: float = 6.0 * s
	var h: float = 6.0 * s
	var tilt: float = -0.12 * facing
	var xf := Transform2D(tilt, Vector2.ONE, 0.0, c)
	var pts := PackedVector2Array([Vector2(-w, 0.0), Vector2(-w, -h * 0.9), Vector2(-w * 0.5, -h * 0.35), Vector2(0.0, -h * 1.15),
		Vector2(w * 0.5, -h * 0.35), Vector2(w, -h * 0.9), Vector2(w, 0.0)])
	var world := PackedVector2Array()
	for p in pts:
		world.append(xf * p)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	ArtKit.soft_shadow(ci, c + Vector2(0.0, 1.2 * s), w * 1.1, 1.4 * s, 0.25)
	ArtKit.fill_poly(ci, world, CROWN)
	# shading: darker lower half and right side, light on the left spike
	var shade := PackedVector2Array([xf * Vector2(-w, -h * 0.28), xf * Vector2(w, -h * 0.28), xf * Vector2(w, 0.0), xf * Vector2(-w, 0.0)])
	ArtKit.fill_poly(ci, shade, Color("#e6a52a"))
	ArtKit.fill_poly(ci, PackedVector2Array([xf * Vector2(w * 0.6, -h * 0.3), xf * Vector2(w, -h * 0.9), xf * Vector2(w, 0.0), xf * Vector2(w * 0.55, 0.0)]), Color(CROWN_DARK, 0.28))
	var closed := world.duplicate()
	closed.append(world[0])
	ci.draw_polyline(closed, CROWN_DARK, 1.2, true)
	ci.draw_line(xf * Vector2(-w * 0.9, -h * 0.12), xf * Vector2(w * 0.9, -h * 0.12), Color(CROWN_DARK, 0.7), 0.9 * s, true)
	ci.draw_line(xf * Vector2(-w * 0.9, -h * 0.82), xf * Vector2(-w * 0.55, -h * 0.4), Color(1.0, 0.97, 0.75, 0.8), 1.2 * s, true)
	for jx in [-0.6, 0.6]:
		ci.draw_circle(xf * Vector2(w * float(jx), -h * 0.2), 0.75 * s, Color("#3da5e0"))
	ci.draw_circle(xf * Vector2(0.0, -h * 0.35), 1.2 * s, CROWN_DARK)
	ci.draw_circle(xf * Vector2(0.0, -h * 0.35), 0.95 * s, Color("#e0402f"))
	ci.draw_circle(xf * Vector2(-0.3 * s, -h * 0.4), 0.3 * s, Color(1, 1, 1, 0.8))
	for tip in [Vector2(-w, -h * 0.9), Vector2(0.0, -h * 1.15), Vector2(w, -h * 0.9)]:
		ci.draw_circle(xf * tip, 1.0 * s, CROWN_DARK)
		ci.draw_circle(xf * tip, 0.8 * s, Color("#fff4cf"))


## A worried "?" in a little bubble with a sweat drop, wobbling.
static func _worry(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var wob: float = sin(t * 6.0) * 1.2
	var at: Vector2 = c + Vector2(wob, -2.0 * absf(sin(t * 3.0)))
	ArtKit.gradient_disc(ci, at, 7.5 * s, at + Vector2(-2.0, -2.5) * s, 0.5, 9.0 * s, [[0.0, Color(0.13, 0.16, 0.25, 0.92)], [1.0, Color(0.03, 0.04, 0.08, 0.92)]], "convoy_worry")
	ci.draw_arc(at, 7.5 * s, 0.0, TAU, 20, WORRY, 1.4, true)
	ci.draw_arc(at, 6.0 * s, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.3), 1.0, true)
	ViewUtil.text(ci, "?", at + Vector2(0.0, 4.4 * s), roundi(13.0 * s), WORRY)
	var drop: Vector2 = c + Vector2(9.0 * s + wob * 0.5, 3.0)
	ViewUtil.fill_poly(ci, PackedVector2Array([drop + Vector2(0.0, -3.4), drop + Vector2(-2.0, 0.6), drop + Vector2(2.0, 0.6)]), Color("#8fd8f2"))
	ci.draw_circle(drop + Vector2(0.0, 0.8), 2.0, Color("#8fd8f2"))
	ci.draw_circle(drop + Vector2(-0.7, 0.2), 0.6, Color(1, 1, 1, 0.8))


# ---------------------------------------------------------------- march range

## Under the leader on its turn: how far the rest of the walk budget reaches (a faint dashed strip with end posts).
static func draw_reach(ci: CanvasItem, ctx: ViewCtx) -> void:
	if not ctx.convoy or ctx.leader == null or ctx.march_budget <= 0.0 or ctx.phase != ViewCtx.PH_TURN_PLAY or not ctx.human_turn:
		return
	var l: Variant = ctx.leader
	var x0: float = ViewUtil.gf(l, "x")
	var y: float = ViewUtil.gf(l, "y") + ViewUtil.gf(l, "r", 10.0) + 6.0
	var reach: float = ctx.march_left
	var a: float = 0.28 + 0.1 * sin(ctx.t_now * 3.0)
	ViewUtil.dashed(ci, PackedVector2Array([Vector2(x0 - reach, y), Vector2(x0 + reach, y)]), 7.0, 6.0, Color(REACH, a), 2.0)
	for sx in [-1.0, 1.0]:
		var px: float = x0 + sx * reach
		ci.draw_line(Vector2(px, y - 9.0), Vector2(px, y + 3.0), Color(REACH, a + 0.25), 2.4, true)
		ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(px, y - 9.0), Vector2(px + sx * 8.0, y - 6.0), Vector2(px, y - 3.0)]), Color(REACH, a + 0.25))


# ---------------------------------------------------------------- goal zone

## The soft soil patch the file is heading for, standing on the ground at `ctx.goal_x`, with the "Terra tova" sign and sparkles.
static func draw_goal(ci: CanvasItem, ctx: ViewCtx) -> void:
	if not ctx.convoy or ctx.goal_x < 0.0 or ctx.terrain == null:
		return
	var gx: float = ctx.goal_x
	var half: float = ctx.goal_half
	var surf: float = ctx.goal_y if ctx.goal_y > 0.0 else float(ctx.terrain.call("find_surface_y", gx, 0.0))
	if surf <= 1.0:
		return
	var t: float = ctx.t_now
	# the mound follows the ground around the goal: a soft heap of soil lying on it, thickest in the middle
	var n: int = 24
	var top := PackedVector2Array()
	var low := PackedVector2Array()
	var ground := PackedFloat32Array()
	for i in n + 1:
		var u: float = float(i) / float(n)
		var x: float = gx - half + u * half * 2.0
		var gy: float = float(ctx.terrain.call("find_surface_y", x, surf - 70.0))
		if absf(gy - surf) > 90.0:
			gy = surf
		ground.append(gy)
		top.append(Vector2(x, gy - sin(u * PI) * 9.0 - 2.0))
		low.append(Vector2(x, gy + 9.0))
	var poly := top.duplicate()
	for i in range(n, -1, -1):
		poly.append(low[i])
	var shadow := PackedVector2Array()
	for i in n + 1:
		shadow.append(Vector2(top[i].x, low[i].y + 2.0))
	ci.draw_polyline(shadow, Color(0.0, 0.0, 0.0, 0.18), 5.0, true)
	ViewUtil.fill_poly(ci, poly, Color(SOIL, 0.94))
	# volume: a darker belly towards the ground line, a lit crest and a soft highlight on the top left
	var belly := PackedVector2Array()
	for i in n + 1:
		belly.append(Vector2(top[i].x, lerpf(top[i].y, low[i].y, 0.55)))
	ci.draw_polyline(belly, Color(SOIL_DARK, 0.35), 7.0, true)
	ci.draw_polyline(top, SOIL_LIGHT, 2.4, true)
	var crest := PackedVector2Array()
	for i in range(1, int(n * 0.6)):
		crest.append(top[i] + Vector2(0.0, 2.2))
	ci.draw_polyline(crest, Color(1.0, 0.93, 0.75, 0.22), 2.0, true)
	for k in 26:
		var i2: int = clampi(int(fmod(float(k) * 0.381966, 1.0) * float(n)), 0, n)
		var p: Vector2 = top[i2] + Vector2(float(k % 3) - 1.0, 4.0 + float(k % 4) * 2.0)
		ci.draw_circle(p, 1.3 + float(k % 3) * 0.5, SOIL_DARK if k % 2 == 0 else SOIL_LIGHT)
	for k in 6:
		_sprout(ci, top[2 + k * 4] + Vector2(0.0, 1.0), t, k)
	_sign(ci, top[n - 5] + Vector2(0.0, 2.0), t)
	for k in 9:
		_sparkle(ci, gx, half, surf, t, k)


static func _sprout(ci: CanvasItem, p: Vector2, t: float, k: int) -> void:
	var sway: float = sin(t * 2.0 + float(k)) * 1.4
	ci.draw_line(p, p + Vector2(sway, -7.0), Color("#6fae4a"), 1.6, true)
	ViewUtil.fill_ellipse(ci, p + Vector2(sway - 2.6, -7.0), 2.8, 1.5, Color("#8fd26a"), -0.4)
	ViewUtil.fill_ellipse(ci, p + Vector2(sway + 2.6, -8.0), 2.8, 1.5, Color("#8fd26a"), 0.4)


## A little wooden sign: a post and a board with the Catalan text.
static func _sign(ci: CanvasItem, foot: Vector2, t: float) -> void:
	var text: String = ViewUtil.tr_text("PROC_GOAL_SIGN")
	var w: float = maxf(70.0, ViewUtil.text_w(text, 12) + 16.0)
	ci.draw_line(foot, foot + Vector2(0.0, -34.0), SOIL_DARK, 3.8, true)
	ci.draw_line(foot + Vector2(-0.5, 0.0), foot + Vector2(-0.5, -34.0), SIGN_WOOD.darkened(0.15), 1.8, true)
	var board := Rect2(foot.x - w * 0.5, foot.y - 52.0 + sin(t * 1.6) * 0.5, w, 20.0)
	ViewUtil.round_rect_fs(ci, board, 4.0, SIGN_WOOD, SOIL_DARK, 1.8)
	ViewUtil.fill_round_rect(ci, Rect2(board.position.x + 1.5, board.position.y + board.size.y * 0.55, w - 3.0, board.size.y * 0.42), 3.0, Color(SOIL_DARK, 0.22))
	ci.draw_line(board.position + Vector2(5.0, 4.0), board.position + Vector2(w - 5.0, 4.0), Color(1.0, 1.0, 1.0, 0.28), 1.2, true)
	for gy in [7.5, 12.5, 16.5]:
		ci.draw_line(board.position + Vector2(4.0, gy), board.position + Vector2(w * 0.45 + gy, gy + 0.4), Color(SOIL_DARK, 0.18), 0.8, true)
	for nx in [3.5, w - 3.5]:
		ci.draw_circle(board.position + Vector2(nx, 3.5), 0.9, SOIL_DARK)
	ViewUtil.text(ci, text, Vector2(foot.x, board.position.y + 14.5), 12, SIGN_TEXT)


## A twinkling four-point star floating above the patch.
static func _sparkle(ci: CanvasItem, gx: float, half: float, surf: float, t: float, k: int) -> void:
	var ph: float = fmod(t * 0.55 + float(k) * 0.37, 1.0)
	var x: float = gx - half * 0.9 + fmod(float(k) * 53.0, half * 1.8)
	var y: float = surf - 8.0 - ph * 46.0 - float(k % 3) * 6.0
	var a: float = sin(ph * PI)
	var sz: float = (3.0 + float(k % 3)) * a
	if sz < 0.4:
		return
	var col := Color(SPARKLE, a)
	ci.draw_line(Vector2(x - sz, y), Vector2(x + sz, y), col, 1.6, true)
	ci.draw_line(Vector2(x, y - sz), Vector2(x, y + sz), col, 1.6, true)
	ci.draw_circle(Vector2(x, y), sz * 0.35, Color(1.0, 1.0, 1.0, a))

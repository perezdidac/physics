## What the levels of the second pass show in the world (docs/story_contracts.md §7): the pine branch of REACH, the silk cocoon of the trapped
## sister of RESCUE, a golden ring round every pine nut of COLLECT and the small HP bar over a destructible anthill. Everything is read from
## the ViewCtx (filled by `read` from sim.goals); nothing is stored.
class_name StoryGoalArt
extends RefCounted

const NEEDLE: Color = Color("#4f8f3e")
const NEEDLE_LIGHT: Color = Color("#8fd26a")
const BARK: Color = Color("#6b4a2f")
const BARK_DARK: Color = Color("#3f2a19")
const SILK: Color = Color(0.96, 0.95, 0.92)
const GOLD: Color = Color("#ffd24a")
const SPARKLE: Color = Color("#fff3b0")
const SIGN_WOOD: Color = Color("#a8743a")
const SIGN_TEXT: Color = Color("#2d1a0a")
const BAR_BACK: Color = Color(0.04, 0.05, 0.08, 0.85)


## Fills the goal fields of `ctx` from the sim (the defaults outside the levels that have one).
static func read(ctx: ViewCtx, sim: Object) -> void:
	ctx.goal_kind = ""
	ctx.goal_pos = Vector2.ZERO
	ctx.goal_nuts = []
	ctx.anthill_frac = -1.0
	var g: Variant = ViewUtil.g(sim, "goals")
	if g == null:
		return
	ctx.goal_kind = ViewUtil.gs(g, "kind")
	var p: Variant = ViewUtil.g(g, "pos")
	if p is Vector2 and (p as Vector2).is_finite() and not ViewUtil.gb(g, "freed"):
		ctx.goal_pos = p
		ctx.goal_radius = ViewUtil.gf(g, "radius", 60.0)
	for n in ViewUtil.g(g, "nuts", []):
		ctx.goal_nuts.append(Vector2(ViewUtil.gf(n, "x"), ViewUtil.gf(n, "y")))
	var mx: int = ViewUtil.gi(g, "anthill_max")
	if mx > 0:
		ctx.anthill_frac = clampf(float(ViewUtil.gi(g, "anthill_hp")) / float(mx), 0.0, 1.0)


static func draw(ci: CanvasItem, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	if ctx.goal_pos != Vector2.ZERO:
		if ctx.goal_kind == "REACH":
			_branch(ci, ctx.goal_pos, ctx.goal_radius, t)
		elif ctx.goal_kind == "RESCUE":
			_cocoon(ci, ctx.goal_pos, t)
	for p in ctx.goal_nuts:
		_nut_ring(ci, p, t)
	if ctx.anthill_frac >= 0.0 and ctx.has_anthill:
		_anthill_bar(ci, ctx.anthill_pos, ctx.anthill_frac)


## A pine branch standing on the ground: a trunk of bark with three needle fans and a wooden sign, over a dashed ring that marks the radius.
static func _branch(ci: CanvasItem, foot: Vector2, radius: float, t: float) -> void:
	var ring_a: float = 0.32 + 0.1 * sin(t * 2.4)
	ViewUtil.dashed(ci, PackedVector2Array([foot + Vector2(-radius, 2.0), foot + Vector2(radius, 2.0)]), 8.0, 6.0, Color(NEEDLE_LIGHT, ring_a + 0.2), 2.0)
	var top: Vector2 = foot + Vector2(0.0, -46.0)
	ci.draw_line(foot, top, BARK_DARK, 5.0, true)
	ci.draw_line(foot + Vector2(-0.8, 0.0), top + Vector2(-0.8, 0.0), BARK, 2.2, true)
	for k in 3:
		var base: Vector2 = foot + Vector2(0.0, -14.0 - 14.0 * float(k))
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var sway: float = sin(t * 1.6 + float(k)) * 1.6
		var tip: Vector2 = base + Vector2(side * (24.0 - 3.0 * float(k)), -9.0 + sway)
		ci.draw_line(base, tip, BARK, 2.4, true)
		for n in 7:
			var u: float = 0.35 + 0.65 * float(n) / 6.0
			var anchor: Vector2 = base.lerp(tip, u)
			for d in [-1.0, 1.0]:
				ci.draw_line(anchor, anchor + Vector2(side * 4.0, d * 7.0 + sway * 0.3), NEEDLE if n % 2 == 0 else NEEDLE_LIGHT, 1.3, true)
	ci.draw_circle(top + Vector2(0.0, -2.0), 3.0, NEEDLE_LIGHT)
	for k in 5:
		var a: float = t * 1.3 + float(k) * 1.26
		var sp: Vector2 = foot + Vector2(cos(a) * radius * 0.7, -22.0 - sin(a * 1.7) * 18.0)
		ci.draw_circle(sp, 1.3 + 0.7 * sin(t * 4.0 + float(k)), Color(SPARKLE, 0.75))
	_sign(ci, foot + Vector2(radius * 0.55, 0.0), ViewUtil.tr_text("GOAL_BRANCH_SIGN"))


## A wooden sign: a post and a board with the text.
static func _sign(ci: CanvasItem, foot: Vector2, text: String) -> void:
	var w: float = maxf(54.0, ViewUtil.text_w(text, 12) + 14.0)
	ci.draw_line(foot, foot + Vector2(0.0, -28.0), BARK_DARK, 3.4, true)
	var board := Rect2(foot.x - w * 0.5, foot.y - 46.0, w, 19.0)
	ViewUtil.round_rect_fs(ci, board, 4.0, SIGN_WOOD, BARK_DARK, 1.6)
	ViewUtil.text(ci, text, Vector2(foot.x, board.position.y + 13.5), 12, SIGN_TEXT)


## A silk cocoon with two worried eyes, wobbling a little and wrapped in crossing threads.
static func _cocoon(ci: CanvasItem, foot: Vector2, t: float) -> void:
	var wob: float = sin(t * 3.2) * 0.05
	var c: Vector2 = foot + Vector2(0.0, -17.0)
	ci.draw_set_transform_matrix(Transform2D(wob, Vector2.ONE, 0.0, c))
	ViewUtil.fill_ellipse(ci, Vector2(0.0, 17.0), 17.0, 4.0, Color(0.0, 0.0, 0.0, 0.2))
	ViewUtil.ellipse_fs(ci, Vector2.ZERO, 14.0, 18.0, Color(SILK, 0.96), Color("#b8b2a4"), 1.6)
	for k in 5:
		var y: float = -12.0 + float(k) * 6.0
		ci.draw_line(Vector2(-13.0, y), Vector2(13.0, y + 5.0), Color("#c9c3b4"), 1.1, true)
		ci.draw_line(Vector2(13.0, y), Vector2(-13.0, y + 5.0), Color("#d8d3c6"), 0.9, true)
	for ex in [-5.0, 5.0]:
		ci.draw_circle(Vector2(ex, -4.0), 3.6, Color.WHITE)
		ci.draw_circle(Vector2(ex + 0.6, -3.6), 1.9, Color("#2d1a0a"))
	ci.draw_arc(Vector2(0.0, 5.0), 3.2, PI * 1.1, PI * 1.9, 8, Color("#8a5a14"), 1.3, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	var bob: float = sin(t * 3.0) * 2.0
	ViewUtil.text(ci, "!", Vector2(foot.x, foot.y - 50.0 + bob), 18, Color("#ffb347"))
	for k in 4:
		var a: float = t * 1.1 + float(k) * 1.57
		ci.draw_circle(c + Vector2(cos(a) * 24.0, sin(a * 1.3) * 16.0), 1.4, Color(SPARKLE, 0.7))


## A golden ring pulsing round a nut of the goal.
static func _nut_ring(ci: CanvasItem, p: Vector2, t: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * 3.0 + p.x * 0.05)
	ci.draw_arc(p, 11.0 + 2.5 * pulse, 0.0, TAU, 24, Color(GOLD, 0.35 + 0.35 * pulse), 1.8, true)
	ci.draw_circle(p + Vector2(0.0, -13.0 - 2.0 * pulse), 1.4, Color(SPARKLE, 0.8))


## The HP bar of the anthill, over its mouth.
static func _anthill_bar(ci: CanvasItem, top: Vector2, frac: float) -> void:
	var rect := Rect2(top.x - 30.0, top.y - 36.0, 60.0, 7.0)
	ViewUtil.fill_round_rect(ci, rect.grow(1.5), 4.0, Color("#3f2a19"))
	ViewUtil.fill_round_rect(ci, rect, 3.5, BAR_BACK)
	if frac > 0.0:
		var col: Color = Color("#e8eef5") if frac > 0.55 else Color("#ffb347").lerp(Color("#ff5a4a"), clampf(1.0 - frac / 0.55, 0.0, 1.0))
		ViewUtil.fill_round_rect(ci, Rect2(rect.position + Vector2(1.0, 1.0), Vector2(maxf(4.0, (rect.size.x - 2.0) * frac), rect.size.y - 2.0)), 2.5, col)

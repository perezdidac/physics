## Procedural art of the larvae of the story mode (units larva_l1 .. larva_l5): a round, cute caterpillar scaled by `unit.art_scale`.
## L1 is pale cream with long white hairs (fluffy); L2 is browner with shorter reddish hairs; L3 to L5 (the Cuca stage) are darker, longer
## (more segments) and grow tufts of orange urticating hairs along the back. No hats. Drawn in `ci` world space,
## standing on the ground below the fighter centre.
class_name LarvaArt
extends RefCounted

const SPACING: float = 6.6

## Palette per instar: body centre / body edge / dorsal stripe / head / hairs / cheek.
const LOOKS: Dictionary = {
	"L1": {"mid": "#f6ecd2", "edge": "#d9c89c", "dorsal": "#e7cf92", "head": "#efdcb2", "hair": "#ffffff", "hair_len": 4.6, "hair_w": 1.2},
	"L2": {"mid": "#c9a073", "edge": "#7f5636", "dorsal": "#5a3a22", "head": "#8a5e3c", "hair": "#e8b078", "hair_len": 3.4, "hair_w": 1.2},
	"L3": {"mid": "#a98259", "edge": "#5d3d27", "dorsal": "#33221a", "head": "#4a3326", "hair": "#e49a5e", "hair_len": 3.6, "hair_w": 1.2, "segments": 5, "spot": "#e4772c"},
	"L4": {"mid": "#8c6c4f", "edge": "#4b3223", "dorsal": "#271a12", "head": "#35251c", "hair": "#ee8a46", "hair_len": 4.0, "hair_w": 1.3, "segments": 5, "spot": "#ef7a22"},
	"L5": {"mid": "#725b4a", "edge": "#3b2a20", "dorsal": "#1d130d", "head": "#281c15", "hair": "#f58c3a", "hair_len": 4.4, "hair_w": 1.4, "segments": 6, "spot": "#f6761a"},
}


## "L1".."L5" from the unit kind (LARVA_L1 .. LARVA_L5); an unknown kind is L1.
static func instar(kind: String) -> String:
	var key: String = "L" + kind.right(1)
	return key if LOOKS.has(key) else "L1"


## Scale of the drawing: `unit.art_scale` (1 = caterpillar size).
static func scale_of(f: Variant) -> float:
	var u: Variant = ViewUtil.g(f, "unit")
	return maxf(0.3, ViewUtil.gf(u, "art_scale", 0.75)) if u != null else 0.75


static func draw(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var look: Dictionary = LOOKS[instar(ViewUtil.gs(f, "kind", "LARVA_L1"))]
	var t: float = ctx.t_now
	var team: int = ViewUtil.gi(f, "team")
	var team_col: Color = ViewColors.team(team)
	var walk: float = ctx.walk_of(f)
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 9.0)
	var s: float = scale_of(f)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var grounded: bool = ViewUtil.gb(f, "grounded", true)
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var dizzy: float = ViewUtil.gf(f, "dizzy_timer")
	var urticating: bool = ViewUtil.gi(f, "urticating_ticks") > 0
	var fx: float = ViewUtil.gf(f, "x")
	var feet := Vector2(fx, ViewUtil.gf(f, "y") + r - (4.0 if drowning else 0.0))
	var rot: float = ViewUtil.gf(f, "flip_angle")
	var vel: float = Vector2(ViewUtil.gf(f, "vx"), ViewUtil.gf(f, "vy")).length()
	if rot == 0.0 and not grounded and not drowning and vel > 210.0:
		rot = sin(t * 14.0) * 0.35
	var xf := Transform2D(rot, Vector2(facing * ViewUtil.gf(f, "squash_x", 1.0) * s, ViewUtil.gf(f, "squash_y", 1.0) * s), 0.0, feet)
	ci.draw_set_transform_matrix(xf)
	var mid: Color = ViewColors.h(look["mid"])
	var edge: Color = ViewColors.h(look["edge"])
	var dorsal: Color = ViewColors.h(look["dorsal"])
	var head_col: Color = ViewColors.h(look["head"])
	var hair: Color = ViewColors.h(look["hair"])
	if urticating:
		hair = ViewColors.BRISTLE_URTICATING
	if drowning:
		mid = mid.lerp(ViewColors.h("#7ab4d6"), 0.55)
		edge = edge.lerp(ViewColors.h("#3d6987"), 0.55)
		head_col = head_col.lerp(ViewColors.h("#6a9ab8"), 0.55)
	var segments: int = int(look.get("segments", 4))
	var moving: float = 1.0 if grounded else 0.0
	var line: Color = edge.darkened(0.45)
	# a faint silk thread under the body
	if grounded and not drowning:
		ci.draw_line(Vector2(-SPACING * segments - 4.0, 0.6), Vector2(8.0, 0.6), Color(0.96, 0.95, 0.92, 0.3), 1.4, true)
	# body segments, tail first so the head overlaps them
	for i in range(segments, 0, -1):
		var wave: float = sin(walk * 1.5 - float(i) * 0.9) * moving
		var seg_r: float = 6.2 - float(i) * 0.38
		var c := Vector2(-float(i) * SPACING + 1.0, -seg_r - 0.5 - maxf(0.0, wave) * 1.5)
		_segment(ci, c, seg_r, i, t, wave, mid, edge, dorsal, hair, line, look, team_col)
	# thorax + head
	var bob: float = sin(walk) * 1.1 * moving
	var neck := Vector2(0.0, -6.4 + bob)
	_segment(ci, neck, 6.4, 0, t, sin(walk * 1.5) * moving, mid, edge, dorsal, hair, line, look, team_col)
	_head(ci, f, Vector2(4.6, -10.6 + bob), head_col, line, hair, team_col, t, hurt, dizzy, ctx)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# dizzy stars and itch sparks above the body, unscaled by the facing flip
	if dizzy > 0.0 and not drowning:
		for k in 3:
			var a2: float = t * 6.5 + float(k) * TAU / 3.0
			ci.draw_circle(Vector2(fx + cos(a2) * 11.0, feet.y - 30.0 * s + sin(a2) * 3.5), 2.2, ViewColors.h("#ffe066") if k % 2 == 0 else Color.WHITE)
	if urticating and not drowning:
		for k in 3:
			var a: float = t * 9.0 + float(k) * 2.1
			ci.draw_line(feet + Vector2(cos(a) * 11.0, -10.0 + sin(a) * 7.0), feet + Vector2(cos(a) * 15.0, -10.0 + sin(a) * 10.0), ViewColors.BRISTLE_URTICATING, 1.4, true)


## One round furry segment: hairs behind, shaded body, dorsal stripe and a team-coloured bead.
static func _segment(ci: CanvasItem, c: Vector2, seg_r: float, idx: int, t: float, wave: float, mid: Color, edge: Color, dorsal: Color,
		hair: Color, line: Color, look: Dictionary, team_col: Color) -> void:
	var hair_len: float = float(look["hair_len"])
	var hw: float = float(look["hair_w"])
	var n: int = 9
	for b in n:
		var ba: float = -PI * 0.5 + (float(b) - float(n - 1) * 0.5) * 0.36 + sin(t * 3.0 + float(idx) + float(b)) * 0.06
		var len_b: float = seg_r + hair_len * (1.0 if b % 2 == 0 else 0.7)
		var p0: Vector2 = c + Vector2(cos(ba), sin(ba)) * (seg_r - 1.0)
		var p1: Vector2 = c + Vector2(cos(ba), sin(ba)) * len_b + Vector2(sin(t * 2.0 + float(b)) * 0.5, 0.0)
		ci.draw_line(p0, p1, hair, hw, true)
	ViewUtil.gradient_disc(ci, c, seg_r, Vector2(-1.2, -2.0), 1.0, seg_r, [[0.0, mid], [0.7, mid.lerp(edge, 0.5)], [1.0, edge]], "larva_%s_%s" % [mid.to_html(false), edge.to_html(false)])
	ci.draw_arc(c, seg_r, 0.0, TAU, 18, line, 1.2, true)
	ViewUtil.fill_ellipse(ci, c + Vector2(0.0, -seg_r * 0.45), seg_r * 0.55, seg_r * 0.26, Color(dorsal, 0.9))
	if look.has("spot") and idx > 0:
		# the orange patch of urticating hairs of the older larvae
		ViewUtil.fill_ellipse(ci, c + Vector2(0.0, -seg_r * 0.62), seg_r * 0.4, seg_r * 0.2, ViewColors.h(str(look["spot"])))
	ci.draw_circle(c + Vector2(0.0, seg_r * 0.45 + wave * 0.2), 1.1, team_col)


## Big cute head with two round eyes, blush and a tiny smile; the eyes cross out when hurt or dizzy.
static func _head(ci: CanvasItem, f: Variant, c: Vector2, head_col: Color, line: Color, hair: Color, team_col: Color, t: float, hurt: float, dizzy: float, ctx: ViewCtx) -> void:
	ViewUtil.gradient_disc(ci, c, 7.6, Vector2(-1.5, -2.0), 1.0, 8.0, [[0.0, head_col.lightened(0.18)], [0.75, head_col], [1.0, head_col.darkened(0.2)]], "larva_head_%s" % head_col.to_html(false))
	ci.draw_arc(c, 7.6, 0.0, TAU, 22, line, 1.3, true)
	# a tuft of hair on top
	for k in 3:
		var a: float = -PI * 0.5 + (float(k) - 1.0) * 0.5
		ci.draw_line(c + Vector2(cos(a), sin(a)) * 6.4, c + Vector2(cos(a), sin(a)) * 11.2 + Vector2(sin(t * 3.0 + float(k)) * 0.6, 0.0), hair, 1.2, true)
	# antennae
	var wig: float = sin(t * 7.0 + ViewUtil.gf(f, "x")) * 1.0
	ci.draw_polyline(ViewUtil.quad_pts(c + Vector2(3.0, -6.0), c + Vector2(5.0, -10.0), c + Vector2(7.6 + wig, -10.4), 6), line, 1.1, true)
	ci.draw_circle(c + Vector2(7.6 + wig, -10.4), 1.2, team_col)
	var blink: bool = fmod(t * 0.9 + float(ViewUtil.gi(f, "id")) * 1.73, 4.2) > 4.05
	var white := ViewColors.h("#fffaf0")
	var ink := ViewColors.h("#1a1412")
	var e1: Vector2 = c + Vector2(0.6, -1.0)
	var e2: Vector2 = c + Vector2(4.4, -1.0)
	if hurt > 0.2 or dizzy > 0.0:
		for e in [e1, e2]:
			var ec: Vector2 = e
			ci.draw_line(ec + Vector2(-1.3, -1.3), ec + Vector2(1.3, 1.3), ink, 1.2, true)
			ci.draw_line(ec + Vector2(1.3, -1.3), ec + Vector2(-1.3, 1.3), ink, 1.2, true)
	elif blink:
		ci.draw_line(e1 + Vector2(-1.6, 0.0), e1 + Vector2(1.6, 0.0), ink, 1.2, true)
		ci.draw_line(e2 + Vector2(-1.6, 0.0), e2 + Vector2(1.6, 0.0), ink, 1.2, true)
	else:
		ViewUtil.fill_ellipse(ci, e1, 2.5, 3.0, white)
		ViewUtil.fill_ellipse(ci, e2, 2.2, 2.7, white)
		ci.draw_circle(e1 + Vector2(0.5, 0.2), 1.5, ink)
		ci.draw_circle(e2 + Vector2(0.5, 0.2), 1.35, ink)
		ci.draw_circle(e1 + Vector2(0.0, -0.6), 0.55, Color.WHITE)
		ci.draw_circle(e2 + Vector2(0.0, -0.6), 0.5, Color.WHITE)
	# blush and smile
	ViewUtil.fill_ellipse(ci, c + Vector2(-1.2, 2.6), 1.7, 1.0, Color(1.0, 0.5, 0.5, 0.45))
	ViewUtil.fill_ellipse(ci, c + Vector2(5.4, 2.6), 1.5, 0.9, Color(1.0, 0.5, 0.5, 0.45))
	var near_danger: bool = false
	for p in ctx.projectiles:
		if ViewUtil.pos(p).distance_to(ViewUtil.pos(f)) < 90.0:
			near_danger = true
			break
	if near_danger or hurt > 0.2 or ctx.is_lost(f):
		ViewUtil.fill_ellipse(ci, c + Vector2(2.9, 4.2), 1.1, 1.3, ink)
	else:
		ci.draw_arc(c + Vector2(2.9, 2.6), 1.7, 0.2, PI - 0.2, 8, ink, 1.0, true)
	if hurt > 0.0:
		ViewUtil.fill_ellipse(ci, c, 8.0, 8.0, Color(1.0, 0.25, 0.2, clampf(hurt, 0.0, 1.0) * 0.4))

## Procedural drawing of a caterpillar fighter (port of drawFighter / drawFighterHead / drawOrugaHat, renderer.js:1298-1803):
## six furry segments, thorax, head, hat, wings, nameplate and health pill. Everything is drawn in `ci` local (world) space.
class_name CaterpillarArt
extends RefCounted

## Registry ids this view draws through (checked by the registry test).
const ART_KINDS: Array[String] = ["creature:", "creature:CATERPILLAR", "tuft_front", "convoy_marks", "weapon:held"]


## Draws one fighter. `ctx` carries the per-frame facts (time, active fighter, hats, projectiles ...).
static func draw_fighter(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var kind: String = ViewUtil.gs(f, "kind", "CATERPILLAR")
	if kind != "CATERPILLAR":
		_draw_critter(ci, f, ctx, kind)
		return
	var team: int = ViewUtil.gi(f, "team")
	var fx: float = ViewUtil.gf(f, "x")
	var fy: float = ViewUtil.gf(f, "y")
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var is_current: bool = f == ctx.active and ctx.phase != ViewCtx.PH_GAME_OVER
	var team_col: Color = ViewColors.team(team)
	# 1-4. body: segments, thorax, head, wings, sparks, stars (sprite rig, the old vector drawing while parts are missing)
	ArtRegistry.draw("creature:CATERPILLAR", ci, f, ArtContext.of(ctx))
	var root := Transform2D(0.0, Vector2.ONE, 0.0, Vector2(fx, fy))
	ci.draw_set_transform_matrix(root)

	# 5. held weapon (hidden in the touch MOVE phase, like the aim guides)
	var sliding: bool = ViewUtil.gb(f, "sliding")
	if is_current and not sliding and not drowning and ((ctx.phase == ViewCtx.PH_TURN_PLAY and ctx.aim_shown) or ctx.phase == ViewCtx.PH_RETREAT):
		ArtRegistry.draw("weapon:held", ci, {"root": root, "f": f}, ArtContext.of(ctx))
		ci.draw_set_transform_matrix(root)

	# 6. nameplate / health pill
	if not drowning:
		draw_plate(ci, f, ctx, is_current, team_col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	ArtRegistry.draw("convoy_marks", ci, f, ArtContext.of(ctx))



## The old procedural body of the fighter (segments, thorax, head, wings, sparks, stars): the vector fallback of CaterpillarSpriteArt.
static func draw_body_vector(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	var team: int = ViewUtil.gi(f, "team")
	var fx: float = ViewUtil.gf(f, "x")
	var fy: float = ViewUtil.gf(f, "y")
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var grounded: bool = ViewUtil.gb(f, "grounded", true)
	var team_col: Color = ViewColors.team(team)
	var dorsal_v: Variant = ViewUtil.g(f, "dorsal_color")
	var dorsal_col: Color = ViewColors.parse(dorsal_v, ViewColors.DORSAL_0 if team == 0 else ViewColors.DORSAL_1) if dorsal_v != null else (ViewColors.DORSAL_0 if team == 0 else ViewColors.DORSAL_1)
	var body_cols: Array[Color] = _body_colors(ViewUtil.g(f, "body_colors"))
	var urticating: bool = ViewUtil.gi(f, "urticating_ticks") > 0
	var bristle: Color = ViewColors.BRISTLE_URTICATING if urticating else ViewColors.BRISTLE
	var walk: float = ctx.walk_of(f)

	# 1. segments tail -> neck
	var segs: Variant = ViewUtil.g(f, "segs", [])
	if segs.size() > 0:
		if grounded and not drowning:
			var thread := PackedVector2Array([Vector2(fx, fy + 8.0)])
			for s in segs:
				thread.append(ViewUtil.pos(s) + Vector2(0, 5.0))
			ci.draw_polyline(thread, Color(0.9608, 0.949, 0.9216, 0.28), 1.4, true)
		for i in range(segs.size() - 1, -1, -1):
			_draw_segment(ci, ViewUtil.pos(segs[i]), i, walk, t, drowning, bristle, body_cols, dorsal_col, team_col)

	# 2. thorax + head group
	var root := Transform2D(0.0, Vector2.ONE, 0.0, Vector2(fx, fy))
	var bob: float = sin(walk) * 1.8 if grounded else 0.0
	var rot: float = 0.0
	var flip: float = ViewUtil.gf(f, "flip_angle")
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var vel: float = Vector2(ViewUtil.gf(f, "vx"), ViewUtil.gf(f, "vy")).length()
	if flip != 0.0:
		rot = flip
	elif ViewUtil.gb(f, "sliding") and grounded:
		rot = ViewUtil.gf(f, "slide_angle") + facing * 0.32
	elif not grounded and not drowning and vel > 210.0:
		rot = sin(t * 14.0) * 0.35
	var grp: Transform2D = root * Transform2D(rot, Vector2(facing * ViewUtil.gf(f, "squash_x", 1.0), ViewUtil.gf(f, "squash_y", 1.0)), 0.0, Vector2.ZERO)
	ci.draw_set_transform_matrix(grp)

	var jet: float = ViewUtil.gf(f, "jet_fuel")
	var metamorphosed: bool = ViewUtil.gb(f, "metamorphosed")
	if metamorphosed or jet > 0.0:
		var flap: float = sin(t * 32.0) * 0.38 if not grounded else sin(t * 5.0) * 0.12
		var wing_fill: Color = Color(0.9647, 0.8118, 0.4667, 0.76) if metamorphosed else ViewColors.h("#c89b52")
		ViewUtil.ellipse_fs(ci, Vector2(-8, -8), 11.0, 5.2, wing_fill, ViewColors.h("#fff5df"), 1.2, -0.45 + flap)
		ViewUtil.fill_ellipse(ci, Vector2(-10, -4), 7.5, 3.5, Color(0.9098, 0.4784, 0.1412, 0.58), -0.25 + flap * 0.8)

	for b in range(-4, 3):
		var ba: float = -PI * 0.55 + float(b) * 0.28
		ci.draw_line(Vector2(cos(ba), sin(ba)) * 6.0, Vector2(cos(ba), sin(ba)) * 13.5, bristle, 1.25, true)
	ViewUtil.ellipse_fs(ci, Vector2(-1, 1.0 + bob), 7.8, 8.2, ViewColors.THORAX, ViewColors.h("#0e1015"), 1.7)
	ViewUtil.fill_ellipse(ci, Vector2(-1, -4.0 + bob), 5.5, 2.5, team_col)
	_draw_head(ci, grp, f, ctx, bob, team_col)
	ci.draw_set_transform_matrix(root)

	# 3. itch sparks, 4. dizzy stars
	if urticating and not drowning:
		for i in 3:
			var a: float = t * 9.0 + float(i) * 2.1
			ci.draw_line(Vector2(cos(a) * 13.0, -8.0 + sin(a) * 8.0), Vector2(cos(a) * 18.0, -8.0 + sin(a) * 11.0), ViewColors.BRISTLE_URTICATING, 1.5, true)
	if ViewUtil.gf(f, "dizzy_timer") > 0.0 and not drowning:
		for i in 3:
			var a2: float = t * 6.5 + float(i) * TAU / 3.0
			ci.draw_circle(Vector2(cos(a2) * 14.0, -24.0 + sin(a2) * 4.5), 2.6, ViewColors.h("#ffe066") if i % 2 == 0 else Color.WHITE)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

## Story-mode units (egg, ant): their own art plus the shared nameplate; a hidden one is faded with needles in front.
static func _draw_critter(ci: CanvasItem, f: Variant, ctx: ViewCtx, kind: String) -> void:
	var hidden: bool = ViewUtil.gb(f, "hidden")
	var is_boss: bool = ctx.boss != null and f == ctx.boss
	if is_boss:
		BossArt.draw(ci, f, ctx)
	else:
		ArtRegistry.draw("creature:" + kind, ci, f, ArtContext.of(ctx))
	if hidden:
		ArtRegistry.draw("tuft_front", ci, {"ground": Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + ViewUtil.gf(f, "r", 10.0)), "seed": ViewUtil.gi(f, "id")}, ArtContext.of(ctx))
	ArtRegistry.draw("convoy_marks", ci, f, ArtContext.of(ctx))
	if not ViewUtil.gb(f, "drowning") and not is_boss and kind != "WILD_BOAR":
		var is_current: bool = f == ctx.active and ctx.phase != ViewCtx.PH_GAME_OVER
		draw_plate(ci, f, ctx, is_current, ViewColors.team(ViewUtil.gi(f, "team")))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## The weapon in the hands of the active larva (same as the caterpillar's), anchored at the fighter centre.
static func draw_larva_held(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var drowning: bool = ViewUtil.gb(f, "drowning")
	if f == ctx.active and not ViewUtil.gb(f, "sliding") and not drowning and ((ctx.phase == ViewCtx.PH_TURN_PLAY and ctx.aim_shown) or ctx.phase == ViewCtx.PH_RETREAT):
		var root := Transform2D(0.0, Vector2.ONE, 0.0, ViewUtil.pos(f))
		ArtRegistry.draw("weapon:held", ci, {"root": root, "f": f}, ArtContext.of(ctx))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _body_colors(v: Variant) -> Array[Color]:
	if v is Array and (v as Array).size() >= 3:
		var out: Array[Color] = []
		for i in 3:
			out.append(ViewColors.parse(v[i], ViewColors.BODY_DEFAULT[i]))
		return out
	return ViewColors.BODY_DEFAULT


static func _draw_segment(ci: CanvasItem, p: Vector2, i: int, walk: float, t: float, drowning: bool, bristle: Color,
		body_cols: Array[Color], dorsal: Color, team_col: Color) -> void:
	var seg_r: float = 6.8 - float(i) * 0.45
	var step_wave: float = sin(walk * 1.5 - float(i) * 0.9)
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, 0.0, p))
	if not drowning:
		ci.draw_circle(Vector2(-1.2, seg_r - 0.5 + maxf(0.0, step_wave * 1.4)), 1.7, ViewColors.PROLEG)
		ci.draw_circle(Vector2(1.5, seg_r - 0.5 + maxf(0.0, -step_wave * 1.4)), 1.7, ViewColors.PROLEG)
	for b in range(-3, 4):
		var ba: float = -PI * 0.5 + float(b) * 0.34 + sin(t * 6.0 + float(i) + float(b)) * 0.08
		var h_len: float = seg_r + (4.8 if b % 2 == 0 else 3.2)
		ci.draw_line(Vector2(cos(ba), sin(ba)) * (seg_r - 1.0), Vector2(cos(ba), sin(ba)) * h_len, bristle, 1.1, true)
	if drowning:
		ViewUtil.gradient_disc(ci, Vector2.ZERO, seg_r, Vector2(-1, -2), 1.0, seg_r, [[0.0, ViewColors.h("#6a9ab8")], [1.0, ViewColors.h("#263e52")]], "seg_drown")
	else:
		var key: String = "seg_%s_%s_%s" % [body_cols[0].to_html(false), body_cols[1].to_html(false), body_cols[2].to_html(false)]
		ViewUtil.gradient_disc(ci, Vector2.ZERO, seg_r, Vector2(-1, -2), 1.0, seg_r, [[0.0, body_cols[0]], [0.65, body_cols[1]], [1.0, body_cols[2]]], key)
	ci.draw_arc(Vector2.ZERO, seg_r, 0.0, TAU, 20, ViewColors.OUTLINE_DARK, 1.5, true)
	if not drowning:
		ViewUtil.fill_ellipse(ci, Vector2(0, -seg_r * 0.42), seg_r * 0.62, seg_r * 0.32, dorsal)
		ci.draw_circle(Vector2(0, 1.2), 1.3, team_col)


static func _draw_head(ci: CanvasItem, grp: Transform2D, f: Variant, ctx: ViewCtx, bob: float, team_col: Color) -> void:
	var t: float = ctx.t_now
	var head_xf: Transform2D = grp * Transform2D(0.0, Vector2.ONE, 0.0, Vector2(2.0, -8.0 + bob))
	ci.draw_set_transform_matrix(head_xf)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var face: Texture2D = ViewUtil.as_texture(ctx.face_of(f))
	if face != null:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 24:
			var a: float = TAU * float(i) / 24.0
			pts.append(Vector2(cos(a), sin(a)) * 10.5)
			uvs.append(Vector2(cos(a), sin(a)) * (10.5 / 22.0) + Vector2(0.5, 0.5))
		ci.draw_colored_polygon(pts, Color.WHITE, uvs, face)
		ci.draw_arc(Vector2.ZERO, 10.5, 0.0, TAU, 24, team_col, 2.0, true)
	else:
		if drowning:
			ViewUtil.gradient_disc(ci, Vector2.ZERO, 9.2, Vector2(0, 0), 1.0, 10.0, [[0.0, ViewColors.h("#7ab4d6")], [0.7, ViewColors.h("#3d6987")], [1.0, ViewColors.h("#1d3547")]], "head_drown")
		else:
			ViewUtil.gradient_disc(ci, Vector2.ZERO, 9.2, Vector2(0, 0), 1.0, 10.0, [[0.0, ViewColors.h("#4f5666")], [0.55, ViewColors.h("#252932")], [1.0, ViewColors.h("#0f1116")]], "head")
		ci.draw_arc(Vector2.ZERO, 9.2, 0.0, TAU, 24, ViewColors.h("#090a0d"), 1.8, true)
		ci.draw_arc(Vector2(0.5, -0.5), 7.6, -PI * 0.78, -PI * 0.18, 10, Color(1.0, 0.98, 0.92, 0.34), 1.3, true)
		var wig: float = sin(t * 8.0 + ViewUtil.gf(f, "x")) * 1.4
		var ant := ViewColors.h("#1b1e26")
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(2, -8), Vector2(5, -14), Vector2(8.0 + wig, -13)), ant, 1.5, true)
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(-2, -8), Vector2(-1, -14), Vector2(2.0 - wig, -14)), ant, 1.5, true)
		ci.draw_circle(Vector2(8.0 + wig, -13), 1.7, team_col)
		ci.draw_circle(Vector2(2.0 - wig, -14), 1.5, team_col)

		var dizzy: float = ViewUtil.gf(f, "dizzy_timer")
		var hurt: float = ViewUtil.gf(f, "hurt_timer")
		var blink: bool = fmod(t * 0.9 + float(ViewUtil.gi(f, "id")) * 1.73, 4.2) > 4.04 and dizzy <= 0.0 and hurt <= 0.0
		var fpos: Vector2 = ViewUtil.pos(f)
		var near_danger: bool = false
		for p in ctx.projectiles:
			if ViewUtil.pos(p).distance_to(fpos) < 115.0:
				near_danger = true
				break
		if not near_danger:
			for m in ctx.mines:
				if ViewUtil.gb(m, "triggered") and ViewUtil.pos(m).distance_to(fpos) < 115.0:
					near_danger = true
					break
		var squint: bool = f == ctx.active and ctx.is_charging
		var ey: float = 0.12 if blink else (1.22 if near_danger else (0.78 if squint else 1.0))
		var white := ViewColors.h("#fff8e7")
		ViewUtil.fill_ellipse(ci, Vector2(3.4, -1.2), 2.7, 3.3 * ey, white)
		ViewUtil.fill_ellipse(ci, Vector2(7.1, -1.2), 2.2, 2.8 * ey, white)
		if dizzy > 0.0 or hurt > 0.2:
			var xc := ViewColors.h("#181412")
			ci.draw_line(Vector2(2.2, -2.4), Vector2(4.6, 0.0), xc, 1.3, true)
			ci.draw_line(Vector2(4.6, -2.4), Vector2(2.2, 0.0), xc, 1.3, true)
			ci.draw_line(Vector2(6.0, -2.2), Vector2(8.2, 0.0), xc, 1.3, true)
			ci.draw_line(Vector2(8.2, -2.2), Vector2(6.0, 0.0), xc, 1.3, true)
		elif not blink:
			var pr: float = 0.82 if (ViewUtil.gb(f, "sliding") or drowning or near_danger) else 1.35
			ci.draw_circle(Vector2(4.2, -1.2), pr, ViewColors.h("#141110"))
			ci.draw_circle(Vector2(7.7, -1.2), pr * 0.85, ViewColors.h("#141110"))
			ci.draw_circle(Vector2(3.7, -2.0), 0.65, Color.WHITE)
			ci.draw_circle(Vector2(7.3, -1.9), 0.55, Color.WHITE)
			if near_danger:
				ci.draw_line(Vector2(1.0, -3.6), Vector2(8.4, -5.0), team_col, 1.6, true)
			elif squint:
				ci.draw_line(Vector2(0.8, -5.0), Vector2(8.8, -2.5), team_col, 1.6, true)
			else:
				ci.draw_line(Vector2(1.0, -4.6), Vector2(8.6, -3.2), team_col, 1.6, true)
		ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(5.5, 4.2), Vector2(8.5, 5.5), Vector2(5.0, 6.2)]), ViewColors.h("#d48a46"))
		if ViewUtil.gb(f, "has_mustache"):
			var mc := ViewColors.h("#181412")
			ci.draw_polyline(ViewUtil.quad_pts(Vector2(4.5, 3.0), Vector2(1.0, 3.5), Vector2(-1.5, 1.0), 8), mc, 1.4, true)
			ci.draw_polyline(ViewUtil.quad_pts(Vector2(5.5, 3.0), Vector2(9.0, 3.2), Vector2(10.8, 0.8), 8), mc, 1.4, true)
	var team: int = ViewUtil.gi(f, "team")
	var hat_team: String = str(ctx.team_hats[team]) if team < ctx.team_hats.size() else "CATALAN"
	var chosen: String = ViewUtil.gs(f, "individual_hat", "CATALAN") if hat_team == "VARIED" else hat_team
	draw_hat(ci, chosen)


## Hat in head space (origin = head centre).
static func draw_hat(ci: CanvasItem, hat: String) -> void:
	if hat == "CATALAN":
		ci.draw_rect(Rect2(-8, -9.5, 15, 2.8), ViewColors.h("#16181f"))
		var pts := PackedVector2Array()
		pts.append_array(ViewUtil.quad_pts(Vector2(-7.5, -9.5), Vector2(-2, -19), Vector2(-12, -14), 8))
		var tail: PackedVector2Array = ViewUtil.quad_pts(Vector2(-12, -14), Vector2(-6, -11), Vector2(6.5, -9.5), 8)
		tail.remove_at(0)
		pts.append_array(tail)
		ViewUtil.fill_poly(ci, pts, ViewColors.h("#d93228"))
		pts.append(pts[0])
		ci.draw_polyline(pts, ViewColors.h("#16181f"), 1.2, true)
	elif hat == "CASTELLER":
		var half := ViewUtil.arc_pts(Vector2(-0.5, -8.2), 8.2, PI, TAU, 14)
		ViewUtil.fill_poly(ci, half, ViewColors.h("#f5c23b"))
		var closed: PackedVector2Array = half.duplicate()
		closed.append(half[0])
		ci.draw_polyline(closed, ViewColors.h("#14161d"), 1.3, true)
		var s: float = -4.5
		while s <= 4.51:
			ci.draw_line(Vector2(s, -8.5), Vector2(s * 0.75, -15.8), ViewColors.h("#d92b22"), 1.5, true)
			s += 3.0
		ci.draw_rect(Rect2(-8.5, -9.2, 16, 2.4), ViewColors.h("#181b22"))
	elif hat == "BANDOLER":
		var crown := PackedVector2Array([Vector2(-6, -8.5), Vector2(-4, -17), Vector2(3, -17), Vector2(5, -8.5)])
		ViewUtil.fill_poly(ci, crown, ViewColors.h("#241e1a"))
		var cl: PackedVector2Array = crown.duplicate()
		cl.append(crown[0])
		ci.draw_polyline(cl, ViewColors.h("#0e0b09"), 1.2, true)
		ci.draw_rect(Rect2(-5.5, -11, 10, 2.2), ViewColors.h("#d93228"))
		ci.draw_rect(Rect2(-1, -11.3, 2.6, 2.6), ViewColors.h("#f5b945"))
		ViewUtil.ellipse_fs(ci, Vector2(-0.5, -8.5), 11.5, 2.3, ViewColors.h("#2b231e"), ViewColors.h("#0e0b09"), 1.2, -0.05)
	elif hat == "PAGES":
		var dome := ViewUtil.arc_pts(Vector2(-0.5, -8.5), 7.6, PI, TAU, 14)
		ViewUtil.fill_poly(ci, dome, ViewColors.h("#e8c168"))
		var dc: PackedVector2Array = dome.duplicate()
		dc.append(dome[0])
		ci.draw_polyline(dc, ViewColors.h("#5c3d14"), 1.2, true)
		ci.draw_rect(Rect2(-7.8, -10.5, 14.6, 2.0), ViewColors.h("#d93228"))
		ViewUtil.ellipse_fs(ci, Vector2(-0.5, -8.2), 12.2, 2.4, ViewColors.h("#f0cf7b"), ViewColors.h("#5c3d14"), 1.2, -0.04)
	else:
		for i in range(-3, 4):
			ci.draw_line(Vector2(float(i) * 1.8, -8.0), Vector2(float(i) * 2.8, -15.0 - (2.0 if i % 2 == 0 else 0.0)), ViewColors.h("#ffae42"), 1.4, true)


## Name tag / health pill above the fighter (shared by the story-mode units).
static func draw_plate(ci: CanvasItem, f: Variant, ctx: ViewCtx, is_current: bool, team_col: Color) -> void:
	var t: float = ctx.t_now
	var linked: Array = ViewUtil.g(f, "linked_allies", [])
	var castell: bool = ViewUtil.gb(f, "castell_tower")
	if castell or linked.size() > 0:
		var aura: Color = Color(1.0, 0.851, 0.4, 0.72) if castell else Color(0.9608, 0.7843, 0.4118, 0.38)
		var rad: float = 19.0 + sin(t * 6.0) * 1.5
		if castell:
			ViewUtil.dashed_circle(ci, Vector2(0, -5), rad, 4.0, 3.0, aura, 2.2)
		else:
			ci.draw_arc(Vector2(0, -5), rad, 0.0, TAU, 28, aura, 1.5, true)
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var dizzy: float = ViewUtil.gf(f, "dizzy_timer")
	var near_aim: bool = ctx.mouse_world.distance_to(ViewUtil.pos(f)) < 62.0
	var hp_frac: float = clampf(ViewUtil.gf(f, "hp") / maxf(1.0, ViewUtil.gf(f, "max_hp", 100.0)), 0.0, 1.0)
	if is_current or hurt > 0.0 or dizzy > 0.0 or near_aim:
		var label_y: float = -36.0
		var nm: String = ViewUtil.gs(f, "name")
		var tw: float = ViewUtil.text_w(nm, 12) + 18.0
		ViewUtil.fill_round_rect(ci, Rect2(-tw / 2.0, label_y - 13.0, tw, 18.0), 9.0, ViewColors.NAME_PILL)
		ViewUtil.stroke_round_rect(ci, Rect2(-tw / 2.0, label_y - 13.0, tw, 18.0), 9.0, team_col if is_current else ViewColors.NAME_PILL_BORDER, 1.6 if is_current else 1.1)
		ViewUtil.text(ci, nm, Vector2(0, label_y), 12, ViewColors.NAME_TEXT)
		var bw: float = 38.0
		var bh: float = 4.5
		ViewUtil.fill_round_rect(ci, Rect2(-bw / 2.0 - 1.0, label_y + 7.0, bw + 2.0, bh + 2.0), 3.0, ViewColors.BAR_FRAME)
		ViewUtil.fill_round_rect(ci, Rect2(-bw / 2.0, label_y + 8.0, maxf(2.0, bw * hp_frac), bh), 2.2, team_col)
		var jet: float = ViewUtil.gf(f, "jet_fuel")
		if jet > 0.0:
			ViewUtil.fill_round_rect(ci, Rect2(-bw / 2.0, label_y + 14.0, bw, 3.0), 1.5, Color(0, 0, 0, 0.75))
			ViewUtil.fill_round_rect(ci, Rect2(-bw / 2.0, label_y + 14.0, maxf(1.0, bw * jet / 100.0), 3.0), 1.5, ViewColors.FUEL_BAR)
		if is_current and ctx.phase == ViewCtx.PH_TURN_PLAY:
			var ay: float = label_y - 21.0 + sin(t * 6.0) * 3.0
			ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(0, ay + 6.0), Vector2(-5.5, ay - 2.0), Vector2(5.5, ay - 2.0)]), team_col)
	else:
		var pill_y: float = -28.0
		var pw: float = 28.0
		ViewUtil.fill_round_rect(ci, Rect2(-pw / 2.0 - 1.0, pill_y - 1.0, pw + 2.0, 6.0), 3.0, Color(0.0353, 0.0471, 0.0706, 0.72))
		ViewUtil.fill_round_rect(ci, Rect2(-pw / 2.0, pill_y, maxf(2.0, pw * hp_frac), 4.0), 2.0, team_col)

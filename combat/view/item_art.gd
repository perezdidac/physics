## Procedural drawing of the battlefield entities and decoration (port of renderer.js: flora, shadows, updrafts, silk nests and
## webs, pine nuts, larvae, rovellons, caganers, escudelles, tombstones, mines, crates, barrels, ropes and tethers).
class_name ItemArt
extends RefCounted


static func _t(ci: CanvasItem, p: Vector2, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	ci.draw_set_transform_matrix(Transform2D(rot, sc, 0.0, p))


static func _reset(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, stroke: Color, w: float) -> void:
	ViewUtil.fill_poly(ci, pts, fill)
	if w > 0.0:
		var c: PackedVector2Array = pts.duplicate()
		c.append(pts[0])
		ci.draw_polyline(c, stroke, w, true)


# ------------------------------------------------------------------ flora

## Wind-swaying surface plants of the map (drawSurfaceFlora).
static func draw_flora(ci: CanvasItem, flora: Array, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	for fl in flora:
		var phase: float = ViewUtil.gf(fl, "phase")
		var sway: float = sin(t * 2.8 + phase) * (0.08 + absf(ctx.wind) * 0.0028) + ctx.wind * 0.0035
		var sc: float = ViewUtil.gf(fl, "scale", 1.0)
		_t(ci, ViewUtil.pos(fl), sway, Vector2(sc, sc))
		var variant: int = ViewUtil.gi(fl, "variant")
		match ViewUtil.gs(fl, "type"):
			"MONTSERRAT":
				for b in range(-2, 3):
					var bx: float = float(b) * 3.2
					var bh: float = 9.0 + float(2 - absi(b)) * 3.0
					ci.draw_polyline(ViewUtil.quad_pts(Vector2(0, 1), Vector2(bx * 0.5, -bh * 0.5), Vector2(bx, -bh), 6), ViewColors.h("#3b5c34"), 1.6, true)
					ci.draw_circle(Vector2(bx, -bh), 1.6, ViewColors.h("#ffd54f") if variant == 0 else ViewColors.h("#b39ddb"))
			"CADAQUES":
				if variant == 0:
					for b in range(-2, 3):
						_t(ci, ViewUtil.pos(fl), sway + float(b) * 0.36, Vector2(sc, sc))
						var leaf := PackedVector2Array()
						leaf.append_array(ViewUtil.quad_pts(Vector2(-2, 1), Vector2(0, -13), Vector2(0, -15), 6))
						leaf.append_array(ViewUtil.quad_pts(Vector2(0, -15), Vector2(0, -13), Vector2(2, 1), 6))
						_poly(ci, leaf, ViewColors.h("#4e7a6b"), ViewColors.h("#254238"), 1.1)
				else:
					var pear := ViewColors.h("#5c8c46")
					var edge := ViewColors.h("#2b471f")
					ViewUtil.ellipse_fs(ci, Vector2(0, -5), 4.5, 5.5, pear, edge, 1.1)
					ViewUtil.ellipse_fs(ci, Vector2(-4.5, -11), 3.2, 4.2, pear, edge, 1.1, -0.35)
					ViewUtil.ellipse_fs(ci, Vector2(4.2, -10), 3.0, 3.8, pear, edge, 1.1, 0.35)
					ci.draw_circle(Vector2(-6, -15), 1.7, ViewColors.h("#ff7043"))
					ci.draw_circle(Vector2(5.5, -13.5), 1.6, ViewColors.h("#ff7043"))
			"TAULL":
				ci.draw_line(Vector2(0, 1), Vector2(0, -10), ViewColors.h("#4a6b53"), 1.5, true)
				for p in 5:
					var a: float = float(p) / 5.0 * TAU
					ViewUtil.fill_ellipse(ci, Vector2(cos(a) * 3.2, -10.0 + sin(a) * 3.2), 2.2, 1.1, ViewColors.h("#f4f9ff"), a)
				ci.draw_circle(Vector2(0, -10), 1.5, ViewColors.h("#ffe082"))
			"DELTA_EBRE":
				for b in range(-1, 2):
					var rx: float = float(b) * 3.5
					ci.draw_polyline(ViewUtil.quad_pts(Vector2(rx * 0.4, 1), Vector2(rx, -8), Vector2(rx * 1.3, -15), 6), ViewColors.h("#6c8f3f"), 1.5, true)
				ViewUtil.fill_round_rect(ci, Rect2(-1.6, -13, 3.2, 5.5), 1.5, ViewColors.h("#5c381e"))
			"TARRACO":
				for b in [-1, 1]:
					ci.draw_polyline(ViewUtil.quad_pts(Vector2(0, 1), Vector2(float(b) * 3.0, -6), Vector2(float(b) * 4.5, -11), 6), ViewColors.h("#4e7332"), 1.4, true)
					ci.draw_circle(Vector2(float(b) * 4.5, -11), 2.6, ViewColors.h("#e53935"))
					ci.draw_circle(Vector2(float(b) * 4.5, -11), 0.9, ViewColors.h("#1c1816"))
			"PEDRAFORCA":
				ci.draw_line(Vector2(0, 1), Vector2(-2, -9), ViewColors.h("#3b6952"), 1.5, true)
				ci.draw_line(Vector2(0, 1), Vector2(2.5, -10), ViewColors.h("#3b6952"), 1.5, true)
				ci.draw_circle(Vector2(-2, -9.5), 2.3, ViewColors.h("#448aff"))
				ci.draw_circle(Vector2(2.5, -10.5), 2.5, ViewColors.h("#448aff"))
			"MONTBLANC":
				ci.draw_polyline(ViewUtil.quad_pts(Vector2(0, 1), Vector2(1.5, -6), Vector2(0, -12), 6), ViewColors.h("#2e5928"), 1.6, true)
				ci.draw_circle(Vector2(0, -12.5), 3.0, ViewColors.h("#d50000"))
				ci.draw_arc(Vector2(0, -12.5), 1.4, 0.0, PI * 1.4, 8, ViewColors.h("#ff8a80"), 0.9, true)
			_:
				var col: Color = ViewColors.h("#d9531e") if variant == 0 else (ViewColors.h("#e89b2d") if variant == 1 else ViewColors.h("#6e8c3a"))
				for b in range(-1, 2):
					ci.draw_polyline(ViewUtil.quad_pts(Vector2(0, 1), Vector2(float(b) * 4.0, -6), Vector2(float(b) * 6.0, -11), 6), ViewColors.h("#4a2e18"), 1.4, true)
					ViewUtil.fill_ellipse(ci, Vector2(float(b) * 5.0, -9), 3.4, 2.0, col, float(b) * 0.4)
	_reset(ci)


# ------------------------------------------------------------------ shadows

## Sun-cast contact shadows under entities (drawGroundContactShadows).
static func draw_shadows(ci: CanvasItem, sim: Object, ctx: ViewCtx) -> void:
	var terrain: Object = ctx.terrain
	var sun_shift: float = -3.5 if (ctx.map_id == "MONTSERRAT" or ctx.map_id == "CASTELLFOLLIT") else (3.5 if ctx.map_id == "CADAQUES" else 1.0)
	for f in ctx.fighters:
		if not ViewUtil.gb(f, "alive") or ViewUtil.gb(f, "drowning"):
			continue
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + ViewUtil.gf(f, "r", 12.0), 12.5, 3.8, 0.44)
		var segs: Variant = ViewUtil.g(f, "segs", [])
		var i: int = 0
		while i < segs.size():
			_shadow(ci, terrain, ctx, sun_shift, ViewUtil.pos(segs[i]).x, ViewUtil.pos(segs[i]).y + 5.0, 7.5 - float(i) * 0.5, 2.5, 0.32)
			i += 2
	for b in ViewUtil.g(sim, "barrels", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(b, "x"), ViewUtil.gf(b, "y") + ViewUtil.gf(b, "r", 14.0), 14.0, 4.2, 0.48)
	for c in ViewUtil.g(sim, "crates", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(c, "x"), ViewUtil.gf(c, "y") + 10.0, 12.0, 3.6, 0.45)
	for m in ViewUtil.g(sim, "mines", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(m, "x"), ViewUtil.gf(m, "y") + 4.0, 9.0, 2.8, 0.42)
	for rv in ViewUtil.g(sim, "rovellons", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(rv, "x"), ViewUtil.gf(rv, "y"), ViewUtil.gf(rv, "r", 18.0) * 0.9, 3.8, 0.44)
	for cg in ViewUtil.g(sim, "caganers", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(cg, "x"), ViewUtil.gf(cg, "y") + 7.0, 10.0, 3.2, 0.44)
	for tb in ViewUtil.g(sim, "tombstones", []):
		_shadow(ci, terrain, ctx, sun_shift, ViewUtil.gf(tb, "x"), ViewUtil.gf(tb, "y") + 10.0, 11.0, 3.4, 0.46)


static func _shadow(ci: CanvasItem, terrain: Object, ctx: ViewCtx, sun_shift: float, x: float, y: float, rx: float, ry: float, alpha: float) -> void:
	if terrain == null or not terrain.has_method("find_surface_y"):
		return
	var sy: float = float(terrain.call("find_surface_y", x, y - 4.0))
	var dist: float = sy - y
	if dist < -6.0 or dist > 54.0 or sy >= ctx.water_y:
		return
	var falloff: float = clampf(1.0 - maxf(0.0, dist) / 54.0, 0.15, 1.0)
	ViewUtil.fill_ellipse(ci, Vector2(x + sun_shift * (0.4 + (1.0 - falloff) * 0.8), sy + 1.0), rx * (0.7 + falloff * 0.35), ry, Color(ViewColors.SHADOW, alpha * falloff), 0.0)


# ------------------------------------------------------------------ updrafts, nests, webs, nuts, larvae

static func draw_updraft(ci: CanvasItem, u: Variant, t: float) -> void:
	var ux: float = ViewUtil.gf(u, "x")
	var uy: float = ViewUtil.gf(u, "y")
	var uw: float = ViewUtil.gf(u, "w", 42.0)
	var uh: float = ViewUtil.gf(u, "h", 230.0)
	var x0: float = ux - uw * 0.7
	var x1: float = ux + uw * 0.7
	var c0 := Color(0.9647, 0.8118, 0.4667, 0.22)
	var c1 := Color(0.7059, 0.9216, 1.0, 0.12)
	var c2 := Color(0.7059, 0.9216, 1.0, 0.0)
	ViewUtil.vgrad_rect(ci, x0, x1, uy - uh, uy, [[0.0, c2], [0.4, c1], [1.0, c0]])
	for s in range(-1, 2):
		var flow: float = fmod(t * 95.0 + float(s + 1) * 65.0, uh)
		var sx: float = ux + float(s) * 11.0 + sin(t * 5.0 + float(s)) * 4.0
		var sy: float = uy - flow
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(sx, sy), Vector2(sx + 4.0, sy - 14.0), Vector2(sx - 2.0, sy - 28.0), 6), Color(1.0, 0.9216, 0.6863, 0.36), 1.4, true)


static func draw_nest(ci: CanvasItem, nest: Variant, t: float) -> void:
	var p: Vector2 = ViewUtil.pos(nest)
	ci.draw_line(Vector2(ViewUtil.gf(nest, "anchor_x"), ViewUtil.gf(nest, "anchor_y")), p, Color(0.9608, 0.9412, 0.902, 0.78), 1.8, true)
	var sway: float = ViewUtil.gf(nest, "sway_phase")
	var pulse: float = 1.0 + sin(t * 5.0 + sway) * 0.05
	_t(ci, p, 0.0, Vector2(pulse, pulse))
	var r: float = ViewUtil.gf(nest, "r", 13.0)
	ViewUtil.radial(ci, Vector2.ZERO, 2.0, r * 1.6, [[0.0, Color(1.0, 0.9216, 0.6863, 0.65)], [1.0, Color(1.0, 0.9216, 0.6863, 0.0)]], 1.0, "nest_glow")
	ViewUtil.ellipse_fs(ci, Vector2.ZERO, r * 1.1, r * 0.85, ViewColors.h("#f5f0e6"), ViewColors.h("#d4a153"), 1.6)
	for w in [-1, 1]:
		var wx: float = float(w) * 3.5 + sin(t * 7.0 + float(w) + sway) * 2.2
		var wy: float = float(w) * 1.8 + cos(t * 6.0 + float(w)) * 1.5
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(wx - 3.5, wy), Vector2(wx, wy - 2.5), Vector2(wx + 3.5, wy + 0.5), 6), Color(0.2549, 0.2039, 0.1647, 0.42), 2.1, true)
	var web := Color(0.7059, 0.6471, 0.5686, 0.55)
	ci.draw_line(Vector2(-8, -4), Vector2(9, 3), web, 1.0, true)
	ci.draw_line(Vector2(-7, 4), Vector2(8, -4), web, 1.0, true)
	_reset(ci)


static func draw_web(ci: CanvasItem, w: Variant, t: float) -> void:
	var p1 := Vector2(ViewUtil.gf(w, "x1"), ViewUtil.gf(w, "y1"))
	var p2 := Vector2(ViewUtil.gf(w, "x2"), ViewUtil.gf(w, "y2"))
	var mid: Vector2 = (p1 + p2) * 0.5
	var d: Vector2 = p2 - p1
	var ln: float = maxf(1.0, d.length())
	var n := Vector2(-d.y / ln, d.x / ln)
	var vib: float = sin(t * 42.0) * ViewUtil.gf(w, "vibration") * 9.0
	ci.draw_circle(p1, 3.5, ViewColors.h("#fff6df"))
	ci.draw_circle(p2, 3.5, ViewColors.h("#fff6df"))
	for s in range(-1, 2):
		var col: Color = Color(1.0, 0.9725, 0.8824, 0.95) if s == 0 else Color(0.9608, 0.7255, 0.2706, 0.55)
		ci.draw_polyline(ViewUtil.quad_pts(p1, mid + n * (vib + float(s) * 4.0), p2, 12), col, 2.6 if s == 0 else 1.3, true)


static func draw_pine_nut(ci: CanvasItem, pn: Variant, t: float) -> void:
	var p: Vector2 = ViewUtil.pos(pn)
	ViewUtil.radial(ci, p, 1.0, 11.0, [[0.0, Color(1.0, 0.8824, 0.451, 0.85)], [1.0, Color(1.0, 0.7451, 0.2353, 0.0)]], 1.0, "nut_glow")
	ViewUtil.ellipse_fs(ci, p, 5.5, 3.8, ViewColors.h("#f6cf77"), ViewColors.h("#6e471b"), 1.4, sin(t * 4.0) * 0.3)


static func draw_larvae(ci: CanvasItem, sw: Variant, t: float) -> void:
	var p: Vector2 = ViewUtil.pos(sw)
	for k in 4:
		var lx: float = cos(t * 12.0 + float(k) * 1.6) * 7.0
		var ly: float = sin(t * 15.0 + float(k) * 2.1) * 4.0
		ViewUtil.ellipse_fs(ci, p + Vector2(lx, ly), 4.2, 2.2, ViewColors.h("#252934"), ViewColors.h("#ffae42"), 1.0)


# ------------------------------------------------------------------ props

static func draw_rovello(ci: CanvasItem, rv: Variant) -> void:
	var r: float = ViewUtil.gf(rv, "r", 18.0)
	var sq: float = ViewUtil.gf(rv, "squash", 1.0)
	_t(ci, ViewUtil.pos(rv), 0.0, Vector2(2.0 - sq, sq))
	ViewUtil.radial(ci, Vector2(0, -10), 2.0, r * 1.5, [[0.0, Color(1.0, 0.647, 0.2941, 0.38)], [1.0, Color(1.0, 0.549, 0.1765, 0.0)]], 1.0, "rov_glow")
	var edge := ViewColors.h("#5c3118")
	ViewUtil.round_rect_fs(ci, Rect2(-5.5, -13, 11, 15), 3.0, ViewColors.h("#f2d8bd"), edge, 1.5)
	var cap := PackedVector2Array()
	cap.append_array(ViewUtil.bezier_pts(Vector2(-r, -11), Vector2(-r * 0.85, -23), Vector2(-4, -18), Vector2(0, -16), 10))
	cap.append_array(ViewUtil.bezier_pts(Vector2(0, -16), Vector2(4, -18), Vector2(r * 0.85, -23), Vector2(r, -11), 10))
	cap.append_array(ViewUtil.quad_pts(Vector2(r, -11), Vector2(0, -7), Vector2(-r, -11), 10))
	# cap gradient: 3 horizontal bands approximating the vertical linear gradient
	var cols := PackedColorArray()
	for p in cap:
		var tt: float = clampf((p.y + 22.0) / 13.0, 0.0, 1.0)
		cols.append(ViewColors.h("#ff8833").lerp(ViewColors.h("#d9531e"), clampf(tt / 0.6, 0.0, 1.0)).lerp(ViewColors.h("#8c2d10"), clampf((tt - 0.6) / 0.4, 0.0, 1.0)))
	ci.draw_polygon(cap, cols)
	var cl: PackedVector2Array = cap.duplicate()
	cl.append(cap[0])
	ci.draw_polyline(cl, edge, 1.5, true)
	ci.draw_arc(Vector2(0, -13), r * 0.58, PI * 1.1, PI * 1.9, 10, Color(1.0, 0.8431, 0.6471, 0.55), 1.1, true)
	ci.draw_circle(Vector2(-r * 0.45, -14), 1.8, ViewColors.h("#4e8c45"))
	ci.draw_circle(Vector2(r * 0.38, -13), 1.5, ViewColors.h("#4e8c45"))
	_reset(ci)


static func draw_caganer(ci: CanvasItem, cg: Variant, t: float) -> void:
	var bob: float = sin(t * 3.5 + ViewUtil.gf(cg, "bob_phase")) * 1.5
	_t(ci, ViewUtil.pos(cg) + Vector2(0, bob))
	ViewUtil.radial(ci, Vector2(0, -4), 2.0, 20.0, [[0.0, Color(1.0, 0.8784, 0.4, 0.72)], [1.0, Color(1.0, 0.7647, 0.1961, 0.0)]], 1.0, "cag_glow")
	ViewUtil.ellipse_fs(ci, Vector2(-6, 5), 3.8, 2.2, ViewColors.h("#6e421c"), ViewColors.h("#ffd966"), 0.9)
	ViewUtil.fill_ellipse(ci, Vector2(-1, 3), 5.5, 3.8, ViewColors.h("#1d2028"))
	ci.draw_rect(Rect2(-4.5, -1, 8, 2.5), ViewColors.h("#d93226"))
	var edge := ViewColors.h("#241a14")
	ViewUtil.round_rect_fs(ci, Rect2(-4.5, -7, 8.5, 6.5), 2.5, ViewColors.h("#f7f3e8"), edge, 1.2)
	ViewUtil.circle_fs(ci, Vector2(0.5, -10.5), 4.2, ViewColors.h("#f2c199"), edge, 1.2)
	ci.draw_rect(Rect2(-3.5, -14, 8, 2), ViewColors.h("#181a20"))
	_poly(ci, PackedVector2Array([Vector2(-3.5, -14), Vector2(1, -20), Vector2(6.5, -16), Vector2(4.5, -14)]), ViewColors.h("#e02f24"), edge, 1.2)
	_reset(ci)


static func draw_escudella(ci: CanvasItem, ol: Variant, t: float) -> void:
	var sp: float = ViewUtil.gf(ol, "steam_phase")
	_t(ci, ViewUtil.pos(ol))
	ViewUtil.fill_ellipse(ci, Vector2(0, 11), 11.0, 3.2, ViewColors.h("#ff7b29") if sin(t * 9.0 + sp) > 0.0 else ViewColors.h("#e03e1a"))
	var pot := ViewUtil.arc_pts(Vector2(0, 1), 13.0, 0.0, PI, 14)
	pot.append(Vector2(-11, -6))
	pot.append(Vector2(11, -6))
	var edge := ViewColors.h("#0e1014")
	_poly(ci, pot, ViewColors.h("#23262e"), edge, 1.6)
	ci.draw_polyline(ViewUtil.arc_pts(Vector2(-12, -2), 3.2, PI * 0.5, PI * 1.5, 8), ViewColors.h("#3a3f4b"), 1.8, true)
	ci.draw_polyline(ViewUtil.arc_pts(Vector2(12, -2), 3.2, -PI * 0.5, PI * 0.5, 8), ViewColors.h("#3a3f4b"), 1.8, true)
	ViewUtil.ellipse_fs(ci, Vector2(0, -6), 10.5, 3.5, ViewColors.h("#f2b949"), edge, 1.6)
	var bob: float = sin(t * 4.5 + sp) * 1.1
	ViewUtil.ellipse_fs(ci, Vector2(-2, -7.2 + bob), 5.2, 3.6, ViewColors.h("#a86438"), ViewColors.h("#4a2810"), 1.1, -0.1)
	ci.draw_circle(Vector2(4.5, -6.5 - bob * 0.6), 2.8, ViewColors.h("#fff5df"))
	_reset(ci)


static func draw_tombstone(ci: CanvasItem, tb: Variant) -> void:
	_t(ci, ViewUtil.pos(tb))
	var body := PackedVector2Array([Vector2(-9, 10), Vector2(-9, -4)])
	body.append_array(ViewUtil.arc_pts(Vector2(0, -4), 9.0, PI, TAU, 12))
	body.append(Vector2(9, 10))
	var cols := PackedColorArray()
	for p in body:
		var tt: float = clampf(((p.x + 9.0) * 0.5 + (p.y + 13.0) * 0.5) / 23.0, 0.0, 1.0)
		cols.append(ViewColors.h("#888590").lerp(ViewColors.h("#6c6a72"), clampf(tt / 0.5, 0.0, 1.0)).lerp(ViewColors.h("#49474f"), clampf((tt - 0.5) / 0.5, 0.0, 1.0)))
	ci.draw_polygon(body, cols)
	var bl: PackedVector2Array = body.duplicate()
	bl.append(body[0])
	ci.draw_polyline(bl, ViewColors.h("#222026"), 1.8, true)
	ViewUtil.fill_poly(ci, ViewUtil.arc_pts(Vector2(-6, 9.5), 2.4, PI, TAU, 6), ViewColors.h("#4e7c3e"))
	ViewUtil.fill_poly(ci, ViewUtil.arc_pts(Vector2(5, 9.5), 2.8, PI, TAU, 6), ViewColors.h("#4e7c3e"))
	var cross := ViewColors.h("#3b3940")
	ci.draw_line(Vector2(0, -9), Vector2(0, 1), cross, 1.5, true)
	ci.draw_line(Vector2(-3.5, -5.5), Vector2(3.5, -5.5), cross, 1.5, true)
	var nm: String = ViewUtil.gs(tb, "name")
	if nm != "":
		ViewUtil.text(ci, nm.substr(0, 7).to_upper(), Vector2(0, 6.8), 6, ViewColors.h("#e2dfd7"))
	var hat: Color = ViewColors.h("#d93228") if ViewUtil.gi(tb, "team") != 1 else ViewColors.h("#3b82f6")
	var cap := PackedVector2Array()
	cap.append_array(ViewUtil.quad_pts(Vector2(-5, -11.5), Vector2(0, -18), Vector2(7, -14), 6))
	cap.append_array(ViewUtil.quad_pts(Vector2(7, -14), Vector2(3, -11), Vector2(4, -11.5), 4))
	_poly(ci, cap, hat, ViewColors.h("#18161b"), 1.0)
	_reset(ci)


static func draw_mine(ci: CanvasItem, m: Variant, t: float) -> void:
	_t(ci, ViewUtil.pos(m))
	ViewUtil.ellipse_fs(ci, Vector2(0, 1), 8.0, 4.5, ViewColors.h("#3b424c"), ViewColors.h("#14161a"), 1.6)
	var on: bool = (sin(t * 32.0) > 0.0) if ViewUtil.gb(m, "triggered") else (sin(t * 3.0) > 0.7)
	ci.draw_circle(Vector2(0, -2.5), 2.6, ViewColors.h("#ff3b30") if on else ViewColors.h("#6e1c18"))
	_reset(ci)


static func draw_crate(ci: CanvasItem, c: Variant, t: float) -> void:
	var med: bool = ViewUtil.gb(c, "is_medkit")
	_t(ci, ViewUtil.pos(c))
	if ViewUtil.gb(c, "parachuting"):
		var sway: float = sin(t * 3.5 + ViewUtil.gf(c, "x") * 0.05) * 0.16
		_t(ci, ViewUtil.pos(c), sway)
		var rope := Color(0.9373, 0.9098, 0.8549, 0.65)
		ci.draw_line(Vector2(-8, -8), Vector2(-18, -28), rope, 1.2, true)
		ci.draw_line(Vector2(8, -8), Vector2(18, -28), rope, 1.2, true)
		ci.draw_line(Vector2(0, -8), Vector2(0, -30), rope, 1.2, true)
		var dome: PackedVector2Array = ViewUtil.arc_pts(Vector2(0, -26), 19.0, PI, TAU, 14)
		_poly(ci, dome, ViewColors.h("#d9483b") if med else ViewColors.h("#d99b43"), ViewColors.h("#181a20"), 1.6)
		_t(ci, ViewUtil.pos(c))
	ViewUtil.rect_fs(ci, Rect2(-10, -10, 20, 20), ViewColors.h("#e8e4dc") if med else ViewColors.h("#7a5434"), ViewColors.h("#1b1612"), 1.8)
	if med:
		ci.draw_rect(Rect2(-2.5, -6.5, 5, 13), ViewColors.h("#d93829"))
		ci.draw_rect(Rect2(-6.5, -2.5, 13, 5), ViewColors.h("#d93829"))
	else:
		ci.draw_rect(Rect2(-7, -7, 14, 14), ViewColors.h("#c89b52"), false, 1.8)
		ci.draw_line(Vector2(-7, -7), Vector2(7, 7), ViewColors.h("#c89b52"), 1.8, true)
	_reset(ci)


static func draw_barrel(ci: CanvasItem, b: Variant) -> void:
	var r: float = ViewUtil.gf(b, "r", 14.0)
	_t(ci, ViewUtil.pos(b))
	var rect := Rect2(-r * 0.85, -r, r * 1.7, r * 2.0)
	var pts: PackedVector2Array = ViewUtil.round_rect_pts(rect, 3.0)
	var cols := PackedColorArray()
	for p in pts:
		var tt: float = clampf((p.x + r) / (2.0 * r), 0.0, 1.0)
		cols.append(ViewColors.h("#591c15").lerp(ViewColors.h("#a63427"), clampf(tt / 0.4, 0.0, 1.0)).lerp(ViewColors.h("#3b110c"), clampf((tt - 0.4) / 0.6, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	ViewUtil.stroke_round_rect(ci, rect, 3.0, ViewColors.h("#1a1210"), 1.8)
	var band := ViewColors.h("#2d3138")
	ci.draw_line(Vector2(-r * 0.85, -r * 0.4), Vector2(r * 0.85, -r * 0.4), band, 2.5, true)
	ci.draw_line(Vector2(-r * 0.85, r * 0.4), Vector2(r * 0.85, r * 0.4), band, 2.5, true)
	ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0)]), ViewColors.h("#f3c66f"))
	_reset(ci)


# ------------------------------------------------------------------ ropes and tethers

static func draw_grapple(ci: CanvasItem, f: Variant) -> void:
	var g: Variant = ViewUtil.g(f, "grapple")
	if not (g is Dictionary) or (g as Dictionary).is_empty() or not ViewUtil.gb(f, "alive"):
		return
	var hook := Vector2(ViewUtil.gf(g, "hook_x"), ViewUtil.gf(g, "hook_y"))
	ci.draw_line(Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") - 4.0), hook, ViewColors.h("#d9b372"), 2.6, true)
	ci.draw_polyline(ViewUtil.arc_pts(hook, 6.0, 0.0, PI * 1.35, 12), ViewColors.h("#e2e8f0"), 3.0, true)


static func draw_tethers(ci: CanvasItem, fighters: Array) -> void:
	for f in fighters:
		if not ViewUtil.gb(f, "alive") or ViewUtil.gb(f, "drowning"):
			continue
		for ally in ViewUtil.g(f, "linked_allies", []):
			if ViewUtil.gi(f, "member_idx") < ViewUtil.gi(ally, "member_idx"):
				var col: Color = Color(0.9608, 0.7255, 0.2706, 0.78) if ViewUtil.gi(f, "team") == 0 else Color(0.9176, 0.3373, 0.2824, 0.78)
				var a := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + 2.0)
				var b := Vector2(ViewUtil.gf(ally, "x"), ViewUtil.gf(ally, "y") + 2.0)
				var ctrl := Vector2((a.x + b.x) * 0.5, minf(ViewUtil.gf(f, "y"), ViewUtil.gf(ally, "y")) - 6.0)
				ViewUtil.dashed(ci, ViewUtil.quad_pts(a, ctrl, b, 14), 5.0, 3.0, col, 2.4)

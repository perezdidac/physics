## Screen-space backdrop and overlays of the battle: sky gradient, parallax background JPG, mountain ridges, sun, god rays,
## cloud veil, birds, clouds, weather and vignette (port of render() steps 1-3, 5-7 and the drawSky*/Weather helpers).
## Drawn in logical viewport pixels; the world plane is positioned separately by CombatView.
class_name SkyPainter
extends RefCounted

const TERRAIN_W: float = 3200.0

var view: Vector2 = Vector2(1280, 720)
var scale_px: float = 1.0
var cx: float = 1600.0
var cy: float = 400.0
var smooth_mouse: Vector2 = Vector2.ZERO
var atmo: ViewAtmosphere = null
var ctx: ViewCtx = null
var facts: Dictionary = {}
var bg_tex: Texture2D = null
var veil_mat: ShaderMaterial = null
var splash: bool = false
var projectiles_offscreen: bool = true


func _dx() -> float:
	return cx - TERRAIN_W * 0.5


func _dy() -> float:
	return cy - 400.0


func _sun_rgb() -> Color:
	var id: String = atmo.map_id
	var warm: bool = id in ["MONTSERRAT", "CASTELLFOLLIT", "DELTA_EBRE", "MONTBLANC", "TARRACO"]
	if id == "DELTA_EBRE":
		return Color8(255, 175, 135)
	if id == "MONTBLANC":
		return Color8(255, 165, 105)
	if id == "PEDRAFORCA":
		return Color8(215, 210, 255)
	if warm:
		return Color8(255, 205, 115)
	if id == "CADAQUES":
		return Color8(255, 232, 165)
	return Color8(210, 235, 255)


## Sky gradient, background image, ridges and the sun glow.
func draw_base(ci: CanvasItem) -> void:
	var W: float = view.x
	var H: float = view.y
	var pal: Array[Color] = atmo.palette
	ViewUtil.vgrad_rect(ci, 0.0, W, 0.0, H, [[0.0, pal[0]], [0.32, pal[1]], [0.64, pal[2]], [0.86, pal[3]], [1.0, pal[4]]])
	if bg_tex != null:
		var aspect: float = float(bg_tex.get_width()) / float(bg_tex.get_height())
		var dw: float = W * 1.28
		var dh: float = dw / aspect
		if dh < H * 1.22:
			dh = H * 1.22
			dw = dh * aspect
		var par_x: float = -_dx() * 0.14 * scale_px - smooth_mouse.x * 1.6
		var par_y: float = -_dy() * 0.16 * scale_px - smooth_mouse.y * 1.3
		var bx: float = (W - dw) * 0.5 + clampf(par_x, -(dw - W) * 0.48, (dw - W) * 0.48)
		var by: float = (H - dh) * 0.5 + clampf(par_y, -(dh - H) * 0.48, (dh - H) * 0.48)
		ci.draw_texture_rect(bg_tex, Rect2(bx, by, dw, dh), false)
		ViewUtil.vgrad_rect(ci, 0.0, W, 0.0, H, [[0.0, Color(0.0314, 0.0392, 0.0588, 0.12)], [0.65, Color(0.0392, 0.0549, 0.0784, 0.08)], [1.0, Color(0.0235, 0.0392, 0.0627, 0.38)]])
	_draw_ridge(ci, atmo.ridge_far, 0.065, 0.08, 0.8, H * 0.25, Color(pal[1], 0x44 / 255.0), Color(0.0392, 0.0549, 0.0863, 0.34))
	_draw_ridge(ci, atmo.ridge_near, 0.115, 0.13, 1.3, H * 0.38, Color(pal[0], 0x52 / 255.0), Color(0.0314, 0.0392, 0.0627, 0.42))
	var sun_k: float = 0.62
	match atmo.map_id:
		"MONTSERRAT", "DELTA_EBRE":
			sun_k = 0.68
		"CADAQUES", "TARRACO":
			sun_k = 0.30
		"TAULL", "PEDRAFORCA":
			sun_k = 0.44
	var sx: float = W * sun_k - _dx() * 0.04 * scale_px
	var sy: float = H * 0.19 - _dy() * 0.04 * scale_px
	var sc: Color = _sun_rgb()
	ViewUtil.radial(ci, Vector2(sx, sy), 8.0 * scale_px, 340.0 * scale_px, [[0.0, Color(sc, 0.42)], [0.35, Color(sc, 0.16)], [1.0, Color(sc, 0.0)]], 1.0, "sun_" + sc.to_html(false))


func _draw_ridge(ci: CanvasItem, ridge: PackedFloat32Array, fx: float, fy: float, mouse_k: float, y0: float, top: Color, bot: Color) -> void:
	if ridge.size() < 2:
		return
	var W: float = view.x
	var H: float = view.y
	var span: float = W * 1.48
	var par_x: float = -_dx() * fx * scale_px - smooth_mouse.x * mouse_k
	var par_y: float = -_dy() * fy * scale_px
	var start: float = (W - span) * 0.5 + clampf(par_x, -(span - W) * 0.48, (span - W) * 0.48)
	var pts := PackedVector2Array([Vector2(start, H)])
	var cols := PackedColorArray([bot])
	for i in ridge.size():
		var px: float = start + float(i) / float(ridge.size() - 1) * span
		var py: float = H * ridge[i] + par_y
		pts.append(Vector2(px, py))
		cols.append(top.lerp(bot, clampf((py - y0) / maxf(1.0, H - y0), 0.0, 1.0)))
	pts.append(Vector2(start + span, H))
	cols.append(bot)
	ci.draw_polygon(pts, cols)


## God rays (additive).
func draw_rays(ci: CanvasItem) -> void:
	var W: float = view.x
	var H: float = view.y
	var sun_k: float = 0.62
	match atmo.map_id:
		"MONTSERRAT", "DELTA_EBRE":
			sun_k = 0.68
		"CADAQUES", "TARRACO":
			sun_k = 0.30
		"TAULL", "PEDRAFORCA":
			sun_k = 0.44
	var sx: float = W * sun_k - _dx() * 0.04 * scale_px
	var sy: float = H * 0.19 - _dy() * 0.04 * scale_px
	var sc: Color = _sun_rgb()
	for r in 5:
		var phase: float = ctx.t_now * 0.28 + float(r) * 1.35
		var alpha: float = (0.045 + sin(phase) * 0.02) * (0.78 if atmo.map_id == "TAULL" else 1.0)
		var rx: float = sx + float(r - 2) * 140.0 * scale_px
		var spread: float = (65.0 + float(r % 2) * 35.0) * scale_px
		var slant: float = (ctx.wind * 0.9 + (float(r) - 1.5) * 55.0) * scale_px
		var pts := PackedVector2Array([Vector2(rx - spread * 0.35, sy), Vector2(rx + spread * 0.35, sy), Vector2(rx + slant + spread * 1.5, H * 0.92), Vector2(rx + slant - spread * 1.5, H * 0.92)])
		var c_top := Color(sc, alpha * 1.4)
		var c_bot := Color(sc, 0.0)
		ci.draw_polygon(pts, PackedColorArray([c_top, c_top, c_bot, c_bot]))


## Cloud veil (shader on a screen band).
func draw_veil(ci: CanvasItem) -> void:
	if veil_mat == null:
		return
	var s: float = scale_px
	var cw: float = maxf(400.0, 1600.0 * s)
	var ch: float = 320.0 * s
	var drift: float = fmod(ctx.t_now * (10.0 + ctx.wind * 0.25), 1600.0)
	var base_ox: float = -fmod((_dx() * 0.14 - drift) * s, cw)
	var oy: float = (view.y * 0.14 if atmo.map_id == "MONTSERRAT" else view.y * 0.04) - _dy() * 0.10 * s
	veil_mat.set_shader_parameter("tile_w", cw)
	veil_mat.set_shader_parameter("tile_h", ch)
	veil_mat.set_shader_parameter("base_ox", base_ox)
	veil_mat.set_shader_parameter("top_y", oy)
	veil_mat.set_shader_parameter("veil_alpha", 0.30 if atmo.map_id == "TAULL" else 0.16)
	ci.draw_rect(Rect2(0.0, oy, view.x, ch), Color.WHITE)


## Birds and the cloud flock.
func draw_clouds(ci: CanvasItem) -> void:
	var W: float = view.x
	var H: float = view.y
	var s: float = scale_px
	var t: float = ctx.t_now
	var bird_col: Color = Color(0.1647, 0.102, 0.0863, 0.58) if (atmo.map_id == "MONTSERRAT" or atmo.map_id == "CASTELLFOLLIT") else Color(0.1098, 0.149, 0.1882, 0.55)
	for b in atmo.birds:
		var bx: float = W * 0.5 + (float(b["x"]) - TERRAIN_W * 0.5 - _dx() * float(b["z"])) * s
		var by: float = H * 0.5 + (float(b["y"]) - 400.0 - _dy() * float(b["z"]) + sin(t * 2.5 + float(b["wing_phase"])) * 6.0) * s
		if bx < -60.0 or bx > W + 60.0:
			continue
		var flap: float = sin(t * 8.5 + float(b["wing_phase"])) * float(b["size"]) * 0.65 * s
		var span: float = float(b["size"]) * s
		var pts := PackedVector2Array()
		pts.append_array(ViewUtil.quad_pts(Vector2(bx - span, by - flap), Vector2(bx - span * 0.4, by - span * 0.35), Vector2(bx, by), 6))
		pts.append_array(ViewUtil.quad_pts(Vector2(bx, by), Vector2(bx + span * 0.4, by - span * 0.35), Vector2(bx + span, by - flap), 6))
		ci.draw_polyline(pts, bird_col, 1.6 * s, true)
	var rim: Color
	var mid: Color
	match atmo.map_id:
		"DELTA_EBRE":
			rim = ViewColors.h("#ffe5dc")
			mid = ViewColors.h("#f2b6b0")
		"MONTBLANC":
			rim = ViewColors.h("#ffe0c8")
			mid = ViewColors.h("#de9e8b")
		"PEDRAFORCA":
			rim = ViewColors.h("#eee8ff")
			mid = ViewColors.h("#c8bfe8")
		"MONTSERRAT", "CASTELLFOLLIT", "TARRACO":
			rim = ViewColors.h("#fff0d4")
			mid = ViewColors.h("#f0cbb0")
		"CADAQUES":
			rim = ViewColors.h("#fff9eb")
			mid = ViewColors.h("#dce6f0")
		_:
			rim = ViewColors.h("#ebf5ff")
			mid = ViewColors.h("#c4d6e8")
	var shade: Color = Color(0.3843, 0.251, 0.3294, 0.42) if atmo.map_id in ["MONTSERRAT", "CASTELLFOLLIT", "DELTA_EBRE", "MONTBLANC"] else Color(0.251, 0.3137, 0.4235, 0.42)
	var shear: float = clampf(ctx.wind * 0.0018, -0.18, 0.18)
	for c in atmo.clouds:
		var z: float = float(c["z"])
		var cxs: float = W * 0.5 + (float(c["x"]) - TERRAIN_W * 0.5 - _dx() * z) * s
		var bob: float = sin(t * 0.9 + float(c["bob_phase"])) * 4.0
		var cys: float = H * 0.5 + (float(c["y"]) + bob - 400.0 - _dy() * z) * s
		if cxs < -320.0 * s or cxs > W + 320.0 * s:
			continue
		var tier: int = int(c["tier"])
		var ga: float = 0.26 if tier == 0 else (0.36 if tier == 1 else 0.22)
		ci.draw_set_transform_matrix(Transform2D(Vector2(s, 0.0), Vector2(shear * s, s), Vector2(cxs, cys)))
		var passes: Array = c["passes"]
		var cols: Array[Color] = [Color(shade, shade.a * ga), Color(mid, ga), Color(rim, ga)]
		for pi in 3:
			for poly in passes[pi]:
				ci.draw_colored_polygon(poly, cols[pi])
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Wind ribbons and weather particles.
func draw_weather(ci: CanvasItem) -> void:
	var W: float = view.x
	var H: float = view.y
	var s: float = scale_px
	var t: float = ctx.t_now
	var wind: float = ctx.wind
	var wm: float = absf(wind)
	if wm > 4.0:
		var dir: float = 1.0 if wind >= 0.0 else -1.0
		var rc: Color = Color(1.0, 0.8863, 0.6078) if wind >= 0.0 else Color(0.6471, 0.8941, 1.0)
		for r in atmo.ribbons:
			var rz: float = float(r["z"])
			var sx: float = W * 0.5 + (float(r["x"]) - TERRAIN_W * 0.5 - _dx() * rz) * s
			var sy: float = H * 0.5 + (float(r["y"]) - 400.0 - _dy() * rz) * s
			if sx < -220.0 or sx > W + 220.0 or sy < -60.0 or sy > H + 60.0:
				continue
			var ln: float = float(r["len"]) * (0.45 + wm * 0.011) * s * dir
			var wave: float = sin(t * 4.5 + float(r["phase"])) * float(r["amp"]) * s
			var alpha: float = float(r["alpha"]) * clampf(wm / 55.0, 0.22, 0.95)
			var pts: PackedVector2Array = ViewUtil.bezier_pts(Vector2(sx - ln * 0.5, sy - wave * 0.4), Vector2(sx - ln * 0.15, sy + wave), Vector2(sx + ln * 0.15, sy - wave), Vector2(sx + ln * 0.5, sy + wave * 0.3), 12)
			var cols := PackedColorArray()
			for i in pts.size():
				var f: float = float(i) / float(pts.size() - 1)
				cols.append(Color(rc, alpha * (1.0 - absf(f - 0.5) * 2.0)))
			ci.draw_polyline_colors(pts, cols, (1.3 + wm / 100.0 * 1.2) * s, true)
	var wtype: String = atmo.weather
	for m in atmo.particles:
		var z: float = float(m["z"])
		var rad: float = float(m["r"])
		var ph: float = float(m["phase"])
		var mx: float
		var my: float
		if wtype == "SNOW":
			mx = fposmod(float(m["x"]) + t * (float(m["vx"]) * 1.1 + wind * 0.85), TERRAIN_W)
			my = fposmod(float(m["y"]) + t * 95.0 + sin(t * 2.2 + ph) * 8.0, 800.0)
			ci.draw_circle(_wp(mx, my, z), rad * 1.15 * z * s, Color(0.9490, 0.9725, 1.0, 0.72))
		elif wtype == "GULLS_BREEZE":
			mx = fposmod(float(m["x"]) + t * (float(m["vx"]) * 1.5 + wind * 0.6), TERRAIN_W)
			my = float(m["y"]) + sin(t * 1.8 + ph) * 10.0
			ci.draw_circle(_wp(mx, my, z), rad * 1.5 * s, Color(0.9216, 0.9725, 1.0, 0.36))
		elif wtype == "AUTUMN_LEAVES":
			mx = fposmod(float(m["x"]) + t * (float(m["vx"]) * 1.2 + wind * 0.75), TERRAIN_W)
			my = fposmod(float(m["y"]) + t * 48.0 + sin(t * 2.4 + ph) * 14.0, 800.0)
			var p: Vector2 = _wp(mx, my, z)
			var lc: Color = Color(0.902, 0.4627, 0.1765, 0.68) if ph > 3.14 else Color(0.9608, 0.7137, 0.2588, 0.68)
			ViewUtil.fill_ellipse(ci, p, rad * 1.7 * s, rad * 0.95 * s, lc, t * 2.2 + ph)
		else:
			mx = fposmod(float(m["x"]) + t * (float(m["vx"]) + wind * 0.45), TERRAIN_W)
			my = float(m["y"]) + sin(t * 1.5 + ph) * 12.0
			ci.draw_circle(_wp(mx, my, z), rad * z * s, Color(1.0, 0.8784, 0.5882, 0.48))


func _wp(mx: float, my: float, z: float) -> Vector2:
	return Vector2(view.x * 0.5 + (mx - TERRAIN_W * 0.5 - _dx() * z) * scale_px, view.y * 0.5 + (my - 400.0 - _dy() * z) * scale_px)


## Off-screen projectile pill, touch ripples, splash procession and the vignette. `fx` supplies the touch ripples.
func draw_overlay(ci: CanvasItem, fx: FxPools, cam: CameraRig) -> void:
	var W: float = view.x
	var H: float = view.y
	if ctx.playing:
		for p in ctx.projectiles:
			var scr: Vector2 = cam.world_to_screen(ViewUtil.pos(p), view)
			if scr.y < 14.0:
				var clamped_x: float = clampf(scr.x, 48.0, W - 48.0)
				var meters: int = maxi(1, int(floor((cy - (H * 0.5) / scale_px - ViewUtil.gf(p, "y")) * 0.12 + 0.5)))
				var ptype: String = ViewUtil.gs(p, "type")
				var stroke: Color = ViewColors.WARM_YELLOW if ptype == "HOLY" else (ViewColors.BRISTLE_URTICATING if ViewUtil.gb(p, "is_urticating") else ViewColors.h("#ff8b3d"))
				var rect := Rect2(clamped_x - 31.0, 58.0, 62.0, 20.0)
				ViewUtil.fill_round_rect(ci, rect, 10.0, Color(0.0431, 0.0549, 0.0863, 0.88))
				ViewUtil.stroke_round_rect(ci, rect, 10.0, stroke, 1.6)
				ViewUtil.text(ci, ViewUtil.tr_text("TRACKER_METERS") % meters, Vector2(clamped_x, 71.5), 10, ViewColors.NAME_TEXT)
		for rp in fx.touch_ripples:
			var a: float = clampf(float(rp["life"]), 0.0, 1.0)
			var col: Color = rp["color"]
			ci.draw_arc(Vector2(float(rp["x"]), float(rp["y"])), float(rp["r"]), 0.0, TAU, 28, Color(col, col.a * a), 2.4, true)
			if str(rp["label"]) != "":
				ViewUtil.text(ci, str(rp["label"]), Vector2(float(rp["x"]), float(rp["y"]) - float(rp["r"]) - 8.0), 10, Color(ViewColors.AIM_LABEL, a))
	if splash:
		_draw_splash(ci)
	var m: float = minf(W, H)
	var big: float = maxf(W, H)
	ViewUtil.radial(ci, Vector2(W * 0.5, H * 0.5), m * 0.4, big * 0.76, [[0.0, Color(0, 0, 0, 0.0)], [1.0, ViewColors.VIGNETTE_EDGE]], 1.0, "vignette")


func _draw_splash(ci: CanvasItem) -> void:
	var W: float = view.x
	var H: float = view.y
	var t: float = ctx.t_now
	var by: float = H * 0.74
	var br := ViewColors.h("#12151c")
	var branch: PackedVector2Array = ViewUtil.quad_pts(Vector2(0, by + 18.0), Vector2(W * 0.5, by - 12.0), Vector2(W, by + 10.0), 24)
	ci.draw_polyline(branch, br, 14.0, true)
	var span: float = W + 400.0
	for c in 6:
		var head_x: float = fmod(t * 48.0 + float(c) * 92.0, span) - 200.0
		var st: float = head_x / maxf(1.0, W)
		var base_y: float = (1.0 - st) * (1.0 - st) * (by + 18.0) + 2.0 * (1.0 - st) * st * (by - 12.0) + st * st * (by + 10.0) - 10.0
		for s in range(5, -1, -1):
			var sx: float = head_x - float(s) * 11.0
			var sy: float = base_y + sin(t * 9.0 - float(s) * 0.9 + float(c)) * 2.4
			var r: float = 7.5 if s == 0 else 6.5 - float(s) * 0.35
			for h in range(-3, 4):
				var ha: float = -PI * 0.5 + float(h) * 0.35
				ci.draw_line(Vector2(sx + cos(ha) * r, sy + sin(ha) * r), Vector2(sx + cos(ha) * (r + 6.0), sy + sin(ha) * (r + 6.0)), Color(0.9647, 0.8118, 0.4667, 0.55), 1.2, true)
			ci.draw_circle(Vector2(sx, sy), r, ViewColors.h("#16181f") if s == 0 else ViewColors.h("#252934"))
			if s > 0:
				ViewUtil.fill_ellipse(ci, Vector2(sx, sy - r * 0.45), r * 0.65, r * 0.35, ViewColors.h("#e6772e"))
			else:
				ci.draw_circle(Vector2(sx + 3.0, sy - 1.0), 1.8, ViewColors.h("#f5b945"))

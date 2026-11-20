## Procedural pictograms of the weapons: the one held by the active fighter, projectiles in flight and the airstrike plane
## (port of drawHeldWeapon / drawProjectile / drawAirstrikePlane, renderer.js:1931-2174, 2439-2744).
class_name WeaponArt
extends RefCounted

static var _rng := RandomNumberGenerator.new()


static func _poly(ci: CanvasItem, pts: Array, fill: Color, stroke: Color, w: float) -> void:
	ArtKit.poly(ci, PackedVector2Array(pts), fill, stroke, w)


static func _lines(ci: CanvasItem, segs: Array, col: Color, w: float) -> void:
	var i: int = 0
	while i + 1 < segs.size():
		ci.draw_line(segs[i], segs[i + 1], col, w, true)
		i += 2


## Weapon in the hand of the active fighter. `root` is the fighter's world transform (no flip).
static func draw_held(ci: CanvasItem, root: Transform2D, f: Variant, ctx: ViewCtx) -> void:
	var swing_t: float = ViewUtil.gf(f, "bat_swing_timer")
	var swing: float = sin(swing_t * 18.0) * 1.8 if swing_t > 0.0 else 0.0
	var base: Transform2D = root * Transform2D(ctx.aim_angle + swing, Vector2.ONE, 0.0, Vector2(0, -3))
	ci.draw_set_transform_matrix(base)
	var t: float = ctx.t_now
	match ctx.weapon_id:
		"BAZOOKA":
			_poly(ci, [Vector2(-10, 4), Vector2(-2, -2), Vector2(-2, 3), Vector2(-8, 7)], ViewColors.h("#7a4621"), ViewColors.h("#1a120b"), 1.4)
			ViewUtil.rect_fs(ci, Rect2(-2, -3, 14, 5), ViewColors.h("#3f464e"), ViewColors.h("#1a120b"), 1.4)
			_poly(ci, [Vector2(12, -3.5), Vector2(22, -7.5), Vector2(22, 6.5), Vector2(12, 2.5)], ViewColors.h("#d99b43"), ViewColors.h("#1a120b"), 1.4)
		"CARQUINYOLI":
			ci.draw_set_transform_matrix(base * Transform2D(-0.22, Vector2.ONE, 0.0, Vector2(12, 0)))
			ViewUtil.round_rect_fs(ci, Rect2(-7, -3.5, 14, 7), 3.0, ViewColors.h("#c87d32"), ViewColors.h("#4a280a"), 1.3)
			ViewUtil.fill_ellipse(ci, Vector2(-2.5, 0), 2.2, 1.3, ViewColors.h("#fff5df"), 0.3)
			ViewUtil.fill_ellipse(ci, Vector2(2.5, -0.3), 2.0, 1.2, ViewColors.h("#fff5df"), -0.25)
		"URTICARIA":
			ViewUtil.circle_fs(ci, Vector2(12, 0), 5.5, ViewColors.h("#8b3eb8"), ViewColors.h("#f6cf77"), 1.4)
		"SHOTGUN":
			_poly(ci, [Vector2(-6, 5)] + Array(ViewUtil.quad_pts(Vector2(-6, 5), Vector2(-3, -1), Vector2(4, -1), 6)) + [Vector2(4, 3)] + Array(ViewUtil.quad_pts(Vector2(4, 3), Vector2(-1, 3), Vector2(-3, 7), 6)), ViewColors.h("#8c542b"), ViewColors.h("#1c120a"), 1.3)
			ViewUtil.rect_fs(ci, Rect2(3, -3, 17, 3.5), ViewColors.h("#8d96a3"), ViewColors.h("#1c120a"), 1.3)
			ci.draw_rect(Rect2(5, -6, 3, 3), ViewColors.h("#d9a14a"))
		"FUET":
			var bend: float = sin(swing_t * 26.0) * 7.0 if swing_t > 0.0 else -2.5
			ci.draw_polyline(ViewUtil.quad_pts(Vector2(2, 1), Vector2(15, bend), Vector2(28, bend * 0.6), 10), ViewColors.h("#7a1f2d"), 5.4, true)
			ViewUtil.dashed(ci, ViewUtil.quad_pts(Vector2(3, 1), Vector2(15, bend), Vector2(27, bend * 0.6), 14), 2.8, 2.2, ViewColors.h("#f4eee1"), 4.2)
			ci.draw_line(Vector2(28, bend * 0.6), Vector2(32, bend * 0.6 - 3), ViewColors.h("#d9b372"), 1.4, true)
			ci.draw_line(Vector2(28, bend * 0.6), Vector2(32, bend * 0.6 + 2.5), ViewColors.h("#d9b372"), 1.4, true)
		"BAT":
			ViewUtil.rect_fs(ci, Rect2(2, -2, 8, 4), ViewColors.h("#b87430"), ViewColors.h("#2b1808"), 1.3)
			var blade := PackedVector2Array()
			blade.append_array(ViewUtil.bezier_pts(Vector2(10, 0), Vector2(16, -13), Vector2(28, -10), Vector2(26, 2), 10))
			blade.append_array(ViewUtil.bezier_pts(Vector2(26, 2), Vector2(24, 8), Vector2(17, 8), Vector2(14, 5), 8))
			blade.append_array(ViewUtil.bezier_pts(Vector2(14, 5), Vector2(19, 5), Vector2(22, 2), Vector2(22, -2), 8))
			blade.append_array(ViewUtil.bezier_pts(Vector2(22, -2), Vector2(22, -7), Vector2(15, -7), Vector2(10, 1), 8))
			ViewUtil.fill_poly(ci, blade, ViewColors.h("#dce3ec"))
			blade.append(blade[0])
			ci.draw_polyline(blade, ViewColors.h("#4a525d"), 1.4, true)
		"GRENADE":
			ViewUtil.ellipse_fs(ci, Vector2(12, 0), 5.5, 4.5, ViewColors.h("#7c4d2b"), ViewColors.h("#f6cf77"), 1.2)
		"CLUSTER":
			_lines(ci, [Vector2(9, 4), Vector2(13, -2), Vector2(12, 5), Vector2(15, -2)], ViewColors.h("#f2ecdf"), 2.2)
			_lines(ci, [Vector2(13, -2), Vector2(16, -7), Vector2(15, -2), Vector2(19, -6)], ViewColors.h("#5ca856"), 2.2)
			ci.draw_rect(Rect2(10, 0, 6, 2.5), ViewColors.h("#d93829"))
		"HOLY":
			_poly(ci, [Vector2(9, 5), Vector2(12, -5), Vector2(15, -5), Vector2(18, 5)], ViewColors.h("#f0b849"), Color.WHITE, 1.3)
		"DYNAMITE":
			ci.draw_rect(Rect2(7, -4, 12, 7), ViewColors.h("#8c5830"))
			ci.draw_rect(Rect2(7, -4, 6, 7), ViewColors.h("#d93829"))
		"AIRSTRIKE":
			ci.draw_rect(Rect2(8, -5, 6, 9), ViewColors.h("#d94638"))
			ci.draw_line(Vector2(11, -5), Vector2(11, -13), ViewColors.h("#f6cf77"), 1.5, true)
		"CULLERA":
			var wob: float = sin(t * 28.0) * 0.28 if ViewUtil.gf(f, "spoon_timer") > 0.0 else 0.0
			ci.draw_set_transform_matrix(base * Transform2D(wob, Vector2.ONE, 0.0, Vector2.ZERO))
			ViewUtil.round_rect_fs(ci, Rect2(2, -2, 16, 4), 1.5, ViewColors.h("#cfa05a"), ViewColors.h("#4a2c0d"), 1.3)
			ViewUtil.ellipse_fs(ci, Vector2(22, 0), 7.5, 5.0, ViewColors.h("#e6b973"), ViewColors.h("#4a2c0d"), 1.3)
			ViewUtil.fill_ellipse(ci, Vector2(22.5, 0), 5.0, 3.2, ViewColors.h("#b8843e"))
		"BARRINA":
			var jit: float = (_rng.randf() - 0.5) * 3.0 if ViewUtil.gf(f, "drill_timer") > 0.0 else 0.0
			ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2.ONE, 0.0, Vector2(jit, 0)))
			ViewUtil.rect_fs(ci, Rect2(3, -4.5, 11, 9), ViewColors.h("#d97b29"), ViewColors.h("#1c1612"), 1.3)
			_poly(ci, [Vector2(14, -3.5), Vector2(28, 0), Vector2(14, 3.5)], ViewColors.h("#b8c2cf"), ViewColors.h("#1c1612"), 1.3)
		"PONT_PEDRA":
			ViewUtil.rect_fs(ci, Rect2(8, -4.5, 13, 8), ViewColors.h("#a8a298"), ViewColors.h("#2d2a26"), 1.3)
			ci.draw_rect(Rect2(8, -4.5, 13, 2.5), ViewColors.h("#82a858"))
		"GANXO":
			ci.draw_line(Vector2(2, 1), Vector2(18, -1), ViewColors.h("#9c6234"), 2.6, true)
			ci.draw_polyline(ViewUtil.arc_pts(Vector2(21, -1), 4.5, -PI * 0.6, PI * 0.65, 10), ViewColors.h("#e2e8f0"), 2.4, true)
		_:
			pass


## Projectile in flight (trail first, then the body).
static func draw_projectile(ci: CanvasItem, p: Variant, ctx: ViewCtx) -> void:
	draw_trail(ci, p)
	draw_projectile_body(ci, p, ctx)


## The fading trail behind a projectile.
static func draw_trail(ci: CanvasItem, p: Variant) -> void:
	var ptype: String = ViewUtil.gs(p, "type")
	var trail: PackedVector2Array = ViewUtil.g(p, "trail", PackedVector2Array())
	if trail.size() > 2:
		var holy: bool = ptype == "HOLY"
		var urt: bool = ptype == "URTICARIA"
		var baz: bool = ptype == "BAZOOKA" or ptype == "BOMBLER"
		for i in range(1, trail.size()):
			var frac: float = float(i) / float(trail.size())
			var col: Color
			if holy:
				col = Color(ViewColors.TRAIL_HOLY, frac * 0.55)
			elif urt:
				col = Color(ViewColors.TRAIL_URTICARIA, frac * 0.52)
			elif baz:
				col = Color(ViewColors.TRAIL_BAZOOKA, frac * 0.48)
			else:
				col = Color(ViewColors.TRAIL_DEFAULT, frac * 0.34)
			var wd: float = maxf(1.0, frac * (7.5 if holy else (6.0 if baz else 4.2)))
			ci.draw_line(trail[i - 1], trail[i], col, wd, true)


## The vector body of a projectile (the fallback of the sprites in art/weapons).
static func draw_projectile_body(ci: CanvasItem, p: Variant, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	var ptype: String = ViewUtil.gs(p, "type")
	var px: float = ViewUtil.gf(p, "x")
	var py: float = ViewUtil.gf(p, "y")
	var at: Vector2 = Vector2(px, py)
	var ang: float = ViewUtil.gf(p, "ang")
	if ptype == "CARQUINYOLI":
		ci.draw_set_transform_matrix(Transform2D(ang + t * 14.0, Vector2.ONE, 0.0, at))
		if ViewUtil.gb(p, "is_fuet_slice"):
			ViewUtil.circle_fs(ci, Vector2.ZERO, 6.2, ViewColors.h("#8a2434"), ViewColors.h("#f4eee1"), 2.2)
			var cr := ViewColors.h("#f4eee1")
			ci.draw_circle(Vector2(-2, -1.5), 1.2, cr)
			ci.draw_circle(Vector2(2, 1.5), 1.3, cr)
			ci.draw_circle(Vector2(1.5, -2), 0.9, cr)
		else:
			ViewUtil.round_rect_fs(ci, Rect2(-7.5, -4, 15, 8), 3.5, ViewColors.h("#c87d32"), ViewColors.h("#5c310c"), 1.5)
			ViewUtil.ellipse_fs(ci, Vector2(-2.8, 0), 2.3, 1.4, ViewColors.h("#fff5df"), ViewColors.h("#7a4414"), 0.8, 0.3)
			ViewUtil.ellipse_fs(ci, Vector2(2.8, -0.3), 2.1, 1.3, ViewColors.h("#fff5df"), ViewColors.h("#7a4414"), 0.8, -0.25)
	elif ptype == "BAZOOKA" or ptype == "BOMBLER" or ptype == "URTICARIA":
		var a2: float = atan2(ViewUtil.gf(p, "vy"), ViewUtil.gf(p, "vx"))
		ci.draw_set_transform_matrix(Transform2D(a2, Vector2.ONE, 0.0, at))
		if ptype == "BOMBLER":
			ci.draw_line(Vector2(-5, 0), Vector2(3, 0), ViewColors.h("#f2ecdf"), 3.0, true)
			ci.draw_line(Vector2(3, 0), Vector2(8, -2), ViewColors.h("#5ca856"), 2.5, true)
			ci.draw_line(Vector2(3, 0), Vector2(8, 2), ViewColors.h("#5ca856"), 2.5, true)
			ci.draw_circle(Vector2(-5, 0), 3.0, ViewColors.h("#ff6b2b"))
		elif ptype == "BAZOOKA":
			ViewUtil.circle_fs(ci, Vector2.ZERO, 6.0, ViewColors.h("#282d34"), ViewColors.h("#d99b43"), 1.6)
			_poly(ci, [Vector2(-6, -2.5), Vector2(-15.0 - _rng.randf() * 6.0, 0), Vector2(-6, 2.5)], ViewColors.h("#ff9b3b"), Color.BLACK, 0.0)
		else:
			ViewUtil.ellipse_fs(ci, Vector2.ZERO, 7.0, 4.5, ViewColors.h("#7a2eb0"), ViewColors.h("#f5b945"), 1.5)
			_poly(ci, [Vector2(-7, -2), Vector2(-14.0 - _rng.randf() * 5.0, 0), Vector2(-7, 2)], ViewColors.h("#d88aff"), Color.BLACK, 0.0)
	elif ptype == "GRENADE" or ptype == "CLUSTER" or ptype == "HOLY":
		ci.draw_set_transform_matrix(Transform2D(ang, Vector2.ONE, 0.0, at))
		if ptype == "HOLY":
			ViewUtil.radial(ci, Vector2.ZERO, 2.0, 19.0, [[0.0, Color(1.0, 0.9216, 0.5686, 0.78)], [1.0, Color(1.0, 0.7843, 0.2941, 0.0)]], 1.0, "holy_halo")
			_poly(ci, [Vector2(-5, 6), Vector2(-2, -6), Vector2(2, -6), Vector2(5, 6)], ViewColors.h("#f0b849"), Color.WHITE, 1.6)
			ci.draw_line(Vector2(-3, 2), Vector2(-10, -4), Color.WHITE, 1.6, true)
			ci.draw_rect(Rect2(-3.5, 1, 7, 4.5), ViewColors.h("#a81c1c"))
			ci.draw_line(Vector2(0, -13), Vector2(0, -7), Color.WHITE, 2.0, true)
			ci.draw_line(Vector2(-3.5, -10.5), Vector2(3.5, -10.5), Color.WHITE, 2.0, true)
		elif ptype == "CLUSTER":
			_lines(ci, [Vector2(-3, 6), Vector2(-2, -2), Vector2(0, 6), Vector2(0, -3), Vector2(3, 6), Vector2(2, -2)], ViewColors.h("#f2ecdf"), 2.4)
			_lines(ci, [Vector2(-2, -2), Vector2(-5, -7), Vector2(0, -3), Vector2(0, -8), Vector2(2, -2), Vector2(5, -7)], ViewColors.h("#5ca856"), 2.2)
			ci.draw_rect(Rect2(-4, -1, 8, 2.5), ViewColors.h("#d93829"))
		else:
			var r: float = ViewUtil.gf(p, "r", 6.0)
			ViewUtil.ellipse_fs(ci, Vector2.ZERO, r, r * 1.15, ViewColors.h("#7c4d2b"), ViewColors.h("#241509"), 1.6)
			var sc := ViewColors.h("#d9a15b")
			ci.draw_polyline(PackedVector2Array([Vector2(-4, -2), Vector2(0, -5), Vector2(4, -2)]), sc, 1.1, true)
			ci.draw_polyline(PackedVector2Array([Vector2(-4, 2), Vector2(0, -1), Vector2(4, 2)]), sc, 1.1, true)
		ci.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, 0.0, at))
		if ViewUtil.gb(p, "has_fuse"):
			ViewUtil.text(ci, str(int(ceil(ViewUtil.gf(p, "fuse")))), Vector2(0, -14), 12, ViewColors.h("#ffe57f") if ptype == "HOLY" else Color.WHITE)
	elif ptype == "DYNAMITE":
		ci.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, 0.0, at))
		ci.draw_line(Vector2(-5, 4), Vector2(-7, 10), ViewColors.h("#5c3818"), 2.2, true)
		ci.draw_line(Vector2(5, 4), Vector2(7, 10), ViewColors.h("#5c3818"), 2.2, true)
		ViewUtil.round_rect_fs(ci, Rect2(-9, -5, 18, 10), 3.0, ViewColors.h("#8c5830"), ViewColors.h("#241408"), 1.6)
		ViewUtil.fill_round_rect(ci, Rect2(-9, -5, 9, 10), 2.0, ViewColors.h("#d93829"))
		ci.draw_circle(Vector2(5, -1.5), 1.3, Color.WHITE)
		ci.draw_polyline(ViewUtil.arc_pts(Vector2(5, 1), 2.2, 0.1, PI - 0.1, 8), Color.WHITE, 1.2, true)
		ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(2, -5), Vector2(8, -11), Vector2(11, -7), Vector2(7, -5)]), ViewColors.h("#e03228"))
		ci.draw_circle(Vector2(-2, -9), 3.2, ViewColors.h("#ffee77") if sin(t * 35.0) > 0.0 else ViewColors.h("#ff6622"))
		if ViewUtil.gb(p, "has_fuse"):
			ViewUtil.text(ci, str(int(ceil(ViewUtil.gf(p, "fuse")))), Vector2(0, -15), 12, ViewColors.h("#ffeb99"))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Airstrike plane.
static func draw_plane(ci: CanvasItem, pl: Variant) -> void:
	var flip: float = -1.0 if ViewUtil.gf(pl, "vx") < 0.0 else 1.0
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(flip, 1.0), 0.0, ViewUtil.pos(pl)))
	_poly(ci, [Vector2(-42, -4), Vector2(36, 0), Vector2(48, 5), Vector2(-38, 7)], ViewColors.h("#2b3038"), ViewColors.h("#121418"), 2.0)
	ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(-32, -4), Vector2(-44, -18), Vector2(-22, -4)]), ViewColors.h("#2b3038"))
	ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(-40, 0), Vector2(-58.0 - _rng.randf() * 10.0, 2), Vector2(-40, 5)]), ViewColors.h("#ff9b42"))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

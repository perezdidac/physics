## View maths and helpers: camera transform (JS getCameraTransform), colour parsing, noise port, effect pools.
##   godot --headless --path . res://tests/TestViewMath.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	_test_camera()
	_test_colors()
	_test_noise()
	_test_fx()
	_test_util()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _test_camera() -> void:
	var cam := CameraRig.new()
	cam.x = 1600.0
	cam.y = 400.0
	cam.zoom = 1.08
	var view := Vector2(1920, 1080)
	var xf: Dictionary = cam.get_transform(view)
	# docs/port_inventory_view.md 9.5: cssBaseScale 1.185 * 1.08 * 1.22 = 1.5614
	_check(absf(float(xf["scale"]) - 1.5614) < 0.002, "camera scale 1920x1080 = 1.5614 (got %.4f)" % float(xf["scale"]))
	_check(CameraRig.base_scale(Vector2(390, 844)) == clampf(390.0 / 600.0, 0.56, 0.86), "portrait base scale")
	_check(absf(CameraRig.base_scale(Vector2(844, 390)) - clampf(minf(844.0 / 1220.0, 390.0 / 580.0), 0.54, 0.88)) < 0.0001, "landscape mobile base scale")
	var w: Vector2 = cam.screen_to_world(Vector2(960, 540), view)
	_check(w.distance_to(Vector2(1600, 400)) < 0.01, "screen centre maps to camera centre")
	var back: Vector2 = cam.world_to_screen(Vector2(1700, 450), view)
	_check(cam.screen_to_world(back, view).distance_to(Vector2(1700, 450)) < 0.01, "world->screen->world round trip")
	cam.zoom_user(10.0)
	_check(cam.user_zoom == 2.5, "user zoom clamps at 2.5")
	cam.zoom_user(0.0, 0.5)
	_check(absf(cam.user_zoom - 1.25) < 0.0001, "pinch multiplies the zoom")
	_check(absf(CameraRig.STORY_USER_ZOOM / CameraRig.DEFAULT_USER_ZOOM - 1.6) < 0.01, "story starts about 1.6x closer than classic")
	_check(PlatformCamera.zoom_for(Vector2(1600, 720), true) > PlatformCamera.zoom_for(Vector2(1600, 720)), "phone platformer zoom is closer")
	cam.zoom_user(-10.0)
	_check(cam.user_zoom == 0.50, "user zoom clamps at 0.50")
	cam.target_x = 2000.0
	cam.step(0.033)
	var k: float = 1.0 - pow(0.015, 0.033)
	_check(absf(cam.x - lerpf(1600.0, 2000.0, k)) < 0.001, "camera smoothing uses 1 - 0.015^dt")
	cam.pan_by(99999.0, 99999.0)
	_check(cam.pan_x == 3200.0 * 0.85 and cam.pan_y == 320.0, "pan offsets clamp like the JS")


func _test_colors() -> void:
	_check(ViewColors.parse("#f5b945") == Color("#f5b945"), "parse hex")
	var c: Color = ViewColors.parse("rgba(42, 114, 122, 0.82)")
	_check(absf(c.r - 42.0 / 255.0) < 0.001 and absf(c.a - 0.82) < 0.001, "parse rgba()")
	var d: Color = ViewColors.parse("255, 225, 175")
	_check(absf(d.g - 225.0 / 255.0) < 0.001 and d.a == 1.0, "parse bare r, g, b")
	_check(ViewColors.parse(Color.RED) == Color.RED, "parse passes Color through")


func _test_noise() -> void:
	var p: PackedInt32Array = ViewNoise.perm()
	_check(p.size() == 512 and p[0] == p[256], "perm table is 512 entries, mirrored")
	var seen: Dictionary = {}
	for i in 256:
		seen[p[i]] = true
	_check(seen.size() == 256, "perm table is a permutation of 0..255")
	var n: float = ViewNoise.noise2d(3.7, 9.1)
	_check(n > -0.5 and n < 1.5, "noise2d in range")
	_check(absf(ViewNoise.noise2d(0.0, 0.0) - 0.5) < 0.0001, "noise2d(0,0) = 0.5 (zero gradient at lattice point)")
	if ResourceLoader.exists("res://combat/sim/sim_noise.gd"):
		var sn: GDScript = load("res://combat/sim/sim_noise.gd")
		var same: bool = true
		for i in 20:
			var x: float = 1.3 + float(i) * 0.77
			var y: float = 4.1 + float(i) * 0.31
			if absf(float(sn.call("noise2d", x, y)) - ViewNoise.noise2d(x, y)) > 0.00001:
				same = false
		_check(same, "ViewNoise.noise2d equals the sim's SimNoise.noise2d")
		_check(absf(float(sn.call("fbm", 2.2, 5.5, 4)) - ViewNoise.fbm(2.2, 5.5, 4)) < 0.00001, "ViewNoise.fbm equals SimNoise.fbm")
	else:
		print("OK    SKIP sim noise comparison (sim not available)")


func _test_fx() -> void:
	var fx := FxPools.new()
	fx.spawn("fireball", {"x": 100.0, "y": 100.0, "r": 20.0, "max_r": 80.0, "urticating": false})
	fx.spawn("sparks", {"x": 100.0, "y": 100.0, "count": 12})
	fx.spawn("smoke", {"x": 100.0, "y": 100.0, "count": 5, "style": "dark"})
	fx.spawn("debris", {"x": 100.0, "y": 100.0, "count": 6})
	_check(fx.fireballs.size() == 1 and fx.particles.size() == 18 and fx.smokes.size() == 5, "sim effect kinds spawn fireball, sparks, smoke, debris")
	fx.spawn("water_plunge", {"x": 10.0, "y": 700.0, "scale": 1.0})
	_check(fx.plumes.size() == 1 and fx.ripples.size() == 1, "water_plunge spawns a plume and a ripple")
	fx.spawn("beam", {"x1": 0.0, "y1": 0.0, "x2": 50.0, "y2": 0.0, "life": 0.22})
	fx.spawn("smoke", {"x": 1.0, "y": 1.0, "count": 3, "style": "silk"})
	fx.spawn("bubbles", {"x": 5.0, "y": 720.0})
	fx.spawn("shockwave", {"x": 1.0, "y": 1.0, "r": 5.0, "max_r": 40.0, "alpha": 1.0, "color": ""})
	for i in 300:
		fx.update(0.033, 20.0, null, 700.0)
	_check(fx.particles.is_empty() and fx.fireballs.is_empty() and fx.smokes.is_empty() and fx.shockwaves.is_empty() and fx.plumes.is_empty(), "all pools empty after 10 s")
	fx.add_float_text(Vector2(1, 1), "hi", Color.WHITE, 1.0)
	fx.update(1.1, 0.0, null, 700.0)
	_check(fx.floats.is_empty(), "floating text expires after its life")


func _test_util() -> void:
	var d: Dictionary = {"x": 3.0, "hp": 5}
	_check(ViewUtil.gf(d, "x") == 3.0 and ViewUtil.gi(d, "hp") == 5 and ViewUtil.gf(d, "missing", 7.0) == 7.0, "duck-typed field access on a Dictionary")
	_check(ViewUtil.pos(Vector2(1, 2)) == Vector2(1, 2), "pos() accepts a Vector2")
	var pts: PackedVector2Array = ViewUtil.round_rect_pts(Rect2(0, 0, 20, 10), 3.0)
	_check(pts.size() == 24, "round rect outline has 4 corners x 6 points")
	_check(ViewUtil.clamp_js(NAN, 1.0, 5.0) == 1.0 and ViewUtil.clamp_js(9.0, 1.0, 5.0) == 5.0, "clamp_js returns lo for NaN")

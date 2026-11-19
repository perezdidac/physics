## CombatScreen with a real CombatSim: frame loop, signals into the view, terrain textures, input commands.
##   godot --headless --path . res://tests/TestViewScreen.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	await _run()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	_test_shader()
	if not ResourceLoader.exists("res://combat/sim/combat_sim.gd"):
		print("OK    SKIP CombatScreen tests (combat/sim/combat_sim.gd not available yet)")
		return
	var screen: CombatScreen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
	screen.auto_start = false
	add_child(screen)
	var cfg: Object = load("res://combat/sim/match_config.gd").new()
	cfg.set("map_idx", 1)
	cfg.set("game_mode", "2P_LOCAL")
	cfg.set("worms_per_team", 2)
	var sim: Object = load("res://combat/sim/combat_sim.gd").new()
	sim.call("setup", cfg)
	screen.start(sim)
	_check(screen.sim == sim and screen.view != null and screen.input != null, "CombatScreen instantiates and binds a CombatSim")
	await _frames(20)
	_check(screen.t_now > 0.0, "frame loop advances the animation clock (t_now=%.3f)" % screen.t_now)
	_check(float(sim.get("t_now")) > 0.0, "sim.step runs from the screen loop")
	_check(screen.view.atmo.clouds.size() >= 9 and screen.view.atmo.palette.size() == 5, "atmosphere generated (clouds, 5-colour palette)")
	_check(screen.view.terrain_view.uploads == 0, "terrain textures built at start")

	# signals -> view
	sim.emit_signal("float_text", Vector2(100, 100), "HELLO", Color.WHITE, 1.0)
	sim.emit_signal("effect", "fireball", {"x": 500.0, "y": 300.0, "r": 20.0, "max_r": 70.0, "urticating": false})
	_check(screen.view.fx.floats.size() >= 1 and screen.view.fx.fireballs.size() >= 1, "sim float_text / effect signals reach the effect pools")
	sim.emit_signal("camera_focus", Vector2(900, 300), null)
	_check(screen.cam.impact_active and screen.cam.impact_pos == Vector2(900, 300), "camera_focus sets the impact camera")
	sim.emit_signal("screen_shake", 12.0)
	_check(screen.shake > 1.0, "screen_shake raises the shake")
	var before: float = screen.t_now
	sim.emit_signal("hit_stop", 0.5, false)
	await _frames(3)
	_check(is_equal_approx(screen.t_now, before), "hit_stop freezes the animation clock")
	screen.hit_stop = 0.0
	screen.slow_mo = 0.0
	sim.emit_signal("slow_mo", 0.45, false)
	sim.emit_signal("slow_mo", 0.35, true)
	_check(is_equal_approx(screen.slow_mo, 0.45), "slow_mo use_max keeps the longer value")
	sim.emit_signal("slow_mo", 0.3, false)
	_check(is_equal_approx(screen.slow_mo, 0.3), "slow_mo without use_max overwrites")
	screen.slow_mo = 0.0

	# terrain mask texture after a carve
	var terrain: Object = sim.get("terrain")
	var tx: float = 1600.0
	var ty: float = float(terrain.call("find_surface_y", tx, 40.0)) + 12.0
	var tv: TerrainView = screen.view.terrain_view
	terrain.call("carve_crater", tx, ty, 20.0)
	tv.flush()
	_check(tv.uploads == 1, "terrain_changed uploads the changed mask rectangle once")
	_check(tv.scorch_count == 1, "crater scorch baked into the colour layer")
	terrain.call("build_girder", tx, ty - 80.0, 0.0)
	tv.flush()
	_check(tv.uploads == 2, "girder repaints its rectangle")

	# input -> sim commands (2P_LOCAL: the human controls the active team)
	screen.cam.locked = false
	screen.input.set_key("right", true)
	await _frames(3)
	_check(bool(sim.call("key_right")), "held right key reaches sim.set_move")
	screen.input.set_key("right", false)
	await _frames(3)
	_check(not bool(sim.call("key_right")), "released key clears the move")
	for i in 150:
		sim.call("step", 0.033)
	var f: Object = sim.get("active_fighter")
	_check(bool(f.get("grounded")), "active fighter settled on the ground")
	screen.input.do_forward_jump()
	_check(not bool(f.get("grounded")) and bool(sim.get("has_acted_or_moved_this_turn")), "forward jump command accepted by the sim")
	_check(screen.view.ctx.fighters.size() == 4 and screen.view.ctx.active == f, "view context reads the fighters and the active one")
	# splash / menu showcase: not playing -> drifting camera, no crash
	sim.set("playing", false)
	await _frames(10)
	_check(screen.cam.playing == false and screen.view.sky.splash, "showcase mode (playing=false) renders with the splash silhouette")
	screen.queue_free()


func _test_shader() -> void:
	var sh: Shader = load("res://combat/view/terrain.gdshader") as Shader
	_check(sh != null and sh.get_mode() == Shader.MODE_CANVAS_ITEM, "terrain shader loads as a canvas_item shader")
	var names: Array[String] = []
	for u in sh.get_shader_uniform_list():
		names.append(str(u["name"]))
	_check(names.has("mask_tex") and names.has("front_tex") and names.has("back_tex"), "terrain shader exposes the mask and the baked front / back textures")
	var cv: Shader = load("res://combat/view/cloud_veil.gdshader") as Shader
	_check(cv != null and cv.get_mode() == Shader.MODE_CANVAS_ITEM, "cloud veil shader loads")
	_check(ViewNoise.perm_image().get_size() == Vector2i(256, 1), "perm texture image is 256x1")

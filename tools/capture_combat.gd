## Opens a quick match in a real window, lets it run for ~2 s and saves a screenshot, then quits.
##   CUCS_MAP=3 godot --path . res://tools/CaptureCombat.tscn      (output: /tmp/claude-1000/cucs_capture_<map>.png)
## Optional env vars: CUCS_WAIT (seconds, default 2), CUCS_FIRE (1 = fire the first weapon after 0.5 s),
## CUCS_CAM ("x,y,zoom": freeze the camera there), CUCS_STAMP ("KIND[/n[/zoom]]": frame the n-th (default 0) terrain stamp of that
## kind, e.g. WATCHTOWER or TREE@DOUGLAS_FIR; "LIST" prints all stamps), CUCS_OUT (png path instead of the default),
## CUCS_BOOM ("dx,dy,r[;dx,dy,r...]": carve craters at offsets from the framed stamp, to see structures destroyed),
## CUCS_SIM (seconds the sim is stepped offline before the capture, e.g. through the ants' turns; use with CUCS_SKIP), CUCS_FOLLOW (zoom: lock the camera on the active fighter, or on the middle of the ants of a critter phase),
## CUCS_SKIP (1 = end the player's first turn after 0.3 s so the CPU ants play), CUCS_ROCK ("x,y,w,h[;...]": fill solid rectangles, e.g. a wall for the ants),
## CUCS_GIRDER ("dx,dy,angle[;...]": build dry-stone girders at offsets from the framed stamp).
extends Node

var _screen: CombatScreen = null
var _elapsed: float = 0.0
var _map: int = 0
var _fired: bool = false
var _skipped: bool = false


func _ready() -> void:
	# CUCS_DPI=440 CUCS_SIZE=2404x1080 simulate a phone (touch UI); CUCS_PLATFORM=egg_1 captures that platform level instead
	# of a combat (CUCS_PAUSE=1 opens its pause menu).
	if OS.get_environment("CUCS_DPI") != "":
		TouchMetrics.force_dpi = float(OS.get_environment("CUCS_DPI"))
		TouchMetrics.force = 1
	if OS.get_environment("CUCS_SIZE") != "":
		var wh: PackedStringArray = OS.get_environment("CUCS_SIZE").split("x")
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	if OS.get_environment("CUCS_PLATFORM") != "":
		var plat: PlatformScreen = load("res://platform/PlatformScreen.tscn").instantiate() as PlatformScreen
		plat.auto_start = false
		plat.go_callable = func(_n: String) -> void: pass
		add_child(plat)
		plat.start(load("res://data/levels/%s.tres" % OS.get_environment("CUCS_PLATFORM")) as LevelDef)
		if OS.get_environment("CUCS_PAUSE") == "1":
			plat.set_paused(true)
		return
	_map = int(OS.get_environment("CUCS_MAP")) if OS.get_environment("CUCS_MAP") != "" else 0
	_screen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
	_screen.auto_start = false
	add_child(_screen)
	var cfg := MatchConfig.new()
	cfg.map_idx = _map
	GameState.map_idx = _map
	cfg.game_mode = "2P_LOCAL"
	cfg.seed = int(OS.get_environment("CUCS_SEED"))
	cfg.worms_per_team = 4
	if OS.get_environment("CUCS_LEVEL") != "": # a story level, e.g. CUCS_LEVEL=cuca_1
		GameState.story_level = load("res://data/levels/%s.tres" % OS.get_environment("CUCS_LEVEL")) as LevelDef
		cfg = GameState.make_match_config() as MatchConfig
	var sim := CombatSim.new()
	sim.setup(cfg)
	_screen.start(sim)
	var st_env: PackedStringArray = OS.get_environment("CUCS_STAMP").split("/")
	if st_env[0] == "LIST":
		for st in sim.terrain.stamps:
			print("STAMP ", st)
		get_tree().quit.call_deferred()
	elif st_env[0] != "":
		var want: int = int(st_env[1]) if st_env.size() > 1 else 0
		var seen: int = 0
		for st in sim.terrain.stamps:
			if str(st.get("kind", "")) == st_env[0] or str(st.get("kind", "")) + "@" + str(st.get("style", "")) == st_env[0]:
				if seen == want:
					_screen.cam.locked = true
					_screen.cam.x = float(st.get("x", 0.0))
					_screen.cam.y = float(st.get("y", 0.0)) - 30.0
					_screen.cam.zoom = float(st_env[2]) if st_env.size() > 2 else 2.0
					for boom in OS.get_environment("CUCS_BOOM").split(";", false):
						var b: PackedStringArray = boom.split(",")
						if b.size() >= 3:
							sim.terrain.carve_crater(float(st.get("x", 0.0)) + float(b[0]), float(st.get("y", 0.0)) + float(b[1]), float(b[2]))
					for g in OS.get_environment("CUCS_GIRDER").split(";", false):
						var gb: PackedStringArray = g.split(",")
						if gb.size() >= 3:
							sim.terrain.build_girder(float(st.get("x", 0.0)) + float(gb[0]), float(st.get("y", 0.0)) + float(gb[1]), float(gb[2]))
					break
				seen += 1
	for rk in OS.get_environment("CUCS_ROCK").split(";", false):
		var rb: PackedStringArray = rk.split(",")
		if rb.size() >= 4:
			var rr := Rect2i(int(rb[0]), int(rb[1]), int(rb[2]), int(rb[3]))
			for ry in range(rr.position.y, rr.end.y):
				for rx in range(rr.position.x, rr.end.x):
					sim.terrain.mask[ry * TerrainSim.W + rx] = 1
			sim.terrain._announce(rr)
	if OS.get_environment("CUCS_SKIP") == "1":
		sim.end_turn()
		_skipped = true
	var sim_s: float = float(OS.get_environment("CUCS_SIM")) if OS.get_environment("CUCS_SIM") != "" else 0.0
	for i in int(sim_s * 60.0):
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
		sim.step(1.0 / 60.0)
		sim.advance_real(1.0 / 60.0)
	var cam_env: PackedStringArray = OS.get_environment("CUCS_CAM").split(",")
	if cam_env.size() >= 3:
		_screen.cam.locked = true
		_screen.cam.x = float(cam_env[0])
		_screen.cam.y = float(cam_env[1])
		_screen.cam.zoom = float(cam_env[2])


func _process(delta: float) -> void:
	_elapsed += delta
	if _screen != null and OS.get_environment("CUCS_FOLLOW") != "" and _screen.sim.active_fighter != null:
		var af: SimFighter = _screen.sim.active_fighter
		_screen.cam.locked = true
		_screen.cam.x = af.x
		_screen.cam.y = af.y
		var acting: Array[SimFighter] = _screen.sim.critter_acting
		if acting.size() >= 2: # a critter phase: centre on the ants that still move
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for m in acting:
				lo = Vector2(minf(lo.x, m.x), minf(lo.y, m.y))
				hi = Vector2(maxf(hi.x, m.x), maxf(hi.y, m.y))
			_screen.cam.x = (lo.x + hi.x) * 0.5
			_screen.cam.y = (lo.y + hi.y) * 0.5
		_screen.cam.zoom = float(OS.get_environment("CUCS_FOLLOW"))
	if _screen != null and OS.get_environment("CUCS_FIRE") == "1" and not _fired and _elapsed > 0.5:
		_fired = true
		_screen.sim.call("begin_charge_or_fire")
		_screen.sim.call("release_charge")
	if _screen != null and OS.get_environment("CUCS_SKIP") == "1" and not _skipped and _elapsed > 0.3:
		_skipped = true
		_screen.sim.end_turn()
	var wait: float = float(OS.get_environment("CUCS_WAIT")) if OS.get_environment("CUCS_WAIT") != "" else 2.0
	if _elapsed >= wait:
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = "/tmp/claude-1000/cucs_capture_%d.png" % _map
		if OS.get_environment("CUCS_OUT") != "":
			path = OS.get_environment("CUCS_OUT")
		DirAccess.make_dir_recursive_absolute("/tmp/claude-1000")
		var err: int = img.save_png(path)
		print("CAPTURE: %s (%dx%d) err=%d fps=%d" % [path, img.get_width(), img.get_height(), err, Engine.get_frames_per_second()])
		set_process(false)
		get_tree().quit()

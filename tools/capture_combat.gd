## Opens a quick match in a real window, lets it run for ~2 s and saves a screenshot, then quits.
##   CUCS_MAP=3 godot --path . res://tools/CaptureCombat.tscn      (output: /tmp/claude-1000/cucs_capture_<map>.png)
## Optional env vars: CUCS_WAIT (seconds, default 2), CUCS_FIRE (1 = fire the first weapon after 0.5 s),
## CUCS_CAM ("x,y,zoom": freeze the camera there).
extends Node

var _screen: CombatScreen = null
var _elapsed: float = 0.0
var _map: int = 0
var _fired: bool = false


func _ready() -> void:
	_map = int(OS.get_environment("CUCS_MAP")) if OS.get_environment("CUCS_MAP") != "" else 0
	_screen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
	_screen.auto_start = false
	add_child(_screen)
	var cfg := MatchConfig.new()
	cfg.map_idx = _map
	GameState.map_idx = _map
	cfg.game_mode = "2P_LOCAL"
	cfg.worms_per_team = 4
	var sim := CombatSim.new()
	sim.setup(cfg)
	_screen.start(sim)
	var cam_env: PackedStringArray = OS.get_environment("CUCS_CAM").split(",")
	if cam_env.size() >= 3:
		_screen.cam.locked = true
		_screen.cam.x = float(cam_env[0])
		_screen.cam.y = float(cam_env[1])
		_screen.cam.zoom = float(cam_env[2])


func _process(delta: float) -> void:
	_elapsed += delta
	if OS.get_environment("CUCS_FIRE") == "1" and not _fired and _elapsed > 0.5:
		_fired = true
		_screen.sim.call("begin_charge_or_fire")
		_screen.sim.call("release_charge")
	var wait: float = float(OS.get_environment("CUCS_WAIT")) if OS.get_environment("CUCS_WAIT") != "" else 2.0
	if _elapsed >= wait:
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = "/tmp/claude-1000/cucs_capture_%d.png" % _map
		DirAccess.make_dir_recursive_absolute("/tmp/claude-1000")
		var err: int = img.save_png(path)
		print("CAPTURE: %s (%dx%d) err=%d fps=%d" % [path, img.get_width(), img.get_height(), err, Engine.get_frames_per_second()])
		set_process(false)
		get_tree().quit()

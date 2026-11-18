## The battle screen: owns a CombatSim, runs the frame loop (port of main.js loop()), the human input controller, the camera,
## the effect pools and the view layers, and instances the HUD scenes of combat/hud/ when they exist.
class_name CombatScreen
extends Node

const SIM_SCRIPT: String = "res://combat/sim/combat_sim.gd"
const HUD_SCENES: Array[String] = ["res://combat/hud/TopHud.tscn", "res://combat/hud/BottomHud.tscn", "res://combat/hud/VictoryModal.tscn"]
const SLOW_MO_FACTOR: float = 0.38

## When true the screen creates its own CombatSim from GameState on _ready (set false to call start() yourself).
var auto_start: bool = true
var sim: Object = null
var cam := CameraRig.new()
var view: CombatView = null
var input: CombatInput = null
var hud_layer: CanvasLayer = null
## Animation clock in seconds of slowed game time (JS tNow).
var t_now: float = 0.0
var shake: float = 0.0
var flash_light: float = 0.0
var flash_pos: Vector2 = Vector2(1600, 400)
var hit_stop: float = 0.0
var slow_mo: float = 0.0
var _seen_tracked: Variant = null
var _airstrike_index: int = -1
var spotlight: float = 0.0
var huds: Array[Node] = []
var rotate_overlay: RotateOverlay = null
var _unlocked: bool = false


func _ready() -> void:
	view = CombatView.new()
	add_child(view)
	input = CombatInput.new()
	input.cam = cam
	add_child(input)
	input.restart_requested.connect(_on_restart_requested)
	input.sound_requested.connect(_on_input_sound)
	input.ripple_requested.connect(_on_ripple_requested)
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	rotate_overlay = (load("res://ui/menus/RotateOverlay.tscn") as PackedScene).instantiate() as RotateOverlay
	var rotate_layer := CanvasLayer.new()
	rotate_layer.layer = 20
	add_child(rotate_layer)
	rotate_layer.add_child(rotate_overlay)
	if auto_start:
		var s: Object = create_sim()
		if s != null:
			start(s)


## Creates a CombatSim from GameState (null when the sim is not available).
func create_sim() -> Object:
	if not ResourceLoader.exists(SIM_SCRIPT):
		push_warning("CombatScreen: combat/sim/combat_sim.gd not found")
		return null
	var script: GDScript = load(SIM_SCRIPT) as GDScript
	var s: Object = script.new()
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("make_match_config"):
		s.call("setup", gs.call("make_match_config"))
	return s


## Binds an (already set up) sim to this screen and resets the frame state.
func start(sim_obj: Object) -> void:
	sim = sim_obj
	_connect_sim()
	view.setup(sim)
	input.sim = sim
	cam.playing = ViewUtil.gb(sim, "playing", true)
	var a: Variant = ViewUtil.g(sim, "active_fighter")
	if a != null:
		cam.x = ViewUtil.gf(a, "x")
		cam.y = ViewUtil.gf(a, "y") - 35.0
		cam.target_x = cam.x
		cam.target_y = cam.y
	t_now = 0.0
	shake = 0.0
	flash_light = 0.0
	hit_stop = 0.0
	slow_mo = 0.0
	spotlight = 1.9
	_instance_huds()


func _connect_sim() -> void:
	_try_connect("sfx", _on_sfx)
	_try_connect("float_text", _on_float_text)
	_try_connect("speech_bubble", _on_speech_bubble)
	_try_connect("effect", _on_effect)
	_try_connect("camera_focus", _on_camera_focus)
	_try_connect("screen_shake", _on_screen_shake)
	_try_connect("flash", _on_flash)
	_try_connect("hit_stop", _on_hit_stop)
	_try_connect("slow_mo", _on_slow_mo)
	_try_connect("terrain_changed", _on_terrain_changed)
	_try_connect("turn_started", _on_turn_started)


func _try_connect(sig: String, fn: Callable) -> void:
	if sim.has_signal(sig):
		sim.connect(sig, fn)
	else:
		push_warning("CombatScreen: sim has no signal '%s'" % sig)


func _instance_huds() -> void:
	for h in huds:
		h.queue_free()
	huds.clear()
	for path in HUD_SCENES:
		if not ResourceLoader.exists(path):
			continue
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			continue
		var inst: Node = ps.instantiate()
		hud_layer.add_child(inst)
		huds.append(inst)
		if inst.has_method("bind"):
			inst.call("bind", sim)
		if inst.has_signal("zoom_requested"):
			inst.connect("zoom_requested", _on_zoom_requested)
		if inst.has_signal("center_requested"):
			inst.connect("center_requested", cam.reset_pan)
		if inst.has_signal("fighter_pip_pressed"):
			inst.connect("fighter_pip_pressed", _on_pip_pressed)


# ---------------------------------------------------------------- frame loop (main.js loop())

func _process(delta: float) -> void:
	if sim == null:
		return
	var raw_dt: float = minf(delta, 0.033)
	sim.set("rotate_prompt_open", rotate_overlay.is_open)
	input.blocked = rotate_overlay.is_open
	var snd: Node = get_node_or_null("/root/Sound")
	if snd != null:
		snd.call("update_ambient", ViewUtil.gf(sim, "wind"), ViewUtil.gb(sim, "playing", true))
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if sim.has_method("advance_real"):
		sim.call("advance_real", raw_dt)
	if hit_stop > 0.0:
		hit_stop -= raw_dt
		_render(vs)
		return
	var dt: float = raw_dt
	if slow_mo > 0.0:
		slow_mo -= raw_dt
		dt = raw_dt * SLOW_MO_FACTOR
	t_now += dt
	if shake > 0.0:
		shake *= pow(0.04, dt)
	if flash_light > 0.0:
		flash_light = maxf(0.0, flash_light - dt * 2.6)
	if spotlight > 0.0:
		spotlight = maxf(0.0, spotlight - dt)
	view.atmo.update(dt, ViewUtil.gf(sim, "wind"), t_now)
	input.tick(raw_dt)
	sim.call("step", dt)
	if sim.get("impact_tracked_worm") != _seen_tracked:
		_seen_tracked = sim.get("impact_tracked_worm")
		cam.impact_tracked = _seen_tracked
	view.fx.spawn_projectile_puffs(ViewUtil.g(sim, "projectiles", []))
	cam.playing = ViewUtil.gb(sim, "playing", true)
	cam.update_targets(sim, t_now, slow_mo > 0.0, input.moving_keys_held(), ViewUtil.gi(sim, "selected_weapon_idx") == _airstrike_idx())
	cam.step(raw_dt)
	var terr: Variant = ViewUtil.g(sim, "terrain")
	view.fx.update(dt, ViewUtil.gf(sim, "wind"), terr, ViewUtil.gf(terr, "water_y", 700.0))
	_render(vs)


## Index of the airstrike weapon in the sim's weapon list (the camera frees itself for map targeting).
func _airstrike_idx() -> int:
	if _airstrike_index < 0 and sim.has_method("weapon_index"):
		_airstrike_index = int(sim.call("weapon_index", "AIRSTRIKE"))
	return _airstrike_index


func _render(vs: Vector2) -> void:
	var ctx: ViewCtx = view.ctx
	ctx.read_sim(sim, t_now)
	ctx.team_hats = _team_hats()
	var gs: Node = get_node_or_null("/root/GameState")
	ctx.custom_faces = gs.get("custom_faces") if gs != null and gs.get("custom_faces") is Array else []
	ctx.flash_light = flash_light
	ctx.flash_pos = flash_pos
	ctx.spotlight_timer = spotlight
	ctx.human_turn = ctx.playing and not bool(sim.call("is_current_turn_ai")) if sim.has_method("is_current_turn_ai") else ctx.playing
	input.drawer_open = _drawer_open()
	view.render(cam, vs, shake)


func _team_hats() -> Array:
	var h: Variant = ViewUtil.g(ViewUtil.g(sim, "cfg"), "team_hats", ViewUtil.g(sim, "team_hats"))
	if h is Array and (h as Array).size() >= 2:
		return h
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		var gh: Variant = gs.get("team_hats")
		if gh is Array and (gh as Array).size() >= 2:
			return gh
	return ["CATALAN", "BANDOLER"]


func _drawer_open() -> bool:
	for h in huds:
		if h.has_method("is_drawer_open") and bool(h.call("is_drawer_open")):
			return true
	return false


func _input(event: InputEvent) -> void:
	if _unlocked or not (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch):
		return
	_unlocked = true
	var snd: Node = get_node_or_null("/root/Sound")
	if snd != null:
		snd.call("unlock")


# ---------------------------------------------------------------- sim signals

func _on_sfx(sfx_name: String, params: Dictionary) -> void:
	_play_sound(sfx_name, params)


func _play_sound(sfx_name: String, params: Dictionary) -> void:
	var snd: Node = get_node_or_null("/root/Sound")
	if snd != null and snd.has_method("play"):
		snd.call("play", sfx_name, params)


func _on_float_text(pos: Vector2, text: String, color: Color, life: float) -> void:
	view.fx.add_float_text(pos, text, color, life)


func _on_speech_bubble(fighter: Variant, text: String, life: float) -> void:
	view.fx.add_speech(fighter, text, life)


func _on_effect(kind: String, params: Dictionary) -> void:
	view.fx.spawn(kind, params)


func _on_camera_focus(pos: Vector2, fighter: Variant) -> void:
	cam.focus(pos, fighter)


func _on_screen_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func _on_flash(pos: Vector2, amount: float) -> void:
	flash_pos = pos
	flash_light = amount


func _on_hit_stop(seconds: float, use_max: bool) -> void:
	hit_stop = maxf(hit_stop, seconds) if use_max else seconds


func _on_slow_mo(seconds: float, use_max: bool) -> void:
	slow_mo = maxf(slow_mo, seconds) if use_max else seconds


func _on_terrain_changed(rect: Rect2i) -> void:
	view.terrain_view.on_terrain_changed(rect)


func _on_turn_started(_team: int, _fighter: Variant) -> void:
	cam.clear_impact()
	spotlight = 1.9


# ---------------------------------------------------------------- input signals

func _on_restart_requested() -> void:
	var router: Node = get_node_or_null("/root/ScreenRouter")
	if router != null and router.has_method("go"):
		router.call("go", "combat")


func _on_input_sound(sfx_name: String) -> void:
	_play_sound(sfx_name, {})


func _on_zoom_requested(delta: float) -> void:
	cam.zoom_user(delta)


## Click on a squad pip: switch to that worm, or peek at it with the camera when switching is not allowed.
func _on_pip_pressed(fighter: Variant) -> void:
	if sim == null or fighter == null:
		return
	if input.switch_worm(fighter):
		return
	var a: Variant = ViewUtil.g(sim, "active_fighter")
	if a != null and ViewUtil.gb(fighter, "alive"):
		cam.pan_x = clampf(ViewUtil.gf(fighter, "x") - ViewUtil.gf(a, "x"), -CameraRig.TERRAIN_W * 0.85, CameraRig.TERRAIN_W * 0.85)
		cam.pan_y = clampf(ViewUtil.gf(fighter, "y") - ViewUtil.gf(a, "y"), -360.0, 320.0)


func _on_ripple_requested(pos: Vector2, label: String, color: Color, _is_world: bool) -> void:
	view.fx.add_touch_ripple(pos, label, color)

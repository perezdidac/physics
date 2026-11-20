## Real-time platformer screen (the egg stage of the story mode). Owns a PlatformSim and runs it at a fixed 1/60 s step, draws the
## level procedurally, follows Perleta with a smooth camera, reads keyboard and touch, and hands the result to the story results.
## The sim is the source of truth; this node only draws it and forwards the input. See docs/platform_contracts.md.
class_name PlatformScreen
extends Node

const STEP: float = 1.0 / 60.0
const MAX_STEPS_PER_FRAME: int = 6
const END_DELAY: float = 1.5
## The hatching celebration needs a little longer.
const HATCH_DELAY: float = 3.2
## Metamorphosis (the pupa opens) and the final egg laying take longer still.
const META_DELAY: float = 4.6
const LAY_DELAY: float = 7.0
## Seconds the night takes to turn into dawn after the eggs are laid.
const DAWN_TIME: float = 4.5
## World pixels shown from top to bottom in a boss arena: the wasp flies above the egg and both must stay in view.
const BOSS_VIEW_HEIGHT: float = 640.0
## World pixels of sky the camera may show above a DIG level.
const DIG_SKY: float = 130.0
## World pixels shown from top to bottom in the hoopoe level, and how far the camera leans towards the surface (the bird stays in view).
const HOOPOE_VIEW_HEIGHT: float = 540.0
const HOOPOE_LEAN: float = 0.3
const FALLBACK_LEVEL := "res://data/levels/egg_1.tres"

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
## Extra input added to the keyboard / touch input (tests and captures drive the level with these): -1/0/1 each, and the jump button.
var debug_move: int = 0
var debug_vert: int = 0
var debug_jump: bool = false
## False in tests and captures that call start() themselves.
var auto_start: bool = true

## Owned hub upgrades for the level (read from the save when the screen starts itself; tests leave it empty).
var upgrades: Array[String] = []
var sim: PlatformSim = null
var level: LevelDef = null
var layout: PlatformLayout = null
var cam := PlatformCamera.new()
var t_now: float = 0.0
var paused: bool = false
var ended: bool = false
var end_timer: float = -1.0
var rotate_overlay: RotateOverlay = null

var backdrop: PlatformBackdrop
var world: Node2D
var world_view: PlatformWorldView
var actors: Array[PlatformActorView] = []
var player_view: PlatformActorView
var fx: PlatformFxView
var weather: PlatformWeatherView
var boss_view: PlatformBossView
var hud: PlatformHud
## "" (egg levels), "DIG" (pupa) or "FLY" (moth), from layout.mode.
var mode: String = ""
var dig_view: PlatformDigView
var fly_back: PlatformFlyView
var fly_front: PlatformFlyView
var hoopoe_view: PlatformHoopoeView
var bat_view: PlatformBatView

var _acc: float = 0.0
var _jump_latch: bool = false
var _sound: Node = null
var _finish_stats: Dictionary = {}
var _boss_total: float = 0.0
var _crumb_t: float = 0.0
var _dawn: float = -1.0


func _ready() -> void:
	_sound = get_node_or_null("/root/Sound")
	backdrop_layer()
	world = Node2D.new()
	add_child(world)
	world_view = PlatformWorldView.new()
	world.add_child(world_view)
	fx = PlatformFxView.new()
	boss_view = PlatformBossView.new()
	weather = PlatformWeatherView.new()
	dig_view = PlatformDigView.new()
	fly_back = PlatformFlyView.new()
	fly_front = PlatformFlyView.new()
	fly_front.layer_name = "front"
	hoopoe_view = PlatformHoopoeView.new()
	bat_view = PlatformBatView.new()
	hud = PlatformHud.new()
	add_child(hud)
	hud.pause_requested.connect(func() -> void: set_paused(true))
	hud.resume_requested.connect(func() -> void: set_paused(false))
	hud.exit_requested.connect(exit_to_map)
	hud.pad.jump_pressed.connect(func() -> void: _jump_latch = true)
	rotate_overlay = load("res://ui/menus/RotateOverlay.tscn").instantiate() as RotateOverlay
	hud.root.add_child(rotate_overlay)
	if auto_start:
		upgrades = StoryProgress.owned_upgrades()
		start(GameState.story_level)


func backdrop_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	backdrop = PlatformBackdrop.new()
	layer.add_child(backdrop)


## Starts `p_level` (a PLATFORM level; any other level falls back to the first egg level).
func start(p_level: LevelDef) -> void:
	level = p_level
	if level == null or level.layout == null:
		level = load(FALLBACK_LEVEL) as LevelDef
	layout = level.layout
	mode = layout.mode if layout.mode == "DIG" or layout.mode == "FLY" else ""
	sim = PlatformSim.new()
	sim.setup(level, upgrades)
	ended = false
	end_timer = -1.0
	_dawn = -1.0
	sim.level_finished.connect(_on_level_finished)
	sim.sfx.connect(_on_sfx)
	sim.float_text.connect(func(pos: Vector2, text: String, color: Color) -> void: fx.float_text(pos, text, color))
	sim.nutrient_taken.connect(_on_nutrient_taken)
	sim.ant_stomped.connect(func(_idx: int, pos: Vector2) -> void: fx.poof(pos))
	sim.checkpoint_reached.connect(_on_checkpoint)
	sim.respawned.connect(_on_respawned)
	_connect_storm_signals()
	_connect_mode_signals()
	backdrop.set_background(layout.background_key)
	world_view.mode = mode
	world_view.night = 1.0 if mode == "FLY" else 0.0
	world_view.setup(sim, layout)
	weather.setup(sim, layout)
	backdrop.storm = 1.0 if weather.storm else 0.0
	backdrop.night = 1.0 if mode == "FLY" else 0.0
	hud.set_mode(mode)
	for a in actors:
		a.queue_free()
	actors.clear()
	for ant in sim.ants:
		var v := PlatformActorView.new()
		v.body = ant
		world.add_child(v)
		actors.append(v)
	player_view = PlatformActorView.new()
	player_view.is_player = true
	player_view.mode = mode
	player_view.extra = sim.dig if mode == "DIG" else sim.fly
	player_view.body = sim.player
	world.add_child(player_view)
	actors.append(player_view)
	for extra: Node2D in [boss_view, hoopoe_view, bat_view, fly_front, fx, weather]:
		if extra.get_parent() != null:
			extra.get_parent().remove_child(extra)
		world.add_child(extra)
	_setup_mode_views()
	boss_view.boss = sim.boss
	boss_view.record(true)
	_boss_total = _boss_seconds()
	for a in actors:
		a.record(true)
	var vs: Vector2 = _view_size()
	cam.phone = hud.pad.is_shown()
	var boss_h: float = PlatformCamera.PHONE_BOSS_VIEW_HEIGHT if cam.phone else BOSS_VIEW_HEIGHT
	cam.fixed_height = boss_h if sim.boss != null or bat_view.boss != null else HOOPOE_VIEW_HEIGHT if layout.boss == "HOOPOE" else 0.0
	cam.extra_top = DIG_SKY if mode == "DIG" else 0.0
	cam.snap(sim.player.pos, vs, layout.size)
	var touch: bool = hud.pad.is_shown()
	var hint_key: String = "PLAT_HELP_TOUCH" if touch else "PLAT_HELP_KEYS"
	if mode == "DIG":
		hint_key = "PLAT_HELP_DIG_TOUCH" if touch else "PLAT_HELP_DIG_KEYS"
	elif mode == "FLY":
		hint_key = "PLAT_HELP_FLY_TOUCH" if touch else "PLAT_HELP_FLY_KEYS"
	if has_boss():
		hud.show_intro(tr(_boss_intro_key()))
		if mode != "":
			hud.show_hint(tr("PLAT_BOSS_HINT_HOOPOE" if mode == "DIG" else "PLAT_BOSS_HINT_BAT"), 9.0, true)
	else:
		hud.show_hint(tr(hint_key))
	_apply_view(0.0)
	_refresh_hud(0.0)


## True when the level has a boss of any kind (wasp, hoopoe or bat).
func has_boss() -> bool:
	return layout != null and layout.boss != ""


func _boss_intro_key() -> String:
	return "PLAT_BOSS_INTRO_HOOPOE" if layout.boss == "HOOPOE" else "PLAT_BOSS_INTRO_BAT" if layout.boss == "BAT" else "PLAT_BOSS_INTRO"


## Binds the DIG / FLY views to the new sim and puts them in the right order of the world node.
func _setup_mode_views() -> void:
	for n: Node2D in [dig_view, fly_back]:
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
	dig_view.visible = mode == "DIG"
	fly_back.visible = mode == "FLY"
	fly_front.visible = mode == "FLY"
	hoopoe_view.visible = false
	bat_view.visible = false
	hoopoe_view.boss = null
	bat_view.boss = null
	if mode == "DIG":
		var dig: PlatformDig = sim.dig
		world.add_child(dig_view)
		world.move_child(dig_view, 0)
		var surf: float = layout.surface_y
		if surf <= 0.0:
			surf = layout.size.y
			for r in layout.soil:
				surf = minf(surf, r.position.y)
		dig_view.goal = layout.goal if layout.boss == "" else Rect2()
		dig_view.setup(Vector2(dig.cols, dig.rows) * float(PlatformDig.CELL), float(PlatformDig.CELL), surf, dig.cell_at)
		dig_view.stones = dig.stones
		dig_view.rings = dig.noise_rings
		hoopoe_view.boss = dig.hoopoe
		hoopoe_view.record(true)
	elif mode == "FLY":
		world.add_child(fly_back)
		world.move_child(fly_back, world_view.get_index() + 1)
		fly_back.setup(sim.fly, layout)
		fly_front.setup(sim.fly, layout)
		bat_view.boss = sim.fly.bat
		bat_view.pulses = sim.fly.pulses
		bat_view.record(true)
		fly_back.record(true)
		fly_front.record(true)


## Connects the signals of the pupa and moth modes (levels without them never emit these).
func _connect_mode_signals() -> void:
	sim.dig_changed.connect(func(cells: Rect2i) -> void: dig_view.refresh_cells(cells))
	sim.stone_landed.connect(func(idx: int) -> void: _stone_fx(idx, 10))
	sim.stone_broken.connect(func(idx: int, hit: bool) -> void: _stone_fx(idx, 16 if hit else 8))
	sim.stone_wobble.connect(func(idx: int) -> void: _stone_fx(idx, 3))
	sim.lamp_zap.connect(_on_lamp_zap)
	sim.trap_hit.connect(_on_trap_hit)
	sim.nightjar_bite.connect(_on_bite)


func _stone_fx(idx: int, count: int) -> void:
	if sim.dig == null or idx < 0 or idx >= sim.dig.stones.size():
		return
	var st: PlatformStone = sim.dig.stones[idx]
	fx.soil_dust(Vector2(st.pos.x, st.pos.y + PlatformStone.HALF), count)


func _on_lamp_zap(idx: int) -> void:
	if idx >= 0 and idx < layout.lights.size():
		fx.sparkle(Vector2(layout.lights[idx].x, layout.lights[idx].y), Color(1.0, 0.9, 0.5, 1.0), 18)


func _on_trap_hit(idx: int) -> void:
	if idx >= 0 and idx < layout.traps.size():
		fx.sparkle(layout.traps[idx].get_center(), Color(1.0, 0.75, 0.25, 1.0), 16)


func _on_bite(idx: int) -> void:
	var jars: Array[PlatformNightjar] = sim.fly.nightjars
	if idx >= 0 and idx < jars.size():
		fx.sparkle(jars[idx].pos, Color(0.75, 0.6, 0.4, 1.0), 12)


## Connects the storm signals (levels without a storm never emit them).
func _connect_storm_signals() -> void:
	sim.storm_gust.connect(func(dir: int) -> void: weather.gust(dir))
	sim.tuft_flatten.connect(func(idx: int) -> void: fx.dust(Vector2(layout.tufts[idx].get_center().x, layout.tufts[idx].end.y), 14))
	sim.splash.connect(func(pos: Vector2, kind: String) -> void: weather.add_splash(pos, kind))


## Seconds the boss level lasts (0 without a boss).
func _boss_seconds() -> float:
	return layout.boss_time if has_boss() else 0.0


## Seconds left until the egg hatches.
func boss_time_left() -> float:
	return sim.time_left


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	tick(minf(delta, 0.1))


## One frame of logic and drawing for `delta` seconds (called by _process; tests call it directly).
func tick(delta: float) -> void:
	if sim == null:
		return
	t_now += delta
	var rotating: bool = rotate_overlay != null and rotate_overlay.is_open
	if not paused and not rotating:
		if ended:
			sim.set_move(0)
			sim.set_vertical(0)
			sim.set_jump(false)
		else:
			sim.set_move(_move_dir())
			sim.set_vertical(_vert_dir())
			sim.set_jump(_jump_held())
		_acc += delta
		var steps: int = 0
		while _acc >= STEP and steps < MAX_STEPS_PER_FRAME:
			for a in actors:
				a.record(false)
			boss_view.record(false)
			_record_mode_views()
			sim.step(STEP)
			_acc -= STEP
			steps += 1
			_jump_latch = false
		if steps == MAX_STEPS_PER_FRAME:
			_acc = 0.0
	_apply_view(delta)
	_refresh_hud(delta)
	_tick_end(delta)


func _move_dir() -> int:
	var dir: int = 0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or hud.pad.left():
		dir -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or hud.pad.right():
		dir += 1
	return clampi(dir + debug_move, -1, 1)


## Vertical input (-1 up, 1 down): digging only.
func _vert_dir() -> int:
	if mode != "DIG":
		return 0
	var dir: int = 0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or hud.pad.up_held():
		dir -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or hud.pad.down_held():
		dir += 1
	return clampi(dir + debug_vert, -1, 1)


func _jump_held() -> bool:
	var keys: bool = Input.is_key_pressed(KEY_SPACE)
	if mode != "DIG":
		keys = keys or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	return _jump_latch or hud.pad.jump() or keys or debug_jump


func _record_mode_views() -> void:
	hoopoe_view.record(false)
	bat_view.record(false)
	fly_back.record(false)
	fly_front.record(false)


func _apply_view(delta: float) -> void:
	var vs: Vector2 = _view_size()
	var p: Node2D = player_view
	var alpha: float = clampf(_acc / STEP, 0.0, 1.0)
	for a in actors:
		a.present(alpha, t_now, delta)
	var ppos: Vector2 = p.position
	if layout.boss == "HOOPOE":
		ppos.y = lerpf(ppos.y, layout.surface_y, HOOPOE_LEAN)
	if delta > 0.0:
		cam.follow(delta, ppos, sim.player.facing, sim.player.vel.x, vs, layout.size)
	world.scale = Vector2(cam.zoom, cam.zoom)
	world.position = cam.world_offset(vs) - weather.nudge * cam.zoom
	world_view.t_now = t_now
	world_view.view_rect = cam.visible_rect(vs)
	world_view.queue_redraw()
	weather.t_now = t_now
	weather.view_rect = world_view.view_rect
	weather.update(delta)
	backdrop.flash = weather.flash
	boss_view.present(alpha, t_now, delta)
	_present_mode_views(alpha, delta)
	fx.t_now = t_now
	fx.hiding = sim.player.hidden
	fx.hide_ground = Vector2(sim.player.pos.x, sim.player.pos.y + sim.player.radius)
	fx.update(delta)
	var scroll := Vector2(maxf(layout.size.x - vs.x / cam.zoom, 1.0), maxf(layout.size.y - vs.y / cam.zoom, 1.0))
	var half: Vector2 = vs / (2.0 * cam.zoom)
	backdrop.progress = Vector2(clampf((cam.pos.x - half.x) / scroll.x, 0.0, 1.0), clampf((cam.pos.y - half.y) / scroll.y, 0.0, 1.0))
	backdrop.view_size = vs
	backdrop.t_now = t_now
	backdrop.queue_redraw()


## Pushes the frame data to the DIG / FLY views.
func _present_mode_views(alpha: float, delta: float) -> void:
	var vr: Rect2 = world_view.view_rect
	world_view.night = 1.0 - clampf(_dawn / DAWN_TIME, 0.0, 1.0) if mode == "FLY" and _dawn >= 0.0 else world_view.night
	if _dawn >= 0.0:
		fly_front.visible = false
		fly_back.visible = false
		_dawn += delta
		backdrop.night = 1.0 - clampf(_dawn / DAWN_TIME, 0.0, 1.0)
	if mode == "DIG":
		var dig: PlatformDig = sim.dig
		dig_view.t_now = t_now
		dig_view.view_rect = vr
		dig_view.water_y = minf(dig.water_y, 100000.0)
		dig_view.stones = dig.stones
		dig_view.rings = dig.noise_rings
		dig_view.refresh()
		hoopoe_view.present(alpha, t_now, delta)
		_dig_fx(delta)
	elif mode == "FLY":
		for v: PlatformFlyView in [fly_back, fly_front]:
			v.t_now = t_now
			v.view_rect = vr
			v.player_pos = sim.player.pos
			v.present(alpha, delta)
		bat_view.player_pos = sim.player.pos
		bat_view.player_hidden = sim.player.hidden
		bat_view.present(alpha, t_now, delta)
		bat_view.pulses = sim.fly.pulses


## Crumbs flying off the pupa while she digs.
func _dig_fx(delta: float) -> void:
	var dig: PlatformDig = sim.dig
	if dig.digging and not ended:
		_crumb_t -= delta
		if _crumb_t <= 0.0:
			_crumb_t = 0.07
			var dir: Vector2 = dig.dig_dir
			fx.crumbs(sim.player.pos + dir * (sim.player.radius + 2.0), dir, 2)
	dig_view.drown = dig.drown / PlatformDig.DROWN_TIME
	dig_view.player_pos = sim.player.pos


func _refresh_hud(delta: float) -> void:
	var taken: int = 0
	for b: bool in sim.nutrients_taken:
		taken += 1 if b else 0
	hud.refresh(sim.player.hearts, sim.player.max_hearts, taken, layout.nutrients.size(), delta)
	if has_boss() and not ended:
		hud.set_boss_time(boss_time_left(), _boss_total, mode)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_jump_latch = true
		KEY_W, KEY_UP:
			_jump_latch = mode != "DIG"
		KEY_ESCAPE, KEY_P:
			get_viewport().set_input_as_handled()
			set_paused(not paused)


## Opens or closes the pause menu (the sim stops).
func set_paused(value: bool) -> void:
	if ended:
		return
	paused = value
	hud.set_paused(value)


## Leaves to the campaign map.
func exit_to_map() -> void:
	UiUtil.sfx("tick")
	_go("story_map")


func _go(screen_name: String) -> void:
	if go_callable.is_valid():
		go_callable.call(screen_name)
	else:
		ScreenRouter.go(screen_name)


# ---------------------------------------------------------------- sim signals

func _on_sfx(sfx_name: String, params: Dictionary) -> void:
	if _sound != null and _sound.has_method("has_sound") and _sound.call("has_sound", sfx_name):
		_sound.call("play", sfx_name, params)
	if (sfx_name == "jump" and mode != "FLY") or (sfx_name == "hard_slam" and mode != "DIG"):
		fx.dust(Vector2(sim.player.pos.x, sim.player.pos.y + sim.player.radius), 5)


func _on_nutrient_taken(idx: int) -> void:
	if idx >= 0 and idx < layout.nutrients.size():
		fx.sparkle(layout.nutrients[idx], Color(1.0, 0.85, 0.35, 1.0), 14)


func _on_checkpoint(idx: int) -> void:
	if idx >= 0 and idx < layout.checkpoints.size():
		fx.sparkle(layout.checkpoints[idx] + Vector2(10.0, -34.0), Color(1.0, 0.9, 0.4, 1.0), 16)


func _on_respawned() -> void:
	for a in actors:
		a.record(true)
	cam.snap(sim.player.pos, _view_size(), layout.size)


func _on_level_finished(stats: Dictionary) -> void:
	if ended:
		return
	ended = true
	_finish_stats = stats
	GameState.story_result = stats
	end_timer = END_DELAY
	hud.pad.release_all()
	var won: bool = bool(stats.get("won", false))
	var reason: String = str(stats.get("reason", ""))
	if won and reason == "METAMORPHOSIS":
		end_timer = META_DELAY
		player_view.visible = false
		hoopoe_view.boss = null
		hoopoe_view.visible = false
		hud.boss_bar.visible = false
		fx.metamorphosis(sim.player.pos)
		hud.show_banner(tr("PLAT_BANNER_METAMORPHOSIS"), true, true)
		UiUtil.sfx("victory")
		return
	if won and reason == "EGGS_LAID":
		end_timer = LAY_DELAY
		bat_view.boss = null
		bat_view.visible = false
		hud.boss_bar.visible = false
		fx.lay_eggs(sim.player.pos, float(sim.player.facing))
		_dawn = 0.0
		hud.show_banner(tr("PLAT_BANNER_EGGS_LAID"), true, true)
		hud.show_sub_banner(tr("PLAT_BANNER_CYCLE"))
		UiUtil.sfx("victory")
		return
	var hatched: bool = won and reason == "HATCHED"
	if hatched:
		end_timer = HATCH_DELAY
		player_view.visible = false
		boss_view.boss = null
		hud.boss_bar.visible = false
		fx.hatch(sim.player.pos)
		hud.show_banner(tr("PLAT_BANNER_HATCHED"), true, true)
		UiUtil.sfx("victory")
		return
	var won_key: String = "PLAT_BANNER_CHAMBER" if mode == "DIG" else "PLAT_BANNER_LANDED" if mode == "FLY" else "PLAT_BANNER_WON"
	hud.show_banner(tr(won_key) if won else tr("PLAT_BANNER_LOST"), won)
	if won:
		fx.sparkle(sim.player.pos, Color(1.0, 0.95, 0.6, 1.0), 24)
		UiUtil.sfx("victory")


func _tick_end(delta: float) -> void:
	if end_timer < 0.0:
		return
	end_timer -= delta
	if end_timer < 0.0:
		end_timer = -1.0
		_go("story_results")

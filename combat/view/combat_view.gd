## Builds and draws the whole battle picture in the JS render() order: sky layers (CanvasLayer behind), the world plane
## (water, terrain, flora, entities, effects, water front) and the screen overlays (weather, trackers, vignette).
class_name CombatView
extends Node

const TERRAIN_W: float = 3200.0

var ctx := ViewCtx.new()
var atmo := ViewAtmosphere.new()
var fx := FxPools.new()
var sky := SkyPainter.new()
var terrain_view: TerrainView = null
var facts: Dictionary = {}
var sim: Object = null

var _sky_cl: CanvasLayer = null
var _over_cl: CanvasLayer = null
var _world: Node2D = null
var _layers: Array[DrawLayer] = []
var _cam: CameraRig = null
var _tr: Dictionary = {"scale": 1.0, "cx": 1600.0, "cy": 400.0}


func _ready() -> void:
	_sky_cl = CanvasLayer.new()
	_sky_cl.layer = -10
	add_child(_sky_cl)
	_add_layer(_sky_cl, _draw_sky_base)
	_add_layer(_sky_cl, _draw_sky_rays, true)
	var veil: DrawLayer = _add_layer(_sky_cl, _draw_sky_veil)
	var veil_mat := ShaderMaterial.new()
	veil_mat.shader = load("res://combat/view/cloud_veil.gdshader") as Shader
	veil_mat.set_shader_parameter("perm_tex", ImageTexture.create_from_image(ViewNoise.perm_image()))
	veil.material = veil_mat
	sky.veil_mat = veil_mat
	_add_layer(_sky_cl, _draw_sky_clouds)

	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_add_layer(_world, _draw_water_back)
	terrain_view = TerrainView.new()
	_world.add_child(terrain_view)
	_add_layer(_world, _draw_actors)
	_add_layer(_world, _draw_fireballs, true)
	_add_layer(_world, _draw_fx_main)
	_add_layer(_world, _draw_flash, true)
	_add_layer(_world, _draw_water_front)
	_add_layer(_world, _draw_reflections, true)
	_add_layer(_world, _draw_top)

	_over_cl = CanvasLayer.new()
	_over_cl.layer = 1
	add_child(_over_cl)
	_add_layer(_over_cl, _draw_overlay)


func _add_layer(parent: Node, fn: Callable, additive: bool = false) -> DrawLayer:
	var l := DrawLayer.new()
	l.draw_fn = fn
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		l.material = m
	parent.add_child(l)
	_layers.append(l)
	return l


## Binds the view to a freshly set-up sim: atmosphere, background, terrain textures.
func setup(sim_obj: Object) -> void:
	sim = sim_obj
	facts = ViewMaps.resolve(sim)
	ctx.map_id = str(facts["id"])
	atmo.generate(facts)
	sky.atmo = atmo
	sky.ctx = ctx
	sky.facts = facts
	sky.bg_tex = ArtCatalog.background(str(facts["bg"]))
	terrain_view.setup(ViewUtil.g(sim, "terrain"))
	fx.clear()


## Positions the layers for the current camera and redraws everything.
func render(cam: CameraRig, view_size: Vector2, shake: float) -> void:
	_cam = cam
	_tr = cam.get_transform(view_size)
	var s: float = _tr["scale"]
	var jitter := Vector2.ZERO
	if shake > 0.2:
		jitter = Vector2(randf() - 0.5, randf() - 0.5) * shake * 1.4
	_world.position = view_size * 0.5 - Vector2(float(_tr["cx"]), float(_tr["cy"])) * s + jitter
	_world.scale = Vector2(s, s)
	_sky_cl.offset = jitter
	_over_cl.offset = jitter
	terrain_view.set_camera(float(_tr["cx"]), float(_tr["cy"]))
	ctx.view_size = view_size
	ctx.scale_px = s
	sky.view = view_size
	sky.scale_px = s
	sky.cx = float(_tr["cx"])
	sky.cy = float(_tr["cy"])
	sky.smooth_mouse = cam.smooth_mouse
	sky.splash = not ctx.playing
	for l in _layers:
		l.queue_redraw()


# ---------------------------------------------------------------- passes

func _draw_sky_base(ci: CanvasItem) -> void:
	sky.draw_base(ci)


func _draw_sky_rays(ci: CanvasItem) -> void:
	sky.draw_rays(ci)


func _draw_sky_veil(ci: CanvasItem) -> void:
	sky.draw_veil(ci)


func _draw_sky_clouds(ci: CanvasItem) -> void:
	sky.draw_clouds(ci)


func _visible_x() -> Vector2:
	var hw: float = ctx.view_size.x * 0.5 / maxf(0.01, float(_tr["scale"]))
	return Vector2(float(_tr["cx"]) - hw, float(_tr["cx"]) + hw)


func _draw_water_back(ci: CanvasItem) -> void:
	var vx: Vector2 = _visible_x()
	WaterView.draw_back(ci, ctx, vx.x, vx.y)


func _draw_actors(ci: CanvasItem) -> void:
	var t: float = ctx.t_now
	ItemArt.draw_flora(ci, ViewUtil.g(sim, "surface_flora", []), ctx)
	ItemArt.draw_shadows(ci, sim, ctx)
	for u in ViewUtil.g(sim, "updrafts", []):
		ItemArt.draw_updraft(ci, u, t)
	for n in ViewUtil.g(sim, "silk_nests", []):
		ItemArt.draw_nest(ci, n, t)
	for w in ViewUtil.g(sim, "silk_webs", []):
		ItemArt.draw_web(ci, w, t)
	for pn in ViewUtil.g(sim, "pine_nuts", []):
		ItemArt.draw_pine_nut(ci, pn, t)
	for sw in ViewUtil.g(sim, "larvae_swarms", []):
		ItemArt.draw_larvae(ci, sw, t)
	for rv in ViewUtil.g(sim, "rovellons", []):
		ItemArt.draw_rovello(ci, rv)
	for cg in ViewUtil.g(sim, "caganers", []):
		ItemArt.draw_caganer(ci, cg, t)
	for ol in ViewUtil.g(sim, "escudelles", []):
		ItemArt.draw_escudella(ci, ol, t)
	for tb in ViewUtil.g(sim, "tombstones", []):
		ItemArt.draw_tombstone(ci, tb)
	for m in ViewUtil.g(sim, "mines", []):
		ItemArt.draw_mine(ci, m, t)
	for c in ViewUtil.g(sim, "crates", []):
		ItemArt.draw_crate(ci, c, t)
	for b in ViewUtil.g(sim, "barrels", []):
		ItemArt.draw_barrel(ci, b)
	for f in ctx.fighters:
		ItemArt.draw_grapple(ci, f)
	ItemArt.draw_tethers(ci, ctx.fighters)
	for f in ctx.fighters:
		if ViewUtil.gb(f, "alive"):
			CaterpillarArt.draw_fighter(ci, f, ctx)
	var act: Variant = ctx.active
	if ctx.playing and ctx.phase == ViewCtx.PH_TURN_PLAY and act != null and ViewUtil.gb(act, "alive") and not ViewUtil.gb(act, "drowning") and ctx.human_turn:
		AimHud.draw(ci, act, ctx)
	for pl in ViewUtil.g(sim, "airstrike_planes", []):
		WeaponArt.draw_plane(ci, pl)
	for p in ctx.projectiles:
		WeaponArt.draw_projectile(ci, p, ctx)


func _draw_fireballs(ci: CanvasItem) -> void:
	fx.draw_fireballs(ci)


func _draw_fx_main(ci: CanvasItem) -> void:
	fx.draw_main(ci)


func _draw_flash(ci: CanvasItem) -> void:
	fx.draw_flash(ci, ctx.flash_light, ctx.flash_pos)


func _draw_water_front(ci: CanvasItem) -> void:
	var vx: Vector2 = _visible_x()
	WaterView.draw_front(ci, ctx, facts, fx.ripples, vx.x, vx.y)


func _draw_reflections(ci: CanvasItem) -> void:
	WaterView.draw_reflections(ci, ctx, fx.fireballs)


func _draw_top(ci: CanvasItem) -> void:
	fx.draw_top(ci, ctx.t_now)


func _draw_overlay(ci: CanvasItem) -> void:
	sky.draw_weather(ci)
	sky.draw_overlay(ci, fx, _cam)

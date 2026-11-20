## Builds and draws the whole battle picture in the JS render() order: sky layers (CanvasLayer behind), the world plane
## (water, terrain, flora, entities, effects, water front) and the screen overlays (weather, trackers, vignette).
class_name CombatView
extends Node

const TERRAIN_W: float = 3200.0

## Registry ids this view draws through (checked by the registry test); flora and creatures are dispatched by type / kind.
const ART_KINDS: Array[String] = [
	"flora:", "shadows", "tuft", "anthill", "convoy_goal", "story_goal", "updraft", "silk_nest", "silk_web", "pine_nut", "larvae", "rovello",
	"caganer", "escudella", "tombstone", "mine", "crate", "barrel", "grapple", "tethers", "nest_back", "convoy_thread", "convoy_reach",
	"nest_frozen", "nest_front", "spores", "weapon:plane", "weapon:projectile", "boar_warning",
]

var ctx := ViewCtx.new()
var actx := ArtContext.new()
var atmo := ViewAtmosphere.new()
var fx := FxPools.new()
var boss_fx := BossFx.new()
var nest_fx := NestFx.new()
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
	_add_layer(_world, _draw_boss)
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
	boss_fx.clear()
	nest_fx.clear()


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
	ctx.cam_pos = Vector2(float(_tr["cx"]), float(_tr["cy"]))
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
	actx.refresh(ctx)
	for fl in ViewUtil.g(sim, "surface_flora", []):
		ArtRegistry.draw("flora:" + ViewUtil.gs(fl, "type"), ci, fl, actx)
	ArtRegistry.draw("shadows", ci, sim, actx)
	for spot in ctx.hiding_spots:
		ArtRegistry.draw("tuft", ci, spot + Vector2(0.0, ctx.spot_ground_dy), actx)
	if ctx.has_anthill:
		ArtRegistry.draw("anthill", ci, null, actx)
	ArtRegistry.draw("convoy_goal", ci, null, actx)
	ArtRegistry.draw("story_goal", ci, null, actx)
	_draw_all(ci, "updraft", "updrafts")
	_draw_all(ci, "silk_nest", "silk_nests")
	_draw_all(ci, "silk_web", "silk_webs")
	_draw_all(ci, "pine_nut", "pine_nuts")
	_draw_all(ci, "larvae", "larvae_swarms")
	_draw_all(ci, "rovello", "rovellons")
	_draw_all(ci, "caganer", "caganers")
	_draw_all(ci, "escudella", "escudelles")
	_draw_all(ci, "tombstone", "tombstones")
	_draw_all(ci, "mine", "mines")
	_draw_all(ci, "crate", "crates")
	_draw_all(ci, "barrel", "barrels")
	for f in ctx.fighters:
		ArtRegistry.draw("grapple", ci, f, actx)
	ArtRegistry.draw("tethers", ci, ctx.fighters, actx)
	ArtRegistry.draw("nest_back", ci, nest_fx, actx)
	ArtRegistry.draw("convoy_thread", ci, null, actx)
	ArtRegistry.draw("convoy_reach", ci, null, actx)
	for f in ctx.fighters:
		if ViewUtil.gb(f, "alive"):
			CaterpillarArt.draw_fighter(ci, f, ctx)
			if ctx.cold_active and ViewUtil.gi(f, "team") == 0 and ViewUtil.gs(f, "kind", "CATERPILLAR") == "CATERPILLAR" and not ctx.in_nest(f):
				ArtRegistry.draw("nest_frozen", ci, f, actx)
	ArtRegistry.draw("nest_front", ci, null, actx)
	ArtRegistry.draw("spores", ci, null, actx)
	var act: Variant = ctx.active
	if ctx.playing and ctx.phase == ViewCtx.PH_TURN_PLAY and act != null and ViewUtil.gb(act, "alive") and not ViewUtil.gb(act, "drowning") and ctx.human_turn and not ctx.no_weapons:
		AimHud.draw(ci, act, ctx)
	for pl in ViewUtil.g(sim, "airstrike_planes", []):
		ArtRegistry.draw("weapon:plane", ci, pl, actx)
	for p in ctx.projectiles:
		ArtRegistry.draw("weapon:projectile", ci, p, actx)


## Draws every entry of the sim list `field` with the registered art of `kind`.
func _draw_all(ci: CanvasItem, kind: String, field: String) -> void:
	var art: ThingArt = ArtRegistry.get_instance().resolve(kind)
	if art == null:
		return
	for e in ViewUtil.g(sim, field, []):
		art.draw(ci, e, actx)


func _draw_boss(ci: CanvasItem) -> void:
	nest_fx.draw_world(ci, ctx)
	BossOverlay.draw(ci, ctx)
	for intent in ctx.boar_intents:
		ArtRegistry.draw("boar_warning", ci, intent, actx)
	boss_fx.draw(ci)


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
	nest_fx.draw_overlay(ci, ctx)

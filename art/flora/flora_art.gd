## Base of the wind-swaying surface plants of the map (drawSurfaceFlora). State: one flora entry of the sim
## ({x, y, type, variant, scale, phase}). Subclasses (one per plant type) draw the plant in a frame whose origin is the plant
## foot, already swayed and scaled; ids are "flora:<TYPE>" with "flora:" as the default plant.
class_name FloraArt
extends ThingArt

## World size of one 128-unit sprite viewBox of a plant, and the foot of the plant inside it.
const SPRITE_BOX: float = 26.0
const SPRITE_FOOT := Vector2(64.0, 113.0)

static var _textures: Dictionary = {}


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var phase: float = ViewUtil.gf(state, "phase")
	var sway: float = sin(ctx.t * 2.8 + phase) * (0.08 + absf(ctx.wind) * 0.0028) + ctx.wind * 0.0035
	var sc: float = ViewUtil.gf(state, "scale", 1.0)
	ArtKit.place(ci, ViewUtil.pos(state), sway, Vector2(sc, sc))
	_draw_plant(ci, state, ViewUtil.gi(state, "variant"), sway, sc)
	ArtKit.reset(ci)


## One plant in the local frame (origin = foot). `fl` is the flora entry (for plants that re-place themselves).
func _draw_plant(_ci: CanvasItem, _fl: Variant, _variant: int, _sway: float, _sc: float) -> void:
	pass


func sample_state() -> Variant:
	return {"x": 0.0, "y": 0.0, "type": "", "variant": 0, "scale": 1.0, "phase": 0.0}


## Draws assets/sprites/flora/<name>_<variant>.svg (variant clamped to the `count` files that exist) with its foot at the local
## origin; false when the file is missing so the subclass draws its vector plant.
func _draw_sprite(ci: CanvasItem, name: String, variant: int, count: int = 1) -> bool:
	var p: String = "res://assets/sprites/flora/%s_%d.svg" % [name, clampi(variant, 0, count - 1)]
	if not _textures.has(p):
		_textures[p] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	var tex: Texture2D = _textures[p]
	if tex == null:
		return false
	var k: float = SPRITE_BOX / SpriteArt.VIEWBOX
	ci.draw_texture_rect(tex, Rect2(-SPRITE_FOOT * k, Vector2(SpriteArt.VIEWBOX, SpriteArt.VIEWBOX) * k), false)
	return true


## Forgets cached textures (tests).
static func clear_cache() -> void:
	_textures.clear()

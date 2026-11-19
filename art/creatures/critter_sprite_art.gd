## Base of the sprite creatures of the combat view: draws its CreatureRig (cut-out SVG parts driven by the sim phases) and falls back
## to the old vector drawing while a part SVG is missing. Subclasses implement `_draw_rig(ci, state, vc)`.
class_name CritterSpriteArt
extends ThingArt

var rig: CreatureRig = null
var fallback: ThingArt = null
var _sample: Variant = null


func _init(p_rig: CreatureRig, p_fallback: ThingArt, p_sample: Variant = null) -> void:
	rig = p_rig
	fallback = p_fallback
	_sample = p_sample


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	if rig == null or not rig.is_complete():
		if fallback != null:
			fallback.draw(ci, state, ctx)
		return
	_draw_rig(ci, state, ctx.combat if ctx.combat != null else ViewCtx.new())
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## True when every part SVG of the rig(s) exists.
func is_sprite_complete() -> bool:
	return rig != null and rig.is_complete()


static func cast(a: ThingArt) -> CritterSpriteArt:
	return a as CritterSpriteArt


func _draw_rig(_ci: CanvasItem, _state: Variant, _vc: ViewCtx) -> void:
	pass


func vector_fallback() -> ThingArt:
	return fallback


func sample_state() -> Variant:
	if _sample != null:
		return _sample
	return fallback.sample_state() if fallback != null else null


func sample_extent() -> Vector2:
	return fallback.sample_extent() if fallback != null else Vector2(48.0, 48.0)


## Tint of a drowning creature: blended towards water blue.
static func drown_tint(drowning: bool) -> Color:
	return Color(0.72, 0.86, 1.0) if drowning else Color.WHITE


## Red hit flash over the body (hurt_timer fades).
static func hurt_flash(ci: CanvasItem, c: Vector2, rx: float, ry: float, hurt: float, rot: float = 0.0) -> void:
	if hurt > 0.0:
		ArtKit.fill_ellipse(ci, c, rx, ry, Color(1.0, 0.25, 0.2, clampf(hurt, 0.0, 1.0) * 0.4), rot)


## Blue wash over a drowning creature (the sprite itself is only tinted).
static func water_wash(ci: CanvasItem, c: Vector2, rx: float, ry: float, drowning: bool, rot: float = 0.0) -> void:
	if drowning:
		ArtKit.fill_ellipse(ci, c, rx, ry, Color(0.35, 0.62, 0.85, 0.2), rot)

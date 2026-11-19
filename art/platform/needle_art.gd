## A giant pine needle pair (a one-way platform), darkened by the night amount: assets/sprites/platform_props/needle.svg stretched along the
## platform rectangle, plus the needle_sheath.svg where the pair joins the twig. State: its Rect2.
class_name NeedleArt
extends ThingArt

const IDS: Array[String] = ["needle", "needle_sheath"]
var _fallback: ThingArt = NeedleVectorArt.new()


func vector_fallback() -> ThingArt:
	return _fallback


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	if not PlatformSprites.has_all(IDS):
		_fallback.draw(ci, state, ctx)
		return
	var r: Rect2 = state
	var th: float = clampf(r.size.y * 0.6, 6.0, 10.0)
	var mod: Color = ArtKit.night_tint("#ffffff", ctx.night)
	# the body occupies the 16 middle units of the 32-unit-high sprite: they map to `th` world px
	var sy: float = th / 16.0
	ci.draw_texture_rect(PlatformSprites.tex("needle"), Rect2(r.position.x, r.position.y - 8.0 * sy, r.size.x, 32.0 * sy), false, mod)
	# sheath: its 44 x 52 body units map to 12 x (th + 2) px
	var sx: float = 12.0 / 44.0
	var shy: float = (th + 2.0) / 52.0
	ci.draw_texture_rect(PlatformSprites.tex("needle_sheath"), Rect2(r.position.x - 3.0 - 10.0 * sx, r.position.y - 1.0 - 6.0 * shy, 64.0 * sx, 64.0 * shy), false, mod)


func sample_state() -> Variant:
	return Rect2(-60.0, -6.0, 120.0, 10.0)


func sample_extent() -> Vector2:
	return Vector2(140.0, 30.0)

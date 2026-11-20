## The pine-needle tuft (hiding spot of the story mode): three needle bunches (assets/sprites/scene/tuft_l/c/r.svg) that each sway
## about the base of the tuft, over a code-drawn contact shadow. State: the ground point (Vector2).
class_name TuftSpriteArt
extends SpriteArt

## Wide drawing (256 x 128): world size of its width, and the base point inside it.
const WIDTH: float = 72.0
const BASE := Vector2(128.0, 120.0)
const PARTS: Array[String] = ["tuft_l", "tuft_c", "tuft_r"]


func _init(p_fallback: ThingArt = null) -> void:
	super("scene", "tuft_c", WIDTH, p_fallback)


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var ground: Vector2 = state
	var texs: Array[Texture2D] = []
	for part in PARTS:
		var p: String = "%s%s/%s.svg" % [ROOT, group, part]
		if not _textures.has(p):
			_textures[p] = load(p) as Texture2D if ResourceLoader.exists(p) else null
		if _textures[p] == null:
			if fallback != null:
				fallback.draw(ci, state, ctx)
			return
		texs.append(_textures[p])
	var k: float = WIDTH / 256.0
	ArtKit.soft_shadow(ci, ground + Vector2(0.0, 1.0), 20.0, 3.4, 0.34)
	for i in 3:
		var sway: float = sin(ctx.t * 1.3 + float(i) * 1.9 + ground.x) * 0.045 * (1.0 + 0.4 * absf(ctx.wind) * 0.02)
		ci.draw_set_transform_matrix(Transform2D(sway, Vector2.ONE, 0.0, ground + Vector2(0.0, 0.5)))
		ci.draw_texture_rect(texs[i], Rect2(-BASE * k, Vector2(256.0, 128.0) * k), false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func sample_state() -> Variant:
	return Vector2(0.0, 0.0)


func sample_extent() -> Vector2:
	return Vector2(60.0, 36.0)

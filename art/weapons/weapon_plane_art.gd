## The airstrike plane: assets/sprites/weapons/plane.svg (nose to +x, flipped when flying left) with the code-drawn exhaust flame.
## State: the sim plane (x, y, vx).
class_name WeaponPlaneArt
extends SpriteArt

static var _rng := RandomNumberGenerator.new()


func _init() -> void:
	super("weapons", "plane", 128.0, null)
	anchor = Vector2(64.0, 62.0)
	set_sample({"x": 0.0, "y": 0.0, "vx": 1.0})


func sample_extent() -> Vector2:
	return Vector2(120.0, 60.0)


func vector_fallback() -> ThingArt:
	return null


func draw(ci: CanvasItem, pl: Variant, _ctx: ArtContext) -> void:
	if texture() == null:
		WeaponArt.draw_plane(ci, pl)
		return
	var flip: float = -1.0 if ViewUtil.gf(pl, "vx") < 0.0 else 1.0
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(flip, 1.0), 0.0, ViewUtil.pos(pl)))
	ArtKit.poly(ci, PackedVector2Array([Vector2(-44, 0), Vector2(-60.0 - _rng.randf() * 10.0, 2), Vector2(-44, 5)]), ViewColors.h("#ff9b42"), Color(0, 0, 0, 0), 0.0)
	ci.draw_texture_rect(texture(), Rect2(-anchor, Vector2(VIEWBOX, VIEWBOX)), false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

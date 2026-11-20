## The explosive barrel: assets/sprites/props/barrel.svg, scaled so the body is about 2r tall (r = the barrel radius of the sim).
class_name BarrelArt
extends SpriteArt

## World size of the viewBox per unit of barrel radius (the 100-unit-tall body then measures ~2.0 r).
const BOX_PER_R: float = 2.55
## Ground line of the barrel inside the viewBox.
const GROUND_Y: float = 113.0


func _init() -> void:
	super("props", "barrel", 38.0, BarrelVectorArt.new())
	anchor = Vector2(64.0, GROUND_Y)


func _box(state: Variant) -> float:
	return ViewUtil.gf(state, "r", 14.0) * BOX_PER_R


## The sim position is the barrel centre; the sprite stands on the ground r below it.
func _origin(state: Variant, _ctx: ArtContext) -> Vector2:
	return ViewUtil.pos(state) + Vector2(0.0, ViewUtil.gf(state, "r", 14.0))

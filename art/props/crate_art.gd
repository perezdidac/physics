## The supply crate: assets/sprites/props/crate.svg at 20x20 world px. The medkit variant is its own sprite (MedkitArt, medkit.svg); a parachuting wooden crate gets the code-drawn ParachuteArt behind the sprite.
class_name CrateArt
extends SpriteArt

## World size of the viewBox: the 92-unit-wide frame measures 20 px.
const BOX: float = 28.0
const GROUND_Y: float = 110.0

var _parachute := ParachuteArt.new()
var _medkit := MedkitArt.new(CrateVectorArt.new())


func _init() -> void:
	super("props", "crate", BOX, CrateVectorArt.new())
	anchor = Vector2(64.0, GROUND_Y)


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	if ViewUtil.gb(state, "is_medkit"):
		_medkit.draw(ci, state, ctx)
		return
	super.draw(ci, state, ctx)


## The sim position is the crate centre; it stands 10 below it.
func _origin(state: Variant, _ctx: ArtContext) -> Vector2:
	return ViewUtil.pos(state) + Vector2(0.0, 10.0)


func _underlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	_parachute.draw(ci, state, ctx)

## The caganer pickup: assets/sprites/props/caganer.svg (~24 px tall) bobbing on the spot, with its warm glow drawn in code.
class_name CaganerArt
extends SpriteArt

const BOX: float = 31.0
const GROUND_Y: float = 116.0


func _init() -> void:
	super("props", "caganer", BOX, CaganerVectorArt.new())
	anchor = Vector2(62.0, GROUND_Y)


func _bob(state: Variant, ctx: ArtContext) -> float:
	return sin(ctx.t * 3.5 + ViewUtil.gf(state, "bob_phase")) * 1.5


## The sim position is a little above the feet (they land 7 px below it).
func _origin(state: Variant, ctx: ArtContext) -> Vector2:
	return ViewUtil.pos(state) + Vector2(0.0, 7.0 + _bob(state, ctx))


func _underlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	ArtKit.place(ci, ViewUtil.pos(state) + Vector2(0.0, _bob(state, ctx)))
	ViewUtil.radial(ci, Vector2(0, -4), 2.0, 20.0, [[0.0, Color(1.0, 0.8784, 0.4, 0.72)], [1.0, Color(1.0, 0.7647, 0.1961, 0.0)]], 1.0, "cag_glow")
	ArtKit.reset(ci)

## The rovelló mushroom (a healing pickup): assets/sprites/props/rovello.svg with the squash of the sim and a warm glow in code.
class_name RovelloArt
extends SpriteArt

## World size of the viewBox for a mushroom of cap radius 18.
const BOX_AT_18: float = 44.0


func _init() -> void:
	super("props", "rovello", BOX_AT_18, RovelloVectorArt.new())
	anchor = Vector2(64.0, 112.0)


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var tex: Texture2D = texture()
	if tex == null:
		fallback.draw(ci, state, ctx)
		return
	var r: float = ViewUtil.gf(state, "r", 18.0)
	var sq: float = ViewUtil.gf(state, "squash", 1.0)
	var k: float = BOX_AT_18 * r / 18.0 / VIEWBOX
	ArtKit.place(ci, ViewUtil.pos(state) + Vector2(0.0, 2.0), 0.0, Vector2(2.0 - sq, sq))
	ArtKit.radial(ci, Vector2(0, -12), 2.0, r * 1.5, [[0.0, Color(1.0, 0.647, 0.2941, 0.38)], [1.0, Color(1.0, 0.549, 0.1765, 0.0)]], 1.0, "rov_glow")
	ci.draw_texture_rect(tex, Rect2(-anchor * k, Vector2(VIEWBOX, VIEWBOX) * k), false, _modulate(state))
	ArtKit.reset(ci)

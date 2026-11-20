## The pot of escudella over a fire: assets/sprites/props/escudella.svg (iron pot, stones, broth); the fire flicker and the
## bobbing meatball are drawn in code.
class_name EscudellaArt
extends SpriteArt

## World size of the viewBox: the 13 px half width of the pot is 45 units wide.
const BOX: float = 37.0
const GROUND_Y: float = 112.0


func _init() -> void:
	super("props", "escudella", BOX, EscudellaVectorArt.new())
	anchor = Vector2(64.0, GROUND_Y)


## The sim position is the pot's centre; the sprite stands 14 below it.
func _origin(state: Variant, _ctx: ArtContext) -> Vector2:
	return ViewUtil.pos(state) + Vector2(0.0, 14.0)


func _underlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var sp: float = ViewUtil.gf(state, "steam_phase")
	var lit: bool = sin(ctx.t * 9.0 + sp) > 0.0
	var p: Vector2 = ViewUtil.pos(state)
	var core: Color = ArtKit.hex("#ff7b29") if lit else ArtKit.hex("#e03e1a")
	ArtKit.radial(ci, p + Vector2(0.0, 9.0), 2.0, 17.0, [[0.0, Color(core, 0.55)], [1.0, Color(core, 0.0)]], 1.0, "esc_fire_%d" % int(lit))
	ArtKit.fill_ellipse(ci, p + Vector2(0.0, 11.0), 11.0, 3.2, core)


func _overlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var sp: float = ViewUtil.gf(state, "steam_phase")
	var bob: float = sin(ctx.t * 4.5 + sp) * 1.1
	ArtKit.place(ci, ViewUtil.pos(state))
	ArtKit.ellipse_fs(ci, Vector2(-2, -7.2 + bob), 5.2, 3.6, ArtKit.hex("#a86438"), ArtKit.hex("#4a2810"), 1.1, -0.1)
	ArtKit.ellipse_fs(ci, Vector2(-3.4, -8.4 + bob), 2.2, 1.0, Color(1.0, 0.82, 0.6, 0.45), Color.TRANSPARENT, 0.0, -0.2)
	ci.draw_circle(Vector2(4.5, -6.5 - bob * 0.6), 2.8, ArtKit.hex("#fff5df"))
	ci.draw_circle(Vector2(3.8, -7.4 - bob * 0.6), 1.0, Color(1, 1, 1, 0.7))
	ArtKit.reset(ci)

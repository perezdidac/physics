## A silk nest pickup hanging from its thread: assets/sprites/scene/silk_nest.svg pulsing, with a glow and two wriggling larvae in code.
class_name SilkNestArt
extends SpriteArt

## World size of the viewBox per unit of nest radius (the 100-unit-wide cocoon then measures 2.2 r).
const BOX_PER_R: float = 2.82


func _init() -> void:
	super("scene", "silk_nest", 36.0, SilkNestVectorArt.new())
	anchor = Vector2(64.0, 64.0)


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var tex: Texture2D = texture()
	if tex == null:
		fallback.draw(ci, state, ctx)
		return
	var t: float = ctx.t
	var p: Vector2 = ViewUtil.pos(state)
	var sway: float = ViewUtil.gf(state, "sway_phase")
	var r: float = ViewUtil.gf(state, "r", 13.0)
	ci.draw_line(Vector2(ViewUtil.gf(state, "anchor_x"), ViewUtil.gf(state, "anchor_y")), p, Color(0.9608, 0.9412, 0.902, 0.78), 1.8, true)
	ci.draw_line(Vector2(ViewUtil.gf(state, "anchor_x") - 0.6, ViewUtil.gf(state, "anchor_y")), p + Vector2(-0.6, 0.0), Color(1, 1, 1, 0.5), 0.7, true)
	var pulse: float = 1.0 + sin(t * 5.0 + sway) * 0.05
	ArtKit.place(ci, p, 0.0, Vector2(pulse, pulse))
	ArtKit.radial(ci, Vector2.ZERO, 2.0, r * 1.6, [[0.0, Color(1.0, 0.9216, 0.6863, 0.65)], [1.0, Color(1.0, 0.9216, 0.6863, 0.0)]], 1.0, "nest_glow")
	var k: float = r * BOX_PER_R / VIEWBOX
	ci.draw_texture_rect(tex, Rect2(-anchor * k, Vector2(VIEWBOX, VIEWBOX) * k), false)
	for w in [-1, 1]:
		var wx: float = float(w) * 3.5 + sin(t * 7.0 + float(w) + sway) * 2.2
		var wy: float = float(w) * 1.8 + cos(t * 6.0 + float(w)) * 1.5
		ci.draw_polyline(ArtKit.quad_pts(Vector2(wx - 3.5, wy), Vector2(wx, wy - 2.5), Vector2(wx + 3.5, wy + 0.5), 6), Color(0.2549, 0.2039, 0.1647, 0.5), 2.2, true)
	ArtKit.reset(ci)

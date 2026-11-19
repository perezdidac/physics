## A checkpoint flag on its pole; lit once reached. The pole with its stone foot is assets/sprites/platform_props/checkpoint_pole.svg,
## the cloth is a 2-part cutout (checkpoint_flag_lit.svg raised on the tip, checkpoint_flag_dim.svg hanging lower) drawn in strips so
## the wave stays code; the glow of a lit flag is code. State: {i: index, p: foot position, lit: bool}.
class_name CheckpointArt
extends SpriteArt

## The pole is 58 px tall: 93 of the 128 units at this box.
const BOX: float = 80.0
const POLE_H: float = 58.0
const FLAG_W: float = 27.0
const FLAG_H: float = 21.6
const STRIPS: int = 10
## How far the dim flag hangs down the pole.
const DIM_DROP: float = 15.0


func _init() -> void:
	super("platform_props", "checkpoint_pole", BOX, CheckpointVectorArt.new())


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	if not has_sprite() or not PlatformSprites.has_all(["checkpoint_flag_lit", "checkpoint_flag_dim"] as Array[String]):
		fallback.draw(ci, state, ctx)
		return
	super(ci, state, ctx)


func _underlay(ci: CanvasItem, state: Variant, _ctx: ArtContext) -> void:
	if ViewUtil.gb(state, "lit"):
		var tip: Vector2 = _tip(state)
		for k in 4:
			ci.draw_circle(tip + Vector2(12.0, 10.0), 34.0 - float(k) * 7.0, Color(1.0, 0.85, 0.3, 0.06 + float(k) * 0.03))


func _overlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var lit: bool = ViewUtil.gb(state, "lit")
	var i: int = ViewUtil.gi(state, "i")
	var tex: Texture2D = PlatformSprites.tex("checkpoint_flag_lit" if lit else "checkpoint_flag_dim")
	var tip: Vector2 = _tip(state)
	var amp: float = 3.0 if lit else 0.6
	var x0: float = tip.x - 1.0
	var y0: float = tip.y + (1.0 if lit else DIM_DROP)
	var tsz: Vector2 = tex.get_size()
	var step: float = FLAG_W / float(STRIPS)
	for s in STRIPS:
		var u: float = float(s) / float(STRIPS)
		var dy: float = sin(ctx.t * 4.0 + float(i) - u * 3.5) * amp * u
		var src := Rect2(tsz.x * u, 0.0, tsz.x / float(STRIPS), tsz.y)
		ci.draw_texture_rect_region(tex, Rect2(x0 + u * FLAG_W, y0 + dy, step + 0.6, FLAG_H), src)


func _tip(state: Variant) -> Vector2:
	return (state["p"] as Vector2) + Vector2(0.0, -POLE_H)


func sample_state() -> Variant:
	return {"i": 0, "p": Vector2(-10.0, 0.0), "lit": true}

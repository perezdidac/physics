## The proximity mine: assets/sprites/props/mine.svg; the blinking light (fast when triggered) is drawn in code in its socket.
class_name MineArt
extends SpriteArt

const GROUND_Y: float = 104.0


func _init() -> void:
	super("props", "mine", 23.0, MineVectorArt.new())
	anchor = Vector2(64.0, GROUND_Y)


## The sim position is the mine's centre; the sprite stands 5.5 below it.
func _origin(state: Variant, _ctx: ArtContext) -> Vector2:
	return ViewUtil.pos(state) + Vector2(0.0, 5.5)


func _overlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var on: bool = (sin(ctx.t * 32.0) > 0.0) if ViewUtil.gb(state, "triggered") else (sin(ctx.t * 3.0) > 0.7)
	var p: Vector2 = ViewUtil.pos(state) + Vector2(0.0, -2.5)
	if on:
		ArtKit.radial(ci, p, 1.0, 9.0, [[0.0, Color(1.0, 0.25, 0.2, 0.6)], [1.0, Color(1.0, 0.25, 0.2, 0.0)]], 1.0, "mine_glow")
	ci.draw_circle(p, 2.3, ArtKit.hex("#ff3b30") if on else ArtKit.hex("#6e1c18"))
	if on:
		ci.draw_circle(p + Vector2(-0.6, -0.6), 0.8, Color(1.0, 0.85, 0.8, 0.9))

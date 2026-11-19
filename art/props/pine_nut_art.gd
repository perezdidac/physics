## A glowing pine nut that rolls in the wind: assets/sprites/props/pine_nut.svg rocking about its centre, glow in code.
class_name PineNutArt
extends SpriteArt


func _init() -> void:
	super("props", "pine_nut", 14.5, PineNutVectorArt.new())
	anchor = Vector2(64.0, 64.0)


func _rotation(_state: Variant, ctx: ArtContext) -> float:
	return sin(ctx.t * 4.0) * 0.3


func _underlay(ci: CanvasItem, state: Variant, _ctx: ArtContext) -> void:
	ArtKit.radial(ci, ViewUtil.pos(state), 1.0, 11.0, [[0.0, Color(1.0, 0.8824, 0.451, 0.85)], [1.0, Color(1.0, 0.7451, 0.2353, 0.0)]], 1.0, "nut_glow")

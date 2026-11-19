## A few short needles (assets/sprites/scene/tuft_front.svg) in front of a hidden fighter. State: {ground, seed}.
class_name TuftFrontSpriteArt
extends SpriteArt


func _init(p_fallback: ThingArt = null) -> void:
	super("scene", "tuft_front", 19.0, p_fallback)
	anchor = Vector2(64.0, 118.0)


func _origin(state: Variant, _ctx: ArtContext) -> Vector2:
	return state["ground"]


func _flip(state: Variant) -> bool:
	return int(state["seed"]) % 2 == 1


func _rotation(state: Variant, ctx: ArtContext) -> float:
	return sin(ctx.t * 1.4 + float(int(state["seed"]))) * 0.04

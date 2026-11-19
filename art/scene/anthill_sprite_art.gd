## The entrance of the anthill: assets/sprites/scene/anthill.svg (lip of earth, hole, clods) at the top of the mound; the grains on
## the dome, the two ants and the dust puff stay code (AnthillArt). State: none (reads the combat view context).
class_name AnthillSpriteArt
extends SpriteArt


func _init(p_fallback: ThingArt = null) -> void:
	super("scene", "anthill", 32.0, p_fallback)
	anchor = Vector2(64.0, 64.0)


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var tex: Texture2D = texture()
	if tex == null:
		if fallback != null:
			fallback.draw(ci, state, ctx)
		return
	AnthillArt.draw(ci, ctx.combat.anthill_pos, ctx.t, ctx.t - ctx.combat.wave_time, tex)

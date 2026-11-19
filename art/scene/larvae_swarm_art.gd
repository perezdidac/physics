## A swarm of four tiny larvae wriggling around a point: assets/sprites/scene/larva_item.svg, each one turned along its path.
class_name LarvaeSwarmArt
extends SpriteArt


func _init() -> void:
	super("scene", "larva_item", 12.0, LarvaeSwarmVectorArt.new())
	anchor = Vector2(64.0, 64.0)


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var tex: Texture2D = texture()
	if tex == null:
		fallback.draw(ci, state, ctx)
		return
	var t: float = ctx.t
	var p: Vector2 = ViewUtil.pos(state)
	var k: float = box / VIEWBOX
	for i in 4:
		var f: float = float(i)
		var lx: float = cos(t * 12.0 + f * 1.6) * 7.0
		var ly: float = sin(t * 15.0 + f * 2.1) * 4.0
		var vel := Vector2(-sin(t * 12.0 + f * 1.6) * 7.0 * 12.0, cos(t * 15.0 + f * 2.1) * 4.0 * 15.0)
		ci.draw_set_transform_matrix(Transform2D(vel.angle(), Vector2(1.0, 1.0), 0.0, p + Vector2(lx, ly)))
		ci.draw_texture_rect(tex, Rect2(-anchor * k, Vector2(VIEWBOX, VIEWBOX) * k), false)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

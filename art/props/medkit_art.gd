## The first-aid crate: assets/sprites/props/medkit.svg at the same 20x20 world px as the wooden crate. The parachute is code.
class_name MedkitArt
extends SpriteArt

var _parachute := ParachuteArt.new()


func _init(p_fallback: ThingArt = null) -> void:
	super("props", "medkit", CrateArt.BOX, p_fallback)
	anchor = Vector2(64.0, CrateArt.GROUND_Y)


func _origin(state: Variant, _ctx: ArtContext) -> Vector2:
	return ViewUtil.pos(state) + Vector2(0.0, 10.0)


func _underlay(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	_parachute.draw(ci, state, ctx)

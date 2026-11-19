## The old procedural drawing of a combat creature, kept as the vector fallback of its sprite art (and for the contact sheet).
class_name CritterVectorArt
extends ThingArt

var kind: String = ""
var _sample: Variant = null
var _extent: Vector2 = Vector2(48.0, 48.0)


func _init(p_kind: String, p_sample: Variant = null, p_extent: Vector2 = Vector2(48.0, 48.0)) -> void:
	kind = p_kind
	_sample = p_sample
	_extent = p_extent


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var vc: ViewCtx = ctx.combat
	match kind:
		"ant": AntArt.draw(ci, state, vc)
		"egg":
			var a: float = ViewUtil.gf(state, "alpha", -1.0)
			if a < 0.0:
				a = 0.45 if ViewUtil.gb(state, "hidden") else 1.0
			EggArt.draw(ci, state, vc, a)
		"caterpillar": CaterpillarArt.draw_body_vector(ci, state, vc)
		"larva": LarvaArt.draw(ci, state, vc)
		"boar": BoarArt.draw(ci, state, vc)
		"calosoma": CalosomaArt.draw(ci, state, vc)
		"forestry": ForestryArt.draw_worker(ci, state, vc)
		"fly": FlyArt.draw(ci, state, vc)
		"bird": BirdArt.draw(ci, state, vc)
		"cuckoo": CuckooArt.draw_vector(ci, state, vc)


func sample_state() -> Variant:
	return _sample


func sample_extent() -> Vector2:
	return _extent

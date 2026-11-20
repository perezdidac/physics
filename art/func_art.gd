## Adapter: wraps an existing static draw function as a ThingArt, so creatures, weapons and scene passes that still live in
## their old classes are reachable through the registry until a phase-2 agent replaces them one by one.
##   reg.add("creature:ANT", FuncArt.new(func(ci, s, c): AntArt.draw(ci, s, c.combat), sample))
class_name FuncArt
extends ThingArt

var _fn: Callable
var _sample: Variant = null
var _extent: Vector2 = Vector2(48.0, 48.0)


## `fn(ci: CanvasItem, state: Variant, ctx: ArtContext)`; `sample` (optional) is the sample state.
func _init(fn: Callable, sample: Variant = null, extent: Vector2 = Vector2(48.0, 48.0)) -> void:
	_fn = fn
	_sample = sample
	_extent = extent


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	_fn.call(ci, state, ctx)


func sample_state() -> Variant:
	return _sample


func sample_extent() -> Vector2:
	return _extent

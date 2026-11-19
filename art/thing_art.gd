## One drawable kind (a barrel, a crate, a pine needle, an ant...). The single interface of the art layer: views never know
## the concrete class, they ask the ArtRegistry for the kind id and call `draw`. Subclasses own exactly one kind.
##   - `state` is whatever the sim hands over for one instance (an object, a Dictionary, a Rect2...), read through ViewUtil.g*.
##   - `ctx` carries the animation clock and the view bits (see ArtContext).
## An art leaves the draw transform at identity when it returns.
class_name ThingArt
extends RefCounted


## Draws one instance of the kind.
func draw(_ci: CanvasItem, _state: Variant, _ctx: ArtContext) -> void:
	pass


## A representative state for the contact sheet and the tests; null = this art cannot be drawn on its own.
func sample_state() -> Variant:
	return null


## The vector art a sprite art falls back to (null for plain vector arts). The contact sheet draws both side by side.
func vector_fallback() -> ThingArt:
	return null


## Nominal on-screen extent (world px) of the sample, used by the contact sheet to size the cell.
func sample_extent() -> Vector2:
	return Vector2(48.0, 48.0)

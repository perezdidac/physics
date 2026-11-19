## A falling stone of the DIG mode (a 28x28 block). Driven by PlatformDig, read by the view.
class_name PlatformStone
extends RefCounted

const HALF: float = 14.0

## Centre.
var pos: Vector2 = Vector2.ZERO
var vel_y: float = 0.0
## "REST" (supported, solid), "WOBBLE" (the soil under it is gone: it shakes for a moment), "FALL", "GONE" (crumbled or shattered; ignore it).
var state: String = "REST"
## Seconds left in WOBBLE.
var timer: float = 0.0
## Seconds the pupa has been digging into it (it crumbles at PlatformDig.CRUMBLE_TIME).
var crumble: float = 0.0


## The stone as a rectangle.
func rect() -> Rect2:
	return Rect2(pos.x - HALF, pos.y - HALF, HALF * 2.0, HALF * 2.0)

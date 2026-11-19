## An expanding ring: a noise ring of the pupa (DIG mode) or an echolocation pulse of the bat (FLY mode).
## Read by the view: draw a circle of `radius` at `pos`, fading with `fade()`.
class_name PlatformRing
extends RefCounted

## Centre (where the noise was made, or where the bat was when it called).
var pos: Vector2 = Vector2.ZERO
## Current radius in px.
var radius: float = 0.0
## The ring vanishes at this radius.
var max_radius: float = 300.0
## Growth in px/s.
var speed: float = 300.0
## True once the ring has been noticed (it reached the surface / it passed over the moth). Each ring triggers at most once.
var heard: bool = false


## 1 at birth, 0 when it vanishes.
func fade() -> float:
	return clampf(1.0 - radius / maxf(max_radius, 1.0), 0.0, 1.0)


## Grows the ring; returns false when it is gone.
func grow(dt: float) -> bool:
	radius += speed * dt
	return radius < max_radius

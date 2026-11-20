## One falling raindrop of the storm (driven by PlatformSim, read by the view).
class_name PlatformDrop
extends RefCounted

## Centre.
var pos: Vector2 = Vector2.ZERO
## Fall speed in px/s.
var speed: float = 560.0
## Collision radius.
var radius: float = 7.0
## y where it will splash (top of the first surface below it); INF over a pit. The view draws a warning shadow there.
var ground_y: float = INF

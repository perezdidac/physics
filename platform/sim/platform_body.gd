## The player's state in the platformer (read by the view, driven by PlatformSim).
class_name PlatformBody
extends RefCounted

## Centre of the egg.
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
## Collision radius (constant; the view may scale the drawing with `growth`).
var radius: float = 14.0
var on_ground: bool = false
## -1 left, 1 right.
var facing: int = 1
## Standing still inside a tuft.
var hidden: bool = false
var hearts: int = 3
var max_hearts: int = 3
## Seconds of invulnerability left (the view may blink).
var invuln: float = 0.0
## Grows while running; use sin() of it for the waddle.
var walk_cycle: float = 0.0
## Draw scale (x, y) of the squash and stretch; (1, 1) at rest.
var squash: Vector2 = Vector2.ONE
## Nutrients taken / total, 0..1.
var growth: float = 0.0
## Seconds left in which the egg may still jump after leaving the ground.
var coyote: float = 0.0
## Seconds left in which a jump press is remembered.
var buffer: float = 0.0
## Seconds in which the player's steering is disabled after a hit.
var hurt_lock: float = 0.0
## True from a jump until landing (enables cutting the jump short).
var jumping: bool = false
## Wind acceleration (px/s²) acting on her right now, 0 outside the wind zones and inside tufts.
var wind: float = 0.0
## Standing in a puddle (slowed down).
var in_puddle: bool = false

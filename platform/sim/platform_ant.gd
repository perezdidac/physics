## One patrolling ant of the platformer (driven by PlatformSim).
class_name PlatformAnt
extends RefCounted

## Centre.
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var radius: float = 12.0
## -1 left, 1 right.
var facing: int = 1
var walk_cycle: float = 0.0
## "PATROL", "CHASE" or "LOST".
var state: String = "PATROL"
## 1 right after biting, fades to 0 (for the jaw animation).
var bite: float = 0.0
## Patrol range and speed (from the layout).
var x_min: float = 0.0
var x_max: float = 0.0
var speed: float = 40.0
## Seconds left looking around after losing the player.
var timer: float = 0.0
## Seconds left of the knock-back after a bite.
var stun: float = 0.0


## The y of the ant's feet.
func feet() -> float:
	return pos.y + radius

## True once stomped: the ant no longer walks, bites or sees; it squashes for `ko_age` seconds and then is `gone`.
var knocked: bool = false
## Seconds since the stomp (drives the squash and poof in the view).
var ko_age: float = 0.0
## The knock-out animation is over: the ant is no longer part of the level (the view hides it).
var gone: bool = false


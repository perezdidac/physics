## The hoopoe, boss of the Crisàlide stage (DIG mode, layout.boss == "HOOPOE"). Driven by PlatformDig, read by the view.
##
## It walks on the surface (`surface_y`). When a noise ring of the pupa reaches the surface it walks to the spot above the noise,
## shows a telegraph (AIM: `target` marker, shadow and dirt trickle for `warn_time` s) and stabs its long beak straight down
## (up to STAB_DEPTH px into the soil, stopping at rock and roots). The beak carves a shaft. Staying still is silent.
## API:
##   pos (centre of the body, standing on the surface), facing (-1/1), radius
##   state: "IDLE" (strolls), "HUNT" (walks to `target`), "AIM" (telegraph), "STAB" (beak going down), "HOLD" (beak stuck), "PULL" (beak coming up), "REST"
##   target: Vector2 (the spot on the surface the strike is aimed at; x follows new noises while HUNT, locked in AIM)
##   timer: seconds left in the state; warn_time: length of the current AIM (telegraph progress = 1 - timer / warn_time)
##   tip_y: world y of the beak tip (== surface_y when the beak is not out); beak_out(): bool; BEAK_HALF: half width of the beak
class_name PlatformHoopoe
extends RefCounted

const WALK_SPEED: float = 70.0
const HUNT_SPEED: Vector2 = Vector2(230.0, 330.0)
const AIM_TIME: Vector2 = Vector2(0.8, 0.6)
const STAB_SPEED: float = 1500.0
const STAB_DEPTH: float = 260.0
const HOLD_TIME: float = 0.3
const PULL_SPEED: float = 420.0
const REST_TIME: Vector2 = Vector2(1.2, 0.8)
const BEAK_HALF: float = 9.0

var pos: Vector2 = Vector2.ZERO
var facing: int = 1
var radius: float = 22.0
var state: String = "IDLE"
var target: Vector2 = Vector2.ZERO
var timer: float = 0.0
var warn_time: float = 0.8
var tip_y: float = 0.0
var surface_y: float = 0.0

var _x_min: float = 0.0
var _x_max: float = 0.0
## x of the last noise that has not been answered yet (-1 = none).
var _pending: float = -1.0


## Places the hoopoe on the surface in the middle of the strip [x_min, x_max].
func setup(surf_y: float, x_min: float, x_max: float) -> void:
	surface_y = surf_y
	_x_min = x_min
	_x_max = x_max
	pos = Vector2((x_min + x_max) * 0.5, surf_y - radius)
	tip_y = surf_y
	state = "IDLE"
	_pending = -1.0


## True while the beak is in the ground.
func beak_out() -> bool:
	return tip_y > surface_y + 2.0


## A noise reached the surface above x.
func hear(x: float) -> void:
	_pending = clampf(x, _x_min, _x_max)


## Advances the hoopoe. `dig` carves the beak shaft; `difficulty` is 0..1. `sim` receives the boss signals.
func step(sim: PlatformSim, dig: PlatformDig, dt: float, difficulty: float, attacking: bool) -> void:
	match state:
		"IDLE":
			var dir: int = facing
			if pos.x <= _x_min + 10.0:
				dir = 1
			elif pos.x >= _x_max - 10.0:
				dir = -1
			facing = dir
			pos.x += dir * WALK_SPEED * dt
			if _pending >= 0.0 and attacking:
				state = "HUNT"
				target = Vector2(_pending, surface_y)
				_pending = -1.0
		"HUNT":
			if _pending >= 0.0:
				target.x = _pending
				_pending = -1.0
			var dx: float = target.x - pos.x
			facing = 1 if dx >= 0.0 else -1
			pos.x = move_toward(pos.x, target.x, lerpf(HUNT_SPEED.x, HUNT_SPEED.y, difficulty) * dt)
			if absf(target.x - pos.x) < 2.0:
				state = "AIM"
				warn_time = lerpf(AIM_TIME.x, AIM_TIME.y, difficulty)
				timer = warn_time
				sim.boss_warn.emit(target)
				sim.sfx.emit("mine_beep", {})
		"AIM":
			timer -= dt
			if timer <= 0.0:
				state = "STAB"
				tip_y = surface_y
				sim.boss_dive.emit()
				sim.sfx.emit("drill_bore", {})
		"STAB":
			var want: float = minf(tip_y + STAB_SPEED * dt, surface_y + STAB_DEPTH)
			tip_y = dig.carve_beak(target.x, tip_y, want)
			if tip_y < want - 0.5 or tip_y >= surface_y + STAB_DEPTH - 0.5:
				state = "HOLD"
				timer = HOLD_TIME
		"HOLD":
			timer -= dt
			if timer <= 0.0:
				state = "PULL"
		"PULL":
			tip_y -= PULL_SPEED * dt
			if tip_y <= surface_y:
				tip_y = surface_y
				_pending = -1.0
				state = "REST"
				timer = lerpf(REST_TIME.x, REST_TIME.y, difficulty)
		"REST":
			timer -= dt
			if timer <= 0.0:
				state = "IDLE"
	pos.x = clampf(pos.x, _x_min, _x_max)
	pos.y = surface_y - radius

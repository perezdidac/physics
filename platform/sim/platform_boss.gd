## The parasitoid wasp, boss of the egg stage (docs/platform_contracts.md §7). Driven by PlatformSim; read by the view.
##
## API (final):
##   PlatformSim.boss: PlatformBoss          null when layout.boss == ""
##   PlatformSim.time_left: float            seconds until hatching (frozen during the intro, 0 without a boss)
##   PlatformBoss.INTRO = 2.0                intro seconds at the start (wasp only flies; time_left does not run). sim.time < INTRO
##   boss.pos, boss.vel, boss.facing (-1/1), boss.radius
##   boss.state: "PATROL" (figure eight above the arena), "WARN" (hovering, `target` marked), "DIVE" (straight line), "RECOVER"
##   boss.target: where the dive is aimed (follows Perleta during the first part of WARN, then locks)
##   boss.timer: seconds left in the current state; boss.warn_time: length of the current WARN (marker progress = 1 - timer / warn_time)
##   boss.missed: true from a dive started while Perleta was hidden until the next WARN (the wasp "lost" her)
##   boss.dive_dir: unit vector of the dive (for the trail)
## Signals (also forwarded by PlatformSim): boss_warn(target), boss_dive(), boss_missed().
## Flattened tufts (boss levels): when a dive misses a hidden Perleta, the tuft she hid in is flattened for 8 s
## (PlatformSim.TUFT_FLATTEN_TIME). State: PlatformSim.tuft_flattened: Array[float], seconds left per tuft, same order as
## layout.tufts (> 0 = flattened: hides nobody and gives no wind shelter; she becomes visible at once). Signal:
## PlatformSim.tuft_flatten(idx) (named so because the array already uses the name tuft_flattened).
## Difficulty (0..1) grows as time_left shrinks: shorter patrol, WARN 0.8 -> 0.65 s, faster dive, RECOVER 1.2 -> 0.9 s.
class_name PlatformBoss
extends RefCounted

signal warned(target: Vector2)
signal dived()
signal missed_her()

const INTRO: float = 2.0
const PATROL_TIME: Vector2 = Vector2(2.0, 0.9)
const WARN_TIME: Vector2 = Vector2(0.8, 0.65)
const RECOVER_TIME: Vector2 = Vector2(1.2, 0.9)
const DIVE_SPEED: Vector2 = Vector2(850.0, 1250.0)
## Fraction of WARN during which the target still follows Perleta.
const TRACK_FRACTION: float = 0.5
const MISS_OFFSET: float = 150.0
const OVERSHOOT: float = 140.0
const RECOVER_SPEED: float = 650.0

var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var radius: float = 20.0
var facing: int = 1
var state: String = "PATROL"
var target: Vector2 = Vector2.ZERO
var timer: float = 0.0
var warn_time: float = 0.8
var missed: bool = false
var dive_dir: Vector2 = Vector2.DOWN

var _center: Vector2 = Vector2.ZERO
var _amp: Vector2 = Vector2.ZERO
var _phase: float = 0.0
var _dive_left: float = 0.0
var _dive_speed: float = 650.0
var _arena: Rect2 = Rect2()


## Places the wasp on its figure eight above `arena`.
func setup(arena: Rect2) -> void:
	_arena = arena
	_center = Vector2(arena.get_center().x, arena.position.y + 170.0)
	_amp = Vector2(arena.size.x * 0.38, 60.0)
	_phase = 0.0
	pos = _eight(_phase)
	vel = Vector2.ZERO
	state = "PATROL"
	timer = PATROL_TIME.x
	missed = false


## Advances the wasp. `attacking` is false during the intro; `difficulty` is 0..1; `solids` end a dive on the ground.
func step(dt: float, player: PlatformBody, difficulty: float, attacking: bool, solids: Array[Rect2]) -> void:
	var before: Vector2 = pos
	match state:
		"PATROL":
			_phase += dt * lerpf(0.8, 1.3, difficulty)
			pos = _eight(_phase)
			if attacking:
				timer -= dt
				if timer <= 0.0:
					_start_warn(player, difficulty)
		"WARN":
			timer -= dt
			if timer > warn_time * (1.0 - TRACK_FRACTION):
				target = player.pos
			pos += Vector2(0.0, sin(timer * 30.0) * 0.4)
			if timer <= 0.0:
				_start_dive(player, difficulty)
		"DIVE":
			var step_len: float = _dive_speed * dt
			pos += dive_dir * step_len
			_dive_left -= step_len
			if _dive_left <= 0.0 or _in_solid(solids) or pos.y > _arena.end.y:
				state = "RECOVER"
				timer = lerpf(RECOVER_TIME.x, RECOVER_TIME.y, difficulty)
		"RECOVER":
			timer -= dt
			_phase += dt * lerpf(0.8, 1.3, difficulty)
			pos = pos.move_toward(_eight(_phase), RECOVER_SPEED * dt)
			if timer <= 0.0 and pos.distance_to(_eight(_phase)) < 30.0:
				pos = _eight(_phase)
				state = "PATROL"
				timer = lerpf(PATROL_TIME.x, PATROL_TIME.y, difficulty)
	vel = (pos - before) / dt if dt > 0.0 else Vector2.ZERO
	if absf(vel.x) > 5.0 and state != "WARN":
		facing = 1 if vel.x > 0.0 else -1


func _eight(phase: float) -> Vector2:
	return _center + Vector2(_amp.x * sin(phase), _amp.y * sin(2.0 * phase))


func _start_warn(player: PlatformBody, difficulty: float) -> void:
	state = "WARN"
	warn_time = lerpf(WARN_TIME.x, WARN_TIME.y, difficulty)
	timer = warn_time
	target = player.pos
	missed = false
	facing = 1 if target.x >= pos.x else -1
	warned.emit(target)


func _start_dive(player: PlatformBody, difficulty: float) -> void:
	if player.hidden:
		# She vanished in the needles: the wasp dives at the spot beside her and loses her.
		var side: float = 1.0 if _arena.get_center().x >= target.x else -1.0
		target.x = clampf(target.x + side * MISS_OFFSET, _arena.position.x + 30.0, _arena.end.x - 30.0)
		missed = true
		missed_her.emit()
	var to: Vector2 = target - pos
	dive_dir = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	_dive_left = to.length() + OVERSHOOT
	_dive_speed = lerpf(DIVE_SPEED.x, DIVE_SPEED.y, difficulty)
	state = "DIVE"
	dived.emit()


func _in_solid(solids: Array[Rect2]) -> bool:
	for r in solids:
		if r.grow(-radius * 0.3).has_point(pos + Vector2(0.0, radius * 0.5)):
			return true
	return false

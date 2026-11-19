## The bat, final boss of the Papallona stage (FLY mode, layout.boss == "BAT"). Driven by PlatformFly, read by the view.
##
## It hovers in a slow figure eight above the arena and sends echolocation pulses (PlatformFly.pulses). A pulse that passes over the
## moth while she is NOT inside an active shadow marks her: MARK (`target` marker for `warn_time` s, follows her for the first half),
## then SWOOP in a straight line to the target and past it, then RECOVER. If she hides in a shadow before the swoop starts, it
## swoops at the spot beside her and misses (boss_missed). Touching the bat while it swoops (or always) costs a heart.
## API: pos, vel, facing (-1/1), radius,
##      state: "PATROL" (figure eight, pulses), "MARK", "SWOOP", "RECOVER"
##      target: Vector2 (where the swoop is aimed), timer (seconds left in the state), warn_time (length of the current MARK),
##      dive_dir: unit vector of the swoop, pulse_in: seconds until the next pulse (PATROL only).
class_name PlatformBat
extends RefCounted

const PULSE_PERIOD: Vector2 = Vector2(3.2, 2.2)
const PULSE_SPEED: float = 420.0
const MARK_TIME: Vector2 = Vector2(0.7, 0.5)
const TRACK_FRACTION: float = 0.5
const SWOOP_SPEED: Vector2 = Vector2(700.0, 950.0)
const OVERSHOOT: float = 120.0
const RECOVER_TIME: Vector2 = Vector2(1.1, 0.8)
const RECOVER_SPEED: float = 480.0
const MISS_OFFSET: float = 140.0

var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var radius: float = 18.0
var facing: int = 1
var state: String = "PATROL"
var target: Vector2 = Vector2.ZERO
var timer: float = 0.0
var warn_time: float = 0.7
var dive_dir: Vector2 = Vector2.DOWN
var pulse_in: float = 1.5

var _arena: Rect2 = Rect2()
var _center: Vector2 = Vector2.ZERO
var _amp: Vector2 = Vector2.ZERO
var _phase: float = 0.0
var _swoop_left: float = 0.0
var _swoop_speed: float = 700.0


## Places the bat on its figure eight in the upper part of `arena`.
func setup(arena: Rect2) -> void:
	_arena = arena
	_center = Vector2(arena.get_center().x, arena.position.y + 130.0)
	_amp = Vector2(arena.size.x * 0.3, 50.0)
	_phase = 0.0
	pos = _eight(_phase)
	state = "PATROL"
	pulse_in = 1.5


## Advances the bat. `attacking` is false during the intro; `difficulty` is 0..1.
func step(sim: PlatformSim, fly: PlatformFly, dt: float, difficulty: float, attacking: bool) -> void:
	var before: Vector2 = pos
	var p: PlatformBody = sim.player
	match state:
		"PATROL":
			_phase += dt * lerpf(0.5, 0.8, difficulty)
			pos = _eight(_phase)
			if attacking:
				pulse_in -= dt
				if pulse_in <= 0.0:
					pulse_in = lerpf(PULSE_PERIOD.x, PULSE_PERIOD.y, difficulty)
					fly.emit_pulse(sim, pos)
		"MARK":
			timer -= dt
			if timer > warn_time * (1.0 - TRACK_FRACTION):
				target = p.pos
			pos += Vector2(0.0, sin(timer * 40.0) * 0.5)
			if timer <= 0.0:
				_start_swoop(sim, difficulty)
		"SWOOP":
			var len_step: float = _swoop_speed * dt
			pos += dive_dir * len_step
			_swoop_left -= len_step
			if _swoop_left <= 0.0 or pos.y > _arena.end.y - 10.0:
				state = "RECOVER"
				timer = lerpf(RECOVER_TIME.x, RECOVER_TIME.y, difficulty)
		"RECOVER":
			timer -= dt
			_phase += dt * lerpf(0.5, 0.8, difficulty)
			pos = pos.move_toward(_eight(_phase), RECOVER_SPEED * dt)
			if timer <= 0.0 and pos.distance_to(_eight(_phase)) < 30.0:
				pos = _eight(_phase)
				state = "PATROL"
	vel = (pos - before) / dt if dt > 0.0 else Vector2.ZERO
	if absf(vel.x) > 5.0 and state != "MARK":
		facing = 1 if vel.x > 0.0 else -1


## A pulse passed over the moth who is not hidden: start marking her.
func mark(sim: PlatformSim, difficulty: float) -> void:
	if state != "PATROL":
		return
	state = "MARK"
	warn_time = lerpf(MARK_TIME.x, MARK_TIME.y, difficulty)
	timer = warn_time
	target = sim.player.pos
	facing = 1 if target.x >= pos.x else -1
	sim.boss_warn.emit(target)
	sim.sfx.emit("mine_beep", {})


func _start_swoop(sim: PlatformSim, difficulty: float) -> void:
	if sim.player.hidden:
		var side: float = 1.0 if _arena.get_center().x >= target.x else -1.0
		target.x = clampf(target.x + side * MISS_OFFSET, _arena.position.x + 30.0, _arena.end.x - 30.0)
		sim.boss_missed.emit()
	var to: Vector2 = target - pos
	dive_dir = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	_swoop_left = to.length() + OVERSHOOT
	_swoop_speed = lerpf(SWOOP_SPEED.x, SWOOP_SPEED.y, difficulty)
	state = "SWOOP"
	sim.boss_dive.emit()
	sim.sfx.emit("jet_thrust", {})


func _eight(phase: float) -> Vector2:
	return _center + Vector2(_amp.x * sin(phase), _amp.y * sin(2.0 * phase))

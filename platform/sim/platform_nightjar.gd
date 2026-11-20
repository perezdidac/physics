## A nightjar of the FLY mode (layout.nightjars). Driven by PlatformFly, read by the view.
##
## It patrols its path (waypoints, back and forth). It chases when it sees the moth within SIGHT px and she is not hidden in a shadow,
## and gives up when she gets farther than LOSE px or stays hidden for LOSE_HIDDEN s. A bite costs her a heart and sends the bird off.
## It flies around solids (pushed out of them).
## API: pos, vel, facing (-1/1), radius, flap (grows while flying: use sin() for the wings),
##      state: "PATROL", "CHASE", "RETURN" (flying back to its path), "RECOIL" (after a bite).
class_name PlatformNightjar
extends RefCounted

const PATROL_SPEED: float = 80.0
const CHASE_SPEED: float = 185.0
const RETURN_SPEED: float = 120.0
const RECOIL_SPEED: float = 170.0
const RECOIL_TIME: float = 0.9
const SIGHT: float = 220.0
const LOSE: float = 340.0
const LOSE_HIDDEN: float = 1.0
const ACCEL: float = 520.0

var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var radius: float = 16.0
var facing: int = 1
var flap: float = 0.0
var state: String = "PATROL"

var _path: PackedVector2Array = PackedVector2Array()
var _idx: int = 0
var _dir: int = 1
var _timer: float = 0.0
var _hidden_for: float = 0.0


## Puts the bird on the first waypoint of `path` (at least 2 points).
func setup(path: PackedVector2Array) -> void:
	_path = path
	pos = path[0]
	_idx = 1 if path.size() > 1 else 0
	_dir = 1
	state = "PATROL"


## Advances the bird; returns true when it bit the moth this step.
func step(sim: PlatformSim, dt: float) -> bool:
	var p: PlatformBody = sim.player
	var to_p: Vector2 = p.pos - pos
	var dist: float = to_p.length()
	var goal_speed: float = PATROL_SPEED
	var heading: Vector2 = Vector2.ZERO
	if p.hidden:
		_hidden_for += dt
	else:
		_hidden_for = 0.0
	match state:
		"PATROL":
			heading = _toward(_path[_idx])
			if pos.distance_to(_path[_idx]) < 8.0:
				_idx += _dir
				if _idx >= _path.size() or _idx < 0:
					_dir = -_dir
					_idx = clampi(_idx + 2 * _dir, 0, _path.size() - 1)
			if not p.hidden and dist < SIGHT:
				state = "CHASE"
				sim.sfx.emit("mine_beep", {})
		"CHASE":
			heading = to_p / maxf(dist, 0.001)
			goal_speed = CHASE_SPEED
			if dist > LOSE or _hidden_for > LOSE_HIDDEN:
				state = "RETURN"
				_idx = _nearest_waypoint()
		"RETURN":
			heading = _toward(_path[_idx])
			goal_speed = RETURN_SPEED
			if pos.distance_to(_path[_idx]) < 10.0:
				state = "PATROL"
			elif not p.hidden and dist < SIGHT * 0.8:
				state = "CHASE"
		"RECOIL":
			heading = -to_p / maxf(dist, 0.001)
			goal_speed = RECOIL_SPEED
			_timer -= dt
			if _timer <= 0.0:
				state = "RETURN"
				_idx = _nearest_waypoint()
	vel = vel.move_toward(heading * goal_speed, ACCEL * dt)
	pos += vel * dt
	for r in sim.layout.solids:
		var push: Vector2 = sim._push_rect(pos, radius, r)
		if push != Vector2.ZERO:
			pos += push
			var n: Vector2 = push.normalized()
			var into: float = vel.dot(n)
			if into < 0.0:
				vel -= n * into
	if absf(vel.x) > 8.0:
		facing = 1 if vel.x > 0.0 else -1
	flap += dt * 9.0
	if state != "RECOIL" and not p.hidden and p.invuln <= 0.0 and dist < p.radius + radius - 4.0:
		state = "RECOIL"
		_timer = RECOIL_TIME
		return true
	return false


func _toward(pt: Vector2) -> Vector2:
	var d: Vector2 = pt - pos
	return d / maxf(d.length(), 0.001)


func _nearest_waypoint() -> int:
	var best: int = 0
	var best_d: float = INF
	for i in _path.size():
		var d: float = pos.distance_squared_to(_path[i])
		if d < best_d:
			best_d = d
			best = i
	return best

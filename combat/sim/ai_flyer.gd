## Bird AI for story levels (the blue tit): it hovers over a perch, flies to a point above the nearest visible caterpillar,
## hovers there for WARN_TIME (the telegraph: `ai_state == "warn"`), dives, pecks with the unit's melee weapon and flies back up.
## It moves kinematically while `flying` (no gravity). A knockback or an explosion clears `flying`; the bird then falls under
## the normal physics until it lands, and takes off again at the start of its next turn.
class_name AiFlyer
extends RefCounted

## Flight speeds (px/s) of the approach, the dive and the way back to the perch.
const APPROACH_SPEED: float = 260.0
const DIVE_SPEED: float = 380.0
const RETURN_SPEED: float = 300.0
## Seconds of the telegraph hover before the dive.
const WARN_TIME: float = 0.6
## Longest time (s) of each flight state; the sum stays below SimStory.SWARM_TURN_TIME.
const APPROACH_MAX: float = 2.2
const DIVE_MAX: float = 1.2
const RETURN_MAX: float = 1.4
## Height (px) above the target and sideways distance of the point the bird hovers at before it dives.
const STOOP_HEIGHT: float = 110.0
const STOOP_SIDE: float = 90.0
## The bird dives only when the hover point is at most this far (px) from the target after the approach.
const DIVE_RANGE: float = 340.0
const ARRIVE_DIST: float = 10.0
## Highest and lowest (above the water) a bird flies.
const CEILING: float = 50.0
const WATER_MARGIN: float = 60.0


## One AI frame for an active fighter whose unit uses FLYER.
static func update(sim: CombatSim, dt: float) -> void:
	var af: SimFighter = sim.active_fighter
	if sim.ai_plan.is_empty():
		sim.ai_plan = {"mode": "flyer", "walk_dir": 0, "state": "start", "t": 0.0, "total_time": 0.0}
		if not af.flying:
			# landed after a fall: back into the air (the perch stays where it was)
			af.flying = true
			af.grounded = true
			af.vx = 0.0
			af.vy = 0.0
			af.sliding = false
	var plan: Dictionary = sim.ai_plan
	plan["total_time"] = float(plan["total_time"]) + dt
	plan["t"] = float(plan["t"]) + dt
	if not af.flying:
		_finish(sim, af)
		return
	var target: SimFighter = SimBolso.flyer_target(sim, af, plan, AiCritter._nearest_visible(sim, af))
	var wpn: WeaponDef = AiCritter.melee_weapon(sim, af)
	match String(plan["state"]):
		"start":
			if target != null:
				sim.critter_last_seen = Vector2(target.x, target.y)
			_enter(af, plan, "approach")
		"approach":
			_approach(sim, af, plan, target, dt)
		"warn":
			if target == null or wpn == null:
				_enter(af, plan, "return")
			else:
				af.facing = 1 if target.x >= af.x else -1
				af.y += sin(sim.t_now * 40.0) * 0.4
				if float(plan["t"]) >= WARN_TIME:
					_enter(af, plan, "dive")
		"dive":
			_dive(sim, af, plan, target, wpn, dt)
		"return":
			if _fly_to(sim, af, af.perch, RETURN_SPEED, dt) or float(plan["t"]) >= RETURN_MAX:
				_finish(sim, af)


static func _enter(af: SimFighter, plan: Dictionary, state: String) -> void:
	plan["state"] = state
	plan["t"] = 0.0
	af.ai_state = state


## Ends the bird's turn: it hovers where it is (or lies where it landed).
static func _finish(sim: CombatSim, af: SimFighter) -> void:
	af.ai_state = "idle"
	sim.end_turn()


## Flies toward the hover point above the nearest visible caterpillar (or, with none visible, toward the last place one was seen).
static func _approach(sim: CombatSim, af: SimFighter, plan: Dictionary, target: SimFighter, dt: float) -> void:
	var dest: Vector2 = Vector2.INF
	if target != null:
		if int(plan.get("stoop_id", -1)) != target.id:
			plan["stoop_id"] = target.id
			plan["stoop"] = _stoop_point(sim, af, target)
		dest = plan["stoop"]
		sim.critter_last_seen = Vector2(target.x, target.y)
	elif sim.critter_last_seen != Vector2.INF:
		dest = Vector2(sim.critter_last_seen.x, af.perch.y)
	if dest == Vector2.INF:
		_finish(sim, af)
		return
	var arrived: bool = _fly_to(sim, af, dest, APPROACH_SPEED, dt)
	if arrived or float(plan["t"]) >= APPROACH_MAX:
		var can_dive: bool = target != null and Vector2(target.x - af.x, target.y - af.y).length() <= DIVE_RANGE \
			and AiCritter.melee_weapon(sim, af) != null and _clear_line(sim, Vector2(af.x, af.y), Vector2(target.x, target.y))
		if can_dive:
			sim.play("jump")
			_enter(af, plan, "warn")
		else:
			_finish(sim, af)


## The free air point above the target the bird dives from: on its own side first, 90 px beside the target, with a clear line down to it.
static func _stoop_point(sim: CombatSim, af: SimFighter, target: SimFighter) -> Vector2:
	var own: float = 1.0 if af.x >= target.x else -1.0
	var tpos := Vector2(target.x, target.y)
	for height in [STOOP_HEIGHT, 150.0, 75.0, 190.0]:
		for side in [own, -own, 0.0]:
			var p := Vector2(target.x + side * STOOP_SIDE, maxf(CEILING, target.y - height))
			if not sim.terrain.is_solid(p.x, p.y) and _clear_line(sim, p, tpos):
				return p
	return Vector2(target.x + own * STOOP_SIDE, maxf(CEILING, target.y - STOOP_HEIGHT))


## True when no rock lies on the line between the two points (the last body length before `to` is ignored).
static func _clear_line(sim: CombatSim, from: Vector2, to: Vector2) -> bool:
	var dist: float = from.distance_to(to)
	var d: float = 0.0
	while d < dist - 14.0:
		var p: Vector2 = from.lerp(to, d / dist)
		if sim.terrain.is_solid(p.x, p.y):
			return false
		d += 6.0
	return true


## Straight dive at the target; the peck ends the dive and the bird flies back up (the turn goes on until it is at the perch).
static func _dive(sim: CombatSim, af: SimFighter, plan: Dictionary, target: SimFighter, wpn: WeaponDef, dt: float) -> void:
	if target == null or wpn == null or float(plan["t"]) >= DIVE_MAX:
		_enter(af, plan, "return")
		return
	var to: Vector2 = Vector2(target.x - af.x, target.y - af.y)
	af.facing = 1 if to.x >= 0.0 else -1
	if to.length() <= wpn.reach - 2.0:
		_peck(sim, af, plan, wpn, target)
		return
	if not _move(sim, af, to.normalized() * DIVE_SPEED * dt):
		_enter(af, plan, "return")


## Pecks with the weapon and goes on with the turn (fire_weapon asks for the end of the turn: the bird still has to fly up).
static func _peck(sim: CombatSim, af: SimFighter, plan: Dictionary, wpn: WeaponDef, target: SimFighter) -> void:
	if target.id == SimBolso.TARGET_ID:
		SimBolso.peck(sim, af, wpn)
	else:
		sim.selected_weapon_idx = sim.weapon_index(wpn.id)
		var angle: float = atan2(target.y - af.y, target.x - af.x)
		SimCombat.fire_weapon(sim, wpn, angle, 1.0, null)
	if sim.turn_phase != CombatSim.Phase.GAME_OVER:
		sim.turn_phase = CombatSim.Phase.TURN_PLAY
	_enter(af, plan, "return")


## Moves the bird toward `dest`; true once it is there.
static func _fly_to(sim: CombatSim, af: SimFighter, dest: Vector2, speed: float, dt: float) -> bool:
	var to: Vector2 = dest - Vector2(af.x, af.y)
	if to.length() <= ARRIVE_DIST:
		return true
	if not _move(sim, af, to.normalized() * minf(speed * dt, to.length())):
		# rock in the way: climb over it
		_move(sim, af, Vector2(0.0, -speed * dt))
	af.facing = 1 if to.x >= 0.0 else -1
	return false


## One flying step; false when the rock blocks it. The bird stays between the ceiling and the water.
static func _move(sim: CombatSim, af: SimFighter, step: Vector2) -> bool:
	var nx: float = sim.terrain.clamp_hard(af.x + step.x, 40.0)
	var ny: float = clampf(af.y + step.y, CEILING, sim.terrain.water_y - WATER_MARGIN)
	if sim.terrain.is_solid(nx, ny + af.r * 0.6) or sim.terrain.is_solid(nx, ny - af.r * 0.6):
		return false
	af.x = nx
	af.y = ny
	af.walk_cycle += 0.3
	af.jump_start_y = ny
	af.peak_air_y = ny
	return true

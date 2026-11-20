## Boss movement helpers: kinematic flight over the terrain for flying bosses, a ground charge for walking ones,
## take-off and landing.
class_name BossMotion
extends RefCounted

## Highest point a flying boss goes (px from the top).
const CEILING: float = 50.0
## Distance at which a move counts as arrived.
const ARRIVE_DIST: float = 6.0
## Clearance (px) of the cruise height over the highest ground between the boss and its destination.
const CRUISE_CLEARANCE: float = 50.0
## Lowest a flying boss goes over the water (px above it).
const WATER_MARGIN: float = 24.0
## Column step (px) of the cruise height search.
const CRUISE_STEP: float = 8.0

## Cruise height of the current flight: {"sim", "dest", "y"} (computed once per destination).
static var _cruise: Dictionary = {}


## Moves the boss toward `dest` (flying, or along the ground for walkers); true once it is there.
static func move_to(sim: CombatSim, f: SimFighter, dest: Vector2, speed: float, dt: float) -> bool:
	if sim.boss_def.flies:
		return fly_to(sim, f, dest, speed, dt)
	var dx: float = dest.x - f.x
	if absf(dx) <= ARRIVE_DIST:
		return true
	f.facing = 1 if dx > 0.0 else -1
	var nx: float = f.x + signf(dx) * minf(absf(dx), speed * dt)
	var gy: float = sim.terrain.find_surface_y(nx, f.y - 40.0) - f.r + 1.0
	if gy < f.y - 40.0 or gy > sim.terrain.water_y - f.r:
		return true
	f.x = nx
	f.y = gy
	f.walk_cycle += dt * 12.0
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	return false


## Kinematic flight toward `dest`: straight when the line is clear; else it rises to a cruise height over the highest ground on
## the way, crosses at that height and drops when the line clears. It never gets stuck (the route keeps it out of the rock);
## it stays between the ceiling and the water. True once it is there.
static func fly_to(sim: CombatSim, f: SimFighter, dest: Vector2, speed: float, dt: float) -> bool:
	var pos := Vector2(f.x, f.y)
	var to: Vector2 = dest - pos
	if to.length() <= ARRIVE_DIST:
		return true
	var dir: Vector2 = to.normalized()
	if absf(to.x) > ARRIVE_DIST and not AiFlyer._clear_line(sim, pos, dest):
		var cy: float = _cruise_y(sim, f.x, dest)
		dir = Vector2(signf(to.x) * 0.2, -1.0).normalized() if f.y > cy + 2.0 else Vector2(signf(to.x), 0.0)
	var p: Vector2 = pos + dir * minf(speed * dt, to.length())
	f.x = sim.terrain.clamp_hard(p.x, 40.0)
	f.y = clampf(p.y, CEILING, sim.terrain.water_y - WATER_MARGIN)
	f.facing = 1 if to.x >= 0.0 else -1
	f.walk_cycle += 0.3
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	return false


static func _cruise_y(sim: CombatSim, x: float, dest: Vector2) -> float:
	if _cruise.get("sim", 0) == sim.get_instance_id() and _cruise.get("dest", Vector2.INF) == dest:
		return float(_cruise["y"])
	var top: float = dest.y
	var cx: float = minf(x, dest.x)
	while cx <= maxf(x, dest.x):
		top = minf(top, sim.terrain.find_surface_y(cx, CEILING))
		cx += CRUISE_STEP
	var y: float = maxf(CEILING, top - CRUISE_CLEARANCE)
	_cruise = {"sim": sim.get_instance_id(), "dest": dest, "y": y}
	return y


## The air point `height` px above the ground at x (below the ceiling, out of the rock).
static func hover_point(sim: CombatSim, x: float, height: float) -> Vector2:
	var hx: float = sim.terrain.clamp_hard(x, 80.0)
	var ground: float = minf(sim.terrain.find_surface_y(hx, CEILING), sim.terrain.water_y)
	var y: float = maxf(CEILING, ground - height)
	while sim.terrain.is_solid(hx, y) and y > CEILING:
		y -= 4.0
	return Vector2(hx, y)


## Back into the air (flying bosses): no gravity until a knockback.
static func take_off(f: SimFighter) -> void:
	f.flying = true
	f.grounded = true
	f.sliding = false
	f.vx = 0.0
	f.vy = 0.0
	f.ai_state = "takeoff"


## Puts the boss down on the ground under it (it stops flying): the rest pose. Over the water it rests hovering.
static func land(sim: CombatSim, f: SimFighter) -> void:
	f.ai_state = "rest"
	var gy: float = sim.terrain.find_surface_y(f.x, f.y - f.r)
	if gy >= sim.terrain.water_y - 4.0:
		return
	f.y = gy - f.r + 1.0
	f.flying = false
	f.grounded = true
	f.sliding = false
	f.vx = 0.0
	f.vy = 0.0
	f.jump_start_y = f.y
	f.peak_air_y = f.y

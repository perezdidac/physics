## Melee animal AI for story levels (ants...): scurry to the nearest visible enemy and use the first melee weapon of the team.
## With no visible target it searches the last place it saw one, or the nearest hiding spot. It always ends its turn early.
## It moves along the SimNav path (kinematic) and hugs the ground: it follows the real floor, walks to the foot of a wall and climbs along its
## face, steps off an edge and lets itself down the face, and falls (normal physics) as soon as nothing supports it. SimNav follows the terrain,
## so craters change its routes. Units with UnitDef.can_dig (the ants) chew a tunnel through the rock toward a target they cannot reach.
class_name AiCritter
extends RefCounted

## Fraction of the turn time a critter may walk toward a target / while searching before it gives up the turn.
const CHASE_FRACTION: float = 0.8
const SEARCH_FRACTION: float = 0.3
## Seconds between two path searches.
const REPLAN_TIME: float = 0.6
## Distance at which a search destination counts as reached.
const ARRIVE_DIST: float = 22.0
## Walking speed (px/s) of a unit with speed_mult 1 (the caterpillar walk).
const WALK_SPEED: float = 78.0
## A surface step (px between two path columns) above this is a wall: the critter climbs it (or lets itself down) instead of walking.
const WALL_STEP: float = SimNav.WALL_STEP
## Vertical speed (px/s) climbing up a wall / climbing down one. 80 px of wall take about a second: ~1.3 px per frame.
const CLIMB_SPEED: float = 80.0
const DESCEND_SPEED: float = 150.0
## Most a critter follows the floor vertically in one second (px), so a replan or a bump never teleports it.
const SLOPE_FOLLOW_SPEED: float = 180.0
## Nose-up angle (rad) while climbing a wall; how fast the body tilts toward the slope (1/s).
const WALL_PITCH: float = 1.3
const TILT_RATE: float = 10.0
## A turn never ends while the critter hangs on a wall, but not longer than this many seconds past its budget.
const CLIMB_GRACE: float = 4.0
## Rows (px relative to the feet) in which the floor under a walker is searched: this far above and below.
const FLOOR_UP: int = 12
const FLOOR_DOWN: int = 10
## Sideways speed (px/s) at which a climber keeps its body against the wall face.
const FACE_SPEED: float = 80.0

## Digging: seconds between two bites, bites per turn, walking speed in a tunnel, steepest tunnel slope (dy / dx).
const BITE_INTERVAL: float = 0.35
const MAX_BITES: int = 6
const DIG_SPEED: float = 30.0
## Most the body follows the tunnel floor vertically (px/s).
const DIG_FOLLOW_SPEED: float = 90.0
const MAX_DIG_SLOPE: float = 0.6
## An ant digs instead of taking a detour when the path is longer than direct distance * DIG_DETOUR + DIG_DETOUR_EXTRA px
## and the rock between it and the target is at most MAX_SHORTCUT_ROCK px thick (no path at all: it digs whatever the thickness).
const DIG_DETOUR: float = 2.5
const DIG_DETOUR_EXTRA: float = 160.0
const MAX_SHORTCUT_ROCK: float = 120.0


## A fresh critter plan.
static func _new_plan() -> Dictionary:
	return {"mode": "critter", "walk_dir": 0, "total_time": 0.0, "replan": 0.0, "path": [] as Array[Vector2], "wp": 0, "climbing": false,
		"nav_stamp": 0, "dig": false, "bites": 0, "bite_t": 0.0, "wall_i": -1, "wall_phase": 0, "wall_x": 0.0, "done": false, "delay": 0.0, "arrived": false}


## One AI frame for an active fighter whose unit uses MELEE_CRITTER. In a critter phase (sim.critter_group, see begin_group) every unit of the
## group gets its frame, in fighter index order, each with its own plan; active_fighter is the leader again afterwards.
static func update(sim: CombatSim, dt: float) -> void:
	if sim.critter_group.size() < 2:
		_update_one(sim, dt)
		return
	var acting: Array[SimFighter] = []
	for m in sim.critter_group:
		var plan: Dictionary = sim.critter_plans[m.id]
		if not m.alive or m.drowning or bool(plan["done"]):
			continue
		sim.active_fighter = m
		sim.ai_plan = plan
		var phase: int = sim.turn_phase
		_update_one(sim, dt)
		# a bite / a miss moves the turn on in a single-ant turn; here the others still act
		if phase == CombatSim.Phase.TURN_PLAY and sim.turn_phase != CombatSim.Phase.GAME_OVER:
			sim.turn_phase = CombatSim.Phase.TURN_PLAY
		if not bool(plan["done"]) and m.alive and not m.drowning:
			acting.append(m)
	sim.critter_acting = acting
	refresh_leader(sim)
	_forget_seen_place(sim)
	if acting.is_empty() and sim.turn_phase == CombatSim.Phase.TURN_PLAY:
		end_phase(sim)
		sim.end_turn()


## The shared "last seen" place is forgotten once every living unit of the phase has reached it.
static func _forget_seen_place(sim: CombatSim) -> void:
	if sim.critter_last_seen == Vector2.INF:
		return
	var any: bool = false
	for m in sim.critter_group:
		if m.alive and not m.drowning:
			any = true
			if not bool(sim.critter_plans[m.id]["arrived"]) and not bool(sim.critter_plans[m.id]["done"]):
				return
	if any:
		sim.critter_last_seen = Vector2.INF


## The critter phase is over (all done, or the turn ended otherwise): nobody is climbing or acting any more.
static func end_phase(sim: CombatSim) -> void:
	for id in sim.critter_plans:
		sim.critter_plans[id]["climbing"] = false
		sim.critter_plans[id]["done"] = true
	sim.critter_acting = []


## Points active_fighter / ai_plan at the first unit of the critter phase that still acts (else the first one alive).
static func refresh_leader(sim: CombatSim) -> void:
	var lead: SimFighter = null
	for m in sim.critter_group:
		if m.alive and not m.drowning and not bool(sim.critter_plans[m.id]["done"]):
			lead = m
			break
	if lead == null:
		for m in sim.critter_group:
			if m.alive and not m.drowning:
				lead = m
				break
	if lead != null:
		sim.active_fighter = lead
		sim.ai_plan = sim.critter_plans[lead.id]
	var acting: Array[SimFighter] = []
	for m in sim.critter_group:
		if m.alive and not m.drowning and not bool(sim.critter_plans[m.id]["done"]):
			acting.append(m)
	sim.critter_acting = acting


## Starts a critter phase: `leader` plus the other walking critters still in the swarm queue act together. Returns false (nothing changed)
## when the leader is not a MELEE_CRITTER or none of the others is. Birds, bosses and boars keep their own turns.
static func begin_group(sim: CombatSim, leader: SimFighter) -> bool:
	if not _is_walker(leader):
		return false
	var group: Array[SimFighter] = [leader]
	for id in sim.swarm_queue:
		for f in sim.fighters:
			if f.id == id and f.alive and not f.drowning and f != leader and _is_walker(f):
				group.append(f)
	if group.size() < 2:
		return false
	group.sort_custom(func(a: SimFighter, b: SimFighter) -> bool: return sim.fighters.find(a) < sim.fighters.find(b))
	for m in group:
		sim.swarm_queue.erase(m.id)
		sim.critter_plans[m.id] = _new_plan()
		sim.critter_plans[m.id]["delay"] = 0.05 * float(sim.critter_plans.size() - 1)
	sim.critter_group = group
	sim.critter_acting = group.duplicate()
	sim.active_fighter = group[0]
	sim.ai_plan = sim.critter_plans[group[0].id]
	return true


static func _is_walker(f: SimFighter) -> bool:
	return f.unit != null and f.unit.ai == "MELEE_CRITTER" and not f.unit.flies


## Ends the turn of the active critter: the whole turn in a single-ant turn, only this unit in a critter phase.
static func _finish(sim: CombatSim) -> void:
	if sim.critter_group.size() >= 2:
		sim.ai_plan["done"] = true
	else:
		sim.end_turn()


static func _update_one(sim: CombatSim, dt: float) -> void:
	var af: SimFighter = sim.active_fighter
	if sim.ai_plan.is_empty():
		sim.ai_plan = _new_plan()
	var plan: Dictionary = sim.ai_plan
	if float(plan.get("delay", 0.0)) > 0.0:
		plan["delay"] = float(plan["delay"]) - dt  # a critter phase staggers the first path searches of its units over a few frames
		return
	plan["total_time"] = float(plan["total_time"]) + dt
	if not af.grounded or af.sliding or af.hurt_timer > 0.0:
		# falling or knocked: whatever it was doing is over, it replans after landing
		plan["climbing"] = false
		plan["replan"] = 0.0
		return

	var wpn: WeaponDef = melee_weapon(sim, af)
	var target: SimFighter = _nearest_visible(sim, af)
	var dest: Vector2 = Vector2.INF
	var budget: float = CHASE_FRACTION * sim.sub_turn_time
	if target != null:
		sim.critter_last_seen = Vector2(target.x, target.y)
		dest = sim.critter_last_seen
		af.facing = 1 if target.x >= af.x else -1
		if wpn != null and Vector2(target.x - af.x, target.y - af.y).length() <= wpn.reach - 2.0:
			_bite(sim, af, wpn, target)
			return
	else:
		budget = SEARCH_FRACTION * sim.sub_turn_time
		dest = _search_destination(sim, af)
		if dest != Vector2.INF and absf(dest.x - af.x) <= ARRIVE_DIST:
			if sim.critter_last_seen != Vector2.INF and absf(sim.critter_last_seen.x - af.x) <= ARRIVE_DIST:
				if sim.critter_group.size() >= 2:
					plan["arrived"] = true  # the place is forgotten when every unit of the phase has been there (refresh_leader)
				else:
					sim.critter_last_seen = Vector2.INF
			dest = Vector2.INF
	var hanging: bool = bool(plan["climbing"]) and float(plan["total_time"]) < budget + CLIMB_GRACE
	if hanging:
		sim.turn_timer = maxf(sim.turn_timer, 0.5)  # the turn waits for a critter on a wall (the grace may outlast a short sub-turn)
	if dest == Vector2.INF or (float(plan["total_time"]) > budget and not hanging) or not walk(sim, af, plan, dest, dt):
		plan["climbing"] = false
		af.climb = 0.0
		_finish(sim)


## Moves the critter along the path to `dest`; false when there is none (or it already stands at the end). `plan.leap` (default: can_jump) lets it clear walls.
static func walk(sim: CombatSim, af: SimFighter, plan: Dictionary, dest: Vector2, dt: float) -> bool:
	var nav: SimNav = sim.walk_nav()
	nav.sync()
	plan["replan"] = float(plan["replan"]) - dt
	var path: Array[Vector2] = plan["path"]
	if not bool(plan["climbing"]) and (float(plan["replan"]) <= 0.0 or nav.edits_hit_path(int(plan["nav_stamp"]), path)):
		plan["replan"] = REPLAN_TIME
		plan["nav_stamp"] = sim.terrain.edit_log.size()
		path = nav.find_path(Vector2(af.x, af.y), dest, bool(plan.get("leap", af.can_jump())), 24.0, true)
		plan["path"] = path
		plan["wp"] = 0
		plan["wall_i"] = -1
		plan["dig"] = _wants_dig(sim, af, path, dest)
	if bool(plan["dig"]):
		return _dig(sim, af, plan, dest, dt)
	var i: int = plan["wp"]
	while i < path.size() - 1 and _reached(path, i, af):
		i += 1
	plan["wp"] = i
	if path.is_empty() or (i >= path.size() - 1 and _reached(path, i, af)):
		return false
	var terrain: TerrainSim = sim.terrain
	var next: Vector2 = path[i]
	var prev: Vector2 = path[i - 1] if i > 0 else Vector2(af.x, af.y + af.r - 1.0)
	var dir: int = signi(roundi(next.x - prev.x))
	if dir == 0:
		dir = signi(roundi(next.x - af.x))
	if dir == 0:
		dir = af.facing
	var rise: float = prev.y - next.y
	var pitch: float
	var supported: bool = true
	plan["climbing"] = false
	if absf(rise) > WALL_STEP:
		plan["climbing"] = true
		if int(plan["wall_i"]) != i:
			plan["wall_i"] = i
			plan["wall_phase"] = 0
			plan["wall_x"] = _wall_anchor(terrain, af, dir, next, rise > 0.0)
		supported = _wall_step(sim, af, plan, dir, next, rise > 0.0, dt)
		pitch = WALL_PITCH if rise > 0.0 and int(plan["wall_phase"]) < 2 else (-WALL_PITCH if rise < 0.0 and int(plan["wall_phase"]) < 2 else 0.0)
	else:
		supported = _step_ground(terrain, af, next.x, dt)
		pitch = atan2(rise, maxf(1.0, absf(next.x - prev.x)))
	if not supported:
		_fall(af, plan)
		return true
	af.climb = lerpf(af.climb, pitch, minf(1.0, TILT_RATE * dt))
	af.facing = dir
	af.walk_cycle += dt * 12.0
	af.jump_start_y = af.y
	af.peak_air_y = af.y
	sim.play("crawl_step")
	return true


## One frame of a wall segment (wall_phase: up = 0 walk to the foot, 1 climb the face, 2 step over the lip; down = 0 walk to the edge and step off,
## 1 let itself down the face, 2 walk on). False when the critter lost its support.
static func _wall_step(sim: CombatSim, af: SimFighter, plan: Dictionary, dir: int, next: Vector2, up: bool, dt: float) -> bool:
	var terrain: TerrainSim = sim.terrain
	var goal_y: float = next.y - af.r + 1.0
	var anchor: float = plan["wall_x"]
	var phase: int = plan["wall_phase"]
	if up:
		if phase == 0:
			if absf(af.x - anchor) <= 1.0:
				phase = 1
			else:
				plan["wall_phase"] = phase
				return _step_ground(terrain, af, anchor, dt)
		if phase == 1:
			if af.y <= goal_y + 0.6:
				phase = 2
			else:
				plan["wall_phase"] = 1
				var fx: float = _face_center_x(terrain, af, dir)
				if not is_nan(fx):
					af.x = move_toward(af.x, fx, FACE_SPEED * dt)
					af.y = move_toward(af.y, goal_y, CLIMB_SPEED * dt)
					return true
				if af.y - goal_y > af.r + 2.0:
					return false
				# the face curves away just under the lip (a crater rim): the last few px go straight to the lip
				af.y = move_toward(af.y, goal_y, CLIMB_SPEED * dt)
				plan["wall_phase"] = 1 if af.y > goal_y + 0.6 else 2
				return true
		plan["wall_phase"] = 2
		af.x = move_toward(af.x, next.x, WALK_SPEED * af.speed_mult() * dt)
		af.y = move_toward(af.y, goal_y, CLIMB_SPEED * dt)
		return _lip_supported(terrain, af, dir, goal_y)
	if phase == 0:
		var beyond: float = (af.x - anchor) * dir + af.r
		if absf(af.x - anchor) <= 0.5:
			phase = 1
		elif beyond < 0.0:
			plan["wall_phase"] = 0
			return _step_ground(terrain, af, anchor, dt)
		else:
			# over the edge: slide off at the same height
			plan["wall_phase"] = 0
			af.x = move_toward(af.x, anchor, WALK_SPEED * af.speed_mult() * dt)
			return true
	if phase == 1:
		if af.y >= goal_y - 0.6:
			phase = 2
		else:
			plan["wall_phase"] = 1
			var fx2: float = _face_center_x(terrain, af, -dir)
			if not is_nan(fx2):
				af.x = move_toward(af.x, fx2, FACE_SPEED * dt)
			af.y = move_toward(af.y, goal_y, DESCEND_SPEED * dt)
			return true
	plan["wall_phase"] = 2
	return _step_ground(terrain, af, next.x, dt)


## X (the critter's centre) at which it stands against the wall in front of it (up) or hangs off the edge it walks off (down).
static func _wall_anchor(terrain: TerrainSim, af: SimFighter, dir: int, next: Vector2, up: bool) -> float:
	var limit: int = int(absf(next.x - af.x) + af.r * 2.0 + 6.0)
	if up:
		for k in range(0, limit + 1):
			if terrain.is_solid(af.x + dir * k, af.y):
				return af.x + dir * (k - af.r - 1.0)
		return af.x
	for k in range(0, limit + 1):
		if not terrain.is_solid(af.x + dir * k, af.y + af.r + 2.0):
			return af.x + dir * (k + af.r)
	return next.x


## Centre x at which the body touches the rock lying in direction `rock_dir` (NAN when there is no rock beside it).
static func _face_center_x(terrain: TerrainSim, af: SimFighter, rock_dir: int) -> float:
	var best: float = NAN
	for off in [-0.7, 0.0, 0.7]:
		var yy: float = af.y + off * af.r
		for k in range(0, int(af.r) + 9):
			if terrain.is_solid(af.x + rock_dir * k, yy):
				var cx: float = af.x + rock_dir * (k - af.r - 1.0)
				if is_nan(best) or (cx - best) * rock_dir < 0.0:
					best = cx
				break
	return best


## True while there is rock under the critter's front half as it steps over a lip.
static func _lip_supported(terrain: TerrainSim, af: SimFighter, dir: int, y: float) -> bool:
	for k in [0.0, 4.0, 8.0, af.r]:
		if terrain.is_solid(af.x + dir * k, y + af.r + 2.0):
			return true
	return false


## First solid pixel row within the floor window around the feet at column x (-1: none). Looks at x and, at the edge of a platform, at x +- 4.
static func _floor_y(terrain: TerrainSim, x: float, feet: float) -> int:
	var found: int = -1
	for dx in [0.0, -4.0, 4.0]:
		for y in range(int(feet) - FLOOR_UP, int(feet) + FLOOR_DOWN + 1):
			if terrain.is_solid(x + dx, y):
				if dx == 0.0:
					return y
				found = y if found < 0 else maxi(found, y)
				break
	return found


## Walks toward target_x at walking speed with the body on the real floor. False when there is no floor under it.
static func _step_ground(terrain: TerrainSim, af: SimFighter, target_x: float, dt: float) -> bool:
	af.x = move_toward(af.x, target_x, WALK_SPEED * af.speed_mult() * dt)
	var fy: int = _floor_y(terrain, af.x, af.y + af.r - 1.0)
	if fy < 0:
		return false
	af.y = move_toward(af.y, fy - af.r + 1.0, SLOPE_FOLLOW_SPEED * dt)
	return true


## Loses the support: the critter stops being kinematic and falls with the normal fighter physics (fall damage included), then replans.
static func _fall(af: SimFighter, plan: Dictionary) -> void:
	plan["climbing"] = false
	plan["dig"] = false
	plan["path"] = [] as Array[Vector2]
	plan["replan"] = 0.0
	plan["wall_i"] = -1
	af.climb = 0.0
	af.grounded = false
	af.sliding = false
	af.slide_angle = 0.0
	af.vx = 0.0
	af.vy = 0.0
	af.jump_start_y = af.y
	af.peak_air_y = af.y
	af.is_voluntary_jump = false


## True when the critter should chew its way instead of walking: no path at all, or one far longer than a short tunnel through the rock.
static func _wants_dig(sim: CombatSim, af: SimFighter, path: Array[Vector2], dest: Vector2) -> bool:
	if af.unit == null or not af.unit.can_dig:
		return false
	if path.is_empty():
		return true
	var direct: float = Vector2(dest.x - af.x, dest.y - af.y).length()
	if SimNav.path_length(path) <= direct * DIG_DETOUR + DIG_DETOUR_EXTRA:
		return false
	var rock: float = 0.0
	var steps: int = int(direct / 2.0)
	for k in steps:
		var p: Vector2 = Vector2(af.x, af.y).lerp(dest, float(k) / maxf(1.0, steps))
		if sim.terrain.is_solid(p.x, p.y):
			rock += 2.0
	return rock > 0.0 and rock <= MAX_SHORTCUT_ROCK


## Digging toward `dest`: a bite (a small crater) in front of the critter every BITE_INTERVAL while rock blocks the way, a short walk along the
## tunnel floor when it is open. Mostly horizontal, a little up or down. False when the turn's bites are used up or it must not dig there.
static func _dig(sim: CombatSim, af: SimFighter, plan: Dictionary, dest: Vector2, dt: float) -> bool:
	var terrain: TerrainSim = sim.terrain
	plan["climbing"] = false
	plan["bite_t"] = float(plan["bite_t"]) - dt
	var dx: float = dest.x - af.x
	if absf(dx) < 4.0:
		return false  # right above / below the target: digging sideways back and forth would only wobble (the turn is over for this critter)
	var sx: float = signf(dx)
	var dir: Vector2 = Vector2(sx, clampf((dest.y - af.y) / maxf(absf(dx), 24.0), -MAX_DIG_SLOPE, MAX_DIG_SLOPE)).normalized()
	af.facing = int(sx)
	af.climb = lerpf(af.climb, atan2(-dir.y, absf(dir.x)), minf(1.0, TILT_RATE * dt))
	# the body's upper side is checked further out than its lower side: the tunnel floor under the feet is not "in the way"
	var up: Vector2 = Vector2(dir.y, -dir.x) if dir.x > 0.0 else Vector2(-dir.y, dir.x)
	if _dig_blocked(terrain, af, dir, up):
		if float(plan["bite_t"]) > 0.0:
			return true
		if int(plan["bites"]) >= MAX_BITES:
			return false
		var radius: float = af.r + 2.0
		# a little above the body centre so the hole's bottom stays at the feet (the tunnel floor does not sink)
		var c: Vector2 = Vector2(af.x, af.y - 3.0) + dir * af.r
		if c.y + radius > terrain.water_y - 8.0 or c.y - radius < 40.0 or c.x - radius < terrain.arena_x0 + 24.0 or c.x + radius > terrain.arena_x1 - 24.0:
			return false
		terrain.carve_crater(c.x, c.y, radius)
		sim.play("spoon_scoop", {"pitch_scale": 1.7})
		SimCombat.debris(sim, c.x, c.y, 3)
		af.squash_x = 1.18
		af.squash_y = 0.84
		plan["bites"] = int(plan["bites"]) + 1
		plan["bite_t"] = BITE_INTERVAL
		return true
	if af.y + af.r > terrain.water_y - 22.0:
		return false
	var nx: float = af.x + dir.x * DIG_SPEED * dt
	var fy: int = _floor_y(terrain, nx, af.y + af.r - 1.0)
	if fy < 0:
		# an open gap or a cliff edge ahead: it stops there (the nav map takes over when the way around exists), it does not jump
		if _floor_y(terrain, af.x, af.y + af.r - 1.0) < 0:
			_fall(af, plan)
			return true
		return false
	af.x = nx
	af.walk_cycle += dt * 12.0
	af.y = move_toward(af.y, fy - af.r + 1.0, DIG_FOLLOW_SPEED * dt)
	af.jump_start_y = af.y
	af.peak_air_y = af.y
	return true


## True when rock is within the body's reach in front (several distances, so a thin pillar cannot slip between the probes).
static func _dig_blocked(terrain: TerrainSim, af: SimFighter, dir: Vector2, up: Vector2) -> bool:
	var c := Vector2(af.x, af.y)
	if terrain.is_solid(c.x + dir.x * af.r * 0.6 + up.x * af.r * 0.8, c.y + dir.y * af.r * 0.6 + up.y * af.r * 0.8):
		return true
	for dist in [0.5, 1.0, 1.22]:
		var p: Vector2 = c + dir * (af.r * dist)
		if terrain.is_solid(p.x, p.y) or terrain.is_solid(p.x + up.x * af.r * 0.7, p.y + up.y * af.r * 0.7) or terrain.is_solid(p.x - up.x * af.r * 0.2, p.y - up.y * af.r * 0.2):
			return true
	return false


## True when the critter stands at waypoint i; after a wall it must also have finished climbing (or letting itself down) it.
static func _reached(path: Array[Vector2], i: int, af: SimFighter) -> bool:
	if absf(path[i].x - af.x) > 1.0:
		return false
	return i == 0 or absf(path[i].y - path[i - 1].y) <= WALL_STEP or absf(af.y - (path[i].y - af.r + 1.0)) < 1.0


static func _bite(sim: CombatSim, af: SimFighter, wpn: WeaponDef, target: SimFighter) -> void:
	af.climb = 0.0
	sim.selected_weapon_idx = sim.weapon_index(wpn.id)
	var angle: float = atan2(target.y - af.y, target.x - af.x)
	SimCombat.fire_weapon(sim, wpn, angle, 1.0, null)
	if sim.turn_phase == CombatSim.Phase.TURN_PLAY or sim.critter_group.size() >= 2:
		_finish(sim)


## The melee weapon of the fighter's unit (UnitDef.melee_weapon), else the first melee weapon of its team arsenal; null when it has none with ammo.
static func melee_weapon(sim: CombatSim, af: SimFighter) -> WeaponDef:
	if af.unit != null and not af.unit.melee_weapon.is_empty():
		var idx: int = sim.weapon_index(af.unit.melee_weapon)
		return sim.weapons[idx] if idx >= 0 and sim.ammo_f(af.team, af.unit.melee_weapon) > 0.0 else null
	for i in sim.team_arsenal(af.team):
		var w: WeaponDef = sim.weapons[i]
		if w.type == "MELEE" and sim.ammo_f(af.team, w.id) > 0.0:
			return w
	return null


static func _nearest_visible(sim: CombatSim, af: SimFighter) -> SimFighter:
	var best: SimFighter = null
	var best_d: float = INF
	for f in sim.fighters:
		if f.team != af.team and f.alive and not f.drowning and not f.hidden:
			var d: float = Vector2(f.x - af.x, f.y - af.y).length()
			if d < best_d:
				best_d = d
				best = f
	return best


## Where to go when nobody is visible: the last place an enemy was seen, else the nearest hiding spot that is not under the critter.
static func _search_destination(sim: CombatSim, af: SimFighter) -> Vector2:
	if sim.critter_last_seen != Vector2.INF:
		return sim.critter_last_seen
	var best: Vector2 = Vector2.INF
	for s in sim.hiding_spots:
		if absf(s.x - af.x) > ARRIVE_DIST and (best == Vector2.INF or s.distance_to(Vector2(af.x, af.y)) < best.distance_to(Vector2(af.x, af.y))):
			best = s
	return best

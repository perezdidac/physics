## La Processó (docs/procession_contracts.md): the CONVOY rule. The squad is a file of caterpillars; only the first one, the leader, is
## played (by the player or the CPU), and the others trail the path the leader walked, at a fixed spacing. The leader has a walking budget
## per turn (`march_left`). A follower knocked more than LOST_DIST px away from its place in the line is "lost" until the leader walks back
## to it. The level is won when the leader reaches the goal (or, in BOSS_OR_GOAL / mini-boss levels, the boss falls) and lost when it dies.
## Every function is a no-op when the match is not a convoy level (classic matches never change).
class_name SimConvoy
extends RefCounted

## Distance (px) along the leader's path between two neighbours of the line.
const SPACING: float = 36.0
## A settled follower further than this from its place is lost; the leader this close to a lost one picks it up again.
const LOST_DIST: float = 120.0
const REJOIN_DIST: float = 60.0
## Speed (px/s) of a follower catching up with its place (the leader walks at 78).
const FOLLOW_SPEED: float = 160.0
## The trail keeps this much (px) beyond the last place of the line.
const TRAIL_SLACK: float = 240.0
## The goal needs the leader's feet within this height (px) of the goal ground.
const GOAL_HEIGHT: float = 60.0
## Most rounds of ramp cutting while the road is made.
const ROAD_PASSES: int = 8
## A fall counts as "walked off a ledge" when it moved at most this far sideways (px); the follower steps off with this sideways speed.
const FALL_REACH: float = 40.0
const FALL_PUSH: float = 30.0


## True in a CONVOY / BOSS_OR_GOAL level.
static func active(sim: CombatSim) -> bool:
	return sim.level != null and sim.level.is_convoy()


## Clears the convoy state of the sim (every match).
static func reset(sim: CombatSim) -> void:
	sim.convoy_leader = null
	sim.convoy_line = []
	sim.convoy_start_count = 0
	sim.march_budget = 0.0
	sim.march_left = 0.0
	sim.goal_x = -1.0
	sim.goal_y = 0.0
	sim.goal_radius = 80.0
	sim.goal_reached = false
	sim.boar_intents = []
	sim.convoy_trail = SimTrail.new()
	sim.convoy_s = {}
	sim.convoy_air = false
	sim.convoy_last_x = 0.0
	SimSpores.reset(sim)


## After the squads are placed: the first caterpillar leads, the trail is the file as it stands, the goal ground is found.
static func build(sim: CombatSim, level: LevelDef) -> void:
	if not level.is_convoy():
		return
	var squad: Array[SimFighter] = _squad(sim)
	if squad.is_empty():
		return
	sim.convoy_leader = squad[0]
	squad[0].is_leader = true
	sim.convoy_start_count = squad.size()
	sim.convoy_line = squad.duplicate()
	sim.march_budget = level.march_budget
	sim.march_left = level.march_budget
	sim.goal_x = level.goal_x
	sim.goal_radius = level.goal_radius
	_build_road(sim)
	# The road cuts ramps into the terrain after the spawns, so a fighter can be left in the air: drop it back onto the ground.
	_settle_fighters(sim)
	for k in range(squad.size() - 1, 0, -1):
		sim.convoy_trail.record(Vector2(squad[k].x, squad[k].y), false)
	sim.convoy_last_x = squad[0].x
	SimSpores.build(sim, level)
	_reindex(sim)


## Puts every walking fighter left without ground under its feet (by the road ramps) back on the surface below it.
static func _settle_fighters(sim: CombatSim) -> void:
	for f in sim.fighters:
		if not f.alive or f.flying or f.x < 0.0 or f.x >= SimTables.TERRAIN_W:
			continue
		if SimPlacement.supported(sim.terrain, f.x, f.y + f.r + 2.0):
			continue
		var ground: float = sim.terrain.find_surface_y(f.x, f.y)
		if ground > float(sim.terrain.H):
			continue
		var dy: float = ground - f.r - 1.0 - f.y
		f.y += dy
		for i in f.segs.size():
			f.segs[i] = f.segs[i] + Vector2(0.0, dy)


## The player's fighters in squad order (member 0 = the leader).
static func _squad(sim: CombatSim) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team == 0:
			out.append(f)
	return out


## The road: the shortest way for a leaping walker (the ants) from the leader to the goal ground, with a ramp cut into every wall the
## caterpillars could not climb (the maps are rugged), so that the whole way can be walked. Also finds the goal ground: the walkable
## point nearest to the goal x becomes `goal_x` / `goal_y`. Does nothing when no way exists (the level seed is then not playable).
static func _build_road(sim: CombatSim) -> void:
	var l: SimFighter = sim.convoy_leader
	for _pass in ROAD_PASSES:
		var goal: Vector2 = _goal_point(sim)
		if goal == Vector2.INF:
			return
		sim.goal_x = goal.x
		sim.goal_y = goal.y
		var path: Array[Vector2] = sim.nav.find_path(Vector2(l.x, l.y), Vector2(goal.x, goal.y - l.r - 2.0), true, 12.0)
		var walls: int = 0
		for i in range(1, path.size()):
			var rise: float = path[i - 1].y - path[i].y
			if rise > SimNav.MAX_CLIMB:
				sim.terrain.cut_ramp(path[i - 1], 1 if path[i].x >= path[i - 1].x else -1, rise)
				walls += 1
		if walls == 0:
			return
		sim.nav = SimNav.new(sim.terrain, false)


## The surface point a leaping walker can reach from the leader that is nearest to goal_x (Vector2.INF when it reaches nothing).
static func _goal_point(sim: CombatSim) -> Vector2:
	var best := Vector2.INF
	for c in sim.nav.reachable(Vector2(sim.convoy_leader.x, sim.convoy_leader.y), true):
		if best == Vector2.INF or absf(c.x - sim.goal_x) < absf(best.x - sim.goal_x):
			best = Vector2(c.x, c.y)
	return best


## The leader (null outside a convoy level).
static func leader(sim: CombatSim) -> SimFighter:
	return sim.convoy_leader


## True when the leader of a convoy level is dead (the level is lost).
static func leader_dead(sim: CombatSim) -> bool:
	var l: SimFighter = sim.convoy_leader
	return l != null and (not l.alive or l.drowning)


## True when a unit of the level's `mini_boss` kind existed and none is left.
static func mini_boss_down(sim: CombatSim) -> bool:
	if sim.level == null or sim.level.mini_boss == "":
		return false
	var seen: bool = false
	for f in sim.fighters:
		if f.kind == sim.level.mini_boss:
			if f.alive and not f.drowning:
				return false
			seen = true
	return seen


## The enemy side is beaten as far as a convoy level cares: its boss or mini-boss is down. (Wiping the others out wins nothing.)
static func enemy_done(sim: CombatSim) -> bool:
	return SimBoss.beaten(sim) or mini_boss_down(sim)


## Caterpillars of the squad still in the line (leader and followers), and the followers at the start / now alive but lost.
static func in_line_count(sim: CombatSim) -> int:
	return sim.convoy_line.size()


static func lost_count(sim: CombatSim) -> int:
	var n: int = 0
	for f in _squad(sim):
		n += 1 if f.lost and f.alive and not f.drowning else 0
	return n


## The leader may not walk or jump: its march budget is spent (CombatSim input, SimFighterStep walking).
static func walk_blocked(sim: CombatSim, f: SimFighter) -> bool:
	return f != null and f.is_leader and active(sim) and sim.march_left <= 0.0


## Start of the player's turn: the leader is the one that plays and its march budget is full again.
static func on_player_turn(sim: CombatSim) -> void:
	sim.march_left = sim.march_budget
	sim.convoy_last_x = sim.convoy_leader.x
	sim.hud()


# ---------------------------------------------------------------------------
# Per frame
# ---------------------------------------------------------------------------

## Every frame after the physics: the march budget, the trail, the followers, lost and rejoined ones, and the goal.
static func update(sim: CombatSim, dt: float) -> void:
	var l: SimFighter = sim.convoy_leader
	if l == null or sim.turn_phase == CombatSim.Phase.GAME_OVER:
		return
	_spend_march(sim, l)
	_record_trail(sim, l)
	_prune(sim)
	_check_goal(sim, l)
	if sim.turn_phase == CombatSim.Phase.GAME_OVER:
		return
	_follow(sim, l, dt)
	_lose_and_rejoin(sim, l)


static func _spend_march(sim: CombatSim, l: SimFighter) -> void:
	var walking: bool = sim.active_team == 0 and sim.active_fighter == l and (sim.turn_phase == CombatSim.Phase.TURN_PLAY or sim.turn_phase == CombatSim.Phase.RETREAT)
	if walking and sim.march_left > 0.0:
		var before: float = floorf(sim.march_left / 8.0)
		sim.march_left = maxf(0.0, sim.march_left - absf(l.x - sim.convoy_last_x))
		if floorf(sim.march_left / 8.0) != before or sim.march_left <= 0.0:
			sim.hud()
	sim.convoy_last_x = l.x


## The leader leaves a trail of the ground it stood on, one point every SimTrail.STEP px (a jump or a fall makes a gap in it).
static func _record_trail(sim: CombatSim, l: SimFighter) -> void:
	if not l.alive or l.drowning:
		return
	if not l.grounded or l.sliding:
		sim.convoy_air = true
		return
	if sim.convoy_trail.record(Vector2(l.x, l.y), sim.convoy_air):
		sim.convoy_trail.trim(_head_s(sim), SPACING * sim.convoy_start_count + TRAIL_SLACK)
	sim.convoy_air = false


## Distance the leader has walked (the trail does not grow while it is in the air).
static func _head_s(sim: CombatSim) -> float:
	var l: SimFighter = sim.convoy_leader
	return sim.convoy_trail.head_s(Vector2(l.x, l.y), sim.convoy_air or not l.grounded or l.sliding)


## The place `back` px behind the leader along its trail.
static func place_behind(sim: CombatSim, back: float) -> Vector2:
	return sim.convoy_trail.sample(_head_s(sim) - back)


## Removes the fallen from the line and renumbers it.
static func _prune(sim: CombatSim) -> void:
	var changed: bool = false
	for i in range(sim.convoy_line.size() - 1, 0, -1):
		var f: SimFighter = sim.convoy_line[i]
		if not f.alive or f.drowning:
			sim.convoy_line.remove_at(i)
			changed = true
	if changed:
		_reindex(sim)
		sim.convoy_changed.emit()
		sim.hud()


static func _reindex(sim: CombatSim) -> void:
	for f in _squad(sim):
		f.line_index = sim.convoy_line.find(f)


## True when a follower stands and can walk (not flying through the air, sliding or drowning).
static func _settled(f: SimFighter) -> bool:
	return f.alive and not f.drowning and f.grounded and not f.sliding


## The followers walk along the trail to their place, and look the way they walk. Each one keeps its own distance on the trail
## (`convoy_s`), which grows toward its place at FOLLOW_SPEED; a gap in the trail is crossed by _cross_gap.
static func _follow(sim: CombatSim, l: SimFighter, dt: float) -> void:
	if not l.alive or l.drowning:
		return
	var head: float = _head_s(sim)
	var trail: SimTrail = sim.convoy_trail
	for k in range(1, sim.convoy_line.size()):
		var f: SimFighter = sim.convoy_line[k]
		if not _settled(f):
			continue
		var at: float = float(sim.convoy_s.get(f.id, head - k * SPACING))
		var next: float = move_toward(at, head - k * SPACING, FOLLOW_SPEED * dt)
		var g: int = trail.gap_between(at, next)
		if g >= 0:
			_cross_gap(sim, f, g)
			sim.convoy_s[f.id] = trail.s[g]
			continue
		sim.convoy_s[f.id] = next
		var want: Vector2 = trail.sample(next)
		var d: Vector2 = want - Vector2(f.x, f.y)
		if d.length() < 0.01:
			continue
		var step: Vector2 = d if d.length() <= FOLLOW_SPEED * dt else d.normalized() * FOLLOW_SPEED * dt
		f.x += step.x
		f.y += step.y
		if absf(d.x) > 0.5:
			f.facing = 1 if d.x > 0.0 else -1
		f.walk_cycle += dt * 12.0
		f.vx = 0.0
		f.vy = 0.0
		f.jump_start_y = f.y
		f.peak_air_y = f.y


## The leader was in the air between point g-1 and point g of its trail. A follower that comes to the first one steps off the ledge when
## the leader fell (the physics drops it; it walks on from where it lands), and hops over when the leader jumped (it cannot).
static func _cross_gap(sim: CombatSim, f: SimFighter, g: int) -> void:
	var trail: SimTrail = sim.convoy_trail
	var from: Vector2 = trail.points[g - 1]
	var to: Vector2 = trail.points[g]
	var fell: bool = to.y - from.y >= SimTrail.GAP_MIN and absf(to.x - from.x) <= FALL_REACH
	if fell:
		f.x = from.x
		f.y = from.y
		f.vx = signf(to.x - from.x) * FALL_PUSH
		f.vy = 0.0
		f.grounded = false
		f.sliding = false
		f.is_voluntary_jump = false
		f.jump_start_y = f.y
		f.peak_air_y = f.y
	else:
		f.x = to.x
		f.y = to.y
		f.squash_x = 0.82
		f.squash_y = 1.22
		f.jump_start_y = f.y
		f.peak_air_y = f.y
	f.facing = 1 if to.x >= from.x else -1


## A settled follower far from its place is lost; the leader next to a lost one picks it up again at the tail of the line.
static func _lose_and_rejoin(sim: CombatSim, l: SimFighter) -> void:
	var changed: bool = false
	for k in range(sim.convoy_line.size() - 1, 0, -1):
		var f: SimFighter = sim.convoy_line[k]
		if _settled(f) and f.hurt_timer <= 0.0 and Vector2(f.x, f.y).distance_to(place_behind(sim, k * SPACING)) > LOST_DIST:
			sim.convoy_line.remove_at(k)
			f.lost = true
			sim.ftext(f.x, f.y - 40.0, "FT_LINE_LOST", Palette.FT_ORANGE, 1.9, [f.name])
			changed = true
	if l.alive and not l.drowning and _settled(l):
		for f in _squad(sim):
			if f.lost and _settled(f) and absf(f.x - l.x) <= REJOIN_DIST and absf(f.y - l.y) <= 40.0:
				f.lost = false
				sim.convoy_line.append(f)
				sim.ftext(f.x, f.y - 40.0, "FT_LINE_REJOINED", Palette.FT_GREEN, 1.9, [f.name])
				changed = true
	if changed:
		_reindex(sim)
		sim.convoy_changed.emit()
		sim.hud()


## The leader standing on the goal ground wins the level.
static func _check_goal(sim: CombatSim, l: SimFighter) -> void:
	if sim.goal_x < 0.0 or not l.alive or l.drowning or not l.grounded or l.sliding:
		return
	if absf(l.x - sim.goal_x) <= sim.goal_radius and absf(l.y + l.r - sim.goal_y) <= GOAL_HEIGHT:
		sim.goal_reached = true
		sim.winner = 0
		sim.turn_phase = CombatSim.Phase.GAME_OVER
		sim.ftext(l.x, l.y - 46.0, "FT_GOAL_REACHED", Palette.FT_GOLD_SOFT, 2.4)
		sim.play("victory")
		sim.convoy_goal_reached.emit()
		sim.game_over.emit(0, SimTurns.make_game_stats(sim))
		sim.hud()

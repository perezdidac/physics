## The CPU driving the leader of a CONVOY level (headless runs, tests): it walks the shortest walkable path to the goal until the march budget
## of the turn is spent. It stops short of an announced boar band (it waits for the charge to pass) and of a spore cloud it cannot cross
## in one go with the whole line. The followers need no brain: they trail the leader (SimConvoy).
class_name AiConvoy
extends RefCounted

## Seconds between two path searches; how far ahead (px) on the path the leader aims; seconds without progress before it hops.
const REPLAN_TIME: float = 0.6
const LOOK_AHEAD: float = 16.0
const STUCK_TIME: float = 1.2
## How far (px) from a hazard the leader stops.
const STOP_MARGIN: float = 24.0
## A cloud is crossed only when the leader (and the whole line behind it) can be out of it by the end of the turn, with this much to spare.
const CROSS_SPARE: float = 30.0


## One AI frame for the leader of the squad. It walks like a player would (the physics walk of the classic AI: `ai_plan.walk_dir`), so
## the followers can trail it over the same ground; if it is stuck against a wall for a while it jumps.
static func update(sim: CombatSim, dt: float) -> void:
	var af: SimFighter = sim.active_fighter
	if af != sim.convoy_leader:
		sim.end_turn()
		return
	if sim.ai_plan.is_empty():
		sim.ai_plan = {"mode": "convoy", "walk_dir": 0, "total_time": 0.0, "replan": 0.0, "path": [] as Array[Vector2], "stuck": 0.0, "last_x": af.x}
	var plan: Dictionary = sim.ai_plan
	plan["total_time"] = float(plan["total_time"]) + dt
	if float(plan["total_time"]) > sim.sub_turn_time - 1.0 or sim.march_left <= 0.0:
		_stop(sim, plan)
		return
	if not af.grounded or af.sliding or af.hurt_timer > 0.0:
		plan["walk_dir"] = 0
		return
	var dest := Vector2(sim.goal_x, sim.goal_y - af.r - 2.0)
	var dir: float = 1.0 if dest.x >= af.x else -1.0
	if dir * (_limit_x(sim, af, dir) - af.x) <= 0.0:
		_stop(sim, plan)
		return
	plan["replan"] = float(plan["replan"]) - dt
	if float(plan["replan"]) <= 0.0:
		plan["replan"] = REPLAN_TIME
		plan["path"] = sim.nav.find_path(Vector2(af.x, af.y), dest, false)
	var path: Array[Vector2] = plan["path"]
	var next: Vector2 = Vector2.INF
	for p in path:
		if absf(p.x - af.x) >= LOOK_AHEAD and (p.x - af.x) * dir >= 0.0:
			next = p
			break
	if next == Vector2.INF:
		if not path.is_empty():
			plan["walk_dir"] = 0
			return
		next = dest  # no walkable way from here (knocked into a pit): push straight toward the goal and hop
	plan["walk_dir"] = 1 if next.x > af.x else -1
	# stuck against a wall: hop
	plan["stuck"] = float(plan["stuck"]) + dt
	if absf(af.x - float(plan["last_x"])) > 6.0:
		plan["stuck"] = 0.0
		plan["last_x"] = af.x
	elif float(plan["stuck"]) > STUCK_TIME:
		plan["stuck"] = 0.0
		af.facing = int(plan["walk_dir"])
		sim._do_forward_jump(af)


static func _stop(sim: CombatSim, plan: Dictionary) -> void:
	plan["walk_dir"] = 0
	sim.end_turn()


## The x the leader must not pass this turn walking in direction `dir` (+/- INF when nothing is in the way).
static func _limit_x(sim: CombatSim, af: SimFighter, dir: float) -> float:
	var limit: float = dir * INF
	var line_len: float = (sim.convoy_line.size() - 1) * SimConvoy.SPACING
	for it in sim.boar_intents:
		var band: Rect2 = it["band"]
		if _ahead(band, af.x, dir):
			limit = _nearer(limit, _edge(band, dir), dir)
	for r in sim.spores:
		if af.y < r.position.y or af.y > r.end.y or not _ahead(r, af.x, dir):
			continue
		var far_side: float = r.end.x if dir > 0.0 else r.position.x
		if absf(far_side - af.x) + line_len + STOP_MARGIN + CROSS_SPARE > sim.march_left:
			limit = _nearer(limit, _edge(r, dir), dir)
	return limit


## True when the whole of `r` lies in front of x.
static func _ahead(r: Rect2, x: float, dir: float) -> bool:
	return r.position.x > x if dir > 0.0 else r.end.x < x


## The near edge of `r` seen from the side the leader comes from, less the stopping margin.
static func _edge(r: Rect2, dir: float) -> float:
	return (r.position.x - STOP_MARGIN) if dir > 0.0 else (r.end.x + STOP_MARGIN)


static func _nearer(a: float, b: float, dir: float) -> float:
	return a if dir * a < dir * b else b

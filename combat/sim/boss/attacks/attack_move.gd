## MOVE: relocates the boss. `to`: "PERCH" (the highest ground within 350 px of a visible enemy: a tree top or a crag, where it
## lands), "TARGET" (hover over a visible enemy) or "HOME" (back over its spawn point). With rest_state it lands there (e.g. the
## great tit "PERCHED", vulnerable only then).
class_name AttackMove
extends BossAttack

const MOVE_MAX: float = 3.0
## Half width (px) of the strip searched for a perch, and the sampling step.
const PERCH_SPAN: float = 350.0
const PERCH_STEP: float = 20.0


func plan(sim: CombatSim, atk: Dictionary) -> Dictionary:
	var b: SimFighter = sim.boss
	var to: String = str(atk.get("to", "TARGET"))
	if to == "HOME":
		return make_intent(sim, atk, [], BossMotion.hover_point(sim, sim.terrain.arena_at(sim.boss_def.spawn_frac), sim.boss_def.hover_height))
	var vis: Array[SimFighter] = visible_targets(sim)
	if vis.is_empty():
		return {}
	var f: SimFighter = vis[int(sim.rand() * vis.size())]
	if to == "PERCH":
		var best := Vector2.INF
		var x: float = maxf(80.0, f.x - PERCH_SPAN)
		while x <= minf(sim.terrain.arena_x1 - 80.0, f.x + PERCH_SPAN):
			var sy: float = sim.terrain.find_surface_y(x, BossMotion.CEILING)
			if sy < sim.terrain.water_y - 30.0 and (best == Vector2.INF or sy < best.y):
				best = Vector2(x, sy)
			x += PERCH_STEP
		if best == Vector2.INF:
			return {}
		return make_intent(sim, atk, [], Vector2(best.x, best.y - b.r - 1.0))
	return make_intent(sim, atk, [], BossMotion.hover_point(sim, f.x, sim.boss_def.hover_height))


func step(sim: CombatSim, atk: Dictionary, intent: Dictionary, run: Dictionary, dt: float) -> bool:
	var b: SimFighter = sim.boss
	b.ai_state = "approach"
	run["t"] = float(run.get("t", 0.0)) + dt
	if not BossMotion.move_to(sim, b, intent["pos"], sim.boss_def.speed_of(sim.boss_phase), dt) and float(run["t"]) < MOVE_MAX:
		return false
	if str(atk.get("rest_state", "")) != "" and sim.boss_def.flies:
		BossMotion.land(sim, b)
	sim.boss_attack.emit(str(atk.get("id", "")), intent["pos"])
	return true

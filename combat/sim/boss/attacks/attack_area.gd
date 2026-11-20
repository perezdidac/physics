## AREA: marks a spot (on a visible enemy); next turn the boss goes over it, winds up and strikes the whole area: an explosion of
## `radius`, `damage`, `knockback` (it carves the ground). Base of the other area attacks (GUST, STATUS), which override _impact.
## Keys: radius, damage, knockback, height (px above the spot it strikes from; default: its hover height), at ("NEST": the mark is the
## nest, not an enemy), stand (walkers: distance from the mark they shoot from; default radius + 20).
class_name AttackArea
extends BossAttack


func plan(sim: CombatSim, atk: Dictionary) -> Dictionary:
	if str(atk.get("at", "")) == "NEST":
		return make_intent(sim, atk, [], sim.nest.pos) if SimBolso.alive(sim) else {}
	return super.plan(sim, atk)


func start(sim: CombatSim, atk: Dictionary, intent: Dictionary, run: Dictionary) -> void:
	var pos: Vector2 = intent["pos"]
	var height: float = float(atk.get("height", sim.boss_def.hover_height))
	var stand: float = float(atk.get("stand", float(atk.get("radius", 0.0)) + 20.0))
	var from: Vector2 = BossMotion.hover_point(sim, pos.x, height) if sim.boss_def.flies else Vector2(pos.x + signf(sim.boss.x - pos.x) * stand, pos.y)
	run["from"] = from
	run["aim"] = from
	run["stage"] = "approach"
	run["t"] = 0.0


func step(sim: CombatSim, atk: Dictionary, intent: Dictionary, run: Dictionary, dt: float) -> bool:
	if strike_step(sim, run, INF, dt) != "arrived":
		return false
	_impact(sim, atk, intent)
	sim.boss_attack.emit(str(atk.get("id", "")), intent["pos"])
	return true


func _impact(sim: CombatSim, atk: Dictionary, intent: Dictionary) -> void:
	var pos: Vector2 = intent["pos"]
	SimCombat.trigger_explosion(sim, pos.x, pos.y, float(atk.get("radius", 40.0)), float(atk.get("damage", 20)), float(atk.get("knockback", 300.0)))


## Enemies of the boss within the intent radius, with their falloff (1 at the centre, 0.3 at the edge): [[fighter, falloff]].
static func in_area(sim: CombatSim, intent: Dictionary) -> Array:
	var out: Array = []
	var pos: Vector2 = intent["pos"]
	var radius: float = float(intent["radius"])
	for f in sim.fighters:
		if f.team != sim.boss.team and f.alive and not f.drowning:
			var d: float = Vector2(f.x, f.y).distance_to(pos)
			if d <= radius:
				out.append([f, clampf(1.0 - d / radius, 0.3, 1.0)])
	return out

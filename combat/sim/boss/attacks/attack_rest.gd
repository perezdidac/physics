## REST: the boss does nothing but catch its breath: it enters its `rest_state` (e.g. "WINDED", vulnerable) when the attack runs.
## Used with `after` (usable only after that many attacks) so it comes as the "out of breath" window. Keys: rest_state, rest_text.
class_name AttackRest
extends BossAttack


func plan(sim: CombatSim, atk: Dictionary) -> Dictionary:
	return make_intent(sim, atk, [], Vector2(sim.boss.x, sim.boss.y))


func step(sim: CombatSim, atk: Dictionary, _intent: Dictionary, _run: Dictionary, _dt: float) -> bool:
	sim.boss.ai_state = "rest"
	sim.boss_attack.emit(str(atk.get("id", "")), Vector2(sim.boss.x, sim.boss.y))
	return true

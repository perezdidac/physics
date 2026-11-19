## LINE: a vertical band of `width` px (full height) marked in front of the boss; next turn the boss walks (or flies) to its
## `standoff`, winds up and brings the pole down on the band: every enemy inside it takes `damage` and is knocked away, and the
## nest takes `nest_damage` when it touches the band. The intent carries the band (`rect`, `dir`); moving out of it is the dodge.
## The band goes on the nearest-to-random enemy or the nest; when the target is farther than the boss can walk in one turn the
## band is set where it will arrive, so the telegraph is always true. Keys: width, standoff, damage, nest_damage, knockback, dmg_label.
class_name AttackLine
extends BossAttack

const DEFAULT_WIDTH: float = 140.0
const DEFAULT_STANDOFF: float = 130.0


func plan(sim: CombatSim, atk: Dictionary) -> Dictionary:
	var b: SimFighter = sim.boss
	var xs: Array[float] = []
	for f in visible_targets(sim):
		xs.append(f.x)
	if SimBolso.alive(sim) and sim.nest.hp > 0:
		xs.append(sim.nest.pos.x)
	if xs.is_empty():
		return {}
	var tx: float = xs[int(sim.rand() * xs.size())]
	var dir: float = signf(tx - b.x) if absf(tx - b.x) > 1.0 else float(b.facing)
	var standoff: float = float(atk.get("standoff", DEFAULT_STANDOFF))
	var walk_max: float = sim.boss_def.speed_of(sim.boss_phase) * APPROACH_MAX * 0.85
	var move: float = clampf((tx - dir * standoff - b.x) * dir, 0.0, walk_max)
	var stand_x: float = sim.terrain.clamp_hard(b.x + dir * move, 80.0)
	var centre_x: float = sim.terrain.clamp_hard(stand_x + dir * standoff, 80.0)
	var width: float = float(atk.get("width", DEFAULT_WIDTH))
	var intent: Dictionary = make_intent(sim, atk, [], Vector2(centre_x, sim.terrain.find_surface_y(centre_x, 40.0)))
	intent["radius"] = width * 0.5
	intent["rect"] = Rect2(centre_x - width * 0.5, 0.0, width, sim.terrain.water_y)
	intent["dir"] = dir
	intent["stand_x"] = stand_x
	return intent


func start(sim: CombatSim, _atk: Dictionary, intent: Dictionary, run: Dictionary) -> void:
	var stand_x: float = float(intent["stand_x"])
	run["from"] = BossMotion.hover_point(sim, stand_x, sim.boss_def.hover_height) if sim.boss_def.flies else Vector2(stand_x, sim.boss.y)
	run["aim"] = intent["pos"]
	run["stage"] = "approach"
	run["t"] = 0.0


func step(sim: CombatSim, atk: Dictionary, intent: Dictionary, run: Dictionary, dt: float) -> bool:
	if strike_step(sim, run, INF, dt) != "arrived":
		return false
	sim.boss.facing = 1 if float(intent["dir"]) >= 0.0 else -1
	SimBolso.sweep(sim, intent["rect"], int(atk.get("damage", 20)), int(atk.get("nest_damage", 0)), float(atk.get("knockback", 240.0)), str(atk.get("dmg_label", "DMG_BOSS")))
	sim.boss_attack.emit(str(atk.get("id", "")), intent["pos"])
	return true

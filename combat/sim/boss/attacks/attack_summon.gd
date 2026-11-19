## SUMMON: calls `count` units of `unit` (a UnitDef) beside the boss; they join team 1 and act from the next enemy turn on.
## Flying units hover where they appear (that is their perch). Usually `once` with a high `priority`, on a phase change.
class_name AttackSummon
extends BossAttack

## Seconds of the wind-up before they appear.
const WIND_UP: float = 0.6
## Distance (px) between the summoned units.
const GAP: float = 60.0


func plan(sim: CombatSim, atk: Dictionary) -> Dictionary:
	if not atk.get("unit") is UnitDef:
		return {}
	return make_intent(sim, atk, [], Vector2(sim.boss.x, sim.boss.y))


func step(sim: CombatSim, atk: Dictionary, _intent: Dictionary, run: Dictionary, dt: float) -> bool:
	var b: SimFighter = sim.boss
	b.ai_state = "summon"
	run["t"] = float(run.get("t", 0.0)) + dt
	if float(run["t"]) < WIND_UP:
		return false
	var unit: UnitDef = atk["unit"]
	var count: int = int(atk.get("count", 1))
	var reg := SimPlacement.new(sim)
	for k in count:
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var x: float = sim.terrain.clamp_hard(b.x + side * GAP * (1 + (k >> 1)), 80.0)
		var idx: int = 0
		for f in sim.fighters:
			idx += 1 if f.team == b.team else 0
		var nm: String = "%s %d" % [sim.tx(unit.name_key), k + 1]
		if unit.flies:
			var p: Vector2 = BossMotion.hover_point(sim, x, maxf(60.0, sim.terrain.find_surface_y(x, BossMotion.CEILING) - b.y))
			var m: SimFighter = SimStory._make_unit(sim, b.team, idx, nm, Vector2(p.x, p.y + unit.radius + 2.0), unit, b.facing)
			m.y = p.y
			m.flying = true
			m.grounded = true
			m.perch = p
			m.jump_start_y = p.y
			m.peak_air_y = p.y
			sim.fighters.append(m)
		else:
			var spot: Vector2 = SimSetup.place_fighter(sim, reg, SimSetup.find_spawn_spot(sim, x, 200.0, false), unit.radius, 200.0)
			sim.fighters.append(SimStory._make_unit(sim, b.team, idx, nm, spot, unit, b.facing))
		SimCombat.smoke(sim, x, b.y, 6, "dust")
	sim.play("crate_pickup")
	sim.ftext(b.x, b.y - 48.0, "FT_BOSS_SUMMON", Palette.FT_ORANGE, 1.9)
	sim.boss_attack.emit(str(atk.get("id", "")), Vector2(b.x, b.y))
	sim.hud()
	return true

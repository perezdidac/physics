## GUST: a wind blast (the fly's buzz) on a marked area: every enemy within `radius` of the mark is pushed away from it
## (`knockback`, less at the edge) and takes `damage`. The intent is the "move away" warning.
class_name AttackGust
extends AttackArea


func _impact(sim: CombatSim, atk: Dictionary, intent: Dictionary) -> void:
	var pos: Vector2 = intent["pos"]
	sim.play("wind_gust")
	SimCombat.shockwave(sim, pos.x, pos.y, 10.0, float(intent["radius"]), 0.9, "220, 235, 255")
	sim.fx("skid_smoke", {"x": pos.x, "y": pos.y})
	for pair in in_area(sim, intent):
		var f: SimFighter = pair[0]
		var dmg: int = int(atk.get("damage", 0))
		if dmg > 0:
			SimCombat.damage_fighter(sim, f, dmg, str(atk.get("dmg_label", "DMG_BOSS")))
		var dir: float = signf(f.x - pos.x) if absf(f.x - pos.x) > 2.0 else float(sim.boss.facing)
		knock(f, dir, float(atk.get("knockback", 300.0)), float(pair[1]))

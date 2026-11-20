## STATUS: a cloud on a marked area: every enemy within `radius` gets `status` for `turns` (and `damage` if any), no knockback.
class_name AttackStatus
extends AttackArea


func _impact(sim: CombatSim, atk: Dictionary, intent: Dictionary) -> void:
	var pos: Vector2 = intent["pos"]
	SimCombat.smoke(sim, pos.x, pos.y, 14, "urticating")
	for pair in in_area(sim, intent):
		var f: SimFighter = pair[0]
		var dmg: int = int(atk.get("damage", 0))
		if dmg > 0:
			SimCombat.damage_fighter(sim, f, dmg, str(atk.get("dmg_label", "DMG_BOSS")))
		if f.alive and str(atk.get("status", "")) != "":
			SimStatus.apply(sim, f, str(atk["status"]), int(atk.get("turns", 1)))

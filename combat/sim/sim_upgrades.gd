## Hub upgrades in a story match (docs/nest_contracts.md section 2). The ids come from MatchConfig.upgrades; the sim never reads
## the save. Classic matches get none (level == null), so they never change.
class_name SimUpgrades
extends RefCounted

const LIST_PATH: String = "res://data/upgrades/upgrade_list.tres"

static var _cache: Array[UpgradeDef] = []


## Every upgrade of the hub, in shop order.
static func all() -> Array[UpgradeDef]:
	if _cache.is_empty():
		var list: UpgradeList = load(LIST_PATH)
		_cache.assign(list.upgrades)
	return _cache


## The upgrade with this id (null when unknown).
static func find(id: String) -> UpgradeDef:
	for u in all():
		if u.id == id:
			return u
	return null


## Clears the upgrade state of the sim (every match).
static func reset(sim: CombatSim) -> void:
	sim.upgrades = []
	sim.upgrade_effects = {}
	sim.damage_mult = [1.0, 1.0]
	sim.silk_webs_per_turn = 1


## Applies the owned upgrades to a story match once the squads, the arsenals and the nest exist. Unknown ids are ignored.
static func apply(sim: CombatSim, ids: Array[String]) -> void:
	if sim.level == null:
		return
	for id in ids:
		var u: UpgradeDef = find(id)
		if u == null or sim.upgrades.has(id):
			continue
		sim.upgrades.append(id)
		sim.upgrade_effects[u.effect] = float(sim.upgrade_effects.get(u.effect, 0.0)) + u.amount
		match u.effect:
			"MAX_HP_PCT":
				for f in sim.fighters:
					if f.team == 0:
						f.max_hp = roundi(f.max_hp * (1.0 + u.amount / 100.0))
						f.hp = f.max_hp
			"DAMAGE_PCT":
				sim.damage_mult[0] *= 1.0 + u.amount / 100.0
			"NEST_HP":
				if sim.nest != null:
					sim.nest.max_hp += roundi(u.amount)
					sim.nest.hp += roundi(u.amount)
			"WARM_SILK":
				sim.cold_active = false
			"EXTRA_SILK_WEB":
				sim.silk_webs_per_turn += 1
			"START_AMMO":
				if sim.level != null and sim.level.win_rule == "ONE_SHOT":
					continue  # the single shots of ONE_SHOT are the level's own count
				for w in sim.team_ammo[0]:
					var have: float = float(sim.team_ammo[0][w])
					if not is_inf(have) and have > 0.0:
						sim.team_ammo[0][w] = have + u.amount

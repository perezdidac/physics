## Generic status effects on fighters (SimFighter.statuses: status id -> turns left). What a status does comes from data
## (BossDef.statuses: damage per turn, damage label, silk_cleans). Every function is a no-op when nobody has a status.
class_name SimStatus
extends RefCounted

## Seconds the fighter may still walk after cleaning itself with silk (the cleaning uses its action).
const CLEAN_RETREAT: float = 2.5


## Data of a status ({} when unknown).
static func def_of(sim: CombatSim, id: String) -> Dictionary:
	if sim.boss_def == null:
		return {}
	return sim.boss_def.statuses.get(id, {})


## Gives a fighter a status for `turns` of its own turns (a longer one already there is kept).
static func apply(sim: CombatSim, f: SimFighter, id: String, turns: int) -> void:
	f.statuses[id] = maxi(int(f.statuses.get(id, 0)), turns)
	var key: String = str(def_of(sim, id).get("text", ""))
	if key != "":
		sim.ftext(f.x, f.y - 46.0, key, Palette.FT_PURPLE, 1.9, [f.name])
	sim.hud()


## Start of the fighter's turn: every status does its damage and loses one turn.
static func tick_turn_start(sim: CombatSim, f: SimFighter) -> void:
	if f.statuses.is_empty():
		return
	for id in f.statuses.keys():
		var d: Dictionary = def_of(sim, id)
		f.statuses[id] = int(f.statuses[id]) - 1
		if int(f.statuses[id]) <= 0:
			f.statuses.erase(id)
		var dmg: int = int(d.get("damage", 0))
		if dmg > 0 and f.alive:
			sim.play("worm_voice", {"kind": "ITCH"})
			SimCombat.damage_fighter(sim, f, dmg, str(d.get("label", "")))
			SimCombat.spawn_hairs(sim, f.x, f.y - 6.0, 10)
	sim.hud()


## True when the fighter carries a status that silk cleans.
static func has_silk_cleanable(sim: CombatSim, f: SimFighter) -> bool:
	for id in f.statuses:
		if bool(def_of(sim, id).get("silk_cleans", false)):
			return true
	return false


## The fighter just spun a silk web: it cleans off every status that silk cleans, which uses its action (only a short walk left).
static func on_silk_web(sim: CombatSim, f: SimFighter) -> void:
	if not has_silk_cleanable(sim, f):
		return
	for id in f.statuses.keys():
		if bool(def_of(sim, id).get("silk_cleans", false)):
			f.statuses.erase(id)
	sim.ftext(f.x, f.y - 46.0, "FT_CLEANED", Palette.FT_GREEN, 1.9, [f.name])
	SimCombat.spawn_hairs(sim, f.x, f.y - 6.0, 18)
	sim.has_acted_or_moved_this_turn = true
	sim.is_charging = false
	sim.charge_power = 0.0
	sim.turn_phase = CombatSim.Phase.RETREAT
	sim.phase_timer = CLEAN_RETREAT
	sim.hud()


## CPU caterpillars clean themselves with silk when they can, except while the boss is open to a hit (then they attack),
## unless what the statuses still have to do would kill them.
static func ai_wants_clean(sim: CombatSim, f: SimFighter) -> bool:
	if f.statuses.is_empty() or not sim.can_spin_web() or sim.silk_web_used_this_turn or not has_silk_cleanable(sim, f):
		return false
	return not SimBoss.is_vulnerable(sim) or pending_damage(sim, f) >= f.hp


## Damage the fighter's statuses will still do if left alone.
static func pending_damage(sim: CombatSim, f: SimFighter) -> int:
	var total: int = 0
	for id in f.statuses:
		total += int(def_of(sim, id).get("damage", 0)) * int(f.statuses[id])
	return total

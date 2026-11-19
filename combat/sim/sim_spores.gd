## La Processó: the Beauveria fungus spore clouds (LevelDef.spores). A cloud is a rectangle of the world that drifts sideways a fixed
## number of px every round (and turns around at the edges of the map). A fighter inside one at the start of its turn loses SPORE_DAMAGE HP:
## the whole squad at the start of the player's turn, an enemy unit at the start of its own sub-turn. No-op in levels without clouds.
class_name SimSpores
extends RefCounted

const SPORE_DAMAGE: int = 6
## The clouds stay this far (px) inside the playable span.
const EDGE: float = 120.0


static func reset(sim: CombatSim) -> void:
	sim.spores = []
	sim.spore_speeds = []


static func build(sim: CombatSim, level: LevelDef) -> void:
	sim.spores = level.spores.duplicate()
	for i in sim.spores.size():
		sim.spore_speeds.append(level.spore_drift[i] if i < level.spore_drift.size() else 0.0)


## True when the fighter's body is inside a cloud.
static func inside(sim: CombatSim, f: SimFighter) -> bool:
	for r in sim.spores:
		if r.has_point(Vector2(f.x, f.y)):
			return true
	return false


## A new round starts: the drifting clouds move on.
static func drift(sim: CombatSim) -> void:
	var moved: bool = false
	for i in sim.spores.size():
		if sim.spore_speeds[i] == 0.0:
			continue
		var r: Rect2 = sim.spores[i]
		r.position.x += sim.spore_speeds[i]
		var x_min: float = sim.terrain.arena_x0 + EDGE
		var x_max: float = sim.terrain.arena_x1 - EDGE
		if r.position.x < x_min or r.end.x > x_max:
			r.position.x = clampf(r.position.x, x_min, x_max - r.size.x)
			sim.spore_speeds[i] = -sim.spore_speeds[i]
		sim.spores[i] = r
		moved = true
	if moved:
		sim.hud()


## Start of a turn: the fighters of the acting side that stand in a cloud cough (the damage can kill).
static func on_turn_start(sim: CombatSim) -> void:
	if sim.spores.is_empty():
		return
	for f in sim.fighters:
		var turn_of: bool = f.team == 0 if sim.active_team == 0 else sim.is_actor(f)
		if turn_of and f.alive and not f.drowning and inside(sim, f):
			sim.spore_tick.emit(f, SPORE_DAMAGE)
			sim.play("worm_voice", {"kind": "ITCH"})
			SimCombat.damage_fighter(sim, f, SPORE_DAMAGE, "DMG_SPORES")
			SimCombat.smoke(sim, f.x, f.y - 6.0, 4, "dust")

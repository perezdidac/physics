## MELEE_TARGET: marks `targets` fighters (default 1; those without `status` first); next turn it strikes each in turn (a flying
## boss dives from above, a walker charges along the ground). A target that moved more than `dodge` px from its mark, or hid,
## is missed. Keys: damage, knockback, status, turns, targets, dodge, dmg_label; with rest_state it hops land_offset px away
## from the last victim and lands there (flying bosses). `followers_only`: it never marks the leader of a procession (unless alone).
class_name AttackMeleeTarget
extends BossAttack

## Extra reach (px) of the strike beyond body contact (a dive stopped by the ground still lands).
const REACH: float = 22.0
## Sideways hop (px) away from the last victim before it lands to rest (key land_offset).
const LAND_OFFSET: float = 70.0
## Longest settle hop (s).
const SETTLE_MAX: float = 0.8


func plan(sim: CombatSim, atk: Dictionary) -> Dictionary:
	var targets: Array[SimFighter] = pick_targets(sim, int(atk.get("targets", 1)), str(atk.get("status", "")), bool(atk.get("followers_only", false)))
	if targets.is_empty():
		return {}
	return make_intent(sim, atk, targets, Vector2.ZERO)


func start(sim: CombatSim, _atk: Dictionary, intent: Dictionary, run: Dictionary) -> void:
	run["i"] = 0
	_aim_at(sim, intent, run)


func step(sim: CombatSim, atk: Dictionary, intent: Dictionary, run: Dictionary, dt: float) -> bool:
	var marks: Array = intent["targets"]
	if str(run["stage"]) == "settle":
		return _settle(sim, run, dt)
	if int(run["i"]) >= marks.size():
		return true
	var mark: Dictionary = marks[int(run["i"])]
	var f: SimFighter = still_marked(sim, mark, float(atk.get("dodge", 0.0)))
	run["aim"] = _aim_point(f, mark)
	var b: SimFighter = sim.boss
	var contact: float = b.r + (f.r if f != null else 0.0) + 4.0
	if strike_step(sim, run, contact, dt) != "arrived":
		return false
	if f != null and Vector2(b.x, b.y).distance_to(Vector2(f.x, f.y)) <= contact + REACH:
		hit(sim, f, atk)
	else:
		var p: Vector2 = mark["pos"]
		sim.ftext(p.x, p.y - 30.0, "FT_DODGED", Palette.FT_GREEN, 1.6)
		sim.boss_attack.emit(str(atk.get("id", "")), p)
	run["i"] = int(run["i"]) + 1
	if int(run["i"]) < marks.size():
		_aim_at(sim, intent, run)
		return false
	if str(atk.get("rest_state", "")) == "":
		return true
	run["stage"] = "settle"
	run["t"] = 0.0
	run["from"] = Vector2(b.x + (1.0 if b.x >= float(mark["pos"].x) else -1.0) * float(atk.get("land_offset", LAND_OFFSET)), b.y)
	return false


## Sets up the approach to the current mark: where it strikes from.
func _aim_at(sim: CombatSim, intent: Dictionary, run: Dictionary) -> void:
	var mark: Dictionary = (intent["targets"] as Array)[int(run["i"])]
	var f: SimFighter = fighter_by_id(sim, int(mark["id"]))
	var aim: Vector2 = _aim_point(f if f != null and f.alive else null, mark)
	run["aim"] = aim
	run["from"] = strike_from(sim, aim)
	run["stage"] = "approach"
	run["t"] = 0.0


## Where the strike goes: just above the marked fighter (or its marked spot), so a dive does not plough into the ground.
static func _aim_point(f: SimFighter, mark: Dictionary) -> Vector2:
	var p: Vector2 = Vector2(f.x, f.y) if f != null else mark["pos"]
	return p - Vector2(0.0, 8.0)


## After the strikes: the hop aside, then the landing (flying bosses).
func _settle(sim: CombatSim, run: Dictionary, dt: float) -> bool:
	var b: SimFighter = sim.boss
	run["t"] = float(run["t"]) + dt
	var dest: Vector2 = run["from"]
	if not sim.boss_def.flies:
		return BossMotion.move_to(sim, b, dest, sim.boss_def.speed_of(sim.boss_phase), dt) or float(run["t"]) >= SETTLE_MAX
	b.ai_state = "return"
	if BossMotion.move_to(sim, b, dest, sim.boss_def.speed_of(sim.boss_phase) * 0.6, dt) or float(run["t"]) >= SETTLE_MAX:
		BossMotion.land(sim, b)
		return true
	return false

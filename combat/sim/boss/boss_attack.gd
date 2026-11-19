## Base of the boss attack handlers. One handler per attack `kind` (see BossAttacks); the attack itself is a Dictionary of
## BossDef.attacks. A handler announces (plan) and then executes (start + step, one call per frame in the boss's sub-turn).
## Subclasses override what they need; the static helpers are shared by every handler.
class_name BossAttack
extends RefCounted

## Flight phases of a strike: seconds of the telegraph hover and the longest approach / dive.
const WARN_TIME: float = 0.35
const APPROACH_MAX: float = 6.0
const DIVE_MAX: float = 1.5
## Height (px) over the target of the point a flying boss dives from.
const STOOP_HEIGHT: float = 110.0


## The intent of `atk` with targets chosen now; {} when the attack cannot be used (no target...). Default: an area on a visible enemy.
func plan(sim: CombatSim, atk: Dictionary) -> Dictionary:
	var vis: Array[SimFighter] = visible_targets(sim)
	if vis.is_empty():
		return {}
	var f: SimFighter = vis[int(sim.rand() * vis.size())]
	return make_intent(sim, atk, [], Vector2(f.x, f.y))


## Starts the execution of `intent`; `run` is scratch memory for this execution.
func start(_sim: CombatSim, _atk: Dictionary, _intent: Dictionary, _run: Dictionary) -> void:
	pass


## One frame of the execution; true when it is over.
func step(_sim: CombatSim, _atk: Dictionary, _intent: Dictionary, _run: Dictionary, _dt: float) -> bool:
	return true


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

## Enemies of the boss it can see: alive, not drowning, not hidden.
static func visible_targets(sim: CombatSim) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team != sim.boss.team and f.alive and not f.drowning and not f.hidden:
			out.append(f)
	return out


## Up to `n` different visible enemies, chosen at random; those without `avoid_status` first. `followers_only`: the leader of a
## procession is left out unless it is the only one visible.
static func pick_targets(sim: CombatSim, n: int, avoid_status: String = "", followers_only: bool = false) -> Array[SimFighter]:
	var fresh: Array[SimFighter] = []
	var marked: Array[SimFighter] = []
	var seen: Array[SimFighter] = visible_targets(sim)
	if followers_only and seen.any(func(f: SimFighter) -> bool: return not f.is_leader):
		var rest: Array[SimFighter] = []
		rest.assign(seen.filter(func(f: SimFighter) -> bool: return not f.is_leader))
		seen = rest
	for f in seen:
		if avoid_status != "" and f.statuses.has(avoid_status):
			marked.append(f)
		else:
			fresh.append(f)
	var out: Array[SimFighter] = []
	for pool in [fresh, marked]:
		var list: Array[SimFighter] = pool
		while out.size() < n and not list.is_empty():
			out.append(list.pop_at(int(sim.rand() * list.size())))
	return out


## The intent Dictionary of the contract: attack_id, kind, target_id, pos, radius, turns_left, label_key, label, targets.
static func make_intent(sim: CombatSim, atk: Dictionary, targets: Array[SimFighter], pos: Vector2) -> Dictionary:
	var marks: Array[Dictionary] = []
	var names: Array[String] = []
	for f in targets:
		marks.append({"id": f.id, "pos": Vector2(f.x, f.y)})
		names.append(f.name)
	var label_key: String = str(atk.get("label", ""))
	var label: String = ""
	if label_key != "":
		label = sim.tx(label_key, [] if names.is_empty() else [names_text(sim, names)])
	return {
		"attack_id": str(atk.get("id", "")),
		"kind": str(atk.get("kind", "")),
		"target_id": targets[0].id if not targets.is_empty() else -1,
		"pos": marks[0]["pos"] if not marks.is_empty() else pos,
		"radius": float(atk.get("radius", atk.get("dodge", 0.0))),
		"turns_left": 1,
		"label_key": label_key,
		"label": label,
		"targets": marks,
	}


## "A", "A i B", "A, B i C" with the translated "and".
static func names_text(sim: CombatSim, names: Array[String]) -> String:
	if names.size() == 1:
		return names[0]
	return sim.tx("BOSS_NAMES_AND", [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]])


static func fighter_by_id(sim: CombatSim, id: int) -> SimFighter:
	for f in sim.fighters:
		if f.id == id:
			return f
	return null


## The marked fighter if it did not dodge: alive and visible, and at most `dodge` px from the mark (or, once the enemy turn
## settled the marks, not marked "dodged"); else null.
static func still_marked(sim: CombatSim, mark: Dictionary, dodge: float) -> SimFighter:
	var f: SimFighter = fighter_by_id(sim, int(mark["id"]))
	if f == null or not f.alive or f.drowning:
		return null
	if mark.has("dodged"):
		return null if bool(mark["dodged"]) else f
	if f.hidden:
		return null
	if dodge > 0.0 and Vector2(f.x, f.y).distance_to(mark["pos"]) > dodge:
		return null
	return f


## A strike on a fighter: damage (BossDef armour does not apply: it is not the boss), knock away from the boss, status.
static func hit(sim: CombatSim, f: SimFighter, atk: Dictionary) -> void:
	var b: SimFighter = sim.boss
	var dmg: int = int(atk.get("damage", 0))
	if dmg > 0:
		SimCombat.damage_fighter(sim, f, dmg, str(atk.get("dmg_label", "DMG_BOSS")))
	knock(f, signf(f.x - b.x) if f.x != b.x else float(b.facing), float(atk.get("knockback", 160.0)), 1.0)
	var status: String = str(atk.get("status", ""))
	if status != "" and f.alive:
		SimStatus.apply(sim, f, status, int(atk.get("turns", 1)))
	SimCombat.spawn_hairs(sim, f.x, f.y - 4.0, 16)
	SimCombat.shockwave(sim, f.x, f.y - 4.0, 4.0, 50.0, 1.0)
	sim.play("home_run")
	sim.screen_shake.emit(9.0)
	sim.boss_attack.emit(str(atk.get("id", "")), Vector2(f.x, f.y))


## Knocks a fighter sideways (dir -1/+1) and up; `falloff` scales the push.
static func knock(f: SimFighter, dir: float, knockback: float, falloff: float) -> void:
	if knockback <= 0.0 or not f.alive:
		return
	f.vx = dir * knockback * falloff
	f.vy = minf(f.vy, 0.0) - knockback * 0.55 * falloff - 60.0
	f.grounded = false
	f.sliding = false
	f.is_voluntary_jump = false
	f.was_blasted = true
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	f.dizzy_timer = 1.6


## The point a boss strikes `aim` from: above it (flying bosses), beside it on the ground (walkers).
static func strike_from(sim: CombatSim, aim: Vector2) -> Vector2:
	var b: SimFighter = sim.boss
	var side: float = 1.0 if b.x >= aim.x else -1.0
	if not sim.boss_def.flies:
		return Vector2(aim.x + side * (b.r + 16.0), aim.y)
	for height in [STOOP_HEIGHT, 150.0, 75.0]:
		for s in [side, -side, 0.0]:
			var p := Vector2(aim.x + s * 70.0, maxf(BossMotion.CEILING, aim.y - height))
			if not sim.terrain.is_solid(p.x, p.y) and AiFlyer._clear_line(sim, p, aim):
				return p
	return Vector2(aim.x + side * 70.0, maxf(BossMotion.CEILING, aim.y - STOOP_HEIGHT))


## Approach → warn → strike state machine shared by the targeted attacks: approaches `run.from`, hovers WARN_TIME, then dives
## to `run.aim` (the caller updates it). Returns "approach", "warn", "dive" while busy and "arrived" on contact / at the mark.
static func strike_step(sim: CombatSim, run: Dictionary, contact: float, dt: float) -> String:
	var b: SimFighter = sim.boss
	var speed: float = sim.boss_def.speed_of(sim.boss_phase)
	run["t"] = float(run.get("t", 0.0)) + dt
	match str(run.get("stage", "approach")):
		"approach":
			b.ai_state = "approach"
			if BossMotion.move_to(sim, b, run["from"], speed, dt) or float(run["t"]) >= APPROACH_MAX:
				run["stage"] = "warn"
				run["t"] = 0.0
				sim.play("jump")
		"warn":
			b.ai_state = "warn"
			var aim: Vector2 = run["aim"]
			b.facing = 1 if aim.x >= b.x else -1
			if float(run["t"]) >= WARN_TIME:
				run["stage"] = "dive"
				run["t"] = 0.0
		"dive":
			b.ai_state = "dive"
			var aim: Vector2 = run["aim"]
			var close: bool = Vector2(b.x, b.y).distance_to(aim) <= contact
			if close or BossMotion.move_to(sim, b, aim, speed * 1.4, dt) or float(run["t"]) >= DIVE_MAX:
				return "arrived"
	return str(run.get("stage", "approach"))

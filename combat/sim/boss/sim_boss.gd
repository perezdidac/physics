## Turn-based boss framework (docs/boss_contracts.md): spawning the boss of a level, its sub-turn (execute the intent announced
## last turn, reposition, announce the next one), phases, armour and vulnerable states, rests, the water rule and the defeat.
## The boss is a fighter of team 1 whose UnitDef.ai is "BOSS"; its attacks run through BossAttacks. Every hook used by the
## other sim modules is a no-op when the match has no boss (sim.boss == null), so classic matches never change.
class_name SimBoss
extends RefCounted

## Longest repositioning flight (s) after the attack, and the time kept for it at the end of the sub-turn.
const MOVE_MAX: float = 4.0
const MOVE_RESERVE: float = 2.0
## Sideways offset (px) of the hover point from the enemy it hovers over.
const HOVER_SIDE: float = 120.0
## Speed factor of the drift back up into the air outside its own turn (after a rest or a splash).
const DRIFT_SPEED: float = 0.5

## True while a hit must skip the armour (the water rule).
static var _raw_hit: bool = false


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Clears the boss state of the sim (every match).
static func reset(sim: CombatSim) -> void:
	sim.boss = null
	sim.boss_def = null
	sim.boss_phase = 0
	sim.boss_state = ""
	sim.boss_intent = {}
	sim.boss_memory = {}


## Spawns the boss of the level (if any) on team 1: flying bosses hover over the ground at spawn_frac of the world.
static func spawn(sim: CombatSim, level: LevelDef) -> void:
	var def: BossDef = level.boss
	if def == null:
		return
	var unit := UnitDef.new()
	unit.id = def.id
	unit.name_key = def.name_key
	unit.max_hp = def.max_hp
	unit.radius = def.radius
	unit.can_jump = false
	unit.ai = "BOSS"
	unit.flies = def.flies
	unit.art_scale = def.art_scale
	var spot: Vector2 = SimSetup.find_spawn_spot(sim, sim.terrain.arena_at(def.spawn_frac), 400.0, false)
	if not def.flies:
		spot = SimSetup.place_fighter(sim, SimPlacement.new(sim), _walker_spot(sim, spot), def.radius, 260.0)
	var idx: int = 0
	for f in sim.fighters:
		idx += 1 if f.team == 1 else 0
	var b: SimFighter = SimStory._make_unit(sim, 1, idx, sim.tx(def.name_key), spot, unit, -1)
	if def.flies:
		var p: Vector2 = BossMotion.hover_point(sim, b.x, def.hover_height)
		b.x = p.x
		b.y = p.y
		b.jump_start_y = p.y
		b.peak_air_y = p.y
		b.perch = p
		b.flying = true
		b.grounded = true
	sim.fighters.append(b)
	sim.boss = b
	sim.boss_def = def
	sim.boss_phase = 1
	sim.boss_state = "IDLE"
	sim.boss_memory = {"cooldowns": {}, "used": {}, "rest": {}, "turns": 0, "drift": Vector2.INF, "defeated": false}


## The ground spot a walking boss starts on: the one nearest to `wish` (x) that has a walking path to the squad (the wish itself when
## there is none, or in a match without a walking map).
static func _walker_spot(sim: CombatSim, wish: Vector2) -> Vector2:
	if sim.nav == null or sim.fighters.is_empty():
		return wish
	var squad: SimFighter = sim.fighters[0]
	var best := Vector2.INF
	for c in sim.nav.reachable(Vector2(squad.x, squad.y), false, true):
		if best == Vector2.INF or absf(c.x - wish.x) < absf(best.x - wish.x):
			best = Vector2(c.x, c.y)
	return wish if best == Vector2.INF else best


# ---------------------------------------------------------------------------
# Hooks of the turn system
# ---------------------------------------------------------------------------

## Start of the enemy turn: the boss plays last in the swarm, and the marks of its intent are settled now: a marked fighter that
## moved more than the attack's `dodge` px away, or hid, during its team's turn dodged it; the others are hit wherever the
## other enemies knock them before the boss acts.
static func begin_enemy_turn(sim: CombatSim) -> void:
	if sim.boss == null:
		return
	if sim.swarm_queue.has(sim.boss.id):
		sim.swarm_queue.erase(sim.boss.id)
		sim.swarm_queue.append(sim.boss.id)
	var atk: Dictionary = attack_of(sim, sim.boss_intent)
	for mark in sim.boss_intent.get("targets", []):
		mark["dodged"] = BossAttack.still_marked(sim, mark, float(atk.get("dodge", 0.0))) == null


## Seconds of a swarm sub-turn: the boss gets BossDef.turn_time, the other units SimStory.SWARM_TURN_TIME.
static func swarm_time(sim: CombatSim, f: SimFighter) -> float:
	return sim.boss_def.turn_time if sim.boss != null and f == sim.boss else SimStory.SWARM_TURN_TIME


## True when the level is won by beating the boss (win rule BOSS, or BOSS_OR_GOAL: the goal wins too) and the boss is down.
static func beaten(sim: CombatSim) -> bool:
	return sim.boss != null and sim.level != null and (sim.level.win_rule == "BOSS" or sim.level.win_rule == "BOSS_OR_GOAL") and (not sim.boss.alive or sim.boss.drowning)


## True while the boss takes full damage (its state is one of BossDef.vulnerable_states).
static func is_vulnerable(sim: CombatSim) -> bool:
	return sim.boss != null and sim.boss_def.vulnerable_states.has(sim.boss_state)


# ---------------------------------------------------------------------------
# Damage hooks (SimCombat.damage_fighter)
# ---------------------------------------------------------------------------

## Damage after the armour: outside the vulnerable states the boss takes damage x armored_mult (at least 1) and shows "ARMORED".
static func scale_damage(sim: CombatSim, f: SimFighter, dmg: int) -> int:
	if sim.boss == null or f != sim.boss or _raw_hit or is_vulnerable(sim):
		return dmg
	var out: int = maxi(1, roundi(dmg * sim.boss_def.armored_mult))
	if out < dmg:
		sim.ftext(f.x, f.y - 50.0, "FT_ARMORED", Palette.FT_GREY, 1.3)
	return out


## After any damage: defeat, phase change, the hits that end a rest.
static func on_damaged(sim: CombatSim, f: SimFighter) -> void:
	if sim.boss == null or f != sim.boss:
		return
	if not f.alive:
		_defeat(sim)
		return
	var phase: int = 1
	for t in sim.boss_def.phases:
		if float(f.hp) <= t * f.max_hp:
			phase += 1
	if phase > sim.boss_phase:
		sim.boss_phase = phase
		sim.play("urticating_burst")
		sim.ftext(f.x, f.y - 62.0, "FT_BOSS_PHASE", Palette.FT_ORANGE, 2.2)
		sim.boss_phase_changed.emit(phase)
	var rest: Dictionary = sim.boss_memory["rest"]
	if not rest.is_empty() and int(rest["hits"]) > 0:
		rest["hits"] = int(rest["hits"]) - 1
		if int(rest["hits"]) == 0:
			end_rest(sim)
	sim.boss_changed.emit()


## Water rule (BossDef.water_damage >= 0): knocked into the water, the boss loses that much HP (no armour) and flies out.
## True when it handled the fall (the fighter must not drown).
static func rescue_from_water(sim: CombatSim, f: SimFighter) -> bool:
	if sim.boss == null or f != sim.boss or sim.boss_def.water_damage < 0:
		return false
	var wy: float = sim.terrain.water_y
	sim.play("plunge")
	SimCombat.water_plunge(sim, f.x, wy, 1.0)
	sim.ftext(f.x, wy - 40.0, "FT_BOSS_SPLASH", Palette.FT_WATER, 1.8)
	f.y = wy - 40.0
	BossMotion.take_off(f)
	_raw_hit = true
	SimCombat.damage_fighter(sim, f, sim.boss_def.water_damage, "DMG_SPLASH")
	_raw_hit = false
	if not sim.boss_memory["rest"].is_empty():
		end_rest(sim)
	sim.boss_memory["drift"] = BossMotion.hover_point(sim, f.x, sim.boss_def.hover_height)
	return true


# ---------------------------------------------------------------------------
# Per frame (CombatSim.step) and states
# ---------------------------------------------------------------------------

## Every frame: defeat check, the rest timer (it runs during the enemy's turn), knocked out of the air -> STUNNED,
## and the drift back up into the air outside its own turn.
static func tick(sim: CombatSim, dt: float) -> void:
	var b: SimFighter = sim.boss
	if b == null:
		return
	if not b.alive or b.drowning:
		_defeat(sim)
		return
	var rest: Dictionary = sim.boss_memory["rest"]
	if not rest.is_empty() and float(rest["time"]) > 0.0 and sim.active_team != b.team and sim.turn_phase == CombatSim.Phase.TURN_PLAY:
		rest["time"] = float(rest["time"]) - dt
		if float(rest["time"]) <= 0.0:
			end_rest(sim)
	if sim.boss_def.flies and not b.flying and b.ai_state == "fall" and rest.is_empty() and sim.boss_state != "STUNNED":
		set_state(sim, "STUNNED")
	var own_turn: bool = sim.active_fighter == b and sim.turn_phase == CombatSim.Phase.TURN_PLAY
	var drift: Vector2 = sim.boss_memory["drift"]
	if not own_turn and drift != Vector2.INF and b.flying:
		if BossMotion.move_to(sim, b, drift, sim.boss_def.speed_of(sim.boss_phase) * DRIFT_SPEED, dt):
			sim.boss_memory["drift"] = Vector2.INF
			b.ai_state = "idle"


static func set_state(sim: CombatSim, state: String) -> void:
	if sim.boss_state != state:
		sim.boss_state = state
		sim.boss_changed.emit()


static func set_intent(sim: CombatSim, intent: Dictionary) -> void:
	sim.boss_intent = intent
	sim.boss_intent_changed.emit()
	sim.hud()


## Enters the after-state of an attack (rest_state, e.g. "RESTING"): it lasts until the boss's next turn, or rest_time seconds of
## the enemy's turn, or rest_hits hits.
static func enter_rest(sim: CombatSim, atk: Dictionary) -> void:
	sim.boss_memory["rest"] = {"state": str(atk["rest_state"]), "time": float(atk.get("rest_time", 0.0)), "hits": int(atk.get("rest_hits", 0))}
	set_state(sim, str(atk["rest_state"]))
	sim.ftext(sim.boss.x, sim.boss.y - 50.0, str(atk.get("rest_text", "FT_BOSS_LANDS")), Palette.FT_GOLD_BRIGHT, 2.0)
	sim.hud()


## Ends a rest: armoured again ("RECOVER"); a flying boss takes off and drifts back up.
static func end_rest(sim: CombatSim) -> void:
	sim.boss_memory["rest"] = {}
	set_state(sim, "RECOVER")
	var b: SimFighter = sim.boss
	if sim.boss_def.flies and b.alive:
		BossMotion.take_off(b)
		sim.boss_memory["drift"] = BossMotion.hover_point(sim, b.x, sim.boss_def.hover_height)
		sim.ftext(b.x, b.y - 50.0, "FT_BOSS_TAKEOFF", Palette.FT_GREY, 1.6)
	sim.hud()


static func _defeat(sim: CombatSim) -> void:
	if bool(sim.boss_memory.get("defeated", true)):
		return
	sim.boss_memory["defeated"] = true
	sim.boss_memory["rest"] = {}
	set_state(sim, "DEFEATED")
	set_intent(sim, {})
	var b: SimFighter = sim.boss
	sim.ftext(b.x, b.y - 64.0, "FT_BOSS_DEFEATED", Palette.FT_GOLD_BRIGHT, 2.6)
	sim.screen_shake.emit(18.0)
	sim.boss_defeated.emit()
	sim.hud()


# ---------------------------------------------------------------------------
# The boss's sub-turn (AiBrain dispatches here for UnitDef.ai == "BOSS")
# ---------------------------------------------------------------------------

## One AI frame of the boss's own sub-turn: 1. execute the intent announced last turn, 2. reposition, 3. announce the next one.
static func update(sim: CombatSim, dt: float) -> void:
	var b: SimFighter = sim.active_fighter
	if b != sim.boss:
		sim.end_turn()
		return
	if sim.ai_plan.is_empty():
		sim.ai_plan = {"mode": "boss", "walk_dir": 0, "step": "start", "t": 0.0, "total_time": 0.0, "run": {}}
	var plan: Dictionary = sim.ai_plan
	plan["total_time"] = float(plan["total_time"]) + dt
	plan["t"] = float(plan["t"]) + dt
	if not b.flying and not b.grounded:
		return
	var def: BossDef = sim.boss_def
	var late: bool = float(plan["total_time"]) > sim.sub_turn_time - MOVE_RESERVE
	match str(plan["step"]):
		"start":
			sim.boss_memory["turns"] = int(sim.boss_memory["turns"]) + 1
			if not sim.boss_memory["rest"].is_empty():
				end_rest(sim)
			else:
				set_state(sim, "RECOVER")
				if def.flies and not b.flying:
					BossMotion.take_off(b)
			sim.boss_memory["drift"] = Vector2.INF
			var atk: Dictionary = attack_of(sim, sim.boss_intent)
			if atk.is_empty():
				_next(plan, "move")
			else:
				set_state(sim, "ACT")
				BossAttacks.handler(str(atk["kind"])).start(sim, atk, sim.boss_intent, plan["run"])
				_next(plan, "act")
		"act":
			var atk: Dictionary = attack_of(sim, sim.boss_intent)
			if atk.is_empty() or BossAttacks.handler(str(atk["kind"])).step(sim, atk, sim.boss_intent, plan["run"], dt) or late:
				set_intent(sim, {})
				if not atk.is_empty() and str(atk.get("rest_state", "")) != "" and b.alive:
					if def.flies and b.flying:
						BossMotion.land(sim, b)
					enter_rest(sim, atk)
					_next(plan, "announce")
				else:
					set_state(sim, "RECOVER")
					_next(plan, "move")
		"move":
			if not plan.has("dest"):
				plan["dest"] = _hover_spot(sim)
			if def.flies:
				b.ai_state = "return"
			if not def.flies or BossMotion.move_to(sim, b, plan["dest"], def.speed_of(sim.boss_phase), dt) or float(plan["t"]) >= MOVE_MAX or late:
				_next(plan, "announce")
		"announce":
			b.ai_state = "rest" if not sim.boss_memory["rest"].is_empty() else "idle"
			announce(sim)
			_next(plan, "done")
			sim.end_turn()


static func _next(plan: Dictionary, step_name: String) -> void:
	plan["step"] = step_name
	plan["t"] = 0.0


## The BossDef.attacks entry of an intent ({} when none).
static func attack_of(sim: CombatSim, intent: Dictionary) -> Dictionary:
	var i: int = int(intent.get("attack_index", -1))
	if sim.boss_def == null or i < 0 or i >= sim.boss_def.attacks.size():
		return {}
	return sim.boss_def.attacks[i]


## Where a flying boss waits: hover_height over the ground beside a visible enemy (on the boss's side), else where it is.
static func _hover_spot(sim: CombatSim) -> Vector2:
	var b: SimFighter = sim.boss
	var vis: Array[SimFighter] = BossAttack.visible_targets(sim)
	var x: float = b.x
	if not vis.is_empty():
		var f: SimFighter = vis[int(sim.rand() * vis.size())]
		x = f.x + (HOVER_SIDE if b.x >= f.x else -HOVER_SIDE)
	return BossMotion.hover_point(sim, x, sim.boss_def.hover_height)


## Picks and announces the next intent: among the attacks of the current phase not on cooldown (and `once` ones not used yet),
## the highest `priority` first, weighted by `weight`; an attack whose handler cannot plan (no target) is skipped.
static func announce(sim: CombatSim) -> void:
	var def: BossDef = sim.boss_def
	var cds: Dictionary = sim.boss_memory["cooldowns"]
	var used: Dictionary = sim.boss_memory["used"]
	var streak: int = int(sim.boss_memory.get("streak", 0))
	var pool: Array[Dictionary] = []
	for a in def.attacks_of_phase(sim.boss_phase):
		if int(cds.get(a.get("id", ""), 0)) <= 0 and not (bool(a.get("once", false)) and used.has(a.get("id", ""))) and int(a.get("after", 0)) <= streak:
			pool.append(a)
	var intent: Dictionary = {}
	var chosen: Dictionary = {}
	while intent.is_empty() and not pool.is_empty():
		var top: int = -1000000
		for a in pool:
			top = maxi(top, int(a.get("priority", 0)))
		var group: Array[Dictionary] = []
		group.assign(pool.filter(func(a: Dictionary) -> bool: return int(a.get("priority", 0)) == top))
		var a: Dictionary = _weighted(sim, group)
		pool.erase(a)
		var h: BossAttack = BossAttacks.handler(str(a.get("kind", "")))
		intent = h.plan(sim, a) if h != null else {}
		chosen = a
	for id in cds.keys():
		cds[id] = int(cds[id]) - 1
	if intent.is_empty():
		set_intent(sim, {})
	else:
		cds[chosen.get("id", "")] = int(chosen.get("cooldown", 0))
		used[chosen.get("id", "")] = true
		sim.boss_memory["streak"] = 0 if int(chosen.get("after", 0)) > 0 else streak + 1
		intent["attack_index"] = def.attacks.find(chosen)
		set_intent(sim, intent)
		var b: SimFighter = sim.boss
		if str(intent["label"]) != "":
			sim.float_text.emit(Vector2(b.x, b.y - 56.0), str(intent["label"]), Palette.FT_ORANGE, 2.6)
	if sim.boss_memory["rest"].is_empty():
		set_state(sim, "IDLE" if intent.is_empty() else "INTENT")


static func _weighted(sim: CombatSim, group: Array[Dictionary]) -> Dictionary:
	var total: float = 0.0
	for a in group:
		total += maxf(0.0, float(a.get("weight", 1.0)))
	var r: float = sim.rand() * total
	for a in group:
		r -= maxf(0.0, float(a.get("weight", 1.0)))
		if r < 0.0:
			return a
	return group[group.size() - 1]

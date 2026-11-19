## The wild boar of La Processó (UnitDef.ai "CHARGER"): an environmental hazard, not an enemy. It waits off the map. At the enemy turn of its
## round (LevelDef.boar_rounds) it announces a charge across a band of the map (state "warn", `sim.boar_intents`); at the next enemy turn it
## runs through the band from the announced side, hurting and knocking back every fighter it touches, and leaves ("gone"). It cannot be
## hurt (UnitDef.killable == false). A boar is one charge: two charges need two boars.
class_name AiCharger
extends RefCounted

## Width (px) of the band, and how far ahead of the leader (px) its near edge is placed when announced.
const BAND_WIDTH: float = 260.0
const BAND_GAP_MIN: float = 190.0
const BAND_GAP_RANGE: float = 90.0
## The boar starts and ends its run this far (px) outside the band.
const RUN_UP: float = 140.0
const CHARGE_SPEED: float = 560.0
const HIT_DAMAGE: int = 22
const HIT_KNOCKBACK: float = 300.0
## Where a boar waits (off the map) and the first round it comes when the level lists none.
const WAIT_POS: Vector2 = Vector2(-160.0, 80.0)
const DEFAULT_FIRST_ROUND: int = 2
const DEFAULT_EVERY: int = 2


## Index of a boar among the boars of the match (0 = the first to come).
static func boar_index(sim: CombatSim, f: SimFighter) -> int:
	var i: int = 0
	for g in sim.fighters:
		if g.unit != null and g.unit.ai == "CHARGER":
			if g == f:
				return i
			i += 1
	return -1


## True when the boar has something to do in this enemy turn (it announces, or it charges); gone and waiting boars sit it out.
static func acts_now(sim: CombatSim, f: SimFighter) -> bool:
	if f.unit == null or f.unit.ai != "CHARGER":
		return true
	return f.ai_state == "warn" or f.ai_state == "charge" or (f.ai_state != "gone" and _due(sim, f))


static func _due(sim: CombatSim, f: SimFighter) -> bool:
	var i: int = boar_index(sim, f)
	var rounds: Array[int] = sim.level.boar_rounds
	var round_no: int = rounds[i] if i < rounds.size() else DEFAULT_FIRST_ROUND + i * DEFAULT_EVERY
	return sim.round_number >= round_no and sim.convoy_leader != null and sim.convoy_leader.alive


## Puts a boar in its waiting place (spawn and after the charge).
static func park(f: SimFighter, state: String) -> void:
	f.x = WAIT_POS.x
	f.y = WAIT_POS.y
	f.flying = true
	f.grounded = true
	f.vx = 0.0
	f.vy = 0.0
	f.ai_state = state


## One AI frame of the boar's sub-turn.
static func update(sim: CombatSim, dt: float) -> void:
	var af: SimFighter = sim.active_fighter
	if sim.ai_plan.is_empty():
		sim.ai_plan = {"mode": "charger", "walk_dir": 0, "total_time": 0.0, "hit": []}
	sim.ai_plan["total_time"] = float(sim.ai_plan["total_time"]) + dt
	af.flying = true
	af.grounded = true
	af.vx = 0.0
	af.vy = 0.0
	match af.ai_state:
		"charge":
			_run(sim, af, dt)
		"warn":
			_start_charge(sim, af)
		"gone":
			sim.end_turn()
		_:
			if _due(sim, af):
				_announce(sim, af)
			sim.end_turn()


## The band is placed ahead of the leader (toward the goal), clear of the line, and a side is drawn.
static func _announce(sim: CombatSim, af: SimFighter) -> void:
	var l: SimFighter = sim.convoy_leader
	var dir: float = 1.0 if sim.goal_x < 0.0 or sim.goal_x >= l.x else -1.0
	var near: float = l.x + dir * (BAND_GAP_MIN + sim.rand() * BAND_GAP_RANGE)
	var x0: float = near if dir > 0.0 else near - BAND_WIDTH
	x0 = clampf(x0, sim.terrain.arena_x0 + sim.terrain.edge_margin(260.0), sim.terrain.arena_x1 - sim.terrain.edge_margin(260.0) - BAND_WIDTH)
	var band := Rect2(x0, 0.0, BAND_WIDTH, sim.terrain.water_y)
	var side: int = -1 if sim.rand() < 0.5 else 1
	af.ai_state = "warn"
	af.facing = -side
	sim.boar_intents.append({"boar": af, "band": band, "side": side, "turns_left": 1, "ground_y": l.y + l.r})
	sim.ftext(band.position.x + band.size.x * 0.5, 120.0, "FT_BOAR_WARN", Palette.FT_ORANGE, 2.6)
	sim.play("jump")
	sim.boar_telegraph.emit(af, band, side)
	sim.hud()


static func _intent_of(sim: CombatSim, af: SimFighter) -> Dictionary:
	for it in sim.boar_intents:
		if it["boar"] == af:
			return it
	return {}


static func _start_charge(sim: CombatSim, af: SimFighter) -> void:
	var it: Dictionary = _intent_of(sim, af)
	if it.is_empty():
		af.ai_state = "gone"
		sim.end_turn()
		return
	var band: Rect2 = it["band"]
	var side: int = it["side"]
	af.ai_state = "charge"
	af.x = band.position.x - RUN_UP if side < 0 else band.end.x + RUN_UP
	af.facing = -side
	af.y = _ground(sim, af, float(it["ground_y"]))
	sim.ai_plan["hit"] = []
	sim.play("home_run")
	sim.screen_shake.emit(6.0)
	sim.boar_charge.emit(af, band, side)
	sim.hud()


## Centre y of the boar standing on the tier of the ground at its x closest to the height it was announced at (its own y when there is none).
static func _ground(sim: CombatSim, af: SimFighter, ref: float) -> float:
	var best: float = NAN
	for tier in sim.terrain.find_all_walkable_surfaces_at_x(af.x):
		if is_nan(best) or absf(float(tier) - ref) < absf(best - ref):
			best = float(tier)
	return af.y if is_nan(best) else best - af.r - 2.0


static func _run(sim: CombatSim, af: SimFighter, dt: float) -> void:
	var it: Dictionary = _intent_of(sim, af)
	var band: Rect2 = it["band"]
	var side: int = it["side"]
	var dir: float = -float(side)
	af.x += dir * CHARGE_SPEED * dt
	af.y = _ground(sim, af, float(it["ground_y"]))
	af.facing = int(dir)
	af.walk_cycle += dt * 30.0
	sim.play("crawl_step")
	for g in sim.fighters:
		if g == af or not g.alive or g.drowning or (g.unit != null and g.unit.ai == "CHARGER") or sim.ai_plan["hit"].has(g.id):
			continue
		if absf(g.x - af.x) <= af.r + g.r + 6.0 and absf(g.y - af.y) <= 38.0:
			sim.ai_plan["hit"].append(g.id)
			SimCombat.damage_fighter(sim, g, HIT_DAMAGE, "DMG_BOAR")
			BossAttack.knock(g, dir, HIT_KNOCKBACK, 1.0)
			SimCombat.spawn_hairs(sim, g.x, g.y - 4.0, 12)
			sim.play("home_run")
			sim.screen_shake.emit(9.0)
			sim.boar_hit.emit(af, g)
	var past: bool = af.x > band.end.x + RUN_UP if dir > 0.0 else af.x < band.position.x - RUN_UP
	if past or float(sim.ai_plan["total_time"]) > 4.0:
		sim.boar_intents.erase(it)
		park(af, "gone")
		sim.boar_gone.emit(af)
		sim.hud()
		sim.end_turn()

## El Bolsó (docs/nest_contracts.md): the big silk nest the squad defends in the NEST stage. One instance per match
## (`sim.nest`, null in every other match) plus the static rules around it: placing it, damage and repair, the shelter inside,
## the cold, the forestry pole, and the target the birds peck. Every hook used by the other sim modules is a no-op when
## `sim.nest == null` (and the cold and the pole only exist in levels that ask for them), so classic matches never change.
## Not to be mixed up with SimNest, the little pendulum nest that hangs from the trees.
class_name SimBolso
extends RefCounted

## Width and height (px) of the nest; it stands on the ground, `pos` is its centre.
const SIZE: Vector2 = Vector2(170.0, 110.0)
## Damage of a sheltered caterpillar is multiplied by this.
const SHELTER_MULT: float = 0.5
## HP lost by a caterpillar outside the nest at the start of its turn (cold levels).
const COLD_DAMAGE: int = 5
## HP a repair gives, and how close (px to the nest) the caterpillar must be.
const REPAIR_HP: int = 40
const REPAIR_REACH: float = 60.0
## Seconds the caterpillar may still walk after repairing (the repair uses its action).
const REPAIR_RETREAT: float = 2.5
## Explosions of the player's own turn hurt the nest this much less.
const FRIENDLY_MULT: float = 0.5
## Birds go for the nest when its distance times this is not longer than the distance of the nearest caterpillar.
const BIRD_BIAS: float = 0.75
## How far (px) from the squad the nest is looked for. A spot is "good" (the level seeds are chosen so) when the ground under the nest
## differs at most FLAT_TOLERANCE px between its centre and its two sides, at most MAX_BURIED of its area is rock and no tree or tower is in it.
const SEARCH_RADIUS: float = 600.0
const FLAT_TOLERANCE: float = 24.0
const MAX_BURIED: float = 0.12
## The CPU squad repairs when the nest is at or below this fraction of its HP.
const AI_REPAIR_BELOW: float = 0.7
## The pole: every POLE_EVERY rounds a band of POLE_WIDTH px is marked at the start of the player's turn, and swept at the start of
## the enemy turn that follows.
const POLE_EVERY: int = 2
const POLE_WIDTH: float = 130.0
const POLE_DAMAGE: int = 22
const POLE_NEST_DAMAGE: int = 50
const POLE_KNOCKBACK: float = 220.0
## Id of the stand-in fighter the birds fly at when they go for the nest (never in sim.fighters).
const TARGET_ID: int = -100

var pos: Vector2 = Vector2.ZERO
var size: Vector2 = SIZE
var hp: int = 300
var max_hp: int = 300
var destroyed: bool = false
## The point the birds dive at (the top of the nest), as a fighter-shaped target.
var target: SimFighter = SimFighter.new()


## The area of the nest (Rect2 in world pixels).
func rect() -> Rect2:
	return Rect2(pos - size * 0.5, size)


## Distance (px) from a point to the area of the nest (0 inside).
func distance_to(p: Vector2) -> float:
	var r: Rect2 = rect()
	return Vector2(maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x), maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)).length()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Clears the nest state of the sim (every match).
static func reset(sim: CombatSim) -> void:
	sim.nest = null
	sim.cold_active = false
	sim.pole_band = Rect2()
	sim.pole_state = ""


## Puts the nest of the level (LevelDef.nest_hp > 0) on flat ground close to the squad, clear of the trees and towers.
static func build(sim: CombatSim, level: LevelDef) -> void:
	if level.nest_hp <= 0:
		return
	var n := SimBolso.new()
	n.hp = level.nest_hp
	n.max_hp = level.nest_hp
	n.pos = _find_spot(sim)
	n.target.id = TARGET_ID
	n.target.team = 0
	n.target.alive = true
	n.target.r = 20.0
	n.target.x = n.pos.x
	n.target.y = n.pos.y - n.size.y * 0.5 + 18.0
	sim.nest = n
	sim.cold_active = level.cold
	sim.nest_changed.emit()


## Centre of the nest: among the walkable tiers near the squad (on its tier), the spot with the flattest ground, clear of trees and
## towers and rock, as close to the squad as possible (the cost of a spot adds those up; first the nearest one wins ties).
static func _find_spot(sim: CombatSim) -> Vector2:
	var sx: float = 0.0
	var sy: float = 0.0
	var n: int = 0
	for f in sim.fighters:
		if f.team == 0:
			sx += f.x
			sy += f.y + f.r
			n += 1
	sx /= maxf(1.0, n)
	sy /= maxf(1.0, n)
	var stamps: Array[Rect2] = SimPlacement.stamp_rects(sim.terrain)
	var walkable: Dictionary = {}
	for c in sim.nav.reachable(Vector2(sx, sy - 14.0), true):
		var col: int = roundi(c.x / SimNav.STEP)
		if not walkable.has(col):
			walkable[col] = []
		walkable[col].append(c.y)
	var half_w: float = SIZE.x * 0.5
	var best := Vector2(sx, sy - SIZE.y * 0.5)
	var best_cost: float = INF
	var r: float = 0.0
	while r <= SEARCH_RADIUS:
		for d in ([0] if r == 0.0 else [-1, 1]):
			var x: float = sim.terrain.clamp_hard(sx + d * r, half_w + 60.0)
			var ground: float = NAN
			for tier in sim.terrain.find_all_walkable_surfaces_at_x(x):
				if absf(float(tier) - sy) <= 40.0 and (is_nan(ground) or absf(float(tier) - sy) < absf(ground - sy)):
					ground = float(tier)
			if is_nan(ground) or ground > sim.terrain.water_y - 40.0 or not _reachable(walkable, x, ground):
				continue
			var slope: float = maxf(absf(sim.terrain.find_surface_y(x - half_w * 0.8, ground - 40.0) - ground), absf(sim.terrain.find_surface_y(x + half_w * 0.8, ground - 40.0) - ground))
			var area := Rect2(x - half_w, ground - SIZE.y, SIZE.x, SIZE.y)
			var cost: float = slope + (100.0 if SimPlacement.hits_stamp(stamps, area) else 0.0) + 200.0 * SimPlacement.buried_fraction(sim.terrain, area) + 0.04 * r
			if cost < best_cost:
				best_cost = cost
				best = Vector2(x, ground - SIZE.y * 0.5)
		r += 10.0
	return best


## True when the squad can walk to the ground point (x, y): `walkable` maps nav columns to the surfaces the squad reaches.
static func _reachable(walkable: Dictionary, x: float, y: float) -> bool:
	var col: int = roundi(x / SimNav.STEP)
	for c in [col - 1, col, col + 1]:
		for wy in walkable.get(c, []):
			if absf(float(wy) - y) <= 6.0:
				return true
	return false


# ---------------------------------------------------------------------------
# Damage, repair, shelter
# ---------------------------------------------------------------------------

## True while the nest stands.
static func alive(sim: CombatSim) -> bool:
	return sim.nest != null and not sim.nest.destroyed


## True when the fighter stands inside the area of the nest.
static func in_nest(sim: CombatSim, f: SimFighter) -> bool:
	return sim.nest != null and not sim.nest.destroyed and sim.nest.rect().has_point(Vector2(f.x, f.y))


## Hurts the nest: float text, the `nest_hit` signal, and the defeat at 0 HP.
static func damage(sim: CombatSim, amount: int, at: Vector2) -> void:
	var n: SimBolso = sim.nest
	if n == null or n.destroyed or amount <= 0 or sim.turn_phase == CombatSim.Phase.GAME_OVER:
		return
	n.hp = maxi(0, n.hp - amount)
	sim.ftext(at.x, n.rect().position.y - 8.0, "FT_NEST_DAMAGE", Palette.FT_RED, 1.5, [amount])
	sim.nest_hit.emit(at, amount)
	sim.nest_changed.emit()
	if n.hp <= 0:
		_destroy(sim, n)
	sim.hud()


static func _destroy(sim: CombatSim, n: SimBolso) -> void:
	n.destroyed = true
	sim.pole_band = Rect2()
	sim.pole_state = ""
	sim.ftext(n.pos.x, n.pos.y - 40.0, "FT_NEST_DESTROYED", Palette.FT_RED, 2.6)
	SimCombat.smoke(sim, n.pos.x, n.pos.y, 14, "silk")
	sim.screen_shake.emit(16.0)
	sim.nest_destroyed.emit()
	end_match_lost(sim)


## The match ends lost (the nest fell).
static func end_match_lost(sim: CombatSim) -> void:
	if sim.turn_phase == CombatSim.Phase.GAME_OVER:
		return
	sim.turn_phase = CombatSim.Phase.GAME_OVER
	sim.winner = 1
	sim.is_charging = false
	sim.game_over.emit(1, SimTurns.make_game_stats(sim))
	sim.hud()


## An explosion: the nest takes damage by the distance from the centre of the blast to its area (like a fighter, down to 14 %).
## The blasts of the player's own turn hurt it only FRIENDLY_MULT as much.
static func on_explosion(sim: CombatSim, ex: float, ey: float, hit_radius: float, max_dmg: float) -> void:
	var n: SimBolso = sim.nest
	if n == null or n.destroyed:
		return
	var dist: float = n.distance_to(Vector2(ex, ey))
	if dist >= hit_radius:
		return
	var falloff: float = clampf(1.0 - dist / hit_radius, 0.14, 1.0)
	var dmg: float = max_dmg * falloff * (FRIENDLY_MULT if sim.active_team == 0 else 1.0)
	damage(sim, maxi(1, roundi(dmg)), Vector2(clampf(ex, n.rect().position.x, n.rect().end.x), n.rect().position.y + 30.0))


## The damage a sheltered caterpillar (team 0 inside the nest) takes: half, at least 1.
static func shelter_scale(sim: CombatSim, f: SimFighter, dmg: int) -> int:
	if dmg <= 0 or f.team != 0 or not in_nest(sim, f):
		return dmg
	sim.ftext(f.x, f.y - 52.0, "FT_SHELTERED", Palette.FT_GREEN, 1.2)
	return maxi(1, roundi(dmg * SHELTER_MULT))


## True when the active fighter may repair now: a squad caterpillar on its turn, close to a damaged nest.
static func can_repair(sim: CombatSim) -> bool:
	var f: SimFighter = sim.active_fighter
	return alive(sim) and sim.nest.hp < sim.nest.max_hp and sim.playing and sim.turn_phase == CombatSim.Phase.TURN_PLAY \
		and sim.active_team == 0 and f != null and f.alive and not f.drowning \
		and sim.nest.distance_to(Vector2(f.x, f.y)) <= REPAIR_REACH


## REPAIR: the active caterpillar spends its action to give the nest back REPAIR_HP; it may still walk a little. True when done.
static func repair(sim: CombatSim) -> bool:
	if not can_repair(sim):
		return false
	var n: SimBolso = sim.nest
	var f: SimFighter = sim.active_fighter
	var gained: int = mini(REPAIR_HP, n.max_hp - n.hp)
	n.hp += gained
	sim.play("stone_build")
	SimCombat.smoke(sim, n.pos.x, n.pos.y, 8, "silk")
	SimCombat.spawn_hairs(sim, f.x, f.y - 6.0, 10)
	sim.ftext(n.pos.x, n.rect().position.y - 8.0, "FT_NEST_REPAIRED", Palette.FT_GREEN, 1.8, [gained])
	sim.has_acted_or_moved_this_turn = true
	sim.is_charging = false
	sim.charge_power = 0.0
	sim.turn_phase = CombatSim.Phase.RETREAT
	sim.phase_timer = REPAIR_RETREAT
	sim.nest_changed.emit()
	sim.hud()
	return true


## The CPU squad (CPU-vs-CPU runs) repairs a worn nest when it stands next to it. True when it did.
static func ai_repair(sim: CombatSim) -> bool:
	return alive(sim) and sim.active_team == 0 and float(sim.nest.hp) <= AI_REPAIR_BELOW * sim.nest.max_hp and repair(sim)


# ---------------------------------------------------------------------------
# Cold
# ---------------------------------------------------------------------------

## Start of a squad caterpillar's turn: outside the nest it loses COLD_DAMAGE HP ("FT_COLD"). WARM_SILK cancels the cold (cold_active).
static func on_turn_start(sim: CombatSim, f: SimFighter) -> void:
	if not sim.cold_active or f.team != 0 or not f.alive or f.drowning or in_nest(sim, f):
		return
	sim.cold_tick.emit(f, COLD_DAMAGE)
	SimCombat.damage_fighter(sim, f, COLD_DAMAGE, "FT_COLD")


# ---------------------------------------------------------------------------
# The pole
# ---------------------------------------------------------------------------

## Start of a round (the player's turn): every POLE_EVERY rounds the pole marks a band over a squad caterpillar or the nest.
static func pole_round_start(sim: CombatSim) -> void:
	var lv: LevelDef = sim.level
	if lv == null or not lv.pole or not alive(sim) or sim.round_number % POLE_EVERY != 0:
		return
	var centres: Array[float] = [sim.nest.pos.x]
	for f in sim.fighters:
		if f.team == 0 and f.alive and not f.drowning:
			centres.append(f.x)
	var cx: float = centres[int(sim.rand() * centres.size())]
	sim.pole_band = Rect2(cx - POLE_WIDTH * 0.5, 0.0, POLE_WIDTH, sim.terrain.water_y)
	sim.pole_state = "WARN"
	sim.ftext(cx, 90.0, "FT_POLE_WARN", Palette.FT_ORANGE, 2.6)
	sim.play("tick")
	sim.pole_warn.emit(sim.pole_band)
	sim.hud()


## Start of the enemy turn: a marked band is swept now. True when the pole came down.
static func pole_strike(sim: CombatSim) -> bool:
	if sim.pole_state != "WARN":
		return false
	var band: Rect2 = sim.pole_band
	sim.pole_state = ""
	sim.pole_band = Rect2()
	sweep(sim, band, POLE_DAMAGE, POLE_NEST_DAMAGE, POLE_KNOCKBACK, "DMG_POLE")
	return true


## A pole comes down on a vertical band: every squad caterpillar inside it takes `damage` and is knocked away from the centre of the
## band, the nest takes `nest_damage` when its area touches the band. Used by the level pole and by the boss LINE attack.
static func sweep(sim: CombatSim, band: Rect2, dmg: int, nest_dmg: int, knockback: float, label: String) -> void:
	var cx: float = band.position.x + band.size.x * 0.5
	sim.play("boom", {"scale": 0.9})
	sim.screen_shake.emit(12.0)
	SimCombat.shockwave(sim, cx, sim.terrain.find_surface_y(cx, 40.0), 8.0, band.size.x * 0.8, 0.9)
	sim.pole_sweep.emit(band)
	for f in sim.fighters:
		if f.team == 0 and f.alive and not f.drowning and f.x >= band.position.x and f.x <= band.end.x:
			var dir: float = signf(f.x - cx) if absf(f.x - cx) > 2.0 else float(f.facing)
			SimCombat.damage_fighter(sim, f, dmg, label)
			if f.alive:
				BossAttack.knock(f, dir, knockback, 1.0)
	if nest_dmg > 0 and sim.nest != null and not sim.nest.destroyed:
		var r: Rect2 = sim.nest.rect()
		if r.position.x <= band.end.x and r.end.x >= band.position.x:
			damage(sim, nest_dmg, Vector2(clampf(cx, r.position.x, r.end.x), r.position.y + 30.0))


# ---------------------------------------------------------------------------
# Birds
# ---------------------------------------------------------------------------

## What a bird flies at on its turn: the nest (a fighter-shaped stand-in, `nest.target`) when it is not much farther than the nearest
## caterpillar, else that caterpillar. The choice is made once per turn (kept in the AI plan).
static func flyer_target(sim: CombatSim, af: SimFighter, plan: Dictionary, nearest: SimFighter) -> SimFighter:
	if not alive(sim):
		return nearest
	var n: SimBolso = sim.nest
	if not plan.has("nest_pick"):
		var d_nest: float = Vector2(n.target.x - af.x, n.target.y - af.y).length()
		var d_fighter: float = INF if nearest == null else Vector2(nearest.x - af.x, nearest.y - af.y).length()
		plan["nest_pick"] = d_nest * BIRD_BIAS <= d_fighter
	return n.target if bool(plan["nest_pick"]) else nearest


## A bird pecks the nest with its melee weapon (no ammo, no fighter in reach): the weapon's damage, the swing for the view.
static func peck(sim: CombatSim, af: SimFighter, wpn: WeaponDef) -> void:
	af.bat_swing_timer = 0.48
	af.last_melee_id = wpn.id
	sim.has_acted_or_moved_this_turn = true
	sim.play("worm_voice", {"kind": "ATTACK"})
	damage(sim, roundi(wpn.max_dmg), Vector2(sim.nest.pos.x, sim.nest.rect().position.y + 20.0))

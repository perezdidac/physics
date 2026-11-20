## Goals of the levels of the second pass (docs/story_contracts.md §7): REACH the branch, RESCUE the trapped sister, COLLECT pine nuts,
## ONE_SHOT at a sheltered enemy, the destructible anthill of WAVES, and the explosive barrels and mines a level places. One instance per
## story match in `sim.goals` (null in classic matches); the functions are static, so nothing here runs without a level.
## Placement uses no random numbers: a level plays the same for the same seed.
class_name SimGoals
extends RefCounted

## A caterpillar's feet must be within this height (px) of the goal ground.
const GOAL_HEIGHT: float = 70.0
## Radius of the pine nut pickup (px) and its effect on the picker.
const NUT_R: float = 6.0
const NUT_HEAL: int = 10
## Distance (px) between two barrels of a chain (the blast of one wrecks its neighbour: 55 * (1 - d / 97) >= 20 HP).
const BARREL_GAP: float = 50.0
## Farthest apart (px) two barrels of a row may stand: the blasts of the level's barrels are weaker to match (BARREL_HP).
const MAX_CHAIN_GAP: float = 68.0
const BARREL_HP: float = 14.0
## Closest a mine is placed to a fighter (px, from the fighter centre): beyond its trigger distance (38 px) with room to spare on a slope.
const MINE_GAP: float = 60.0
## The sister freed by a RESCUE level joins under this name.
const SISTER_NAME: String = "Brins"
## Height (px) of the fall-away of a destroyed anthill's crater.
const CRATER_R: float = 38.0

## The rule of the level and the round limit (0 = none).
var kind: String = ""
var limit: int = 0
## REACH / RESCUE: the ground point of the goal (a branch, the cocoon of the sister) and its radius; Vector2.INF when there is none.
var pos: Vector2 = Vector2.INF
var radius: float = 60.0
## RESCUE: the sister was freed.
var freed: bool = false
## WAVES: HP of the anthill (anthill_max 0 = indestructible).
var anthill_hp: int = 0
var anthill_max: int = 0
## COLLECT: nuts gathered, nuts needed, nuts placed, and the ones still lying on the map.
var nut_got: int = 0
var nut_need: int = 0
var nut_total: int = 0
var nuts: Array[SimNut] = []
## ONE_SHOT: shots the squad has left (ammo of its arsenal), counted every frame.
var shots: int = 0
## Why the match ended ("" while it runs): REACHED, RESCUED, ANTHILL_DESTROYED, COLLECTED, TIME_UP, OUT_OF_AMMO, NUTS_LOST.
var reason: String = ""


## The goals of the running story match (null in classic matches).
static func of(sim: CombatSim) -> SimGoals:
	return sim.goals if sim.level != null else null


## True when the enemies of the level stand still (ONE_SHOT): the AI passes their turn.
static func holds_still(sim: CombatSim, f: SimFighter) -> bool:
	return sim.level != null and sim.level.enemy_still and f.team == 1


# ---------------------------------------------------------------- setup

## After the squads and the hiding spots are placed (called by SimStory.place_hiding_spots).
static func setup(sim: CombatSim, level: LevelDef) -> void:
	var g := SimGoals.new()
	sim.goals = g
	g.kind = level.win_rule
	g.limit = level.survive_rounds if level.is_timed_goal() else 0
	g.radius = level.goal_radius if level.win_rule == "REACH" or level.win_rule == "RESCUE" else 60.0
	if level.win_rule == "WAVES":
		g.anthill_hp = level.anthill_hp
		g.anthill_max = level.anthill_hp
	var reg := SimPlacement.new(sim)
	match level.win_rule:
		"REACH", "RESCUE":
			g.pos = _goal_spot(sim, level, reg)
		"COLLECT":
			_place_nuts(sim, level, g, reg)
		"ONE_SHOT":
			if level.enemy_still:
				_shelter_enemies(sim, reg)
	_place_barrels(sim, level, reg)
	_place_mines(sim, level, reg)
	g.shots = shots_left(sim)


static func _player_fighters(sim: CombatSim) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team == 0 and f.alive and not f.drowning:
			out.append(f)
	return out


## The walking map placements use (the strict one on a level whose squads were placed on its main ground, else the permissive one).
static func _nav(sim: CombatSim) -> SimNav:
	return sim.placement_nav if sim.placement_nav != null else sim.nav


## The water level (y) the level will have at its last round: goals and nuts are placed above it (the tide of a level with a round limit
## keeps rising, `rounds` more than a level without one: 4).
static func final_water_y(sim: CombatSim, level: LevelDef) -> float:
	if not level.tide:
		return sim.terrain.water_y
	var last: int = level.survive_rounds if level.survive_rounds > 0 else level.tide_round + 4
	var rises: int = maxi(0, last - level.tide_round + 1)
	return maxf(460.0, sim.terrain.water_y - SimTurns.TIDE_STEP * float(rises))


## The walkable ground the squad can reach, nearest to the wanted x, preferring high ground (a branch) and keeping away from the enemies.
static func _goal_spot(sim: CombatSim, level: LevelDef, reg: SimPlacement) -> Vector2:
	var span: Vector2 = SimStory.spawn_span(sim)
	var want_x: float = level.goal_x if level.goal_x > 0.0 else span.x + (span.y - span.x) * level.goal_frac
	var egg_pos := Vector2(sim.fighters[0].x, sim.fighters[0].y)
	var squad_x: float = SimStory._squad_x(sim, 0)
	var best := Vector2.INF
	var best_score: float = INF
	var wy: float = final_water_y(sim, level)
	for relaxed in [false, true]:
		for c in _nav(sim).reachable(egg_pos, false):
			var near_enemy: bool = false
			for f in sim.fighters:
				near_enemy = near_enemy or (f.team == 1 and absf(f.x - c.x) < (110.0 if not relaxed else 50.0))
			if c.y >= wy - 90.0 or absf(c.x - squad_x) < (span.y - span.x) * (0.4 if not relaxed else 0.2) or near_enemy:
				continue
			if not reg.is_free("FIGHTER", c.x, c.y):
				continue
			var score: float = absf(c.x - want_x) + 0.35 * c.y
			if score < best_score:
				best_score = score
				best = Vector2(c.x, c.y)
		if best != Vector2.INF:
			return best
	return SimSetup.find_spawn_spot(sim, want_x, 400.0, false)


## COLLECT: the nuts lie on ground the squad can walk to, one per slice of the way between the squad and the far edge, well above the water.
static func _place_nuts(sim: CombatSim, level: LevelDef, g: SimGoals, reg: SimPlacement) -> void:
	var span: Vector2 = SimStory.spawn_span(sim)
	var squad_x: float = SimStory._squad_x(sim, 0)
	var egg_pos := Vector2(sim.fighters[0].x, sim.fighters[0].y)
	var reach: Array[Vector3] = _nav(sim).reachable(egg_pos, false)
	var wy: float = final_water_y(sim, level)
	var x0: float = squad_x + 140.0
	var x1: float = span.y - 40.0
	var n: int = level.collect_count
	var taken: Array[Vector2] = []
	for i in n:
		var want: float = x0 + (x1 - x0) * (float(i) + 0.5) / float(n)
		var best := Vector2.INF
		for relaxed in [false, true]:
			for c in reach:
				if c.y >= wy - (170.0 if not relaxed else 110.0) or c.x < x0 - 60.0:
					continue
				var apart: bool = true
				for t in taken:
					apart = apart and t.distance_to(Vector2(c.x, c.y)) >= (110.0 if not relaxed else 60.0)
				var spaced: bool = true
				for f in sim.fighters:
					spaced = spaced and (f.team == 0 or absf(f.x - c.x) > 40.0)
				if apart and spaced and reg.is_free("FIGHTER", c.x, c.y, 0.5) and (best == Vector2.INF or absf(c.x - want) < absf(best.x - want)):
					best = Vector2(c.x, c.y)
			if best != Vector2.INF:
				break
		if best == Vector2.INF:
			# no walkable ground left in this slice: any dry surface there (the level must always have its nuts)
			best = SimSetup.find_spawn_spot(sim, want, 200.0, false)
			if best.y >= wy - 60.0:
				continue
		taken.append(best)
		reg.add("FIGHTER", best.x, best.y, 0.5)
		var pn := SimNut.new()
		pn.x = best.x
		pn.y = best.y - NUT_R - 1.0
		pn.r = NUT_R
		pn.grounded = true
		pn.life = 1.0e9
		sim.pine_nuts.append(pn)
		g.nuts.append(pn)
	g.nut_total = g.nuts.size()
	g.nut_need = mini(level.collect_need, g.nut_total)


## ONE_SHOT: every enemy goes where the squad has no straight shot at it but can still hit it with a lob: ground the ants can walk to (the strict
## map of the placement) with some rock between it and the squad (MIN_COVER..MAX_COVER samples, not a sealed-in pocket) and a free arc.
const MIN_COVER: int = 4
const MAX_COVER: int = 14
## Candidates whose arc is tried per enemy (best first).
const ARC_TRIES: int = 14


static func _shelter_enemies(sim: CombatSim, reg: SimPlacement) -> void:
	var span: Vector2 = SimStory.spawn_span(sim)
	var usable: float = span.y - span.x
	var squad_x: float = SimStory._squad_x(sim, 0)
	var squad_y: float = sim.fighters[0].y - 16.0
	var egg_pos := Vector2(sim.fighters[0].x, sim.fighters[0].y)
	var cands: Array[Vector3] = _nav(sim).reachable(egg_pos, true, true)
	var used: Array[float] = []
	for f in sim.fighters:
		if f.team != 1 or f.flying:
			continue
		var scored: Array[Vector3] = []  # x, y, score (higher is better)
		for c in cands:
			var dx: float = c.x - squad_x
			if dx < usable * 0.38 or dx > usable * 0.8 or c.y >= sim.terrain.water_y - 60.0:
				continue
			var apart: bool = true
			for ux in used:
				apart = apart and absf(ux - c.x) >= 90.0
			if not apart or not reg.is_free("FIGHTER", c.x, c.y, f.r / 12.0):
				continue
			var cover: int = _cover(sim, Vector2(squad_x, squad_y), Vector2(c.x, c.y - 14.0))
			if cover < MIN_COVER or cover > MAX_COVER:
				continue
			scored.append(Vector3(c.x, c.y, float(cover) - absf(dx - usable * 0.6) * 0.02))
		scored.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z)
		var best := Vector2.INF
		for k in mini(ARC_TRIES, scored.size()):
			if _arc_hits(sim, Vector2(squad_x, squad_y), Vector2(scored[k].x, scored[k].y - 14.0)):
				best = Vector2(scored[k].x, scored[k].y)
				break
		if best == Vector2.INF and not scored.is_empty():
			best = Vector2(scored[0].x, scored[0].y)  # no arc found by the coarse search: the best cover still plays
		if best == Vector2.INF:
			continue
		used.append(best.x)
		reg.add("FIGHTER", best.x, best.y, f.r / 12.0)
		_relocate(sim, f, best)


## True when a lob (the estimator of the CPU, no wind) from `from` lands within 36 px of `to`.
static func _arc_hits(sim: CombatSim, from: Vector2, to: Vector2) -> bool:
	var sgn: float = 1.0 if to.x >= from.x else -1.0
	for deg in range(20, 86, 5):
		var ang: float = deg_to_rad(float(deg))
		var angle: float = -ang if sgn > 0.0 else -PI + ang
		for power in [0.45, 0.6, 0.75, 0.9, 1.0]:
			if AiBrain.simulate_arc(sim, from.x, from.y, angle, power, 0.0).distance_to(to) <= 36.0:
				return true
	return false


## Samples of the straight line a -> b that are inside rock (capped), the "cover" an enemy has from a.
static func _cover(sim: CombatSim, a: Vector2, b: Vector2) -> int:
	var n: int = int(a.distance_to(b) / 8.0)
	var hits: int = 0
	for i in range(1, n):
		var p: Vector2 = a.lerp(b, float(i) / float(n))
		if sim.terrain.is_solid(p.x, p.y):
			hits += 1
	return mini(hits, 40)


static func _relocate(sim: CombatSim, f: SimFighter, spot: Vector2) -> void:
	f.x = spot.x
	f.y = minf(sim.terrain.water_y - 30.0, spot.y - f.r - 2.0)
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	f.vx = 0.0
	f.vy = 0.0
	for s in f.segs.size():
		f.segs[s] = Vector2(f.x - f.facing * (s + 1) * 5.2, f.y + 4.0)


## Explosive barrels: round the anthill (WAVES), or in short rows beside the first two enemies, so one hit sets the row off (ELIMINATE).
static func _place_barrels(sim: CombatSim, level: LevelDef, reg: SimPlacement) -> void:
	if level.barrels <= 0:
		return
	var wy: float = sim.terrain.water_y
	if level.win_rule == "WAVES" and sim.anthill_pos != Vector2.INF:
		var ground_y: float = sim.anthill_pos.y + TerrainSim.ANTHILL_H
		for k in level.barrels:
			var side: float = 1.0 if k % 2 == 0 else -1.0
			var want_x: float = sim.anthill_pos.x + side * (74.0 + BARREL_GAP * float(k >> 1))
			var spot: Vector2 = reg.find("BARREL", want_x, ground_y, wy - 22.0, 1.0, 0.0, 30.0)
			if spot != Vector2.INF:
				_add_barrel(sim, reg, spot)
		return
	var foes: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team == 1 and not f.flying:
			foes.append(f)
	var squad_x: float = SimStory._squad_x(sim, 0)
	foes.sort_custom(func(a: SimFighter, b: SimFighter) -> bool: return absf(a.x - squad_x) < absf(b.x - squad_x))
	if foes.is_empty():
		return
	var rows: int = 2
	var per: int = ceili(float(level.barrels) / float(rows))
	var left: int = level.barrels
	for f in foes:
		if rows == 0 or left <= 0:
			break
		var dir: float = signf(squad_x - f.x)
		var prev := Vector2(f.x, f.y + f.r)
		var placed: int = 0
		while placed < mini(per, left):
			var spot: Vector2 = _next_barrel(reg, prev, dir, wy)
			if spot == Vector2.INF and placed == 0:
				dir = -dir  # the ground is a cliff on that side
				spot = _next_barrel(reg, prev, dir, wy)
			if spot == Vector2.INF:
				break
			_add_barrel(sim, reg, spot)
			prev = spot
			placed += 1
		if placed > 0:
			rows -= 1
			left -= placed


## The free ground 34-68 px (so that a blast of one wrecks the next) from `prev`, on the side of `dir`.
static func _next_barrel(reg: SimPlacement, prev: Vector2, dir: float, wy: float) -> Vector2:
	for dx in [48.0, 44.0, 52.0, 40.0, 56.0, 36.0, 60.0, 64.0]:
		var spot: Vector2 = reg.find("BARREL", prev.x + dir * dx, prev.y, wy - 22.0, 1.0, 0.0, 0.0)
		if spot != Vector2.INF and spot.distance_to(prev) >= 34.0 and spot.distance_to(prev) <= MAX_CHAIN_GAP:
			return spot
	return Vector2.INF


static func _add_barrel(sim: CombatSim, reg: SimPlacement, spot: Vector2) -> void:
	reg.add("BARREL", spot.x, spot.y)
	var br := SimBarrel.new()
	br.x = spot.x
	br.y = spot.y - 14.0
	br.hp = BARREL_HP
	sim.barrels.append(br)


## Proximity mines on the way between the squads.
static func _place_mines(sim: CombatSim, level: LevelDef, reg: SimPlacement) -> void:
	if level.mines <= 0:
		return
	var squad_x: float = SimStory._squad_x(sim, 0)
	var foe_x: float = SimStory._squad_x(sim, 1)
	var ref_y: float = sim.fighters[0].y + sim.fighters[0].r
	for i in level.mines:
		var x: float = squad_x + (foe_x - squad_x) * (0.18 + 0.64 * (float(i) + 0.5) / float(level.mines))
		var spot: Vector2 = reg.find("MINE", x, ref_y, sim.terrain.water_y - 22.0, 1.0, MINE_GAP, 140.0)
		if spot == Vector2.INF:
			continue
		reg.add("MINE", spot.x, spot.y)
		var mi := SimMine.new()
		mi.x = spot.x
		mi.y = spot.y - 5.0
		sim.mines.append(mi)


# ---------------------------------------------------------------- rules

## Ammo (shots) of the player's team across its arsenal; unlimited weapons count as 99.
static func shots_left(sim: CombatSim) -> int:
	var n: int = 0
	for id in sim.arsenals[0]:
		var a: float = sim.ammo_f(0, id)
		n += 99 if a == INF else int(a)
	return n


## An explosion at (ex, ey): hurts the anthill of a WAVES level that has HP.
static func on_explosion(sim: CombatSim, ex: float, ey: float, hit_radius: float, max_dmg: float) -> void:
	var g: SimGoals = of(sim)
	if g == null or g.anthill_max <= 0 or g.anthill_hp <= 0 or sim.anthill_pos == Vector2.INF or sim.turn_phase == CombatSim.Phase.GAME_OVER:
		return
	var centre: Vector2 = sim.anthill_pos + Vector2(0.0, TerrainSim.ANTHILL_H * 0.5)
	var reach: float = hit_radius + 20.0
	var d: float = centre.distance_to(Vector2(ex, ey))
	if d >= reach:
		return
	var dmg: int = maxi(1, ceili(max_dmg * clampf(1.0 - d / reach, 0.14, 1.0)))
	damage_anthill(sim, dmg)


## Takes `dmg` HP off the anthill; at 0 the mound crumbles and the level is won.
static func damage_anthill(sim: CombatSim, dmg: int) -> void:
	var g: SimGoals = of(sim)
	if g == null or g.anthill_max <= 0 or g.anthill_hp <= 0:
		return
	g.anthill_hp = maxi(0, g.anthill_hp - dmg)
	var top: Vector2 = sim.anthill_pos
	sim.ftext(top.x, top.y - 30.0, "FT_ANTHILL_HIT", Palette.FT_ORANGE, 1.4, [dmg])
	sim.hud()
	if g.anthill_hp > 0:
		return
	sim.terrain.carve_crater(top.x, top.y + 14.0, CRATER_R)
	SimCombat.smoke(sim, top.x, top.y, 14, "dark")
	SimCombat.sparks(sim, top.x, top.y, 18)
	sim.play("boom", {"scale": 1.0})
	_finish(sim, 0, "ANTHILL_DESTROYED", "FT_ANTHILL_DOWN", top)


## Ends the match: `winner` 0 (the squad) or 1, with the reason of the results screen and a floating text at `at`.
static func _finish(sim: CombatSim, winner: int, why: String, text_key: String, at: Vector2) -> void:
	var g: SimGoals = of(sim)
	if g == null or sim.turn_phase == CombatSim.Phase.GAME_OVER:
		return
	if winner == 0 and sim.team_alive_count(0) == 0:
		# the last caterpillar fell with the goal (its own blast, a barrel chain): nobody is left to win
		winner = 1
		why = "LOST"
		text_key = ""
	g.reason = why
	sim.winner = winner
	sim.turn_phase = CombatSim.Phase.GAME_OVER
	if text_key != "":
		sim.ftext(at.x, at.y - 46.0, text_key, Palette.FT_GOLD_SOFT if winner == 0 else Palette.FT_RED, 2.4)
	if winner == 0:
		sim.play("victory")
	sim.game_over.emit(winner, SimTurns.make_game_stats(sim))
	sim.hud()


## Start of a round of a timed rule (called by SimStory.begin_round): the rounds left count down and the last one ends the level lost.
## True when the level was lost.
static func begin_round(sim: CombatSim) -> bool:
	var g: SimGoals = of(sim)
	if g == null or g.limit <= 0:
		return false
	if sim.round_number > g.limit:
		sim.rounds_left = 0
		var at: Vector2 = Vector2(sim.fighters[0].x, sim.fighters[0].y)
		for f in _player_fighters(sim):
			at = Vector2(f.x, f.y)
			break
		_finish(sim, 1, "TIME_UP", "FT_TIME_UP", at)
		return true
	sim.rounds_left = g.limit - sim.round_number + 1
	return false


## A pine nut of the COLLECT level was picked up by a squad caterpillar.
static func on_nut(sim: CombatSim, pn: SimNut, f: SimFighter) -> void:
	var g: SimGoals = of(sim)
	if g == null:
		return
	g.nuts.erase(pn)
	g.nut_got += 1
	f.hp = mini(f.max_hp, f.hp + NUT_HEAL)
	sim.play("crate_pickup")
	sim.ftext(f.x, f.y - 30.0, "FT_NUT_COLLECTED", Palette.FT_GOLD_SOFT, 1.7, [g.nut_got, g.nut_need])
	sim.hud()


## True when `pn` belongs to the goal of the level.
static func is_goal_nut(sim: CombatSim, pn: SimNut) -> bool:
	var g: SimGoals = of(sim)
	return g != null and g.nuts.has(pn)


## Every frame after the physics: the goal checks of the rule.
static func update(sim: CombatSim, dt: float) -> void:
	var g: SimGoals = of(sim)
	if g == null or sim.turn_phase == CombatSim.Phase.GAME_OVER:
		return
	match g.kind:
		"REACH", "RESCUE":
			_check_spot(sim, g)
		"COLLECT":
			_check_nuts(sim, g)
		"ONE_SHOT":
			_check_ammo(sim, g, dt)


## A squad caterpillar standing on the goal ground.
static func _check_spot(sim: CombatSim, g: SimGoals) -> void:
	if g.pos == Vector2.INF:
		return
	# the ground under the goal may have been dug away (craters): the goal follows the surface that is there now
	var sy: float = sim.terrain.find_surface_y(g.pos.x, maxf(0.0, g.pos.y - 60.0))
	if sy < sim.terrain.water_y - 22.0:
		g.pos.y = sy
	for f in _player_fighters(sim):
		if f.grounded and absf(f.x - g.pos.x) <= g.radius and absf(f.y + f.r - g.pos.y) <= GOAL_HEIGHT and not f.is_hazard():
			if g.kind == "REACH":
				_finish(sim, 0, "REACHED", "FT_BRANCH_REACHED", Vector2(f.x, f.y))
			else:
				_free_sister(sim, g)
			return


## RESCUE: the sister joins the squad where she was trapped, and the level is won.
static func _free_sister(sim: CombatSim, g: SimGoals) -> void:
	g.freed = true
	var n0: int = 0
	for f in sim.fighters:
		n0 += 1 if f.team == 0 else 0
	var spot := Vector2(g.pos.x, g.pos.y)
	var sister: SimFighter = SimStory._make_unit(sim, 0, n0, SISTER_NAME, spot, sim.level.player_unit, 1)
	sim.fighters.append(sister)
	sim.ftext(spot.x, spot.y - 36.0, "FT_SISTER_FREED", Palette.FT_GREEN, 2.2, [SISTER_NAME])
	_finish(sim, 0, "RESCUED", "FT_SISTER_SAFE", spot)


## COLLECT: enough nuts won; too few nuts left to ever reach the count lost.
static func _check_nuts(sim: CombatSim, g: SimGoals) -> void:
	var i: int = g.nuts.size() - 1
	while i >= 0:
		if not sim.pine_nuts.has(g.nuts[i]):
			g.nuts.remove_at(i)
		i -= 1
	if g.nut_got >= g.nut_need and g.nut_need > 0:
		var at := Vector2(sim.fighters[0].x, sim.fighters[0].y)
		_finish(sim, 0, "COLLECTED", "FT_NUTS_DONE", at)
	elif g.nut_got + g.nuts.size() < g.nut_need:
		var at2 := Vector2(sim.fighters[0].x, sim.fighters[0].y)
		_finish(sim, 1, "NUTS_LOST", "FT_NUTS_LOST", at2)


## ONE_SHOT: keeps the shot counter of the HUD current.
static func _check_ammo(sim: CombatSim, g: SimGoals, _dt: float) -> void:
	var left: int = shots_left(sim)
	if left != g.shots:
		g.shots = left
		sim.hud()


## ONE_SHOT, at the start of every turn (SimTurns.start_next_turn, after the elimination check): the squad is out of ammo and the enemy still
## stands, so the level is lost. Everything of the last shot has settled by then (projectiles, falling units, armed mines), and a shot that
## would still kill the enemy was resolved first.
static func on_turn_start(sim: CombatSim) -> bool:
	var g: SimGoals = of(sim)
	if g == null or g.kind != "ONE_SHOT" or sim.turn_phase == CombatSim.Phase.GAME_OVER:
		return false
	if shots_left(sim) > 0 or sim.team_alive_count(1, true) == 0:
		return false
	var at := Vector2(sim.fighters[0].x, sim.fighters[0].y)
	_finish(sim, 1, "OUT_OF_AMMO", "FT_OUT_OF_AMMO", at)
	return true

## Story-mode rules on top of the classic match: level setup, arsenals, hiding spots, hiding and sniffing,
## the SURVIVE_ROUNDS goal and the extra game-over stats. Every function is a no-op for classic matches (level == null).
class_name SimStory
extends RefCounted

## An enemy that ends its turn this close to a hidden fighter smells it out.
const SNIFF_RADIUS: float = 40.0
## Walking distance (px) between the ant spawns and the eggs (an ant walks up to ~1100 px per turn and plays once every few rounds).
const ANT_PATH_MIN: float = 800.0
const ANT_PATH_MAX: float = 1300.0
## Shortest walk (px) between the two squads in a small arena.
const MIN_ANT_PATH: float = 420.0
## Share of the arena width the main walkable ground must span for the squads to be placed with the strict walking map (and at least
## MIN_MAIN_SPAN px, so a tiny arena still needs a real stretch of ground).
const MIN_MAIN_SHARE: float = 0.6
const MIN_MAIN_SPAN: float = 500.0
## Longest walk (px) from the eggs to a spot near them / to any spot (eggs crawl ~680 px per turn).
const NEAR_SPOT_PATH: float = 520.0
const FAR_SPOT_PATH: float = 1500.0


## Seconds of one enemy sub-turn in a swarm turn.
const SWARM_TURN_TIME: float = 6.0
## Distance (px) from the anthill centre to the first ant of a wave.
const WAVE_GAP: float = 58.0


## True when the enemy team of the level acts as a swarm (every unit in its own sub-turn each round): ants and birds.
static func is_swarm(sim: CombatSim) -> bool:
	if sim.level == null:
		return false
	if sim.level.boss != null:
		return true
	var units: Array[UnitDef] = sim.level.enemy_units.duplicate()
	units.append(sim.level.enemy_unit)
	for u in units:
		if u != null and u.ai != "CATERPILLAR":
			return true
	return false


## True for the rules that count rounds (SURVIVE_ROUNDS, WAVES and DEFEND_NEST): `rounds_left` is used and surviving the last round wins.
static func counts_rounds(level: LevelDef) -> bool:
	return level.win_rule == "SURVIVE_ROUNDS" or level.win_rule == "WAVES" or level.win_rule == "DEFEND_NEST"


## True while the enemy swarm still has units waiting to act (the turn stays with team 1).
static func swarm_continues(sim: CombatSim) -> bool:
	if not is_swarm(sim) or sim.active_team != 1:
		return false
	return _next_swarm_id(sim) != -1


static func _next_swarm_id(sim: CombatSim) -> int:
	for id in sim.swarm_queue:
		for f in sim.fighters:
			if f.id == id and f.alive and not f.drowning:
				return id
	return -1


## Takes the next living unit of the swarm queue (null when it is not a swarm turn).
static func pop_swarm(sim: CombatSim) -> SimFighter:
	if not is_swarm(sim) or sim.active_team != 1:
		return null
	var id: int = _next_swarm_id(sim)
	if id == -1:
		return null
	while sim.swarm_queue[0] != id:
		sim.swarm_queue.pop_front()
	sim.swarm_queue.pop_front()
	for f in sim.fighters:
		if f.id == id:
			return f
	return null


## Margin (px) of the squad spawns from the edges of the whole terrain, and the span they cover there.
const SPAWN_MARGIN: float = 380.0
const FULL_USABLE: float = SimTables.TERRAIN_W - 2.0 * SPAWN_MARGIN


## The span (x from, x to) squads and goals are placed in: the playable span minus the spawn margin (shrunk in a clipped arena).
static func spawn_span(sim: CombatSim) -> Vector2:
	var m: float = sim.terrain.edge_margin(SPAWN_MARGIN)
	return Vector2(sim.terrain.arena_x0 + m, sim.terrain.arena_x1 - m)


## True when the strict main ground spans enough of the arena for squads to stand on it.
static func strict_main_wide_enough(sim: CombatSim, main: Dictionary) -> bool:
	var arena_w: float = sim.terrain.arena_x1 - sim.terrain.arena_x0
	return SimNav.node_span(main) >= maxf(MIN_MAIN_SPAN, MIN_MAIN_SHARE * arena_w)


## Replaces the classic squads: team 0 = player units on the left third, team 1 = enemy units on the right half.
static func spawn_squads(sim: CombatSim, level: LevelDef) -> void:
	var span: Vector2 = spawn_span(sim)
	var names1: Array = SimSetup._shuffled(sim, Array(SimTables.NAMES_POOL_1))
	var n0: int = maxi(1, level.player_names.size())
	var base_x: float = span.x + (span.y - span.x) * (0.02 + sim.rand() * 0.10)
	var ref_y: float = NAN
	var reg := SimPlacement.new(sim)
	var radius: float = level.player_unit.radius if level.player_unit != null else 12.0
	var convoy: bool = level.is_convoy()
	# Squads are placed with the strict walking map when its main ground is wide enough: the eggs stand on that ground (not in a cave or pocket
	# that rock or cliffs close in, they could not get out) and the ants start where they really can walk to them. On a map shattered by cliffs
	# the permissive `sim.nav` (which links through rock) decides as before and the ants dig their way to the eggs.
	var main: Dictionary = {}
	sim.placement_nav = sim.nav
	if not convoy:
		main = sim.walk_nav().main_ground(sim.terrain.arena_x0, sim.terrain.arena_x1)
		if strict_main_wide_enough(sim, main):
			sim.placement_nav = sim.walk_nav()
		else:
			main = {}
	var file: Array[Vector2] = []
	if convoy:
		file = _convoy_file(sim, base_x + (n0 - 1) * SimConvoy.SPACING, n0, radius, reg)
	for i in n0:
		var spot: Vector2
		if convoy:
			spot = file[i]
		else:
			var pref: float = base_x + i * 64.0 + sim.rand() * 20.0
			spot = SimSetup.find_spawn_spot(sim, pref, 140.0, false) if is_nan(ref_y) else _spot_near(sim, pref, ref_y)
			spot = SimSetup.place_fighter(sim, reg, _to_main(sim, main, spot, reg, radius), radius, 120.0)
		ref_y = spot.y
		var nm: String = level.player_names[i] if i < level.player_names.size() else "Ou %d" % (i + 1)
		sim.fighters.append(_make_unit(sim, 0, i, nm, spot, level.player_unit, 1))
	var egg_pos := Vector2(sim.fighters[0].x, sim.fighters[0].y)
	var taken: Array[float] = []
	var roster: Array[UnitDef] = level.enemy_roster()
	for j in roster.size():
		var unit: UnitDef = roster[j]
		if unit.ai == "CHARGER":
			var boar: SimFighter = _make_unit(sim, 1, j, String(names1[j % names1.size()]).strip_edges(), AiCharger.WAIT_POS, unit, 1)
			AiCharger.park(boar, "wait")
			sim.fighters.append(boar)
			continue
		var spot: Vector2 = _ant_spot(sim, roster.size(), j, egg_pos, taken, reg)
		if unit.flies:
			taken.append(spot.x)
			var bird: SimFighter = _make_unit(sim, 1, j, String(names1[j % names1.size()]).strip_edges(), spot, unit, -1)
			_lift(sim, bird, spot)
			sim.fighters.append(bird)
			continue
		spot = SimSetup.place_fighter(sim, reg, spot, unit.radius, 260.0)
		taken.append(spot.x)
		sim.fighters.append(_make_unit(sim, 1, j, String(names1[j % names1.size()]).strip_edges(), spot, unit, -1))


## Height (px) of a bird's perch above the ground it was placed over.
const PERCH_HEIGHT: float = 150.0


## Puts a bird in the air over its ground spot: that point is its perch.
static func _lift(sim: CombatSim, f: SimFighter, ground: Vector2) -> void:
	var y: float = maxf(70.0, ground.y - PERCH_HEIGHT)
	while sim.terrain.is_solid(f.x, y) and y > 40.0:
		y -= 4.0
	f.y = y
	f.jump_start_y = y
	f.peak_air_y = y
	f.flying = true
	f.grounded = true
	f.perch = Vector2(f.x, y)
	for s in f.segs.size():
		f.segs[s] = Vector2(f.x - f.facing * (s + 1) * 5.2, f.y + 4.0)


## An ant spot on the right half with a walking path to the eggs, about two turns of walking away.
static func _ant_spot(sim: CombatSim, total: int, j: int, egg_pos: Vector2, taken: Array[float], reg: SimPlacement) -> Vector2:
	var span: Vector2 = spawn_span(sim)
	var usable: float = span.y - span.x
	# The walking distances were tuned for the whole terrain: a smaller arena shrinks them (never below MIN_ANT_PATH).
	var scale: float = minf(1.0, usable / FULL_USABLE)
	var path_min: float = minf(ANT_PATH_MIN, maxf(MIN_ANT_PATH, ANT_PATH_MIN * scale))
	var path_max: float = maxf(path_min + 200.0, ANT_PATH_MAX * scale)
	var x_min: float = span.x + (1450.0 - SPAWN_MARGIN) / FULL_USABLE * usable
	var cands: Array[Vector3] = []
	var farthest := Vector3.INF
	for c in sim.placement_nav.reachable(egg_pos, true, true):
		var apart: bool = true
		for tx in taken:
			apart = apart and absf(tx - c.x) >= 90.0
		if not apart or not reg.is_free("FIGHTER", c.x, c.y):
			continue
		if c.x >= x_min and c.z >= path_min and c.z <= path_max:
			cands.append(c)
		if farthest == Vector3.INF or c.z > farthest.z:
			farthest = c
	# The real walkable ground around the eggs may be smaller than the tuned distances (cliffs close it in): the ants then start on its far end.
	if cands.is_empty() and farthest != Vector3.INF and farthest.z >= MIN_ANT_PATH:
		return Vector2(farthest.x, farthest.y)
	if cands.is_empty():
		return SimSetup.find_spawn_spot(sim, span.x + usable * (0.55 + 0.40 * (j + 0.5) / total), 200.0, j % 2 == 0)
	var pick: Vector3 = cands[int(sim.rand() * cands.size())]
	return Vector2(pick.x, pick.y)


## `spot` when it is on the main ground (or there is none), else the closest free surface that is (sideways first, then by height).
static func _to_main(sim: CombatSim, main: Dictionary, spot: Vector2, reg: SimPlacement, radius: float) -> Vector2:
	var wn: SimNav = sim.walk_nav()
	if main.is_empty() or main.has(wn.node_at(spot.x, spot.y)):
		return spot
	for k in range(0, 900, 8):
		var best := Vector2.INF
		for d in ([0] if k == 0 else [-1, 1]):
			var col: int = clampi(roundi((sim.terrain.clamp_x(spot.x + d * k, 240.0) - SimNav.X_MIN) / SimNav.STEP), 0, wn.tiers.size() - 1)
			for t in wn.tiers[col].size():
				var sy: float = wn.tiers[col][t]
				var x: float = SimNav.X_MIN + col * SimNav.STEP
				if main.has(col * 8 + t) and (best == Vector2.INF or absf(sy - spot.y) < absf(best.y - spot.y)) and reg.is_free("FIGHTER", x, sy, radius / 12.0):
					best = Vector2(x, sy)
		if best != Vector2.INF:
			return best
	return spot


## The spots of a procession in single file: the leader near `lead_x` and each follower SimConvoy.SPACING px behind the previous one, on
## gentle ground the whole way (no step above FILE_STEP px between neighbours), clear of trees and above the water. The ground closest to
## lead_x that has room for the whole file is used (falls back to a flat line on the first ground it finds when none has).
const FILE_STEP: float = 16.0


static func _convoy_file(sim: CombatSim, lead_x: float, n: int, radius: float, reg: SimPlacement) -> Array[Vector2]:
	var r: float = 0.0
	while r <= 700.0:
		for d in ([0] if r == 0.0 else [-1, 1]):
			var em: float = sim.terrain.edge_margin(240.0)
			var x: float = clampf(lead_x + d * r, sim.terrain.arena_x0 + em + (n - 1) * SimConvoy.SPACING, sim.terrain.arena_x1 - em)
			for tier in sim.terrain.find_all_walkable_surfaces_at_x(x):
				var file: Array[Vector2] = _file_from(sim, Vector2(x, float(tier)), n, radius, reg)
				if not file.is_empty():
					for p in file:
						reg.add("FIGHTER", p.x, p.y, radius / 12.0)
					return file
		r += 6.0
	var spot: Vector2 = SimSetup.place_fighter(sim, reg, SimSetup.find_spawn_spot(sim, lead_x, 400.0, false), radius, 120.0)
	var out: Array[Vector2] = []
	for i in n:
		out.append(Vector2(spot.x - i * SimConvoy.SPACING, spot.y))
	return out


## The file of `n` spots whose leader stands at `head`, or an empty array when the ground does not allow it.
static func _file_from(sim: CombatSim, head: Vector2, n: int, radius: float, reg: SimPlacement) -> Array[Vector2]:
	var out: Array[Vector2] = [head]
	for i in range(1, n):
		var x: float = head.x - i * SimConvoy.SPACING
		var prev_y: float = out[i - 1].y
		var best: float = NAN
		for tier in sim.terrain.find_all_walkable_surfaces_at_x(x):
			if absf(float(tier) - prev_y) <= FILE_STEP and (is_nan(best) or absf(float(tier) - prev_y) < absf(best - prev_y)):
				best = float(tier)
		if is_nan(best):
			return []
		out.append(Vector2(x, best))
	for p in out:
		if p.y > sim.terrain.water_y - 50.0 or not reg.is_free("FIGHTER", p.x, p.y, radius / 12.0):
			return []
		for side in [-6.0, 6.0]:
			if absf(sim.terrain.find_surface_y(p.x + side, p.y - 30.0) - p.y) > FILE_STEP * 0.75:
				return []
	return out


## A spot at x (or the closest column with a surface) whose tier is the nearest to ref_y.
static func _spot_near(sim: CombatSim, x: float, ref_y: float) -> Vector2:
	var r: float = 0.0
	while r <= 140.0:
		for d in ([0] if r == 0.0 else [-1, 1]):
			var tx: float = sim.terrain.clamp_x(x + d * r, 240.0)
			var best: float = NAN
			for sy in sim.terrain.find_all_walkable_surfaces_at_x(tx):
				if absf(float(sy) - ref_y) <= 40.0 and (is_nan(best) or absf(float(sy) - ref_y) < absf(best - ref_y)):
					best = float(sy)
			if not is_nan(best):
				return Vector2(tx, best)
		r += 12.0
	return SimSetup.find_spawn_spot(sim, x, 200.0, false)


static func _make_unit(sim: CombatSim, team: int, idx: int, nm: String, spot: Vector2, unit: UnitDef, facing: int) -> SimFighter:
	var f: SimFighter = SimSetup.create_fighter(sim, team, idx, nm, spot.x, facing, spot.y)
	f.unit = unit
	f.kind = unit.id
	f.r = unit.radius
	f.hp = unit.max_hp
	f.max_hp = unit.max_hp
	f.y = minf(sim.terrain.water_y - 30.0, spot.y - unit.radius - 2.0)
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	for s in f.segs.size():
		f.segs[s] = Vector2(f.x - facing * (s + 1) * 5.2, f.y + 4.0)
	return f


## Level arsenals: only listed weapons have ammo (-1 = unlimited). `extra` (weapon id -> ammo) is added to the player's arsenal.
static func apply_arsenals(sim: CombatSim, level: LevelDef, extra: Dictionary = {}) -> void:
	for t in 2:
		var listed: Dictionary = (level.player_arsenal if t == 0 else level.enemy_arsenal).duplicate()
		if t == 0:
			for id in extra:
				var have: int = int(listed.get(id, 0))
				var add: int = int(extra[id])
				listed[id] = -1 if (have < 0 or add < 0) else have + add
		sim.arsenals[t] = listed
		for w in sim.weapons:
			var amount: int = int(listed.get(w.id, 0))
			sim.team_ammo[t][w.id] = INF if amount < 0 else float(amount)


## WAVES: stamps the anthill on flat ground near anthill_x and sets sim.anthill_pos (top of the mound). Runs before the walking map is built.
static func build_anthill(sim: CombatSim, level: LevelDef) -> void:
	if level.win_rule != "WAVES":
		return
	var stamps: Array[Rect2] = SimPlacement.stamp_rects(sim.terrain)
	var best := Vector2.INF
	var r: float = 0.0
	while r <= 500.0 and best == Vector2.INF:
		for d in ([0] if r == 0.0 else [-1, 1]):
			var x: float = sim.terrain.clamp_x(level.anthill_x + d * r, 300.0)
			for sy in sim.terrain.find_all_walkable_surfaces_at_x(x):
				var flat: bool = absf(sim.terrain.find_surface_y(x - 44.0, sy - 40.0) - sy) <= 14.0 and absf(sim.terrain.find_surface_y(x + 44.0, sy - 40.0) - sy) <= 14.0
				var rect := Rect2(x - 44.0, sy - 34.0, 88.0, 40.0)
				if best == Vector2.INF and flat and sy < sim.terrain.water_y - 50.0 and not SimPlacement.hits_stamp(stamps, rect):
					best = Vector2(x, sy)
		r += 8.0
	if best == Vector2.INF:
		best = SimSetup.find_spawn_spot(sim, level.anthill_x, 400.0, false)
	sim.terrain.stamp_anthill(int(best.x), int(best.y))
	sim.anthill_pos = Vector2(best.x, best.y - TerrainSim.ANTHILL_H)


## Start of an enemy turn in a WAVES level: a new wave of ants comes out of the anthill. True when ants were spawned.
static func spawn_wave(sim: CombatSim) -> bool:
	var lv: LevelDef = sim.level
	if lv == null or lv.win_rule != "WAVES" or sim.waves_left <= 0 or sim.anthill_pos == Vector2.INF or lv.enemy_unit == null:
		return false
	var wave_no: int = lv.survive_rounds - sim.waves_left + 1
	sim.waves_left -= 1
	var unit: UnitDef = lv.enemy_unit
	var names1: Array = SimSetup._shuffled(sim, Array(SimTables.NAMES_POOL_1))
	var ground_y: float = sim.anthill_pos.y + TerrainSim.ANTHILL_H
	var reg := SimPlacement.new(sim)
	var player_x: float = _squad_x(sim, 0)
	for k in lv.wave_size:
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var pref: float = sim.anthill_pos.x + side * (WAVE_GAP + (k >> 1) * 24.0)
		var spot: Vector2 = reg.find("FIGHTER", pref, ground_y, sim.terrain.water_y - 28.0, unit.radius / 12.0, 0.0, 140.0)
		if spot == Vector2.INF:
			spot = Vector2(pref, ground_y)
		reg.add("FIGHTER", spot.x, spot.y, unit.radius / 12.0)
		var idx: int = 0
		for f in sim.fighters:
			idx += 1 if f.team == 1 else 0
		var facing: int = 1 if player_x > spot.x else -1
		sim.fighters.append(_make_unit(sim, 1, idx, String(names1[k % names1.size()]).strip_edges(), spot, unit, facing))
	sim.ftext(sim.anthill_pos.x, sim.anthill_pos.y - 36.0, "FT_WAVE", Palette.FT_ORANGE, 2.0, [wave_no])
	sim.wave_spawned.emit(wave_no, lv.wave_size, sim.anthill_pos)
	sim.hud()
	return true


## Places level.hiding_spots tufts on surfaces the eggs can walk to, above the water, between the squads: some close to the eggs, the rest further on.
static func place_hiding_spots(sim: CombatSim, level: LevelDef) -> void:
	sim.hiding_spots = []
	var ex: float = _squad_x(sim, 0)
	var ax: float = _squad_x(sim, 1)
	var egg_pos := Vector2(sim.fighters[0].x, sim.fighters[0].y)
	var reach: Array[Vector3] = sim.placement_nav.reachable(egg_pos, false)
	var n: int = level.hiding_spots
	var near: int = maxi(1, roundi(n * 0.4))
	var far: int = n - near
	var r: float = level.player_unit.radius if level.player_unit != null else 12.0
	var reg := SimPlacement.new(sim)
	for i in n:
		var t: float = 0.07 + 0.13 * i if i < near else 0.38 + 0.34 * (i - near) / maxf(1.0, far - 1.0)
		var want: float = ex + t * (ax - ex) + (sim.rand() - 0.5) * 40.0
		var best := Vector2.INF
		# The ground the eggs can walk to may be small (cliffs close it in): the walking-distance bands are then dropped.
		for relaxed in [false, true]:
			for c in reach:
				var in_band: bool = relaxed or (c.z <= NEAR_SPOT_PATH if i < near else (c.z >= 300.0 and c.z <= FAR_SPOT_PATH))
				var spot := Vector2(c.x, c.y - r)
				if in_band and c.x < ax - 100.0 and not _too_close(sim, spot, i < near) and (best == Vector2.INF or absf(c.x - want) < absf(best.x - want)) \
						and reg.is_free("HIDE", c.x, c.y, r / 12.0):
					best = spot
			if best != Vector2.INF:
				break
		if best != Vector2.INF:
			reg.add("HIDE", best.x, best.y + r, r / 12.0)
			sim.hiding_spots.append(best)
	SimGoals.setup(sim, level)


static func _squad_x(sim: CombatSim, team: int) -> float:
	var sum: float = 0.0
	var n: int = 0
	for f in sim.fighters:
		if f.team == team:
			sum += f.x
			n += 1
	return sum / maxf(1.0, n)


static func _too_close(sim: CombatSim, spot: Vector2, near_eggs: bool) -> bool:
	for s in sim.hiding_spots:
		if s.distance_to(spot) < 70.0:
			return true
	for f in sim.fighters:
		if f.team == 0 and absf(f.x - spot.x) < (60.0 if near_eggs else 120.0):
			return true
	return false


static func nearest_spot(sim: CombatSim, pos: Vector2) -> Vector2:
	var best: Vector2 = Vector2.INF
	for s in sim.hiding_spots:
		if best == Vector2.INF or s.distance_to(pos) < best.distance_to(pos):
			best = s
	return best


## True when the fighter stands within HIDING_SPOT_RADIUS of a hiding spot.
static func on_spot(sim: CombatSim, f: SimFighter) -> bool:
	var s: Vector2 = nearest_spot(sim, Vector2(f.x, f.y))
	return s != Vector2.INF and s.distance_to(Vector2(f.x, f.y)) <= CombatSim.HIDING_SPOT_RADIUS


## First weapon of the team with ammo left (index 0 for classic matches or when nothing is left).
static func first_armed_weapon(sim: CombatSim, team: int) -> int:
	if sim.level == null:
		return 0
	for i in sim.team_arsenal(team):
		if sim.ammo_f(team, sim.weapons[i].id) > 0.0:
			return i
	return 0


## End of the active fighter's turn: it hides if it stopped on a spot, and an enemy that stopped close to a hidden fighter sniffs it out. Runs once per turn.
static func on_turn_end(sim: CombatSim) -> void:
	var f: SimFighter = sim.active_fighter
	if sim.level == null or sim.turn_end_handled or f == null:
		return
	sim.turn_end_handled = true
	if sim.critter_group.size() >= 2:
		# a critter phase: every unit of the group ends its turn (hides, sniffs), in fighter index order; the leader comes back at the end
		for m in sim.critter_group:
			sim.active_fighter = m
			_end_turn_of(sim, m)
		sim.active_fighter = f
		return
	_end_turn_of(sim, f)


static func _end_turn_of(sim: CombatSim, f: SimFighter) -> void:
	for g in sim.fighters:
		if g.hidden and (not g.alive or g.drowning or not on_spot(sim, g)):
			g.hidden = false
	if not f.alive or f.drowning:
		return
	if f.unit != null and (f.unit.can_hide or (f.team == 0 and sim.level.hiding_spots > 0)) and f.grounded and not f.hidden and on_spot(sim, f):
		f.hidden = true
		sim.ftext(f.x, f.y - 34.0, "FT_HIDDEN", Palette.FT_GREEN, 1.6, [f.name])
		sim.hud()
	for g in sim.fighters:
		if g.hidden and g.team != f.team and g.alive and not g.drowning and Vector2(g.x - f.x, g.y - f.y).length() <= SNIFF_RADIUS:
			g.hidden = false
			sim.play("worm_voice", {"kind": "ITCH"})
			sim.ftext(g.x, g.y - 34.0, "FT_SNIFFED", Palette.FT_ORANGE, 1.8, [g.name])
			sim.hud()


## Start of a new round (team 0 about to play). Updates rounds_left; returns true when the SURVIVE_ROUNDS / WAVES goal is reached and the match ended.
static func begin_round(sim: CombatSim) -> bool:
	var lv: LevelDef = sim.level
	if lv.is_timed_goal():
		return SimGoals.begin_round(sim)
	if not counts_rounds(lv):
		return false
	if sim.round_number > lv.survive_rounds:
		sim.rounds_left = 0
		sim.turn_phase = CombatSim.Phase.GAME_OVER
		sim.winner = 0
		for f in sim.fighters:
			if f.team == 0 and f.alive and not f.drowning:
				sim.ftext(f.x, f.y - 40.0, "FT_NEST_SAVED" if lv.win_rule == "DEFEND_NEST" else "FT_HATCHED", Palette.FT_GOLD_SOFT, 2.4)
				break
		sim.play("victory")
		sim.game_over.emit(0, SimTurns.make_game_stats(sim))
		sim.hud()
		return true
	sim.rounds_left = lv.survive_rounds - sim.round_number + 1
	return false


## Extra game_over keys of a level: level_id, won, survivors, stars, reason (LOST, NEST_DESTROYED, ELIMINATED_ENEMY, SURVIVED, BOSS_DEFEATED,
## and in a convoy GOAL_REACHED, MINI_BOSS_DEFEATED, LEADER_DIED; `survivors` is then the leader plus the followers still in the line, plus
## followers, followers_start, followers_lost and goal_reached),
## enemies_defeated (enemy units that fell or drowned), nest_hp and nest_max_hp (levels with a nest).
static func add_stats(sim: CombatSim, stats: Dictionary) -> void:
	var lv: LevelDef = sim.level
	var survivors: int = sim.team_alive_count(0)
	var won: bool = sim.winner == 0
	var reason: String = "NEST_DESTROYED" if sim.nest != null and sim.nest.destroyed else "LOST"
	var convoy: bool = SimConvoy.active(sim)
	if convoy:
		survivors = SimConvoy.in_line_count(sim)
		reason = "LEADER_DIED" if SimConvoy.leader_dead(sim) else reason
	if won and sim.goal_reached:
		reason = "GOAL_REACHED"
	elif won and SimBoss.beaten(sim):
		reason = "BOSS_DEFEATED"
	elif won and SimConvoy.mini_boss_down(sim):
		reason = "MINI_BOSS_DEFEATED"
	elif won:
		reason = "ELIMINATED_ENEMY" if sim.team_alive_count(1) == 0 else "SURVIVED"
	if sim.goals != null and sim.goals.reason != "":
		reason = sim.goals.reason
	var stars: int = 0
	if won:
		stars = 1
		for need in lv.star_survivors:
			if survivors >= need:
				stars += 1
	if reason == "SURVIVED":
		stats["rounds"] = lv.survive_rounds
	var defeated: int = 0
	for f in sim.fighters:
		defeated += 1 if f.team == 1 and not f.alive else 0
	stats["enemies_defeated"] = defeated
	if convoy:
		stats["followers"] = maxi(0, survivors - 1)
		stats["followers_start"] = sim.convoy_start_count - 1
		stats["followers_lost"] = SimConvoy.lost_count(sim)
		stats["goal_reached"] = sim.goal_reached
	stats["level_id"] = lv.id
	stats["won"] = won
	stats["survivors"] = survivors
	stats["stars"] = stars
	stats["reason"] = reason
	if sim.nest != null:
		stats["nest_hp"] = maxi(0, sim.nest.hp)
		stats["nest_max_hp"] = sim.nest.max_hp
	if sim.goals != null:
		if sim.goals.anthill_max > 0:
			stats["anthill_hp"] = sim.goals.anthill_hp
			stats["anthill_max_hp"] = sim.goals.anthill_max
		if sim.goals.nut_total > 0:
			stats["nuts"] = sim.goals.nut_got
			stats["nuts_needed"] = sim.goals.nut_need
	if sim.boss != null:
		stats["boss_id"] = sim.boss_def.id
		stats["boss_hp"] = maxi(0, sim.boss.hp)

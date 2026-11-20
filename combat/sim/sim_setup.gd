## Match setup (JS initMatch, createFighter, spawn helpers).
class_name SimSetup
extends RefCounted


## JS initMatch: terrain, entities, first turn.
static func init_match(sim: CombatSim, config: MatchConfig) -> void:
	sim.cfg = config
	var level: LevelDef = config.level
	sim.level = level
	sim.weapons = sim._weapon_cache if level != null else sim._classic_weapon_cache
	sim.game_mode = config.game_mode
	sim.ai_difficulty = config.ai_difficulty
	sim.worms_per_team = config.worms_per_team
	sim.turn_time = 30.0
	sim.hiding_spots = []
	sim.nav = null
	sim._walk_nav = null
	sim.placement_nav = null
	sim.swarm_queue = []
	sim.critter_group = []
	sim.critter_plans = {}
	sim.critter_acting = []
	sim.sub_turn_time = 30.0
	sim.rounds_left = -1
	sim.critter_last_seen = Vector2.INF
	sim.turn_end_handled = false
	sim.waves_left = -1
	sim.anthill_pos = Vector2.INF
	sim.arsenals = [{}, {}]
	sim.wind_scale = 1.0
	SimBoss.reset(sim)
	SimBolso.reset(sim)
	SimConvoy.reset(sim)
	SimUpgrades.reset(sim)
	sim.silk_webs_spun = 0
	if level != null:
		sim.game_mode = "1P_CPU"
		sim.ai_difficulty = level.ai_difficulty
		sim.worms_per_team = maxi(1, level.player_names.size())
		sim.turn_time = level.turn_time
		sim.rounds_left = level.survive_rounds if SimStory.counts_rounds(level) else -1
		sim.waves_left = level.survive_rounds if level.win_rule == "WAVES" else -1
		sim.wind_scale = level.wind_scale
	if config.seed != 0:
		sim.rng.seed = config.seed
	else:
		sim.rng.randomize()
	var map_idx: int = clampi(config.map_idx, 0, sim.maps.size() - 1)
	sim.terrain.generate(sim.maps[map_idx], sim.rng, config.seed != 0)
	var terrain: TerrainSim = sim.terrain
	if level != null and level.mode == "COMBAT" and level.arena_width > 0.0 and level.arena_width < float(SimTables.TERRAIN_W):
		var mid: float = level.arena_center if level.arena_center > 0.0 else SimTables.TERRAIN_W * 0.5
		var x0: float = clampf(mid - level.arena_width * 0.5, 0.0, SimTables.TERRAIN_W - level.arena_width)
		terrain.set_arena(x0, x0 + level.arena_width)

	sim.fighters = []
	sim.barrels = []
	sim.mines = []
	sim.crates = []
	sim.projectiles = []
	sim.airstrike_planes = []
	sim.tombstones = []
	sim.surface_flora = []
	sim.silk_webs = []
	sim.silk_nests = []
	sim.pine_nuts = []
	sim.larvae_swarms = []
	sim.updrafts = []
	sim.rovellons = []
	sim.caganers = []
	sim.escudelles = []
	sim._delayed = []
	sim.active_fighter = null
	sim.ai_plan = {}
	sim.round_number = 1
	sim.winner = -1
	sim.team_damage_dealt = [0, 0]
	sim.team_selected_weapon_idx = [0, 0]
	sim.selected_weapon_idx = 0
	for t in 2:
		sim.team_ammo[t] = {}
		for w in sim.weapons:
			sim.team_ammo[t][w.id] = INF if w.default_ammo < 0 else float(w.default_ammo)

	if level != null:
		SimStory.build_anthill(sim, level)
		sim.nav = SimNav.new(terrain, false)
		SimStory.apply_arsenals(sim, level, config.extra_arsenal)
		SimStory.spawn_squads(sim, level)
		SimBoss.spawn(sim, level)
		SimStory.place_hiding_spots(sim, level)
		SimConvoy.build(sim, level)
		SimBolso.build(sim, level)
		SimUpgrades.apply(sim, config.upgrades)
	var names: Array = _squad_names(sim, config) if level == null else [[], []]

	var count: int = clampi(config.worms_per_team, 1, 6) if level == null else 0
	var usable_span: float = SimTables.TERRAIN_W - 760.0
	var reg := SimPlacement.new(sim)
	if count > 0:
		var nav := SimNav.new(terrain, false)
		reg.extra_filter = func(x: float, sy: float) -> bool: return nav.reachable(Vector2(x, sy - 14.0), true).size() >= SimPlacement.MIN_ROOM
	for i in count:
		var frac1: float = (0.22 + sim.rand() * 0.18) if count == 1 else (i + 0.15 + sim.rand() * 0.35) / count
		var frac2: float = (0.60 + sim.rand() * 0.18) if count == 1 else (i + 0.50 + sim.rand() * 0.35) / count
		var pref_x1: float = 380.0 + frac1 * usable_span
		var pref_x2: float = 380.0 + frac2 * usable_span
		var s1: Vector2 = place_fighter(sim, reg, find_spawn_spot(sim, pref_x1, 260.0, i % 2 == 1))
		var s2: Vector2 = place_fighter(sim, reg, find_spawn_spot(sim, pref_x2, 260.0, i % 2 == 0))
		sim.fighters.append(create_fighter(sim, 0, i, names[0][i], s1.x, 1, s1.y))
		sim.fighters.append(create_fighter(sim, 1, i, names[1][i], s2.x, -1, s2.y))

	var wy: float = terrain.water_y
	if level == null or level.hazards:
		_spawn_barrels(sim, wy)
		_spawn_mines(sim, wy)
		_spawn_nests(sim)
		var flora: Array[SimFlora] = _flora_candidates(sim, wy, sim.maps[map_idx].id)
		_spawn_updrafts(sim, wy)
		_spawn_pickups(sim, wy)
		_place_flora(sim, flora)

	var start_idx0: int = int(sim.rand() * maxi(1, config.worms_per_team))
	var start_idx1: int = int(sim.rand() * maxi(1, config.worms_per_team))
	sim.team_turn_idx = [start_idx0, start_idx1]
	if level != null:
		sim.round_number = 0
	sim.active_team = 1 if sim.game_mode == "1P_CPU" else (0 if sim.rand() < 0.5 else 1)
	SimTurns.start_next_turn(sim)
	sim.hud()


static func _squad_names(sim: CombatSim, config: MatchConfig) -> Array:
	if config.team_names.size() >= 2 and (config.team_names[0] as Array).size() >= config.worms_per_team:
		return config.team_names
	var p0: Array = _shuffled(sim, Array(SimTables.NAMES_POOL_0))
	var p1: Array = _shuffled(sim, Array(SimTables.NAMES_POOL_1))
	var out: Array = [[], []]
	for i in 6:
		out[0].append(String(p0[i]).strip_edges())
		out[1].append(String(p1[i]).strip_edges())
	return out


static func _shuffled(sim: CombatSim, items: Array) -> Array:
	var a: Array = items.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j: int = int(sim.rand() * (i + 1))
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
	return a


## JS findValidLandX.
static func find_valid_land_x(sim: CombatSim, preferred_x: float, max_radius: float = 260.0) -> float:
	var r: float = 0.0
	while r <= max_radius:
		for d in ([0] if r == 0.0 else [-1, 1]):
			var test_x: float = sim.terrain.clamp_x(SimMath.round_js(preferred_x + d * r), 240.0)
			var sy: float = sim.terrain.find_surface_y(test_x, 40.0)
			if sy < sim.terrain.water_y - 28.0:
				return test_x
		r += 18.0
	return sim.terrain.clamp_x(SimMath.round_js(preferred_x), 260.0)


## JS findMultiLevelSpawnSpot: x and tier y of a spawn spot near preferred_x.
static func find_spawn_spot(sim: CombatSim, preferred_x: float, max_radius: float = 260.0, prefer_lower: bool = false) -> Vector2:
	var r: float = 0.0
	while r <= max_radius:
		for d in ([0] if r == 0.0 else [-1, 1]):
			var test_x: float = sim.terrain.clamp_x(SimMath.round_js(preferred_x + d * r), 240.0)
			var tiers: PackedInt32Array = sim.terrain.find_all_walkable_surfaces_at_x(test_x)
			if tiers.size() > 0:
				var chosen_y: int = tiers[0]
				if tiers.size() > 1 and (prefer_lower or sim.rand() < 0.52):
					chosen_y = tiers[tiers.size() - 1]
				return Vector2(test_x, float(chosen_y))
		r += 18.0
	var fallback_x: float = find_valid_land_x(sim, preferred_x, max_radius)
	return Vector2(fallback_x, sim.terrain.find_surface_y(fallback_x, 40.0))


## JS createFighter.
static func create_fighter(sim: CombatSim, team: int, member_idx: int, fname: String, x: float, facing: int, explicit_surf_y: float) -> SimFighter:
	var sy: float = explicit_surf_y
	var fy: float = minf(sim.terrain.water_y - 30.0, sy - 14.0)
	var f := SimFighter.new()
	f.id = sim.next_fighter_id
	sim.next_fighter_id += 1
	f.team = team
	f.member_idx = member_idx
	f.name = fname
	f.x = x
	f.y = fy
	f.jump_start_y = fy
	f.peak_air_y = fy
	f.facing = facing
	for s in 6:
		f.segs.append(Vector2(x - facing * (s + 1) * 5.2, fy + 4.0))
	f.walk_cycle = sim.rand() * TAU
	var pal_idx: int = (member_idx + int(sim.rand() * SimTables.BODY_PALETTES.size())) % SimTables.BODY_PALETTES.size()
	var pal: Array = SimTables.BODY_PALETTES[pal_idx]
	f.body_colors = [Color(pal[0]), Color(pal[1]), Color(pal[2])]
	f.dorsal_color = Color(SimTables.DORSAL_PALETTES_0[pal_idx] if team == 0 else SimTables.DORSAL_PALETTES_1[pal_idx])
	f.individual_hat = SimTables.HAT_STYLES[(member_idx + team * 2 + int(sim.rand() * 2.0)) % SimTables.HAT_STYLES.size()]
	f.has_mustache = sim.rand() < 0.38
	return f


## A fighter spawn spot moved to the nearest free place (not on a tree, not on another fighter, not in rock); the spot itself when none is.
static func place_fighter(sim: CombatSim, reg: SimPlacement, spot: Vector2, radius: float = 12.0, max_shift: float = 260.0) -> Vector2:
	var free: Vector2 = reg.find("FIGHTER", spot.x, spot.y, sim.terrain.water_y - 28.0, radius / 12.0, 0.0, max_shift)
	var out: Vector2 = spot if free == Vector2.INF else free
	reg.add("FIGHTER", out.x, out.y, radius / 12.0)
	return out


## A world x of the whole terrain mapped into the playable span (unchanged when the arena is the whole terrain).
static func _fit(sim: CombatSim, x: float) -> float:
	if not sim.terrain.is_clipped():
		return x
	return sim.terrain.arena_at(x / float(SimTables.TERRAIN_W))


static func _spawn_barrels(sim: CombatSim, wy: float) -> void:
	var reg := SimPlacement.new(sim)
	var barrel_count: int = 3 + int(sim.rand() * 5.0)
	for b in barrel_count:
		var raw_x: float = _fit(sim, 360.0 + ((b + 0.3 + sim.rand() * 0.4) / barrel_count) * (SimTables.TERRAIN_W - 720.0))
		var want: Vector2 = find_spawn_spot(sim, raw_x, 180.0, b % 2 == 1)
		var spot: Vector2 = reg.find("BARREL", want.x, want.y, wy - 22.0, 1.0, 42.0)
		if spot != Vector2.INF:
			reg.add("BARREL", spot.x, spot.y)
			var br := SimBarrel.new()
			br.x = spot.x
			br.y = spot.y - 14.0
			sim.barrels.append(br)


static func _spawn_mines(sim: CombatSim, wy: float) -> void:
	var reg := SimPlacement.new(sim)
	var mine_count: int = 2 + int(sim.rand() * 4.0)
	for m in mine_count:
		var raw_x: float = _fit(sim, 440.0 + ((m + 0.25 + sim.rand() * 0.5) / mine_count) * (SimTables.TERRAIN_W - 880.0))
		var want: Vector2 = find_spawn_spot(sim, raw_x, 180.0, m % 2 == 0)
		var spot: Vector2 = reg.find("MINE", want.x, want.y, wy - 22.0, 1.0, 58.0)
		if spot != Vector2.INF:
			reg.add("MINE", spot.x, spot.y)
			var mi := SimMine.new()
			mi.x = spot.x
			mi.y = spot.y - 5.0
			sim.mines.append(mi)


static func _spawn_nests(sim: CombatSim) -> void:
	var subset: Array[Dictionary] = []
	for spot in sim.terrain.tree_spots:
		if sim.rand() < 0.68:
			subset.append(spot)
	var chosen: Array[Dictionary] = subset
	if subset.size() < 2:
		chosen = []
		for i in mini(3, sim.terrain.tree_spots.size()):
			chosen.append(sim.terrain.tree_spots[i])
	for spot in chosen:
		var nest := SimNest.new()
		nest.anchor_x = float(spot["tx"]) - 18.0
		nest.anchor_y = maxf(85.0, float(spot["crown_y"]) + 4.0)
		nest.x = nest.anchor_x
		nest.y = nest.anchor_y + 28.0
		nest.sway_phase = sim.rand() * TAU
		sim.silk_nests.append(nest)


## The flora tufts of the map (the RNG is drawn here, in the JS order); `_place_flora` keeps the ones that find room.
static func _flora_candidates(sim: CombatSim, wy: float, map_id: String) -> Array[SimFlora]:
	var out: Array[SimFlora] = []
	var fx: float = maxf(240.0, sim.terrain.arena_x0)
	while fx < minf(SimTables.TERRAIN_W - 240.0, sim.terrain.arena_x1):
		var tiers: PackedInt32Array = sim.terrain.find_all_walkable_surfaces_at_x(fx)
		for sy in tiers:
			if sy < wy - 22.0 and not sim.terrain.is_solid(fx, sy - 10.0):
				var n: Vector2 = sim.terrain.surface_normal(fx, sy)
				if absf(n.x) < 0.62:
					var fl := SimFlora.new()
					fl.x = fx
					fl.y = sy
					fl.type = map_id
					fl.variant = int(sim.rand() * 3.0)
					fl.scale = 0.78 + sim.rand() * 0.45
					fl.phase = sim.rand() * TAU
					out.append(fl)
		fx += 44.0 + floorf(sim.rand() * 38.0)
	return out


## Flora is scenery: it yields to every other object and to the structures.
static func _place_flora(sim: CombatSim, candidates: Array[SimFlora]) -> void:
	var reg := SimPlacement.new(sim)
	for fl in candidates:
		if reg.is_free("FLORA", fl.x, fl.y, fl.scale):
			reg.add("FLORA", fl.x, fl.y, fl.scale)
			sim.surface_flora.append(fl)


static func _spawn_updrafts(sim: CombatSim, wy: float) -> void:
	var reg := SimPlacement.new(sim)
	var valleys: Array = _shuffled(sim, Array(sim.terrain.valley_spots))
	var count: int = mini(valleys.size(), 1 + int(sim.rand() * minf(3.0, valleys.size())))
	for u in count:
		var ux: float = float(valleys[u])
		var uy: float = minf(wy - 12.0, sim.terrain.find_surface_y(ux, 140.0))
		var spot: Vector2 = reg.find("UPDRAFT", ux, uy, wy - 12.0, 1.0, 0.0, 40.0)
		if spot != Vector2.INF:
			reg.add("UPDRAFT", spot.x, spot.y)
			var ud := SimUpdraft.new()
			ud.x = spot.x
			ud.y = spot.y
			sim.updrafts.append(ud)


static func _spawn_pickups(sim: CombatSim, wy: float) -> void:
	var reg := SimPlacement.new(sim)
	var rov_count: int = 3 + int(sim.rand() * 3.0)
	for r in rov_count:
		var raw_x: float = _fit(sim, 480.0 + ((r + 0.2 + sim.rand() * 0.6) / rov_count) * (SimTables.TERRAIN_W - 960.0))
		var want: Vector2 = find_spawn_spot(sim, raw_x, 160.0, r % 2 == 1)
		var spot: Vector2 = reg.find("ROVELLO", want.x, want.y, wy - 25.0, 1.0, 44.0)
		if spot != Vector2.INF:
			reg.add("ROVELLO", spot.x, spot.y)
			var rv := SimRovello.new()
			rv.x = spot.x
			rv.y = spot.y
			rv.r = 17.0 + sim.rand() * 4.0
			sim.rovellons.append(rv)
	var cag_count: int = 1 + int(sim.rand() * 2.0)
	for c in cag_count:
		var raw_x: float = _fit(sim, 620.0 + c * 1450.0 + (sim.rand() - 0.5) * 420.0)
		var want: Vector2 = find_spawn_spot(sim, raw_x, 200.0, true)
		var spot: Vector2 = reg.find("CAGANER", want.x, want.y, wy - 30.0, 1.0, 55.0)
		if spot != Vector2.INF:
			reg.add("CAGANER", spot.x, spot.y)
			var cg := SimCaganer.new()
			cg.x = spot.x
			cg.y = spot.y - 8.0
			cg.bob_phase = sim.rand() * TAU
			sim.caganers.append(cg)
	for e in 2:
		var raw_x: float = _fit(sim, 920.0 + e * 1280.0 + (sim.rand() - 0.5) * 320.0)
		var want: Vector2 = find_spawn_spot(sim, raw_x, 180.0, e == 1)
		var spot: Vector2 = reg.find("ESCUDELLA", want.x, want.y, wy - 28.0, 1.0, 52.0)
		if spot != Vector2.INF:
			reg.add("ESCUDELLA", spot.x, spot.y)
			var es := SimEscudella.new()
			es.x = spot.x
			es.y = spot.y - 12.0
			es.steam_phase = sim.rand() * TAU
			sim.escudelles.append(es)


## JS spawnSupplyDrop. The crate is dropped where it will land on free ground (no tree crown, nothing under it, not in the water).
static func spawn_supply_drop(sim: CombatSim) -> void:
	var x: float = _fit(sim, 300.0 + sim.rand() * (SimTables.TERRAIN_W - 600.0))
	var medkit: bool = sim.rand() < 0.42
	var reward: String = SimTables.CRATE_REWARDS[int(sim.rand() * SimTables.CRATE_REWARDS.size())]
	var drop_x: float = SimPlacement.new(sim).find_drop(x)
	if is_nan(drop_x):
		return
	var c := SimCrate.new()
	c.x = drop_x
	c.is_medkit = medkit
	c.reward_wpn = reward
	sim.crates.append(c)

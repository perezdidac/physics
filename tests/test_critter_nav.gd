## Critter navigation on changing terrain: SimNav follows craters, no link goes through rock, ants climb along the wall face, fall when the ground
## goes away and dig a tunnel toward a target they cannot reach (deterministically).
##   godot --headless --path . res://tests/TestCritterNav.tscn
extends Node

const DT: float = 1.0 / 60.0
const GROUND: int = 500

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	_nav_follows_craters()
	_no_links_through_rock()
	_climb_hugs_wall()
	_falls_without_ground()
	_dig_tunnel()
	_dig_limits()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


## One ant (team 1) and one egg (team 0) on a flat floor at y = GROUND (x from 0 to the end) plus the given solid rectangles. The turn is the egg's.
func _world(rocks: Array[Rect2i], ant_x: float, egg_x: float, egg_y: float = -1.0) -> CombatSim:
	var lv := load("res://data/levels/egg_1.tres").duplicate() as LevelDef
	lv.survive_rounds = 99
	var cfg := MatchConfig.new()
	cfg.level = lv
	cfg.map_idx = lv.map_idx
	cfg.seed = lv.seed
	cfg.game_mode = "1P_CPU"
	cfg.worms_per_team = lv.player_names.size()
	var sim := CombatSim.new()
	sim.setup(cfg)
	var t: TerrainSim = sim.terrain
	t.mask.fill(0)
	_fill(t, Rect2i(0, GROUND, TerrainSim.W, TerrainSim.H - GROUND))
	for r in rocks:
		_fill(t, r)
	sim.nav = SimNav.new(t)
	sim._walk_nav = null # the terrain was edited behind the sim's back: the critters' map is built again from it
	var egg: SimFighter = null
	var ant: SimFighter = null
	for f in sim.fighters:
		if f.team == 0 and egg == null:
			egg = f
		elif f.team == 1 and ant == null:
			ant = f
		else:
			f.alive = false
	egg.x = egg_x
	egg.y = (float(GROUND) - egg.r - 1.0) if egg_y < 0.0 else egg_y
	ant.x = ant_x
	ant.y = float(GROUND) - ant.r - 1.0
	for f in [egg, ant]:
		f.grounded = false
		f.vx = 0.0
		f.vy = 0.0
		f.jump_start_y = f.y
		f.peak_air_y = f.y
	return sim


func _fill(t: TerrainSim, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			t.mask[y * TerrainSim.W + x] = 1


func _step(sim: CombatSim, seconds: float) -> void:
	for i in int(seconds / DT):
		sim.step(DT)
		sim.advance_real(DT)


## Passes the egg's turn and runs until the ant's turn starts.
func _to_ant_turn(sim: CombatSim) -> SimFighter:
	_step(sim, 1.0)
	if sim.active_team == 0 and sim.turn_phase == CombatSim.Phase.TURN_PLAY:
		sim.end_turn()
	var t: float = 0.0
	while t < 30.0 and not (sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 1):
		_step(sim, DT)
		t += DT
	return sim.active_fighter


func _ant(sim: CombatSim) -> SimFighter:
	for f in sim.fighters:
		if f.team == 1 and f.alive:
			return f
	return null


func _nav_follows_craters() -> void:
	var sim := _world([], 300.0, 2000.0)
	var nav: SimNav = sim.nav
	var col: int = roundi((1000.0 - SimNav.X_MIN) / SimNav.STEP)
	_check(nav.tiers[col][0] == GROUND, "flat floor: one surface at the ground line")
	sim.terrain.carve_crater(1000.0, float(GROUND), 40.0)
	nav.sync()
	_check(nav.tiers[col][0] > GROUND + 25, "after a crater the column under it has the crater floor (%d)" % nav.tiers[col][0])
	var path: Array[Vector2] = nav.find_path(Vector2(700.0, 480.0), Vector2(1300.0, 480.0), true)
	var over_hole: bool = false
	for p in path:
		if absf(p.x - 1000.0) < 25.0 and p.y < GROUND + 20.0:
			over_hole = true
	_check(not path.is_empty() and not over_hole, "a path to the other side goes down into the hole, not over it")
	sim.terrain.build_girder(1000.0, float(GROUND) + 10.0, 0.0, 100.0, 30.0)
	_check(nav.find_path(Vector2(700.0, 480.0), Vector2(1300.0, 480.0), false).size() > 0 and nav.edits_seen == sim.terrain.edit_log.size(), "a girder over the hole refreshes the map as well")
	var stamp: int = sim.terrain.edit_log.size()
	sim.terrain.carve_crater(600.0, float(GROUND), 20.0)
	_check(nav.edits_hit_path(stamp, path) == false and nav.edits_hit_path(stamp, [Vector2(600.0, GROUND), Vector2(610.0, GROUND)] as Array[Vector2]), "edits_hit_path tells which paths a later edit touches")


func _no_links_through_rock() -> void:
	# a wall 4 px thin between two columns, no column sees it
	var sim := _world([Rect2i(1004, 440, 4, 60)], 300.0, 2000.0)
	var nav: SimNav = sim.nav
	var c: int = roundi((1000.0 - SimNav.X_MIN) / SimNav.STEP)
	_check(nav.tiers[c][0] == GROUND and nav.tiers[c + 1][0] == GROUND, "the thin wall is invisible to the columns")
	_check(not nav._passable(c, GROUND, c + 1, GROUND), "no link through a thin wall")
	_check(nav.find_path(Vector2(700.0, 480.0), Vector2(1300.0, 480.0), true).is_empty(), "no path through the thin wall")
	# a slab over the ground: the top of the slab is not linked down to the floor under it
	var sim2 := _world([Rect2i(1100, 440, 200, 30)], 300.0, 2000.0)
	var n2: SimNav = sim2.nav
	var cs: int = roundi((1104.0 - SimNav.X_MIN) / SimNav.STEP)
	_check(n2.tiers[cs].size() == 2, "under the slab the column has two surfaces (top of the slab and the floor)")
	_check(not n2._passable(cs, 440, cs + 1, GROUND) and not n2._passable(cs + 1, GROUND, cs, 440), "no link between the top of a slab and the floor under it")
	_check(n2._passable(cs - 1, GROUND, cs, GROUND), "the floor under the slab is still a walkable passage")
	_check(n2.find_path(Vector2(900.0, 480.0), Vector2(1200.0, 440.0), true).size() > 0, "the top of the slab is reached by climbing its end")
	# a ceiling lower than a body: nothing passes under it
	var sim3 := _world([Rect2i(1100, 440, 200, 52)], 300.0, 2000.0)
	_check(sim3.nav.find_path(Vector2(900.0, 480.0), Vector2(1400.0, 480.0), true).size() > 0, "a ceiling too low to enter does not block the way over it")


func _climb_hugs_wall() -> void:
	var sim := _world([Rect2i(1000, 420, 260, GROUND - 420)], 800.0, 1230.0, 420.0 - 12.0)
	var ant: SimFighter = _to_ant_turn(sim)
	var egg: SimFighter = null
	for f in sim.fighters:
		if f.team == 0 and f.alive:
			egg = f
	var face_gap: float = 0.0
	var climbed: float = 0.0
	var t: float = 0.0
	while t < 12.0 and sim.turn_phase == CombatSim.Phase.TURN_PLAY and egg.hp == egg.max_hp:
		_step(sim, DT)
		t += DT
		if ant.x < 1000.0 and ant.y < float(GROUND) - ant.r - 8.0 and ant.y > 416.0 and ant.grounded:
			climbed = maxf(climbed, float(GROUND) - ant.y)
			face_gap = maxf(face_gap, absf(ant.x - (1000.0 - ant.r - 1.0)))
	_check(climbed > 40.0, "the ant climbs the wall (%.0f px up)" % climbed)
	_check(face_gap <= 2.5, "while climbing the ant's body touches the wall face (largest gap %.1f px)" % face_gap)
	_check(ant.y < 420.0 and ant.x > 1000.0, "it ends up over the lip on top of the wall")


func _falls_without_ground() -> void:
	var sim := _world([], 800.0, 1700.0)
	var ant: SimFighter = _to_ant_turn(sim)
	_step(sim, 0.6)
	_check(ant.grounded and ant.x > 820.0, "the ant walks toward the egg")
	var y0: float = ant.y
	sim.terrain.carve_crater(ant.x + 6.0, float(GROUND), 38.0)
	_step(sim, 0.12)
	_check(not ant.grounded and ant.y > y0, "with the ground gone the ant stops walking and falls")
	_step(sim, 0.5)
	_check(ant.alive and ant.grounded and ant.y > y0 + 25.0, "it lands on the crater floor")
	var x1: float = ant.x
	_step(sim, 6.0)
	_check(ant.alive and ant.x > x1 + 40.0, "and climbs out and goes on (%.0f -> %.0f)" % [x1, ant.x])
	var sim2 := _world([], 800.0, 1700.0)
	var ant2: SimFighter = _to_ant_turn(sim2)
	_step(sim2, 0.4)
	sim2.terrain.carve_crater(ant2.x + 6.0, float(GROUND), 120.0)
	var hp0: int = ant2.hp
	_step(sim2, 2.0)
	_check(ant2.hp < hp0 or not ant2.alive, "a long fall hurts like any other fall (%d -> %d)" % [hp0, ant2.hp])


## Runs the tunnel scenario and returns {ant_turns, bites_per_turn, x, y, hp, hash}.
func _dig_run() -> Dictionary:
	var sim := _world([Rect2i(1000, 100, 70, GROUND - 100)], 880.0, 1250.0)
	var turns: Array[int] = [0]
	sim.turn_started.connect(func(team: int, _f: SimFighter) -> void: turns[0] += 1 if team == 1 else 0)
	var ant: SimFighter = _to_ant_turn(sim)
	var egg: SimFighter = null
	for f in sim.fighters:
		if f.team == 0 and f.alive:
			egg = f
	var bites: Array[int] = []
	var log0: int = sim.terrain.edit_log.size()
	var t: float = 0.0
	while t < 200.0 and egg.hp == egg.max_hp and egg.alive and turns[0] < 6:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			bites.append(sim.terrain.edit_log.size() - log0)
			log0 = sim.terrain.edit_log.size()
			sim.end_turn()
		_step(sim, DT)
		t += DT
	var mask_hash: int = hash(sim.terrain.mask)
	return {"turns": turns[0], "bites": bites, "x": ant.x, "y": ant.y, "egg_hp": egg.hp, "hash": mask_hash, "log": sim.terrain.edit_log.size()}


func _dig_tunnel() -> void:
	var a: Dictionary = _dig_run()
	_check(int(a["egg_hp"]) < 100 or a["x"] > 1070.0, "an ant facing a rock wall 70 px thick digs through and reaches the egg (ant turns: %d, x %.0f, egg hp %d)" % [a["turns"], a["x"], a["egg_hp"]])
	_check(int(a["turns"]) <= 4, "the 70 px wall takes at most 4 ant turns (%d)" % a["turns"])
	var worst: int = 0
	for b in a["bites"]:
		worst = maxi(worst, int(b))
	_check(worst > 0 and worst <= AiCritter.MAX_BITES, "it bites at most %d times per turn (most in a turn: %d)" % [AiCritter.MAX_BITES, worst])
	var b2: Dictionary = _dig_run()
	_check(a["hash"] == b2["hash"] and is_equal_approx(a["x"], b2["x"]) and is_equal_approx(a["y"], b2["y"]) and a["log"] == b2["log"] and a["egg_hp"] == b2["egg_hp"], "digging is deterministic: same terrain, same position, same damage twice")


func _dig_limits() -> void:
	# a unit without can_dig stays out of the rock
	var sim := _world([Rect2i(1000, 100, 70, GROUND - 100)], 880.0, 1250.0)
	var ant: SimFighter = _to_ant_turn(sim)
	ant.unit = ant.unit.duplicate()
	ant.unit.can_dig = false
	var log0: int = sim.terrain.edit_log.size()
	_step(sim, 6.0)
	_check(sim.terrain.edit_log.size() == log0, "a unit that cannot dig leaves the rock alone")
	# no digging below the water line
	var sim2 := _world([Rect2i(1000, 100, 70, GROUND - 100)], 880.0, 1250.0)
	sim2.terrain.water_y = float(GROUND) + 4.0
	var ant2: SimFighter = _to_ant_turn(sim2)
	var log1: int = sim2.terrain.edit_log.size()
	_step(sim2, 6.0)
	_check(sim2.terrain.edit_log.size() == log1 and ant2.alive, "the ant does not dig under water")

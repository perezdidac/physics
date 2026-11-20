## Story mode in the sim: classic matches unchanged, level setup, egg limits, hiding, the ant AI, the SURVIVE_ROUNDS goal and full CPU-driven runs.
##   godot --headless --path . res://tests/TestStorySim.tscn
extends Node

const DT: float = 1.0 / 60.0

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _level(id: String) -> LevelDef:
	return load("res://data/levels/%s.tres" % id)


func _make(level: LevelDef) -> CombatSim:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.level = level
	cfg.map_idx = level.map_idx
	cfg.seed = level.seed
	cfg.game_mode = "1P_CPU"
	cfg.worms_per_team = level.player_names.size()
	sim.setup(cfg)
	return sim


func _classic(seed_v: int = 99) -> CombatSim:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = seed_v
	cfg.game_mode = "2P_LOCAL"
	cfg.worms_per_team = 3
	cfg.map_idx = 3
	sim.setup(cfg)
	return sim


func _run(sim: CombatSim, seconds: float) -> void:
	var n: int = int(seconds / DT)
	for i in n:
		sim.step(DT)
		sim.advance_real(DT)


## Steps until the active team is `team` in TURN_PLAY again (or the match ends); returns the seconds spent.
func _until_turn(sim: CombatSim, team: int, max_s: float = 90.0) -> float:
	var t: float = 0.0
	while t < max_s and sim.turn_phase != CombatSim.Phase.GAME_OVER:
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == team and t > 0.5:
			break
	return t


func _team(sim: CombatSim, team: int) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team == team:
			out.append(f)
	return out


## Puts a fighter on the ground at x, falling from above, and lets it settle.
func _drop_at(f: SimFighter, x: float, sy: float) -> void:
	f.x = x
	f.y = sy - f.r - 2.0
	f.vx = 0.0
	f.vy = 0.0
	f.grounded = false


## Distance walked in one second, trying both directions (a wall may block one of them).
func _best_walk(sim: CombatSim, f: SimFighter) -> float:
	var best: float = 0.0
	for dir in [1, -1]:
		var x0: float = f.x
		sim.set_move(dir)
		_run(sim, 1.0)
		sim.set_move(0)
		best = maxf(best, absf(f.x - x0))
	return best


func _ready() -> void:
	_classic_unchanged()
	_level_setup()
	_arena()
	_egg_limits()
	_hiding()
	_ant_ai()
	_swarm()
	_survive_rounds()
	_full_run("egg_1")
	_full_run("egg_2")
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


## LevelDef.arena_width: the land outside the span is gone, everything stands inside it, nobody can leave it, classic terrain untouched.
func _arena() -> void:
	var classic := _classic()
	_check(not classic.terrain.is_clipped() and classic.terrain.arena_x0 == 0.0 and classic.terrain.arena_x1 == 3200.0 and classic.terrain.clamp_x(100.0, 240.0) == 240.0 and classic.terrain.clamp_x(3150.0, 240.0) == 2960.0, "classic: the arena is the whole terrain and the placement clamps are the old ones")
	var cols: int = 0
	for id in ["larva_1", "cuca_3", "nest_2", "proc_1", "larva_boss"]:
		var lv: LevelDef = _level(id)
		var sim := _make(lv)
		var t: TerrainSim = sim.terrain
		var mid: float = lv.arena_center if lv.arena_center > 0.0 else 1600.0
		var land_out: int = 0
		for y in range(0, TerrainSim.H, 7):
			for x in range(0, TerrainSim.W, 5):
				if (float(x) < t.arena_x0 or float(x) >= t.arena_x1) and t.mask[y * TerrainSim.W + x] == 1:
					land_out += 1
				cols += 1 if t.mask[y * TerrainSim.W + x] == 1 else 0
		_check(lv.arena_width >= 900.0 and lv.arena_width <= 2200.0 and t.is_clipped() and absf(t.arena_x0 - (mid - lv.arena_width * 0.5)) < 0.01 and absf(t.arena_width() - lv.arena_width) < 0.01, "%s: the arena is %d px wide around x %d" % [id, int(lv.arena_width), int(mid)])
		_check(land_out == 0, "%s: no land outside the arena" % id)
		var inside: bool = true
		for f in sim.fighters:
			inside = inside and f.x >= t.arena_x0 + 20.0 and f.x <= t.arena_x1 - 20.0
		inside = inside and (sim.nest == null or (sim.nest.pos.x > t.arena_x0 and sim.nest.pos.x < t.arena_x1))
		inside = inside and (sim.goal_x < 0.0 or (sim.goal_x > t.arena_x0 and sim.goal_x < t.arena_x1))
		_check(inside, "%s: squads, boss, nest and goal are inside the arena" % id)
		# walking against the wall stops at the edge of the arena
		var p: SimFighter = _team(sim, 0)[0]
		sim.active_fighter = p
		p.x = t.arena_x0 + 60.0
		p.y = t.find_surface_y(p.x, 40.0) - p.r - 1.0
		p.grounded = true
		sim.set_move(-1)
		_run(sim, 3.0)
		sim.set_move(0)
		_check(p.x >= t.arena_x0 + 29.0, "%s: a caterpillar cannot walk out of the arena (x %.0f, edge %.0f)" % [id, p.x, t.arena_x0])
	_check(cols > 0, "the arenas still have land")


func _classic_unchanged() -> void:
	var sim := _classic()
	var ids: Array[String] = []
	for w in sim.weapons:
		ids.append(w.id)
	_check(sim.weapons.size() == 16 and ids[0] == "BAZOOKA" and ids[15] == "GANXO" and not ids.has("EMPENTA"), "classic match sees exactly the 16 original weapons in order")
	_check(sim.team_arsenal(0).size() == 16 and sim.team_arsenal(1)[15] == 15, "classic team_arsenal is every weapon")
	var f: SimFighter = sim.fighters[0]
	_check(f.kind == "CATERPILLAR" and f.unit == null and not f.hidden and f.r == 12.0 and f.hp == 100 and f.speed_mult() == 1.0 and f.can_jump(), "classic fighters are plain caterpillars")
	_check(sim.level == null and sim.hiding_spots.is_empty() and sim.rounds_left == -1 and sim.turn_timer == 30.0 and sim.turn_time == 30.0, "classic: no level state, 30 s turn")
	_check(sim.barrels.size() > 0 and sim.mines.size() > 0, "classic still spawns barrels and mines")
	var same := _classic()
	_check(same.fighters[0].x == sim.fighters[0].x and same.barrels.size() == sim.barrels.size(), "classic setup is still deterministic")
	var a: SimFighter = sim.active_fighter
	_run(sim, 1.0)
	sim.jump_forward()
	_check(not a.grounded or a.vy < 0.0, "classic caterpillar still jumps")
	var slot_after: bool = sim.team_ammo[0].has("MOSSEGADA")
	_check(not slot_after, "classic ammo table has no story weapons")
	var s2 := _classic()
	s2.end_turn()
	_check(s2.turn_phase == CombatSim.Phase.ACTION_WAIT, "end_turn passes the turn in a classic match too")


func _level_setup() -> void:
	var l1: LevelDef = _level("egg_1")
	var sim := _make(l1)
	var eggs: Array[SimFighter] = _team(sim, 0)
	var ants: Array[SimFighter] = _team(sim, 1)
	_check(sim.weapons.size() == 21 and sim.weapon_index("EMPENTA") == 16 and sim.weapon_index("MOSSEGADA") == 17 and sim.weapon_index("PICOTADA") == 18 and sim.weapon_index("PICOTADA_FORTA") == 19 and sim.weapon_index("PERXADA") == 20, "level match has the 21 weapons (the story ones appended)")
	_check(eggs.size() == 3 and ants.size() == 2, "egg_1: 3 eggs vs 2 ants")
	var ok_stats: bool = true
	for e in eggs:
		if e.kind != "EGG" or e.hp != 60 or e.max_hp != 60 or e.r != 10.0 or e.unit == null:
			ok_stats = false
	for a in ants:
		if a.kind != "ANT" or a.hp != 30 or a.r != 9.0 or a.unit == null:
			ok_stats = false
	_check(ok_stats, "eggs 60 HP radius 10, ants 30 HP radius 9")
	_check(eggs[0].name == "Perleta" and eggs[1].name == "Pinyoleta", "eggs carry the level names")
	_check(sim.team_arsenal(0).is_empty() and str(sim.team_arsenal(1)) == "[17]", "egg_1 arsenals: eggs none, ants Bite")
	_check(sim.ammo(0, "BAZOOKA") == 0 and sim.ammo(1, "MOSSEGADA") == -1 and sim.ammo(0, "EMPENTA") == 0, "egg_1 ammo: only the Bite is available")
	_check(sim.active_team == 0 and not sim.is_current_turn_ai() and sim.turn_phase == CombatSim.Phase.TURN_PLAY, "the player opens")
	_check(sim.turn_timer == 25.0 and sim.game_mode == "1P_CPU", "turn time comes from the level")
	_check(sim.rounds_left == 4 and sim.round_number == 1, "rounds_left starts at survive_rounds (round 1)")
	_check(sim.barrels.is_empty() and sim.mines.is_empty() and sim.crates.is_empty() and sim.silk_nests.is_empty() and sim.rovellons.is_empty() and sim.surface_flora.is_empty(), "no hazards without the flag")
	_check(sim.hiding_spots.size() == 4, "egg_1: 4 hiding spots")
	var l2: LevelDef = _level("egg_2")
	var sim2 := _make(l2)
	_check(_team(sim2, 0).size() == 3 and _team(sim2, 1).size() == 4, "egg_2: 3 eggs vs 4 ants")
	_check(str(sim2.team_arsenal(0)) == "[16]" and sim2.ammo(0, "EMPENTA") == -1, "egg_2: eggs get the Shove")
	_check(sim2.hiding_spots.size() == 3 and sim2.rounds_left == 5, "egg_2: 3 spots, 5 rounds")
	for pair in [[sim, "egg_1"], [sim2, "egg_2"]]:
		var s: CombatSim = pair[0]
		var egg_pos := Vector2(s.fighters[0].x, s.fighters[0].y)
		var reachable: bool = true
		for sp in s.hiding_spots:
			reachable = reachable and not s.nav.find_path(egg_pos, sp, false).is_empty()
		for f in s.fighters:
			if f.team == 1:
				reachable = reachable and not s.nav.find_path(Vector2(f.x, f.y), egg_pos, true).is_empty()
		_check(reachable, "%s: the eggs can walk to every spot and every ant can walk to the eggs" % pair[1])
		var good: bool = true
		for sp in s.hiding_spots:
			if sp.y >= s.terrain.water_y - 22.0 or s.terrain.is_solid(sp.x, sp.y) or not s.terrain.is_solid(sp.x, sp.y + 14.0):
				good = false
		_check(good, "%s: hiding spots stand on the surface above the water" % pair[1])
		var ok_pos: bool = true
		for f in s.fighters:
			if f.y + f.r > s.terrain.water_y or s.terrain.is_solid(f.x, f.y):
				ok_pos = false
		_check(ok_pos, "%s: every unit spawns above the water, outside the ground" % pair[1])
		var ex: float = 0.0
		var ax: float = 0.0
		for f in s.fighters:
			if f.team == 0:
				ex += f.x / 3.0
			else:
				ax += f.x / float(_team(s, 1).size())
		_check(ex < ax - 800.0 and ex < SimTables.TERRAIN_W * 0.4, "%s: eggs on the left, ants far on the right" % pair[1])
		var near: bool = false
		var spread: float = 0.0
		var inside: bool = true
		for sp in s.hiding_spots:
			near = near or absf(sp.x - ex) < 330.0
			spread = maxf(spread, absf(sp.x - ex))
			inside = inside and sp.x < ax
		_check(near and inside and spread > 150.0, "%s: some spots near the eggs, the others spread toward the ants" % pair[1])
	var l3 := _level("egg_1").duplicate() as LevelDef
	l3.hazards = true
	l3.supply_drops = true
	var sim3 := _make(l3)
	_check(sim3.barrels.size() > 0 or sim3.mines.size() > 0, "hazards flag brings the hazards back")


func _egg_limits() -> void:
	var sim := _make(_level("egg_2"))
	_run(sim, 1.5)
	var egg: SimFighter = sim.active_fighter
	_check(egg.kind == "EGG" and egg.grounded, "the egg stands on the ground")
	sim.jump_forward()
	sim.jump_backward()
	_run(sim, 0.2)
	_check(egg.grounded and egg.vy == 0.0, "an egg cannot jump or backflip")
	var egg_dx: float = _best_walk(sim, egg)
	var cat := _classic()
	_run(cat, 1.5)
	var cat_dx: float = _best_walk(cat, cat.active_fighter)
	_check(absf(egg_dx - 78.0 * 0.35) < 3.0 and egg_dx < cat_dx, "the egg crawls at 35%% of the walking speed (%.1f px/s; caterpillar %.1f)" % [egg_dx, cat_dx])
	var seg_ok: bool = true
	for f in sim.fighters:
		if f.segs.size() != 6:
			seg_ok = false
	_check(seg_ok, "units keep valid body segments")
	var before: int = sim.round_number
	sim.end_turn()
	_check(sim.turn_phase == CombatSim.Phase.ACTION_WAIT, "end_turn moves TURN_PLAY to ACTION_WAIT")
	_until_turn(sim, 1, 10.0)
	_check(sim.active_team == 1 and sim.round_number == before, "after the pass the ants play")


func _hiding() -> void:
	var sim := _make(_level("egg_2"))
	_run(sim, 1.5)
	var texts: Array[String] = []
	sim.float_text.connect(func(_p: Vector2, t: String, _c: Color, _l: float) -> void: texts.append(t))
	var egg: SimFighter = sim.active_fighter
	var spot: Vector2 = sim.hiding_spots[0]
	_drop_at(egg, spot.x, spot.y + egg.r)
	_run(sim, 1.0)
	_check(egg.grounded and Vector2(egg.x, egg.y).distance_to(spot) <= CombatSim.HIDING_SPOT_RADIUS, "an egg settles within the spot radius")
	_check(not egg.hidden, "an egg is not hidden while it still plays")
	sim.end_turn()
	_check(egg.hidden, "ending the turn on a spot hides the egg")
	_check(texts.any(func(t: String) -> bool: return t.contains("FT_HIDDEN") or t.contains(egg.name)), "hiding shows a floating text")
	var eggs: Array[SimFighter] = _team(sim, 0)
	var other: SimFighter = eggs[0] if eggs[0] != egg else eggs[1]
	_check(not other.hidden, "other eggs are not hidden")
	_until_turn(sim, 1, 10.0)
	# the ant that plays now must ignore the hidden egg as a target
	var ant: SimFighter = sim.active_fighter
	_check(AiCritter._nearest_visible(sim, ant) != egg, "CPU units never target a hidden egg")
	# walking clears hiding
	var sim2 := _make(_level("egg_2"))
	_run(sim2, 1.5)
	var e2: SimFighter = sim2.active_fighter
	e2.hidden = true
	sim2.set_move(1)
	_run(sim2, 0.3)
	sim2.set_move(0)
	_check(not e2.hidden, "walking clears hidden")
	# an egg ending its turn far from any spot does not hide
	var sim3 := _make(_level("egg_2"))
	_run(sim3, 1.5)
	var e3: SimFighter = sim3.active_fighter
	sim3.end_turn()
	_check(not e3.hidden, "an egg far from every spot does not hide")
	# sniffing: an ant ending its turn next to a hidden egg reveals it
	var sim4 := _make(_level("egg_2"))
	_run(sim4, 1.5)
	var sniffs: Array[String] = []
	sim4.float_text.connect(func(_p: Vector2, t: String, _c: Color, _l: float) -> void: sniffs.append(t))
	var hid: SimFighter = sim4.active_fighter
	var sp4: Vector2 = sim4.hiding_spots[0]
	_drop_at(hid, sp4.x, sp4.y + hid.r)
	_run(sim4, 1.0)
	sim4.end_turn()
	_until_turn(sim4, 1, 10.0)
	var ant4: SimFighter = sim4.active_fighter
	_check(hid.hidden, "egg stays hidden into the ants' turn")
	ant4.x = hid.x + 30.0
	ant4.y = hid.y
	sim4.end_turn()
	_check(not hid.hidden, "an ant that ends its move next to a hidden egg sniffs it out")
	_check(sniffs.any(func(t: String) -> bool: return t.contains("FT_SNIFFED") or t.contains(hid.name)), "sniffing shows a floating text")
	# an ant far away does not reveal it
	var sim5 := _make(_level("egg_2"))
	_run(sim5, 1.5)
	var h5: SimFighter = sim5.active_fighter
	var sp5: Vector2 = sim5.hiding_spots[0]
	_drop_at(h5, sp5.x, sp5.y + h5.r)
	_run(sim5, 1.0)
	sim5.end_turn()
	_until_turn(sim5, 1, 10.0)
	sim5.end_turn()
	_check(h5.hidden, "a far ant does not reveal a hidden egg")


func _ant_ai() -> void:
	# ants always end their turn well before the timer, even with every egg hidden or far away
	var sim := _make(_level("egg_2"))
	_run(sim, 1.0)
	var worst: float = 0.0
	var turns: int = 0
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and turns < 8:
		sim.end_turn()
		_until_turn(sim, 1, 10.0)
		var t: float = 0.0
		while sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 1 and t < 40.0:
			sim.step(DT)
			sim.advance_real(DT)
			t += DT
		worst = maxf(worst, t)
		turns += 1
		_until_turn(sim, 0, 20.0)
	_check(worst < 20.0, "ant turns end well before the 25 s timer (worst %.1f s)" % worst)
	# a visible egg in reach gets bitten
	var sim2 := _make(_level("egg_2"))
	_run(sim2, 1.0)
	sim2.end_turn()
	_until_turn(sim2, 1, 10.0)
	var ant: SimFighter = sim2.active_fighter
	var victim: SimFighter = _team(sim2, 0)[0]
	var hp0: int = victim.hp
	_drop_at(victim, ant.x - 22.0, ant.y + ant.r)
	_run(sim2, 0.4)
	var t2: float = 0.0
	while sim2.turn_phase == CombatSim.Phase.TURN_PLAY and sim2.active_team == 1 and t2 < 20.0:
		sim2.step(DT)
		t2 += DT
	_check(victim.hp <= hp0 - 10 or not victim.alive, "an ant bites a visible egg in reach (%d -> %d)" % [hp0, victim.hp])
	# a far visible egg is approached
	var sim3 := _make(_level("egg_1"))
	_run(sim3, 1.0)
	sim3.end_turn()
	_until_turn(sim3, 1, 10.0)
	var ant3: SimFighter = sim3.active_fighter
	var d0: float = absf(_team(sim3, 0)[0].x - ant3.x)
	var x3: float = ant3.x
	var t3: float = 0.0
	while sim3.turn_phase == CombatSim.Phase.TURN_PLAY and sim3.active_team == 1 and t3 < 30.0:
		sim3.step(DT)
		t3 += DT
	_check(absf(ant3.x - x3) > 40.0 and d0 > 100.0, "an ant walks toward the eggs (%.0f px)" % absf(ant3.x - x3))
	# with every egg hidden, the ant searches and still ends its turn
	var sim4 := _make(_level("egg_1"))
	_run(sim4, 1.0)
	var tucked: Array[SimFighter] = _team(sim4, 0)
	for k in tucked.size():
		_drop_at(tucked[k], sim4.hiding_spots[k].x, sim4.hiding_spots[k].y + tucked[k].r)
	_run(sim4, 1.0)
	for e in tucked:
		e.hidden = true
	sim4.end_turn()
	_until_turn(sim4, 1, 10.0)
	var ant4: SimFighter = sim4.active_fighter
	var t4: float = 0.0
	while sim4.turn_phase == CombatSim.Phase.TURN_PLAY and sim4.active_team == 1 and t4 < 30.0:
		sim4.step(DT)
		t4 += DT
	_check(t4 < 12.0 and ant4.alive, "with nothing visible the ant wanders and ends its turn (%.1f s)" % t4)
	# an ant never jumps off into the void on its own: it stays above the water
	_check(_team(sim4, 1).all(func(a: SimFighter) -> bool: return a.alive), "searching ants do not fall into the water")


## Swarm turn: every living ant acts once in each enemy turn, rounds count full rounds, the enemy turn stays short.
func _swarm() -> void:
	var sim := _make(_level("egg_2"))
	var order: Array = []
	# the ants of an enemy turn act together in one critter phase: every unit of the group counts as acting in that turn
	sim.turn_started.connect(func(t: int, f: SimFighter) -> void:
		var acting: Array = [f] if sim.critter_group.is_empty() else sim.critter_group
		for m in acting:
			order.append([t, m.id, sim.round_number, sim.rounds_left]))
	var left_seq: Array[int] = []
	var enemy_start: float = -1.0
	var worst_enemy: float = 0.0
	var clock: float = 0.0
	var prev_team: int = -1
	var guard: float = 0.0
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and guard < 900.0:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
		sim.step(DT)
		sim.advance_real(DT)
		guard += DT
		clock += DT
		if sim.turn_phase != CombatSim.Phase.GAME_OVER and sim.active_team != prev_team:
			if prev_team == 1 and enemy_start >= 0.0:
				worst_enemy = maxf(worst_enemy, clock - enemy_start)
			enemy_start = clock if sim.active_team == 1 else -1.0
			prev_team = sim.active_team
			if sim.active_team == 0 and (left_seq.is_empty() or left_seq[left_seq.size() - 1] != sim.rounds_left):
				left_seq.append(sim.rounds_left)
	var ok: bool = true
	var rounds_seen: int = 1
	var i: int = 0
	while i < order.size():
		if order[i][0] == 0:
			rounds_seen += 1
			i += 1
			continue
		var ids: Array = []
		var rnd: int = order[i][2]
		while i < order.size() and order[i][0] == 1:
			ids.append(order[i][1])
			i += 1
		ids.sort()
		var distinct: bool = true
		for k in range(1, ids.size()):
			distinct = distinct and ids[k] != ids[k - 1]
		if ids.size() != 4 or not distinct or rnd != rounds_seen:
			ok = false
	_check(ok and rounds_seen == 5, "swarm: all 4 ants act once in each of the 5 enemy turns (%d player turns)" % rounds_seen)
	_check(str(left_seq) == "[5, 4, 3, 2, 1]", "swarm: rounds_left counts full rounds (%s)" % str(left_seq))
	_check(worst_enemy < 30.0, "swarm: a 4-ant enemy turn stays under 30 s (worst %.1f s)" % worst_enemy)
	_check(sim.winner == 0 and sim.round_number == 6, "swarm: the player survives 5 full rounds")
	for id in ["egg_1", "egg_2"]:
		var pass_sim := _make(_level(id))
		_play_passing(pass_sim)
		print("INFO  %s pass-only run: %d of 3 eggs survive, winner %d" % [id, pass_sim.team_alive_count(0), pass_sim.winner])
	var cv := _make(_level("egg_1"))
	cv.toggle_convoy()
	_check(cv.procession_convoy_enabled, "convoy key is ignored in story levels")


## The level without ant weapons: the eggs can only pass, so the rounds decide the match.
func _peaceful(id: String, rounds: int) -> LevelDef:
	var lv := _level(id).duplicate() as LevelDef
	lv.enemy_arsenal = {}
	lv.survive_rounds = rounds
	return lv


func _survive_rounds() -> void:
	var sim := _make(_peaceful("egg_1", 3))
	var overs: Array = []
	sim.game_over.connect(func(w: int, s: Dictionary) -> void: overs.append([w, s]))
	var seen_left: Array[int] = [sim.rounds_left]
	var guard: int = 0
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and guard < 40:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
		sim.step(DT)
		sim.advance_real(DT)
		if seen_left[seen_left.size() - 1] != sim.rounds_left:
			seen_left.append(sim.rounds_left)
		guard += 1 if sim.turn_phase == CombatSim.Phase.TURN_DELAY and sim.phase_timer > 1.99 else 0
	_check(overs.size() == 1 and overs[0][0] == 0 and sim.winner == 0, "SURVIVE_ROUNDS: team 0 wins")
	_check(seen_left == Array([3, 2, 1, 0], TYPE_INT, "", null), "rounds_left counts 3, 2, 1 and reaches 0 (%s)" % str(seen_left))
	var st: Dictionary = overs[0][1] if overs.size() > 0 else {}
	_check(st.get("level_id", "") == "egg_1" and st.get("won", false) == true and st.get("survivors", 0) == 3 and st.get("stars", 0) == 3 and st.get("reason", "") == "SURVIVED", "stats: won, 3 survivors, 3 stars, SURVIVED")
	_check(st.get("rounds", 0) == 3 and st.has("map_name_key") and st.has("team_damage"), "stats keep the classic keys and rounds = survive_rounds")
	_check(sim.round_number == 4, "the win comes when round survive_rounds + 1 would start")

	var sim2 := _make(_peaceful("egg_1", 2))
	var o2: Array = []
	sim2.game_over.connect(func(w: int, s: Dictionary) -> void: o2.append([w, s]))
	_team(sim2, 0)[2].alive = false
	_play_passing(sim2)
	var s2: Dictionary = o2[0][1] if o2.size() > 0 else {}
	_check(s2.get("survivors", 0) == 2 and s2.get("stars", 0) == 2 and s2.get("won", false), "2 survivors: 2 stars")

	var sim3 := _make(_peaceful("egg_1", 2))
	var o3: Array = []
	sim3.game_over.connect(func(w: int, s: Dictionary) -> void: o3.append([w, s]))
	_team(sim3, 0)[2].alive = false
	_team(sim3, 0)[1].alive = false
	_play_passing(sim3)
	var s3: Dictionary = o3[0][1] if o3.size() > 0 else {}
	_check(s3.get("survivors", 0) == 1 and s3.get("stars", 0) == 1 and s3.get("won", false), "1 survivor: 1 star")

	var sim4 := _make(_peaceful("egg_1", 5))
	var o4: Array = []
	sim4.game_over.connect(func(w: int, s: Dictionary) -> void: o4.append([w, s]))
	for e in _team(sim4, 0):
		e.alive = false
	_play_passing(sim4)
	var s4: Dictionary = o4[0][1] if o4.size() > 0 else {}
	_check(o4.size() == 1 and o4[0][0] == 1 and s4.get("won", true) == false and s4.get("stars", 9) == 0 and s4.get("reason", "") == "LOST" and s4.get("survivors", 9) == 0, "all eggs lost: LOST, 0 stars")

	var sim5 := _make(_peaceful("egg_1", 5))
	var o5: Array = []
	sim5.game_over.connect(func(w: int, s: Dictionary) -> void: o5.append([w, s]))
	for a in _team(sim5, 1):
		a.alive = false
	_play_passing(sim5)
	var s5: Dictionary = o5[0][1] if o5.size() > 0 else {}
	_check(o5.size() == 1 and o5[0][0] == 0 and s5.get("reason", "") == "ELIMINATED_ENEMY" and s5.get("stars", 0) == 3, "all ants gone: ELIMINATED_ENEMY win")

	var lv := _peaceful("egg_1", 3)
	lv.win_rule = "ELIMINATE"
	var sim6 := _make(lv)
	_check(sim6.rounds_left == -1, "ELIMINATE rule: rounds_left is -1")


## Plays until game over, the eggs only passing.
func _play_passing(sim: CombatSim) -> void:
	var t: float = 0.0
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and t < 600.0:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
		sim.step(DT)
		sim.advance_real(DT)
		t += DT


## Scripted egg: walk toward the nearest free spot, pass when on it.
func _drive_egg(sim: CombatSim) -> void:
	var f: SimFighter = sim.active_fighter
	var target: Vector2 = Vector2.INF
	for s in sim.hiding_spots:
		var taken: bool = false
		for g in sim.fighters:
			if g != f and g.team == 0 and g.alive and Vector2(g.x, g.y).distance_to(s) < 20.0:
				taken = true
		if not taken and (target == Vector2.INF or absf(s.x - f.x) < absf(target.x - f.x)):
			target = s
	if SimStory.on_spot(sim, f) or target == Vector2.INF or absf(target.x - f.x) < 6.0:
		sim.set_move(0)
		sim.end_turn()
	else:
		sim.set_move(1 if target.x > f.x else -1)


func _full_run(id: String) -> void:
	var sim := _make(_level(id))
	var overs: Array = []
	sim.game_over.connect(func(w: int, s: Dictionary) -> void: overs.append([w, s]))
	var hid_seen: bool = false
	var t: float = 0.0
	var counter: Array[int] = [0]
	sim.turn_started.connect(func(_t: int, _f: SimFighter) -> void: counter[0] += 1)
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and t < 900.0:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			_drive_egg(sim)
		sim.step(DT)
		sim.advance_real(DT)
		for f in sim.fighters:
			hid_seen = hid_seen or f.hidden
		t += DT
	_check(sim.turn_phase == CombatSim.Phase.GAME_OVER and overs.size() == 1, "%s: the CPU-driven run finishes (%d turns, %.0f s of sim time)" % [id, counter[0], t])
	var st: Dictionary = overs[0][1] if overs.size() > 0 else {}
	_check(st.has("stars") and st.has("reason") and st.get("level_id", "") == id, "%s: result %s, %d survivors, %d stars, reason %s" % [id, "won" if st.get("won", false) else "lost", st.get("survivors", -1), st.get("stars", -1), st.get("reason", "?")])
	_check(hid_seen, "%s: at least one egg managed to hide" % id)
	var in_water: bool = false
	for f in sim.fighters:
		if f.y > sim.terrain.water_y + 60.0 and f.alive:
			in_water = true
	_check(not in_water, "%s: nobody is stuck below the water" % id)

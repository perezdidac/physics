## Pelussa stage in the sim: larva units, the blue tit (FLYER AI), mixed enemy teams, WAVES, silk web per level, extra arsenal, wind scale
## and CPU-vs-CPU runs of the five larva levels (with the win rates, to judge the difficulty).
##   godot --headless --path . res://tests/TestPelussaSim.tscn
extends Node

const DT: float = 1.0 / 60.0
const LARVA_LEVELS: Array[String] = ["larva_1", "larva_2", "larva_3", "larva_4", "larva_5"]
const RUN_SEEDS: int = 5
const RUN_LIMIT_S: float = 2400.0

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


## The level as it is in the data.
func _real(id: String) -> LevelDef:
	return load("res://data/levels/%s.tres" % id)


## The first-pass version of larva_3/4/5 (large arenas, ELIMINATE / 5 waves, mixed teams, strong wind): the fixtures of the generic rules below
## (mixed swarms, waves, wind scale). The second pass of the levels (docs/story_contracts.md §7) is tested in tests/test_story_rules2.gd.
func _level(id: String) -> LevelDef:
	var lv: LevelDef = _real(id)
	if id != "larva_3" and id != "larva_4" and id != "larva_5":
		return lv
	lv = lv.duplicate() as LevelDef
	var ant: UnitDef = load("res://data/units/ant.tres")
	var tit: UnitDef = load("res://data/units/blue_tit.tres")
	lv.hiding_spots = 0
	lv.mines = 0
	lv.barrels = 0
	lv.tide = false
	match id:
		"larva_3":
			lv.arena_width = 1600.0
			lv.seed = 4343
			lv.survive_rounds = 5
			lv.anthill_x = 2180.0
			lv.anthill_hp = 0
		"larva_4":
			lv.arena_width = 1700.0
			lv.seed = 4426
			lv.win_rule = "ELIMINATE"
			lv.survive_rounds = 0
			lv.enemy_unit = ant
			lv.enemy_count = 3
			lv.enemy_units = [ant, tit]
			lv.enemy_counts = [3, 1]
		"larva_5":
			lv.arena_width = 1700.0
			lv.seed = 4545
			lv.win_rule = "ELIMINATE"
			lv.survive_rounds = 0
			lv.wind_scale = 1.8
			lv.enemy_unit = tit
			lv.enemy_count = 2
			lv.enemy_units = [tit, ant]
			lv.enemy_counts = [2, 2]
			lv.enemy_arsenal = {"MOSSEGADA": -1, "PICOTADA": -1}
	return lv


func _make(level: LevelDef, extra: Dictionary = {}, seed_v: int = -1) -> CombatSim:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.level = level
	cfg.map_idx = level.map_idx
	cfg.seed = level.seed if seed_v < 0 else seed_v
	cfg.game_mode = "1P_CPU"
	cfg.worms_per_team = level.player_names.size()
	cfg.extra_arsenal = extra
	sim.setup(cfg)
	return sim


func _team(sim: CombatSim, team: int) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team == team:
			out.append(f)
	return out


func _kind(sim: CombatSim, team: int, kind: String) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in _team(sim, team):
		if f.kind == kind:
			out.append(f)
	return out


func _run(sim: CombatSim, seconds: float) -> void:
	for i in int(seconds / DT):
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


## Makes the player's units sturdy so a scripted scenario cannot end the match.
func _sturdy(sim: CombatSim) -> void:
	for f in _team(sim, 0):
		f.hp = 9999
		f.max_hp = 9999


func _ready() -> void:
	_units()
	_mixed_teams()
	_swarm_acts_once()
	_bird_attack()
	_bird_knocked_down()
	_waves()
	_waves_win()
	_silk_web()
	_extra_arsenal()
	_extra_arsenal_game_state()
	_wind_scale()
	_unlock_chain()
	_cpu_runs()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _units() -> void:
	var l1: UnitDef = load("res://data/units/larva_l1.tres")
	var l2: UnitDef = load("res://data/units/larva_l2.tres")
	var tit: UnitDef = load("res://data/units/blue_tit.tres")
	_check(l1.max_hp == 45 and l1.radius == 9.0 and is_equal_approx(l1.speed_mult, 0.85) and l1.can_jump and l1.ai == "CATERPILLAR" and not l1.flies, "larva_l1: 45 HP, radius 9, speed 0.85, jumps, caterpillar AI")
	_check(l2.max_hp == 60 and l2.radius == 10.5 and is_equal_approx(l2.speed_mult, 0.9) and l2.can_jump and l2.ai == "CATERPILLAR" and l2.art_scale > l1.art_scale, "larva_l2: 60 HP, radius 10.5, speed 0.9, bigger art than L1")
	_check(tit.id == "BLUE_TIT" and tit.max_hp == 40 and tit.radius == 13.0 and tit.ai == "FLYER" and tit.flies and not tit.can_jump, "blue_tit: 40 HP, radius 13, flies, FLYER AI")
	var sim := _make(_level("larva_4"))
	var pk: WeaponDef = sim.weapons[sim.weapon_index("PICOTADA")]
	_check(pk.type == "MELEE" and pk.max_dmg == 12.0 and pk.reach == 40.0 and pk.story_only and sim.weapon_index("PICOTADA") == 18, "PICOTADA: melee, 12 damage, reach 40, story-only, appended at the end")
	var classic := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = 5
	classic.setup(cfg)
	_check(classic.weapon_index("PICOTADA") == -1 and classic.weapons.size() == 16 and classic.wind_scale == 1.0 and classic.waves_left == -1 and classic.anthill_pos == Vector2.INF, "classic matches do not see PICOTADA, waves or wind scale")
	_check(classic.can_spin_web() and classic.enemies_alive == 4, "classic: the silk web is allowed, enemies_alive counts team 1")
	var kinds_ok: bool = true
	for id in LARVA_LEVELS:
		var lv: LevelDef = _level(id)
		kinds_ok = kinds_ok and lv.mode == "COMBAT" and lv.player_names.size() == 3 and lv.player_unit == (l1 if id in ["larva_1", "larva_2", "larva_3"] else l2) \
			and lv.player_arsenal.has("URTICARIA")
	_check(kinds_ok, "larva levels: COMBAT, 3 larvae (L1 for 1-3, L2 for 4-5), URTICARIA in the arsenal")
	var ant_b: bool = true
	for f in _team(sim, 0):
		ant_b = ant_b and f.kind == "LARVA_L2" and f.hp == 60 and f.r == 10.5 and f.unit == l2 and not f.flying
	_check(ant_b, "larva_4 spawns 3 L2 larvae with their stats")


func _mixed_teams() -> void:
	var sim := _make(_level("larva_4"))
	var ants: Array[SimFighter] = _kind(sim, 1, "ANT")
	var tits: Array[SimFighter] = _kind(sim, 1, "BLUE_TIT")
	_check(ants.size() == 3 and tits.size() == 1 and sim.enemies_alive == 4, "larva_4: 3 ants + 1 blue tit")
	var tit: SimFighter = tits[0]
	var ground: float = sim.terrain.find_surface_y(tit.x, tit.y)
	_check(tit.flying and tit.grounded and tit.hp == 40 and tit.r == 13.0 and tit.perch == Vector2(tit.x, tit.y) and ground - tit.y >= 100.0 and not sim.terrain.is_solid(tit.x, tit.y), "the blue tit hovers at its perch in the air")
	var ants_ok: bool = true
	for a in ants:
		ants_ok = ants_ok and a.hp == 30 and a.r == 9.0 and not a.flying
	_check(ants_ok, "the ants keep their stats and walk")
	var sim2 := _make(_level("larva_5"))
	_check(_kind(sim2, 1, "BLUE_TIT").size() == 2 and _kind(sim2, 1, "ANT").size() == 2, "larva_5: 2 blue tits + 2 ants")
	var reach_ok: bool = true
	var egg := Vector2(sim2.fighters[0].x, sim2.fighters[0].y)
	for a in _kind(sim2, 1, "ANT"):
		reach_ok = reach_ok and not sim2.nav.find_path(Vector2(a.x, a.y), egg, true).is_empty()
	_check(reach_ok, "larva_5: every ant can walk to the larvae")
	var lv: LevelDef = _level("larva_5")
	_check(lv.enemy_roster().size() == 4 and lv.enemy_roster()[0].id == "BLUE_TIT" and _level("larva_1").enemy_roster().size() == 2 and _level("larva_3").enemy_roster().is_empty(), "LevelDef.enemy_roster: mixed, simple and empty teams")
	var tits_hit: bool = sim2.team_arsenal(1).size() == 2 and sim2.ammo(1, "PICOTADA") == -1 and sim2.ammo(1, "MOSSEGADA") == -1 and sim2.ammo(0, "PICOTADA") == 0
	_check(tits_hit, "larva_5: the enemy arsenal is Bite + Peck, the larvae have no peck")


## Every living enemy unit (ants and birds) acts once in each enemy turn.
func _swarm_acts_once() -> void:
	var sim := _make(_level("larva_5"))
	_sturdy(sim)
	var order: Array = []
	# the ants act together in one critter phase (the birds keep their own turns): every unit of the group counts as acting
	sim.turn_started.connect(func(t: int, f: SimFighter) -> void:
		var acting: Array = [f] if sim.critter_group.is_empty() else sim.critter_group
		for m in acting:
			order.append([t, m.id]))
	var enemy_turns: int = 0
	var guard: float = 0.0
	while enemy_turns < 3 and guard < 600.0:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
		sim.step(DT)
		sim.advance_real(DT)
		guard += DT
		var n: int = 0
		for e in order:
			n += 1 if e[0] == 0 else 0
		enemy_turns = n - 1
	var runs: Array = []
	var cur: Array = []
	for e in order:
		if e[0] == 1:
			cur.append(e[1])
		elif not cur.is_empty():
			runs.append(cur)
			cur = []
	var ok: bool = runs.size() >= 3
	for r in runs:
		var ids: Array = r.duplicate()
		ids.sort()
		var distinct: bool = true
		for k in range(1, ids.size()):
			distinct = distinct and ids[k] != ids[k - 1]
		ok = ok and ids.size() == 4 and distinct
	_check(ok, "mixed swarm: all 4 units (2 tits, 2 ants) act once in each of %d enemy turns" % runs.size())


## A tit with a single larva to peck: approach, warn (0.6 s), dive, peck and fly back up to the perch.
func _bird_attack() -> void:
	var sim := _make(_level("larva_5"))
	var victims: Array[SimFighter] = _team(sim, 0)
	var victim: SimFighter = victims[0]
	victims[1].alive = false
	victims[2].alive = false
	var tit: SimFighter = _kind(sim, 1, "BLUE_TIT")[0]
	for f in _team(sim, 1):
		if f != tit:
			f.alive = false
	tit.x = victim.x + 170.0
	tit.y = victim.y - 150.0
	tit.perch = Vector2(tit.x, tit.y)
	tit.flying = true
	tit.grounded = true
	_check(not sim.terrain.is_solid(tit.x, tit.y), "scenario: the tit's perch is free air")
	var hp0: int = victim.hp
	sim.end_turn()
	var states: Array[String] = []
	var warn_frames: int = 0
	var dive_to_peck: bool = false
	var t: float = 0.0
	var started: bool = false
	var min_dist: float = INF
	while t < 40.0 and sim.turn_phase != CombatSim.Phase.GAME_OVER:
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
		if sim.active_fighter == tit and sim.turn_phase == CombatSim.Phase.TURN_PLAY:
			started = true
			if states.is_empty() or states[states.size() - 1] != tit.ai_state:
				states.append(tit.ai_state)
			warn_frames += 1 if tit.ai_state == "warn" else 0
			min_dist = minf(min_dist, Vector2(victim.x - tit.x, victim.y - tit.y).length())
		elif started:
			break
	dive_to_peck = states.has("warn") and states.has("dive") and states.find("warn") < states.find("dive") and states.find("approach") < states.find("warn")
	_check(dive_to_peck, "the tit approaches, warns, dives and returns (%s)" % str(states))
	_check(absf(warn_frames * DT - 0.6) < 0.1, "the warn hover lasts 0.6 s (%.2f s)" % (warn_frames * DT))
	_check(victim.hp <= hp0 - 12 or not victim.alive, "the tit pecks a visible larva (%d -> %d)" % [hp0, victim.hp])
	_check(tit.flying and tit.alive and tit.ai_state == "idle" and Vector2(tit.x, tit.y).distance_to(tit.perch) < 20.0 and tit.y < victim.y - 60.0, "the tit flies back up to its perch after the peck")
	_check(states.size() >= 4 and states[states.size() - 1] == "return", "the last state of the turn is the way back")

	# a hidden larva is not a target: the tit ends its turn at once
	var sim2 := _make(_level("larva_5"))
	for f in _team(sim2, 0):
		f.hidden = true
		sim2.hiding_spots.append(Vector2(f.x, f.y))
	var tit2: SimFighter = _kind(sim2, 1, "BLUE_TIT")[0]
	sim2.end_turn()
	var seen_warn: bool = false
	for i in 1800:
		sim2.step(DT)
		sim2.advance_real(DT)
		if sim2.active_fighter == tit2:
			seen_warn = seen_warn or tit2.ai_state == "warn"
	_check(not seen_warn and tit2.flying, "a tit never dives at hidden larvae")


## An explosion knocks the tit out of the air: it falls with gravity, lands, and flies again in its next turn.
func _bird_knocked_down() -> void:
	var sim := _make(_level("larva_5"))
	_sturdy(sim)
	var victim: SimFighter = _team(sim, 0)[0]
	var tit: SimFighter = _kind(sim, 1, "BLUE_TIT")[0]
	for f in _team(sim, 1):
		if f != tit:
			f.alive = false
	tit.x = victim.x
	tit.y = victim.y - 110.0
	tit.perch = Vector2(tit.x, tit.y)
	tit.flying = true
	tit.grounded = true
	var y0: float = tit.y
	_run(sim, 0.3)
	_check(tit.flying and absf(tit.y - y0) < 1.0, "a hovering tit does not fall")
	SimCombat.trigger_explosion(sim, tit.x, tit.y + 14.0, 40.0, 4.0, 120.0)
	_run(sim, 0.1)
	_check(not tit.flying and not tit.grounded and tit.ai_state == "fall", "an explosion knocks the tit out of the air (fall state)")
	var vy_ok: bool = tit.vy != 0.0
	_run(sim, 4.0)
	_check(vy_ok and tit.grounded and tit.y > y0 + 40.0 and tit.alive and tit.ai_state == "idle" and not tit.flying, "the knocked-back tit falls and lands (y %.0f -> %.0f)" % [y0, tit.y])
	var landed_y: float = tit.y
	sim.end_turn()
	var took_off: bool = false
	var t: float = 0.0
	while t < 40.0 and sim.turn_phase != CombatSim.Phase.GAME_OVER:
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
		if sim.active_fighter == tit and sim.turn_phase == CombatSim.Phase.TURN_PLAY and tit.flying:
			took_off = true
			break
	_run(sim, 1.5)
	_check(took_off and (tit.flying or not tit.alive) and tit.y < landed_y, "the landed tit takes off again in its next turn")

	# over the water it drowns like a caterpillar
	var sim2 := _make(_level("larva_5"))
	var tit2: SimFighter = _kind(sim2, 1, "BLUE_TIT")[0]
	var wx: float = NAN
	var x: float = 400.0
	while x < 2800.0 and is_nan(wx):
		if sim2.terrain.find_surface_y(x, 0.0) > sim2.terrain.water_y + 10.0:
			wx = x
		x += 8.0
	if is_nan(wx):
		_check(true, "no open water column on this map: the tit-drowning check is skipped")
	else:
		tit2.x = wx
		tit2.y = sim2.terrain.water_y - 120.0
		tit2.flying = false
		tit2.grounded = false
		_run(sim2, 5.0)
		_check(not tit2.alive and tit2.hp == 0, "a tit that falls in the water drowns")


func _waves() -> void:
	var lv: LevelDef = _level("larva_3")
	var sim := _make(lv)
	_sturdy(sim)
	_check(lv.win_rule == "WAVES" and lv.wave_size == 2 and lv.survive_rounds == 5, "larva_3: WAVES, 2 ants per wave, 5 rounds")
	_check(sim.waves_left == 5 and sim.enemies_alive == 0 and sim.rounds_left == 5 and sim.anthill_pos != Vector2.INF, "waves_left 5, no ants yet, anthill_pos set")
	var stamp_ok: bool = false
	for st in sim.terrain.stamps:
		stamp_ok = stamp_ok or (st["kind"] == "ANTHILL" and absf(float(st["x"]) - sim.anthill_pos.x) < 1.0)
	var top: Vector2 = sim.anthill_pos
	_check(stamp_ok and sim.terrain.is_solid(top.x, top.y + 6.0) and not sim.terrain.is_solid(top.x, top.y - 6.0) and sim.terrain.is_solid(top.x + 25.0, top.y + 20.0), "the anthill is a solid mound stamped on the ground")
	var waves: Array = []
	sim.wave_spawned.connect(func(w: int, c: int, p: Vector2) -> void: waves.append([w, c, p]))
	var texts: Array[String] = []
	sim.float_text.connect(func(_p: Vector2, tx: String, _c: Color, _l: float) -> void: texts.append(tx))
	_check(sim.active_team == 0 and sim.turn_phase == CombatSim.Phase.TURN_PLAY, "the player opens even with no enemies on the map")
	_run(sim, 1.0)
	_check(sim.turn_phase == CombatSim.Phase.TURN_PLAY, "an empty enemy team does not end the player's turn or the match")
	var totals: Array[int] = []
	var lefts: Array[int] = []
	var guard: float = 0.0
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and guard < 900.0:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
		sim.step(DT)
		sim.advance_real(DT)
		guard += DT
		if waves.size() > totals.size():
			totals.append(_team(sim, 1).size())
			lefts.append(sim.waves_left)
			var near: bool = true
			var fresh: Array[SimFighter] = _team(sim, 1).slice(-2)
			for a in fresh:
				near = near and absf(a.x - sim.anthill_pos.x) < 140.0 and not sim.terrain.is_solid(a.x, a.y) and a.kind == "ANT"
			_check(near, "wave %d: 2 ants stand near the anthill, outside the rock" % waves.size())
	_check(totals == [2, 4, 6, 8, 10], "5 waves of 2 ants (total ants after each wave: %s)" % str(totals))
	_check(lefts == [4, 3, 2, 1, 0] and waves.size() == 5 and waves[0][0] == 1 and waves[0][1] == 2 and waves[4][0] == 5, "waves_left counts down 4..0 and wave_spawned fires 5 times (%s)" % str(lefts))
	var wave_text: String = TranslationServer.translate("FT_WAVE") # the key itself when no translation is loaded
	var wave_head: String = wave_text.split("%")[0]
	_check(texts.any(func(t: String) -> bool: return t.contains("FT_WAVE") or (not wave_head.is_empty() and t.begins_with(wave_head))), "each wave shows a floating text")
	_check(sim.winner == 0 and sim.turn_phase == CombatSim.Phase.GAME_OVER and sim.round_number == 6 and sim.waves_left == 0, "WAVES: surviving the last round wins (round 6 would start)")


func _waves_win() -> void:
	var overs: Array = []
	var sim := _make(_level("larva_3"))
	_sturdy(sim)
	sim.game_over.connect(func(w: int, s: Dictionary) -> void: overs.append([w, s]))
	var guard: float = 0.0
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and guard < 900.0:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			for a in _team(sim, 1):
				if a.alive:
					a.alive = false
			sim.end_turn()
		sim.step(DT)
		sim.advance_real(DT)
		guard += DT
	var st: Dictionary = overs[0][1] if overs.size() > 0 else {}
	_check(overs.size() == 1 and overs[0][0] == 0 and st.get("won", false) and st.get("survivors", 0) == 3 and st.get("stars", 0) == 3, "WAVES: killing every ant still lets the rounds run out and wins")
	_check(st.get("enemies_defeated", -1) == 8 and st.get("reason", "") == "SURVIVED", "stats: enemies_defeated counts the fallen ants (%s; the last wave is still alive), reason %s" % [str(st.get("enemies_defeated")), st.get("reason", "?")])
	# all the waves are out and every ant is dead: early win
	var sim2 := _make(_level("larva_3"))
	_sturdy(sim2)
	sim2.waves_left = 0
	sim2.end_turn()
	_run(sim2, 6.0)
	_check(sim2.turn_phase == CombatSim.Phase.GAME_OVER and sim2.winner == 0, "no waves left and no ants alive: the larvae win at once")
	# the larvae all die: lost
	var sim3 := _make(_level("larva_3"))
	var o3: Array = []
	sim3.game_over.connect(func(w: int, s: Dictionary) -> void: o3.append([w, s]))
	for f in _team(sim3, 0):
		f.alive = false
	_run(sim3, 6.0)
	_check(o3.size() == 1 and o3[0][0] == 1 and o3[0][1].get("reason", "") == "LOST" and o3[0][1].get("enemies_defeated", -1) == 0, "all larvae lost: LOST, 0 enemies defeated")
	# ELIMINATE levels also report enemies_defeated
	var sim4 := _make(_level("larva_1"))
	var o4: Array = []
	sim4.game_over.connect(func(w: int, s: Dictionary) -> void: o4.append([w, s]))
	for a in _team(sim4, 1):
		a.alive = false
	_run(sim4, 6.0)
	_check(o4.size() == 1 and o4[0][0] == 0 and o4[0][1].get("enemies_defeated", -1) == 2 and o4[0][1].get("stars", 0) == 3, "ELIMINATE: both ants down, 2 enemies defeated, 3 stars")


func _silk_web() -> void:
	var s1 := _make(_level("larva_1"))
	_check(not s1.can_spin_web(), "larva_1 does not list SILK_WEB")
	s1.spin_silk_web()
	_check(s1.silk_webs.is_empty(), "larva_1: spin_silk_web does nothing")
	var s2 := _make(_level("larva_2"))
	_check(s2.can_spin_web() and _level("larva_2").has_ability("SILK_WEB"), "larva_2 lists SILK_WEB")
	s2.spin_silk_web()
	_check(s2.silk_webs.size() == 1, "larva_2: the larva spins a web")
	s2.spin_silk_web()
	_check(s2.silk_webs.size() == 1, "larva_2: one web per turn")
	var c := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = 8
	cfg.game_mode = "2P_LOCAL"
	c.setup(cfg)
	c.spin_silk_web()
	_check(c.silk_webs.size() == 1, "classic: the web is always allowed")
	var custom := _level("larva_1").duplicate() as LevelDef
	custom.abilities = ["SILK_WEB"]
	var s3 := _make(custom)
	s3.spin_silk_web()
	_check(s3.silk_webs.size() == 1, "a level that lists SILK_WEB allows it")


func _extra_arsenal() -> void:
	var lv: LevelDef = _level("larva_1")
	var plain := _make(lv)
	_check(plain.team_arsenal(0).size() == 1 and plain.weapons[plain.team_arsenal(0)[0]].id == "URTICARIA" and plain.ammo(0, "URTICARIA") == -1, "larva_1 base arsenal: only URTICARIA, unlimited")
	var sim := _make(lv, {"FUET": -1, "CARQUINYOLI": 2, "URTICARIA": 3})
	var ids: Array[String] = []
	for i in sim.team_arsenal(0):
		ids.append(sim.weapons[i].id)
	_check(ids == ["CARQUINYOLI", "URTICARIA", "FUET"], "extra_arsenal is merged into the player's arsenal in list order (%s)" % str(ids))
	_check(sim.ammo(0, "FUET") == -1 and sim.ammo(0, "CARQUINYOLI") == 2 and sim.ammo(0, "URTICARIA") == -1, "extra ammo: unlimited stays unlimited, 2 carquinyolis")
	_check(sim.team_arsenal(1).size() == 1 and sim.ammo(1, "FUET") == 0, "extra_arsenal does not reach the enemy")
	var l2 := lv.duplicate() as LevelDef
	l2.player_arsenal = {"URTICARIA": 2}
	var sim2 := _make(l2, {"URTICARIA": 3})
	_check(sim2.ammo(0, "URTICARIA") == 5, "finite ammo adds up (2 + 3)")
	_check(sim.ammo_f(0, sim.weapons[sim.selected_weapon_idx].id) > 0.0, "the selected weapon of the first turn has ammo")


func _extra_arsenal_game_state() -> void:
	var saved_path: String = StoryProgress.save_path
	StoryProgress.save_path = "user://test_pelussa_progress.cfg"
	StoryProgress.reset_progress()
	var larva_2: LevelDef = StoryProgress.levels().filter(func(l: LevelDef) -> bool: return l.id == "larva_2")[0]
	var larva_3: LevelDef = StoryProgress.levels().filter(func(l: LevelDef) -> bool: return l.id == "larva_3")[0]
	GameState.story_level = larva_3
	var cfg: MatchConfig = GameState.make_match_config()
	_check(cfg.extra_arsenal.is_empty(), "GameState: nothing unlocked yet, no extra arsenal")
	StoryProgress.record_result({"level_id": "larva_2", "won": true, "stars": 2})
	cfg = GameState.make_match_config()
	_check(cfg.extra_arsenal == {"FUET": -1}, "GameState: winning larva_2 adds FUET to the next levels (%s)" % str(cfg.extra_arsenal))
	var sim := CombatSim.new()
	sim.setup(cfg)
	_check(sim.ammo(0, "FUET") == -1 and sim.ammo(0, "URTICARIA") == -1 and sim.team_arsenal(0).size() == 2, "the sim built from that config lets the larvae use FUET and URTICARIA")
	StoryProgress.record_result({"level_id": "larva_3", "won": true, "stars": 1})
	GameState.story_level = _level("larva_4")
	cfg = GameState.make_match_config()
	_check(cfg.extra_arsenal.has("FUET") and cfg.extra_arsenal.has("CARQUINYOLI") and cfg.extra_arsenal.size() == 2, "GameState: every weapon unlocked so far is merged (%s)" % str(cfg.extra_arsenal.keys()))
	_check(cfg.team_names[1].size() == 4 and cfg.team_names[0].size() == 3 and cfg.level == GameState.story_level, "GameState names the mixed enemy team (4) and the squad (3)")
	var no_unlock := _level("larva_4").duplicate() as LevelDef
	no_unlock.use_unlocked = false
	GameState.story_level = no_unlock
	cfg = GameState.make_match_config()
	_check(cfg.extra_arsenal.is_empty(), "use_unlocked = false: no extra arsenal")
	GameState.story_level = null
	cfg = GameState.make_match_config()
	_check(cfg.extra_arsenal.is_empty() and larva_2 != null, "classic config has no extra arsenal")
	StoryProgress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StoryProgress.save_path))
	StoryProgress.save_path = saved_path
	StoryProgress.load_progress()


func _wind_scale() -> void:
	var base := _level("larva_5").duplicate() as LevelDef
	base.wind_scale = 1.0
	var strong := _level("larva_5").duplicate() as LevelDef
	_check(is_equal_approx(strong.wind_scale, 1.8) and is_equal_approx(_level("larva_1").wind_scale, 1.0), "larva_5 has wind_scale 1.8, the others 1")
	var a := _make(base)
	var b := _make(strong)
	_check(a.wind_scale == 1.0 and b.wind_scale == 1.8 and is_equal_approx(a.wind_float, b.wind_float), "same seed, same raw wind")
	_check(absi(b.wind - roundi(a.wind_float * 1.8)) <= 1 and absi(a.wind - roundi(a.wind_float)) <= 1, "the turn wind is multiplied by wind_scale (%d vs %d)" % [a.wind, b.wind])
	var max_a: int = 0
	var max_b: int = 0
	for i in 1200:
		a.step(DT)
		b.step(DT)
		max_a = maxi(max_a, absi(a.wind))
		max_b = maxi(max_b, absi(b.wind))
	_check(max_b > max_a and max_b <= 190 and max_b >= int(max_a * 1.5), "during the turn the wind stays scaled (peak %d vs %d)" % [max_b, max_a])


func _unlock_chain() -> void:
	var all: Array[LevelDef] = StoryProgress.levels()
	var ids: Array[String] = []
	for l in all:
		ids.append(l.id)
	_check(ids.slice(0, 5) == ["egg_1", "egg_2", "egg_3", "egg_4", "egg_boss"] and ids.slice(5, 10) == LARVA_LEVELS, "level_list: the egg stage, then larva_1..5 (%s)" % str(ids))
	var saved_path: String = StoryProgress.save_path
	StoryProgress.save_path = "user://test_pelussa_chain.cfg"
	StoryProgress.reset_progress()
	var by_id: Dictionary = {}
	for l in all:
		by_id[l.id] = l
	_check(not StoryProgress.is_unlocked(by_id["larva_1"]), "larva_1 is locked until egg_boss is won")
	StoryProgress.record_result({"level_id": "egg_boss", "won": true, "stars": 1})
	_check(StoryProgress.is_unlocked(by_id["larva_1"]) and not StoryProgress.is_unlocked(by_id["larva_2"]), "winning egg_boss opens larva_1 only")
	for i in range(1, 5):
		StoryProgress.record_result({"level_id": "larva_%d" % i, "won": true, "stars": 1})
		_check(StoryProgress.is_unlocked(by_id["larva_%d" % (i + 1)]), "winning larva_%d opens larva_%d" % [i, i + 1])
	_check(StoryProgress.unlocked_weapons() == ["FUET", "CARQUINYOLI", "BAT"], "the levels unlock FUET, CARQUINYOLI and BAT in order (%s)" % str(StoryProgress.unlocked_weapons()))
	StoryProgress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StoryProgress.save_path))
	StoryProgress.save_path = saved_path
	StoryProgress.load_progress()


## Seeds (the level's own first) whose setup is playable: every enemy can walk to the larvae and, for WAVES, the ants from the anthill too.
func _good_seeds(level: LevelDef, count: int) -> Array[int]:
	var out: Array[int] = []
	var sd: int = level.seed
	while out.size() < count and sd < level.seed + 400:
		var sim := _make(level, {}, sd)
		var egg := Vector2(sim.fighters[0].x, sim.fighters[0].y)
		var ok: bool = true
		for f in _team(sim, 1):
			var from := Vector2(f.x, f.perch.y + SimStory.PERCH_HEIGHT - f.r) if f.flying else Vector2(f.x, f.y)
			ok = ok and not sim.nav.find_path(from, egg, true).is_empty()
		if sim.anthill_pos != Vector2.INF:
			ok = ok and not sim.nav.find_path(Vector2(sim.anthill_pos.x + SimStory.WAVE_GAP, sim.anthill_pos.y + TerrainSim.ANTHILL_H - 10.0), egg, true).is_empty()
		if ok or sd == level.seed:
			out.append(sd)
		sd += 1
	return out


## One CPU-vs-CPU match (the larvae play with the caterpillar AI): returns {done, won, survivors, enemies, rounds, seconds, errors}.
func _cpu_match(level: LevelDef, seed_v: int) -> Dictionary:
	var sim := _make(level, {}, seed_v)
	sim.game_mode = "CPU_CPU"
	var res: Dictionary = {}
	sim.game_over.connect(func(w: int, s: Dictionary) -> void:
		res.merge(s, true)
		res["winner"] = w)
	var t: float = 0.0
	var turns: Array[int] = [0]
	sim.turn_started.connect(func(_t: int, _f: SimFighter) -> void: turns[0] += 1)
	var bad_state: bool = false
	var frame: int = 0
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and t < RUN_LIMIT_S:
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
		frame += 1
		if frame % 300 == 0:
			for f in sim.fighters:
				bad_state = bad_state or is_nan(f.x) or is_nan(f.y) or (f.alive and f.y > sim.terrain.water_y + 60.0)
	res["done"] = sim.turn_phase == CombatSim.Phase.GAME_OVER and not res.is_empty()
	res["seconds"] = t
	res["turns"] = turns[0]
	res["bad_state"] = bad_state
	res["rounds_played"] = sim.round_number
	return res


func _cpu_runs() -> void:
	for id in LARVA_LEVELS:
		var level: LevelDef = _real(id)
		var seeds: Array[int] = _good_seeds(level, RUN_SEEDS)
		var wins: int = 0
		var finished: int = 0
		var clean: int = 0
		var surv: int = 0
		var defeated: int = 0
		var turns: int = 0
		var started: int = Time.get_ticks_msec()
		for sd in seeds:
			var r: Dictionary = _cpu_match(level, sd)
			finished += 1 if r["done"] else 0
			clean += 0 if r["bad_state"] else 1
			wins += 1 if r.get("won", false) else 0
			surv += int(r.get("survivors", 0))
			defeated += int(r.get("enemies_defeated", 0))
			turns += int(r["turns"])
		_check(seeds.size() == RUN_SEEDS and finished == RUN_SEEDS and clean == RUN_SEEDS, "%s: %d CPU-vs-CPU runs end without errors (seeds %s)" % [id, finished, str(seeds)])
		print("INFO  %s: caterpillar AI wins %d of %d; survivors avg %.1f of 3, enemies defeated avg %.1f of %d, %.0f turns avg (%.1f s)" % [
			id, wins, seeds.size(), surv / float(seeds.size()), defeated / float(seeds.size()), level.enemy_roster().size() if id != "larva_3" else level.survive_rounds * level.wave_size, turns / float(seeds.size()), (Time.get_ticks_msec() - started) / 1000.0])

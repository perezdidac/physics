## Turn state machine: full cycle, tide, supply drops, game over, wind, setup invariants.
##   godot --headless --path . res://tests/TestSimTurns.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _make(mode: String, worms: int = 3, seed_v: int = 99) -> CombatSim:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = seed_v
	cfg.game_mode = mode
	cfg.worms_per_team = worms
	cfg.map_idx = 3
	sim.setup(cfg)
	return sim


func _ready() -> void:
	_setup_invariants()
	_turn_cycle()
	_tide_and_drops()
	_game_over()
	_wind()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _setup_invariants() -> void:
	var sim := _make("2P_LOCAL", 4)
	_check(sim.fighters.size() == 8 and sim.team_alive_count(0) == 4 and sim.team_alive_count(1) == 4, "8 fighters, 4 per team")
	_check(sim.fighters[0].team == 0 and sim.fighters[1].team == 1 and sim.fighters[0].facing == 1 and sim.fighters[1].facing == -1, "fighters interleave and face each other")
	_check(sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.turn_timer == 30.0 and sim.active_fighter != null, "first turn starts in TURN_PLAY with 30 s")
	_check(sim.ammo(0, "BAZOOKA") == -1 and sim.ammo(1, "HOLY") == 1 and sim.ammo(0, "CLUSTER") == 3, "team ammo from the weapon table")
	var ok_pos: bool = true
	for f in sim.fighters:
		if f.y + f.r > sim.terrain.water_y or sim.terrain.is_solid(f.x, f.y):
			ok_pos = false
	_check(ok_pos, "fighters spawn above the water, outside the ground")
	var sim1 := _make("1P_CPU", 2)
	_check(sim1.active_team == 0 and not sim1.is_current_turn_ai(), "1P_CPU: the human (team 0) opens")
	var again := _make("2P_LOCAL", 4)
	_check(again.fighters[0].x == sim.fighters[0].x, "same seed gives the same match")


func _turn_cycle() -> void:
	var sim := _make("2P_LOCAL", 2)
	var first_team: int = sim.active_team
	var seen: Array[int] = [sim.turn_phase]
	var started: Array[int] = []
	sim.turn_started.connect(func(t: int, _f: SimFighter) -> void: started.append(t))
	# fire a bazooka straight up-left into the ground close by
	_check(sim.select_weapon(0), "weapon 0 selectable")
	sim.begin_charge_or_fire()
	_check(sim.is_charging and sim.charge_power == 0.08, "charging starts at 0.08")
	sim.step(0.1)
	_check(sim.charge_power > 0.15 and sim.charge_power < 0.2, "charge grows 0.92/s")
	sim.release_charge()
	_check(sim.turn_phase == CombatSim.Phase.ACTION_WAIT and sim.projectiles.size() == 1, "firing moves to ACTION_WAIT with a projectile")
	_check(sim.ammo(first_team, "BAZOOKA") == -1, "infinite ammo stays infinite")
	var guard: int = 0
	while sim.turn_phase != CombatSim.Phase.TURN_PLAY and guard < 3000:
		sim.step(1.0 / 60.0)
		if seen[seen.size() - 1] != sim.turn_phase:
			seen.append(sim.turn_phase)
		guard += 1
	_check(guard < 3000, "turn cycle completes")
	_check(seen == [CombatSim.Phase.TURN_PLAY, CombatSim.Phase.ACTION_WAIT, CombatSim.Phase.TURN_DELAY, CombatSim.Phase.TURN_PLAY],
		"phase order TURN_PLAY -> ACTION_WAIT -> TURN_DELAY -> TURN_PLAY (%s)" % str(seen))
	_check(sim.active_team == 1 - first_team and started == [1 - first_team], "the other team plays next")
	_check(sim.turn_timer == 30.0 and not sim.has_acted_or_moved_this_turn, "timers reset")
	# Time out: no action for 30 s moves on as well
	var t_before: int = sim.active_team
	for i in 31 * 60:
		sim.step(1.0 / 60.0)
	_check(sim.turn_phase != CombatSim.Phase.TURN_PLAY or sim.active_team != t_before, "turn timer expiry ends the turn")
	# Retreat: dynamite
	var sim2 := _make("2P_LOCAL", 2, 5)
	sim2.team_ammo[sim2.active_team]["DYNAMITE"] = 2.0
	_check(sim2.select_weapon(sim2.weapon_index("DYNAMITE")), "dynamite selectable")
	sim2.begin_charge_or_fire()
	_check(sim2.turn_phase == CombatSim.Phase.RETREAT and sim2.phase_timer == 4.0, "dynamite starts RETREAT 4 s")
	var jetted: int = sim2.weapon_index("JETPACK")
	_check(jetted == 11, "weapon index lookup")


func _tide_and_drops() -> void:
	var sim := _make("2P_LOCAL", 2, 7)
	sim.round_number = 9
	sim.active_team = 1
	var water0: float = sim.terrain.water_y
	SimTurns.start_next_turn(sim)
	_check(sim.round_number == 10 and sim.terrain.water_y == water0 - 14.0, "round 10 raises the tide by 14 (%.0f)" % sim.terrain.water_y)
	for i in 40:
		SimTurns.start_next_turn(sim)
	_check(sim.terrain.water_y == 448.0, "tide stops at 448 (%.0f)" % sim.terrain.water_y)
	var sim2 := _make("2P_LOCAL", 2, 8)
	var drops: int = 0
	for i in 200:
		sim2.crates.clear()
		SimTurns.start_next_turn(sim2)
		if sim2.crates.size() > 0:
			drops += 1
	_check(drops > 60 and drops < 140, "supply drops appear on roughly 48%% of turns (%d/200)" % drops)


func _game_over() -> void:
	var sim := _make("2P_LOCAL", 2, 11)
	var got: Array = []
	sim.game_over.connect(func(w: int, stats: Dictionary) -> void: got.append([w, stats]))
	for f in sim.fighters:
		if f.team == 1:
			f.alive = false
	SimTurns.start_next_turn(sim)
	_check(sim.turn_phase == CombatSim.Phase.GAME_OVER and sim.winner == 0, "team 1 wiped out: team 0 wins")
	_check(got.size() == 1 and got[0][0] == 0 and got[0][1].has("mvp_name"), "game_over signal with stats")
	var sim2 := _make("2P_LOCAL", 2, 12)
	for f in sim2.fighters:
		f.alive = false
	SimTurns.start_next_turn(sim2)
	_check(sim2.winner == -1 and sim2.turn_phase == CombatSim.Phase.GAME_OVER, "everybody dead: draw")
	# Detection through the per-frame FSM (a drowning fighter does not count)
	var sim3 := _make("2P_LOCAL", 1, 13)
	for f in sim3.fighters:
		if f.team == 0:
			f.drowning = true
	sim3.step(1.0 / 60.0)
	_check(sim3.turn_phase == CombatSim.Phase.ACTION_WAIT, "no alive fighters in a team forces ACTION_WAIT")
	for i in 600:
		sim3.step(1.0 / 60.0)
	_check(sim3.turn_phase == CombatSim.Phase.GAME_OVER or sim3.winner != -2, "the match ends after the delay")


func _wind() -> void:
	var sim := _make("2P_LOCAL", 2, 21)
	var ok: bool = true
	for i in 100:
		SimTurns.randomize_wind(sim)
		if absi(sim.wind) > 85 or sim.wind_target < -100.0 or sim.wind_target > 100.0:
			ok = false
	_check(ok, "randomize_wind stays inside its ranges")
	var hud_count: Array[int] = [0, 0]
	sim.hud_changed.connect(func() -> void: hud_count[0] += 1)
	sim.wind_changed.connect(func() -> void: hud_count[1] += 1)
	for i in 60:
		SimTurns.update_dynamic_wind(sim, 1.0 / 60.0)
	_check(hud_count[0] == 0 and hud_count[1] == 60, "wind updates emit wind_changed, not hud_changed (%d/%d)" % [hud_count[0], hud_count[1]])
	var hi: int = 0
	for i in 3000:
		sim.step(1.0 / 60.0)
		hi = maxi(hi, absi(sim.wind))
		if absi(sim.wind) > 100:
			ok = false
	_check(ok and hi > 0, "dynamic wind stays within +-100 (max %d)" % hi)
	var sim2 := _make("2P_LOCAL", 2, 22)
	sim2.playing = false
	var w0: int = sim2.wind
	for i in 600:
		sim2.step(1.0 / 60.0)
	_check(sim2.wind == w0, "wind frozen while not PLAYING")

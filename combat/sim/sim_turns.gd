## Turn state machine (JS startNextTurn + the per-frame FSM of main.js) and wind.
class_name SimTurns
extends RefCounted


## JS randomizeWind: fresh wind at every turn start.
static func randomize_wind(sim: CombatSim) -> void:
	sim.wind_float = (sim.rand() * 2.0 - 1.0) * 85.0
	sim.wind_target = SimMath.clamp_js(sim.wind_float + (sim.rand() - 0.5) * 65.0, -100.0, 100.0)
	sim.wind_gust_timer = 3.6 + sim.rand() * 2.8
	sim.wind = int(SimMath.round_js(sim.wind_float))
	sim.wind_changed.emit()


## JS updateDynamicWind (the cloud/ribbon/bird drift is view-only).
static func update_dynamic_wind(sim: CombatSim, dt: float) -> void:
	if sim.wind_gust_flash > 0.0:
		sim.wind_gust_flash = maxf(0.0, sim.wind_gust_flash - dt * 1.8)
	var ph: int = sim.turn_phase
	if sim.playing and (ph == CombatSim.Phase.TURN_PLAY or ph == CombatSim.Phase.RETREAT or ph == CombatSim.Phase.ACTION_WAIT):
		sim.wind_gust_timer -= dt
		if sim.wind_gust_timer <= 0.0:
			var strong: bool = sim.rand() < 0.28
			if strong:
				var dir_v: float = 1.0 if sim.rand() < 0.5 else -1.0
				sim.wind_target = SimMath.clamp_js(dir_v * (62.0 + sim.rand() * 38.0), -100.0, 100.0)
				sim.wind_gust_timer = 4.8 + sim.rand() * 3.0
				sim.wind_gust_flash = 1.0
				if ph == CombatSim.Phase.TURN_PLAY and sim.active_fighter != null:
					sim.play("wind_gust")
					if dir_v > 0.0:
						sim.ftext(sim.active_fighter.x, sim.active_fighter.y - 54.0, "FT_GUST_RIGHT", Palette.FT_GUST_RIGHT, 1.55)
					else:
						sim.ftext(sim.active_fighter.x, sim.active_fighter.y - 54.0, "FT_GUST_LEFT", Palette.FT_GUST_LEFT, 1.55)
			else:
				sim.wind_target = SimMath.clamp_js(sim.wind_target + (sim.rand() - 0.5) * 78.0, -96.0, 96.0)
				sim.wind_gust_timer = 3.2 + sim.rand() * 2.8
		var gust_osc: float = sin(sim.t_now * 1.75) * 5.5 + cos(sim.t_now * 0.92) * 3.5
		sim.wind_float = lerpf(sim.wind_float, sim.wind_target, minf(1.0, dt * 0.62))
		sim.wind = int(SimMath.round_js(SimMath.clamp_js(sim.wind_float + gust_osc, -100.0, 100.0)))
	sim.wind_changed.emit()


## JS startNextTurn.
static func start_next_turn(sim: CombatSim) -> void:
	var t0_alive: Array[SimFighter] = []
	var t1_alive: Array[SimFighter] = []
	for f in sim.fighters:
		if f.alive and not f.drowning:
			if f.team == 0:
				t0_alive.append(f)
			else:
				t1_alive.append(f)

	if t0_alive.is_empty() or t1_alive.is_empty():
		sim.turn_phase = CombatSim.Phase.GAME_OVER
		var winner: int = -1
		if t0_alive.size() > 0:
			winner = 0
		elif t1_alive.size() > 0:
			winner = 1
		sim.winner = winner
		sim.play("victory")
		sim.game_over.emit(winner, make_game_stats(sim))
		sim.hud()
		return

	sim.active_team = 1 - sim.active_team
	if sim.active_team == 0:
		sim.round_number += 1

	if sim.round_number > 1 and sim.rand() < 0.48 and sim.crates.size() < 3:
		SimSetup.spawn_supply_drop(sim)

	if sim.round_number >= 10 and sim.terrain.water_y > 460.0:
		sim.terrain.water_y -= 14.0
		var tx_pos: float = sim.active_fighter.x if sim.active_fighter != null else SimTables.TERRAIN_W * 0.5
		sim.ftext(tx_pos, sim.terrain.water_y - 30.0, "FT_TIDE", Palette.FT_RED, 2.2)

	var team_alive: Array[SimFighter] = t0_alive if sim.active_team == 0 else t1_alive
	var pick_idx: int = sim.team_turn_idx[sim.active_team] % team_alive.size()
	sim.team_turn_idx[sim.active_team] += 1
	sim.active_fighter = team_alive[pick_idx]
	sim.active_fighter.jet_fuel = 0.0
	sim.silk_web_used_this_turn = false

	if sim.active_fighter.urticating_ticks > 0:
		sim.active_fighter.urticating_ticks -= 1
		sim.play("worm_voice", {"kind": "ITCH"})
		SimCombat.damage_fighter(sim, sim.active_fighter, 8, "DMG_ITCH")
		SimCombat.spawn_hairs(sim, sim.active_fighter.x, sim.active_fighter.y - 6.0, 14)
		if not sim.active_fighter.alive:
			sim.active_team = 1 - sim.active_team
			start_next_turn(sim)
			return

	if sim.rand() < 0.65:
		sim.taunt(sim.active_fighter, "TURN", 2.2)

	var cur: SimFighter = sim.active_fighter
	sim.turn_phase = CombatSim.Phase.TURN_PLAY
	sim.turn_timer = 30.0
	sim.last_turn_tick_sec = 30
	sim.has_acted_or_moved_this_turn = false
	sim.action_wait_timer = 0.0
	sim.shotgun_shots_left = 1
	sim.is_charging = false
	sim.charge_power = 0.0
	sim.ai_plan = {}
	sim.impact_tracked_worm = null

	sim.aim_pitch = cur.last_aim_pitch
	sim.sync_aim_angle_from_pitch()
	sim.mouse_world = Vector2(
		SimMath.clamp_js(cur.x + cur.facing * 260.0, 200.0, SimTables.TERRAIN_W - 200.0),
		maxf(180.0, cur.y - 95.0))

	sim.selected_weapon_idx = sim.team_selected_weapon_idx[sim.active_team]
	if sim.ammo_f(sim.active_team, sim.weapons[sim.selected_weapon_idx].id) <= 0.0:
		sim.selected_weapon_idx = 0
		sim.team_selected_weapon_idx[sim.active_team] = 0

	randomize_wind(sim)
	sim.hud()
	sim.turn_started.emit(sim.active_team, sim.active_fighter)


## Stats dictionary for the game_over signal (victory modal data).
static func make_game_stats(sim: CombatSim) -> Dictionary:
	var mvp: SimFighter = sim.fighters[0] if sim.fighters.size() > 0 else null
	for f in sim.fighters:
		if f.dmg_dealt > (mvp.dmg_dealt if mvp != null else -1):
			mvp = f
	return {
		"map_name_key": sim.terrain.map.name_key,
		"rounds": sim.round_number,
		"team_damage": [sim.team_damage_dealt[0], sim.team_damage_dealt[1]],
		"mvp_name": mvp.name if mvp != null else "",
		"mvp_damage": mvp.dmg_dealt if mvp != null else 0,
		"mvp_team": mvp.team if mvp != null else -1,
	}


## The per-frame turn state machine of main.js (runs after the physics step).
static func update_turn_fsm(sim: CombatSim, dt: float) -> void:
	var t0_count: int = sim.team_alive_count(0)
	var t1_count: int = sim.team_alive_count(1)
	var af: SimFighter = sim.active_fighter
	match sim.turn_phase:
		CombatSim.Phase.TURN_PLAY:
			sim.action_wait_timer = 0.0
			if not sim.rotate_prompt_open:
				sim.turn_timer -= dt
			var ceil_sec: int = maxi(0, int(ceilf(sim.turn_timer)))
			if ceil_sec <= 5 and ceil_sec > 0 and ceil_sec < sim.last_turn_tick_sec:
				sim.last_turn_tick_sec = ceil_sec
				sim.play("tick")
			if sim.turn_timer <= 0.0 or af == null or not af.alive or af.drowning or t0_count == 0 or t1_count == 0:
				sim.is_charging = false
				sim.turn_phase = CombatSim.Phase.ACTION_WAIT
		CombatSim.Phase.RETREAT:
			sim.action_wait_timer = 0.0
			sim.phase_timer -= dt
			if sim.phase_timer <= 0.0 or af == null or not af.alive or af.drowning or t0_count == 0 or t1_count == 0:
				sim.turn_phase = CombatSim.Phase.ACTION_WAIT
		CombatSim.Phase.ACTION_WAIT:
			sim.action_wait_timer += dt
			var any_moving: bool = false
			for f in sim.fighters:
				if f.alive and (f.drowning or not f.grounded or f.sliding or f.spoon_timer > 0.0 or f.drill_timer > 0.0 or not f.grapple.is_empty()):
					any_moving = true
					break
			var any_armed_mine: bool = false
			for m in sim.mines:
				if m.triggered:
					any_armed_mine = true
					break
			var nothing_flying: bool = sim.projectiles.is_empty() and sim.airstrike_planes.is_empty()
			var wait_timeout: bool = (nothing_flying and sim.action_wait_timer > 3.6) or sim.action_wait_timer > 6.2
			if (nothing_flying and not any_moving and not any_armed_mine) or wait_timeout:
				if wait_timeout:
					sim.projectiles.clear()
					sim.airstrike_planes.clear()
					for f in sim.fighters:
						if f.alive and not f.drowning:
							f.vx = 0.0
							f.vy = 0.0
							f.sliding = false
							f.spoon_timer = 0.0
							f.drill_timer = 0.0
							f.grapple = {}
							f.grounded = true
				sim.action_wait_timer = 0.0
				sim.turn_phase = CombatSim.Phase.TURN_DELAY
				sim.phase_timer = 2.0
		CombatSim.Phase.TURN_DELAY:
			sim.phase_timer -= dt
			if sim.phase_timer <= 0.0:
				start_next_turn(sim)

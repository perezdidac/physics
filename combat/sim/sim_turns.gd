## Turn state machine (JS startNextTurn + the per-frame FSM of main.js) and wind.
class_name SimTurns
extends RefCounted


## Pixels the tide raises the water per round.
const TIDE_STEP: float = 14.0


## JS randomizeWind: fresh wind at every turn start.
static func randomize_wind(sim: CombatSim) -> void:
	sim.wind_float = (sim.rand() * 2.0 - 1.0) * 85.0
	sim.wind_target = SimMath.clamp_js(sim.wind_float + (sim.rand() - 0.5) * 65.0, -100.0, 100.0)
	sim.wind_gust_timer = 3.6 + sim.rand() * 2.8
	sim.wind = int(SimMath.round_js(sim.wind_float * sim.wind_scale))
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
		sim.wind = int(SimMath.round_js(SimMath.clamp_js(sim.wind_float + gust_osc, -100.0, 100.0) * sim.wind_scale))
	sim.wind_changed.emit()


## JS startNextTurn.
static func start_next_turn(sim: CombatSim) -> void:
	SimStory.on_turn_end(sim)
	sim.critter_group = []
	sim.critter_plans = {}
	sim.critter_acting = []
	var t0_alive: Array[SimFighter] = []
	var t1_alive: Array[SimFighter] = []
	for f in sim.fighters:
		if f.alive and not f.drowning:
			if f.team == 0:
				t0_alive.append(f)
			else:
				t1_alive.append(f)

	if _decided(sim, t0_alive, t1_alive):
		return
	if SimGoals.on_turn_start(sim):
		return

	var swarm_next: bool = SimStory.swarm_continues(sim)
	if not swarm_next:
		sim.active_team = 1 - sim.active_team
		if sim.active_team == 1 and t1_alive.is_empty() and SimConvoy.active(sim):
			sim.active_team = 0  # nobody left to play the enemy turn of a procession
		if sim.active_team == 0:
			sim.round_number += 1
			if sim.level != null and SimStory.begin_round(sim):
				return
			if sim.level != null:
				_tide_rises(sim)  # story levels: once per round (classic matches: every turn, as in the JS)
			SimBolso.pole_round_start(sim)
			if sim.round_number > 1:
				SimSpores.drift(sim)
		if sim.active_team == 1 and SimBolso.pole_strike(sim):
			t0_alive = _alive(sim, 0)
			if _decided(sim, t0_alive, t1_alive):
				return
		if sim.active_team == 1 and SimStory.spawn_wave(sim):
			t1_alive = _alive(sim, 1)
		if sim.active_team == 1 and SimStory.is_swarm(sim):
			sim.swarm_queue = []
			for f in t1_alive:
				if AiCharger.acts_now(sim, f):
					sim.swarm_queue.append(f.id)
			SimBoss.begin_enemy_turn(sim)

	if sim.round_number > 1 and (sim.level == null or sim.level.supply_drops) and sim.rand() < 0.48 and sim.crates.size() < 3:
		SimSetup.spawn_supply_drop(sim)

	if sim.level == null:
		_tide_rises(sim)

	var team_alive: Array[SimFighter] = t0_alive if sim.active_team == 0 else t1_alive
	var swarm_fighter: SimFighter = SimStory.pop_swarm(sim)
	if swarm_fighter != null:
		sim.active_fighter = swarm_fighter
		if AiCritter.begin_group(sim, swarm_fighter):
			_group_turn_start_effects(sim)
			swarm_fighter = sim.active_fighter
	elif sim.active_team == 0 and SimConvoy.active(sim):
		sim.active_fighter = SimConvoy.leader(sim)  # only the leader of a procession plays
		SimConvoy.on_player_turn(sim)
	else:
		var pick_idx: int = sim.team_turn_idx[sim.active_team] % team_alive.size()
		sim.team_turn_idx[sim.active_team] += 1
		sim.active_fighter = team_alive[pick_idx]
	sim.active_fighter.jet_fuel = 0.0
	sim.silk_web_used_this_turn = false
	sim.silk_webs_spun = 0

	if sim.active_fighter.urticating_ticks > 0:
		sim.active_fighter.urticating_ticks -= 1
		sim.play("worm_voice", {"kind": "ITCH"})
		SimCombat.damage_fighter(sim, sim.active_fighter, 8, "DMG_ITCH")
		SimCombat.spawn_hairs(sim, sim.active_fighter.x, sim.active_fighter.y - 6.0, 14)
	SimBolso.on_turn_start(sim, sim.active_fighter)
	if sim.active_fighter.alive:
		SimStatus.tick_turn_start(sim, sim.active_fighter)
	if sim.active_fighter.alive:
		SimSpores.on_turn_start(sim)
	if sim.critter_group.size() >= 2 and not sim.active_fighter.alive:
		AiCritter.refresh_leader(sim)  # the first unit fell to its own start-of-turn effect: the next one leads
	if not sim.active_fighter.alive:
		sim.active_team = 1 - sim.active_team
		start_next_turn(sim)
		return

	if sim.rand() < 0.65:
		sim.taunt(sim.active_fighter, "TURN", 2.2)

	var cur: SimFighter = sim.active_fighter
	sim.turn_phase = CombatSim.Phase.TURN_PLAY
	sim.sub_turn_time = sim.turn_time if swarm_fighter == null else minf(sim.turn_time, SimBoss.swarm_time(sim, swarm_fighter))
	sim.turn_timer = sim.sub_turn_time
	sim.last_turn_tick_sec = int(ceilf(sim.sub_turn_time))
	sim.turn_end_handled = false
	sim.has_acted_or_moved_this_turn = false
	sim.action_wait_timer = 0.0
	sim.shotgun_shots_left = 1
	sim.is_charging = false
	sim.charge_power = 0.0
	sim.ai_plan = {} if sim.critter_group.is_empty() else sim.critter_plans[sim.active_fighter.id]
	sim.impact_tracked_worm = null

	sim.aim_pitch = cur.last_aim_pitch
	sim.sync_aim_angle_from_pitch()
	sim.mouse_world = Vector2(
		sim.terrain.clamp_hard(cur.x + cur.facing * 260.0, 200.0),
		maxf(180.0, cur.y - 95.0))

	sim.selected_weapon_idx = sim.team_selected_weapon_idx[sim.active_team]
	if sim.ammo_f(sim.active_team, sim.weapons[sim.selected_weapon_idx].id) <= 0.0:
		sim.selected_weapon_idx = SimStory.first_armed_weapon(sim, sim.active_team)
		sim.team_selected_weapon_idx[sim.active_team] = sim.selected_weapon_idx

	randomize_wind(sim)
	sim.hud()
	sim.turn_started.emit(sim.active_team, sim.active_fighter)


## Start-of-turn effects (itching, statuses) of the critters of a critter phase other than the first one (it gets them with the normal code).
static func _group_turn_start_effects(sim: CombatSim) -> void:
	for m in sim.critter_group:
		if m == sim.critter_group[0]:
			continue
		if m.urticating_ticks > 0:
			m.urticating_ticks -= 1
			SimCombat.damage_fighter(sim, m, 8, "DMG_ITCH")
		if m.alive:
			SimStatus.tick_turn_start(sim, m)


## The water rises 14 px at the start of every round from `tide_round` on (once per round, however many enemy turns or critter phases it has).
static func _tide_rises(sim: CombatSim) -> void:
	if sim.round_number >= (10 if sim.level == null else sim.level.tide_round) and (sim.level == null or sim.level.tide) and sim.terrain.water_y > 460.0:
		sim.terrain.water_y -= TIDE_STEP
		var tx_pos: float = sim.active_fighter.x if sim.active_fighter != null else sim.terrain.arena_at(0.5)
		sim.ftext(tx_pos, sim.terrain.water_y - 30.0, "FT_TIDE", Palette.FT_RED, 2.2)


## Ends the match when it is decided (a squad wiped out, the enemy out, the boss beaten or the nest fallen). True when it ended.
static func _decided(sim: CombatSim, t0_alive: Array[SimFighter], t1_alive: Array[SimFighter]) -> bool:
	var lost_nest: bool = sim.nest != null and sim.nest.destroyed
	var lost_leader: bool = SimConvoy.leader_dead(sim)
	if not (t0_alive.is_empty() or lost_nest or lost_leader or enemy_out(sim, t1_alive.size())):
		return false
	sim.turn_phase = CombatSim.Phase.GAME_OVER
	var winner: int = -1
	if t0_alive.size() > 0 and not lost_nest and not lost_leader:
		winner = 0
	elif t1_alive.size() > 0 or sim.waves_left > 0 or lost_nest or lost_leader:
		winner = 1
	sim.winner = winner
	sim.play("victory")
	sim.game_over.emit(winner, make_game_stats(sim))
	sim.hud()
	return true


## True when the enemy side is beaten: no enemy left (and no wave to come), the boss down or, in a procession, its (mini-)boss down:
## wiping out the other enemies of a convoy level wins nothing.
static func enemy_out(sim: CombatSim, enemy_count: int) -> bool:
	if SimConvoy.active(sim):
		return SimConvoy.enemy_done(sim)
	return (enemy_count == 0 and sim.waves_left <= 0) or SimBoss.beaten(sim)


static func _alive(sim: CombatSim, team: int) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team == team and f.alive and not f.drowning:
			out.append(f)
	return out


## Stats dictionary for the game_over signal (victory modal data).
static func make_game_stats(sim: CombatSim) -> Dictionary:
	var mvp: SimFighter = sim.fighters[0] if sim.fighters.size() > 0 else null
	for f in sim.fighters:
		if f.dmg_dealt > (mvp.dmg_dealt if mvp != null else -1):
			mvp = f
	var stats: Dictionary = {
		"map_name_key": sim.terrain.map.name_key,
		"rounds": sim.round_number,
		"team_damage": [sim.team_damage_dealt[0], sim.team_damage_dealt[1]],
		"mvp_name": mvp.name if mvp != null else "",
		"mvp_damage": mvp.dmg_dealt if mvp != null else 0,
		"mvp_team": mvp.team if mvp != null else -1,
	}
	if sim.level != null:
		SimStory.add_stats(sim, stats)
	return stats


## The per-frame turn state machine of main.js (runs after the physics step).
static func update_turn_fsm(sim: CombatSim, dt: float) -> void:
	var t0_count: int = sim.team_alive_count(0)
	var t1_count: int = sim.team_alive_count(1)
	if sim.critter_group.size() >= 2 and sim.turn_phase == CombatSim.Phase.TURN_PLAY:
		AiCritter.refresh_leader(sim)  # the leader may have fallen this frame: the phase goes on with the next unit
	var af: SimFighter = sim.active_fighter
	var enemy_gone: bool = enemy_out(sim, t1_count)
	match sim.turn_phase:
		CombatSim.Phase.TURN_PLAY:
			sim.action_wait_timer = 0.0
			if not sim.rotate_prompt_open:
				sim.turn_timer -= dt
			var ceil_sec: int = maxi(0, int(ceilf(sim.turn_timer)))
			if ceil_sec <= 5 and ceil_sec > 0 and ceil_sec < sim.last_turn_tick_sec:
				sim.last_turn_tick_sec = ceil_sec
				sim.play("tick")
			if sim.turn_timer <= 0.0 or af == null or not af.alive or af.drowning or t0_count == 0 or enemy_gone:
				sim.is_charging = false
				if not sim.critter_group.is_empty():
					AiCritter.end_phase(sim)
				sim.turn_phase = CombatSim.Phase.ACTION_WAIT
		CombatSim.Phase.RETREAT:
			sim.action_wait_timer = 0.0
			sim.phase_timer -= dt
			if sim.phase_timer <= 0.0 or af == null or not af.alive or af.drowning or t0_count == 0 or enemy_gone:
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

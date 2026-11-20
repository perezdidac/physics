## Tactical ballistic AI (JS updateAI / simulateArc): picks a target and weapon, brute-forces an angle and
## power, then walks, aims, charges and fires on a fixed timeline. Writes the aim fields of CombatSim.
class_name AiBrain
extends RefCounted


## Runs one AI frame (JS updateAI); does nothing unless it is an AI turn in TURN_PLAY.
static func update(sim: CombatSim, dt: float) -> void:
	if sim.critter_group.size() >= 2 and sim.turn_phase == CombatSim.Phase.TURN_PLAY:
		AiCritter.refresh_leader(sim)  # the leader of a critter phase may have fallen: the next unit takes over
	var af: SimFighter = sim.active_fighter
	if not sim.is_current_turn_ai() or sim.turn_phase != CombatSim.Phase.TURN_PLAY or af == null or not af.alive or af.drowning:
		return
	if SimGoals.holds_still(sim, af):
		sim.end_turn()
		return
	if sim.nest != null and SimBolso.ai_repair(sim):
		return
	if SimConvoy.active(sim) and af.team == 0:
		AiConvoy.update(sim, dt)
		return
	if af.unit != null and af.unit.ai == "CHARGER":
		AiCharger.update(sim, dt)
		return
	if af.unit != null and af.unit.ai == "MELEE_CRITTER":
		AiCritter.update(sim, dt)
		return
	if af.unit != null and af.unit.ai == "FLYER":
		AiFlyer.update(sim, dt)
		return
	if af.unit != null and af.unit.ai == "BOSS":
		SimBoss.update(sim, dt)
		return

	if sim.ai_plan.is_empty():
		_make_plan(sim, af)
		if sim.ai_plan.is_empty():
			return

	var plan: Dictionary = sim.ai_plan
	plan["total_time"] = float(plan["total_time"]) + dt

	if float(plan["walk_time"]) > 0.0:
		plan["walk_time"] = float(plan["walk_time"]) - dt
		return
	plan["walk_dir"] = 0

	if not plan["aim_computed"]:
		plan["aim_computed"] = true
		var target: SimFighter = plan["target"]
		if target == null or not target.alive or target.drowning:
			target = null
			for f in sim.fighters:
				if f.team != sim.active_team and f.alive and not f.drowning and not f.hidden:
					target = f
					break
		if target == null:
			sim.turn_phase = CombatSim.Phase.ACTION_WAIT
			return
		plan["target"] = target
		var wpn: WeaponDef = plan["wpn"]
		var best_angle: float = -PI * 0.32 if target.x >= af.x else -PI * 0.68
		var best_power: float = 0.65
		var best_dist: float = INF
		if wpn.type == "CHARGE":
			var dir_to_target: int = 1 if target.x >= af.x else -1
			for a_deg in range(18, 79, 4):
				var ang: float = (-a_deg * PI / 180.0) if dir_to_target > 0 else (-PI + a_deg * PI / 180.0)
				var pwr: float = 0.28
				while pwr <= 0.98:
					var landing: Vector2 = simulate_arc(sim, af.x, af.y - 6.0, ang, pwr, wpn.wind_factor)
					var d: float = Vector2(landing.x - target.x, landing.y - target.y).length()
					var self_d: float = Vector2(landing.x - af.x, landing.y - af.y).length()
					if self_d > 75.0 and d < best_dist:
						best_dist = d
						best_angle = ang
						best_power = pwr
					pwr += 0.05
			var jitter: float = float(SimTables.AI_JITTER.get(sim.ai_difficulty, 0.042))
			best_angle += (sim.rand() - 0.5) * jitter
			best_power = SimMath.clamp_js(best_power + (sim.rand() - 0.5) * jitter, 0.22, 0.98)
		else:
			best_angle = atan2(target.y - af.y, target.x - af.x)
		plan["angle"] = best_angle
		plan["power"] = best_power

	if float(plan["aim_time"]) > 0.0:
		plan["aim_time"] = float(plan["aim_time"]) - dt
		sim.aim_angle = lerpf(sim.aim_angle, plan["angle"], dt * 7.0)
		af.facing = 1 if cos(sim.aim_angle) >= 0.0 else -1
		return

	var wpn2: WeaponDef = plan["wpn"]
	if not plan["executed"]:
		var target2: SimFighter = plan["target"]
		if wpn2.type == "CHARGE" and float(plan["total_time"]) < 3.2:
			sim.is_charging = true
			sim.charge_power += dt * 0.95
			if sim.charge_power >= float(plan["power"]):
				sim.is_charging = false
				plan["executed"] = true
				SimCombat.fire_weapon(sim, wpn2, plan["angle"], plan["power"], null)
		elif wpn2.id == "AIRSTRIKE":
			sim.is_charging = false
			plan["executed"] = true
			SimCombat.fire_weapon(sim, wpn2, 0.0, 1.0, Vector2(target2.x, target2.y))
		else:
			sim.is_charging = false
			plan["executed"] = true
			var pw: float = float(plan["power"])
			SimCombat.fire_weapon(sim, wpn2, plan["angle"], pw if pw != 0.0 else 0.7, Vector2(target2.x, target2.y))
	elif sim.turn_phase == CombatSim.Phase.TURN_PLAY and float(plan["total_time"]) > 3.5:
		sim.is_charging = false
		sim.turn_phase = CombatSim.Phase.ACTION_WAIT


static func _make_plan(sim: CombatSim, af: SimFighter) -> void:
	if SimStatus.ai_wants_clean(sim, af):
		SimCombat.spin_silk_web(sim)
		return
	var enemies: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team != sim.active_team and f.alive and not f.drowning and not f.hidden:
			enemies.append(f)
	if enemies.is_empty():
		sim.turn_phase = CombatSim.Phase.ACTION_WAIT
		return
	enemies.sort_custom(func(a: SimFighter, b: SimFighter) -> bool:
		return Vector2(a.x - af.x, a.y - af.y).length() < Vector2(b.x - af.x, b.y - af.y).length())
	var target: SimFighter = enemies[0 if sim.rand() < 0.75 else int(sim.rand() * enemies.size())]

	var dist_nearest: float = Vector2(enemies[0].x - af.x, enemies[0].y - af.y).length()
	var r_choice: float = sim.rand()
	var chosen_id: String = "BAZOOKA"
	var ta: Dictionary = sim.team_ammo[sim.active_team]
	if dist_nearest < 64.0:
		chosen_id = "FUET" if sim.rand() < 0.6 else "BAT"
	elif r_choice < 0.14 and float(ta.get("HOLY", 0.0)) > 0.0:
		chosen_id = "HOLY"
	elif r_choice < 0.26 and float(ta.get("AIRSTRIKE", 0.0)) > 0.0:
		chosen_id = "AIRSTRIKE"
	elif r_choice < 0.40 and float(ta.get("URTICARIA", 0.0)) > 0.0:
		chosen_id = "URTICARIA"
	elif r_choice < 0.54 and float(ta.get("CLUSTER", 0.0)) > 0.0:
		chosen_id = "CLUSTER"
	elif r_choice < 0.70:
		chosen_id = "CARQUINYOLI"
	elif r_choice < 0.84:
		chosen_id = "GRENADE"
	else:
		chosen_id = "BAZOOKA"

	var idx: int = maxi(0, sim.weapon_index(chosen_id))
	if sim.level != null and sim.ammo_f(sim.active_team, sim.weapons[idx].id) <= 0.0:
		# a story arsenal is small: use the first weapon it has left (shots before melee), or pass
		idx = _story_weapon(sim)
		if idx < 0:
			sim.end_turn()
			return
	sim.selected_weapon_idx = idx
	sim.hud()
	var walk_dir: int = 0 if dist_nearest < 45.0 else (1 if sim.rand() < 0.5 else -1)
	var walk_time: float = 0.08 if dist_nearest < 45.0 else (0.45 + sim.rand() * 0.40)
	sim.ai_plan = {
		"target": target,
		"wpn": sim.weapons[idx],
		"angle": -PI * 0.28 if target.x >= af.x else -PI * 0.72,
		"power": 0.65,
		"walk_dir": walk_dir,
		"walk_time": walk_time,
		"aim_computed": false,
		"aim_time": 0.55,
		"total_time": 0.0,
		"executed": false,
	}


## Index of a weapon of the team's story arsenal that still has ammo: a CHARGE weapon first, else any melee one; -1 when none.
static func _story_weapon(sim: CombatSim) -> int:
	var melee: int = -1
	for i in sim.team_arsenal(sim.active_team):
		if sim.ammo_f(sim.active_team, sim.weapons[i].id) > 0.0:
			if sim.weapons[i].type == "CHARGE":
				return i
			if sim.weapons[i].type == "MELEE" and melee < 0:
				melee = i
	return melee


## JS simulateArc: ballistic estimator (intentionally not identical to the real projectile).
static func simulate_arc(sim: CombatSim, sx: float, sy: float, angle: float, power: float, wind_factor: float) -> Vector2:
	var speed: float = 180.0 + power * 760.0
	var x: float = sx + cos(angle) * 18.0
	var y: float = sy + sin(angle) * 18.0
	var vx: float = cos(angle) * speed
	var vy: float = sin(angle) * speed
	var dt: float = 0.025
	for i in 160:
		vx += (sim.wind * 2.4 * wind_factor) * dt
		vy += SimTables.GRAVITY * dt
		x += vx * dt
		y += vy * dt
		if y >= sim.terrain.water_y or sim.terrain.is_solid(x, y):
			break
	return Vector2(x, y)

## Fighter part of stepPhysics: procession links, castell towers, tools, walking, sliding, flying, landing,
## billiard knock-ons, drowning and the trailing body segments.
class_name SimFighterStep
extends RefCounted

const GRAVITY: float = SimTables.GRAVITY
const W: float = SimTables.TERRAIN_W


static func step(sim: CombatSim, dt: float) -> void:
	var can_control: bool = sim.can_control()
	_update_links(sim)
	for f in sim.fighters:
		if not f.alive:
			continue
		_step_one(sim, f, dt, can_control)


static func _update_links(sim: CombatSim) -> void:
	for f in sim.fighters:
		if not f.alive or f.drowning:
			f.linked_allies = []
			f.castell_tower = false
			continue
		var prev_count: int = f.linked_allies.size()
		var linked: Array[SimFighter] = []
		for other in sim.fighters:
			if other != f and other.team == f.team and other.alive and not other.drowning \
					and Vector2(other.x - f.x, other.y - f.y).length() <= 52.0:
				linked.append(other)
		f.linked_allies = linked
		if f == sim.active_fighter and linked.size() > prev_count and sim.playing:
			sim.taunt(f, "PROCESSION", 2.0)

		var was_castell: bool = f.castell_tower
		var has_base: bool = false
		for other in sim.fighters:
			if other != f and other.team == f.team and other.alive and not other.drowning \
					and absf(other.x - f.x) <= 20.0 and f.y < other.y - 4.0 and (other.y - f.y) <= 34.0:
				has_base = true
				break
		f.castell_tower = has_base
		if f.castell_tower and not was_castell and sim.playing:
			sim.play("caganer_blessing")
			sim.bubble(f, "BUBBLE_CASTELL", 2.4)
			sim.ftext(f.x, f.y - 38.0, "FT_CASTELL", Palette.FT_GOLD_BRIGHT, 1.9)


## JS updateOrugaSegments: the six trailing segments follow the head (cosmetic, reads the mask).
static func update_segments(sim: CombatSim, f: SimFighter, dt: float) -> void:
	if f.segs.size() == 0:
		return
	var terrain: TerrainSim = sim.terrain
	var lead_x: float = f.x
	var lead_y: float = f.y + 3.0
	for i in f.segs.size():
		var seg: Vector2 = f.segs[i]
		var target_x: float = lead_x - f.facing * 5.0
		var wave: float
		if f.grounded and not f.sliding:
			wave = sin(f.walk_cycle * 1.35 - i * 0.95) * 2.2
		else:
			wave = sin(sim.t_now * 14.0 - i * 0.8) * 1.5
		seg.x = lerpf(seg.x, target_x, minf(1.0, dt * (18.0 - i * 1.4)))
		var desired_y: float = lead_y + wave * 0.45
		if f.grounded and not f.drowning:
			for dy in range(-6, 9):
				if not terrain.is_solid(seg.x, f.y + dy) and terrain.is_solid(seg.x, f.y + 10.0 + dy):
					desired_y = f.y + 3.0 + dy + minf(0.0, wave)
					break
		seg.y = lerpf(seg.y, desired_y, minf(1.0, dt * 16.0))
		f.segs[i] = seg
		lead_x = seg.x
		lead_y = seg.y


static func _step_one(sim: CombatSim, f: SimFighter, dt: float, can_control: bool) -> void:
	var terrain: TerrainSim = sim.terrain
	var wy: float = terrain.water_y

	f.squash_x = lerpf(f.squash_x, 1.0, minf(1.0, dt * 11.0))
	f.squash_y = lerpf(f.squash_y, 1.0, minf(1.0, dt * 11.0))
	if f.hurt_timer > 0.0:
		f.hurt_timer = maxf(0.0, f.hurt_timer - dt)
	if f.dizzy_timer > 0.0:
		f.dizzy_timer = maxf(0.0, f.dizzy_timer - dt)
	if f.bat_swing_timer > 0.0:
		f.bat_swing_timer = maxf(0.0, f.bat_swing_timer - dt)

	if f.drowning:
		f.drown_timer -= dt
		f.vx *= 0.92
		f.vy = 42.0
		f.x += f.vx * dt
		f.y += f.vy * dt
		f.walk_cycle += dt * 18.0
		update_segments(sim, f, dt)
		if sim.rand() < 0.48:
			sim.fx("bubbles", {"x": f.x + (sim.rand() - 0.5) * 14.0, "y": f.y - 6.0})
		if f.drown_timer <= 0.0 or f.y > SimTables.TERRAIN_H + 35.0:
			f.alive = false
			f.drowning = false
			sim.hud()
		return

	if f.spoon_timer > 0.0:
		_step_spoon(sim, f, dt)
		return
	if f.drill_timer > 0.0:
		_step_drill(sim, f, dt)
		return
	if not f.grapple.is_empty():
		_step_grapple(sim, f, dt)
		return

	if f.grounded and not terrain.is_solid(f.x, f.y + f.r + 2.0) and not terrain.is_solid(f.x - 4.0, f.y + f.r + 2.0) and not terrain.is_solid(f.x + 4.0, f.y + f.r + 2.0):
		f.grounded = false
		f.sliding = false
		f.slide_angle = 0.0
		f.jump_start_y = f.y
		f.peak_air_y = f.y
		f.is_voluntary_jump = false

	if f.grounded and not f.sliding:
		f.vx = 0.0
		f.vy = 0.0
		f.slide_timer = 0.0
		f.air_timer = 0.0
		f.peak_air_y = f.y

	if f == sim.active_fighter and f.jet_fuel > 0.0 and can_control:
		_step_jetpack(sim, f, dt)

	var ai_walking: bool = sim.is_current_turn_ai() and not sim.ai_plan.is_empty() and int(sim.ai_plan.get("walk_dir", 0)) != 0
	if f == sim.active_fighter and f.grounded and not f.sliding and (can_control or ai_walking):
		_step_walk(sim, f, dt, can_control)

	if f.grounded and f.sliding:
		_step_slide(sim, f, dt)

	if not f.grounded:
		_step_air(sim, f, dt, can_control)

	if f.grounded and not f.sliding:
		f.vx = 0.0
		f.vy = 0.0

	_step_billiards(sim, f)
	update_segments(sim, f, dt)

	if f.y >= wy and not f.drowning:
		f.drowning = true
		f.drown_timer = 1.85
		f.hp = 0
		f.vy = 45.0
		sim.play("plunge")
		SimCombat.water_plunge(sim, f.x, wy, 1.25)
		sim.ftext(f.x, wy - 26.0, "FT_DROWN", Palette.FT_WATER, 2.2, [f.name])
		sim.hud()


static func _step_spoon(sim: CombatSim, f: SimFighter, dt: float) -> void:
	var terrain: TerrainSim = sim.terrain
	f.spoon_timer = maxf(0.0, f.spoon_timer - dt)
	f.spoon_tick -= dt
	if f == sim.active_fighter and not sim.is_current_turn_ai():
		if sim.key_up():
			f.spoon_angle -= 0.9 * dt * f.facing
		if sim.key_down():
			f.spoon_angle += 0.9 * dt * f.facing
	var s_dir_x: float = cos(f.spoon_angle)
	var s_dir_y: float = sin(f.spoon_angle)
	f.facing = 1 if s_dir_x >= 0.0 else -1
	f.walk_cycle += dt * 22.0

	f.x = SimMath.clamp_js(f.x + s_dir_x * 64.0 * dt, 28.0, W - 28.0)
	f.y = SimMath.clamp_js(f.y + s_dir_y * 42.0 * dt, 38.0, terrain.water_y - 18.0)
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	f.grounded = terrain.is_solid(f.x, f.y + f.r + 2.0)
	sim.impact_tracked_worm = f
	sim.focus(f.x, f.y, f)

	if f.spoon_tick <= 0.0:
		f.spoon_tick = 0.085
		sim.play("spoon_scoop")
		var scoop_x: float = f.x + s_dir_x * 15.0
		var scoop_y: float = f.y - 2.0 + s_dir_y * 10.0
		terrain.carve_crater(scoop_x, scoop_y, 19.0)
		SimCombat.debris(sim, scoop_x, scoop_y, 4)
		for other in sim.fighters:
			if other != f and other.alive and not other.drowning and Vector2(other.x - scoop_x, other.y - scoop_y).length() <= 28.0:
				SimCombat.damage_fighter(sim, other, 14, "DMG_SPOON")
				other.vx = s_dir_x * 320.0
				other.vy = -210.0
				other.grounded = false
				other.was_blasted = true
				other.jump_start_y = other.y
				other.peak_air_y = other.y
		for b in sim.barrels:
			if Vector2(b.x - scoop_x, b.y - scoop_y).length() <= 28.0:
				b.vx = s_dir_x * 280.0
				b.vy = -190.0
				b.grounded = false
	update_segments(sim, f, dt)
	if f.spoon_timer <= 0.0 and sim.turn_phase == CombatSim.Phase.ACTION_WAIT:
		sim.turn_phase = CombatSim.Phase.RETREAT
		sim.phase_timer = 1.8


static func _step_drill(sim: CombatSim, f: SimFighter, dt: float) -> void:
	var terrain: TerrainSim = sim.terrain
	f.drill_timer = maxf(0.0, f.drill_timer - dt)
	f.drill_tick -= dt
	var d_ang: float = f.drill_angle if f.drill_angle != 0.0 else PI * 0.5
	var d_dir_x: float = cos(d_ang)
	var d_dir_y: float = maxf(0.25, sin(d_ang))
	f.facing = 1 if d_dir_x >= 0.0 else -1
	f.squash_x = 1.0 + sin(sim.t_now * 55.0) * 0.12
	f.squash_y = 1.0 - sin(sim.t_now * 55.0) * 0.12
	sim.screen_shake.emit(3.5)

	f.x = SimMath.clamp_js(f.x + d_dir_x * 52.0 * dt, 28.0, W - 28.0)
	f.y = SimMath.clamp_js(f.y + d_dir_y * 56.0 * dt, 38.0, terrain.water_y - 22.0)
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	f.grounded = terrain.is_solid(f.x, f.y + f.r + 2.0)
	sim.impact_tracked_worm = f
	sim.focus(f.x, f.y, f)

	if f.drill_tick <= 0.0:
		f.drill_tick = 0.08
		sim.play("drill_bore")
		var bit_x: float = f.x + d_dir_x * 14.0
		var bit_y: float = f.y + d_dir_y * 14.0
		terrain.carve_crater(bit_x, bit_y, 16.0)
		SimCombat.sparks(sim, bit_x, bit_y, 4)
		SimCombat.debris(sim, bit_x, bit_y, 3)
		for other in sim.fighters:
			if other != f and other.alive and not other.drowning and Vector2(other.x - bit_x, other.y - bit_y).length() <= 26.0:
				SimCombat.damage_fighter(sim, other, 7, "DMG_DRILL")
				other.vx = (d_dir_x if d_dir_x != 0.0 else 0.4) * 160.0
				other.vy = -120.0
				other.grounded = false
	update_segments(sim, f, dt)
	if f.drill_timer <= 0.0 and sim.turn_phase == CombatSim.Phase.ACTION_WAIT:
		sim.turn_phase = CombatSim.Phase.RETREAT
		sim.phase_timer = 1.8


static func _step_grapple(sim: CombatSim, f: SimFighter, dt: float) -> void:
	var g: Dictionary = f.grapple
	g["progress"] = minf(1.0, float(g["progress"]) + dt * 2.6)
	var progress: float = g["progress"]
	var ease_v: float = 1.0 - pow(1.0 - progress, 2.2)
	f.x = lerpf(g["start_x"], g["target_x"], ease_v)
	f.y = lerpf(g["start_y"], g["target_y"], ease_v) - sin(progress * PI) * 18.0
	f.vx = 0.0
	f.vy = 0.0
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	f.is_voluntary_jump = true
	f.was_blasted = false
	sim.impact_tracked_worm = f
	sim.focus(f.x, f.y, f)
	update_segments(sim, f, dt)
	if progress >= 1.0:
		f.grapple = {}
		f.grounded = sim.terrain.is_solid(f.x, f.y + f.r + 2.0)
		sim.play("jump")
		if sim.turn_phase == CombatSim.Phase.ACTION_WAIT:
			sim.turn_phase = CombatSim.Phase.RETREAT
			sim.phase_timer = 2.4


static func _step_jetpack(sim: CombatSim, f: SimFighter, dt: float) -> void:
	var thrusting: bool = false
	if sim.key_up():
		f.vy = maxf(-240.0, f.vy - 760.0 * dt)
		thrusting = true
	if sim.key_left():
		f.vx = maxf(-190.0, f.vx - 420.0 * dt)
		f.facing = -1
		thrusting = true
	if sim.key_right():
		f.vx = minf(190.0, f.vx + 420.0 * dt)
		f.facing = 1
		thrusting = true
	if thrusting:
		f.grounded = false
		f.is_voluntary_jump = true
		f.jump_start_y = f.y
		f.peak_air_y = f.y
		f.jet_fuel = maxf(0.0, f.jet_fuel - 28.0 * dt)
		sim.play("jet_thrust")
		if sim.rand() < 0.75:
			sim.fx("jet_flame", {"x": f.x - f.facing * 7.0 + (sim.rand() - 0.5) * 4.0, "y": f.y + 4.0})


## Probes the terrain for the first dy where a worm at stepX can stand (feet on solid, body free).
static func _find_step_y(terrain: TerrainSim, step_x: float, f_y: float, r: float, dy_from: int, dy_to: int) -> float:
	for dy in range(dy_from, dy_to + 1):
		if not terrain.is_solid(step_x, f_y + dy) and terrain.is_solid(step_x, f_y + r + dy):
			return f_y + dy
	return NAN


static func _step_walk(sim: CombatSim, f: SimFighter, dt: float, can_control: bool) -> void:
	var terrain: TerrainSim = sim.terrain
	var move_dir: int = 0
	if can_control:
		if sim.key_left():
			move_dir = -1
		elif sim.key_right():
			move_dir = 1
	else:
		move_dir = int(sim.ai_plan.get("walk_dir", 0))
	if move_dir == 0 or sim.is_charging:
		return
	if can_control:
		sim.has_acted_or_moved_this_turn = true
	if f.facing != move_dir:
		f.facing = move_dir
		if not sim.is_current_turn_ai():
			sim.sync_aim_angle_from_pitch()
	f.walk_cycle += dt * 12.0
	sim.play("crawl_step")
	var step_x: float = SimMath.clamp_js(f.x + move_dir * 78.0 * dt, 30.0, W - 30.0)
	var found_y: float = _find_step_y(terrain, step_x, f.y, f.r, -9, 10)
	if not is_nan(found_y):
		f.x = step_x
		f.y = found_y
		f.jump_start_y = f.y
		f.peak_air_y = f.y
	elif not terrain.is_solid(step_x, f.y):
		f.x = step_x
		f.grounded = false
		f.jump_start_y = f.y
		f.peak_air_y = f.y
		f.is_voluntary_jump = false

	if sim.procession_convoy_enabled and f.linked_allies.size() > 0:
		var leader_x: float = f.x
		for ally in f.linked_allies:
			if not ally.grounded or ally.sliding:
				continue
			var desired_x: float = leader_x - move_dir * 30.0
			var diff_x: float = desired_x - ally.x
			if absf(diff_x) > 4.0:
				var ally_step_x: float = ally.x + SimMath.sign_js(diff_x) * minf(absf(diff_x), 74.0 * dt)
				ally.facing = move_dir
				ally.walk_cycle += dt * 12.0
				var ay: float = _find_step_y(terrain, ally_step_x, ally.y, ally.r, -9, 10)
				if not is_nan(ay):
					ally.x = ally_step_x
					ally.y = ay
			leader_x = ally.x


static func _step_slide(sim: CombatSim, f: SimFighter, dt: float) -> void:
	var terrain: TerrainSim = sim.terrain
	f.slide_timer += dt
	var friction_base: float = 0.90 if f.is_minor_slide else terrain.map.slide_friction
	f.vx *= pow(friction_base, dt * 60.0)
	var step_x: float = SimMath.clamp_js(f.x + f.vx * dt, 24.0, W - 24.0)
	f.facing = 1 if f.vx >= 0.0 else -1

	var found_y: float = _find_step_y(terrain, step_x, f.y, f.r, -10, 12)
	if not is_nan(found_y):
		var dy_slope: float = found_y - f.y
		f.x = step_x
		f.y = found_y
		f.vx += dy_slope * (10.0 if f.is_minor_slide else 18.0) * dt
		f.slide_angle = SimMath.clamp_js(dy_slope * 0.12, -0.5, 0.5)
		var speed: float = absf(f.vx)
		if speed > 26.0:
			sim.play("skid", {"speed": speed})
			if sim.rand() < 0.65:
				sim.fx("skid_smoke", {"x": f.x - f.facing * 8.0, "y": f.y + f.r - 2.0, "vx": -f.vx * 0.25})
	elif not terrain.is_solid(step_x, f.y):
		f.x = step_x
		f.grounded = false
		f.sliding = false
		f.is_minor_slide = false
		f.slide_angle = 0.0
		f.jump_start_y = f.y
		f.peak_air_y = f.y
		f.is_voluntary_jump = false
	else:
		f.vx = -f.vx * 0.4

	var max_slide_dur: float = 0.42 if f.is_minor_slide else 2.2
	var stop_speed: float = 24.0 if f.is_minor_slide else 18.0
	if absf(f.vx) < stop_speed or f.slide_timer > max_slide_dur:
		f.vx = 0.0
		f.vy = 0.0
		f.sliding = false
		f.is_minor_slide = false
		f.slide_angle = 0.0
		f.slide_timer = 0.0
		f.squash_x = 0.88
		f.squash_y = 1.14
		if f == sim.active_fighter and not sim.is_current_turn_ai():
			sim.sync_aim_angle_from_pitch()


static func _step_air(sim: CombatSim, f: SimFighter, dt: float, can_control: bool) -> void:
	var terrain: TerrainSim = sim.terrain
	f.air_timer += dt
	f.peak_air_y = minf(f.peak_air_y, f.y)

	if f.metamorphosed and f == sim.active_fighter and can_control and sim.key_up() and f.vy > 25.0:
		f.vy = lerpf(f.vy, 48.0, dt * 9.0)
		f.vx = lerpf(f.vx, f.facing * 125.0 + sim.wind * 0.55, dt * 3.5)
		f.jump_start_y = f.y
		f.peak_air_y = f.y
		f.is_voluntary_jump = true

	for u in sim.updrafts:
		if absf(f.x - u.x) < u.w and f.y < u.y and f.y > u.y - u.h:
			var lift: float = 620.0 if (f.metamorphosed and sim.key_up()) else 240.0
			f.vy -= lift * dt

	if f.flip_spin != 0.0:
		f.flip_angle += f.flip_spin * dt

	f.vy += GRAVITY * dt
	for s in 4:
		f.x = SimMath.clamp_js(f.x + (f.vx * dt) / 4.0, 18.0, W - 18.0)
		f.y += (f.vy * dt) / 4.0
		f.peak_air_y = minf(f.peak_air_y, f.y)

		if f.vy > 0.0:
			if _bounce_on_web(sim, f):
				break
			if _bounce_on_rovello(sim, f):
				break

		if terrain.is_solid(f.x, f.y + f.r):
			_land(sim, f)
			break

		if terrain.is_solid(f.x, f.y - f.r) and f.vy < 0.0:
			f.vy = -f.vy * 0.35
		if terrain.is_solid(f.x + SimMath.sign_js(f.vx) * f.r, f.y):
			f.vx = -f.vx * 0.55

	if not f.grounded and f.air_timer > 4.5 and f.jet_fuel <= 0.0:
		f.vx = 0.0
		f.vy = 0.0
		f.grounded = true
		f.sliding = false
		f.air_timer = 0.0


static func _bounce_on_web(sim: CombatSim, f: SimFighter) -> bool:
	var wi: int = sim.silk_webs.size() - 1
	while wi >= 0:
		var w: SimWeb = sim.silk_webs[wi]
		var dx_w: float = w.x2 - w.x1
		var dy_w: float = w.y2 - w.y1
		var len_sq: float = dx_w * dx_w + dy_w * dy_w
		if len_sq > 1.0:
			var t_proj: float = SimMath.clamp_js(((f.x - w.x1) * dx_w + ((f.y + f.r * 0.6) - w.y1) * dy_w) / len_sq, 0.0, 1.0)
			var close_x: float = w.x1 + t_proj * dx_w
			var close_y: float = w.y1 + t_proj * dy_w
			if Vector2(f.x - close_x, (f.y + f.r * 0.6) - close_y).length() <= 10.0:
				f.vy = -maxf(215.0, minf(310.0, absf(f.vy) * 0.95))
				f.vx = SimMath.clamp_js(f.vx * 1.08, -190.0, 190.0)
				f.jump_start_y = f.y
				f.peak_air_y = f.y
				f.is_voluntary_jump = true
				f.was_blasted = false
				f.squash_x = 1.32
				f.squash_y = 0.72
				w.vibration = 1.0
				w.hp -= 1
				if w.hp <= 0:
					sim.silk_webs.remove_at(wi)
				sim.play("jump")
				sim.ftext(f.x, f.y - 24.0, "FT_WEB_BOING", Palette.FT_CREAM, 1.0)
				return true
		wi -= 1
	return false


static func _bounce_on_rovello(sim: CombatSim, f: SimFighter) -> bool:
	for rv in sim.rovellons:
		if absf(f.x - rv.x) <= rv.r + 5.0 and absf((f.y + f.r * 0.7) - (rv.y - 10.0)) <= 13.0:
			f.vy = -maxf(255.0, minf(340.0, absf(f.vy) * 1.15 + 120.0))
			f.vx = SimMath.clamp_js(f.vx * 1.12 + f.facing * 35.0, -210.0, 210.0)
			f.jump_start_y = f.y
			f.peak_air_y = f.y
			f.is_voluntary_jump = true
			f.was_blasted = false
			f.squash_x = 1.38
			f.squash_y = 0.68
			rv.squash = 0.42
			sim.play("rovello_boing")
			if f.hp < f.max_hp:
				f.hp = mini(f.max_hp, f.hp + 8)
				sim.hud()
			f.urticating_ticks = 0
			SimCombat.sparks(sim, rv.x, rv.y - 12.0, 10)
			sim.ftext(f.x, f.y - 26.0, "FT_ROVELLO_BOING", Palette.FT_ORANGE, 1.35)
			return true
	return false


## Landing of an airborne fighter: fall classes, damage, slides (the 3-tier fall physics of the JS).
static func _land(sim: CombatSim, f: SimFighter) -> void:
	var terrain: TerrainSim = sim.terrain
	while terrain.is_solid(f.x, f.y + f.r - 1.0) and f.y > 0.0:
		f.y -= 1.0

	var vert_speed: float = absf(f.vy)
	var horiz_speed: float = absf(f.vx)
	var total_speed: float = sqrt(f.vx * f.vx + f.vy * f.vy)
	var fall_drop: float = f.y - f.jump_start_y
	var drop_from_peak: float = f.y - f.peak_air_y
	var n: Vector2 = terrain.surface_normal(f.x, f.y + f.r)
	var tx_v: float = -n.y
	var ty_v: float = n.x
	var tangent_speed: float = f.vx * tx_v + f.vy * ty_v
	var slope_steepness: float = absf(n.x)

	var is_significant: bool = (fall_drop >= 88.0 or drop_from_peak >= 126.0) or (f.was_blasted and (vert_speed > 235.0 or total_speed > 285.0))
	var is_little: bool = not is_significant and not f.was_blasted and (fall_drop >= 12.0 or drop_from_peak >= 54.0 or (vert_speed > 155.0 and slope_steepness > 0.22))

	if is_significant and (vert_speed > 210.0 or total_speed > 260.0 or fall_drop >= 88.0):
		sim.play("hard_slam", {"speed": total_speed})
		sim.screen_shake.emit(SimMath.clamp_js((total_speed - 210.0) * 0.038, 3.0, 14.0))
		var squash_mag: float = SimMath.clamp_js((total_speed - 200.0) / 340.0, 0.25, 0.62)
		f.squash_x = 1.0 + squash_mag * 0.95
		f.squash_y = 1.0 - squash_mag * 0.65
		SimCombat.shockwave(sim, f.x, f.y + f.r - 2.0, 4.0, 26.0 + squash_mag * 32.0, 0.75)
		SimCombat.smoke(sim, f.x, f.y + f.r, 7, "dust")
		SimCombat.spawn_hairs(sim, f.x, f.y, 10)

		var excess_drop: float = maxf(maxf(drop_from_peak - 115.0, fall_drop - 78.0), 0.0)
		var fall_dmg: int = int(SimMath.clamp_js(SimMath.round_js(6.0 + excess_drop * 0.22 + maxf(0.0, total_speed - 250.0) * 0.06), 6.0, 45.0))
		SimCombat.damage_fighter(sim, f, fall_dmg, "DMG_SLAM")
		f.dizzy_timer = 2.8

		if total_speed > 360.0 or drop_from_peak > 150.0:
			terrain.carve_crater(f.x, f.y + f.r - 2.0, 14.0)
			while not terrain.is_solid(f.x, f.y + f.r) and f.y < terrain.water_y:
				f.y += 1.0

		if f == sim.active_fighter and (sim.turn_phase == CombatSim.Phase.TURN_PLAY or sim.turn_phase == CombatSim.Phase.RETREAT):
			sim.is_charging = false
			sim.charge_power = 0.0
			f.jet_fuel = 0.0
			sim.impact_tracked_worm = f
			sim.focus(f.x, f.y, f)
			sim.turn_phase = CombatSim.Phase.ACTION_WAIT

	f.flip_angle = 0.0
	f.flip_spin = 0.0
	f.air_timer = 0.0
	f.peak_air_y = f.y

	if is_little:
		var slide_dir: float
		if horiz_speed > 8.0:
			slide_dir = SimMath.sign_js(f.vx)
		elif absf(tangent_speed) > 12.0:
			slide_dir = SimMath.sign_js(tangent_speed)
		else:
			slide_dir = SimMath.sign_js(n.x) if n.x != 0.0 else float(f.facing)
		var little_speed: float = SimMath.clamp_js(horiz_speed * 0.68 + maxf(0.0, fall_drop) * 0.95 + slope_steepness * 48.0, 46.0, 128.0)
		f.vx = slide_dir * little_speed
		f.vy = 0.0
		f.grounded = true
		f.sliding = true
		f.is_minor_slide = true
		f.slide_timer = 0.0
		f.squash_x = 1.18
		f.squash_y = 0.84
		sim.play("skid", {"speed": little_speed})
		SimCombat.smoke(sim, f.x, f.y + f.r, 3, "dust")
	elif is_significant or f.was_blasted:
		var slide_mag: float = horiz_speed * 0.82 + maxf(0.0, vert_speed - 195.0) * (0.45 + slope_steepness * 0.6)
		if slide_mag > 44.0 or horiz_speed > 85.0:
			var slide_dir2: float
			if absf(tangent_speed) > 18.0:
				slide_dir2 = SimMath.sign_js(tangent_speed)
			elif horiz_speed > 5.0:
				slide_dir2 = SimMath.sign_js(f.vx)
			else:
				slide_dir2 = SimMath.sign_js(n.x) if n.x != 0.0 else float(f.facing)
			f.vx = slide_dir2 * SimMath.clamp_js(slide_mag, 52.0, 380.0)
			f.vy = 0.0
			f.grounded = true
			f.sliding = true
			f.is_minor_slide = false
			f.slide_timer = 0.0
		else:
			f.vx = 0.0
			f.vy = 0.0
			f.grounded = true
			f.sliding = false
			f.is_minor_slide = false
			f.slide_timer = 0.0
	else:
		f.vx = 0.0
		f.vy = 0.0
		f.grounded = true
		f.sliding = false
		f.is_minor_slide = false
		f.slide_timer = 0.0
		f.squash_x = 1.14
		f.squash_y = 0.88
	f.was_blasted = false
	f.is_voluntary_jump = false
	f.jump_start_y = f.y


static func _step_billiards(sim: CombatSim, f: SimFighter) -> void:
	var f_speed: float = sqrt(f.vx * f.vx + f.vy * f.vy)
	if not ((f.sliding or f.was_blasted or (not f.grounded and f_speed > 155.0)) and f_speed > 95.0):
		return
	for other in sim.fighters:
		if other == f or not other.alive or other.drowning:
			continue
		var dx: float = other.x - f.x
		var dy: float = other.y - f.y
		var d: float = sqrt(dx * dx + dy * dy)
		if d > 0.0 and d < f.r + other.r - 2.0 and f.last_knock_time < sim.t_now - 0.28:
			f.last_knock_time = sim.t_now
			other.last_knock_time = sim.t_now
			var nx: float = dx / d
			other.vx = nx * maxf(125.0, absf(f.vx) * 0.78) + f.vx * 0.25
			other.vy = minf(-95.0, f.vy * 0.45 - 80.0)
			other.grounded = false
			other.sliding = false
			other.was_blasted = true
			other.jump_start_y = other.y
			other.peak_air_y = other.y
			other.squash_x = 0.74
			other.squash_y = 1.32
			f.vx *= 0.48
			f.squash_x = 1.24
			f.squash_y = 0.80
			sim.play("bounce")
			SimCombat.spawn_hairs(sim, (f.x + other.x) * 0.5, (f.y + other.y) * 0.5, 6)
			if f_speed > 195.0 and other.team != f.team:
				SimCombat.damage_fighter(sim, other, 6, "DMG_CARAMBOLA")
			else:
				sim.ftext(other.x, other.y - 26.0, "FT_CARAMBOLA", Palette.FT_GOLD_SOFT, 1.1)
	for b in sim.barrels:
		var bdx: float = b.x - f.x
		var bdy: float = b.y - f.y
		var bd: float = sqrt(bdx * bdx + bdy * bdy)
		if bd > 0.0 and bd < f.r + b.r and b.last_knock_time < sim.t_now - 0.25:
			b.last_knock_time = sim.t_now
			b.vx += (bdx / bd) * maxf(95.0, f_speed * 0.55)
			b.vy = -85.0
			b.grounded = false
			f.vx *= 0.55
			sim.play("bounce")

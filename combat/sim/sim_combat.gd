## Explosions, damage, metamorphosis, silk webs and the weapon dispatch (JS physics.js sections 6).
class_name SimCombat
extends RefCounted


# ---------------------------------------------------------------------------
# Effect helpers (event requests for the view)
# ---------------------------------------------------------------------------

static func spawn_hairs(sim: CombatSim, x: float, y: float, count: int) -> void:
	sim.fx("urticating_hairs", {"x": x, "y": y, "count": count})


static func smoke(sim: CombatSim, x: float, y: float, count: int, style: String) -> void:
	sim.fx("smoke", {"x": x, "y": y, "count": count, "style": style})


static func sparks(sim: CombatSim, x: float, y: float, count: int) -> void:
	sim.fx("sparks", {"x": x, "y": y, "count": count})


static func debris(sim: CombatSim, x: float, y: float, count: int) -> void:
	sim.fx("debris", {"x": x, "y": y, "count": count})


static func water_plunge(sim: CombatSim, x: float, y: float, scale: float) -> void:
	sim.fx("water_plunge", {"x": x, "y": y, "scale": scale})


static func shockwave(sim: CombatSim, x: float, y: float, r: float, max_r: float, alpha: float, color: String = "") -> void:
	sim.fx("shockwave", {"x": x, "y": y, "r": r, "max_r": max_r, "alpha": alpha, "color": color})


static func _track(sim: CombatSim, f: SimFighter) -> void:
	sim.impact_tracked_worm = f
	sim.focus(f.x, f.y, f)


# ---------------------------------------------------------------------------
# Nests, webs, metamorphosis
# ---------------------------------------------------------------------------

## JS burstSilkNest: 3 pine nuts and a larvae swarm.
static func burst_silk_nest(sim: CombatSim, nest: SimNest) -> void:
	sim.play("urticating_burst")
	smoke(sim, nest.x, nest.y, 12, "silk")
	spawn_hairs(sim, nest.x, nest.y, 28)
	sim.ftext(nest.x, nest.y - 20.0, "FT_NEST_BURST", Palette.FT_GOLD_SOFT, 2.1)
	for k in 3:
		var pn := SimNut.new()
		pn.x = nest.x + (k - 1) * 10.0
		pn.y = nest.y
		pn.vx = (k - 1) * 65.0 + (sim.rand() - 0.5) * 35.0
		pn.vy = -120.0 - sim.rand() * 55.0
		sim.pine_nuts.append(pn)
	var sw := SimLarvae.new()
	sw.x = nest.x
	sw.y = nest.y + 8.0
	sw.vy = 40.0
	sim.larvae_swarms.append(sw)


## JS spinElasticSilkWeb: one web per turn.
static func spin_silk_web(sim: CombatSim) -> void:
	var af: SimFighter = sim.active_fighter
	if af == null or not af.alive or af.drowning or sim.silk_web_used_this_turn:
		return
	if not sim.playing or (sim.turn_phase != CombatSim.Phase.TURN_PLAY and sim.turn_phase != CombatSim.Phase.RETREAT):
		return
	sim.silk_webs_spun += 1
	sim.silk_web_used_this_turn = sim.silk_webs_spun >= sim.silk_webs_per_turn
	var dir_x: float = cos(sim.aim_angle)
	var dir_y: float = sin(sim.aim_angle)
	var cx: float = af.x + dir_x * 46.0
	var cy: float = (af.y - 6.0) + dir_y * 46.0
	var perp_x: float = -dir_y
	var perp_y: float = dir_x
	var half_span: float = 38.0
	var w := SimWeb.new()
	w.x1 = cx - perp_x * half_span
	w.y1 = cy - perp_y * half_span
	w.x2 = cx + perp_x * half_span
	w.y2 = cy + perp_y * half_span
	w.team = af.team
	sim.silk_webs.append(w)
	sim.play("jump")
	spawn_hairs(sim, cx, cy, 12)
	sim.ftext(cx, cy - 16.0, "FT_WEB_SPUN", Palette.FT_CREAM, 1.65)
	SimStatus.on_silk_web(sim, af)
	sim.hud()


## JS checkMetamorphosis: wings at hp <= 35 or 75 damage dealt.
static func check_metamorphosis(sim: CombatSim, f: SimFighter) -> void:
	if f == null or not f.alive or f.drowning or f.metamorphosed or f.unit != null:
		return
	if (f.hp > 0 and f.hp <= 35) or f.dmg_dealt >= 75:
		f.metamorphosed = true
		sim.play("crate_pickup")
		spawn_hairs(sim, f.x, f.y - 6.0, 26)
		shockwave(sim, f.x, f.y - 4.0, 5.0, 54.0, 0.95, "246, 207, 119")
		sim.taunt(f, "METAMORPH", 2.4)
		sim.ftext(f.x, f.y - 42.0, "FT_METAMORPHOSIS", Palette.FT_GOLD_SOFT, 2.4, [f.name])


# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

## JS damageFighter. `label_key` is a translation key of a damage label ("" for none).
static func damage_fighter(sim: CombatSim, f: SimFighter, dmg: int, label_key: String = "") -> void:
	if not f.alive or f.is_hazard():
		return
	dmg = SimBoss.scale_damage(sim, f, dmg)
	dmg = SimBolso.shelter_scale(sim, f, dmg)
	var actual: int = mini(f.hp, dmg)
	f.hp = maxi(0, f.hp - dmg)
	if sim.playing:
		sim.play("worm_hurt", {"dmg": dmg, "dead": f.hp <= 0})

	var af: SimFighter = sim.active_fighter
	if af != null and af.team != f.team:
		af.dmg_dealt += actual
		sim.team_damage_dealt[af.team] += actual
		check_metamorphosis(sim, af)

	var color: Color = Palette.FT_PURPLE if label_key == "DMG_URTICARIA" else Palette.FT_RED
	if label_key != "":
		sim.ftext(f.x, f.y - 28.0, "FT_DAMAGE_LABEL", color, 1.45, [sim.tx(label_key), dmg])
	else:
		sim.ftext(f.x, f.y - 28.0, "FT_DAMAGE", color, 1.45, [dmg])
	if f.hp <= 0 and not f.drowning:
		f.alive = false
		sim.ftext(f.x, f.y - 46.0, "FT_FALLEN", Palette.FT_GOLD, 1.95, [f.name])
		smoke(sim, f.x, f.y, 10, "dust")
		spawn_hairs(sim, f.x, f.y, 22)
		var tb := SimTombstone.new()
		tb.x = f.x
		tb.y = f.y - 6.0
		tb.name = f.name
		tb.team = f.team
		sim.tombstones.append(tb)
	else:
		check_metamorphosis(sim, f)
	SimBoss.on_damaged(sim, f)
	sim.hud()


# ---------------------------------------------------------------------------
# Explosion
# ---------------------------------------------------------------------------

## JS triggerExplosion: crater, damage with falloff, knockback, pickups, barrels, nests, clusters.
static func trigger_explosion(sim: CombatSim, ex: float, ey: float, radius: float, max_dmg: float, knockback: float, spawn_clusters: int = 0, is_urticating: bool = false) -> void:
	var terrain: TerrainSim = sim.terrain
	if is_urticating:
		sim.play("urticating_burst")
		spawn_hairs(sim, ex, ey, 48)
		smoke(sim, ex, ey, 14, "urticating")
	else:
		sim.play("boom", {"scale": radius / 45.0})
		smoke(sim, ex, ey, int(floorf(radius * 0.42)), "dark")
		sparks(sim, ex, ey, int(floorf(radius * 0.75)))
		sim.fx("embers", {"x": ex, "y": ey, "count": int(floorf(radius * 0.35))})

	sim.fx("fireball", {"x": ex, "y": ey, "r": maxf(8.0, radius * 0.35), "max_r": maxf(20.0, radius * 1.45), "urticating": is_urticating})
	sim.focus(ex, ey, null)
	if sim.turn_phase == CombatSim.Phase.RETREAT:
		sim.turn_phase = CombatSim.Phase.ACTION_WAIT

	sim.screen_shake.emit(radius * 0.38)
	sim.flash.emit(Vector2(ex, ey), 1.0)
	if radius >= 65.0 and sim.playing:
		sim.hit_stop.emit(0.055, false)
		sim.slow_mo.emit(0.45, false)

	shockwave(sim, ex, ey, 8.0, radius * 3.2, 1.0, "210, 125, 255" if is_urticating else "255, 225, 175")
	shockwave(sim, ex, ey, 4.0, radius * 1.95, 0.75, "245, 195, 255" if is_urticating else "255, 145, 70")

	terrain.carve_crater(ex, ey, radius)
	debris(sim, ex, ey, int(floorf(radius * 0.46)))

	var i: int = sim.surface_flora.size() - 1
	while i >= 0:
		var fl: SimFlora = sim.surface_flora[i]
		var d_fl: float = Vector2(fl.x - ex, fl.y - ey).length()
		if d_fl <= radius * 1.45 or not terrain.is_solid(fl.x, fl.y + 3.0):
			sim.surface_flora.remove_at(i)
			sim.fx("flora_uproot", {"x": fl.x, "y": fl.y, "type": fl.type, "from_x": ex})
		i -= 1

	if absf(ey - terrain.water_y) < radius * 1.5:
		water_plunge(sim, ex, terrain.water_y, SimMath.clamp_js(radius / 55.0, 0.5, 1.35))

	var hit_radius: float = radius * (2.1 if is_urticating else 1.68)
	SimBolso.on_explosion(sim, ex, ey, hit_radius, max_dmg)
	SimGoals.on_explosion(sim, ex, ey, hit_radius, max_dmg)

	i = sim.silk_nests.size() - 1
	while i >= 0:
		var nest: SimNest = sim.silk_nests[i]
		var d_nest: float = Vector2(nest.x - ex, nest.y - ey).length()
		if d_nest <= hit_radius + nest.r:
			sim.silk_nests.remove_at(i)
			burst_silk_nest(sim, nest)
		elif d_nest <= radius * 4.2:
			var push_dir: float = SimMath.sign_js(nest.x - ex)
			if push_dir == 0.0:
				push_dir = 1.0
			nest.swing_vel += push_dir * (1.0 - d_nest / (radius * 4.2)) * 12.0
		i -= 1

	for c in sim.crates:
		var d_c: float = Vector2(c.x - ex, c.y - ey).length()
		if d_c < hit_radius * 1.35 and d_c > 1.0:
			var f_c: float = 1.0 - d_c / (hit_radius * 1.35)
			c.vx += ((c.x - ex) / d_c) * 220.0 * f_c
			c.vy -= 160.0 * f_c
			c.grounded = false
	for m in sim.mines:
		var d_m: float = Vector2(m.x - ex, m.y - ey).length()
		if d_m < hit_radius * 1.25 and d_m > 1.0:
			var f_m: float = 1.0 - d_m / (hit_radius * 1.25)
			m.vx += ((m.x - ex) / d_m) * 240.0 * f_m
			m.vy -= 175.0 * f_m
			m.grounded = false
			m.triggered = true

	i = sim.rovellons.size() - 1
	while i >= 0:
		var rv: SimRovello = sim.rovellons[i]
		if Vector2(rv.x - ex, (rv.y - 8.0) - ey).length() <= hit_radius + rv.r:
			sim.rovellons.remove_at(i)
			sim.play("rovello_boing")
			smoke(sim, rv.x, rv.y - 10.0, 8, "ember")
			sim.ftext(rv.x, rv.y - 26.0, "FT_ROVELLO_ROASTED", Palette.FT_ORANGE, 1.6)
			for k in 2:
				var pn := SimNut.new()
				pn.x = rv.x + (-8.0 if k == 0 else 8.0)
				pn.y = rv.y - 14.0
				pn.vx = (-1.0 if k == 0 else 1.0) * (55.0 + sim.rand() * 55.0)
				pn.vy = -135.0 - sim.rand() * 55.0
				sim.pine_nuts.append(pn)
		i -= 1

	for f in sim.fighters:
		if not f.alive or f.drowning or f.is_hazard():
			continue
		var dx: float = f.x - ex
		var dy: float = (f.y - 4.0) - ey
		var dist: float = sqrt(dx * dx + dy * dy)
		if dist < hit_radius:
			var falloff: float = SimMath.clamp_js(1.0 - dist / hit_radius, 0.14, 1.0)
			var shield_mult: float = 0.80 if f.linked_allies.size() > 0 else 1.0
			var dmg: int = maxi(1, int(SimMath.round_js(max_dmg * falloff * shield_mult)))
			if (dmg >= 35 or f.hp <= dmg) and sim.playing:
				sim.hit_stop.emit(0.045, true)
				sim.slow_mo.emit(0.35, true)
			if is_urticating:
				f.urticating_ticks = 3
				sim.taunt(f, "URTICARIA", 2.2)
			elif sim.rand() < 0.55:
				sim.taunt(f, "HIT", 1.8)
			var label: String = ""
			if is_urticating:
				label = "DMG_URTICARIA"
			elif shield_mult < 1.0:
				label = "DMG_SILK_SHIELD"
			damage_fighter(sim, f, dmg, label)
			spawn_hairs(sim, f.x, f.y - 4.0, 8)

			var nx: float = dx / dist if dist > 1.0 else (sim.rand() - 0.5)
			var ny: float = dy / dist if dist > 1.0 else -1.0
			var imp: float = knockback * falloff
			f.vx += nx * imp
			f.vy = minf(f.vy, 0.0) + ny * imp - 155.0 * falloff
			f.grounded = false
			f.sliding = false
			f.is_voluntary_jump = false
			f.was_blasted = true
			f.jump_start_y = f.y
			f.peak_air_y = f.y
			f.hurt_timer = 1.0
			f.squash_x = 0.68
			f.squash_y = 1.42
			if sim.impact_tracked_worm == null or f != sim.active_fighter:
				sim.impact_tracked_worm = f

	i = sim.barrels.size() - 1
	while i >= 0:
		var b: SimBarrel = sim.barrels[i]
		var dist_b: float = Vector2(b.x - ex, b.y - ey).length()
		if dist_b < hit_radius:
			b.hp -= max_dmg * (1.0 - dist_b / hit_radius)
			if b.hp <= 0.0:
				sim.barrels.remove_at(i)
				sim.fx("wine_splash", {"x": b.x, "y": b.y})
				for f in sim.fighters:
					if f.alive and not f.drowning and Vector2(f.x - b.x, f.y - b.y).length() < 115.0:
						f.wine_tipsy = 2.0
						sim.ftext(f.x, f.y - 36.0, "FT_WINE_SPLASH", Palette.FT_WINE, 1.7)
				sim.schedule(0.07, {"kind": "barrel_blast", "x": b.x, "y": b.y})
			else:
				var nxb: float = (b.x - ex) / maxf(1.0, dist_b)
				b.vx += nxb * 240.0
				b.vy -= 210.0
				b.grounded = false
		i -= 1

	i = sim.escudelles.size() - 1
	while i >= 0:
		var ol: SimEscudella = sim.escudelles[i]
		if Vector2(ol.x - ex, ol.y - ey).length() <= hit_radius + ol.r:
			sim.escudelles.remove_at(i)
			sim.play("boom", {"scale": 0.9})
			smoke(sim, ol.x, ol.y - 8.0, 12, "steam")
			sim.ftext(ol.x, ol.y - 28.0, "FT_ESCUDELLA_EXPLODE", Palette.FT_GOLD_SOFT, 1.95)
			for g in 3:
				var ga: float = -PI * 0.5 + (g - 1) * 0.36 + (sim.rand() - 0.5) * 0.12
				var gsp: float = 210.0 + sim.rand() * 80.0
				var p := SimProjectile.new()
				p.type = "CARQUINYOLI"
				p.is_galet = true
				p.x = ol.x
				p.y = ol.y - 10.0
				p.vx = cos(ga) * gsp
				p.vy = sin(ga) * gsp
				p.r = 6.0
				p.wind_factor = 0.15
				p.bounces = true
				p.bounces_left = 2
				p.has_fuse = true
				p.fuse = 2.0 + g * 0.15
				p.last_sec = 0
				p.blast_r = 28.0
				p.max_dmg = 22.0
				p.knockback = 320.0
				p.ang = g
				sim.projectiles.append(p)
		i -= 1

	for k in spawn_clusters:
		var spread: float = (k - (spawn_clusters - 1) * 0.5) * 0.32 + (sim.rand() - 0.5) * 0.12
		var speed: float = 210.0 + sim.rand() * 90.0
		var bp := SimProjectile.new()
		bp.type = "BOMBLER"
		bp.x = ex
		bp.y = ey - 6.0
		bp.vx = sin(spread) * speed
		bp.vy = -cos(spread) * speed
		bp.r = 4.5
		bp.blast_r = 32.0
		bp.max_dmg = 24.0
		bp.knockback = 310.0
		sim.projectiles.append(bp)

	sim.hud()


# ---------------------------------------------------------------------------
# Weapons
# ---------------------------------------------------------------------------

static func _new_proj(type: String, x: float, y: float, vx: float, vy: float, r: float, wind_factor: float, bounces: bool, blast_r: float, max_dmg: float, knockback: float) -> SimProjectile:
	var p := SimProjectile.new()
	p.type = type
	p.x = x
	p.y = y
	p.vx = vx
	p.vy = vy
	p.r = r
	p.wind_factor = wind_factor
	p.bounces = bounces
	p.blast_r = blast_r
	p.max_dmg = max_dmg
	p.knockback = knockback
	return p


## JS fireWeapon: dispatch for all 16 weapons. `target_pt` is a Vector2 (airstrike target) or null.
static func fire_weapon(sim: CombatSim, wpn: WeaponDef, angle: float, power: float, target_pt: Variant) -> void:
	var af: SimFighter = sim.active_fighter
	if af == null or not af.alive or af.drowning:
		return
	var terrain: TerrainSim = sim.terrain
	sim.has_acted_or_moved_this_turn = true
	if not sim.is_current_turn_ai() and wpn.type == "CHARGE":
		af.last_aim_pitch = sim.aim_pitch
		af.last_charge_power = power

	var cur_ammo: float = sim.ammo_f(sim.active_team, wpn.id)
	if not is_inf(cur_ammo):
		sim.team_ammo[sim.active_team][wpn.id] = maxf(0.0, cur_ammo - 1.0)
	sim.hud()

	var dir_x: float = cos(angle)
	var dir_y: float = sin(angle)
	af.facing = 1 if dir_x >= 0.0 else -1

	var linked_count: int = mini(2, af.linked_allies.size())
	var castell_boost: float = 0.30 if af.castell_tower else 0.0
	var pilota_boost: float = 0.25 if af.pilota_buff else 0.0
	var dmg_boost: float = (1.0 + linked_count * 0.25 + castell_boost + pilota_boost + (0.15 if af.metamorphosed else 0.0)) * sim.damage_mult[af.team]
	var radius_boost: float = 1.0 + linked_count * 0.12 + (0.15 if af.castell_tower else 0.0) + (0.10 if af.pilota_buff else 0.0)
	var eff_dmg: int = int(SimMath.round_js(wpn.max_dmg * dmg_boost))
	if af.unit != null and af.unit.melee_damage > 0 and wpn.type == "MELEE":
		eff_dmg = af.unit.melee_damage
	var eff_blast_r: int = int(SimMath.round_js(wpn.blast_r * radius_boost))
	var eff_knockback: int = int(SimMath.round_js(wpn.knockback * (1.0 + pilota_boost)))

	if af.castell_tower:
		sim.ftext(af.x, af.y - 52.0, "FT_CASTELL", Palette.FT_GOLD_BRIGHT, 1.75)
	elif linked_count > 0:
		sim.ftext(af.x, af.y - 44.0, "FT_PROCESSION_FURY", Palette.FT_GOLD_SOFT, 1.6, [int(SimMath.round_js((dmg_boost - 1.0) * 100.0))])

	var muzzle_x: float = af.x + dir_x * 18.0
	var muzzle_y: float = (af.y - 4.0) + dir_y * 18.0

	match wpn.id:
		"BAZOOKA", "URTICARIA":
			sim.play("fire_bazooka")
			smoke(sim, muzzle_x, muzzle_y, 5, "urticating" if wpn.id == "URTICARIA" else "muzzle")
			var speed: float = 180.0 + power * 760.0
			var p: SimProjectile = _new_proj(wpn.id, muzzle_x, muzzle_y, dir_x * speed, dir_y * speed, 5.5, wpn.wind_factor, false, eff_blast_r, eff_dmg, wpn.knockback)
			p.is_urticating = wpn.id == "URTICARIA"
			sim.projectiles.append(p)
			sim.turn_phase = CombatSim.Phase.ACTION_WAIT
		"CARQUINYOLI":
			sim.play("carquinyoli_crunch")
			sim.play("jump")
			sim.ftext(af.x, af.y - 30.0, "FT_CARQUINYOLIS", Palette.FT_GOLD, 1.65)
			for k in 3:
				var a: float = angle + (k - 1) * 0.085
				var sp: float = (210.0 + power * 680.0) * (1.0 - absf(float(k - 1)) * 0.06)
				var p: SimProjectile = _new_proj("CARQUINYOLI", muzzle_x, muzzle_y, cos(a) * sp, sin(a) * sp, 5.5, wpn.wind_factor, true, eff_blast_r, eff_dmg, wpn.knockback)
				p.bounces_left = 3
				p.has_fuse = true
				p.fuse = 2.3 + k * 0.16
				p.last_sec = 0
				p.ang = k * 1.1
				sim.projectiles.append(p)
			sim.turn_phase = CombatSim.Phase.ACTION_WAIT
		"GRENADE", "CLUSTER", "HOLY":
			sim.play("jump")
			var speed: float = 150.0 + power * 680.0
			var fuse_val: float = float(sim.custom_grenade_fuse) if wpn.has_custom_fuse else wpn.fuse
			var p: SimProjectile = _new_proj(wpn.id, muzzle_x, muzzle_y, dir_x * speed, dir_y * speed, 8.0 if wpn.id == "HOLY" else 6.0, 0.0, true, eff_blast_r, eff_dmg, wpn.knockback)
			p.has_fuse = true
			p.fuse = fuse_val
			p.last_sec = int(ceilf(fuse_val))
			p.clusters = 5 if wpn.id == "CLUSTER" else 0
			sim.projectiles.append(p)
			sim.turn_phase = CombatSim.Phase.ACTION_WAIT
		"SHOTGUN":
			_fire_shotgun(sim, af, wpn, muzzle_x, muzzle_y, dir_x, dir_y, eff_blast_r, eff_dmg)
		"FUET", "BAT", "EMPENTA", "MOSSEGADA", "PICOTADA", "PICOTADA_FORTA", "PERXADA":
			_fire_melee(sim, af, wpn, muzzle_x, muzzle_y, dir_x, dir_y, eff_dmg, eff_knockback)
		"DYNAMITE":
			sim.play("tick")
			sim.ftext(af.x, af.y - 30.0, "FT_TIO", Palette.FT_GOLD_SOFT, 1.8)
			var p: SimProjectile = _new_proj("DYNAMITE", af.x + af.facing * 12.0, af.y - 6.0, af.facing * 28.0, -40.0, 7.0, 0.0, true, eff_blast_r, eff_dmg, wpn.knockback)
			p.has_fuse = true
			p.fuse = wpn.fuse
			p.last_sec = int(ceilf(wpn.fuse))
			sim.projectiles.append(p)
			sim.turn_phase = CombatSim.Phase.RETREAT
			sim.phase_timer = 4.0
		"AIRSTRIKE":
			sim.play("jet")
			var tx_v: float = (target_pt as Vector2).x if target_pt != null else SimTables.TERRAIN_W * 0.5
			var from_left: bool = tx_v >= SimTables.TERRAIN_W * 0.5
			var pl := SimPlane.new()
			pl.x = tx_v - 720.0 if from_left else tx_v + 720.0
			pl.vx = 820.0 if from_left else -820.0
			pl.target_x = tx_v
			sim.airstrike_planes.append(pl)
			sim.turn_phase = CombatSim.Phase.ACTION_WAIT
		"JETPACK":
			sim.play("jet")
			af.jet_fuel = 100.0
			af.grounded = false
			af.is_voluntary_jump = true
			af.jump_start_y = af.y
			af.vy = -150.0
			sim.ftext(af.x, af.y - 28.0, "FT_JETPACK", Palette.FT_GOLD, 1.8)
			sim.selected_weapon_idx = 0
			if not sim.is_current_turn_ai():
				sim.team_selected_weapon_idx[sim.active_team] = 0
			sim.hud()
		"CULLERA":
			sim.play("spoon_scoop")
			sim.play("worm_voice", {"kind": "ATTACK"})
			af.spoon_timer = 2.15
			af.spoon_angle = SimMath.clamp_js(angle, -PI * 0.85, PI * 0.85)
			af.spoon_tick = 0.0
			sim.ftext(af.x, af.y - 32.0, "FT_SPOON", Palette.FT_GOLD, 1.75)
			sim.turn_phase = CombatSim.Phase.ACTION_WAIT
		"BARRINA":
			sim.play("drill_bore")
			var d_ang: float = angle
			if sin(d_ang) < 0.22:
				d_ang = 1.05 if af.facing >= 0 else (PI - 1.05)
			af.drill_timer = 1.95
			af.drill_angle = d_ang
			af.drill_tick = 0.0
			sim.ftext(af.x, af.y - 32.0, "FT_DRILL", Palette.FT_AMBER, 1.75)
			sim.turn_phase = CombatSim.Phase.ACTION_WAIT
		"PONT_PEDRA":
			sim.play("stone_build")
			var gx: float = af.x + dir_x * 52.0
			var gy: float = (af.y - 4.0) + dir_y * 52.0
			terrain.build_girder(gx, gy, angle, 82.0, 16.0)
			smoke(sim, gx, gy, 10, "stone")
			debris(sim, gx, gy, 8)
			sim.ftext(gx, gy - 22.0, "FT_GIRDER", Palette.FT_STONE, 1.85)
			sim.turn_phase = CombatSim.Phase.RETREAT
			sim.phase_timer = 2.8
		"GANXO":
			_fire_hook(sim, af, muzzle_x, muzzle_y, dir_x, dir_y, eff_dmg)


static func _fire_shotgun(sim: CombatSim, af: SimFighter, wpn: WeaponDef, muzzle_x: float, muzzle_y: float, dir_x: float, dir_y: float, eff_blast_r: int, eff_dmg: int) -> void:
	sim.play("shotgun")
	smoke(sim, muzzle_x, muzzle_y, 5, "muzzle")
	sparks(sim, muzzle_x, muzzle_y, 8)
	var hit_x: float = muzzle_x
	var hit_y: float = muzzle_y
	var d: float = 4.0
	while d < 920.0:
		var rx: float = muzzle_x + dir_x * d
		var ry: float = muzzle_y + dir_y * d
		var hit_something: bool = sim.terrain.is_solid(rx, ry)
		if not hit_something:
			for f in sim.fighters:
				if f != af and f.alive and not f.drowning and Vector2(f.x - rx, (f.y - 4.0) - ry).length() <= f.r + 4.0:
					hit_something = true
					break
		if not hit_something:
			for b in sim.barrels:
				if Vector2(b.x - rx, b.y - ry).length() <= b.r + 3.0:
					hit_something = true
					break
		if not hit_something:
			for nest in sim.silk_nests:
				if Vector2(nest.x - rx, nest.y - ry).length() <= nest.r + 3.0:
					hit_something = true
					break
		hit_x = rx
		hit_y = ry
		if hit_something:
			break
		d += 3.0
	sim.fx("beam", {"x1": muzzle_x, "y1": muzzle_y, "x2": hit_x, "y2": hit_y, "life": 0.22})
	trigger_explosion(sim, hit_x, hit_y, eff_blast_r, eff_dmg, wpn.knockback, 0, false)
	sim.shotgun_shots_left = 0
	sim.turn_phase = CombatSim.Phase.ACTION_WAIT


static func _fire_melee(sim: CombatSim, af: SimFighter, wpn: WeaponDef, muzzle_x: float, muzzle_y: float, dir_x: float, dir_y: float, eff_dmg: int, eff_knockback: int) -> void:
	var is_fuet: bool = wpn.id == "FUET"
	af.bat_swing_timer = 0.48
	af.last_melee_id = wpn.id
	if is_fuet:
		sim.play("fuet_whip")
	sim.play("worm_voice", {"kind": "ATTACK"})
	if is_fuet:
		smoke(sim, muzzle_x + dir_x * 10.0, muzzle_y + dir_y * 10.0, 8, "flour")
	var reach: float = wpn.reach
	var hit_anyone: bool = false

	for p in sim.projectiles:
		if Vector2(p.x - af.x, p.y - af.y).length() <= reach + 18.0:
			p.vx = dir_x * 640.0
			p.vy = dir_y * 640.0 - 115.0
			if p.has_fuse:
				p.fuse = maxf(p.fuse, 1.8)
			hit_anyone = true
			sim.play("home_run")
			sim.ftext(p.x, p.y - 26.0, "FT_BAT_DEFLECT", Palette.FT_GOLD_BRIGHT, 1.5)

	for f in sim.fighters:
		if f != af and f.alive and not f.drowning and not f.is_hazard() and (af.unit == null or f.team != af.team):
			var dist: float = Vector2(f.x - af.x, f.y - af.y).length()
			if dist <= reach:
				hit_anyone = true
				damage_fighter(sim, f, eff_dmg, "DMG_" + wpn.id)
				f.vx = dir_x * eff_knockback
				f.vy = minf(-185.0 if is_fuet else -210.0, dir_y * eff_knockback - (95.0 if is_fuet else 120.0))
				f.grounded = false
				f.sliding = false
				f.is_voluntary_jump = false
				f.was_blasted = true
				f.jump_start_y = f.y
				f.peak_air_y = f.y
				f.dizzy_timer = 2.8
				f.squash_x = 0.52
				f.squash_y = 1.65
				sim.impact_tracked_worm = f
				sim.focus(f.x, f.y, f)
				spawn_hairs(sim, f.x, f.y - 4.0, 22)
				if is_fuet:
					smoke(sim, f.x, f.y - 4.0, 10, "flour")
				shockwave(sim, f.x, f.y - 4.0, 4.0, 64.0 if is_fuet else 55.0, 1.0)
	if hit_anyone:
		sim.play("home_run")
		if sim.playing:
			sim.hit_stop.emit(0.068, false)
			sim.slow_mo.emit(0.52, false)
		sim.screen_shake.emit(15.0)
		sim.turn_phase = CombatSim.Phase.ACTION_WAIT
	elif is_fuet:
		sim.ftext(af.x, af.y - 28.0, "FT_FUET_SLICE", Palette.FT_WHIP, 1.3)
		var p: SimProjectile = _new_proj("CARQUINYOLI", muzzle_x, muzzle_y, dir_x * 520.0, dir_y * 520.0 - 40.0, 5.5, 0.2, false, 26.0, SimMath.round_js(eff_dmg * 0.75), 480.0)
		p.is_fuet_slice = true
		sim.projectiles.append(p)
		sim.turn_phase = CombatSim.Phase.ACTION_WAIT
	else:
		sim.play("jump")
		sim.turn_phase = CombatSim.Phase.RETREAT
		sim.phase_timer = 2.2


static func _fire_hook(sim: CombatSim, af: SimFighter, muzzle_x: float, muzzle_y: float, dir_x: float, dir_y: float, eff_dmg: int) -> void:
	var terrain: TerrainSim = sim.terrain
	sim.play("grapple_whip")
	var hit_x: float = muzzle_x
	var hit_y: float = muzzle_y
	var latched_terrain: bool = false
	var hooked_enemy: SimFighter = null
	var hooked_barrel: SimBarrel = null

	var d: float = 12.0
	while d <= 480.0:
		var rx: float = muzzle_x + dir_x * d
		var ry: float = muzzle_y + dir_y * d
		if ry >= terrain.water_y - 6.0 or rx < 20.0 or rx > SimTables.TERRAIN_W - 20.0:
			break
		for f in sim.fighters:
			if f != af and f.alive and not f.drowning and Vector2(f.x - rx, (f.y - 4.0) - ry).length() <= f.r + 8.0:
				hooked_enemy = f
				hit_x = f.x
				hit_y = f.y - 4.0
				break
		if hooked_enemy != null:
			break
		for b in sim.barrels:
			if Vector2(b.x - rx, b.y - ry).length() <= b.r + 6.0:
				hooked_barrel = b
				hit_x = b.x
				hit_y = b.y
				break
		if hooked_barrel != null:
			break
		if terrain.is_solid(rx, ry):
			latched_terrain = true
			hit_x = rx
			hit_y = ry
			break
		d += 4.0

	if hooked_enemy != null:
		damage_fighter(sim, hooked_enemy, eff_dmg, "DMG_HOOK")
		hooked_enemy.vx = -dir_x * 360.0
		hooked_enemy.vy = minf(-160.0, -dir_y * 280.0 - 95.0)
		hooked_enemy.grounded = false
		hooked_enemy.sliding = false
		hooked_enemy.was_blasted = true
		hooked_enemy.dizzy_timer = 2.0
		sim.impact_tracked_worm = hooked_enemy
		sim.focus(hooked_enemy.x, hooked_enemy.y, hooked_enemy)
		sim.fx("beam", {"x1": muzzle_x, "y1": muzzle_y, "x2": hit_x, "y2": hit_y, "life": 0.32})
		sim.turn_phase = CombatSim.Phase.ACTION_WAIT
	elif hooked_barrel != null:
		hooked_barrel.vx = -dir_x * 310.0
		hooked_barrel.vy = -170.0
		hooked_barrel.grounded = false
		sim.fx("beam", {"x1": muzzle_x, "y1": muzzle_y, "x2": hit_x, "y2": hit_y, "life": 0.32})
		sim.turn_phase = CombatSim.Phase.RETREAT
		sim.phase_timer = 2.4
	elif latched_terrain:
		terrain.carve_crater(hit_x - dir_x * 10.0, hit_y - dir_y * 10.0, 15.0)
		af.grapple = {
			"start_x": af.x, "start_y": af.y,
			"target_x": SimMath.clamp_js(hit_x - dir_x * 14.0, 28.0, SimTables.TERRAIN_W - 28.0),
			"target_y": SimMath.clamp_js(hit_y - dir_y * 14.0, 42.0, terrain.water_y - 28.0),
			"hook_x": hit_x, "hook_y": hit_y, "progress": 0.0,
		}
		af.grounded = false
		af.sliding = false
		af.is_voluntary_jump = true
		af.was_blasted = false
		sim.ftext(af.x, af.y - 30.0, "FT_GRAPPLE", Palette.FT_GOLD_SOFT, 1.55)
		sim.turn_phase = CombatSim.Phase.ACTION_WAIT
	else:
		sim.fx("beam", {"x1": muzzle_x, "y1": muzzle_y, "x2": muzzle_x + dir_x * 260.0, "y2": muzzle_y + dir_y * 260.0, "life": 0.22})
		sim.ftext(af.x, af.y - 26.0, "FT_GRAPPLE_SHORT", Palette.FT_GREY, 1.2)
		sim.turn_phase = CombatSim.Phase.RETREAT
		sim.phase_timer = 2.0

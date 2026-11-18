## stepPhysics of the JS for everything that is not a fighter: planes, crates, mines, projectiles, nests, webs,
## pickups, nuts, larvae, barrels and tombstones; then the fighters (SimFighterStep). Update order is faithful.
class_name SimPhysics
extends RefCounted

const GRAVITY: float = SimTables.GRAVITY
const SUBS: int = 4


static func step(sim: CombatSim, dt: float) -> void:
	_step_planes(sim, dt)
	_step_crates(sim, dt)
	_step_mines(sim, dt)
	_step_projectiles(sim, dt)
	_step_nests_and_webs(sim, dt)
	_step_rovellons(sim, dt)
	_step_caganers(sim, dt)
	_step_escudelles(sim, dt)
	_step_nuts(sim, dt)
	_step_larvae(sim, dt)
	_step_barrels(sim, dt)
	_step_tombstones(sim, dt)
	SimFighterStep.step(sim, dt)


static func _step_planes(sim: CombatSim, dt: float) -> void:
	var i: int = sim.airstrike_planes.size() - 1
	while i >= 0:
		var pl: SimPlane = sim.airstrike_planes[i]
		pl.x += pl.vx * dt
		for k in 5:
			if not pl.dropped[k]:
				var drop_x: float = pl.target_x + pl.offsets[k]
				if (pl.vx > 0.0 and pl.x >= drop_x) or (pl.vx < 0.0 and pl.x <= drop_x):
					pl.dropped[k] = true
					sim.play("fire_bazooka")
					var p := SimProjectile.new()
					p.type = "BAZOOKA"
					p.x = pl.x
					p.y = pl.y + 14.0
					p.vx = pl.vx * 0.22
					p.vy = 140.0
					p.r = 5.0
					p.wind_factor = 0.4
					p.blast_r = 42.0
					p.max_dmg = 38.0
					p.knockback = 390.0
					sim.projectiles.append(p)
		if absf(pl.x - pl.target_x) > 820.0 or pl.x < -300.0 or pl.x > SimTables.TERRAIN_W + 300.0:
			sim.airstrike_planes.remove_at(i)
		i -= 1


static func _step_crates(sim: CombatSim, dt: float) -> void:
	var terrain: TerrainSim = sim.terrain
	var wy: float = terrain.water_y
	var i: int = sim.crates.size() - 1
	while i >= 0:
		var c: SimCrate = sim.crates[i]
		if not c.grounded:
			if c.parachuting:
				c.vx = lerpf(c.vx, sim.wind * 0.45, dt * 3.0)
				c.vy = 62.0
			else:
				c.vy += GRAVITY * dt
			c.x += c.vx * dt
			c.y += c.vy * dt
			if c.y >= wy:
				sim.play("plunge")
				SimCombat.water_plunge(sim, c.x, wy, 0.7)
				sim.crates.remove_at(i)
				i -= 1
				continue
			if terrain.is_solid(c.x, c.y + 11.0):
				while terrain.is_solid(c.x, c.y + 10.0) and c.y > 0.0:
					c.y -= 1.0
				c.vx = 0.0
				c.vy = 0.0
				c.parachuting = false
				c.grounded = true
				sim.play("bounce")
		elif not terrain.is_solid(c.x, c.y + 13.0):
			c.grounded = false
			c.parachuting = false

		for f in sim.fighters:
			if f.alive and not f.drowning and Vector2(f.x - c.x, f.y - c.y).length() <= 24.0:
				if not c.grounded and not c.parachuting and c.vy > 140.0:
					SimCombat.damage_fighter(sim, f, 18, "DMG_CRATE")
					f.squash_x = 1.32
					f.squash_y = 0.68
					sim.play("bounce")
					if not f.alive:
						sim.crates.remove_at(i)
						break
				sim.play("crate_pickup")
				if c.is_medkit:
					f.hp = mini(150, f.hp + 35)
					f.urticating_ticks = 0
					sim.ftext(f.x, f.y - 28.0, "FT_MEDKIT", Palette.FT_GREEN, 1.65)
					sim.hud()
				else:
					var cur: float = float(sim.team_ammo[f.team].get(c.reward_wpn, 0.0))
					sim.team_ammo[f.team][c.reward_wpn] = cur + 1.0
					var widx: int = sim.weapon_index(c.reward_wpn)
					var wname: String = sim.tx(sim.weapons[widx].name_key).to_upper() if widx >= 0 else c.reward_wpn
					sim.ftext(f.x, f.y - 28.0, "FT_CRATE_WEAPON", Palette.FT_GOLD, 1.65, [wname])
					sim.hud()
				sim.crates.remove_at(i)
				break
		i -= 1


static func _step_mines(sim: CombatSim, dt: float) -> void:
	var terrain: TerrainSim = sim.terrain
	var i: int = sim.mines.size() - 1
	while i >= 0:
		var m: SimMine = sim.mines[i]
		if not m.grounded:
			m.vy += GRAVITY * dt
			m.x += m.vx * dt
			m.y += m.vy * dt
			if m.y >= terrain.water_y:
				sim.mines.remove_at(i)
				i -= 1
				continue
			if terrain.is_solid(m.x, m.y + 5.0):
				while terrain.is_solid(m.x, m.y + 4.0) and m.y > 0.0:
					m.y -= 1.0
				m.vx = 0.0
				m.vy = 0.0
				m.grounded = true
		elif not terrain.is_solid(m.x, m.y + 7.0):
			m.grounded = false

		if not m.triggered:
			for f in sim.fighters:
				if f.alive and not f.drowning and Vector2(f.x - m.x, f.y - m.y).length() < 38.0:
					m.triggered = true
					m.beep_timer = 0.0
					sim.play("mine_beep")
					sim.ftext(m.x, m.y - 18.0, "FT_MINE_ARMED", Palette.FT_RED, 1.2)
					break
		else:
			m.fuse -= dt
			m.beep_timer -= dt
			if m.beep_timer <= 0.0:
				m.beep_timer = maxf(0.12, m.fuse * 0.28)
				sim.play("mine_beep")
			if m.fuse <= 0.0:
				sim.mines.remove_at(i)
				SimCombat.trigger_explosion(sim, m.x, m.y, 50.0, 48.0, 480.0, 0, false)
		i -= 1


static func _explode_projectile(sim: CombatSim, p: SimProjectile, clusters: int, urticating: bool) -> void:
	SimCombat.trigger_explosion(sim, p.x, p.y, p.blast_r, p.max_dmg, p.knockback, clusters, urticating)


static func _step_projectiles(sim: CombatSim, dt: float) -> void:
	var terrain: TerrainSim = sim.terrain
	var wy: float = terrain.water_y
	var sdt: float = dt / SUBS
	for i in range(sim.projectiles.size() - 1, -1, -1):
		var p: SimProjectile = sim.projectiles[i]
		p.age += dt

		if p.age > 8.0 or p.x < -380.0 or p.x > SimTables.TERRAIN_W + 380.0 or p.y > wy + 60.0:
			sim.projectiles.remove_at(i)
			if p.has_fuse and p.x >= -100.0 and p.x <= SimTables.TERRAIN_W + 100.0 and p.y < wy:
				_explode_projectile(sim, p, p.clusters, p.is_urticating)
			continue

		if p.has_fuse:
			p.fuse -= dt
			if p.type == "HOLY" and not p.choir_played and p.fuse <= 1.35:
				p.choir_played = true
				sim.play("hallelujah")
				sim.ftext(p.x, p.y - 24.0, "FT_HOLY_CHOIR", Palette.FT_GOLD, 1.3)
			var sec: int = int(ceilf(p.fuse))
			if sec < p.last_sec and sec > 0:
				p.last_sec = sec
				sim.play("tick")
			if p.fuse <= 0.0:
				if p.type == "DYNAMITE":
					sim.ftext(p.x, p.y - 26.0, "FT_DYNAMITE_BOOM", Palette.FT_AMBER, 1.4)
				sim.projectiles.remove_at(i)
				_explode_projectile(sim, p, p.clusters, p.is_urticating)
				continue

		var exploded: bool = false
		for s in SUBS:
			p.vx += (sim.wind * 2.4 * p.wind_factor) * sdt
			for u in sim.updrafts:
				if absf(p.x - u.x) < u.w and p.y < u.y and p.y > u.y - u.h:
					p.vy -= 145.0 * sdt
			p.vy += GRAVITY * sdt
			p.x += p.vx * sdt
			p.y += p.vy * sdt
			p.ang += p.vx * 0.015 * sdt

			if p.y >= wy:
				sim.play("plunge")
				SimCombat.water_plunge(sim, p.x, wy, 0.75)
				sim.focus(p.x, wy - 24.0, null)
				sim.projectiles.remove_at(i)
				exploded = true
				break

			var ni: int = sim.silk_nests.size() - 1
			while ni >= 0:
				var nest: SimNest = sim.silk_nests[ni]
				if Vector2(p.x - nest.x, p.y - nest.y).length() <= nest.r + p.r + 2.0:
					sim.silk_nests.remove_at(ni)
					SimCombat.burst_silk_nest(sim, nest)
					sim.projectiles.remove_at(i)
					SimCombat.trigger_explosion(sim, p.x, p.y, p.blast_r * 0.75, p.max_dmg, p.knockback, p.clusters, p.is_urticating)
					exploded = true
					break
				ni -= 1
			if exploded:
				break

			for c in sim.crates:
				if c.parachuting and Vector2(p.x - c.x, p.y - (c.y - 20.0)).length() <= 18.0:
					c.parachuting = false
					sim.play("carquinyoli_crunch")
					SimCombat.spawn_hairs(sim, c.x, c.y - 18.0, 10)
					sim.ftext(c.x, c.y - 30.0, "FT_PARACHUTE_CUT", Palette.FT_ORANGE, 1.5)

			if p.age > 0.08:
				var wi: int = sim.silk_webs.size() - 1
				while wi >= 0:
					var w: SimWeb = sim.silk_webs[wi]
					var dx_w: float = w.x2 - w.x1
					var dy_w: float = w.y2 - w.y1
					var len_sq: float = dx_w * dx_w + dy_w * dy_w
					if len_sq > 1.0:
						var t_proj: float = SimMath.clamp_js(((p.x - w.x1) * dx_w + (p.y - w.y1) * dy_w) / len_sq, 0.0, 1.0)
						var close_x: float = w.x1 + t_proj * dx_w
						var close_y: float = w.y1 + t_proj * dy_w
						var dist_w: float = Vector2(p.x - close_x, p.y - close_y).length()
						if dist_w <= p.r + 5.0 and p.last_web_bounce < p.age - 0.12:
							var ln: float = sqrt(len_sq)
							var nx: float = -dy_w / ln
							var ny: float = dx_w / ln
							if p.vx * nx + p.vy * ny > 0.0:
								nx = -nx
								ny = -ny
							var vn: float = p.vx * nx + p.vy * ny
							p.vx = (p.vx - 2.0 * vn * nx) * 0.92
							p.vy = (p.vy - 2.0 * vn * ny) * 0.92
							p.last_web_bounce = p.age
							w.vibration = 1.0
							w.hp -= 1
							sim.play("bounce")
							sim.ftext(close_x, close_y - 12.0, "FT_WEB_RICOCHET", Palette.FT_CREAM, 1.1)
							if w.hp <= 0:
								sim.silk_webs.remove_at(wi)
							break
					wi -= 1

			if p.age > 0.06:
				for f in sim.fighters:
					if f.alive and not f.drowning and Vector2(f.x - p.x, (f.y - 4.0) - p.y).length() <= f.r + p.r:
						if not p.bounces:
							sim.projectiles.remove_at(i)
							SimCombat.trigger_explosion(sim, p.x, p.y, p.blast_r, p.max_dmg, p.knockback, 0, p.is_urticating)
							exploded = true
							break
						elif p.type == "CARQUINYOLI" and p.last_fighter_hit < p.age - 0.16:
							p.last_fighter_hit = p.age
							sim.play("carquinyoli_crunch")
							SimCombat.damage_fighter(sim, f, 12, "DMG_CARQUINYOLI_BITE")
							f.vx += SimMath.sign_js(p.vx if p.vx != 0.0 else 1.0) * 165.0
							f.vy = minf(f.vy, -110.0)
							f.grounded = false
							f.was_blasted = true
							f.peak_air_y = f.y
							f.squash_x = 0.72
							f.squash_y = 1.35
							sim.impact_tracked_worm = f
							sim.focus(f.x, f.y, f)
							SimCombat.sparks(sim, p.x, p.y, 10)
							p.vx = -p.vx * 0.65
							p.vy = -absf(p.vy) * 0.65 - 60.0
							break
				if exploded:
					break

			if terrain.is_solid(p.x, p.y):
				if not p.bounces:
					sim.projectiles.remove_at(i)
					_explode_projectile(sim, p, p.clusters, p.is_urticating)
					exploded = true
					break
				p.x -= p.vx * sdt
				p.y -= p.vy * sdt
				if p.type == "CARQUINYOLI":
					p.bounces_left -= 1
					sim.play("carquinyoli_crunch")
					SimCombat.debris(sim, p.x, p.y, 5)
					if p.bounces_left <= 0:
						sim.projectiles.remove_at(i)
						SimCombat.trigger_explosion(sim, p.x, p.y, p.blast_r, p.max_dmg, p.knockback, 0, false)
						exploded = true
						break
				var n: Vector2 = terrain.surface_normal(p.x, p.y)
				var vn2: float = p.vx * n.x + p.vy * n.y
				if vn2 < 0.0:
					var restitution: float = 0.82 if p.type == "CARQUINYOLI" else (0.15 if p.type == "DYNAMITE" else (0.42 if p.type == "HOLY" else 0.62))
					var friction: float = 0.94 if p.type == "CARQUINYOLI" else (0.35 if p.type == "DYNAMITE" else 0.88)
					var tx_v: float = -n.y
					var ty_v: float = n.x
					var vt: float = p.vx * tx_v + p.vy * ty_v
					p.vx = (-vn2 * restitution) * n.x + (vt * friction) * tx_v
					p.vy = (-vn2 * restitution) * n.y + (vt * friction) * ty_v
					if absf(vn2) > 65.0 and p.type != "CARQUINYOLI":
						sim.play("bounce")

		if not exploded:
			p.trail.append(Vector2(p.x, p.y))
			if p.trail.size() > 14:
				p.trail.remove_at(0)
			if not p.whistled and p.age > 0.45 and p.vy > 210.0 and p.y < wy - 120.0 and (p.type == "BAZOOKA" or p.type == "HOLY" or p.type == "CLUSTER"):
				p.whistled = true
				sim.play("shell_whistle")


static func _step_nests_and_webs(sim: CombatSim, dt: float) -> void:
	for nest in sim.silk_nests:
		var wind_torque: float = sim.wind * 0.0045 + sin(sim.t_now * 2.4 + nest.sway_phase) * (0.14 + absf(float(sim.wind)) * 0.002)
		nest.swing_vel = (nest.swing_vel + (wind_torque - nest.swing_angle * 6.5) * dt) * pow(0.28, dt)
		nest.swing_angle = SimMath.clamp_js(nest.swing_angle + nest.swing_vel * dt, -0.95, 0.95)
		nest.x = nest.anchor_x + sin(nest.swing_angle) * 28.0
		nest.y = nest.anchor_y + cos(nest.swing_angle) * 28.0
	for w in sim.silk_webs:
		if w.vibration > 0.0:
			w.vibration = maxf(0.0, w.vibration - dt * 2.2)


static func _step_rovellons(sim: CombatSim, dt: float) -> void:
	var i: int = sim.rovellons.size() - 1
	while i >= 0:
		var rv: SimRovello = sim.rovellons[i]
		rv.squash = lerpf(rv.squash, 1.0, minf(1.0, dt * 9.0))
		if not sim.terrain.is_solid(rv.x, rv.y + 3.0):
			rv.y += 140.0 * dt
			if rv.y >= sim.terrain.water_y:
				sim.rovellons.remove_at(i)
		i -= 1


static func _step_caganers(sim: CombatSim, dt: float) -> void:
	var i: int = sim.caganers.size() - 1
	while i >= 0:
		var cg: SimCaganer = sim.caganers[i]
		if not sim.terrain.is_solid(cg.x, cg.y + 10.0):
			cg.y += 140.0 * dt
			if cg.y >= sim.terrain.water_y:
				sim.caganers.remove_at(i)
				i -= 1
				continue
		for f in sim.fighters:
			if f.alive and not f.drowning and Vector2(f.x - cg.x, f.y - cg.y).length() <= f.r + cg.r + 10.0:
				sim.play("caganer_blessing")
				f.hp = mini(160, f.hp + 30)
				f.urticating_ticks = 0
				sim.team_ammo[f.team]["HOLY"] = float(sim.team_ammo[f.team].get("HOLY", 0.0)) + 1.0
				sim.team_ammo[f.team]["DYNAMITE"] = float(sim.team_ammo[f.team].get("DYNAMITE", 0.0)) + 1.0
				SimCombat.shockwave(sim, cg.x, cg.y, 5.0, 65.0, 1.0, "255, 215, 90")
				SimCombat.sparks(sim, cg.x, cg.y, 18)
				sim.bubble(f, "BUBBLE_CAGANER", 2.4)
				sim.ftext(cg.x, cg.y - 34.0, "FT_CAGANER", Palette.FT_GOLD_BRIGHT, 2.2)
				sim.hud()
				sim.caganers.remove_at(i)
				break
		i -= 1


static func _step_escudelles(sim: CombatSim, dt: float) -> void:
	var i: int = sim.escudelles.size() - 1
	while i >= 0:
		var ol: SimEscudella = sim.escudelles[i]
		if not sim.terrain.is_solid(ol.x, ol.y + 13.0):
			ol.y += 140.0 * dt
			if ol.y >= sim.terrain.water_y:
				sim.escudelles.remove_at(i)
				i -= 1
				continue
		for f in sim.fighters:
			if f.alive and not f.drowning and Vector2(f.x - ol.x, f.y - ol.y).length() <= f.r + ol.r + 8.0:
				sim.play("crate_pickup")
				f.hp = mini(165, f.hp + 25)
				f.pilota_buff = true
				f.urticating_ticks = 0
				SimCombat.sparks(sim, ol.x, ol.y - 6.0, 14)
				sim.bubble(f, "BUBBLE_ESCUDELLA", 2.3)
				sim.ftext(ol.x, ol.y - 32.0, "FT_ESCUDELLA_BUFF", Palette.FT_GOLD_BRIGHT, 2.1)
				sim.hud()
				sim.escudelles.remove_at(i)
				break
		i -= 1


static func _step_nuts(sim: CombatSim, dt: float) -> void:
	var terrain: TerrainSim = sim.terrain
	var i: int = sim.pine_nuts.size() - 1
	while i >= 0:
		var pn: SimNut = sim.pine_nuts[i]
		pn.life -= dt
		if pn.life <= 0.0 or pn.y >= terrain.water_y:
			sim.pine_nuts.remove_at(i)
			i -= 1
			continue
		if not pn.grounded:
			pn.vy += GRAVITY * dt
			pn.x += pn.vx * dt
			pn.y += pn.vy * dt
			if terrain.is_solid(pn.x, pn.y + pn.r):
				while terrain.is_solid(pn.x, pn.y + pn.r - 1.0) and pn.y > 0.0:
					pn.y -= 1.0
				pn.vy = -pn.vy * 0.38
				pn.vx *= 0.65
				if absf(pn.vy) < 22.0:
					pn.vy = 0.0
					pn.vx = 0.0
					pn.grounded = true
		elif not terrain.is_solid(pn.x, pn.y + pn.r + 2.0):
			pn.grounded = false

		for f in sim.fighters:
			if f.alive and not f.drowning and Vector2(f.x - pn.x, f.y - pn.y).length() <= f.r + pn.r + 6.0:
				sim.play("crate_pickup")
				f.max_hp = mini(160, f.max_hp + 15)
				f.hp = mini(f.max_hp, f.hp + 20)
				f.urticating_ticks = 0
				sim.ftext(f.x, f.y - 30.0, "FT_PINE_NUT", Palette.FT_GOLD_SOFT, 1.75)
				sim.hud()
				sim.pine_nuts.remove_at(i)
				break
		i -= 1


static func _step_larvae(sim: CombatSim, dt: float) -> void:
	var terrain: TerrainSim = sim.terrain
	var i: int = sim.larvae_swarms.size() - 1
	while i >= 0:
		var sw: SimLarvae = sim.larvae_swarms[i]
		sw.life -= dt
		if sw.life <= 0.0 or sw.y >= terrain.water_y:
			sim.larvae_swarms.remove_at(i)
			i -= 1
			continue
		var nearest: SimFighter = null
		var best_d: float = INF
		for f in sim.fighters:
			if f.alive and not f.drowning:
				var d: float = Vector2(f.x - sw.x, f.y - sw.y).length()
				if d < best_d:
					best_d = d
					nearest = f
		if nearest != null:
			var dir_v: float = SimMath.sign_js(nearest.x - sw.x)
			sw.vx = lerpf(sw.vx, dir_v * 88.0, dt * 5.0)
		if not terrain.is_solid(sw.x, sw.y + 5.0):
			sw.vy = minf(260.0, sw.vy + GRAVITY * dt)
		else:
			while terrain.is_solid(sw.x, sw.y + 4.0) and sw.y > 0.0:
				sw.y -= 1.0
			sw.vy = -55.0
		sw.x += sw.vx * dt
		sw.y += sw.vy * dt

		sw.tick_timer -= dt
		if sw.tick_timer <= 0.0 and nearest != null and best_d < 22.0:
			sw.tick_timer = 0.65
			SimCombat.damage_fighter(sim, nearest, 4, "DMG_LARVAE")
			nearest.squash_x = 1.18
			nearest.squash_y = 0.85
			nearest.hurt_timer = 0.35
			SimCombat.spawn_hairs(sim, nearest.x, nearest.y, 4)
		i -= 1


static func _step_barrels(sim: CombatSim, dt: float) -> void:
	var terrain: TerrainSim = sim.terrain
	var i: int = sim.barrels.size() - 1
	while i >= 0:
		var b: SimBarrel = sim.barrels[i]
		if not b.grounded:
			b.vy += GRAVITY * dt
			b.x += b.vx * dt
			b.y += b.vy * dt
			if b.y >= terrain.water_y:
				sim.play("plunge")
				SimCombat.water_plunge(sim, b.x, terrain.water_y, 0.8)
				sim.barrels.remove_at(i)
				i -= 1
				continue
			if terrain.is_solid(b.x, b.y + b.r):
				while terrain.is_solid(b.x, b.y + b.r - 1.0) and b.y > 0.0:
					b.y -= 1.0
				b.vy = 0.0
				b.vx *= 0.4
				if absf(b.vx) < 5.0:
					b.vx = 0.0
					b.grounded = true
		elif not terrain.is_solid(b.x, b.y + b.r + 2.0):
			b.grounded = false
		i -= 1


static func _step_tombstones(sim: CombatSim, dt: float) -> void:
	var terrain: TerrainSim = sim.terrain
	for tb in sim.tombstones:
		if not terrain.is_solid(tb.x, tb.y + 10.0):
			tb.vy = minf(350.0, tb.vy + GRAVITY * dt)
			tb.y += tb.vy * dt
			if terrain.is_solid(tb.x, tb.y + 10.0):
				while terrain.is_solid(tb.x, tb.y + 9.0) and tb.y > 0.0:
					tb.y -= 1.0
				tb.vy = -tb.vy * 0.25
				if absf(tb.vy) < 15.0:
					tb.vy = 0.0

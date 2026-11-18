## Combat numbers: explosion falloff and knockback, fall damage, metamorphosis, melee, links, pickups.
##   godot --headless --path . res://tests/TestSimCombat.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


## A 2-player sim on a flat world (ground at y=400) with two fighters of team 0 and 1 and nothing else.
func _flat_sim() -> CombatSim:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = 4242
	cfg.game_mode = "2P_LOCAL"
	cfg.worms_per_team = 1
	sim.setup(cfg)
	sim.terrain.mask.fill(0)
	for y in range(400, TerrainSim.H):
		for x in TerrainSim.W:
			sim.terrain.mask[y * TerrainSim.W + x] = 1
	sim.barrels.clear()
	sim.mines.clear()
	sim.crates.clear()
	sim.silk_nests.clear()
	sim.rovellons.clear()
	sim.caganers.clear()
	sim.escudelles.clear()
	sim.updrafts.clear()
	sim.surface_flora.clear()
	sim.projectiles.clear()
	for f in sim.fighters:
		f.x = 1000.0 if f.team == 0 else 2000.0
		f.y = 400.0 - f.r
		f.grounded = true
		f.vx = 0.0
		f.vy = 0.0
		f.hp = 100
		f.linked_allies = []
	sim.active_team = 0
	sim.active_fighter = sim.fighters[0]
	sim.turn_phase = CombatSim.Phase.TURN_PLAY
	return sim


func _ready() -> void:
	_explosion()
	_fall_damage()
	_melee_and_boosts()
	_pickups()
	_barrel_chain()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _explosion() -> void:
	var sim := _flat_sim()
	var f: SimFighter = sim.fighters[1]
	f.x = 1500.0
	f.y = 400.0 - 12.0
	# Centre of the blast at the fighter's hit point (f.y - 4): distance 0 -> falloff 1.
	SimCombat.trigger_explosion(sim, 1500.0, f.y - 4.0, 50.0, 50.0, 470.0)
	_check(f.hp == 50, "explosion at distance 0 deals the full 50 damage (hp %d)" % f.hp)
	_check(is_equal_approx(f.vy, -625.0), "knockback vy = -470 - 155 at falloff 1 (vy %.2f)" % f.vy)
	_check(not f.grounded and f.was_blasted, "blasted fighter leaves the ground")
	var f2: SimFighter = sim.fighters[0]
	f2.x = 1500.0 + 42.0
	f2.y = 400.0 - 12.0
	SimCombat.trigger_explosion(sim, 1500.0, f2.y - 4.0, 50.0, 50.0, 470.0)
	# hit_radius 84, distance 42 -> falloff 0.5 -> 25 damage
	_check(f2.hp == 75, "explosion at half the hit radius deals 25 (hp %d)" % f2.hp)
	_check(is_equal_approx(f2.vx, 235.0), "knockback vx = 470 * 0.5 (vx %.2f)" % f2.vx)
	var f3: SimFighter = sim.fighters[1]
	f3.hp = 100
	f3.alive = true
	f3.x = 1500.0 + 83.0
	f3.y = 400.0 - 12.0
	var before: int = f3.hp
	SimCombat.trigger_explosion(sim, 1500.0, f3.y - 4.0, 50.0, 50.0, 470.0)
	_check(before - f3.hp == 7, "far edge of the blast clamps the falloff to 0.14 (7 damage, got %d)" % (before - f3.hp))
	var ground_hole: bool = not sim.terrain.is_solid(1500.0, 410.0)
	_check(ground_hole, "explosion carves a crater")
	var f4: SimFighter = sim.fighters[0]
	f4.hp = 100
	f4.x = 700.0
	f4.y = 388.0
	f4.linked_allies = [sim.fighters[1]]
	SimCombat.trigger_explosion(sim, 700.0, f4.y - 4.0, 50.0, 50.0, 0.0)
	_check(f4.hp == 60, "linked fighters take 20%% less (hp %d)" % f4.hp)


func _fall_damage() -> void:
	var sim := _flat_sim()
	var f: SimFighter = sim.fighters[0]
	f.y = 188.0
	f.grounded = false
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	for i in 400:
		sim.step(1.0 / 60.0)
		if f.grounded:
			break
	_check(f.grounded and f.hp < 100, "200 px fall lands and hurts")
	var lost: int = 100 - f.hp
	_check(lost >= 40 and lost <= 45, "200 px fall damage is about 43 (lost %d)" % lost)
	_check(sim.turn_phase == CombatSim.Phase.ACTION_WAIT, "a significant fall ends the active turn")
	_check(f.sliding or f.vx == 0.0, "landing resolved")

	var sim2 := _flat_sim()
	var g: SimFighter = sim2.fighters[0]
	g.y = 400.0 - 12.0 - 40.0
	g.grounded = false
	g.jump_start_y = g.y
	g.peak_air_y = g.y
	for i in 200:
		sim2.step(1.0 / 60.0)
		if g.grounded:
			break
	_check(g.grounded and g.hp == 100, "40 px fall: no damage")
	_check(g.sliding or g.is_minor_slide or sim2.turn_phase == CombatSim.Phase.TURN_PLAY, "40 px fall: turn continues")

	var sim3 := _flat_sim()
	var h: SimFighter = sim3.fighters[0]
	sim3.set_move(1)
	var x0: float = h.x
	for i in 60:
		sim3.step(1.0 / 60.0)
	_check(absf((h.x - x0) - 78.0) < 2.0, "walking covers 78 px per second (%.1f)" % (h.x - x0))
	sim3.set_move(0)
	sim3.jump_forward()
	_check(not h.grounded and h.vy == -178.0 and h.vx == 92.0, "forward jump sets vx 92 / vy -178")
	for i in 120:
		sim3.step(1.0 / 60.0)
		if h.grounded:
			break
	_check(h.grounded, "jump lands again")


func _melee_and_boosts() -> void:
	var sim := _flat_sim()
	var a: SimFighter = sim.fighters[0]
	var b: SimFighter = sim.fighters[1]
	b.x = a.x + 40.0
	var fuet: int = sim.weapon_index("FUET")
	_check(sim.select_weapon(fuet), "select_weapon FUET")
	sim.aim_angle = 0.0
	SimCombat.fire_weapon(sim, sim.weapons[fuet], 0.0, 1.0, null)
	_check(b.hp == 62, "fuet hit deals 38 (hp %d)" % b.hp)
	_check(a.dmg_dealt == 38 and sim.team_damage_dealt[0] == 38, "damage is credited to the active team")
	_check(sim.turn_phase == CombatSim.Phase.ACTION_WAIT and b.vx == 780.0, "melee hit: ACTION_WAIT and knockback 780")
	# Metamorphosis at <= 35 hp
	b.hp = 40
	SimCombat.damage_fighter(sim, b, 10, "")
	_check(b.hp == 30 and b.metamorphosed, "wings awaken at hp <= 35")
	a.dmg_dealt = 80
	SimCombat.check_metamorphosis(sim, a)
	_check(a.metamorphosed, "wings awaken at 75+ damage dealt")
	# Boosts: linked + castell + pilota + metamorphosed
	sim.projectiles.clear()
	a.linked_allies = [b, b]
	a.castell_tower = true
	a.pilota_buff = true
	var bz: int = sim.weapon_index("BAZOOKA")
	sim.turn_phase = CombatSim.Phase.TURN_PLAY
	SimCombat.fire_weapon(sim, sim.weapons[bz], -1.0, 0.5, null)
	var p: SimProjectile = sim.projectiles[0]
	# dmg 50 * (1 + 0.5 + 0.3 + 0.25 + 0.15) = 110, radius 50 * (1 + 0.24 + 0.15 + 0.10) = 75
	_check(p.max_dmg == 110.0 and p.blast_r == 75.0, "damage/radius boosts (%.0f / %.0f)" % [p.max_dmg, p.blast_r])
	_check(is_equal_approx(p.vx, cos(-1.0) * (180.0 + 0.5 * 760.0)), "bazooka speed 180 + power * 760")
	_check(sim.ammo(0, "BAZOOKA") == -1, "bazooka ammo is unlimited")
	var cl: int = sim.weapon_index("CLUSTER")
	var before: int = sim.ammo(0, "CLUSTER")
	sim.turn_phase = CombatSim.Phase.TURN_PLAY
	SimCombat.fire_weapon(sim, sim.weapons[cl], -1.0, 0.5, null)
	_check(sim.ammo(0, "CLUSTER") == before - 1, "limited ammo is consumed")


func _pickups() -> void:
	var sim := _flat_sim()
	var a: SimFighter = sim.fighters[0]
	var crate := SimCrate.new()
	crate.x = a.x
	crate.y = a.y
	crate.parachuting = false
	crate.grounded = true
	crate.is_medkit = true
	sim.crates.append(crate)
	a.hp = 90
	sim.step(1.0 / 60.0)
	_check(a.hp == 125 and sim.crates.is_empty(), "medkit heals 35 up to 150 (hp %d)" % a.hp)
	var nut := SimNut.new()
	nut.x = a.x
	nut.y = a.y
	nut.grounded = true
	sim.pine_nuts.append(nut)
	sim.step(1.0 / 60.0)
	_check(a.max_hp == 115 and a.hp == 115, "pine nut raises max hp by 15 and heals 20 (%d/%d)" % [a.hp, a.max_hp])
	var cg := SimCaganer.new()
	cg.x = a.x
	cg.y = a.y
	sim.caganers.append(cg)
	var holy_before: int = sim.ammo(0, "HOLY")
	sim.step(1.0 / 60.0)
	_check(sim.ammo(0, "HOLY") == holy_before + 1 and a.hp == 145, "caganer: +30 hp and +1 holy (hp %d)" % a.hp)
	var es := SimEscudella.new()
	es.x = a.x
	es.y = a.y
	sim.escudelles.append(es)
	sim.step(1.0 / 60.0)
	_check(a.pilota_buff and a.hp == 165, "escudella: pilota buff and hp cap 165 (hp %d)" % a.hp)
	# Mine
	var mine := SimMine.new()
	mine.x = a.x
	mine.y = a.y
	sim.mines.append(mine)
	sim.step(1.0 / 60.0)
	_check(mine.triggered or sim.mines.is_empty(), "mine arms when a fighter is near")
	# Water kills
	var b: SimFighter = sim.fighters[1]
	sim.terrain.mask.fill(0)
	b.y = sim.terrain.water_y + 1.0
	b.grounded = false
	sim.step(1.0 / 60.0)
	_check(b.drowning and b.hp == 0, "falling into the water starts drowning")
	for i in 150:
		sim.step(1.0 / 60.0)
	_check(not b.alive, "drowned fighter dies after 1.85 s")


func _barrel_chain() -> void:
	var sim := _flat_sim()
	var barrel := SimBarrel.new()
	barrel.x = 1500.0
	barrel.y = 386.0
	barrel.hp = 5.0
	sim.barrels.append(barrel)
	SimCombat.trigger_explosion(sim, 1500.0, 386.0, 50.0, 50.0, 470.0)
	_check(sim.barrels.is_empty(), "blast destroys the weak barrel")
	var hp_before: int = sim.fighters[1].hp
	sim.fighters[1].x = 1540.0
	sim.fighters[1].y = 388.0
	for i in 6:
		sim.step(1.0 / 60.0)
	_check(sim.fighters[1].hp == hp_before, "barrel delay does not run on scaled sim time")
	for i in 6:
		sim.advance_real(1.0 / 60.0)
	_check(sim.fighters[1].hp < hp_before, "barrel explodes 0.07 s later through the delayed queue")

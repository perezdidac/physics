## Crisàlide (DIG) and Papallona (FLY) modes of PlatformSim, and the eight levels with scripted bots.
##   godot --headless --path . res://tests/TestPlat2Sim.tscn
extends Node

const DT: float = 1.0 / 60.0

var failures: int = 0
var _sig: Dictionary = {}


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	_dig_digging()
	_dig_rock_and_roots()
	_dig_stone_undermined()
	_dig_stone_landed_crumbles()
	_dig_flood()
	_dig_hoopoe_silent()
	_dig_hoopoe_strike()
	_dig_hoopoe_dodge_and_beak()
	_dig_metamorphosis()
	_fly_flap_glide()
	_fly_lamp()
	_fly_trap()
	_fly_shadows()
	_fly_nightjar()
	_fly_bat()
	_fly_eggs_laid()
	_upgrades()
	_determinism()
	_fuzz()
	_levels()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


# ------------------------------------------------------------------ helpers

func _make(lay: PlatformLayout, id: String = "test", upgrade_ids: Array[String] = []) -> PlatformSim:
	var level := LevelDef.new()
	level.id = id
	level.layout = lay
	var sim := PlatformSim.new()
	sim.setup(level, upgrade_ids)
	_sig = {"warn": [], "dive": [], "missed": 0, "wobble": 0, "landed": 0, "broken": [], "zap": 0, "trap": 0, "bite": 0, "pulse": 0,
		"noise": 0, "dirty": Rect2i(), "stats": {}, "respawn": 0}
	sim.boss_warn.connect(func(_t: Vector2) -> void: _sig["warn"].append(sim.time))
	sim.boss_dive.connect(func() -> void: _sig["dive"].append(sim.time))
	sim.boss_missed.connect(func() -> void: _sig["missed"] += 1)
	sim.stone_wobble.connect(func(_i: int) -> void: _sig["wobble"] += 1)
	sim.stone_landed.connect(func(_i: int) -> void: _sig["landed"] += 1)
	sim.stone_broken.connect(func(_i: int, hit: bool) -> void: _sig["broken"].append(hit))
	sim.lamp_zap.connect(func(_i: int) -> void: _sig["zap"] += 1)
	sim.trap_hit.connect(func(_i: int) -> void: _sig["trap"] += 1)
	sim.nightjar_bite.connect(func(_i: int) -> void: _sig["bite"] += 1)
	sim.bat_pulse.connect(func(_p: Vector2) -> void: _sig["pulse"] += 1)
	sim.noise_made.connect(func(_p: Vector2, _r: float) -> void: _sig["noise"] += 1)
	sim.dig_changed.connect(func(c: Rect2i) -> void: _sig["dirty"] = c if _sig["dirty"].size == Vector2i.ZERO else _sig["dirty"].merge(c))
	sim.respawned.connect(func() -> void: _sig["respawn"] += 1)
	sim.level_finished.connect(func(s: Dictionary) -> void: _sig["stats"] = s)
	return sim


func _run(sim: PlatformSim, seconds: float) -> void:
	for _i in roundi(seconds * 60.0):
		sim.step(DT)


func _dig_layout(w: float = 800.0, h: float = 600.0) -> PlatformLayout:
	var lay := PlatformLayout.new()
	lay.mode = "DIG"
	lay.size = Vector2(w, h)
	lay.solids = [Rect2(0, h - 32, w, 32), Rect2(0, 0, 32, h), Rect2(w - 32, 0, 32, h), Rect2(0, 0, w, 32)] as Array[Rect2]
	lay.soil = [Rect2(32, 32, w - 64, h - 64)] as Array[Rect2]
	lay.gaps = [Rect2(48, 64, 100, 64)] as Array[Rect2]
	lay.start = Vector2(100, 116)
	lay.goal = Rect2(0, 0, 0, 0)
	return lay


func _fly_layout() -> PlatformLayout:
	var lay := PlatformLayout.new()
	lay.mode = "FLY"
	lay.size = Vector2(1600, 720)
	lay.solids = [Rect2(0, 640, 1600, 80)] as Array[Rect2]
	lay.start = Vector2(100, 628)
	lay.goal = Rect2(0, 0, 0, 0)
	return lay


## Presses and releases the jump button (one flap).
func _tap(sim: PlatformSim) -> void:
	sim.set_jump(true)
	sim.step(DT)
	sim.set_jump(false)
	sim.step(DT)


# ------------------------------------------------------------------ DIG

func _dig_digging() -> void:
	var sim := _make(_dig_layout())
	var d: PlatformDig = sim.dig
	_check(d != null and sim.fly == null and d.cols == 200 and d.rows == 150 and sim.player.radius == PlatformDig.RADIUS, "DIG: grid %dx%d, the pupa is small" % [d.cols, d.rows])
	_check(d.cell_at(10, 10) == PlatformDig.SOIL and d.cell_at(0, 0) == PlatformDig.ROCK and d.cell_at(20, 20) == PlatformDig.AIR, "DIG: mask values soil/rock/air")
	_check(d.image.get_width() == d.cols and absi(d.image.get_pixel(10, 10).r8 - PlatformDig.SOIL) == 0 and d.image.get_pixel(20, 20).r8 == PlatformDig.AIR, "DIG: the image mirrors the mask")
	_run(sim, 0.5)
	_check(sim.player.on_ground and absf(sim.player.pos.y - 116.0) < 0.6, "DIG: the pupa rests on the gallery floor (y=%.2f)" % sim.player.pos.y)
	sim.set_move(1)
	var guard: int = 0
	while not d.digging and guard < 200:
		sim.step(DT)
		guard += 1
	var x0: float = sim.player.pos.x
	_run(sim, 2.0)
	var dx: float = sim.player.pos.x - x0
	_check(dx > 105.0 and dx < 130.0, "DIG: digs sideways at about 60 px/s (%.1f px in 2 s)" % dx)
	var open: bool = true
	var x: float = 150.0
	while x < x0 + dx - 4.0:
		if d.value_at_px(Vector2(x, 116.0)) != PlatformDig.AIR:
			open = false
		x += 4.0
	_check(open, "DIG: the tunnel is open behind her")
	_check(_sig["dirty"].size != Vector2i.ZERO and _sig["dirty"].position.x >= 36 and _sig["dirty"].end.x <= 100, "DIG: dig_changed reports the dirty cells %s" % str(_sig["dirty"]))
	var synced: bool = true
	for cx in range(36, 90):
		if d.image.get_pixel(cx, 29).r8 != d.cell_at(cx, 29):
			synced = false
	_check(synced, "DIG: image stays in sync with the mask after digging")
	sim.set_move(-1)
	_run(sim, 4.0)
	_check(sim.player.pos.x < 130.0, "DIG: she walks back out of the tunnel (x=%.0f)" % sim.player.pos.x)
	# Dig down, then climb back up the shaft.
	sim = _make(_dig_layout())
	sim.set_vertical(1)
	var y0: float = sim.player.pos.y
	_run(sim, 1.0)
	var dy: float = sim.player.pos.y - y0
	_check(dy > 45.0 and dy < 72.0, "DIG: digs down at about 60 px/s (%.1f px)" % dy)
	_run(sim, 2.0)
	var deep: float = sim.player.pos.y
	sim.set_vertical(-1)
	_run(sim, 3.0)
	_check(sim.player.pos.y < deep - 100.0 and sim.dig.climbing == false or sim.player.pos.y < deep - 100.0, "DIG: she climbs back up her own shaft (%.0f -> %.0f)" % [deep, sim.player.pos.y])
	# Tunnel diagonal and never stuck: walk home from a diagonal tunnel.
	sim = _make(_dig_layout())
	sim.set_move(1)
	sim.set_vertical(1)
	_run(sim, 3.0)
	var far: Vector2 = sim.player.pos
	sim.set_move(-1)
	sim.set_vertical(-1)
	_run(sim, 6.0)
	_check(far.y > 160.0 and sim.player.pos.y < 135.0, "DIG: back up a diagonal tunnel (%.0f,%.0f -> %.0f,%.0f)" % [far.x, far.y, sim.player.pos.x, sim.player.pos.y])
	# A hop is small.
	sim = _make(_dig_layout())
	_run(sim, 0.5)
	sim.set_jump(true)
	var top: float = sim.player.pos.y
	for _i in 40:
		sim.step(DT)
		top = minf(top, sim.player.pos.y)
	_check(116.0 - top > 25.0 and 116.0 - top < 60.0, "DIG: the hop is small (%.0f px)" % (116.0 - top))


func _dig_rock_and_roots() -> void:
	for kind in ["ROCK", "ROOT"]:
		var lay := _dig_layout()
		if kind == "ROCK":
			lay.solids.append(Rect2(148, 64, 200, 64))
		else:
			lay.roots = [Rect2(148, 64, 200, 64)] as Array[Rect2]
		var sim := _make(lay)
		var before: PackedByteArray = sim.dig.mask.duplicate()
		sim.set_move(1)
		_run(sim, 3.0)
		_check(sim.dig.mask == before and sim.player.pos.x < 140.0 and not sim.dig.digging, "DIG: %s cannot be dug (x=%.1f)" % [kind, sim.player.pos.x])
		sim.set_move(0)
		sim.set_vertical(-1)
		_run(sim, 1.0)
		_check(sim.player.pos.y < 80.0 and sim.player.pos.y > 40.0, "DIG: digging up through the ceiling works beside the %s (y=%.0f)" % [kind, sim.player.pos.y])


func _stone_layout() -> PlatformLayout:
	var lay := _dig_layout(600.0, 500.0)
	lay.gaps = [Rect2(48, 200, 300, 64), Rect2(120, 120, 40, 72)] as Array[Rect2]
	lay.stones = [Vector2(140, 178)] as Array[Vector2]
	lay.start = Vector2(140, 252)
	return lay


func _dig_stone_undermined() -> void:
	var sim := _make(_stone_layout())
	_run(sim, 1.0)
	var st: PlatformStone = sim.dig.stones[0]
	_check(st.state == "REST" and absf(st.pos.y - 178.0) < 0.1 and sim.player.hearts == 3, "DIG: a stone sits on the soil shelf")
	sim.set_vertical(1)
	_run(sim, 0.2)
	sim.set_vertical(0)
	_check(st.state == "REST", "DIG: digging away from the stone leaves it alone")
	sim = _make(_stone_layout())
	_run(sim, 0.5)
	st = sim.dig.stones[0]
	sim.player.pos = Vector2(140, 214)
	sim.player.vel = Vector2.ZERO
	sim.set_vertical(-1)
	var wobbled_at: float = -1.0
	var fell_at: float = -1.0
	for i in 120:
		sim.step(DT)
		if wobbled_at < 0.0 and st.state == "WOBBLE":
			wobbled_at = i * DT
		if fell_at < 0.0 and st.state == "FALL":
			fell_at = i * DT
	_check(wobbled_at >= 0.0 and fell_at - wobbled_at > 0.25 and _sig["wobble"] == 1, "DIG: undermined stone wobbles first (%.2f s warning)" % (fell_at - wobbled_at))
	_check(sim.player.hearts == 2 and _sig["broken"] == [true] and st.state == "GONE", "DIG: the falling stone hurts and shatters (hearts %d)" % sim.player.hearts)
	_check(sim.player.invuln > 0.0 or sim.player.hurt_lock >= 0.0, "DIG: she is not squeezed or stuck after the hit")


func _dig_stone_landed_crumbles() -> void:
	var sim := _make(_stone_layout())
	sim.player.pos = Vector2(400, 252)
	_run(sim, 0.3)
	sim.dig.carve_circle(Vector2(140, 196), 22.0)
	var st: PlatformStone = sim.dig.stones[0]
	_run(sim, 1.5)
	_check(st.state == "REST" and absf(st.pos.y - 250.0) < 0.1 and _sig["landed"] == 1 and sim.player.hearts == 3, "DIG: a stone with nobody under it lands in the gallery (y=%.1f)" % st.pos.y)
	sim.player.pos = Vector2(240, 252)
	sim.set_move(-1)
	_run(sim, 0.3)
	_check(sim.player.pos.x > 165.0 and st.state == "REST", "DIG: a landed stone blocks the gallery")
	_run(sim, 1.0)
	_check(st.state == "GONE" and _sig["broken"] == [false], "DIG: digging into the stone crumbles it")
	_run(sim, 1.5)
	_check(sim.player.pos.x < 100.0, "DIG: she walks on through the rubble (x=%.0f)" % sim.player.pos.x)


func _dig_flood() -> void:
	var lay := _dig_layout()
	lay.flood_rate = 20.0
	lay.flood_start = 140.0
	lay.flood_delay = 1.0
	var sim := _make(lay)
	_run(sim, 0.9)
	_check(sim.dig.water_y == 140.0, "DIG: the water waits for its delay")
	_run(sim, 2.0)
	_check(absf(sim.dig.water_y - (140.0 - 20.0 * 1.9)) < 1.0, "DIG: the water rises (%.0f)" % sim.dig.water_y)
	_check(sim.player.pos.y > sim.dig.water_y and sim.dig.drown > 0.0 and sim.player.hearts == 3, "DIG: she is under water and starts to drown (%.2f s)" % sim.dig.drown)
	_run(sim, 2.5)
	_check(sim.player.hearts == 2, "DIG: more than 2 s under water costs a heart (hearts %d)" % sim.player.hearts)
	_run(sim, 2.0)
	_check(sim.player.hearts == 1, "DIG: and another one 2 s later (hearts %d)" % sim.player.hearts)
	_run(sim, 2.2)
	_check(sim.finished and not sim.won and _sig["stats"].get("reason", "") == "LOST", "DIG: drowning with no hearts loses the level")
	# Surfacing resets the timer.
	sim = _make(lay)
	_run(sim, 3.4)
	var wet: float = sim.dig.drown
	sim.dig.water_y = 500.0
	_run(sim, 1.5)
	_check(wet > 0.5 and sim.dig.drown == 0.0 and sim.player.hearts == 3, "DIG: air resets the drowning timer")


func _hoopoe_layout(boss_time: float = 40.0) -> PlatformLayout:
	var lay := _dig_layout(1400.0, 700.0)
	lay.soil = [Rect2(32, 160, 1336, 508)] as Array[Rect2]
	lay.gaps = [Rect2(560, 240, 300, 64)] as Array[Rect2]
	lay.start = Vector2(640, 292)
	lay.boss = "HOOPOE"
	lay.boss_time = boss_time
	lay.surface_y = 160.0
	lay.arena = Rect2(0, 0, 1400, 700)
	return lay


func _dig_hoopoe_silent() -> void:
	var sim := _make(_hoopoe_layout())
	var h: PlatformHoopoe = sim.dig.hoopoe
	_check(h != null and absf(h.pos.y - (160.0 - h.radius)) < 0.01 and sim.time_left == 40.0, "HOOPOE: walks on the surface")
	var x0: float = h.pos.x
	var seen_state: bool = false
	for _i in 60 * 20:
		sim.step(DT)
		if h.state != "IDLE":
			seen_state = true
	_check(not seen_state and sim.player.hearts == 3 and sim.dig.noise_rings.is_empty() and _sig["noise"] == 0, "HOOPOE: staying still is silent and safe for 20 s")
	_check(absf(h.pos.x - x0) > 100.0, "HOOPOE: it strolls about meanwhile")
	_check(absf(sim.time_left - 22.0) < 0.2, "HOOPOE: the timer runs after the 2 s intro (%.1f)" % sim.time_left)


func _dig_hoopoe_strike() -> void:
	var sim := _make(_hoopoe_layout())
	var h: PlatformHoopoe = sim.dig.hoopoe
	_run(sim, 0.5)
	sim.set_jump(true)
	sim.step(DT)
	sim.set_jump(false)
	_check(_sig["noise"] == 1 and sim.dig.noise_rings.size() == 1, "HOOPOE: a hop makes a noise ring")
	var states: Array[String] = []
	for _i in 60 * 12:
		sim.step(DT)
		if states.is_empty() or states[-1] != h.state:
			states.append(h.state)
		if sim.player.hearts < 3:
			break
	_check(states.has("HUNT") and states.has("AIM") and states.has("STAB"), "HOOPOE: the noise reaches the surface, it hunts, aims and stabs (%s)" % str(states))
	_check(_sig["warn"].size() == 1 and _sig["dive"].size() == 1 and _sig["dive"][0] - _sig["warn"][0] >= 0.55 and h.warn_time >= 0.6, "HOOPOE: the beak is telegraphed %.2f s before the strike" % (_sig["dive"][0] - _sig["warn"][0]))
	_check(sim.player.hearts == 2, "HOOPOE: a motionless pupa under the strike loses a heart")
	_run(sim, 3.0)
	_check(h.state == "IDLE" and h.tip_y == 160.0, "HOOPOE: it pulls the beak out and goes back to strolling")
	var shaft: bool = true
	for y in range(168, 400, 8):
		if sim.dig.value_at_px(Vector2(h.target.x, y)) != PlatformDig.AIR:
			shaft = false
	_check(shaft, "HOOPOE: the beak left a shaft down to the pupa")
	_check(_sig["dirty"].size != Vector2i.ZERO, "HOOPOE: the shaft is reported in dig_changed")
	# Digging is loud: a ring every 0.45 s.
	sim = _make(_hoopoe_layout())
	sim.set_move(1)
	_run(sim, 2.0)
	_check(_sig["noise"] >= 3, "HOOPOE: digging makes noise rings (%d in 2 s)" % _sig["noise"])
	# Deep noise never reaches the surface.
	sim = _make(_hoopoe_layout())
	sim.player.pos = Vector2(700, 600)
	sim.player.vel = Vector2.ZERO
	sim.set_jump(true)
	_run(sim, 6.0)
	_check(sim.dig.hoopoe.state == "IDLE", "HOOPOE: noise from too deep is not heard")


func _dig_hoopoe_dodge_and_beak() -> void:
	var sim := _make(_hoopoe_layout())
	var h: PlatformHoopoe = sim.dig.hoopoe
	_run(sim, 0.5)
	sim.set_jump(true)
	sim.step(DT)
	sim.set_jump(false)
	for _i in 60 * 10:
		sim.step(DT)
		if h.state == "AIM":
			break
	_check(h.state == "AIM", "HOOPOE: aiming")
	sim.set_move(1)
	_run(sim, 0.8)
	sim.set_move(0)
	_run(sim, 2.0)
	_check(sim.player.hearts == 3 and _sig["dive"].size() == 1, "HOOPOE: walking away during the telegraph dodges the strike")
	# The beak stops at roots.
	var lay := _hoopoe_layout()
	lay.roots = [Rect2(600, 200, 100, 20)] as Array[Rect2]
	sim = _make(lay)
	var tip: float = sim.dig.carve_beak(640.0, 160.0, 420.0)
	_check(tip >= 190.0 and tip <= 204.0, "HOOPOE: the beak stops at a root (tip y=%.0f)" % tip)


func _dig_metamorphosis() -> void:
	var sim := _make(_hoopoe_layout(5.0))
	_run(sim, 6.5)
	_check(not sim.finished and sim.time_left > 0.0, "METAMORPHOSIS: not before the time is up")
	_run(sim, 1.0)
	var s: Dictionary = _sig["stats"]
	_check(sim.won and s.get("reason", "") == "METAMORPHOSIS" and s.get("stars", 0) == 3 and s.get("hearts_left", 0) == 3, "METAMORPHOSIS: surviving the time wins (%s)" % str(s))


# ------------------------------------------------------------------ FLY

func _fly_flap_glide() -> void:
	var sim := _make(_fly_layout())
	_check(sim.fly != null and sim.dig == null and sim.player.radius == PlatformFly.RADIUS, "FLY: the moth is small")
	_run(sim, 0.5)
	_check(sim.player.on_ground and absf(sim.player.pos.y - 628.0) < 0.6, "FLY: she rests on the ground")
	_tap(sim)
	var top: float = sim.player.pos.y
	for _i in 60:
		sim.step(DT)
		top = minf(top, sim.player.pos.y)
	var rise: float = 628.0 - top
	_check(rise > 55.0 and rise < 85.0, "FLY: one flap lifts her ~70 px (%.0f)" % rise)
	# Flaps during the cooldown are ignored; spaced flaps climb.
	sim = _make(_fly_layout())
	_run(sim, 0.3)
	_tap(sim)
	var vy_after: float = sim.player.vel.y
	_run(sim, 0.05)
	_tap(sim)
	_check(sim.player.vel.y > vy_after, "FLY: a second flap inside the cooldown does nothing (vy %.0f -> %.0f)" % [vy_after, sim.player.vel.y])
	sim = _make(_fly_layout())
	_run(sim, 0.3)
	for _i in 8:
		_tap(sim)
		_run(sim, PlatformFly.FLAP_COOLDOWN)
	_check(sim.player.pos.y < 628.0 - 250.0, "FLY: repeated flaps climb (y=%.0f)" % sim.player.pos.y)
	# Glide: holding the button while falling.
	var fall_free: float = _fall_distance(false)
	var fall_glide: float = _fall_distance(true)
	_check(fall_glide > 50.0 and fall_glide < 90.0 and fall_free > 250.0, "FLY: gliding falls slowly (%.0f px/s vs %.0f free)" % [fall_glide, fall_free])
	# Steering and top speed.
	sim = _make(_fly_layout())
	sim.player.pos = Vector2(400, 300)
	sim.set_move(1)
	_run(sim, 2.0)
	_check(is_equal_approx(sim.player.vel.x, PlatformFly.MAX_SPEED), "FLY: steering reaches the top speed")
	sim.set_move(0)
	_run(sim, 2.0)
	_check(absf(sim.player.vel.x) < 1.0, "FLY: the air slows her down")


## Platform hub upgrades: FAST_DIG digs 30 % faster, LONG_FLIGHT glides down slower, combat upgrades change nothing.
func _upgrades() -> void:
	var slow := _make(_dig_layout())
	var fast := _make(_dig_layout(), "test", ["FAST_DIG"] as Array[String])
	var combat := _make(_dig_layout(), "test", ["SHARP_HAIRS", "TOUGH_SKIN"] as Array[String])
	_check(slow.dig_speed_mult == 1.0 and is_equal_approx(fast.dig_speed_mult, 1.3) and combat.dig_speed_mult == 1.0 and combat.upgrades.is_empty(), "FAST_DIG sets the dig multiplier to 1.3; combat upgrades are ignored here")
	var dist: Array[float] = []
	for sim in [slow, fast]:
		sim.set_vertical(1)
		var y0: float = sim.player.pos.y
		_run(sim, 1.0)
		dist.append(sim.player.pos.y - y0)
	_check(dist[1] > dist[0] * 1.15 and dist[1] < dist[0] * 1.45, "FAST_DIG: digs down faster (%.0f px vs %.0f px in 1 s)" % [dist[1], dist[0]])
	var base: float = _fall_distance(true)
	var long_fly: float = _fall_distance(true, ["LONG_FLIGHT"] as Array[String])
	_check(long_fly < base * 0.65 and long_fly > 10.0, "LONG_FLIGHT: the glide sinks slower (%.0f px/s vs %.0f)" % [long_fly, base])
	var free: float = _fall_distance(false, ["LONG_FLIGHT"] as Array[String])
	_check(free > 250.0, "LONG_FLIGHT does not change a free fall (%.0f px/s)" % free)


## Distance fallen in the second after 1.5 s of free fall or glide from a high start.
func _fall_distance(glide: bool, upgrade_ids: Array[String] = []) -> float:
	var lay := _fly_layout()
	lay.size = Vector2(1600, 2800)
	lay.solids = [Rect2(0, 2640, 1600, 80)] as Array[Rect2]
	var sim := _make(lay, "test", upgrade_ids)
	sim.player.pos = Vector2(400, 100)
	if glide:
		sim.set_jump(true)
	_run(sim, 1.5)
	var y0: float = sim.player.pos.y
	_run(sim, 0.9)
	return (sim.player.pos.y - y0) / 0.9


func _fly_lamp() -> void:
	var lay := _fly_layout()
	lay.lights = [Vector3(600, 300, 150)] as Array[Vector3]
	var sim := _make(lay)
	sim.player.pos = Vector2(540, 300)
	sim.player.vel = Vector2(0, -50)
	_run(sim, 0.1)
	_check(sim.fly.lamp_pull(0) > 0.2 and sim.player.vel.x > 10.0, "LAMP: pulls the moth towards it (vx=%.0f)" % sim.player.vel.x)
	var d0: float = 100.0
	var sim2 := _make(lay)
	sim2.player.pos = Vector2(500, 300)
	sim2.set_move(-1)
	_run(sim2, 0.6)
	_check(sim2.player.pos.x < 500.0 and 600.0 - sim2.player.pos.x > d0, "LAMP: steering away beats the pull")
	# Touching it: heart and stun.
	sim = _make(lay)
	sim.player.pos = Vector2(600, 300)
	sim.player.vel = Vector2.ZERO
	sim.step(DT)
	_check(sim.player.hearts == 2 and _sig["zap"] == 1 and sim.fly.stun > 0.9, "LAMP: touching it costs a heart and stuns her for 1 s")
	var vx: float = sim.player.vel.x
	sim.set_move(-1)
	_run(sim, 0.5)
	_check(sim.player.hurt_lock > 0.0 and sim.fly.stun > 0.0 and absf(sim.player.vel.x) <= absf(vx) + 1.0, "LAMP: no steering while stunned")
	sim.player.pos = Vector2(300, 300)
	sim.player.vel = Vector2.ZERO
	_run(sim, 0.8)
	_check(sim.fly.stun == 0.0 and sim.player.vel.x < -100.0, "LAMP: control comes back after the stun")


func _fly_trap() -> void:
	var lay := _fly_layout()
	lay.traps = [Rect2(300, 560, 60, 80)] as Array[Rect2]
	lay.checkpoints = [Vector2(150, 640)] as Array[Vector2]
	var sim := _make(lay)
	sim.player.pos = Vector2(150, 600)
	_run(sim, 0.2)
	_check(sim.checkpoint_idx == 0, "TRAP: a checkpoint is taken in flight mode too")
	sim.player.pos = Vector2(330, 500)
	sim.player.vel = Vector2.ZERO
	_run(sim, 1.0)
	_check(sim.player.hearts == 2 and _sig["trap"] == 1 and _sig["respawn"] == 1, "TRAP: the sticky box costs a heart and respawns her")
	_check(absf(sim.player.pos.x - 150.0) < 40.0 and sim.player.invuln > 0.0, "TRAP: she reappears at the checkpoint (x=%.0f)" % sim.player.pos.x)
	# With no checkpoint she goes back to the start.
	sim = _make(_fly_layout_trap())
	sim.player.pos = Vector2(330, 580)
	sim.step(DT)
	_check(sim.player.pos.distance_to(sim.layout.start) < 30.0 and sim.player.hearts == 2, "TRAP: no checkpoint: back to the start")
	sim = _make(_fly_layout_trap())
	sim.player.hearts = 1
	sim.player.pos = Vector2(330, 580)
	sim.step(DT)
	_check(sim.finished and not sim.won, "TRAP: the last heart loses the level")


func _fly_layout_trap() -> PlatformLayout:
	var lay := _fly_layout()
	lay.traps = [Rect2(300, 560, 60, 80)] as Array[Rect2]
	return lay


func _fly_shadows() -> void:
	var lay := _fly_layout()
	lay.shadows = [Rect2(200, 400, 200, 200), Rect2(600, 400, 200, 200), Rect2(1000, 400, 200, 200)] as Array[Rect2]
	lay.shadow_period = [0.0, 4.0, 5.0] as Array[float]
	lay.shadow_blink = [false, true, false] as Array[bool]
	lay.shadow_slide = [Vector2.ZERO, Vector2.ZERO, Vector2(100, 0)] as Array[Vector2]
	var sim := _make(lay)
	sim.player.pos = Vector2(300, 500)
	sim.step(DT)
	_check(sim.player.hidden and sim.fly.in_shadow(Vector2(300, 500)) and sim.fly.shadow_count() == 3, "SHADOW: hidden while inside")
	sim.player.pos = Vector2(450, 500)
	sim.step(DT)
	_check(not sim.player.hidden, "SHADOW: visible outside")
	# Blinking: on at the start, off in the last 35 % of the cycle.
	var on_t: int = 0
	var off_t: int = 0
	for _i in 60 * 4:
		sim.step(DT)
		if sim.fly.shadow_active(1):
			on_t += 1
		else:
			off_t += 1
	_check(absf(float(off_t) / float(on_t + off_t) - 0.35) < 0.06, "SHADOW: a blinking shadow is off about 35 %% of the time (%d/%d)" % [off_t, on_t + off_t])
	var sim2 := _make(lay)
	sim2.player.pos = Vector2(700, 500)
	var seen_open: bool = false
	for _i in 60 * 5:
		sim2.player.pos = Vector2(700, 500)
		sim2.player.vel = Vector2.ZERO
		sim2.step(DT)
		if not sim2.fly.shadow_active(1):
			seen_open = seen_open or not sim2.player.hidden
	_check(seen_open, "SHADOW: an inactive shadow hides nobody")
	# Sliding.
	var sim3 := _make(lay)
	var lo: float = 1e9
	var hi: float = -1e9
	for _i in 60 * 5:
		sim3.step(DT)
		lo = minf(lo, sim3.fly.shadow_rect(2).position.x)
		hi = maxf(hi, sim3.fly.shadow_rect(2).position.x)
	_check(hi - lo > 150.0, "SHADOW: a sliding shadow moves (%.0f px of travel)" % (hi - lo))


func _fly_nightjar() -> void:
	var lay := _fly_layout()
	lay.nightjars = [PackedVector2Array([Vector2(600, 400), Vector2(900, 400)])] as Array[PackedVector2Array]
	var sim := _make(lay)
	var bird: PlatformNightjar = sim.fly.nightjars[0]
	sim.player.pos = Vector2(1300, 300)
	_run(sim, 1.0)
	_check(bird.state == "PATROL" and bird.pos.x > 600.0, "NIGHTJAR: patrols while the moth is far")
	var lap: float = 0.0
	var x_prev: float = bird.pos.x
	for _i in 60 * 12:
		sim.step(DT)
		lap = maxf(lap, absf(bird.pos.x - x_prev))
		x_prev = bird.pos.x
	_check(bird.pos.x >= 595.0 and bird.pos.x <= 905.0, "NIGHTJAR: stays on its path (x=%.0f)" % bird.pos.x)
	# Chase within 220 px.
	sim = _make(lay)
	bird = sim.fly.nightjars[0]
	sim.player.pos = Vector2(700, 560)
	sim.player.vel = Vector2.ZERO
	sim.step(DT)
	_check(bird.state == "PATROL" or bird.state == "CHASE", "NIGHTJAR: sees the moth")
	sim.player.pos = Vector2(bird.pos.x, bird.pos.y + 160.0)
	sim.step(DT)
	_check(bird.state == "CHASE", "NIGHTJAR: chases a visible moth within 220 px")
	var fast: float = 0.0
	for _i in 120:
		sim.step(DT)
		fast = maxf(fast, bird.vel.length())
	_check(fast <= PlatformNightjar.CHASE_SPEED + 1.0 and fast < PlatformFly.MAX_SPEED, "NIGHTJAR: the moth can outfly it (%.0f px/s)" % fast)
	_check(sim.player.hearts == 2 and _sig["bite"] == 1 and bird.state == "RECOIL", "NIGHTJAR: the bite costs a heart and sends it off")
	_run(sim, 1.5)
	_check(bird.state != "RECOIL" and sim.player.hearts >= 1, "NIGHTJAR: it comes back after the recoil")
	# A moth in a shadow is not chased and the bird gives up.
	lay.shadows = [Rect2(1000, 400, 300, 240)] as Array[Rect2]
	sim = _make(lay)
	bird = sim.fly.nightjars[0]
	sim.player.pos = Vector2(bird.pos.x, bird.pos.y + 150.0)
	sim.step(DT)
	_check(bird.state == "CHASE", "NIGHTJAR: chases her in the open")
	sim.player.pos = Vector2(1050, 560)
	sim.player.vel = Vector2.ZERO
	var states: Array[String] = []
	for _i in 60 * 6:
		sim.player.pos = Vector2(1050, 560)
		sim.player.vel = Vector2.ZERO
		sim.step(DT)
		if states.is_empty() or states[-1] != bird.state:
			states.append(bird.state)
	_check(sim.player.hidden and not states.has("RECOIL") and sim.player.hearts == 3 and bird.state != "CHASE", "NIGHTJAR: hiding in a shadow makes it lose her (%s)" % str(states))
	# Birds do not fly through solids.
	lay = _fly_layout()
	lay.solids.append(Rect2(700, 300, 40, 300))
	lay.nightjars = [PackedVector2Array([Vector2(500, 450), Vector2(500, 460)])] as Array[PackedVector2Array]
	sim = _make(lay)
	sim.player.pos = Vector2(900, 450)
	var inside: bool = false
	for _i in 60 * 4:
		sim.player.pos = Vector2(900, 450)
		sim.player.vel = Vector2.ZERO
		sim.step(DT)
		if Rect2(700, 300, 40, 300).grow(-4.0).has_point(sim.fly.nightjars[0].pos):
			inside = true
	_check(not inside and sim.fly.nightjars[0].pos.x < 720.0, "NIGHTJAR: a wall stops it (x=%.0f)" % sim.fly.nightjars[0].pos.x)


func _bat_layout(boss_time: float = 30.0) -> PlatformLayout:
	var lay := _fly_layout()
	lay.size = Vector2(1400, 720)
	lay.solids = [Rect2(0, 640, 1400, 80)] as Array[Rect2]
	lay.boss = "BAT"
	lay.boss_time = boss_time
	lay.arena = Rect2(0, 0, 1400, 720)
	lay.shadows = [Rect2(100, 440, 220, 200)] as Array[Rect2]
	lay.start = Vector2(800, 628)
	return lay


func _fly_bat() -> void:
	# In the open: pulse -> mark -> swoop -> hit.
	var sim := _make(_bat_layout())
	var bat: PlatformBat = sim.fly.bat
	_check(bat != null and sim.time_left == 30.0, "BAT: hovers above the arena")
	var states: Array[String] = []
	for _i in 60 * 14:
		sim.step(DT)
		if states.is_empty() or states[-1] != bat.state:
			states.append(bat.state)
		if sim.player.hearts < 3:
			break
	_check(_sig["pulse"] >= 1 and states.has("MARK") and states.has("SWOOP"), "BAT: a pulse marks the visible moth and it swoops (%s)" % str(states))
	_check(_sig["warn"].size() >= 1 and _sig["dive"].size() >= 1 and _sig["dive"][0] - _sig["warn"][0] >= 0.45 and bat.warn_time >= 0.5, "BAT: the mark is telegraphed %.2f s" % (_sig["dive"][0] - _sig["warn"][0]))
	_check(sim.player.hearts == 2, "BAT: the swoop hits a moth that stayed in the open")
	# Hidden when the pulse passes: it never marks her.
	sim = _make(_bat_layout())
	sim.player.pos = Vector2(200, 560)
	var marked: bool = false
	for _i in 60 * 14:
		sim.player.pos = Vector2(200, 560)
		sim.player.vel = Vector2.ZERO
		sim.step(DT)
		if sim.fly.bat.state != "PATROL":
			marked = true
	_check(sim.player.hidden and not marked and _sig["pulse"] >= 3 and sim.player.hearts == 3, "BAT: pulses pass over a moth in a shadow (%d pulses, never marked)" % _sig["pulse"])
	# Marked, then she dives into the shadow before the swoop: it misses.
	sim = _make(_bat_layout())
	sim.player.pos = Vector2(330, 600)
	for _i in 60 * 14:
		sim.step(DT)
		if sim.fly.bat.state == "MARK":
			break
	_check(sim.fly.bat.state == "MARK", "BAT: marks her at the pulse")
	sim.player.pos = Vector2(200, 560)
	sim.player.vel = Vector2.ZERO
	var hurt: bool = false
	for _i in 60 * 3:
		sim.player.vel.x = 0.0
		sim.step(DT)
		hurt = hurt or sim.player.hearts < 3
	_check(_sig["missed"] == 1 and not hurt and sim.player.hidden, "BAT: hiding after the mark makes the swoop miss")
	# Pulses speed up as the boss fight goes on.
	sim = _make(_bat_layout())
	sim.player.pos = Vector2(200, 560)
	var pulse_times: Array[float] = []
	sim.bat_pulse.connect(func(_p: Vector2) -> void: pulse_times.append(sim.time))
	for _i in 60 * 28:
		sim.player.pos = Vector2(200, 560)
		sim.step(DT)
	var gap_early: float = pulse_times[1] - pulse_times[0]
	var gap_late: float = pulse_times[-1] - pulse_times[-2]
	_check(gap_late < gap_early - 0.4 and pulse_times[0] > 2.0, "BAT: pulses come faster later (%.2f s -> %.2f s)" % [gap_early, gap_late])


func _fly_eggs_laid() -> void:
	var sim := _make(_bat_layout(4.0))
	for _i in 60 * 9:
		sim.player.pos = Vector2(200, 560)
		sim.player.vel = Vector2.ZERO
		sim.step(DT)
	var s: Dictionary = _sig["stats"]
	_check(sim.won and s.get("reason", "") == "EGGS_LAID" and s.get("stars", 0) == 3, "EGGS_LAID: surviving the bat wins (%s)" % str(s))
	sim = _make(_bat_layout(30.0))
	sim.player.hearts = 1
	sim.player.pos = Vector2(800, 400)
	for _i in 60 * 20:
		sim.step(DT)
		if sim.finished:
			break
	_check(sim.finished and not sim.won and _sig["stats"].get("reason", "") == "LOST", "EGGS_LAID: dying to the bat loses")


# ------------------------------------------------------------------ determinism

func _scripted(id: String, seed_v: int) -> Array:
	var level := load("res://data/levels/%s.tres" % id) as LevelDef
	var sim := _make_level(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in 60 * 40:
		if i % 15 == 0:
			sim.set_move(rng.randi_range(-1, 1))
			sim.set_vertical(rng.randi_range(-1, 1))
			sim.set_jump(rng.randf() < 0.5)
		sim.player.hearts = 99
		sim.step(DT)
	var out: Array = [sim.player.pos, sim.player.vel, sim.time_left, sim.nutrients_taken.duplicate()]
	if sim.dig != null:
		out.append(sim.dig.mask.duplicate())
		out.append(sim.dig.water_y)
		out.append(sim.dig.noise_rings.size())
		if sim.dig.hoopoe != null:
			out.append(sim.dig.hoopoe.pos)
			out.append(sim.dig.hoopoe.state)
	if sim.fly != null:
		out.append(sim.fly.nightjars.size())
		for n in sim.fly.nightjars:
			out.append(n.pos)
		if sim.fly.bat != null:
			out.append(sim.fly.bat.pos)
			out.append(sim.fly.bat.state)
	return out


func _determinism() -> void:
	for id in ["pupa_2", "pupa_boss", "moth_3", "moth_boss"]:
		var a: Array = _scripted(id, 5)
		var b: Array = _scripted(id, 5)
		_check(a == b, "determinism: %s gives the same state for the same inputs" % id)


# ------------------------------------------------------------------ robustness

## Random inputs for a long time: the pupa never ends up inside soil or rock, the moth never inside a solid, nothing leaves the world.
func _fuzz() -> void:
	for id in ["pupa_1", "pupa_2", "pupa_3", "pupa_boss", "moth_2", "moth_3", "moth_boss"]:
		var level := load("res://data/levels/%s.tres" % id) as LevelDef
		var sim := _make_level(level)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var buried: int = 0
		var outside: int = 0
		for i in 60 * 90:
			if i % 12 == 0:
				sim.set_move(rng.randi_range(-1, 1))
				sim.set_vertical(rng.randi_range(-1, 1))
				sim.set_jump(rng.randf() < 0.5)
			sim.player.hearts = 99
			sim.step(DT)
			var pos: Vector2 = sim.player.pos
			if not Rect2(Vector2.ZERO, sim.layout.size).has_point(pos):
				outside += 1
			if sim.dig != null and sim.dig.value_at_px(pos) != PlatformDig.AIR:
				buried += 1
			if sim.fly != null:
				for r in sim.layout.solids:
					if r.grow(-3.0).has_point(pos):
						buried += 1
			if sim.finished:
				break
		_check(buried == 0 and outside == 0 and is_finite(sim.player.pos.x), "%s: 90 s of random input: never buried (%d) or outside (%d)" % [id, buried, outside])


# ------------------------------------------------------------------ the eight levels and their bots

func _make_level(level: LevelDef) -> PlatformSim:
	var sim := PlatformSim.new()
	sim.setup(level)
	return sim


## Waypoints (the bot walks/digs/flies to each in turn; sap lies on the way).
const ROUTES: Dictionary = {
	"pupa_1": [[300, 116], [502, 262], [782, 422], [900, 536], [1150, 642], [1300, 642], [1340, 690], [1460, 690]],
	"pupa_2": [[300, 116], [300, 400], [300, 660], [700, 660], [700, 520], [700, 200], [1100, 200], [1200, 200], [1200, 500], [1400, 500], [1400, 800], [1480, 800], [1640, 824]],
	"pupa_3": [[150, 1104], [150, 900], [150, 850], [500, 850], [900, 850], [900, 700], [900, 520], [450, 520], [450, 360], [450, 200], [900, 200], [1250, 200], [1250, 150]],
	"moth_1": [[400, 540], [560, 330], [800, 400], [1000, 250], [1220, 250], [1450, 400], [1700, 340], [1900, 300], [2300, 220], [2500, 200]],
	"moth_2": [[400, 300], [700, 160], [900, 200], [1250, 440], [1520, 300], [1800, 200], [2150, 300], [2420, 300], [2700, 250], [2900, 180], [3100, 200]],
	"moth_3": [[450, 540], [800, 520], [1100, 560], [1250, 540], [1700, 560], [2000, 540], [2300, 520], [2700, 540], [3100, 500]],
}

var _flap_toggle: bool = false


func _levels() -> void:
	var ids: Array[String] = ["pupa_1", "pupa_2", "pupa_3", "pupa_boss", "moth_1", "moth_2", "moth_3", "moth_boss"]
	var list := load("res://data/levels/level_list.tres") as LevelList
	var in_list: Array[String] = []
	for l in list.levels:
		if l.id in ids:
			in_list.append(l.id)
	_check(in_list == ids and list.levels[-1].id == "moth_boss", "level_list: the eight levels are at the end, in order")
	for id in ids:
		var level := load("res://data/levels/%s.tres" % id) as LevelDef
		var stage: String = "PUPA" if id.begins_with("pupa") else "MOTH"
		var keys_ok: bool = level.title_key.begins_with("LVL_%s_" % id.to_upper()) and level.tip_key.ends_with("_TIP")
		_check(level.mode == "PLATFORM" and level.stage == stage and level.playable and level.layout.mode == ("DIG" if stage == "PUPA" else "FLY") and keys_ok, "%s: PLATFORM level, stage %s, layout.mode %s" % [id, level.stage, level.layout.mode])
		_bot(level, id)
		_check(ArtCatalog.background(level.layout.background_key) != null, "%s: background '%s' exists" % [id, level.layout.background_key])


func _bot(level: LevelDef, id: String) -> void:
	var sim := _make(level.layout, id)
	var lay: PlatformLayout = level.layout
	var idx: int = 0
	var frames: int = 0
	var limit: int = 60 * 200
	var route: Array = ROUTES.get(id, [])
	var hid: bool = false
	var struck: int = 0
	while not sim.finished and frames < limit:
		if sim.dig != null:
			idx = _dig_bot(sim, route, idx)
		else:
			idx = _fly_bot(sim, route, idx)
		sim.step(DT)
		frames += 1
		hid = hid or sim.player.hidden
		if sim.dig != null and sim.dig.hoopoe != null and sim.dig.hoopoe.state == "STAB":
			struck += 1
	var s: Dictionary = _sig["stats"]
	var taken: int = 0
	for t in sim.nutrients_taken:
		if t:
			taken += 1
	var boss_level: bool = lay.boss != ""
	var reason: String = "METAMORPHOSIS" if lay.boss == "HOOPOE" else ("EGGS_LAID" if lay.boss == "BAT" else "REACHED_GOAL")
	_check(sim.won and s.get("reason", "") == reason, "%s: bot wins in %.1f s (%s, %d/%d sap, %d hearts)" % [id, sim.time, s.get("reason", "?"), taken, sim.nutrients_taken.size(), sim.player.hearts])
	if not boss_level:
		_check(taken == sim.nutrients_taken.size(), "%s: all %d sap taken (3 stars: %s)" % [id, taken, str(s.get("stars", 0))])
	elif lay.boss == "HOOPOE":
		_check(struck > 0 or taken == sim.nutrients_taken.size(), "%s: the hoopoe struck while the bot dug (%d frames of beak)" % [id, struck])
	else:
		_check(hid, "%s: the bot hid in the shadows" % id)


func _dig_bot(sim: PlatformSim, route: Array, idx_in: int) -> int:
	var idx: int = idx_in
	var p: PlatformBody = sim.player
	var mv: int = 0
	var vt: int = 0
	var hoopoe: PlatformHoopoe = sim.dig.hoopoe
	if hoopoe != null:
		# Boss: collect the sap, but step aside when a strike is aimed at us.
		var t: Vector2 = Vector2(-1, -1)
		for i in sim.nutrients_taken.size():
			if not sim.nutrients_taken[i]:
				t = sim.layout.nutrients[i]
				break
		if (hoopoe.state == "AIM" or hoopoe.state == "STAB") and absf(p.pos.x - hoopoe.target.x) < 70.0:
			mv = 1 if p.pos.x >= hoopoe.target.x else -1
		elif t.x >= 0.0:
			var d: Vector2 = t - p.pos
			mv = 0 if absf(d.x) < 8.0 else int(signf(d.x))
			vt = 0 if absf(d.y) < 8.0 else int(signf(d.y))
		return _dig_drive(sim, mv, vt, false, idx)
	if idx >= route.size():
		return idx
	var target := Vector2(route[idx][0], route[idx][1])
	var delta: Vector2 = target - p.pos
	if delta.length() < 14.0:
		idx += 1
		return idx
	mv = 0 if absf(delta.x) < 6.0 else int(signf(delta.x))
	vt = 0 if absf(delta.y) < 6.0 else int(signf(delta.y))
	# Hop over ants.
	var jump: bool = false
	for a in sim.ants:
		var ad: float = (a.pos.x - p.pos.x) * mv
		if mv != 0 and ad > 0.0 and ad < 70.0 and absf(a.pos.y - p.pos.y) < 40.0 and p.on_ground:
			jump = true
	return _dig_drive(sim, mv, vt, jump, idx)


## Sends the inputs; the hop is held until its apex (to jump ants and to reach a ceiling that is out of reach).
func _dig_drive(sim: PlatformSim, mv: int, vt: int, jump: bool, idx: int) -> int:
	var p: PlatformBody = sim.player
	_flap_toggle = not _flap_toggle
	var want_hop: bool = jump or vt < 0
	var held: bool = want_hop and (p.vel.y < 0.0 or _flap_toggle) if p.on_ground else want_hop
	sim.set_move(mv)
	sim.set_vertical(vt)
	sim.set_jump(held)
	return idx


func _fly_bot(sim: PlatformSim, route: Array, idx_in: int) -> int:
	var idx: int = idx_in
	var p: PlatformBody = sim.player
	var fly: PlatformFly = sim.fly
	var target: Vector2 = p.pos
	var braking: bool = true
	if fly.bat != null:
		# Camp in the static shadow (index 0).
		target = fly.shadow_rect(0).get_center() + Vector2(0.0, 40.0)
	else:
		if idx < route.size():
			target = Vector2(route[idx][0], route[idx][1])
			var is_sap: bool = false
			for i in sim.nutrients_taken.size():
				if sim.layout.nutrients[i].distance_to(target) < 4.0 and not sim.nutrients_taken[i]:
					is_sap = true
			braking = is_sap
			if p.pos.distance_to(target) < (20.0 if is_sap else 40.0):
				idx += 1
	var d: Vector2 = target - p.pos
	var mv: int = 0
	if absf(d.x) > 8.0:
		mv = int(signf(d.x))
		if braking and signf(p.vel.x) == float(mv) and absf(d.x) < p.vel.x * p.vel.x / 3200.0 + 4.0:
			mv = -mv
	elif braking and absf(p.vel.x) > 30.0:
		mv = -int(signf(p.vel.x))
	sim.set_move(mv)
	# Flap when 56 px below the target (the flap rises ~70 px), glide down in between: the held button keeps the glide.
	_flap_toggle = not _flap_toggle
	var wants_flap: bool = p.pos.y > target.y + 56.0 and p.vel.y > -20.0
	sim.set_jump(not (wants_flap and _flap_toggle))
	return idx

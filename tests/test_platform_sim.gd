## Egg platformer sim: feel, collisions, ants, rules, and a bot that finishes the three levels.
##   godot --headless --path . res://tests/TestPlatformSim.tscn
extends Node

const DT: float = 1.0 / 60.0
const FLOOR_Y: float = 600.0

var failures: int = 0
var _signals: Dictionary = {}
var _bot_ground_feet: float = 0.0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	_jump_height()
	_coyote_and_buffer()
	_one_way()
	_slopes()
	_no_tunnelling_and_corners()
	_pit_and_checkpoint()
	_ant_contact()
	_stomp()
	_stomp_not_boss()
	_hidden()
	_lost()
	_ants_stay_on_ledges()
	_determinism()
	_bot_levels()
	_wind()
	_rain()
	_puddles()
	_wasp_cycle()
	_wasp_hidden()
	_wasp_hit()
	_hatched()
	_hearts_upgrade()
	_tuft_flatten()
	_storm_levels()
	_boss_bots()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


## A flat test world: ground from x=0 to `ground_w`, start on it.
func _flat_layout(ground_w: float = 1200.0) -> PlatformLayout:
	var lay := PlatformLayout.new()
	lay.size = Vector2(2000.0, 720.0)
	lay.solids = [Rect2(0.0, FLOOR_Y, ground_w, 120.0)] as Array[Rect2]
	lay.start = Vector2(200.0, FLOOR_Y - 14.0)
	lay.goal = Rect2(1900.0, 0.0, 90.0, 300.0)
	return lay


func _make(lay: PlatformLayout) -> PlatformSim:
	var level := LevelDef.new()
	level.id = "test"
	level.layout = lay
	var sim := PlatformSim.new()
	sim.setup(level)
	_signals = {"hurt": 0, "respawn": 0, "cp": 0, "stats": {}, "jump": 0}
	sim.player_hurt.connect(func(_h: int) -> void: _signals["hurt"] += 1)
	sim.respawned.connect(func() -> void: _signals["respawn"] += 1)
	sim.checkpoint_reached.connect(func(_i: int) -> void: _signals["cp"] += 1)
	sim.level_finished.connect(func(s: Dictionary) -> void: _signals["stats"] = s)
	sim.sfx.connect(func(n: String, _p: Dictionary) -> void:
		if n == "jump":
			_signals["jump"] += 1)
	return sim


func _run(sim: PlatformSim, seconds: float) -> void:
	for _i in roundi(seconds * 60.0):
		sim.step(DT)


func _settle(sim: PlatformSim) -> void:
	_run(sim, 0.5)


# ------------------------------------------------------------------ feel

func _apex(hold_frames: int) -> float:
	var sim := _make(_flat_layout())
	_settle(sim)
	var y0: float = sim.player.pos.y
	sim.set_jump(true)
	var top: float = y0
	for i in 90:
		if i >= hold_frames:
			sim.set_jump(false)
		sim.step(DT)
		top = minf(top, sim.player.pos.y)
	return y0 - top


func _jump_height() -> void:
	var sim := _make(_flat_layout())
	_settle(sim)
	_check(sim.player.on_ground and absf(sim.player.pos.y - (FLOOR_Y - 14.0)) < 0.6, "egg rests on the ground (y=%.2f)" % sim.player.pos.y)
	var full: float = _apex(90)
	var tap: float = _apex(2)
	var expected: float = PlatformSim.JUMP_SPEED * PlatformSim.JUMP_SPEED / (2.0 * PlatformSim.GRAVITY)
	_check(absf(full - expected) < 6.0, "full jump ~%.0f px (got %.1f)" % [expected, full])
	_check(tap < full * 0.4 and tap > 5.0, "tap jump is much lower (%.1f vs %.1f)" % [tap, full])
	# Acceleration and top speed.
	sim = _make(_flat_layout())
	sim.set_move(1)
	_run(sim, 0.05)
	_check(sim.player.vel.x > 20.0 and sim.player.vel.x < PlatformSim.MAX_RUN, "accelerates gradually (%.0f)" % sim.player.vel.x)
	_run(sim, 1.0)
	_check(is_equal_approx(sim.player.vel.x, PlatformSim.MAX_RUN), "reaches top speed")
	sim.set_move(0)
	_run(sim, 0.5)
	_check(absf(sim.player.vel.x) < 0.01, "friction stops the egg")
	# Max fall speed.
	sim = _make(_flat_layout())
	sim.player.pos = Vector2(300.0, -2000.0)
	var vmax: float = 0.0
	for _i in 200:
		sim.step(DT)
		vmax = maxf(vmax, sim.player.vel.y)
		if sim.player.on_ground:
			break
	_check(is_equal_approx(vmax, PlatformSim.MAX_FALL) and sim.player.on_ground, "fall speed is capped and she lands (%.0f)" % vmax)


## Runs off a ledge; returns true if a jump pressed `delay` seconds after leaving the ground works.
func _coyote_jump(delay: float) -> bool:
	var sim := _make(_flat_layout(400.0))
	sim.player.pos = Vector2(380.0, FLOOR_Y - 14.0)
	_settle(sim)
	sim.set_move(1)
	var frames: int = 0
	while sim.player.on_ground and frames < 200:
		sim.step(DT)
		frames += 1
	var wait: int = roundi(delay * 60.0)
	_run(sim, wait * DT)
	var before: float = sim.player.vel.y
	sim.set_jump(true)
	sim.step(DT)
	return sim.player.vel.y < before - 300.0


func _coyote_and_buffer() -> void:
	_check(_coyote_jump(0.05), "coyote: jump 0.05 s after leaving the ledge works")
	_check(not _coyote_jump(0.25), "coyote: jump 0.25 s after leaving the ledge does not")
	# Buffer: press while falling, shortly before landing.
	var sim := _make(_flat_layout())
	sim.player.pos = Vector2(300.0, FLOOR_Y - 14.0 - 30.0)
	sim.player.on_ground = false
	var jumped: bool = false
	for i in 40:
		if i == 5:
			sim.set_jump(true)
		sim.step(DT)
		if sim.player.vel.y < -400.0:
			jumped = true
			break
	_check(jumped, "buffer: a jump pressed just before landing fires on landing")
	sim = _make(_flat_layout())
	sim.player.pos = Vector2(300.0, FLOOR_Y - 14.0 - 250.0)
	sim.player.on_ground = false
	sim.set_jump(true)
	sim.step(DT)
	sim.set_jump(false)
	_run(sim, 2.0)
	_check(sim.player.on_ground and sim.player.vel.y == 0.0, "buffer: an old press (too early) is forgotten")


# ------------------------------------------------------------------ collisions

func _one_way() -> void:
	var lay := _flat_layout()
	lay.platforms = [Rect2(100.0, 520.0, 300.0, 12.0)] as Array[Rect2]
	var sim := _make(lay)
	sim.player.pos = Vector2(250.0, FLOOR_Y - 14.0)
	_settle(sim)
	sim.set_jump(true)
	var rose_through: bool = false
	for _i in 90:
		sim.step(DT)
		if sim.player.pos.y + 14.0 < 520.0 and sim.player.vel.y < 0.0:
			rose_through = true
	sim.set_jump(false)
	_run(sim, 1.0)
	_check(rose_through, "one-way: jumping from below passes through the platform")
	_check(sim.player.on_ground and absf(sim.player.pos.y - (520.0 - 14.0)) < 0.6, "one-way: she lands on top of it (y=%.1f)" % sim.player.pos.y)
	# Walking off the edge drops her to the ground; she is not stuck on the needle.
	sim.set_move(1)
	_run(sim, 2.0)
	_check(sim.player.on_ground and sim.player.pos.y > FLOOR_Y - 20.0, "one-way: walking off the end falls to the ground")
	# Standing under it without jumping: the platform does not push her.
	sim = _make(lay)
	sim.player.pos = Vector2(250.0, FLOOR_Y - 14.0)
	_run(sim, 1.0)
	_check(absf(sim.player.pos.y - (FLOOR_Y - 14.0)) < 0.6, "one-way: no effect from below when standing")


func _slope_layout() -> PlatformLayout:
	var lay := _flat_layout(1800.0)
	lay.solids = [Rect2(0.0, FLOOR_Y, 1800.0, 120.0), Rect2(600.0, 540.0, 200.0, 60.0)] as Array[Rect2]
	lay.slopes = [PackedVector2Array([Vector2(480.0, 600.0), Vector2(600.0, 540.0)]), PackedVector2Array([Vector2(800.0, 540.0), Vector2(920.0, 600.0)])] as Array[PackedVector2Array]
	return lay


func _slopes() -> void:
	var sim := _make(_slope_layout())
	sim.set_move(1)
	var on_top: bool = false
	var always_grounded: bool = true
	var air_x: float = -1.0
	for i in 60 * 6:
		sim.step(DT)
		if sim.player.pos.x > 640.0 and sim.player.pos.x < 760.0 and absf(sim.player.pos.y - (540.0 - 14.0)) < 1.5 and sim.player.on_ground:
			on_top = true
		if sim.player.pos.x > 470.0 and sim.player.pos.x < 930.0 and not sim.player.on_ground:
			always_grounded = false
			air_x = sim.player.pos.x
	_check(on_top, "slopes: she walks up the ramp and onto the block")
	_check(always_grounded, "slopes: stays grounded on the way up and down (air at x=%.1f)" % air_x)
	_check(sim.player.pos.x > 1000.0 and absf(sim.player.pos.y - (FLOOR_Y - 14.0)) < 1.0, "slopes: walks down to the flat (x=%.0f)" % sim.player.pos.x)
	# Standing still on a slope does not slide.
	sim = _make(_slope_layout())
	sim.player.pos = Vector2(540.0, 572.0)
	_run(sim, 0.5)
	var x0: float = sim.player.pos.x
	_run(sim, 2.0)
	_check(absf(sim.player.pos.x - x0) < 0.5 and sim.player.on_ground, "slopes: no sliding when idle (dx=%.2f)" % (sim.player.pos.x - x0))
	# Walking back down the up ramp.
	sim.set_move(-1)
	_run(sim, 2.0)
	_check(sim.player.pos.x < 480.0 and sim.player.on_ground, "slopes: walks down the ramp to the left")


func _no_tunnelling_and_corners() -> void:
	var lay := _flat_layout()
	lay.solids = [Rect2(0.0, FLOOR_Y, 1200.0, 8.0), Rect2(700.0, 450.0, 10.0, 150.0)] as Array[Rect2]
	var sim := _make(lay)
	sim.player.pos = Vector2(300.0, -3000.0)
	_run(sim, 6.0)
	_check(sim.player.on_ground and absf(sim.player.pos.y - (FLOOR_Y - 14.0)) < 1.0, "no tunnelling: falls at max speed onto an 8 px floor")
	sim.player.vel = Vector2(1500.0, 0.0)
	sim.player.pos = Vector2(600.0, FLOOR_Y - 14.0)
	_run(sim, 0.5)
	_check(sim.player.pos.x < 700.0, "no tunnelling: a 10 px wall stops a very fast egg (x=%.0f)" % sim.player.pos.x)
	# Pressing into a wall while jumping, then walking away: not stuck.
	lay = _flat_layout()
	lay.solids = [Rect2(0.0, FLOOR_Y, 1200.0, 120.0), Rect2(500.0, 420.0, 100.0, 180.0)] as Array[Rect2]
	sim = _make(lay)
	sim.player.pos = Vector2(440.0, FLOOR_Y - 14.0)
	sim.set_move(1)
	for i in 120:
		sim.set_jump(i % 20 < 10)
		sim.step(DT)
	_check(sim.player.pos.x <= 500.0 - 14.0 + 0.5 or sim.player.pos.y < 520.0, "corner: the wall is solid")
	sim.set_jump(false)
	sim.set_move(-1)
	_run(sim, 1.5)
	_check(sim.player.pos.x < 400.0, "corner: she can walk away again (x=%.0f)" % sim.player.pos.x)
	# Climbing onto a low block by jumping against its corner.
	lay.solids = [Rect2(0.0, FLOOR_Y, 1200.0, 120.0), Rect2(500.0, 520.0, 100.0, 80.0)] as Array[Rect2]
	sim = _make(lay)
	sim.player.pos = Vector2(440.0, FLOOR_Y - 14.0)
	sim.set_move(1)
	var up: bool = false
	for i in 300:
		sim.set_jump(i % 40 < 20)
		sim.step(DT)
		if sim.player.on_ground and sim.player.pos.y < 510.0:
			up = true
	_check(up, "corner: she can jump onto the block")


# ------------------------------------------------------------------ rules

func _pit_layout() -> PlatformLayout:
	var lay := _flat_layout()
	lay.solids = [Rect2(0.0, FLOOR_Y, 500.0, 120.0), Rect2(620.0, FLOOR_Y, 880.0, 120.0)] as Array[Rect2]
	lay.checkpoints = [Vector2(900.0, FLOOR_Y)] as Array[Vector2]
	return lay


func _pit_and_checkpoint() -> void:
	var sim := _make(_pit_layout())
	sim.set_move(1)
	for _i in 60 * 4:
		sim.step(DT)
		if _signals["respawn"] > 0:
			break
	_check(sim.player.hearts == 2 and _signals["hurt"] == 1 and _signals["respawn"] == 1, "pit: costs a heart and respawns")
	_check(absf(sim.player.pos.x - 200.0) < 5.0 and sim.player.invuln > 1.0, "pit: back at the start, invulnerable")
	# Reach the checkpoint (jump over the gap), fall, respawn there.
	sim = _make(_pit_layout())
	sim.player.pos = Vector2(300.0, FLOOR_Y - 14.0)
	sim.set_move(1)
	var frames: int = 0
	while sim.checkpoint_idx < 0 and frames < 600:
		sim.set_jump(sim.player.pos.x > 480.0 and sim.player.pos.x < 640.0)
		sim.step(DT)
		frames += 1
	_check(sim.checkpoint_idx == 0 and _signals["cp"] == 1, "checkpoint: reached after the gap")
	sim.player.pos = Vector2(1000.0, 900.0)
	sim.step(DT)
	_check(sim.player.hearts == 2 and absf(sim.player.pos.x - 900.0) < 1.0 and sim.player.pos.y < FLOOR_Y, "checkpoint: respawn on the last checkpoint")


func _ant_layout() -> PlatformLayout:
	var lay := _flat_layout()
	lay.ants = [Rect2(400.0, FLOOR_Y, 300.0, 60.0)] as Array[Rect2]
	lay.tufts = [Rect2(150.0, 540.0, 100.0, 60.0)] as Array[Rect2]
	return lay


func _ant_contact() -> void:
	var sim := _make(_ant_layout())
	sim.player.pos = Vector2(430.0, FLOOR_Y - 14.0)
	sim.ants[0].pos.x = 400.0
	sim.ants[0].pos.y = FLOOR_Y - 12.0
	_run(sim, 0.1)
	_check(sim.player.hearts == 2 and _signals["hurt"] == 1, "ant: contact costs one heart")
	_check(sim.player.invuln > 1.0 and sim.player.invuln <= PlatformSim.INVULN_TIME, "ant: 1.2 s of invulnerability")
	_check(sim.player.vel.x > 100.0 or sim.player.pos.x > 470.0, "ant: knockback away from the ant")
	var hearts_before: int = sim.player.hearts
	sim.player.pos = sim.ants[0].pos + Vector2(5.0, 0.0)
	_run(sim, 0.5)
	_check(sim.player.hearts == hearts_before, "ant: no second bite while invulnerable")
	_run(sim, 1.0)
	_check(sim.player.invuln == 0.0, "ant: invulnerability ends")
	# An ant chases when it sees her and goes back to patrolling.
	sim = _make(_ant_layout())
	sim.player.pos = Vector2(700.0 + 100.0, FLOOR_Y - 14.0)
	sim.ants[0].pos.x = 690.0
	_run(sim, 0.2)
	_check(sim.ants[0].state == "CHASE", "ant: chases on sight")
	sim.player.pos = Vector2(1500.0, FLOOR_Y - 14.0)
	_run(sim, 0.3)
	_check(sim.ants[0].state == "LOST", "ant: LOST after losing her")
	_run(sim, 1.5)
	_check(sim.ants[0].state == "PATROL", "ant: back to patrolling")


## Drops the egg on the ant from `height` px above its top; returns the sim after the stomp frame (jump held if `hold`).
func _drop_on_ant(hold: bool, height: float = 40.0) -> PlatformSim:
	var sim := _make(_ant_layout())
	var ant: PlatformAnt = sim.ants[0]
	ant.pos = Vector2(500.0, FLOOR_Y - ant.radius)
	sim.player.pos = Vector2(500.0, ant.pos.y - ant.radius - sim.player.radius - height)
	sim.player.on_ground = false
	sim.set_jump(hold)
	for _i in 120:
		sim.step(DT)
		if ant.knocked:
			break
	return sim


func _stomp() -> void:
	var stomped: Array = []
	var texts: Array[String] = []
	var sim := _make(_ant_layout())
	sim.ant_stomped.connect(func(idx: int, pos: Vector2) -> void: stomped.append([idx, pos]))
	sim.float_text.connect(func(_p: Vector2, t: String, _c: Color) -> void: texts.append(t))
	var ant: PlatformAnt = sim.ants[0]
	ant.pos = Vector2(500.0, FLOOR_Y - ant.radius)
	sim.player.pos = Vector2(500.0, ant.pos.y - ant.radius - sim.player.radius - 40.0)
	sim.player.on_ground = false
	for _i in 120:
		sim.step(DT)
		if ant.knocked:
			break
	_check(ant.knocked and stomped.size() == 1 and stomped[0][0] == 0, "stomp: landing on the ant from above knocks it out and emits ant_stomped")
	_check(sim.player.hearts == 3 and _signals["hurt"] == 0, "stomp: no damage to the egg")
	_check(texts.size() == 1 and texts[0] in ["FT_PLAT_STOMP", "Knocked out!", "Noquejada!"], "stomp: one floating text")
	_check(sim.player.vel.y < -300.0 and not sim.player.on_ground, "stomp: the egg bounces up (vy %.0f)" % sim.player.vel.y)
	var pos_before: Vector2 = ant.pos
	_run(sim, 1.0)
	_check(sim.player.hearts == 3 and ant.pos == pos_before, "stomp: a knocked-out ant neither moves nor bites")
	_check(ant.gone and ant.ko_age >= PlatformSim.KO_TIME, "stomp: the ant disappears after the squash")
	var auto_rise: float = _stomp_rise(false)
	var held_rise: float = _stomp_rise(true)
	_check(held_rise > auto_rise + 20.0 and auto_rise > 40.0, "stomp: bounce is higher with jump held (%.0f vs %.0f px)" % [held_rise, auto_rise])
	# Side contact and contact from below still hurt.
	sim = _make(_ant_layout())
	ant = sim.ants[0]
	ant.pos = Vector2(500.0, FLOOR_Y - ant.radius)
	sim.player.pos = Vector2(505.0, ant.pos.y)
	sim.player.vel.y = 100.0
	sim.player.on_ground = false
	sim.step(DT)
	_check(not ant.knocked and sim.player.hearts == 2, "stomp: falling alongside the ant (side contact) still hurts")
	sim = _make(_ant_layout())
	ant = sim.ants[0]
	ant.pos = Vector2(500.0, FLOOR_Y - ant.radius)
	sim.player.pos = Vector2(505.0, ant.pos.y - ant.radius + 2.0)
	sim.player.vel.y = -200.0
	sim.player.on_ground = false
	sim.step(DT)
	_check(not ant.knocked and sim.player.hearts == 2, "stomp: rising over the ant still hurts")
	sim = _make(_ant_layout())
	ant = sim.ants[0]
	ant.pos = Vector2(500.0, FLOOR_Y - ant.radius)
	sim.player.pos = Vector2(480.0, FLOOR_Y - 14.0)
	sim.set_move(1)
	_run(sim, 1.0)
	_check(not ant.knocked and sim.player.hearts < 3, "stomp: walking into the ant on the ground still hurts")


## Highest rise (px) of the egg after stomping an ant from 40 px, with jump held or not.
func _stomp_rise(hold: bool) -> float:
	var sim := _drop_on_ant(hold)
	var y0: float = sim.player.pos.y
	var top: float = y0
	for _i in 90:
		sim.step(DT)
		top = minf(top, sim.player.pos.y)
	return y0 - top


func _stomp_not_boss() -> void:
	var sim := _boss_make(_boss_layout())
	sim.player.pos = sim.boss.pos + Vector2(0.0, -22.0)
	sim.player.vel.y = 300.0
	sim.player.on_ground = false
	sim.step(DT)
	_check(sim.player.hearts == 2 and not sim.player.invuln == 0.0, "stomp: the wasp cannot be stomped (hearts %d)" % sim.player.hearts)


func _hidden() -> void:
	var sim := _make(_ant_layout())
	sim.player.pos = Vector2(200.0, FLOOR_Y - 14.0)
	sim.ants[0].pos.x = 410.0
	sim.ants[0].x_min = 0.0
	_run(sim, 0.3)
	_check(sim.player.hidden, "hidden: standing still in a tuft hides her")
	var saw_chase: bool = false
	for _i in 60 * 12:
		sim.step(DT)
		if sim.ants[0].state == "CHASE":
			saw_chase = true
	_check(sim.player.hearts == 3 and not saw_chase, "hidden: ants walk past without chasing or biting (12 s)")
	sim.set_move(1)
	_run(sim, 0.1)
	_check(not sim.player.hidden, "hidden: moving reveals her")
	# Jumping in a tuft does not hide either.
	sim.set_move(0)
	sim.set_jump(true)
	_run(sim, 0.1)
	_check(not sim.player.hidden, "hidden: not while in the air")


func _lost() -> void:
	var lay := _flat_layout()
	lay.solids = [Rect2(0.0, FLOOR_Y + 300.0, 100.0, 20.0)] as Array[Rect2]
	lay.nutrients = [Vector2(1000.0, 500.0), Vector2(1100.0, 500.0)] as Array[Vector2]
	var sim := _make(lay)
	_run(sim, 4.0)
	_check(sim.finished and not sim.won and sim.player.hearts == 0, "lost: 0 hearts ends the level")
	var s: Dictionary = _signals["stats"]
	_check(s.get("won", true) == false and s.get("stars", -1) == 0 and s.get("reason", "") == "LOST" and s.get("level_id", "") == "test", "lost: stats (won false, 0 stars, LOST)")
	_check(s.get("nutrients_total", 0) == 2 and s.get("hearts_left", -1) == 0 and s.has("time") and s.has("nutrients"), "lost: stats keys")
	var t: float = sim.time
	sim.step(DT)
	_check(sim.time == t, "lost: the sim stops")


func _ants_stay_on_ledges() -> void:
	for id in ["egg_1", "egg_2", "egg_3"]:
		var level := load("res://data/levels/%s.tres" % id) as LevelDef
		var sim := PlatformSim.new()
		sim.setup(level)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var bad: int = 0
		var chased: bool = false
		var home: Array[float] = []
		for a in sim.ants:
			home.append(a.feet())
		for i in 60 * 120:
			if i % 90 == 0:
				sim.set_move(rng.randi_range(-1, 1))
				sim.set_jump(rng.randf() < 0.5)
			sim.player.hearts = 99
			sim.step(DT)
			for k in sim.ants.size():
				var a: PlatformAnt = sim.ants[k]
				var sy: float = sim.surface_y(a.pos.x, a.feet(), 3.0, 3.0)
				if is_inf(sy) or absf(sy - a.feet()) > 1.0 or absf(a.feet() - home[k]) > 70.0:
					bad += 1
				if a.state == "CHASE":
					chased = true
			if sim.finished:
				break
		_check(bad == 0, "%s: ants never leave their surface in 120 s (%d bad frames, chased=%s)" % [id, bad, chased])


func _scripted_run(level: LevelDef, seed_v: int) -> Array:
	var sim := PlatformSim.new()
	sim.setup(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in 60 * 30:
		if i % 20 == 0:
			sim.set_move(rng.randi_range(-1, 1))
			sim.set_jump(rng.randf() < 0.5)
		sim.step(DT)
	return [sim.player.pos, sim.player.vel, sim.player.hearts, sim.nutrients_taken.duplicate(), sim.time, sim.ants[0].pos]


func _determinism() -> void:
	var level := load("res://data/levels/egg_2.tres") as LevelDef
	var a: Array = _scripted_run(level, 3)
	var b: Array = _scripted_run(level, 3)
	_check(a == b, "determinism: the same inputs give the same state")


# ------------------------------------------------------------------ the three levels

var _bot_last_held: bool = false


## Simple bot: walks to the next nutrient (they are listed in route order), then the goal; jumps at ledges,
## walls, ants and when the target is above.
func _bot_input(sim: PlatformSim, target: Vector2) -> void:
	var p := sim.player
	var dx: float = target.x - p.pos.x
	var dir: int = 0 if absf(dx) < 4.0 else (1 if dx > 0.0 else -1)
	var want: bool = false
	var feet: float = p.pos.y + p.radius
	if p.on_ground and dir != 0:
		var ahead: float = p.pos.x + dir * (p.radius + 28.0)
		var sy: float = sim.surface_y(ahead, feet, 120.0, 60.0)
		var lower_target: bool = target.y > p.pos.y + 40.0
		if is_inf(sy) and not lower_target:
			want = true
		elif not is_inf(sy) and sy < feet - 16.0:
			want = true
	if p.on_ground and target.y < p.pos.y - 30.0 and absf(dx) < 60.0:
		want = true
	if p.on_ground:
		for a in sim.ants:
			var ad: float = (a.pos.x - p.pos.x) * dir
			if dir != 0 and ad > 0.0 and ad < 110.0 and absf(a.feet() - feet) < 40.0 and not p.hidden:
				want = true
	var held: bool = (want and not _bot_last_held) if p.on_ground else true
	_bot_last_held = held
	sim.set_move(dir)
	sim.set_jump(held)


## A target too high for one jump: aim at the nearest platform below it that she can reach (stomping ants changes how she gets up).
func _bot_waypoint(sim: PlatformSim, target: Vector2) -> Vector2:
	var p := sim.player
	if p.on_ground:
		_bot_ground_feet = p.pos.y + p.radius
	var feet: float = _bot_ground_feet
	if target.y > feet - 120.0 or absf(target.x - p.pos.x) > 200.0:
		return target
	var best: Vector2 = target
	var best_d: float = INF
	for q in sim.layout.platforms:
		var top: float = q.position.y
		if top < target.y + 10.0 or top > feet - 30.0 or top < feet - 100.0:
			continue
		var c := Vector2(q.get_center().x, top - p.radius)
		var d: float = absf(c.x - p.pos.x)
		if d < best_d and absf(c.x - target.x) < 200.0:
			best_d = d
			best = c
	return best


func _bot_levels() -> void:
	for id in ["egg_1", "egg_2", "egg_3", "egg_4"]:
		var level := load("res://data/levels/%s.tres" % id) as LevelDef
		_check(level.mode == "PLATFORM" and level.layout != null and level.playable, "%s is a playable PLATFORM level" % id)
		var sim := PlatformSim.new()
		sim.setup(level)
		var holder: Dictionary = {}
		sim.level_finished.connect(func(s: Dictionary) -> void: holder["s"] = s)
		_bot_last_held = false
		var frames: int = 0
		while not sim.finished and frames < 60 * 300:
			var target: Vector2 = level.layout.goal.get_center()
			for i in level.layout.nutrients.size():
				if not sim.nutrients_taken[i]:
					target = level.layout.nutrients[i]
					break
			_bot_input(sim, _bot_waypoint(sim, target))
			sim.step(DT)
			frames += 1
		var stats: Dictionary = holder.get("s", {})
		_check(sim.won and stats.get("stars", 0) == 3 and stats.get("reason", "") == "REACHED_GOAL", "%s: bot wins with 3 stars in %.1f s, %d/%d nutrients, %d hearts, checkpoint %d" % [id, sim.time, stats.get("nutrients", -1), stats.get("nutrients_total", -1), stats.get("hearts_left", -1), sim.checkpoint_idx])
		var buried: int = 0
		for pt in level.layout.nutrients:
			for r in level.layout.solids:
				if r.grow(12.0).has_point(pt):
					buried += 1
		_check(buried == 0 and level.layout.checkpoints.size() == (2 if id in ["egg_3", "egg_4"] else (1 if id == "egg_2" else 0)), "%s: nutrients are in the open, %d checkpoints" % [id, level.layout.checkpoints.size()])
		var n: int = level.layout.nutrients.size()
		_check(n >= 6 and n <= 12 and level.layout.size.x >= 1900.0, "%s: %d nutrients, %.0f px, %d ants" % [id, n, level.layout.size.x, level.layout.ants.size()])


# ------------------------------------------------------------------ storm and boss (§7)

func _storm_layout() -> PlatformLayout:
	var lay := _flat_layout()
	lay.wind_zones = [Rect2(300.0, 300.0, 600.0, 320.0)] as Array[Rect2]
	lay.wind_force = [700.0] as Array[float]
	lay.tufts = [Rect2(600.0, 540.0, 90.0, 60.0)] as Array[Rect2]
	return lay


func _wind() -> void:
	var sim := _make(_storm_layout())
	_run(sim, 1.0)
	_check(sim.player.vel.x < 1.0 and sim.player.wind == 0.0, "wind: no push outside the zone")
	sim.player.pos = Vector2(350.0, FLOOR_Y - 14.0)
	_run(sim, 1.0)
	_check(sim.player.wind == 700.0 and sim.player.vel.x > 50.0 and sim.player.pos.x > 400.0, "wind: pushes an idle egg on the ground (vx=%.0f)" % sim.player.vel.x)
	var dx_ground: float = sim.player.pos.x
	# In the air the drift is stronger than on the ground.
	sim = _make(_storm_layout())
	sim.player.pos = Vector2(350.0, 400.0)
	_run(sim, 0.4)
	_check(sim.player.vel.x > 100.0, "wind: pushes harder in the air (vx=%.0f)" % sim.player.vel.x)
	# Running against it is slower than running with it.
	sim = _make(_storm_layout())
	sim.player.pos = Vector2(850.0, FLOOR_Y - 14.0)
	sim.set_move(-1)
	_run(sim, 0.5)
	_check(sim.player.vel.x > -PlatformSim.MAX_RUN + 50.0, "wind: a headwind slows running (vx=%.0f)" % sim.player.vel.x)
	# A tuft shelters from the wind and the egg hides in it.
	sim = _make(_storm_layout())
	sim.player.pos = Vector2(640.0, FLOOR_Y - 14.0)
	_run(sim, 1.0)
	_check(sim.player.hidden and absf(sim.player.vel.x) < 1.0 and sim.wind_at(sim.player.pos) == 0.0, "wind: a tuft shelters her and she can hide in the zone")
	_check(dx_ground > 400.0, "wind: ground drift moved her")
	# Gusts: calm 20 % most of the time, a signal at each swell.
	var lay := _storm_layout()
	lay.wind_period = [4.0] as Array[float]
	sim = _make(lay)
	var gusts: Array = []
	sim.storm_gust.connect(func(d: int) -> void: gusts.append(d))
	var lo: float = 1e9
	var hi: float = 0.0
	for _i in 60 * 12:
		sim.step(DT)
		lo = minf(lo, sim.wind_strength(0))
		hi = maxf(hi, sim.wind_strength(0))
	_check(gusts.size() == 3 and gusts[0] == 1, "wind: a gust signal every period (%d in 12 s)" % gusts.size())
	_check(absf(lo - 140.0) < 1.0 and absf(hi - 700.0) < 1.0, "wind: gusts swing between 20 %% and full strength (%.0f..%.0f)" % [lo, hi])


func _rain_layout(rate: float) -> PlatformLayout:
	var lay := _flat_layout()
	lay.storm = true
	lay.rain_rate = rate
	return lay


func _rain() -> void:
	var sim := _make(_rain_layout(0.0))
	_run(sim, 3.0)
	_check(sim.drops.is_empty(), "rain: none when rain_rate is 0")
	sim = _make(_rain_layout(4.0))
	var splashes: Array = []
	sim.splash.connect(func(_pos: Vector2, k: String) -> void: splashes.append(k))
	_run(sim, 0.4)
	var d: PlatformDrop = sim.drops[0] if not sim.drops.is_empty() else null
	_check(d != null and absf(d.ground_y - FLOOR_Y) < 0.1 and d.pos.y < d.ground_y, "rain: drops fall towards a known ground y")
	_run(sim, 3.0)
	_check(splashes.has("RAIN"), "rain: drops splash on the ground")
	# A drop on her head: knocked back, no heart lost.
	sim = _make(_flat_layout())
	_settle(sim)
	var drop := PlatformDrop.new()
	drop.pos = sim.player.pos + Vector2(-6.0, -20.0)
	drop.ground_y = FLOOR_Y
	sim.drops.append(drop)
	sim.layout.rain_rate = 0.001
	var x0: float = sim.player.pos.x
	_run(sim, 0.15)
	_check(sim.player.hearts == 3 and _signals["hurt"] == 0, "rain: a hit costs no heart")
	_check(sim.player.vel.x > 50.0 or sim.player.pos.x > x0 + 4.0, "rain: knocks her away from the drop (x +%.1f)" % (sim.player.pos.x - x0))
	_check(sim.drops.is_empty() and sim.player.invuln == 0.0, "rain: the drop is gone and no invulnerability is given")
	# A hidden egg is sheltered.
	var lay := _ant_layout()
	lay.ants = [] as Array[Rect2]
	sim = _make(lay)
	sim.player.pos = Vector2(200.0, FLOOR_Y - 14.0)
	_run(sim, 0.3)
	var drop2 := PlatformDrop.new()
	drop2.pos = sim.player.pos + Vector2(0.0, -10.0)
	drop2.ground_y = FLOOR_Y
	sim.drops.append(drop2)
	sim.layout.rain_rate = 0.001
	_run(sim, 0.1)
	_check(sim.player.hidden and absf(sim.player.vel.x) < 1.0, "rain: a hidden egg is not knocked")


func _puddles() -> void:
	var lay := _flat_layout()
	lay.puddles = [Rect2(500.0, FLOOR_Y - 8.0, 300.0, 8.0)] as Array[Rect2]
	var sim := _make(lay)
	var splashes: Array = []
	sim.splash.connect(func(_pos: Vector2, k: String) -> void: splashes.append(k))
	sim.set_move(1)
	_run(sim, 1.0)
	var dry: float = sim.player.vel.x
	_check(is_equal_approx(dry, PlatformSim.MAX_RUN) and not sim.player.in_puddle, "puddle: full speed on dry ground")
	_run(sim, 1.0)
	_check(sim.player.in_puddle and absf(sim.player.vel.x - PlatformSim.MAX_RUN * PlatformSim.PUDDLE_SLOW) < 1.0, "puddle: top speed drops to %.0f (vx=%.0f)" % [PlatformSim.MAX_RUN * PlatformSim.PUDDLE_SLOW, sim.player.vel.x])
	_check(splashes.has("PUDDLE"), "puddle: splash signal")
	_run(sim, 2.0)
	_check(not sim.player.in_puddle and sim.player.vel.x > PlatformSim.MAX_RUN - 1.0, "puddle: speed comes back after it")
	# A jump over it is not slowed.
	sim = _make(lay)
	sim.player.pos = Vector2(520.0, 300.0)
	sim.set_move(1)
	_run(sim, 0.2)
	_check(not sim.player.in_puddle, "puddle: not while in the air")


## A flat arena with a wasp. Tufts at 100..190 and 1100..1190.
func _boss_layout(time_s: float = 60.0) -> PlatformLayout:
	var lay := PlatformLayout.new()
	lay.size = Vector2(1400.0, 720.0)
	lay.solids = [Rect2(0.0, 620.0, 1400.0, 100.0)] as Array[Rect2]
	lay.start = Vector2(700.0, 606.0)
	lay.goal = Rect2()
	lay.tufts = [Rect2(100.0, 560.0, 90.0, 60.0), Rect2(1100.0, 560.0, 90.0, 60.0)] as Array[Rect2]
	lay.boss = "WASP"
	lay.boss_time = time_s
	lay.arena = Rect2(0.0, 0.0, 1400.0, 720.0)
	return lay


func _boss_make(lay: PlatformLayout) -> PlatformSim:
	var sim := _make(lay)
	_signals["warn"] = []
	_signals["dive"] = 0
	_signals["missed"] = 0
	sim.boss_warn.connect(func(t: Vector2) -> void: _signals["warn"].append(t))
	sim.boss_dive.connect(func() -> void: _signals["dive"] += 1)
	sim.boss_missed.connect(func() -> void: _signals["missed"] += 1)
	return sim


## Steps until the boss enters `state`; returns the seconds waited, or -1.
func _until_state(sim: PlatformSim, state: String, max_s: float) -> float:
	for i in roundi(max_s * 60.0):
		if sim.boss.state == state:
			return float(i) * DT
		sim.step(DT)
	return -1.0


func _wasp_cycle() -> void:
	var sim := _boss_make(_boss_layout())
	_check(sim.boss != null and sim.boss.state == "PATROL" and sim.time_left == 60.0, "wasp: starts patrolling, time_left = boss_time")
	_run(sim, 1.0)
	_check(sim.time_left == 60.0 and sim.boss.state == "PATROL", "wasp: the intro does not run the clock or attack")
	var flew_high: bool = true
	for _i in 60 * 4:
		sim.step(DT)
		if sim.boss.state == "PATROL" and sim.boss.pos.y > 400.0:
			flew_high = false
	_check(flew_high and sim.time_left < 60.0, "wasp: patrols high above the arena")
	# Warn -> dive -> recover, with timings of the start of the fight.
	sim = _boss_make(_boss_layout())
	_check(_until_state(sim, "WARN", 6.0) > 0.0 and _signals["warn"].size() == 1, "wasp: WARN starts with a boss_warn signal")
	var w0: float = sim.boss.warn_time
	var target0: Vector2 = sim.boss.target
	var warn_len: float = _until_state(sim, "DIVE", 2.0)
	_check(absf(w0 - 0.8) < 0.05 and absf(warn_len - w0) < 0.1 and _signals["dive"] == 1, "wasp: warns for %.2f s then dives" % warn_len)
	_check(absf(sim.boss.target.x - target0.x) < 260.0, "wasp: the target is where Perleta was")
	# The dive is a straight line towards the target.
	var start: Vector2 = sim.boss.pos
	var dir: Vector2 = sim.boss.dive_dir
	var straight: bool = true
	var dive_frames: int = 0
	while sim.boss.state == "DIVE" and dive_frames < 200:
		sim.step(DT)
		dive_frames += 1
		var off: float = absf((sim.boss.pos - start).cross(dir))
		if off > 6.0:
			straight = false
	_check(straight and dive_frames > 10 and dive_frames < 90, "wasp: dives in a straight line (%d frames)" % dive_frames)
	_check(sim.boss.state == "RECOVER", "wasp: recovers after the dive")
	var rec: float = _until_state(sim, "PATROL", 3.0)
	_check(rec > 0.9 and rec < 1.4, "wasp: recovers for about 1.2 s (%.2f)" % rec)
	# Difficulty: cycles are shorter near the end of the timer.
	var early: float = _cycle_length(60.0, 0.0)
	var late: float = _cycle_length(60.0, 55.0)
	_check(late < early - 1.0, "wasp: attacks speed up as time_left shrinks (cycle %.2f s -> %.2f s)" % [early, late])


## Seconds between two consecutive WARN starts when `elapsed` seconds of the boss time are already gone.
func _cycle_length(boss_time: float, elapsed: float) -> float:
	var sim := _boss_make(_boss_layout(boss_time))
	sim.time_left = boss_time - elapsed
	sim.player.invuln = 999.0
	_run(sim, PlatformBoss.INTRO)
	_until_state(sim, "WARN", 10.0)
	_until_state(sim, "DIVE", 3.0)
	var t0: float = sim.time
	_until_state(sim, "RECOVER", 3.0)
	_until_state(sim, "PATROL", 3.0)
	_until_state(sim, "WARN", 10.0)
	return sim.time - t0 + 0.8


func _wasp_hidden() -> void:
	var lay := _boss_layout()
	var sim := _boss_make(lay)
	sim.player.pos = Vector2(145.0, 606.0)
	_run(sim, 0.4)
	_check(sim.player.hidden, "wasp: the egg hides in the tuft")
	var hits_before: int = _signals["hurt"]
	var closest: float = 1e9
	_until_state(sim, "DIVE", 8.0)
	for _i in 120:
		if sim.boss.state != "DIVE":
			break
		sim.step(DT)
		closest = minf(closest, sim.boss.pos.distance_to(sim.player.pos))
	_check(_signals["missed"] == 1 and _signals["hurt"] == hits_before and sim.player.hearts == 3 and closest > 60.0, "wasp: the first dive at a hidden egg misses (closest %.0f px)" % closest)
	# Revealed (moving) at the dive start: it is a real attack.
	sim = _boss_make(lay)
	sim.player.pos = Vector2(145.0, 606.0)
	_until_state(sim, "WARN", 8.0)
	_check(sim.boss.target.distance_to(sim.player.pos) < 5.0, "wasp: aims at her position when she is not hidden yet")


func _wasp_hit() -> void:
	var sim := _boss_make(_boss_layout())
	# Stand still on open ground: the dive hits.
	var hurt_at: float = -1.0
	for _i in 60 * 12:
		sim.step(DT)
		if _signals["hurt"] > 0:
			hurt_at = sim.time
			break
	_check(sim.player.hearts == 2 and hurt_at > 0.0 and sim.boss.state in ["DIVE", "RECOVER"], "wasp: a dive that connects costs one heart (t=%.1f)" % hurt_at)
	_check(sim.player.invuln > 1.0 and (sim.player.vel.x != 0.0 or sim.player.hurt_lock > 0.0), "wasp: knockback and 1.2 s of invulnerability")
	# No second hit while invulnerable.
	var hearts: int = sim.player.hearts
	_run(sim, 0.5)
	_check(sim.player.hearts == hearts, "wasp: no double hit while invulnerable")
	# Dying: 3 hits end the level as LOST.
	sim = _boss_make(_boss_layout())
	for _i in 60 * 60:
		sim.step(DT)
		if sim.finished:
			break
	_check(sim.finished and not sim.won and _signals["stats"].get("reason", "") == "LOST", "wasp: a motionless egg loses (hearts %d, t=%.1f)" % [sim.player.hearts, sim.time])


func _hatched() -> void:
	var lay := _boss_layout(8.0)
	lay.start = Vector2(145.0, 606.0)
	var sim := _boss_make(lay)
	sim.player.invuln = 999.0
	_run(sim, PlatformBoss.INTRO + 7.0)
	_check(not sim.finished and sim.time_left > 0.0 and sim.time_left < 1.5, "hatch: still running just before the end (%.2f s left)" % sim.time_left)
	_run(sim, 1.6)
	var s: Dictionary = _signals["stats"]
	_check(sim.finished and sim.won and s.get("reason", "") == "HATCHED" and s.get("won", false), "hatch: surviving boss_time wins with reason HATCHED")
	_check(s.get("stars", 0) == 3 and s.get("hearts_left", 0) == 3 and s.get("level_id", "") == "test" and s.has("time"), "hatch: 3 hearts = 3 stars (stats %s)" % str(s))
	_check(sim.time_left == 0.0, "hatch: time_left is 0")
	# Stars follow the hearts; sap in the arena caps a sap-less run at 2.
	lay = _boss_layout(3.0)
	lay.start = Vector2(145.0, 606.0)
	sim = _boss_make(lay)
	sim.player.hearts = 1
	_run(sim, PlatformBoss.INTRO + 3.2)
	_check(_signals["stats"].get("stars", 0) == 1 and sim.won, "hatch: 1 heart left = 1 star")
	lay = _boss_layout(3.0)
	lay.start = Vector2(145.0, 606.0)
	lay.nutrients = [Vector2(900.0, 300.0)] as Array[Vector2]
	sim = _boss_make(lay)
	_run(sim, PlatformBoss.INTRO + 3.2)
	_check(_signals["stats"].get("stars", 0) == 2 and _signals["stats"].get("nutrients_total", 0) == 1, "hatch: missing sap in the arena caps the stars at 2")


func _storm_levels() -> void:
	var level := load("res://data/levels/egg_4.tres") as LevelDef
	var lay := level.layout
	_check(level.mode == "PLATFORM" and level.playable and lay.storm and lay.boss == "", "egg_4: playable storm level, no boss")
	_check(lay.wind_zones.size() == lay.wind_force.size() and lay.wind_zones.size() == lay.wind_period.size() and lay.rain_rate > 0.0 and lay.puddles.size() >= 3, "egg_4: wind (%d zones), rain %.1f/s, %d puddles" % [lay.wind_zones.size(), lay.rain_rate, lay.puddles.size()])
	_check(lay.size.x >= 3000.0 and lay.checkpoints.size() == 2 and lay.nutrients.size() == 10 and lay.ants.size() >= 4, "egg_4: %.0f px, 2 checkpoints, 10 sap, %d ants" % [lay.size.x, lay.ants.size()])
	for t in lay.tufts:
		for z in lay.wind_zones:
			if z.intersects(t):
				_check(true, "egg_4: tuft at %.0f sits in a wind zone (sheltered)" % t.position.x)
	var boss_level := load("res://data/levels/egg_boss.tres") as LevelDef
	var bl := boss_level.layout
	_check(boss_level.mode == "PLATFORM" and bl.boss == "WASP" and bl.boss_time == 60.0 and bl.arena.size.x >= 1300.0 and bl.tufts.size() >= 4 and bl.tufts.size() <= 5, "egg_boss: WASP, 60 s, %.0fx%.0f arena, %d tufts" % [bl.arena.size.x, bl.arena.size.y, bl.tufts.size()])
	var list := load("res://data/levels/level_list.tres") as LevelList
	var ids: Array = []
	for l in list.levels:
		ids.append(l.id)
	_check(ids.slice(2, 5) == ["egg_3", "egg_4", "egg_boss"], "level_list: egg_4 and egg_boss follow egg_3 (%s)" % str(ids))
	# Determinism with wind, rain and the wasp.
	for id in ["egg_4", "egg_boss"]:
		var a: Array = _storm_run(load("res://data/levels/%s.tres" % id), 9)
		var b: Array = _storm_run(load("res://data/levels/%s.tres" % id), 9)
		_check(a == b, "%s: determinism with storm / boss" % id)
	# Ants stay on their ledges in egg_4 too, whatever the rain does to her.
	var sim := PlatformSim.new()
	sim.setup(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bad: int = 0
	for i in 60 * 90:
		if i % 90 == 0:
			sim.set_move(rng.randi_range(-1, 1))
			sim.set_jump(rng.randf() < 0.5)
		sim.player.hearts = 99
		sim.step(DT)
		for a in sim.ants:
			if absf(sim.surface_y(a.pos.x, a.feet(), 3.0, 3.0) - a.feet()) > 1.0:
				bad += 1
	_check(bad == 0, "egg_4: ants never leave their surface (%d bad frames)" % bad)


func _storm_run(level: LevelDef, seed_v: int) -> Array:
	var sim := PlatformSim.new()
	sim.setup(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in 60 * 20:
		if i % 20 == 0:
			sim.set_move(rng.randi_range(-1, 1))
			sim.set_jump(rng.randf() < 0.5)
		sim.step(DT)
	var extra: Array = [sim.drops.size(), sim.time_left]
	if sim.boss != null:
		extra.append(sim.boss.pos)
		extra.append(sim.boss.state)
	return [sim.player.pos, sim.player.vel, sim.player.hearts, sim.nutrients_taken.duplicate(), extra]


## Bot for the arena: dodges the WASP's dive by running away from the marked target; `use_tufts` = hides instead.
var _dive_age: float = 0.0


func _boss_bot_input(sim: PlatformSim, use_tufts: bool, react: float = 0.0, smart: bool = false) -> void:
	var p := sim.player
	var b := sim.boss
	var dir: int = 0
	if use_tufts:
		var best: Rect2 = sim.layout.tufts[0]
		var best_d: float = 1e9
		for i in sim.layout.tufts.size():
			var t: Rect2 = sim.layout.tufts[i]
			var d: float = absf(t.get_center().x - p.pos.x)
			if (smart and sim.tuft_flattened[i] > 0.0) or d >= best_d:
				continue
			best = t
			best_d = d
		var dx: float = best.get_center().x - p.pos.x
		dir = 0 if absf(dx) < 6.0 else (1 if dx > 0.0 else -1)
	elif b.state == "WARN" and react > 0.0 and b.timer > b.warn_time * 0.5 - react:
		dir = 0
	elif b.state == "DIVE" and react > 0.4 and _dive_age < react - 0.4:
		dir = 0
	elif b.state == "WARN" and b.timer > b.warn_time * 0.5:
		# The target still follows her: never stand in a tuft (that would be hiding), otherwise wait.
		if sim.in_tuft(p.pos):
			var to_mid: float = sim.layout.arena.get_center().x - p.pos.x
			dir = 1 if to_mid > 0.0 else -1
	elif b.state == "WARN" or b.state == "DIVE":
		# The target is locked: step away from it.
		var away: float = p.pos.x - b.target.x
		if absf(away) < 130.0:
			dir = 1 if away > 0.0 or (away == 0.0 and p.pos.x < 700.0) else -1
	sim.set_move(dir)
	sim.set_jump(false)


func _boss_bots() -> void:
	var level := load("res://data/levels/egg_boss.tres") as LevelDef
	var worst_by_mode: Dictionary = {}
	# "slow human" starts to run only 0.25 s after the target is locked and ignores the first half of the warning.
	for mode in ["dodging", "slow human", "hiding", "smart hiding"]:
		var worst: int = 3
		var total: int = 0
		for variant in 6:
			var sim := PlatformSim.new()
			sim.setup(level)
			sim.player.pos.x = [250.0, 380.0, 580.0, 820.0, 880.0, 1100.0][variant]
			var holder: Dictionary = {}
			sim.level_finished.connect(func(s: Dictionary) -> void: holder["s"] = s)
			var frames: int = 0
			var counter: Array[int] = [0]
			sim.boss_dive.connect(func() -> void: counter[0] += 0 if sim.boss.missed else 1)
			while not sim.finished and frames < 60 * 90:
				_dive_age = _dive_age + DT if sim.boss.state == "DIVE" else 0.0
				_boss_bot_input(sim, mode.ends_with("hiding"), {"dodging": 0.0, "slow human": 0.25, "hiding": 0.0, "smart hiding": 0.0}[mode], mode == "smart hiding")
				sim.step(DT)
				frames += 1
			var stats: Dictionary = holder.get("s", {})
			var hearts: int = stats.get("hearts_left", 0) if sim.won else 0
			worst = mini(worst, hearts)
			total += hearts
			var exposed: int = counter[0]
			if not mode.ends_with("hiding"):
				_check(exposed >= 8, "egg_boss: %s bot start %d faced %d real dives" % [mode, variant, exposed])
			if variant == 0 and not mode.ends_with("hiding"):
				_check(sim.won and stats.get("reason", "") == "HATCHED" and sim.time > 61.9 and sim.time < 64.5, "egg_boss: %s bot hatches after %.1f s with %d hearts" % [mode, sim.time, hearts])
		worst_by_mode[mode] = worst
		print("      egg_boss %s bot: worst %d hearts, average %.2f over 6 starts" % [mode, worst, total / 6.0])
	_check(worst_by_mode["dodging"] >= 2, "egg_boss: a dodging bot loses at most one heart from any start")
	_check(worst_by_mode["slow human"] >= 2, "egg_boss: a bot that reacts 0.25 s late still survives")
	_check(worst_by_mode["hiding"] < 3, "egg_boss: a bot that sits in one tuft gets hurt (worst %d hearts)" % worst_by_mode["hiding"])
	_check(worst_by_mode["smart hiding"] < 3, "egg_boss: hopping between tufts is not a free win (worst %d hearts)" % worst_by_mode["smart hiding"])


## EXTRA_HEART: more hearts, the level survives one more hit; the second tier stacks; other upgrades change nothing; boss stars ignore the bonus.
func _hearts_upgrade() -> void:
	var level := LevelDef.new()
	level.id = "test"
	level.layout = _ant_layout()
	var plain := PlatformSim.new()
	plain.setup(level)
	var one := PlatformSim.new()
	one.setup(level, ["EXTRA_HEART"] as Array[String])
	var two := PlatformSim.new()
	two.setup(level, ["EXTRA_HEART", "EXTRA_HEART_2", "EXTRA_HEART", "NOPE", "TOUGH_SKIN"] as Array[String])
	_check(plain.player.hearts == 3 and plain.player.max_hearts == 3 and plain.upgrades.is_empty(), "no upgrades: 3 hearts")
	_check(one.player.hearts == 4 and one.player.max_hearts == 4, "EXTRA_HEART: 4 hearts")
	_check(two.player.hearts == 5 and two.player.max_hearts == 5 and two.upgrades.size() == 2, "both tiers (and not twice, not unknown or combat ids): 5 hearts")
	var again := PlatformSim.new()
	again.setup(level)
	_check(again.player.hearts == 3, "setup resets the bonus")
	one.player.hearts = 3
	var got: Array[Dictionary] = []
	one.level_finished.connect(func(s: Dictionary) -> void: got.append(s))
	one._finish(true, "HATCHED")
	_check(got.size() == 1 and int(got[0].get("stars", 0)) == 2, "a boss level with 3 of 4 hearts left gives 2 stars (the bonus heart is not a star)")


func _tuft_flatten() -> void:
	var sim := _boss_make(_boss_layout())
	sim.player.pos = Vector2(145.0, 606.0)
	var flat: Array = []
	sim.tuft_flatten.connect(func(i: int) -> void: flat.append(i))
	_run(sim, 0.4)
	_check(sim.player.hidden, "flatten: hidden in the tuft at first")
	_until_state(sim, "DIVE", 8.0)
	_check(flat == [0] and sim.tuft_flattened[0] > 7.9 and sim.tuft_flattened[1] == 0.0, "flatten: the missed dive flattens her tuft for 8 s")
	sim.step(DT)
	_check(not sim.player.hidden, "flatten: she is visible at once")
	_run(sim, 1.0)
	_check(not sim.player.hidden and not sim.in_tuft(sim.player.pos), "flatten: a flattened tuft hides nobody")
	# Flat tufts recover.
	var regrown: bool = false
	for _i in 60 * 9:
		sim.player.invuln = 99.0
		sim.step(DT)
		if sim.in_tuft(sim.player.pos):
			regrown = true
	_check(regrown, "flatten: it grows back after 8 s")
	# Ant levels are unchanged: tufts never flatten.
	var a := _make(_ant_layout())
	_run(a, 5.0)
	_check(a.tuft_flattened.size() == 1 and a.tuft_flattened[0] == 0.0, "flatten: not in ant levels")

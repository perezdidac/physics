## FLY mode of the platformer (layout.mode == "FLY"): the Papallona stage, night flight. Created and stepped by PlatformSim.
## See docs/platform2_contracts.md §2.
##
## == API for the view (all read-only) ==
## PlatformSim.fly: PlatformFly (null in other modes). PlatformSim.player is the moth (radius 12; `hidden` = inside an active shadow).
## Input: PlatformSim.set_move(-1|0|1) steers; each new press of set_jump(true) is a wing FLAP (upward impulse, cooldown FLAP_COOLDOWN);
##   keeping it held while falling GLIDES (slow fall). The world edges are walls; falling below the world is a pit as in the egg levels.
## Moth state: `gliding` (bool), `flap_age` (seconds since the last flap, for the wing animation), `stun` (seconds left stunned by a lamp:
##   no steering), `PlatformSim.player.on_ground`.
## Lamps: layout.lights (Vector3 x, y, pull radius). `lamp_pull(i) -> float` is the pull on the moth now (0..1, for glow); lamp_zap(idx) signal when she
##   touches one (stun + a heart).
## Traps: layout.traps; signal trap_hit(idx) (she lost a heart and respawned at the last checkpoint).
## Shadows: `shadow_rect(i) -> Rect2` (where it is now), `shadow_active(i) -> bool` (blinking shadows are off at times; an inactive one hides nobody),
##   `shadow_count() -> int`, `in_shadow(pt) -> bool`.
## Nightjars: `nightjars: Array[PlatformNightjar]` (see its header); signal nightjar_bite(idx).
## Boss: `bat: PlatformBat` (see its header; null without boss), `pulses: Array[PlatformRing]` (echolocation rings: pos, radius, max_radius, fade()),
##   PlatformSim.time_left; signals bat_pulse(pos), boss_warn(target) at the mark, boss_dive() at the swoop, boss_missed() when the swoop finds only
##   a hidden moth. Win: time_left <= 0 -> level_finished reason "EGGS_LAID".
## Goal levels: the moth's centre inside layout.goal -> "REACHED_GOAL". Sap and checkpoints work as in the egg levels.
class_name PlatformFly
extends RefCounted

const RADIUS: float = 12.0
const GRAVITY: float = 900.0
const MAX_FALL: float = 520.0
const GLIDE_GRAVITY: float = 220.0
const GLIDE_FALL: float = 75.0
const FLAP_SPEED: float = 360.0
const FLAP_COOLDOWN: float = 0.26
const FLAP_PUSH: float = 45.0
const MAX_RISE: float = 380.0
const MAX_SPEED: float = 240.0
const AIR_ACCEL: float = 800.0
const AIR_DRAG: float = 150.0
const GROUND_ACCEL: float = 1500.0
const GROUND_FRICTION: float = 1600.0
const PULL_MAX: float = 700.0
const LAMP_CORE: float = 14.0
const LAMP_STUN: float = 1.0
const BAT_HIT: float = 16.0
const BLINK_OFF: float = 0.35

## The level layout and the sim time (for the shadows).
var layout: PlatformLayout = null
var time: float = 0.0
var gliding: bool = false
var flap_age: float = 9.0
var stun: float = 0.0
var nightjars: Array[PlatformNightjar] = []
var bat: PlatformBat = null
var pulses: Array[PlatformRing] = []

var _flap_cd: float = 0.0
var _pull: Array[float] = []


## Turns the player into the moth and builds the birds and the bat.
func setup(sim: PlatformSim) -> void:
	var lay: PlatformLayout = sim.layout
	layout = lay
	time = 0.0
	sim.player.radius = RADIUS
	nightjars.clear()
	for path in lay.nightjars:
		if path.size() >= 2:
			var n := PlatformNightjar.new()
			n.setup(path)
			nightjars.append(n)
	bat = null
	pulses.clear()
	if lay.boss == "BAT":
		bat = PlatformBat.new()
		bat.setup(lay.arena)
		sim.time_left = lay.boss_time
	gliding = false
	flap_age = 9.0
	stun = 0.0
	_flap_cd = 0.0
	_pull.clear()
	_pull.resize(lay.lights.size())
	_pull.fill(0.0)


func shadow_count() -> int:
	return layout.shadows.size()


## Where shadow i is right now.
func shadow_rect(i: int) -> Rect2:
	var r: Rect2 = layout.shadows[i]
	var period: float = layout.shadow_period[i] if i < layout.shadow_period.size() else 0.0
	if period > 0.0 and i < layout.shadow_slide.size():
		r.position += layout.shadow_slide[i] * sin(TAU * (time / period + 0.31 * i))
	return r


## Whether shadow i is on (blinking shadows are off for the last BLINK_OFF of their cycle).
func shadow_active(i: int) -> bool:
	var period: float = layout.shadow_period[i] if i < layout.shadow_period.size() else 0.0
	if period <= 0.0 or i >= layout.shadow_blink.size() or not layout.shadow_blink[i]:
		return true
	return fposmod(time / period + 0.31 * i, 1.0) < 1.0 - BLINK_OFF


## Pull of lamp i on the moth in the last step, 0..1 (0 = outside its radius, 1 = on the lamp).
func lamp_pull(i: int) -> float:
	return _pull[i]


## True when the point is inside an active shadow.
func in_shadow(pt: Vector2) -> bool:
	for i in layout.shadows.size():
		if shadow_active(i) and shadow_rect(i).has_point(pt):
			return true
	return false


## Sends an echolocation pulse from `at` (the bat calls this).
func emit_pulse(sim: PlatformSim, at: Vector2) -> void:
	var ring := PlatformRing.new()
	ring.pos = at
	ring.speed = PlatformBat.PULSE_SPEED
	ring.max_radius = sim.layout.arena.size.length() if sim.layout.arena.size != Vector2.ZERO else 1200.0
	pulses.append(ring)
	sim.bat_pulse.emit(at)
	sim.sfx.emit("urticating_burst", {})


## Advances the flight mode by dt (called by PlatformSim.step).
func step(sim: PlatformSim, dt: float) -> void:
	var p: PlatformBody = sim.player
	p.invuln = maxf(0.0, p.invuln - dt)
	p.hurt_lock = maxf(0.0, p.hurt_lock - dt)
	p.buffer = maxf(0.0, p.buffer - dt)
	stun = p.hurt_lock
	_flap_cd = maxf(0.0, _flap_cd - dt)
	flap_age += dt
	time = sim.time
	p.hidden = in_shadow(p.pos)
	_control(sim, dt)
	sim._move_player(dt)
	if sim.finished:
		return
	p.pos.y = maxf(p.pos.y, p.radius)
	p.hidden = in_shadow(p.pos)
	_lamps(sim, dt)
	if not sim.finished:
		_traps(sim)
	if not sim.finished:
		sim._pickups()
		_birds(sim, dt)
	if not sim.finished:
		_bat_step(sim, dt)
	if not sim.finished:
		sim._squash_step(dt)
		if sim.layout.boss == "" and sim.layout.goal.has_point(p.pos):
			sim._finish(true)


func _control(sim: PlatformSim, dt: float) -> void:
	var p: PlatformBody = sim.player
	var locked: bool = p.hurt_lock > 0.0
	var mv: int = 0 if locked else sim._move
	if mv != 0:
		p.facing = mv
	var accel: float = GROUND_ACCEL if p.on_ground else AIR_ACCEL
	if mv != 0:
		if absf(p.vel.x) > MAX_SPEED and signf(p.vel.x) == float(mv):
			p.vel.x = move_toward(p.vel.x, mv * MAX_SPEED, AIR_DRAG * dt)
		else:
			p.vel.x = move_toward(p.vel.x, mv * MAX_SPEED, accel * dt * (2.0 if signf(p.vel.x) == -float(mv) else 1.0))
	elif not locked:
		p.vel.x = move_toward(p.vel.x, 0.0, (GROUND_FRICTION if p.on_ground else AIR_DRAG) * dt)
	# Flap: each press is one beat.
	if p.buffer > 0.0 and _flap_cd <= 0.0 and not locked:
		p.vel.y = -FLAP_SPEED
		p.vel.x += mv * FLAP_PUSH
		p.on_ground = false
		p.buffer = 0.0
		_flap_cd = FLAP_COOLDOWN
		flap_age = 0.0
		sim.sfx.emit("bounce", {})
	# Glide while held and falling.
	gliding = sim._jump_held and not locked and not p.on_ground and p.vel.y > 0.0
	if gliding:
		p.vel.y = minf(p.vel.y + GLIDE_GRAVITY * dt, GLIDE_FALL * sim.glide_fall_mult)
	elif p.on_ground and p.vel.y >= 0.0:
		p.vel.y = 0.0
	else:
		p.vel.y = clampf(p.vel.y + GRAVITY * dt, -MAX_RISE, MAX_FALL)
	if absf(p.vel.x) > 1.0 and p.on_ground:
		p.walk_cycle += absf(p.vel.x) * dt * 0.06


func _lamps(sim: PlatformSim, dt: float) -> void:
	var p: PlatformBody = sim.player
	var lights: Array[Vector3] = sim.layout.lights
	for i in lights.size():
		var c := Vector2(lights[i].x, lights[i].y)
		var to: Vector2 = c - p.pos
		var dist: float = to.length()
		var f: float = clampf(1.0 - dist / maxf(lights[i].z, 1.0), 0.0, 1.0)
		_pull[i] = f
		if f > 0.0 and dist > 0.001:
			p.vel += to / dist * PULL_MAX * f * dt
		if dist < p.radius + LAMP_CORE and p.invuln <= 0.0:
			var away: float = signf(p.pos.x - c.x)
			sim._hurt_player(away if away != 0.0 else float(-p.facing))
			p.hurt_lock = LAMP_STUN
			stun = LAMP_STUN
			sim.sfx.emit("urticating_burst", {})
			sim.lamp_zap.emit(i)
			if sim.finished:
				return


func _traps(sim: PlatformSim) -> void:
	var p: PlatformBody = sim.player
	if p.invuln > 0.0:
		return
	for i in sim.layout.traps.size():
		var r: Rect2 = sim.layout.traps[i]
		if r.has_point(p.pos) or sim._push_rect(p.pos, p.radius, r) != Vector2.ZERO:
			sim.trap_hit.emit(i)
			sim._fall_in_pit("worm_hurt")
			stun = 0.0
			return


func _birds(sim: PlatformSim, dt: float) -> void:
	var p: PlatformBody = sim.player
	for i in nightjars.size():
		if nightjars[i].step(sim, dt):
			var away: float = signf(p.pos.x - nightjars[i].pos.x)
			sim.nightjar_bite.emit(i)
			sim._hurt_player(away if away != 0.0 else float(-nightjars[i].facing))
			if sim.finished:
				return


func _bat_step(sim: PlatformSim, dt: float) -> void:
	if bat == null:
		return
	var p: PlatformBody = sim.player
	var attacking: bool = sim.time >= PlatformBoss.INTRO
	var difficulty: float = clampf(1.0 - sim.time_left / maxf(sim.layout.boss_time, 0.01), 0.0, 1.0)
	for i in range(pulses.size() - 1, -1, -1):
		var ring: PlatformRing = pulses[i]
		var before: float = ring.radius
		var alive: bool = ring.grow(dt)
		var d: float = p.pos.distance_to(ring.pos)
		if not ring.heard and before < d and ring.radius >= d:
			ring.heard = true
			if not p.hidden:
				bat.mark(sim, difficulty)
		if not alive:
			pulses.remove_at(i)
	bat.step(sim, self, dt, difficulty, attacking)
	if p.invuln <= 0.0 and p.pos.distance_to(bat.pos) < p.radius + BAT_HIT:
		sim._hurt_player(signf(p.pos.x - bat.pos.x))
		if sim.finished:
			return
	if attacking:
		sim.time_left = maxf(0.0, sim.time_left - dt)
		if sim.time_left <= 0.0:
			sim._finish(true, "EGGS_LAID")

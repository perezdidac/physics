## Headless, deterministic real-time platformer of the egg stage. See docs/platform_contracts.md §3.
## Feed it `set_move` / `set_jump`, call `step(1/60)`, read `player`, `ants`, `nutrients_taken`.
## `layout.mode` selects the game: "" = the egg platformer (this file); "DIG" = Crisàlide, read `dig` (platform_dig.gd, also `set_vertical`);
## "FLY" = Papallona, read `fly` (platform_fly.gd). Those two modes have their own step, see docs/platform2_contracts.md.
class_name PlatformSim
extends RefCounted

signal sfx(name: String, params: Dictionary)
signal float_text(pos: Vector2, text: String, color: Color)
signal nutrient_taken(idx: int)
signal player_hurt(hearts: int)
signal checkpoint_reached(idx: int)
signal respawned()
signal level_finished(stats: Dictionary)
## An ant was stomped: its index in `ants` and its centre (the view plays the poof).
signal ant_stomped(idx: int, pos: Vector2)
## Storm and boss (docs/platform_contracts.md §7). `kind` of splash: "RAIN" (a drop hit the ground), "PUDDLE" (a drop or her feet in a
## puddle), "HIT" (a drop hit her).
signal splash(pos: Vector2, kind: String)
## A wind zone starts to gust; `dir` is -1 or 1.
signal storm_gust(dir: int)
signal boss_warn(target: Vector2)
signal boss_dive()
## The wasp dived at a hidden Perleta and lost her.
signal boss_missed()
## The tuft `idx` was flattened by a wasp dive that missed a hidden Perleta.
signal tuft_flatten(idx: int)
## DIG and FLY modes (docs/platform2_contracts.md; details in platform_dig.gd and platform_fly.gd).
## DIG: the cells (cell units) of `dig.mask` that changed this step.
signal dig_changed(cells: Rect2i)
signal stone_wobble(idx: int)
signal stone_landed(idx: int)
## A stone crumbled (hit false) or shattered on the pupa (hit true).
signal stone_broken(idx: int, hit: bool)
## The pupa made a noise: a ring starts at `pos` and will fade at `max_radius`.
signal noise_made(pos: Vector2, max_radius: float)
## FLY: the bat sent an echolocation pulse from `pos`.
signal bat_pulse(pos: Vector2)
signal lamp_zap(idx: int)
signal trap_hit(idx: int)
signal nightjar_bite(idx: int)

# Feel (px, seconds).
const MAX_RUN: float = 230.0
const GROUND_ACCEL: float = 1700.0
const GROUND_FRICTION: float = 1900.0
const TURN_BOOST: float = 2.0
const AIR_ACCEL: float = 1100.0
const AIR_FRICTION: float = 350.0
const GRAVITY: float = 1900.0
const JUMP_SPEED: float = 640.0
const JUMP_CUT_SPEED: float = 230.0
const MAX_FALL: float = 900.0
const COYOTE_TIME: float = 0.1
const BUFFER_TIME: float = 0.12
const INVULN_TIME: float = 1.2
const HURT_LOCK_TIME: float = 0.3
const KNOCK_SPEED: Vector2 = Vector2(300.0, -380.0)
const SNAP: float = 8.0
const MAX_STEP_PX: float = 5.0
## Surfaces whose normal points up at least this much count as ground (about 56 degrees).
const GROUND_NORMAL_Y: float = -0.55
const SIGHT_X: float = 180.0
const SIGHT_Y: float = 60.0
const LOSE_X: float = 260.0
const LOSE_Y: float = 90.0
const CHASE_MULT: float = 1.6
const NUTRIENT_RADIUS: float = 12.0
# Stomp (egg mode only; the wasp and the birds cannot be stomped).
## The egg's bottom may be at most this far below the ant's top when she lands on it (a fast fall moves ~15 px per step).
const STOMP_DEPTH: float = 16.0
## Upward speed after a stomp; with jump held it is JUMP_SPEED * STOMP_HOLD_MULT.
const STOMP_BOUNCE: float = 420.0
const STOMP_HOLD_MULT: float = 0.85
## Seconds a knocked-out ant stays squashed before it disappears.
const KO_TIME: float = 0.5
# Storm.
## Seconds of wind acceleration that become drift speed; on the ground only the fraction below.
const WIND_DRIFT_TIME: float = 0.2
const WIND_GROUND: float = 0.6
const GUST_CALM: float = 0.2
const PUDDLE_SLOW: float = 0.55
const RAIN_HEIGHT: float = 560.0
const RAIN_KNOCK: Vector2 = Vector2(260.0, -220.0)
const RAIN_LOCK: float = 0.15
const RAIN_COOLDOWN: float = 0.5
const BOSS_HIT_RADIUS: float = 16.0
const TUFT_FLATTEN_TIME: float = 8.0

var layout: PlatformLayout
var player: PlatformBody = PlatformBody.new()
var ants: Array[PlatformAnt] = []
var nutrients_taken: Array[bool] = []
var checkpoint_idx: int = -1
var time: float = 0.0
var finished: bool = false
var won: bool = false
## Falling raindrops (storm levels).
var drops: Array[PlatformDrop] = []
## The wasp (null when the level has no boss).
var boss: PlatformBoss = null
## Seconds until hatching (boss levels; frozen during the intro).
var time_left: float = 0.0
## Seconds left that each tuft stays flattened (same order as `layout.tufts`; boss levels only). A flattened tuft hides nobody.
var tuft_flattened: Array[float] = []
## DIG mode state (null in other modes). See platform_dig.gd.
var dig: PlatformDig = null
## Ids of the hub upgrades applied to this level (PlatformUpgrades) and the multipliers they set.
var upgrades: Array[String] = []
var dig_speed_mult: float = 1.0
var glide_fall_mult: float = 1.0
## FLY mode state (null in other modes). See platform_fly.gd.
var fly: PlatformFly = null

var _level_id: String = ""
var _move: int = 0
var _vert: int = 0
var _jump_held: bool = false
var _slope_tris: Array[PackedVector2Array] = []
var _taken_count: int = 0
var _rng := RandomNumberGenerator.new()
var _rain_acc: float = 0.0
var _rain_cd: float = 0.0
var _splash_cd: float = 0.0
var _gust_on: Array[bool] = []


## Loads the level (its `layout` must be set) and resets everything. `upgrade_ids` are the owned hub upgrades (the story flow passes them).
func setup(level: LevelDef, upgrade_ids: Array[String] = []) -> void:
	layout = level.layout
	_level_id = level.id
	player = PlatformBody.new()
	player.pos = layout.start
	player.growth = 0.0
	PlatformUpgrades.reset(self)
	PlatformUpgrades.apply(self, upgrade_ids)
	ants.clear()
	for a in layout.ants:
		var ant := PlatformAnt.new()
		ant.x_min = a.position.x
		ant.x_max = a.end.x
		ant.speed = a.size.y
		ant.pos = Vector2(a.position.x, a.position.y - ant.radius)
		ant.facing = 1
		ants.append(ant)
	nutrients_taken.clear()
	nutrients_taken.resize(layout.nutrients.size())
	nutrients_taken.fill(false)
	_taken_count = 0
	checkpoint_idx = -1
	time = 0.0
	finished = false
	won = false
	_move = 0
	_vert = 0
	_jump_held = false
	drops.clear()
	_rng.seed = level.id.hash()
	_rain_acc = 0.0
	_rain_cd = 0.0
	_splash_cd = 0.0
	_gust_on.clear()
	_gust_on.resize(layout.wind_zones.size())
	_gust_on.fill(false)
	boss = null
	time_left = 0.0
	tuft_flattened.clear()
	tuft_flattened.resize(layout.tufts.size())
	tuft_flattened.fill(0.0)
	if layout.boss == "WASP":
		boss = PlatformBoss.new()
		boss.setup(layout.arena)
		boss.warned.connect(_on_boss_warned)
		boss.dived.connect(_on_boss_dived)
		boss.missed_her.connect(_on_boss_missed)
		time_left = layout.boss_time
	_slope_tris.clear()
	for s in layout.slopes:
		if s.size() < 2:
			continue
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var corner := Vector2(a.x if a.y < b.y else b.x, maxf(a.y, b.y))
		_slope_tris.append(PackedVector2Array([a, b, corner]))
	dig = null
	fly = null
	if layout.mode == "DIG":
		dig = PlatformDig.new()
		dig.setup(self)
	elif layout.mode == "FLY":
		fly = PlatformFly.new()
		fly.setup(self)


## Horizontal input: -1, 0 or 1.
func set_move(dir: int) -> void:
	_move = clampi(dir, -1, 1)


## Vertical input for the DIG mode: -1 up, 0, 1 down (ignored in the other modes).
func set_vertical(dir: int) -> void:
	_vert = clampi(dir, -1, 1)


## Jump button state: a press starts a jump (buffered), holding it keeps the jump high.
func set_jump(held: bool) -> void:
	if held and not _jump_held:
		player.buffer = BUFFER_TIME
	_jump_held = held


## Advances the simulation by `dt` seconds (fixed 1/60 from the screen).
func step(dt: float) -> void:
	if finished or layout == null:
		return
	time += dt
	if dig != null:
		dig.step(self, dt)
		return
	if fly != null:
		fly.step(self, dt)
		return
	var p := player
	p.invuln = maxf(0.0, p.invuln - dt)
	p.hurt_lock = maxf(0.0, p.hurt_lock - dt)
	p.buffer = maxf(0.0, p.buffer - dt)
	for i in tuft_flattened.size():
		tuft_flattened[i] = maxf(0.0, tuft_flattened[i] - dt)
	_storm_conditions(dt)
	_control(dt)
	_move_player(dt)
	if finished:
		return
	_pickups()
	_rain_step(dt)
	_ants_step(dt)
	_hide_check()
	_boss_step(dt)
	_squash_step(dt)
	_check_end()


## Highest walkable surface y at `x` between `from_y - max_up` and `from_y + max_down`, or INF if there is none.
## Ants and the tests use it; "no surface" means a ledge or a wall.
func surface_y(x: float, from_y: float, max_up: float, max_down: float) -> float:
	if dig != null:
		return dig.surface_y(x, from_y, max_up, max_down)
	var lo: float = from_y - max_up
	var hi: float = from_y + max_down
	var best: float = INF
	for r in layout.solids:
		if x >= r.position.x and x <= r.end.x and r.position.y >= lo and r.position.y <= hi:
			best = minf(best, r.position.y)
	for r in layout.platforms:
		if x >= r.position.x and x <= r.end.x and r.position.y >= lo and r.position.y <= hi:
			best = minf(best, r.position.y)
	for s in layout.slopes:
		if s.size() < 2:
			continue
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		if x >= a.x and x <= b.x and b.x > a.x:
			var y: float = lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
			if y >= lo and y <= hi:
				best = minf(best, y)
	return best


## Whether the player's centre is inside a tuft.
func in_tuft(pt: Vector2) -> bool:
	for i in layout.tufts.size():
		if layout.tufts[i].has_point(pt) and tuft_flattened[i] <= 0.0:
			return true
	return false


# ---------------------------------------------------------------- player

func _control(dt: float) -> void:
	var p := player
	var dir: int = 0 if p.hurt_lock > 0.0 else _move
	if dir != 0:
		p.facing = dir
	var accel: float = GROUND_ACCEL if p.on_ground else AIR_ACCEL
	var drift: float = p.wind * WIND_DRIFT_TIME * (WIND_GROUND if p.on_ground else 1.0)
	var max_run: float = MAX_RUN * (PUDDLE_SLOW if p.in_puddle else 1.0)
	if dir != 0:
		var rate: float = accel
		if signf(p.vel.x) == -float(dir):
			rate *= TURN_BOOST
		p.vel.x = move_toward(p.vel.x, dir * max_run + drift, rate * dt)
	elif p.hurt_lock <= 0.0:
		p.vel.x = move_toward(p.vel.x, drift, (GROUND_FRICTION if p.on_ground else AIR_FRICTION) * dt)
	# Coyote time and jump.
	if p.on_ground:
		p.coyote = COYOTE_TIME
	else:
		p.coyote = maxf(0.0, p.coyote - dt)
	if p.buffer > 0.0 and p.coyote > 0.0 and p.hurt_lock <= 0.0:
		p.vel.y = -JUMP_SPEED
		p.on_ground = false
		p.coyote = 0.0
		p.buffer = 0.0
		p.jumping = true
		p.squash = Vector2(0.78, 1.28)
		sfx.emit("jump", {})
	# Variable jump height: letting go while rising cuts the jump.
	if p.jumping and not _jump_held and p.vel.y < -JUMP_CUT_SPEED:
		p.vel.y = -JUMP_CUT_SPEED
	if p.on_ground and p.vel.y >= 0.0:
		p.vel.y = 0.0
	else:
		p.vel.y = minf(p.vel.y + GRAVITY * dt, MAX_FALL)
	if absf(p.vel.x) > 1.0 and p.on_ground:
		p.walk_cycle += absf(p.vel.x) * dt * 0.06


func _move_player(dt: float) -> void:
	var p := player
	var was_ground: bool = p.on_ground
	var n: int = clampi(ceili(maxf(absf(p.vel.x), absf(p.vel.y)) * dt / MAX_STEP_PX), 1, 14)
	var h: float = dt / float(n)
	var impact: float = 0.0
	var grounded: bool = false
	for i in n:
		var prev_bottom: float = p.pos.y + p.radius
		p.pos += p.vel * h
		impact = maxf(impact, p.vel.y)
		grounded = _resolve(p, prev_bottom)
		if not grounded and was_ground:
			grounded = _snap(p)
		if grounded:
			was_ground = true
	if grounded and not p.on_ground and impact > 250.0:
		var k: float = clampf(impact / 900.0, 0.0, 1.0) * 0.35
		p.squash = Vector2(1.0 + k, 1.0 - k)
		sfx.emit("bounce", {})
	p.on_ground = grounded
	if grounded:
		p.jumping = false
	p.pos.x = clampf(p.pos.x, p.radius, layout.size.x - p.radius)
	if p.pos.y > layout.size.y + p.radius * 2.0:
		_fall_in_pit()


## Pushes the player out of everything solid; returns true if she stands on ground.
func _resolve(p: PlatformBody, prev_bottom: float) -> bool:
	var ground: bool = false
	for _it in 4:
		var moved: bool = false
		for r in layout.solids:
			var push: Vector2 = _push_rect(p.pos, p.radius, r)
			if push != Vector2.ZERO:
				ground = _apply_push(p, push) or ground
				moved = true
		for tri in _slope_tris:
			var push: Vector2 = _push_poly(p.pos, p.radius, tri)
			if push != Vector2.ZERO:
				ground = _apply_push(p, push) or ground
				moved = true
		if not moved:
			break
	if p.vel.y >= 0.0:
		for r in layout.platforms:
			var bottom: float = p.pos.y + p.radius
			if p.pos.x >= r.position.x and p.pos.x <= r.end.x and prev_bottom <= r.position.y + 3.0 and bottom > r.position.y:
				p.pos.y = r.position.y - p.radius
				p.vel.y = 0.0
				ground = true
	return ground


func _apply_push(p: PlatformBody, push: Vector2) -> bool:
	p.pos += push
	var n: Vector2 = push.normalized()
	var into: float = p.vel.dot(n)
	if into < 0.0:
		p.vel -= n * into
	return n.y < GROUND_NORMAL_Y


## Keeps the player on the ground when walking down slopes or over small steps.
func _snap(p: PlatformBody) -> bool:
	var saved: Vector2 = p.pos
	var saved_vel: Vector2 = p.vel
	p.pos.y += SNAP
	var ok: bool = _resolve(p, saved.y + p.radius)
	if ok and p.pos.y - saved.y <= SNAP + 0.01:
		p.vel.y = maxf(p.vel.y, 0.0)
		return true
	p.pos = saved
	p.vel = saved_vel
	return false


## Push-out vector of a circle against an axis-aligned rectangle (zero if apart).
func _push_rect(c: Vector2, r: float, rect: Rect2) -> Vector2:
	var cp := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	var d: Vector2 = c - cp
	var l2: float = d.length_squared()
	if l2 > 0.0:
		if l2 >= r * r:
			return Vector2.ZERO
		var l: float = sqrt(l2)
		return d / l * (r - l)
	# Centre inside the rectangle: leave through the nearest side.
	var to_left: float = c.x - rect.position.x
	var to_right: float = rect.end.x - c.x
	var to_top: float = c.y - rect.position.y
	var to_bottom: float = rect.end.y - c.y
	var m: float = minf(minf(to_left, to_right), minf(to_top, to_bottom))
	if m == to_top:
		return Vector2(0.0, -(to_top + r))
	if m == to_left:
		return Vector2(-(to_left + r), 0.0)
	if m == to_right:
		return Vector2(to_right + r, 0.0)
	return Vector2(0.0, to_bottom + r)


## Push-out vector of a circle against a convex polygon (zero if apart).
func _push_poly(c: Vector2, r: float, poly: PackedVector2Array) -> Vector2:
	var best_d2: float = INF
	var best_pt: Vector2 = c
	var n: int = poly.size()
	for i in n:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(c, poly[i], poly[(i + 1) % n])
		var d2: float = c.distance_squared_to(q)
		if d2 < best_d2:
			best_d2 = d2
			best_pt = q
	if Geometry2D.is_point_in_polygon(c, poly):
		var out: Vector2 = best_pt - c
		var l: float = out.length()
		var dir: Vector2 = out / l if l > 0.0001 else Vector2.UP
		# Leave through the nearest edge, towards the side where the polygon is not.
		var centroid: Vector2 = (poly[0] + poly[1] + poly[2]) / 3.0
		if dir.dot(best_pt - centroid) < 0.0:
			dir = -dir
		return dir * (l + r)
	if best_d2 >= r * r:
		return Vector2.ZERO
	var dist: float = sqrt(best_d2)
	return (c - best_pt) / dist * (r - dist)


func _fall_in_pit(sfx_name: String = "plunge") -> void:
	var p := player
	sfx.emit(sfx_name, {})
	p.hearts -= 1
	player_hurt.emit(p.hearts)
	if p.hearts <= 0:
		_finish(false)
		return
	var spawn: Vector2 = layout.start
	if checkpoint_idx >= 0:
		spawn = layout.checkpoints[checkpoint_idx] + Vector2(0.0, -p.radius - 1.0)
	p.pos = spawn
	p.vel = Vector2.ZERO
	p.on_ground = false
	p.jumping = false
	p.coyote = 0.0
	p.buffer = 0.0
	p.hurt_lock = 0.0
	p.invuln = INVULN_TIME
	respawned.emit()


func _pickups() -> void:
	var p := player
	for i in layout.nutrients.size():
		if nutrients_taken[i]:
			continue
		if p.pos.distance_to(layout.nutrients[i]) <= p.radius + NUTRIENT_RADIUS:
			nutrients_taken[i] = true
			_taken_count += 1
			p.growth = float(_taken_count) / float(layout.nutrients.size())
			sfx.emit("crate_pickup", {})
			float_text.emit(layout.nutrients[i] + Vector2(0.0, -20.0), tr("FT_PLAT_NUTRIENT"), Palette.FT_GREEN)
			nutrient_taken.emit(i)
	for i in range(checkpoint_idx + 1, layout.checkpoints.size()):
		var cp: Vector2 = layout.checkpoints[i]
		if absf(p.pos.x - cp.x) <= 36.0 and p.pos.y >= cp.y - 260.0 and p.pos.y <= cp.y + 40.0:
			checkpoint_idx = i
			sfx.emit("tick", {})
			float_text.emit(cp + Vector2(0.0, -70.0), tr("FT_PLAT_CHECKPOINT"), Palette.FT_AMBER)
			checkpoint_reached.emit(i)


func _hide_check() -> void:
	var p := player
	p.hidden = p.on_ground and _move == 0 and absf(p.vel.x) < 8.0 and in_tuft(p.pos)


func _squash_step(dt: float) -> void:
	var k: float = minf(1.0, 12.0 * dt)
	player.squash = player.squash.lerp(Vector2.ONE, k)


func _check_end() -> void:
	if not finished and layout.boss == "" and layout.goal.has_point(player.pos):
		_finish(true)


func _finish(victory: bool, reason: String = "REACHED_GOAL") -> void:
	finished = true
	won = victory
	var total: int = layout.nutrients.size()
	var stars: int = 0
	if victory:
		stars = 1
		if _taken_count * 2 >= total:
			stars = 2
		if _taken_count >= total:
			stars = 3
		if reason == "HATCHED" or reason == "METAMORPHOSIS" or reason == "EGGS_LAID":
			# Boss levels: hearts left are the stars (bonus hearts do not count); with sap in the arena, 3 stars also need all of it.
			stars = clampi(player.hearts - (player.max_hearts - 3), 1, 3)
			if total > 0 and _taken_count < total:
				stars = mini(stars, 2)
		sfx.emit("victory", {})
	level_finished.emit({
		"level_id": _level_id,
		"won": victory,
		"stars": stars,
		"reason": reason if victory else "LOST",
		"nutrients": _taken_count,
		"nutrients_total": total,
		"hearts_left": maxi(player.hearts, 0),
		"time": time,
	})


# ---------------------------------------------------------------- ants

func _ants_step(dt: float) -> void:
	var p := player
	var p_feet: float = p.pos.y + p.radius
	for a in ants:
		if a.knocked:
			a.ko_age += dt
			a.gone = a.ko_age >= KO_TIME
			continue
		a.bite = maxf(0.0, a.bite - 3.0 * dt)
		var dx: float = p.pos.x - a.pos.x
		var dy: float = absf(p_feet - a.feet())
		var sees: bool = not p.hidden and absf(dx) < SIGHT_X and dy <= SIGHT_Y
		var keeps: bool = not p.hidden and absf(dx) < LOSE_X and dy <= LOSE_Y
		if dig != null and (sees or keeps) and not dig.line_clear(a.pos, p.pos):
			# Soil between them: the ant neither sees nor smells her.
			sees = false
			keeps = false
		var dir: int = 0
		var spd: float = a.speed
		var stunned: bool = a.stun > 0.0
		if stunned:
			# Knock-back stun: slide away, no thinking.
			a.stun -= dt
			dir = int(signf(a.vel.x))
			spd = absf(a.vel.x)
		else:
			match a.state:
				"PATROL":
					if sees:
						a.state = "CHASE"
					else:
						if a.pos.x <= a.x_min:
							a.facing = 1
						elif a.pos.x >= a.x_max:
							a.facing = -1
						dir = a.facing
				"CHASE":
					if not keeps:
						a.state = "LOST"
						a.timer = 0.9
					else:
						dir = int(signf(dx)) if absf(dx) > 4.0 else 0
						spd = a.speed * CHASE_MULT
				"LOST":
					a.timer -= dt
					if sees:
						a.state = "CHASE"
					elif a.timer <= 0.0:
						a.state = "PATROL"
						a.facing = 1 if a.pos.x < a.x_min else (-1 if a.pos.x > a.x_max else a.facing)
		var moved: bool = _ant_walk(a, dir, spd, dt)
		if not stunned:
			if not moved and dir != 0 and a.state == "PATROL":
				a.facing = -a.facing
			elif dir != 0:
				a.facing = dir
		a.vel.x = dir * spd if moved else 0.0
		if moved:
			a.walk_cycle += spd * dt * 0.08
		_ant_contact(a)


## Walks the ant `dir * spd * dt` px if there is ground ahead; returns false when a ledge or wall stops it.
func _ant_walk(a: PlatformAnt, dir: int, spd: float, dt: float) -> bool:
	if dir == 0:
		return false
	var nx: float = a.pos.x + dir * spd * dt
	var probe: float = nx + dir * (a.radius + 1.0)
	var feet: float = a.feet()
	if is_inf(surface_y(probe, feet, 12.0, 8.0)):
		return false
	var ny: float = surface_y(nx, feet, 12.0, 8.0)
	if is_inf(ny):
		return false
	a.pos = Vector2(nx, ny - a.radius)
	return true


func _ant_contact(a: PlatformAnt) -> void:
	var p := player
	if _try_stomp(a):
		return
	if p.hidden or p.invuln > 0.0:
		return
	if p.pos.distance_to(a.pos) >= p.radius + a.radius - 3.0:
		return
	var away: float = signf(p.pos.x - a.pos.x)
	if away == 0.0:
		away = float(-a.facing)
	a.bite = 1.0
	a.stun = 0.4
	a.vel.x = -away * 140.0
	_hurt_player(away)


## Mario-style stomp: she is falling, her bottom is over the ant's top and they overlap horizontally. The ant is knocked out
## and she bounces (higher with jump held). Works even while invulnerable. Returns true if the ant was stomped.
func _try_stomp(a: PlatformAnt) -> bool:
	var p := player
	if dig != null or fly != null or p.vel.y <= 0.0 or p.on_ground or p.hidden:
		return false
	if absf(p.pos.x - a.pos.x) >= p.radius + a.radius - 3.0:
		return false
	var top: float = a.pos.y - a.radius
	var bottom: float = p.pos.y + p.radius
	if bottom < top - STOMP_DEPTH or bottom > top + STOMP_DEPTH:
		return false
	a.knocked = true
	a.ko_age = 0.0
	a.vel = Vector2.ZERO
	p.pos.y = minf(p.pos.y, top - p.radius)
	p.vel.y = -(JUMP_SPEED * STOMP_HOLD_MULT if _jump_held else STOMP_BOUNCE)
	p.jumping = _jump_held
	p.on_ground = false
	p.coyote = 0.0
	p.squash = Vector2(1.25, 0.8)
	sfx.emit("bounce", {})
	float_text.emit(a.pos + Vector2(0.0, -26.0), tr("FT_PLAT_STOMP"), Palette.FT_GOLD)
	ant_stomped.emit(ants.find(a), a.pos)
	return true


## One heart lost: knock-back away from `away` (-1 or 1), invulnerability, signals; 0 hearts lose the level.
func _hurt_player(away: float) -> void:
	var p := player
	p.hearts -= 1
	p.invuln = INVULN_TIME
	p.hurt_lock = HURT_LOCK_TIME
	p.vel = Vector2(away * KNOCK_SPEED.x, KNOCK_SPEED.y)
	p.on_ground = false
	p.jumping = false
	p.coyote = 0.0
	sfx.emit("worm_hurt", {"dmg": 20.0})
	float_text.emit(p.pos + Vector2(0.0, -30.0), tr("FT_PLAT_HURT"), Palette.FT_RED)
	player_hurt.emit(p.hearts)
	if p.hearts <= 0:
		_finish(false)


# ---------------------------------------------------------------- storm

## Strength (signed px/s²) of wind zone `i` right now, gusts included.
func wind_strength(i: int) -> float:
	var f: float = layout.wind_force[i] if i < layout.wind_force.size() else 0.0
	var period: float = layout.wind_period[i] if i < layout.wind_period.size() else 0.0
	if period <= 0.0:
		return f
	return f * _gust_factor(i, period)


func _gust_factor(i: int, period: float) -> float:
	var swell: float = clampf(sin(TAU * (time / period + 0.37 * i)) * 1.4, 0.0, 1.0)
	return lerpf(GUST_CALM, 1.0, swell)


## Wind acceleration (px/s², + = right) at a point: the strongest zone that contains it, 0 inside tufts.
func wind_at(pt: Vector2) -> float:
	if in_tuft(pt):
		return 0.0
	var best: float = 0.0
	for i in layout.wind_zones.size():
		if layout.wind_zones[i].has_point(pt):
			var w: float = wind_strength(i)
			if absf(w) > absf(best):
				best = w
	return best


## Whether a puddle is under the player's feet.
func in_puddle(p: PlatformBody) -> bool:
	if not p.on_ground:
		return false
	var feet: float = p.pos.y + p.radius
	for r in layout.puddles:
		if p.pos.x >= r.position.x and p.pos.x <= r.end.x and feet >= r.position.y - 8.0 and feet <= r.end.y + 8.0:
			return true
	return false


func _storm_conditions(dt: float) -> void:
	var p := player
	p.wind = wind_at(p.pos) if not layout.wind_zones.is_empty() else 0.0
	for i in layout.wind_zones.size():
		var period: float = layout.wind_period[i] if i < layout.wind_period.size() else 0.0
		if period <= 0.0:
			continue
		var on: bool = _gust_factor(i, period) > 0.6
		if on and not _gust_on[i]:
			var dir: int = 1 if layout.wind_force[i] >= 0.0 else -1
			sfx.emit("wind_gust", {})
			storm_gust.emit(dir)
		_gust_on[i] = on
	var was: bool = p.in_puddle
	p.in_puddle = in_puddle(p)
	_splash_cd = maxf(0.0, _splash_cd - dt)
	if p.in_puddle and (not was or (absf(p.vel.x) > 20.0 and _splash_cd <= 0.0)):
		_splash_cd = 0.25
		splash.emit(Vector2(p.pos.x, p.pos.y + p.radius), "PUDDLE")
		if not was:
			sfx.emit("skid", {})


func _rain_step(dt: float) -> void:
	_rain_cd = maxf(0.0, _rain_cd - dt)
	if layout.rain_rate <= 0.0:
		return
	var p := player
	_rain_acc += layout.rain_rate * dt
	while _rain_acc >= 1.0:
		_rain_acc -= 1.0
		_spawn_drop()
	for i in range(drops.size() - 1, -1, -1):
		var d: PlatformDrop = drops[i]
		d.pos.y += d.speed * dt
		if not p.hidden and _rain_cd <= 0.0 and d.pos.distance_to(p.pos) < p.radius + d.radius:
			var away: float = signf(p.pos.x - d.pos.x)
			if away == 0.0:
				away = float(-p.facing)
			p.vel = Vector2(away * RAIN_KNOCK.x, RAIN_KNOCK.y)
			p.on_ground = false
			p.jumping = false
			p.hurt_lock = maxf(p.hurt_lock, RAIN_LOCK)
			_rain_cd = RAIN_COOLDOWN
			sfx.emit("bounce", {})
			splash.emit(d.pos, "HIT")
			drops.remove_at(i)
		elif d.pos.y >= d.ground_y or d.pos.y > layout.size.y + 40.0:
			if d.ground_y < INF:
				splash.emit(Vector2(d.pos.x, d.ground_y), "PUDDLE" if _puddle_at(d.pos.x, d.ground_y) else "RAIN")
			drops.remove_at(i)


func _spawn_drop() -> void:
	var p := player
	var x: float
	if _rng.randf() < 0.3:
		x = p.pos.x + p.vel.x * 0.8 + _rng.randf_range(-50.0, 50.0)
	else:
		x = p.pos.x + _rng.randf_range(-640.0, 640.0)
	x = clampf(x, 8.0, layout.size.x - 8.0)
	var d := PlatformDrop.new()
	var y0: float = p.pos.y - RAIN_HEIGHT
	d.pos = Vector2(x, y0)
	d.ground_y = surface_y(x, y0, 0.0, layout.size.y + 400.0)
	drops.append(d)


func _puddle_at(x: float, y: float) -> bool:
	for r in layout.puddles:
		if x >= r.position.x and x <= r.end.x and y >= r.position.y - 8.0 and y <= r.end.y + 8.0:
			return true
	return false


# ---------------------------------------------------------------- boss

func _on_boss_warned(target: Vector2) -> void:
	sfx.emit("mine_beep", {})
	boss_warn.emit(target)


func _on_boss_missed() -> void:
	boss_missed.emit()
	for i in layout.tufts.size():
		if layout.tufts[i].has_point(player.pos) and tuft_flattened[i] <= 0.0:
			tuft_flattened[i] = TUFT_FLATTEN_TIME
			player.hidden = false
			tuft_flatten.emit(i)


func _on_boss_dived() -> void:
	sfx.emit("jet_thrust", {})
	boss_dive.emit()


func _boss_step(dt: float) -> void:
	if boss == null:
		return
	var attacking: bool = time >= PlatformBoss.INTRO
	var difficulty: float = clampf(1.0 - time_left / maxf(layout.boss_time, 0.01), 0.0, 1.0)
	boss.step(dt, player, difficulty, attacking, layout.solids)
	var p := player
	if not p.hidden and p.invuln <= 0.0 and p.pos.distance_to(boss.pos) < p.radius + BOSS_HIT_RADIUS:
		var away: float = signf(p.pos.x - boss.pos.x)
		_hurt_player(away if away != 0.0 else float(-boss.facing))
		return
	if attacking:
		time_left = maxf(0.0, time_left - dt)
		if time_left <= 0.0:
			_finish(true, "HATCHED")

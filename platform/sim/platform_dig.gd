## DIG mode of the platformer (layout.mode == "DIG"): the Crisàlide stage, a cross-section of soil. Created and stepped by PlatformSim.
## See docs/platform2_contracts.md §1.
##
## == API for the view (all read-only) ==
## PlatformSim.dig: PlatformDig (null in other modes). PlatformSim.player is the pupa (radius 12).
## Input: PlatformSim.set_move(-1|0|1), set_vertical(-1 up | 0 | 1 down), set_jump(held). Holding a direction into soil digs (60 px/s); in a
##   shaft, holding up with a wall beside her climbs (wriggles). The hop is small. Digging a stone crumbles it.
## The world: a grid of CELL (4) px cells, `cols` x `rows`.
##   mask: PackedByteArray, index = cy * cols + cx, values AIR 0, SOIL 1, ROCK 2 (undiggable), ROOT 3 (undiggable).
##   image: Image (FORMAT_L8, same values in the red channel; always in sync with `mask`) for ImageTexture.create_from_image / update.
##   Signal PlatformSim.dig_changed(cells: Rect2i): the cells (in cell units) whose value changed this step. Multiply by CELL for pixels.
##   cell_at(cx, cy) -> int, value_at_px(pt) -> int (out of the world counts as ROCK).
## Pupa state: `digging` (bool, true while she is cutting soil), `dig_dir` (Vector2, the input direction, zero when idle),
##   `climbing` (bool), `drown` (seconds underwater, 0..DROWN_TIME; the heart is lost at DROWN_TIME).
## Stones: `stones: Array[PlatformStone]` (pos, state "REST"/"WOBBLE"/"FALL"/"GONE", timer, crumble 0..CRUMBLE_TIME; rect()).
##   Signals: stone_wobble(idx), stone_landed(idx), stone_broken(idx, hit) (hit true when it shattered on her).
## Flood: `water_y` (world y of the water surface; INF without flood). Everything with y > water_y is under water.
## Noise (HOOPOE level only): `noise_rings: Array[PlatformRing]` (pos, radius, max_radius, fade()); signal noise_made(pos, max_radius).
## Boss: `hoopoe: PlatformHoopoe` (see its header; null without boss), PlatformSim.time_left, signals boss_warn(target) at the start of the
##   telegraph, boss_dive() when the beak goes down. Win: time_left <= 0 -> level_finished reason "METAMORPHOSIS".
## Goal levels: the centre of the pupa inside layout.goal -> reason "REACHED_GOAL". Sap (nutrients) and checkpoints work as in the egg levels.
class_name PlatformDig
extends RefCounted

const CELL: int = 4
const AIR: int = 0
const SOIL: int = 1
const ROCK: int = 2
const ROOT: int = 3

const RADIUS: float = 12.0
const DIG_SPEED: float = 60.0
const WALK_SPEED: float = 100.0
const WALK_ACCEL: float = 900.0
const FRICTION: float = 1400.0
const GRAVITY: float = 1700.0
const JUMP_SPEED: float = 400.0
const JUMP_CUT_SPEED: float = 150.0
const MAX_FALL: float = 700.0
const COYOTE_TIME: float = 0.1
const BUFFER_TIME: float = 0.12
const MAX_STEP_PX: float = 3.5
## The brush that cuts the soil: the pupa's radius plus CARVE_EXTRA, centred CARVE_LEAD px ahead of her.
const CARVE_EXTRA: float = 1.0
const CARVE_LEAD: float = 3.0
const DIG_HOLD: float = 0.1
const WOBBLE_TIME: float = 0.35
const STONE_GRAVITY: float = 1500.0
const STONE_MAX_FALL: float = 760.0
const CRUMBLE_TIME: float = 0.5
const DROWN_TIME: float = 2.0
const NOISE_DIG_EVERY: float = 0.45
const NOISE_DIG_RADIUS: float = 340.0
const NOISE_WALK_EVERY: float = 0.6
const NOISE_WALK_RADIUS: float = 220.0
const NOISE_SPEED: float = 300.0
const NOISE_WALK_MIN_SPEED: float = 80.0

var cols: int = 0
var rows: int = 0
var mask: PackedByteArray = PackedByteArray()
var image: Image = null
var stones: Array[PlatformStone] = []
var noise_rings: Array[PlatformRing] = []
var hoopoe: PlatformHoopoe = null
var water_y: float = INF
var drown: float = 0.0
var digging: bool = false
var climbing: bool = false
var dig_dir: Vector2 = Vector2.ZERO

var _dirty: Rect2i = Rect2i()
var _has_dirty: bool = false
var _dig_cd: float = 0.0
var _flood_wait: float = 0.0
var _noise_cd: float = 0.0
var _was_ground: bool = false
var _scoop_cd: float = 0.0


## Builds the mask, stones, water and boss from the layout, and turns the player into the pupa.
func setup(sim: PlatformSim) -> void:
	var lay: PlatformLayout = sim.layout
	cols = ceili(lay.size.x / CELL)
	rows = ceili(lay.size.y / CELL)
	mask = PackedByteArray()
	mask.resize(cols * rows)
	mask.fill(AIR)
	_fill(lay.soil, SOIL)
	_fill(lay.solids, ROCK)
	_fill(lay.roots, ROOT)
	_fill(lay.gaps, AIR)
	image = Image.create_from_data(cols, rows, false, Image.FORMAT_L8, mask)
	stones.clear()
	for c in lay.stones:
		var s := PlatformStone.new()
		s.pos = c
		stones.append(s)
	noise_rings.clear()
	hoopoe = null
	if lay.boss == "HOOPOE":
		hoopoe = PlatformHoopoe.new()
		hoopoe.setup(lay.surface_y, 60.0, lay.size.x - 60.0)
		sim.time_left = lay.boss_time
	water_y = INF
	_flood_wait = 0.0
	if lay.flood_rate > 0.0:
		water_y = lay.flood_start if lay.flood_start > 0.0 else lay.size.y
		_flood_wait = lay.flood_delay
	drown = 0.0
	digging = false
	climbing = false
	dig_dir = Vector2.ZERO
	_dig_cd = 0.0
	_noise_cd = 0.0
	_was_ground = false
	_has_dirty = false
	sim.player.radius = RADIUS


## Cell value (AIR, SOIL, ROCK, ROOT); outside the world counts as ROCK.
func cell_at(cx: int, cy: int) -> int:
	if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
		return ROCK
	return mask[cy * cols + cx]


## Cell value at a world point.
func value_at_px(pt: Vector2) -> int:
	return cell_at(floori(pt.x / CELL), floori(pt.y / CELL))


## Highest walkable surface y at x between from_y - max_up and from_y + max_down, or INF (same contract as PlatformSim.surface_y).
func surface_y(x: float, from_y: float, max_up: float, max_down: float) -> float:
	var cx: int = floori(x / CELL)
	if cx < 0 or cx >= cols:
		return INF
	for cy in range(floori((from_y - max_up) / CELL), floori((from_y + max_down) / CELL) + 1):
		if cell_at(cx, cy) != AIR and cell_at(cx, cy - 1) == AIR:
			return float(cy * CELL)
	return INF


## True when only air lies on the segment a-b (sampled every 4 px).
func line_clear(a: Vector2, b: Vector2) -> bool:
	var n: int = maxi(ceili(a.distance_to(b) / float(CELL)), 1)
	for i in range(1, n):
		if value_at_px(a.lerp(b, float(i) / float(n))) != AIR:
			return false
	return true


## Cuts the SOIL cells whose rectangle is closer than `r` to `c`, except those whose top is at or below `floor_y`. Returns how many.
func carve_circle(c: Vector2, r: float, floor_y: float = INF) -> int:
	var n: int = 0
	var r2: float = r * r
	for cy in range(maxi(floori((c.y - r) / CELL), 0), mini(floori((c.y + r) / CELL), rows - 1) + 1):
		var top: float = float(cy * CELL)
		if top >= floor_y:
			continue
		var dy: float = maxf(maxf(top - c.y, c.y - (top + CELL)), 0.0)
		for cx in range(maxi(floori((c.x - r) / CELL), 0), mini(floori((c.x + r) / CELL), cols - 1) + 1):
			if mask[cy * cols + cx] != SOIL:
				continue
			var left: float = float(cx * CELL)
			var dx: float = maxf(maxf(left - c.x, c.x - (left + CELL)), 0.0)
			if dx * dx + dy * dy < r2:
				_set_cell(cx, cy, AIR)
				n += 1
	return n


## The hoopoe's beak: cuts a shaft BEAK_HALF either side of x from y0 down to y1. Returns the y the tip reached (stops above rock and roots).
func carve_beak(x: float, y0: float, y1: float) -> float:
	var c0: int = floori((x - PlatformHoopoe.BEAK_HALF) / CELL)
	var c1: int = floori((x + PlatformHoopoe.BEAK_HALF) / CELL)
	for cy in range(floori(y0 / CELL), ceili(y1 / CELL)):
		for cx in range(c0, c1 + 1):
			var v: int = cell_at(cx, cy)
			if v == ROCK or v == ROOT:
				return maxf(y0, float(cy * CELL))
		for cx in range(c0, c1 + 1):
			if cell_at(cx, cy) == SOIL:
				_set_cell(cx, cy, AIR)
	return y1


## Advances the dig mode by dt (called by PlatformSim.step).
func step(sim: PlatformSim, dt: float) -> void:
	var p: PlatformBody = sim.player
	p.invuln = maxf(0.0, p.invuln - dt)
	p.hurt_lock = maxf(0.0, p.hurt_lock - dt)
	p.buffer = maxf(0.0, p.buffer - dt)
	p.hidden = false
	_flood(sim, dt)
	_control(sim, dt)
	_move(sim, dt)
	if not sim.finished:
		_stones_step(sim, dt)
	if not sim.finished:
		sim._pickups()
		sim._ants_step(dt)
		_ants_fall(sim, dt)
	if not sim.finished:
		_boss_step(sim, dt)
	if not sim.finished:
		sim._squash_step(dt)
		if sim.layout.boss == "" and sim.layout.goal.has_point(p.pos):
			sim._finish(true)
	_flush(sim)


# ---------------------------------------------------------------- build

func _fill(rects: Array[Rect2], value: int) -> void:
	for r in rects:
		var x0: int = maxi(ceili(r.position.x / CELL - 0.5), 0)
		var x1: int = mini(ceili(r.end.x / CELL - 0.5) - 1, cols - 1)
		var y0: int = maxi(ceili(r.position.y / CELL - 0.5), 0)
		var y1: int = mini(ceili(r.end.y / CELL - 0.5) - 1, rows - 1)
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				mask[cy * cols + cx] = value


func _set_cell(cx: int, cy: int, v: int) -> void:
	mask[cy * cols + cx] = v
	image.set_pixel(cx, cy, Color((v + 0.5) / 255.0, 0.0, 0.0))
	if _has_dirty:
		_dirty = _dirty.expand(Vector2i(cx, cy)).expand(Vector2i(cx + 1, cy + 1))
	else:
		_dirty = Rect2i(cx, cy, 1, 1)
		_has_dirty = true


func _flush(sim: PlatformSim) -> void:
	if _has_dirty:
		_has_dirty = false
		sim.dig_changed.emit(_dirty)


# ---------------------------------------------------------------- the pupa

func _control(sim: PlatformSim, dt: float) -> void:
	var p: PlatformBody = sim.player
	var locked: bool = p.hurt_lock > 0.0
	var mv: int = 0 if locked else sim._move
	var vt: int = 0 if locked else sim._vert
	digging = false
	climbing = false
	dig_dir = Vector2.ZERO
	_dig_cd = maxf(0.0, _dig_cd - dt)
	var dn: Vector2 = Vector2.ZERO
	if mv != 0 or vt != 0:
		dn = Vector2(mv, vt).normalized()
		dig_dir = dn
		var floor_y: float = INF if vt > 0 else p.pos.y + p.radius - 0.5
		if carve_circle(p.pos + dn * CARVE_LEAD, p.radius + CARVE_EXTRA, floor_y) > 0:
			_dig_cd = DIG_HOLD
		var crumbled: bool = _crumble_stone(sim, dn, dt)
		digging = _dig_cd > 0.0 or crumbled or _soil_ahead(p, dn)
		_scoop_cd = maxf(0.0, _scoop_cd - dt)
		if digging and _scoop_cd <= 0.0:
			_scoop_cd = 0.35
			sim.sfx.emit("spoon_scoop", {})
	if mv != 0:
		p.facing = mv
	# Horizontal.
	if digging and mv != 0:
		p.vel.x = dn.x * DIG_SPEED * sim.dig_speed_mult
	elif mv != 0:
		var rate: float = WALK_ACCEL * (2.0 if signf(p.vel.x) == -float(mv) else 1.0)
		p.vel.x = move_toward(p.vel.x, mv * WALK_SPEED, rate * dt)
	elif not locked:
		p.vel.x = move_toward(p.vel.x, 0.0, FRICTION * dt)
	# Coyote time and the hop.
	p.coyote = COYOTE_TIME if p.on_ground else maxf(0.0, p.coyote - dt)
	if p.buffer > 0.0 and p.coyote > 0.0 and not locked:
		p.vel.y = -JUMP_SPEED
		p.on_ground = false
		p.coyote = 0.0
		p.buffer = 0.0
		p.jumping = true
		p.squash = Vector2(0.8, 1.25)
		sim.sfx.emit("jump", {})
		_noise(sim, p.pos, 160.0, 0.3)
	if p.jumping and not sim._jump_held and p.vel.y < -JUMP_CUT_SPEED:
		p.vel.y = -JUMP_CUT_SPEED
	# Vertical: dig up/down, wriggle up a shaft, or gravity.
	if digging and vt != 0:
		p.vel.y = dn.y * DIG_SPEED * sim.dig_speed_mult
	elif vt < 0 and _wall_beside(p):
		p.vel.y = -DIG_SPEED * sim.dig_speed_mult
		climbing = true
	elif p.on_ground and p.vel.y >= 0.0:
		p.vel.y = 0.0
	else:
		p.vel.y = minf(p.vel.y + GRAVITY * dt, MAX_FALL)
	if absf(p.vel.x) > 1.0 and p.on_ground:
		p.walk_cycle += absf(p.vel.x) * dt * 0.06
	# Noise of the pupa (the hoopoe level only).
	if hoopoe != null:
		_noise_cd = maxf(0.0, _noise_cd - dt)
		if p.pos.y < sim.layout.surface_y + 4.0:
			_noise(sim, p.pos, 400.0, 0.4)
		elif digging:
			_noise(sim, p.pos, NOISE_DIG_RADIUS, NOISE_DIG_EVERY)
		elif p.on_ground and absf(p.vel.x) > NOISE_WALK_MIN_SPEED:
			_noise(sim, p.pos, NOISE_WALK_RADIUS, NOISE_WALK_EVERY)


## Whether soil (or a stone) lies just beyond the brush in direction dn: the pupa is about to cut.
func _soil_ahead(p: PlatformBody, dn: Vector2) -> bool:
	var perp: Vector2 = Vector2(-dn.y, dn.x)
	var reach: float = p.radius + CARVE_LEAD + CARVE_EXTRA + 3.9
	for k in [0.0, -7.0, 7.0]:
		if value_at_px(p.pos + dn * reach + perp * k) == SOIL:
			return true
	return false


func _wall_beside(p: PlatformBody) -> bool:
	for sx in [-1.0, 1.0]:
		for k in [-0.5, 0.0]:
			if _solid_px(Vector2(p.pos.x + sx * (p.radius + 9.0), p.pos.y + k * p.radius)):
				return true
	return false


## Solid for the pupa: any filled cell, or a stone that is not falling.
func _solid_px(pt: Vector2) -> bool:
	if value_at_px(pt) != AIR:
		return true
	for s in stones:
		if (s.state == "REST" or s.state == "WOBBLE") and s.rect().has_point(pt):
			return true
	return false


func _has_floor(p: PlatformBody) -> bool:
	for k in [-0.55, 0.0, 0.55]:
		if _solid_px(Vector2(p.pos.x + k * p.radius, p.pos.y + p.radius + 1.5)):
			return true
	return false


## The pupa digs into a stone: it crumbles after CRUMBLE_TIME. Returns true while she is working on one.
func _crumble_stone(sim: PlatformSim, dn: Vector2, dt: float) -> bool:
	var p: PlatformBody = sim.player
	var probe: Vector2 = p.pos + dn * 4.0
	for i in stones.size():
		var s: PlatformStone = stones[i]
		if s.state != "REST" and s.state != "WOBBLE":
			continue
		if sim._push_rect(probe, p.radius + 1.0, s.rect()) == Vector2.ZERO:
			continue
		s.crumble += dt
		if s.crumble >= CRUMBLE_TIME:
			s.state = "GONE"
			sim.sfx.emit("hard_slam", {})
			sim.stone_broken.emit(i, false)
		return true
	return false


func _move(sim: PlatformSim, dt: float) -> void:
	var p: PlatformBody = sim.player
	var n: int = clampi(ceili(maxf(absf(p.vel.x), absf(p.vel.y)) * dt / MAX_STEP_PX), 1, 16)
	var h: float = dt / float(n)
	var impact: float = 0.0
	for i in n:
		p.pos += p.vel * h
		impact = maxf(impact, p.vel.y)
		_resolve(sim, p)
	p.pos.x = clampf(p.pos.x, p.radius, sim.layout.size.x - p.radius)
	p.pos.y = clampf(p.pos.y, p.radius, sim.layout.size.y - p.radius)
	var grounded: bool = p.vel.y >= -1.0 and _has_floor(p)
	if grounded and not _was_ground and impact > 250.0:
		var k: float = clampf(impact / 900.0, 0.0, 1.0) * 0.35
		p.squash = Vector2(1.0 + k, 1.0 - k)
		if impact > 420.0:
			_noise(sim, p.pos, 240.0, 0.3)
	p.on_ground = grounded
	_was_ground = grounded
	if grounded:
		p.jumping = false


## Pushes the pupa out of every filled cell and resting stone.
func _resolve(sim: PlatformSim, p: PlatformBody) -> void:
	var r: float = p.radius
	var r2: float = r * r
	for _it in 3:
		var moved: bool = false
		for cy in range(maxi(floori((p.pos.y - r) / CELL), 0), mini(floori((p.pos.y + r) / CELL), rows - 1) + 1):
			var top: float = float(cy * CELL)
			for cx in range(maxi(floori((p.pos.x - r) / CELL), 0), mini(floori((p.pos.x + r) / CELL), cols - 1) + 1):
				if mask[cy * cols + cx] == AIR:
					continue
				var left: float = float(cx * CELL)
				var dx: float = p.pos.x - clampf(p.pos.x, left, left + CELL)
				var dy: float = p.pos.y - clampf(p.pos.y, top, top + CELL)
				if dx * dx + dy * dy >= r2:
					continue
				sim._apply_push(p, sim._push_rect(p.pos, r, Rect2(left, top, CELL, CELL)))
				moved = true
		for s in stones:
			if s.state == "REST" or s.state == "WOBBLE":
				var push: Vector2 = sim._push_rect(p.pos, r, s.rect())
				if push != Vector2.ZERO:
					sim._apply_push(p, push)
					moved = true
		if not moved:
			break


# ---------------------------------------------------------------- stones and ants

func _stones_step(sim: PlatformSim, dt: float) -> void:
	var p: PlatformBody = sim.player
	for i in stones.size():
		var s: PlatformStone = stones[i]
		match s.state:
			"REST":
				if not _stone_supported(s):
					s.state = "WOBBLE"
					s.timer = WOBBLE_TIME
					sim.stone_wobble.emit(i)
					sim.sfx.emit("tick", {})
			"WOBBLE":
				s.timer -= dt
				if s.timer <= 0.0:
					s.state = "FALL"
					s.vel_y = 0.0
			"FALL":
				s.vel_y = minf(s.vel_y + STONE_GRAVITY * dt, STONE_MAX_FALL)
				var dist: float = s.vel_y * dt
				var n: int = maxi(ceili(dist / 3.0), 1)
				for k in n:
					s.pos.y += dist / float(n)
					if sim._push_rect(p.pos, p.radius, s.rect()) != Vector2.ZERO:
						_stone_hits(sim, i, s)
						break
					var row: int = floori((s.pos.y + PlatformStone.HALF) / CELL)
					if _row_filled(s, row):
						s.pos.y = float(row * CELL) - PlatformStone.HALF
						s.state = "REST"
						s.vel_y = 0.0
						sim.sfx.emit("hard_slam", {})
						sim.stone_landed.emit(i)
						break
					if s.pos.y > sim.layout.size.y:
						s.state = "GONE"
						break
			_:
				pass
		if sim.finished:
			return


func _stone_hits(sim: PlatformSim, idx: int, s: PlatformStone) -> void:
	var p: PlatformBody = sim.player
	s.state = "GONE"
	sim.sfx.emit("hard_slam", {})
	sim.stone_broken.emit(idx, true)
	if p.invuln <= 0.0:
		var away: float = signf(p.pos.x - s.pos.x)
		sim._hurt_player(away if away != 0.0 else float(-p.facing))


func _row_filled(s: PlatformStone, row: int) -> bool:
	for cx in range(floori((s.pos.x - PlatformStone.HALF + 0.5) / CELL), floori((s.pos.x + PlatformStone.HALF - 0.5) / CELL) + 1):
		if cell_at(cx, row) != AIR:
			return true
	return false


## A stone stays while at least half of the columns under it are filled.
func _stone_supported(s: PlatformStone) -> bool:
	var row: int = floori((s.pos.y + PlatformStone.HALF + 0.01) / CELL)
	var c0: int = floori((s.pos.x - PlatformStone.HALF + 0.5) / CELL)
	var c1: int = floori((s.pos.x + PlatformStone.HALF - 0.5) / CELL)
	var filled: int = 0
	for cx in range(c0, c1 + 1):
		if cell_at(cx, row) != AIR:
			filled += 1
	return filled * 2 >= (c1 - c0 + 1)


## Ants whose floor was dug away drop to the next surface.
func _ants_fall(sim: PlatformSim, dt: float) -> void:
	for a in sim.ants:
		if is_inf(surface_y(a.pos.x, a.feet(), 12.0, 8.0)):
			var sy: float = surface_y(a.pos.x, a.feet(), 0.0, 600.0)
			if not is_inf(sy):
				a.pos.y = minf(a.pos.y + 450.0 * dt, sy - a.radius)


# ---------------------------------------------------------------- flood

func _flood(sim: PlatformSim, dt: float) -> void:
	if sim.layout.flood_rate <= 0.0:
		return
	if _flood_wait > 0.0:
		_flood_wait -= dt
	else:
		water_y = maxf(0.0, water_y - sim.layout.flood_rate * dt)
	var p: PlatformBody = sim.player
	if p.pos.y > water_y:
		drown += dt
		if drown >= DROWN_TIME:
			drown = 0.0
			p.hearts -= 1
			sim.sfx.emit("worm_hurt", {"dmg": 20.0})
			sim.float_text.emit(p.pos + Vector2(0.0, -30.0), sim.tr("FT_PLAT2_DROWN"), Palette.FT_RED)
			sim.player_hurt.emit(p.hearts)
			if p.hearts <= 0:
				sim._finish(false)
	else:
		drown = maxf(0.0, drown - 2.0 * dt)


# ---------------------------------------------------------------- noise and the hoopoe

## Adds a noise ring unless the cooldown is running (`every` is the cooldown set after it).
func _noise(sim: PlatformSim, at: Vector2, max_radius: float, every: float) -> void:
	if hoopoe == null or _noise_cd > 0.0:
		return
	_noise_cd = every
	var ring := PlatformRing.new()
	ring.pos = at
	ring.max_radius = max_radius
	ring.speed = NOISE_SPEED
	noise_rings.append(ring)
	sim.noise_made.emit(at, max_radius)


func _boss_step(sim: PlatformSim, dt: float) -> void:
	if hoopoe == null:
		return
	var p: PlatformBody = sim.player
	var attacking: bool = sim.time >= PlatformBoss.INTRO
	var difficulty: float = clampf(1.0 - sim.time_left / maxf(sim.layout.boss_time, 0.01), 0.0, 1.0)
	var surface: float = sim.layout.surface_y
	for i in range(noise_rings.size() - 1, -1, -1):
		var ring: PlatformRing = noise_rings[i]
		var alive: bool = ring.grow(dt)
		if not ring.heard and ring.radius >= ring.pos.y - surface:
			ring.heard = true
			hoopoe.hear(ring.pos.x)
		if not alive:
			noise_rings.remove_at(i)
	hoopoe.step(sim, self, dt, difficulty, attacking)
	if p.invuln <= 0.0:
		if hoopoe.beak_out():
			var cy: float = clampf(p.pos.y, surface, hoopoe.tip_y)
			if Vector2(p.pos.x - hoopoe.target.x, p.pos.y - cy).length() < p.radius + PlatformHoopoe.BEAK_HALF:
				var away: float = signf(p.pos.x - hoopoe.target.x)
				sim._hurt_player(away if away != 0.0 else float(-p.facing))
				return
		if p.pos.distance_to(hoopoe.pos) < p.radius + hoopoe.radius - 4.0:
			sim._hurt_player(signf(p.pos.x - hoopoe.pos.x))
			return
	if attacking:
		sim.time_left = maxf(0.0, sim.time_left - dt)
		if sim.time_left <= 0.0:
			sim._finish(true, "METAMORPHOSIS")

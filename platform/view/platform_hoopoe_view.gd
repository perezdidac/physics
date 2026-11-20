## The hoopoe boss of the pupa stage (DIG mode). It reads the sim's PlatformHoopoe (pos, facing, state, target, timer, warn_time, tip_y)
## and draws the bird (platform_bird_art.gd), the telegraph (a growing strike shadow on the surface, a red column showing how deep the
## stab goes and a dirt trickle that gets heavier) and the stab itself: a long beak driven straight down into the soil.
class_name PlatformHoopoeView
extends Node2D

## Registry ids this view draws through (checked by the registry test).
const ART_KINDS: Array[String] = ["platform:hoopoe"]

var _actx := ArtContext.new()

const BIRD_SCALE: float = 0.9
const STAB_DEPTH: float = 260.0

## Sim hoopoe (a PlatformHoopoe); null hides the bird.
var boss: Variant = null
var t_now: float = 0.0
var prev_x: float = 0.0
var cur_x: float = 0.0
## Dirt particles falling from the cracked surface at the target: Dictionaries {p, v, life, max}.
var _dirt: Array[Dictionary] = []
var _walk: float = 0.0
var _crest: float = 0.0
var _wing: float = 0.0
var _lean: float = 0.0
var _alarm: float = 0.0
var _last_state: String = "IDLE"
var _state_t: float = 0.0
var _dirt_acc: float = 0.0


## Records the x position at the end of a simulation step.
func record(first: bool) -> void:
	if boss == null:
		return
	var x: float = _vec("pos").x
	prev_x = x if first else cur_x
	cur_x = x


## Places the bird between the last two steps and animates it.
func present(alpha: float, p_t_now: float, dt: float) -> void:
	visible = boss != null
	if boss == null:
		return
	t_now = p_t_now
	var state: String = ViewUtil.gs(boss, "state", "IDLE")
	if state != _last_state:
		_last_state = state
		_state_t = 0.0
	_state_t += dt
	var x: float = lerpf(prev_x, cur_x, alpha)
	if absf(prev_x - cur_x) > 200.0:
		x = cur_x
	var surf: float = ViewUtil.gf(boss, "surface_y")
	position = Vector2(x, surf)
	var speed: float = absf(cur_x - prev_x) / (1.0 / 60.0)
	_walk += dt * clampf(speed / 9.0, 0.0, 30.0) if speed > 3.0 else 0.0
	var want_crest: float = 0.0
	var want_wing: float = 0.0
	var want_lean: float = 0.0
	match state:
		"IDLE":
			want_lean = sin(t_now * 3.0) * 0.04 + 0.05 * clampf(sin(t_now * 0.9) * 4.0, 0.0, 1.0)
		"HUNT":
			want_crest = 1.0
			want_wing = 0.35
			want_lean = 0.12
		"AIM":
			want_crest = 1.0
			want_wing = 0.9
			want_lean = -0.28
		"STAB", "HOLD":
			want_crest = 1.0
			want_wing = 0.5
			want_lean = 1.0
		"PULL":
			want_crest = 0.6
			want_wing = 0.4
			want_lean = 0.9
		"REST":
			want_crest = 0.1
			want_lean = 0.25 + sin(t_now * 4.0) * 0.05
	var k: float = 1.0 - exp(-dt * 12.0)
	_crest += (want_crest - _crest) * (1.0 - exp(-dt * 8.0))
	_wing += (want_wing - _wing) * k
	_lean += (want_lean - _lean) * (1.0 - exp(-dt * (22.0 if state == "STAB" else 10.0)))
	_alarm = 1.0 if state == "AIM" or state == "STAB" or state == "HOLD" else 0.0
	_update_dirt(dt, state)
	queue_redraw()


func _update_dirt(dt: float, state: String) -> void:
	var tx: float = _vec("target").x
	var surf: float = ViewUtil.gf(boss, "surface_y")
	if state == "AIM":
		var warn: float = maxf(ViewUtil.gf(boss, "warn_time", 0.8), 0.01)
		var prog: float = clampf(1.0 - ViewUtil.gf(boss, "timer") / warn, 0.0, 1.0)
		_dirt_acc += dt * (14.0 + 70.0 * prog)
		while _dirt_acc >= 1.0:
			_dirt_acc -= 1.0
			_dirt.append({"p": Vector2(tx + (randf() - 0.5) * 22.0, surf + 3.0), "v": Vector2((randf() - 0.5) * 18.0, 20.0 + randf() * 40.0), "life": 0.0, "max": 0.5 + randf() * 0.4})
	elif state == "STAB":
		for q in 3:
			_dirt.append({"p": Vector2(tx + (randf() - 0.5) * 16.0, surf - 2.0), "v": Vector2((randf() - 0.5) * 160.0, -60.0 - randf() * 140.0), "life": 0.0, "max": 0.5 + randf() * 0.3})
	for d in _dirt:
		d["life"] += dt
		d["v"] = (d["v"] as Vector2) + Vector2(0.0, 420.0 * dt)
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * dt
	_dirt = _dirt.filter(func(d: Dictionary) -> bool: return d["life"] < d["max"])


func _vec(key: String) -> Vector2:
	return ViewUtil.g(boss, key, Vector2.ZERO)


## Number of live dirt particles (tests).
func dirt_count() -> int:
	return _dirt.size()


func _draw() -> void:
	if boss == null:
		return
	var state: String = ViewUtil.gs(boss, "state", "IDLE")
	var surf: float = ViewUtil.gf(boss, "surface_y")
	var facing: float = float(ViewUtil.gi(boss, "facing", 1))
	var target: Vector2 = _vec("target")
	var striking: bool = state == "STAB" or state == "HOLD" or state == "PULL"
	if state == "AIM":
		_draw_telegraph(target)
	for d in _dirt:
		var k: float = 1.0 - float(d["life"]) / float(d["max"])
		draw_rect(Rect2((d["p"] as Vector2) - Vector2(1.5, 1.5) - position, Vector2(3.0, 3.0)), Color(0.45, 0.31, 0.19, k))
	var s: float = BIRD_SCALE
	var root: Vector2 = PlatformBirdArt.hoopoe_beak_root(_lean) * s
	# in a stab the whole bird shifts back so that the head is above the target and the beak goes straight down
	var shift: float = 0.0
	if striking:
		shift = target.x - position.x - facing * root.x
	var o := {
		"base": Transform2D(0.0, Vector2(facing * s, s), 0.0, Vector2(shift, 0.0)),
		"crest": _crest, "wing": _wing, "lean": _lean, "walk": _walk, "alarm": _alarm,
		"step": 1.0 if state == "IDLE" or state == "HUNT" else 0.0,
		"beak_len": 38.0, "beak_pitch": -0.5 if state == "AIM" else 0.0,
		"hide_beak": striking,
	}
	_actx.t = t_now
	ArtRegistry.draw("platform:hoopoe", self, o, _actx)
	if striking:
		_draw_beak(Vector2(shift + facing * root.x, root.y), surf)
	if state == "REST":
		_draw_dizzy(Vector2(facing * 22.0 * s, -64.0 * s))


## The long beak driving down: from the head to `tip_y`, with a rounded root, a fine point and a streak while it is moving fast.
func _draw_beak(root: Vector2, surf: float) -> void:
	var tip_y: float = ViewUtil.gf(boss, "tip_y", surf) - position.y
	var tx: float = root.x
	if tip_y <= root.y + 2.0:
		return
	var half: float = 8.5
	var poly := PackedVector2Array([Vector2(tx - half, root.y), Vector2(tx + half, root.y), Vector2(tx + 2.0, tip_y - 6.0), Vector2(tx, tip_y), Vector2(tx - 2.0, tip_y - 6.0)])
	draw_colored_polygon(poly, Color(0.34, 0.25, 0.21))
	draw_line(Vector2(tx - half * 0.4, root.y), Vector2(tx - 1.0, tip_y - 6.0), Color(0.86, 0.76, 0.62, 0.9), 2.0, true)
	draw_line(Vector2(tx + half * 0.5, root.y), Vector2(tx + 1.0, tip_y - 6.0), Color(0.12, 0.08, 0.07, 0.8), 2.0, true)
	var loop: PackedVector2Array = poly.duplicate()
	loop.append(poly[0])
	draw_polyline(loop, ViewColors.h(PlatformBirdArt.OUTLINE), 1.4, true)
	if ViewUtil.gs(boss, "state") == "STAB":
		draw_line(Vector2(tx, root.y - 16.0), Vector2(tx, root.y + 10.0), Color(1.0, 1.0, 1.0, 0.35), 3.0, true)
	if tip_y > 6.0:
		# a lip of broken soil around the hole in the surface
		draw_line(Vector2(tx - 14.0, 0.0), Vector2(tx - 8.0, -3.0), Color(0.45, 0.31, 0.19), 3.0, true)
		draw_line(Vector2(tx + 14.0, 0.0), Vector2(tx + 8.0, -3.0), Color(0.45, 0.31, 0.19), 3.0, true)


## Strike shadow on the surface and the column the beak will go through.
func _draw_telegraph(target: Vector2) -> void:
	var warn: float = maxf(ViewUtil.gf(boss, "warn_time", 0.8), 0.01)
	var k: float = clampf(1.0 - ViewUtil.gf(boss, "timer") / warn, 0.0, 1.0)
	var c: Vector2 = target - position
	var pulse: float = 0.5 + 0.5 * sin(t_now * 26.0)
	# the shadow of the beak: a dark ellipse that grows, then a red ring that closes in
	ViewUtil.fill_ellipse(self, c + Vector2(0.0, 2.0), 10.0 + 34.0 * k, 3.0 + 7.0 * k, Color(0.0, 0.0, 0.0, 0.25 + 0.3 * k))
	ViewUtil.stroke_ellipse(self, c + Vector2(0.0, 2.0), lerpf(70.0, 16.0, k), lerpf(14.0, 4.0, k), Color(1.0, 0.3, 0.2, 0.5 + 0.35 * pulse), 2.5)
	# the column under the target: dashed edges and a tint that fills downwards as the hit gets closer
	var depth: float = STAB_DEPTH
	var half: float = 9.0
	draw_rect(Rect2(c.x - half, c.y + 4.0, half * 2.0, depth * k), Color(1.0, 0.25, 0.15, 0.12 + 0.1 * pulse))
	ViewUtil.dashed(self, PackedVector2Array([Vector2(c.x - half, c.y + 4.0), Vector2(c.x - half, c.y + depth)]), 8.0, 6.0, Color(1.0, 0.4, 0.3, 0.55), 1.5)
	ViewUtil.dashed(self, PackedVector2Array([Vector2(c.x + half, c.y + 4.0), Vector2(c.x + half, c.y + depth)]), 8.0, 6.0, Color(1.0, 0.4, 0.3, 0.55), 1.5)
	# little cracks in the turf
	for q in 4:
		var fq: float = float(q) - 1.5
		draw_line(c + Vector2(fq * 7.0, 1.0), c + Vector2(fq * 11.0, 7.0 + 4.0 * k), Color(0.2, 0.12, 0.06, 0.8), 1.4, true)
	ViewUtil.text(self, "!", c + Vector2(0.0, -86.0 - 6.0 * pulse), 26, Color(1.0, 0.85, 0.3, 0.95))


func _draw_dizzy(c: Vector2) -> void:
	for q in 3:
		var an: float = t_now * 4.0 + float(q) * TAU / 3.0
		var sp: Vector2 = c + Vector2(cos(an) * 20.0, sin(an) * 6.0 - 8.0)
		draw_circle(sp, 3.2, Color(1.0, 0.9, 0.3, 0.9))

## The parasitoid wasp of the boss level, drawn procedurally: a striped abdomen with a stinger, a fuzzy thorax, a big-eyed head,
## translucent buzzing wings. In WARN it shows a target marker on Perleta; in DIVE it leaves a motion trail; in RECOVER it is dizzy.
## It reads the sim's PlatformBoss (pos, vel, state, target, facing) and keeps no game state of its own.
class_name PlatformBossView
extends Node2D

const TRAIL_LEN: int = 9
const BODY_SCALE: float = 1.3
const YELLOW := "#ffcc2e"
const YELLOW_DARK := "#d99a14"
const BLACK := "#2b2118"
const OUTLINE := "#1a120b"

## Sim boss; null hides the wasp.
var boss: PlatformBoss = null
var t_now: float = 0.0
var prev_pos: Vector2 = Vector2.ZERO
var cur_pos: Vector2 = Vector2.ZERO
## State drawn this frame ("PATROL", "WARN", "DIVE", "RECOVER").
var state: String = "PATROL"
## World position of the target marker.
var target: Vector2 = Vector2.ZERO

var _trail: Array[Vector2] = []
var _angle: float = 0.0
var _facing: float = 1.0
var _art := WaspBossArt.new()


## Records the boss position at the end of a simulation step.
func record(first: bool) -> void:
	if boss == null:
		return
	var p: Vector2 = boss.pos
	prev_pos = p if first else cur_pos
	cur_pos = p


## Places the wasp between the last two steps and redraws.
func present(alpha: float, p_t_now: float, dt: float) -> void:
	visible = boss != null
	if boss == null:
		return
	t_now = p_t_now
	var p: Vector2 = prev_pos.lerp(cur_pos, alpha)
	if prev_pos.distance_to(cur_pos) > 200.0:
		p = cur_pos
	position = p
	if boss.state != state:
		state = boss.state
		if state != "DIVE":
			_trail.clear()
	target = boss.target
	var vel: Vector2 = boss.vel
	_facing = float(boss.facing)
	# lean into the movement; in a dive the whole body points along the velocity
	var want: float = clampf(vel.x * _facing / 700.0, -0.4, 0.4) * 0.35
	if state == "DIVE" and vel.length() > 60.0:
		if absf(vel.x) > 20.0:
			_facing = signf(vel.x)
		want = (Vector2(vel.x * _facing, vel.y)).angle()
	elif state == "WARN":
		want = 0.25 + sin(t_now * 40.0) * 0.03
	elif state == "RECOVER":
		want = -0.18 + sin(t_now * 3.0) * 0.1
	_angle += (want - _angle) * (1.0 - exp(-dt * 14.0))
	if state == "DIVE":
		_trail.append(p)
		while _trail.size() > TRAIL_LEN:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()
	queue_redraw()


func _draw() -> void:
	if boss == null:
		return
	if state == "WARN":
		_draw_marker()
	_draw_trail()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bob: float = sin(t_now * 7.0) * (3.0 if state != "RECOVER" else 6.0)
	var shake := Vector2.ZERO
	if state == "WARN":
		shake = Vector2(sin(t_now * 90.0), cos(t_now * 77.0)) * 1.6
	_draw_wasp(Vector2(0.0, bob) + shake, _angle, _facing, BODY_SCALE, 1.0)
	if state == "RECOVER":
		_draw_dizzy(Vector2(_facing * 28.0, -14.0 + bob))


# ---------------------------------------------------------------- the wasp

## One wasp, local x forward, centred on the thorax. `alpha` fades ghost copies of the trail.
func _draw_wasp(c: Vector2, ang: float, facing: float, scale_k: float, alpha: float) -> void:
	var curl: float = 0.0
	match state:
		"WARN":
			curl = 0.75
		"DIVE":
			curl = 0.1
		"RECOVER":
			curl = -0.25
		_:
			curl = 0.3 + sin(t_now * 4.0) * 0.1
	if _art.available():
		_art.draw(self, c, ang, facing, scale_k, state, t_now)
		return
	var a := Color(1.0, 1.0, 1.0, alpha)
	draw_set_transform(c, ang * facing, Vector2(facing * scale_k, scale_k))
	_wings(a)
	_legs(a)
	_abdomen(curl, a)
	_thorax(a)
	_head(a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _wings(a: Color) -> void:
	var flap_speed: float = 60.0 if state != "RECOVER" else 18.0
	var base := Vector2(-2.0, -9.0)
	for k in 3:
		var ph: float = t_now * flap_speed + float(k) * 1.1
		var swing: float = sin(ph) * (0.55 if state != "RECOVER" else 0.3)
		var ghost: float = 1.0 if k == 0 else 0.5
		var col := Color(0.88, 0.95, 1.0, 0.45 * ghost * a.a)
		var rot: float = -1.15 + swing
		ViewUtil.fill_ellipse(self, base + Vector2(cos(rot), sin(rot)) * 15.0 - Vector2(8.0, 0.0), 25.0, 9.0, col, rot - 0.35)
		ViewUtil.fill_ellipse(self, base + Vector2(cos(rot - 0.3), sin(rot - 0.3)) * 10.0 - Vector2(4.0, 0.0), 14.0, 5.0, Color(col, col.a * 0.85), rot - 0.6)
		if k == 0:
			ViewUtil.stroke_ellipse(self, base + Vector2(cos(rot), sin(rot)) * 15.0 - Vector2(8.0, 0.0), 25.0, 9.0, Color(0.7, 0.85, 1.0, 0.8 * a.a), 1.2, rot - 0.35)


func _legs(a: Color) -> void:
	var col := Color(ViewColors.h(OUTLINE), a.a)
	for k in 3:
		var x: float = -3.0 + float(k) * 6.0
		var dangle: float = sin(t_now * 9.0 + float(k)) * 1.5
		draw_polyline(PackedVector2Array([Vector2(x, 7.0), Vector2(x + 3.0, 14.0 + dangle), Vector2(x + 1.0, 20.0 + dangle)]), col, 1.5, true)


func _abdomen(curl: float, a: Color) -> void:
	var yellow: Color = ViewColors.h(YELLOW)
	var yellow_dark: Color = ViewColors.h(YELLOW_DARK)
	var black: Color = ViewColors.h(BLACK)
	var outline: Color = ViewColors.h(OUTLINE)
	var seg: int = 5
	var p := Vector2(-9.0, 2.0)
	var dir_a: float = PI - 0.15
	var tip := p
	for k in seg:
		var rad: float = 11.0 - float(k) * 1.6
		var step: float = rad * 1.25
		dir_a -= curl * 0.35
		p += Vector2(cos(dir_a), sin(dir_a)) * step
		var stripe: bool = k % 2 == 1
		var col: Color = black if stripe else yellow
		col.a = a.a
		ViewUtil.fill_ellipse(self, p, rad * 1.05, rad * 0.9, col, dir_a)
		ViewUtil.stroke_ellipse(self, p, rad * 1.05, rad * 0.9, Color(outline, a.a), 1.4, dir_a)
		if not stripe:
			ViewUtil.fill_ellipse(self, p + Vector2(-1.0, -rad * 0.35), rad * 0.55, rad * 0.25, Color(1.0, 0.97, 0.7, 0.55 * a.a), dir_a)
			ViewUtil.fill_ellipse(self, p + Vector2(0.0, rad * 0.5), rad * 0.8, rad * 0.25, Color(yellow_dark, 0.5 * a.a), dir_a)
		tip = p
	# stinger: a dark thorn from the tip, glowing red while it aims
	var sdir := Vector2(cos(dir_a), sin(dir_a))
	var s0: Vector2 = tip + sdir * 5.0
	var s1: Vector2 = s0 + sdir * 14.0 + Vector2(0.0, 2.0 + curl * 4.0)
	var norm := Vector2(-sdir.y, sdir.x)
	draw_colored_polygon(PackedVector2Array([s0 + norm * 2.6, s1, s0 - norm * 2.6]), Color(outline, a.a))
	if state == "WARN":
		draw_circle(s1, 3.5 + sin(t_now * 30.0) * 1.0, Color(1.0, 0.25, 0.2, 0.55 * a.a))


func _thorax(a: Color) -> void:
	var black: Color = ViewColors.h(BLACK)
	black.a = a.a
	ViewUtil.fill_ellipse(self, Vector2(0.0, 0.0), 11.5, 10.5, black)
	ViewUtil.stroke_ellipse(self, Vector2(0.0, 0.0), 11.5, 10.5, Color(ViewColors.h(OUTLINE), a.a), 1.4)
	# fuzzy yellow collar
	for k in 7:
		var u: float = float(k) / 6.0
		var fy: float = lerpf(-8.5, 8.0, u)
		draw_line(Vector2(9.5, fy * 0.8), Vector2(12.5 + sin(float(k) * 2.0), fy * 0.8 - 1.0), Color(ViewColors.h(YELLOW), 0.9 * a.a), 1.6, true)
	ViewUtil.fill_ellipse(self, Vector2(-2.0, -5.0), 5.0, 2.2, Color(1.0, 1.0, 1.0, 0.18 * a.a))


func _head(a: Color) -> void:
	var hc := Vector2(17.0, 1.0)
	var yellow: Color = ViewColors.h(YELLOW)
	yellow.a = a.a
	var outline := Color(ViewColors.h(OUTLINE), a.a)
	# antennae
	var wob: float = sin(t_now * 6.0) * 2.0
	draw_polyline(PackedVector2Array([hc + Vector2(4.0, -8.0), hc + Vector2(10.0, -17.0 + wob), hc + Vector2(17.0, -17.0 + wob * 1.5)]), outline, 1.6, true)
	draw_polyline(PackedVector2Array([hc + Vector2(1.0, -9.0), hc + Vector2(5.0, -19.0 - wob), hc + Vector2(11.0, -21.0 - wob)]), outline, 1.6, true)
	ViewUtil.fill_ellipse(self, hc, 11.0, 10.0, yellow)
	ViewUtil.stroke_ellipse(self, hc, 11.0, 10.0, outline, 1.5)
	# two big shiny eyes; looking down at the target during the warning
	var look := Vector2(1.0, 0.0)
	if state == "WARN":
		look = Vector2(1.2, 1.4)
	elif state == "DIVE":
		look = Vector2(1.6, 1.0)
	for ey: float in [-3.6, 4.2]:
		var ec: Vector2 = hc + Vector2(3.2 + (0.0 if ey < 0.0 else -1.4), ey)
		ViewUtil.fill_ellipse(self, ec, 4.6, 5.2, Color(1.0, 1.0, 1.0, a.a))
		ViewUtil.stroke_ellipse(self, ec, 4.6, 5.2, outline, 1.1)
		if state == "RECOVER":
			_spiral(ec, 3.6, a)
		else:
			var pc: Vector2 = ec + look * 1.1
			var pupil := Color(0.1, 0.07, 0.05, a.a)
			if state == "WARN":
				pupil = Color(0.75, 0.08, 0.08, a.a)
			draw_circle(pc, 2.6, pupil)
			draw_circle(pc + Vector2(-0.8, -1.1), 0.9, Color(1.0, 1.0, 1.0, a.a))
	# slanted brows: cute, but meaning it
	if state == "WARN" or state == "DIVE":
		draw_line(hc + Vector2(-1.0, -11.0), hc + Vector2(9.0, -6.5), outline, 2.0, true)
	# mandible and a little smile
	draw_polyline(PackedVector2Array([hc + Vector2(8.0, 6.0), hc + Vector2(12.0, 8.5), hc + Vector2(10.5, 4.0)]), outline, 1.4, true)
	if state == "RECOVER":
		draw_arc(hc + Vector2(6.0, 7.5), 3.0, PI + 0.4, TAU - 0.4, 6, outline, 1.2, true)


func _spiral(c: Vector2, r: float, a: Color) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var u: float = float(k) / 13.0
		var an: float = u * TAU * 1.6 + t_now * 8.0
		pts.append(c + Vector2(cos(an), sin(an)) * r * u)
	draw_polyline(pts, Color(0.1, 0.07, 0.05, a.a), 1.2, true)


# ---------------------------------------------------------------- effects

func _draw_dizzy(c: Vector2) -> void:
	for k in 3:
		var an: float = t_now * 4.0 + float(k) * TAU / 3.0
		var sp := c + Vector2(cos(an) * 26.0, sin(an) * 8.0 - 14.0)
		var sz: float = 7.0 + sin(an) * 1.5
		var pts := PackedVector2Array()
		for j in 10:
			var aa: float = -PI / 2.0 + float(j) * PI / 5.0
			var rr: float = sz if j % 2 == 0 else sz * 0.45
			pts.append(sp + Vector2(cos(aa), sin(aa)) * rr)
		draw_colored_polygon(pts, Color(1.0, 0.9, 0.3, 0.95))
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, Color(0.7, 0.45, 0.05, 0.9), 1.0, true)


func _draw_trail() -> void:
	var n: int = _trail.size()
	if n < 2:
		return
	for k in n - 1:
		var u: float = float(k) / float(n - 1)
		var a: Vector2 = _trail[k] - position
		var b: Vector2 = _trail[k + 1] - position
		draw_line(a, b, Color(1.0, 0.85, 0.3, 0.12 + 0.3 * u), 4.0 + 20.0 * u, true)
		draw_line(a, b, Color(1.0, 1.0, 0.85, 0.15 + 0.35 * u), 1.5 + 4.0 * u, true)
	# a few speed lines peeling off the trail
	for k in 5:
		var idx: int = clampi(int(float(k) / 4.0 * float(n - 2)), 0, n - 2)
		var off := Vector2(sin(float(k) * 2.4), cos(float(k) * 1.7)) * 16.0
		var q: Vector2 = _trail[idx] - position + off
		draw_line(q, q + (_trail[idx] - _trail[idx + 1]).normalized() * 18.0, Color(1.0, 1.0, 1.0, 0.45), 1.3, true)


## Target marker on the ground spot the wasp picked: a ring that closes in during the warning, a cross, and a dashed line from the wasp.
func _draw_marker() -> void:
	var k: float = clampf(1.0 - boss.timer / maxf(boss.warn_time, 0.01), 0.0, 1.0)
	var c: Vector2 = target - position
	var pulse: float = 0.5 + 0.5 * sin(t_now * 22.0)
	var red := Color(1.0, 0.25, 0.2, 0.55 + 0.3 * pulse)
	var r: float = lerpf(60.0, 20.0, k)
	ViewUtil.dashed(self, PackedVector2Array([Vector2.ZERO, c]), 8.0, 7.0, Color(1.0, 0.3, 0.2, 0.35), 2.0)
	draw_arc(c, r, 0.0, TAU, 40, red, 3.0, true)
	draw_arc(c, 20.0, 0.0, TAU, 28, Color(1.0, 0.25, 0.2, 0.9), 2.0, true)
	for q in 4:
		var an: float = float(q) * PI * 0.5 + PI * 0.25
		var d := Vector2(cos(an), sin(an))
		draw_line(c + d * 12.0, c + d * 30.0, red, 2.5, true)
	draw_circle(c, 3.0, Color(1.0, 0.3, 0.2, 0.9))
	ViewUtil.text(self, "!", c + Vector2(0.0, -r - 8.0), 22, Color(1.0, 0.85, 0.3, 0.9))

## The bat boss of the moth stage: the procedural bat (platform_bat_art.gd), the expanding echolocation rings, the mark warning on the
## moth (a closing ring and a "!") and the swoop trail. Reads the sim's PlatformBat and the pulses of PlatformFly; keeps no game state.
class_name PlatformBatView
extends Node2D

## Registry ids this view draws through (checked by the registry test).
const ART_KINDS: Array[String] = ["platform:bat"]

var _actx := ArtContext.new()

const TRAIL_LEN: int = 9

## Sim bat (PlatformBat); null hides it.
var boss: Variant = null
## Sim pulses (Array of PlatformRing: pos, radius, max_radius, fade()).
var pulses: Array = []
var t_now: float = 0.0
var prev_pos: Vector2 = Vector2.ZERO
var cur_pos: Vector2 = Vector2.ZERO
var state: String = "PATROL"
var target: Vector2 = Vector2.ZERO
## World position of the moth (the rings show where they pass over her).
var player_pos: Vector2 = Vector2.ZERO
var player_hidden: bool = false

var _trail: Array[Vector2] = []
var _angle: float = 0.0
var _facing: float = 1.0
var _state_t: float = 0.0


## Records the bat position at the end of a simulation step.
func record(first: bool) -> void:
	if boss == null:
		return
	var p: Vector2 = ViewUtil.g(boss, "pos", Vector2.ZERO)
	prev_pos = p if first else cur_pos
	cur_pos = p


## Places the bat between the last two steps and redraws.
func present(alpha: float, p_t_now: float, dt: float) -> void:
	visible = boss != null
	if boss == null:
		return
	t_now = p_t_now
	_state_t += dt
	var p: Vector2 = prev_pos.lerp(cur_pos, alpha)
	if prev_pos.distance_to(cur_pos) > 200.0:
		p = cur_pos
	position = p
	var st: String = ViewUtil.gs(boss, "state", "PATROL")
	if st != state:
		state = st
		_state_t = 0.0
		if state != "SWOOP":
			_trail.clear()
	target = ViewUtil.g(boss, "target", Vector2.ZERO)
	var vel: Vector2 = ViewUtil.g(boss, "vel", Vector2.ZERO)
	_facing = float(ViewUtil.gi(boss, "facing", 1))
	var want: float = clampf(vel.x * _facing / 500.0, -0.3, 0.3)
	if state == "SWOOP" and vel.length() > 60.0:
		if absf(vel.x) > 20.0:
			_facing = signf(vel.x)
		want = Vector2(vel.x * _facing, vel.y).angle() * 0.8
	elif state == "MARK":
		want = 0.2
	_angle += (want - _angle) * (1.0 - exp(-dt * 12.0))
	if state == "SWOOP":
		_trail.append(p)
		while _trail.size() > TRAIL_LEN:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()
	queue_redraw()


func _draw() -> void:
	for pr in pulses:
		_draw_pulse(pr)
	if boss == null:
		return
	if state == "MARK":
		_draw_marker()
	_draw_trail()
	var bob: float = sin(t_now * 5.0) * (4.0 if state == "PATROL" else 1.0)
	var shake := Vector2.ZERO
	if state == "MARK":
		shake = Vector2(sin(t_now * 90.0), cos(t_now * 77.0)) * 1.8
	var o := {"base": Transform2D(0.0, Vector2(_facing, 1.0), 0.0, Vector2(0.0, bob) + shake), "state": state, "scale": ViewUtil.gf(boss, "radius", 18.0) / 9.0, "angle": _angle,
		"open": 1.0 if state == "PATROL" and ViewUtil.gf(boss, "pulse_in", 9.0) < 0.35 else 0.0}
	if state == "PATROL" and ViewUtil.gf(boss, "pulse_in", 9.0) < 0.35:
		o["state"] = "PULSE"
	_actx.t = t_now
	ArtRegistry.draw("platform:bat", self, o, _actx)


## An echolocation pulse: thin pale rings that fade as they grow. A bright band shows the front, a second ring follows it.
func _draw_pulse(pr: Variant) -> void:
	var c: Vector2 = ViewUtil.g(pr, "pos", Vector2.ZERO) - position if boss != null else ViewUtil.g(pr, "pos", Vector2.ZERO)
	var r: float = ViewUtil.gf(pr, "radius")
	var maxr: float = maxf(ViewUtil.gf(pr, "max_radius", 600.0), 1.0)
	var a: float = clampf(1.0 - r / maxr, 0.0, 1.0)
	if r < 3.0:
		return
	var tint := Color(0.72, 0.85, 1.0)
	draw_arc(c, r, 0.0, TAU, 96, Color(tint, 0.10 * a + 0.05), 14.0, true)
	draw_arc(c, r, 0.0, TAU, 96, Color(tint, 0.55 * a + 0.12), 2.4, true)
	draw_arc(c, maxf(r - 26.0, 1.0), 0.0, TAU, 96, Color(tint, 0.25 * a), 1.5, true)
	draw_arc(c, maxf(r - 52.0, 1.0), 0.0, TAU, 96, Color(tint, 0.12 * a), 1.2, true)


## The mark: a ring closing on the moth (she is found) and a "!".
func _draw_marker() -> void:
	var warn: float = maxf(ViewUtil.gf(boss, "warn_time", 0.7), 0.01)
	var k: float = clampf(1.0 - ViewUtil.gf(boss, "timer") / warn, 0.0, 1.0)
	var c: Vector2 = target - position
	var pulse: float = 0.5 + 0.5 * sin(t_now * 24.0)
	var col := Color(0.85, 0.4, 1.0, 0.55 + 0.3 * pulse)
	var r: float = lerpf(64.0, 18.0, k)
	ViewUtil.dashed(self, PackedVector2Array([Vector2.ZERO, c]), 8.0, 7.0, Color(0.85, 0.4, 1.0, 0.35), 2.0)
	draw_arc(c, r, 0.0, TAU, 40, col, 3.0, true)
	draw_arc(c, 18.0, 0.0, TAU, 28, Color(1.0, 0.4, 0.5, 0.9), 2.0, true)
	for q in 4:
		var an: float = float(q) * PI * 0.5 + PI * 0.25
		var d := Vector2(cos(an), sin(an))
		draw_line(c + d * 12.0, c + d * 28.0, col, 2.5, true)
	ViewUtil.text(self, "!", c + Vector2(0.0, -r - 8.0), 24, Color(1.0, 0.85, 0.3, 0.95))


func _draw_trail() -> void:
	var n: int = _trail.size()
	if n < 2:
		return
	for k in n - 1:
		var u: float = float(k) / float(n - 1)
		var a: Vector2 = _trail[k] - position
		var b: Vector2 = _trail[k + 1] - position
		draw_line(a, b, Color(0.6, 0.35, 0.85, 0.1 + 0.28 * u), 4.0 + 22.0 * u, true)
		draw_line(a, b, Color(0.9, 0.8, 1.0, 0.12 + 0.3 * u), 1.5 + 4.0 * u, true)

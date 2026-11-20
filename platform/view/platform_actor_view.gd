## One animated character of the platformer: Perleta (the egg art of the combat view) or an ant (the ant art). The node sits at the
## body centre and is scaled so the art fits the physics radius. Positions are interpolated between fixed simulation steps.
class_name PlatformActorView
extends Node2D

## Registry ids this view draws through (checked by the registry test).
const ART_KINDS: Array[String] = ["platform:pupa", "platform:moth", "creature:EGG", "creature:ANT"]

const EGG_FEET: float = 10.5
const ANT_ART_RADIUS: float = 9.0
const ANT_SCALE: float = 1.0

var is_player: bool = false
## Level mode: "" (egg), "DIG" (the player is the pupa) or "FLY" (the player is the moth).
var mode: String = ""
## PlatformDig or PlatformFly of the sim (pupa digging state, moth wing state); null in egg levels.
var extra: Variant = null
## Sim body (PlatformBody or PlatformAnt).
var body: Variant = null
var ctx := ViewCtx.new()
var _actx := ArtContext.new()
var prev_pos: Vector2 = Vector2.ZERO
var cur_pos: Vector2 = Vector2.ZERO
var _walk_view: float = 0.0
var _scale: float = 1.0
var _wiggle: float = 0.0
var _dig_dir: Vector2 = Vector2.ZERO


## Records the body position as the end of a simulation step (`first` also resets the start of the interpolation).
func record(first: bool) -> void:
	var p: Vector2 = ViewUtil.g(body, "pos", cur_pos)
	prev_pos = p if first else cur_pos
	cur_pos = p


## Places the node between the last two steps (`alpha` 0..1) and redraws.
func present(alpha: float, t_now: float, dt: float) -> void:
	ctx.t_now = t_now
	var p: Vector2 = prev_pos.lerp(cur_pos, alpha)
	if prev_pos.distance_to(cur_pos) > 120.0:
		p = cur_pos
	if is_player and mode != "":
		position = p
		_scale = 1.0
		var digging: bool = ViewUtil.gb(extra, "digging") and mode == "DIG"
		_wiggle += ((1.0 if digging else 0.0) - _wiggle) * (1.0 - exp(-dt * 14.0))
		if digging:
			_dig_dir = ViewUtil.g(extra, "dig_dir", Vector2.ZERO)
		else:
			_dig_dir *= exp(-dt * 12.0)
		_walk_view = ViewUtil.gf(body, "walk_cycle")
		scale = Vector2.ONE
	elif is_player:
		var radius: float = ViewUtil.gf(body, "radius", 14.0)
		_scale = radius / EGG_FEET * (1.0 + 0.2 * ViewUtil.gf(body, "growth"))
		position = Vector2(p.x, p.y + radius - EGG_FEET * _scale)
		var vx: float = ViewUtil.g(body, "vel", Vector2.ZERO).x
		var moving: bool = absf(vx) > 12.0 and ViewUtil.gb(body, "on_ground", true)
		var walk: float = ViewUtil.gf(body, "walk_cycle")
		if moving:
			_walk_view = walk
		else:
			# ease the wobble to rest: sin(0.9 w) and sin(1.8 w) vanish at multiples of PI / 0.9
			var rest: float = roundf(_walk_view * 0.9 / PI) * PI / 0.9
			_walk_view += (rest - _walk_view) * (1.0 - exp(-dt * 10.0))
	else:
		var r: float = ViewUtil.gf(body, "radius", ANT_ART_RADIUS)
		_scale = maxf(1.0, r / ANT_ART_RADIUS) * ANT_SCALE
		position = p + Vector2(0.0, r - ANT_ART_RADIUS * _scale)
	if not (is_player and mode != ""):
		scale = Vector2(_scale, _scale)
	queue_redraw()


## The art context of this frame (clock and ViewCtx of this view).
func _art_ctx() -> ArtContext:
	_actx.refresh(ctx)
	return _actx


func _draw() -> void:
	if body == null:
		return
	if is_player and mode == "DIG":
		_draw_pupa()
	elif is_player and mode == "FLY":
		_draw_moth()
	elif is_player:
		_draw_player()
	else:
		_draw_ant()


func _draw_pupa() -> void:
	var invuln: float = ViewUtil.gf(body, "invuln")
	if invuln > 0.0 and int(ctx.t_now * 16.0) % 2 == 0:
		return
	var rad: float = ViewUtil.gf(body, "radius", 12.0)
	var sq: Vector2 = ViewUtil.g(body, "squash", Vector2.ONE)
	ArtRegistry.draw("platform:pupa", self, {"r": rad, "o": {
		"base": Transform2D(0.0, sq, 0.0, Vector2(0.0, rad * (1.0 - sq.y))),
		"facing": ViewUtil.gf(body, "facing", 1.0), "dig": _dig_dir, "wiggle": _wiggle,
		"vel": ViewUtil.g(body, "vel", Vector2.ZERO), "hurt": clampf((invuln - 0.8) * 2.5, 0.0, 1.0),
	}}, _art_ctx())


func _draw_moth() -> void:
	var invuln: float = ViewUtil.gf(body, "invuln")
	if invuln > 0.0 and int(ctx.t_now * 16.0) % 2 == 0:
		return
	var rad: float = ViewUtil.gf(body, "radius", 12.0)
	var age: float = ViewUtil.gf(extra, "flap_age", 9.0)
	var grounded: bool = ViewUtil.gb(body, "on_ground")
	var flap: float = -9.0
	if age < 0.26:
		flap = -cos(TAU * age / 0.26)
	elif grounded:
		flap = 0.55
	else:
		flap = -0.15 + sin(ctx.t_now * 13.0) * 0.28
	var hid: bool = ViewUtil.gb(body, "hidden")
	var sq: Vector2 = ViewUtil.g(body, "squash", Vector2.ONE)
	ArtRegistry.draw("platform:moth", self, {"r": rad, "o": {
		"base": Transform2D(0.0, sq, 0.0, Vector2.ZERO),
		"facing": ViewUtil.gf(body, "facing", 1.0), "flap": flap, "glide": ViewUtil.gb(extra, "gliding"),
		"stun": ViewUtil.gf(extra, "stun"), "vel": ViewUtil.g(body, "vel", Vector2.ZERO),
		"hurt": clampf((invuln - 0.8) * 2.5, 0.0, 1.0), "glow": 0.0 if hid else 1.0,
	}}, _art_ctx())
	if hid:
		draw_circle(Vector2.ZERO, rad * 1.6, Color(0.0, 0.0, 0.05, 0.28))


func _draw_player() -> void:
	var invuln: float = ViewUtil.gf(body, "invuln")
	if invuln > 0.0 and int(ctx.t_now * 16.0) % 2 == 0:
		return
	var sq: Vector2 = ViewUtil.g(body, "squash", Vector2.ONE)
	var vel: Vector2 = ViewUtil.g(body, "vel", Vector2.ZERO)
	var art := {
		"x": 0.0, "y": 0.0, "r": 11.0,
		"walk_cycle": _walk_view,
		"facing": ViewUtil.gf(body, "facing", 1.0),
		"squash_x": sq.x, "squash_y": sq.y,
		"hurt_timer": clampf((invuln - 0.8) * 2.5, 0.0, 1.0),
		"vx": vel.x, "grounded": ViewUtil.gb(body, "on_ground", true),
		"id": 0,
	}
	var is_hidden: bool = ViewUtil.gb(body, "hidden")
	art["alpha"] = 0.5 if is_hidden else 1.0
	ArtRegistry.draw("creature:EGG", self, art, _art_ctx())


func _draw_ant() -> void:
	if ViewUtil.gb(body, "gone"):
		return
	var ko: bool = ViewUtil.gb(body, "knocked")
	if ko:
		# Stomped: flatten onto the ground, then fade out.
		var age: float = ViewUtil.gf(body, "ko_age")
		var sq: float = lerpf(1.0, 0.22, clampf(age / 0.12, 0.0, 1.0))
		modulate.a = clampf((PlatformSim.KO_TIME - age) / 0.2, 0.0, 1.0)
		draw_set_transform_matrix(Transform2D(0.0, Vector2(1.0 + (1.0 - sq) * 0.6, sq), 0.0, Vector2(0.0, ANT_ART_RADIUS * (1.0 - sq))))
	var bite: Variant = ViewUtil.g(body, "bite", 0.0)
	var bite_f: float = (1.0 if bool(bite) else 0.0) if bite is bool else float(bite)
	var vel: Vector2 = ViewUtil.g(body, "vel", Vector2.ZERO)
	var art := {
		"x": 0.0, "y": 0.0, "r": ANT_ART_RADIUS,
		"walk_cycle": ViewUtil.gf(body, "walk_cycle"),
		"facing": ViewUtil.gf(body, "facing", -1.0),
		"bat_swing_timer": bite_f * 0.48,
		"grounded": absf(vel.y) < 60.0,
		"id": int(prev_pos.x) % 7,
	}
	ArtRegistry.draw("creature:ANT", self, art, _art_ctx())
	if ko:
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var state: String = ViewUtil.gs(body, "state", "PATROL")
	if state == "CHASE" or state == "LOST":
		var mark: String = "!" if state == "CHASE" else "?"
		var col: Color = ViewColors.h("#ff4a3a") if state == "CHASE" else ViewColors.h("#ffd04a")
		var lift: float = sin(ctx.t_now * 9.0) * 1.5
		draw_set_transform_matrix(Transform2D(0.0, Vector2(1.0 / _scale, 1.0 / _scale), 0.0, Vector2(0.0, -17.0 * _scale + lift)))
		ViewUtil.text(self, mark, Vector2(0.0, 0.0), 22, Color(0, 0, 0, 0.55))
		ViewUtil.text(self, mark, Vector2(0.0, -1.5), 22, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)

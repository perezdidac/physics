## Decoration of the anthill of the WAVES levels. The mound itself is terrain (a solid dome stamped by the sim); this draws what sits on it:
## the dark entrance hole with a lip of loose earth, pebbles, two tiny ants trotting over the dome and a puff of dust when a wave comes out.
## `top` is the top of the mound (the hole).
class_name AnthillArt
extends RefCounted

## Half width and height of the dome (TerrainSim.ANTHILL_HALF / ANTHILL_H).
const HALF: float = 36.0
const HEIGHT: float = 24.0
## Seconds the dust puff lasts after a wave spawns.
const DUST_TIME: float = 1.5


## Height of the dome surface below the top at horizontal offset `dx`.
static func drop(dx: float) -> float:
	return HEIGHT * (1.0 - cos(clampf(dx / HALF, -1.0, 1.0) * PI * 0.5))


## `entrance` is the sprite of the lip and hole (assets/sprites/scene/anthill.svg); without it they are drawn in code.
static func draw(ci: CanvasItem, top: Vector2, t: float, dust_age: float, entrance: Texture2D = null) -> void:
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, 0.0, top))
	var soil_light: Color = ViewColors.h("#c08a56")
	var soil_dark: Color = ViewColors.h("#4a2c18")
	if entrance != null:
		ci.draw_texture_rect(entrance, Rect2(Vector2(-16.0, -16.0), Vector2(32.0, 32.0)), false)
	else:
		# lip of loose earth round the hole, then the hole
		ViewUtil.fill_ellipse(ci, Vector2(0.0, 1.0), 13.5, 5.0, soil_light)
		ViewUtil.stroke_ellipse(ci, Vector2(0.0, 1.0), 13.5, 5.0, soil_dark, 1.4)
		ViewUtil.fill_ellipse(ci, Vector2(0.0, 1.6), 9.0, 3.6, ViewColors.h("#1d0f08"))
		ViewUtil.fill_ellipse(ci, Vector2(0.5, 2.4), 6.0, 2.0, ViewColors.h("#0a0503"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(top.x) + 3
	for i in 9:
		var gx: float = rng.randf_range(-HALF * 0.7, HALF * 0.7)
		ci.draw_circle(Vector2(gx, drop(gx) + rng.randf_range(2.0, 5.0)), rng.randf_range(0.8, 1.6), soil_dark if i % 2 == 0 else soil_light)
	for px: float in ([-HALF - 3.0, HALF * 0.55] if entrance == null else [-HALF - 3.0]):
		ViewUtil.ellipse_fs(ci, Vector2(px, drop(px) + 1.5), 3.0, 2.0, ViewColors.h("#a79e8c"), ViewColors.h("#58524a"), 1.0)
	# two tiny ants walking over the dome
	for k in 2:
		var ph: float = fmod(t * 0.12 + float(k) * 0.5, 1.0)
		var dir: float = 1.0 if k == 0 else -1.0
		var ax: float = lerpf(-HALF * 0.8, HALF * 0.8, ph) * dir
		_tiny_ant(ci, Vector2(ax, drop(ax) - 1.2), dir, t * 14.0 + float(k))
	if dust_age >= 0.0 and dust_age < DUST_TIME:
		_dust(ci, dust_age / DUST_TIME)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _tiny_ant(ci: CanvasItem, p: Vector2, dir: float, walk: float) -> void:
	var col: Color = ViewColors.h("#4a1d10")
	ci.draw_circle(p + Vector2(-3.0 * dir, 0.0), 1.9, col)
	ci.draw_circle(p + Vector2(-0.4 * dir, -0.2), 1.4, col)
	ci.draw_circle(p + Vector2(2.0 * dir, -0.4), 1.5, col)
	for i in 3:
		var x: float = (-1.4 + float(i) * 1.4) * dir
		var sw: float = sin(walk + float(i) * 2.1) * 1.0
		ci.draw_line(p + Vector2(x, 0.4), p + Vector2(x + sw, 2.2), col, 0.8, true)


## Brown puffs rising from the hole and fading.
static func _dust(ci: CanvasItem, u: float) -> void:
	for i in 9:
		var a: float = -PI * 0.5 + (float(i) - 4.0) * 0.32
		var d: float = (6.0 + float(i % 3) * 5.0) + u * (18.0 + float(i % 4) * 7.0)
		var p := Vector2(cos(a) * d * 1.3, 0.0 + sin(a) * d)
		var rad: float = 3.0 + u * (7.0 + float(i % 3) * 2.0)
		ci.draw_circle(p, rad, Color(0.86, 0.7, 0.5, (1.0 - u) * 0.8))

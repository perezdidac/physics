## Pine-needle tufts: the hiding spots of the story mode (a fan of thin green and olive needles) and the few needles drawn in front of a hidden fighter.
class_name TuftArt
extends RefCounted

const NEEDLE_COLORS: Array[String] = ["#5f8a3a", "#7ba246", "#4a7430", "#8aa94f", "#a0a65a", "#6f5a2e"]


## The tuft whose base sits at `ground` (world point on the surface).
static func draw(ci: CanvasItem, ground: Vector2, t: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ground.x * 7.0) + 11
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, 0.0, ground))
	ViewUtil.fill_ellipse(ci, Vector2(0, 1.0), 20.0, 3.4, Color(0.05, 0.08, 0.03, 0.34))
	var n: int = 20
	for i in n:
		var u: float = (float(i) + rng.randf() * 0.7) / float(n - 1)
		var ang: float = -PI * 0.5 + (u - 0.5) * 2.3
		var needle_len: float = (17.0 + rng.randf() * 11.0) * (1.0 - absf(u - 0.5) * 0.55)
		var sway: float = sin(t * 1.3 + float(i) * 0.9 + ground.x) * 0.9
		var base := Vector2((u - 0.5) * 7.0, 0.5)
		var tip := base + Vector2(cos(ang), sin(ang)) * needle_len + Vector2(sway, 0.0)
		var mid := base + Vector2(cos(ang), sin(ang)) * needle_len * 0.55 + Vector2(0.0, -2.0)
		var col: Color = ViewColors.h(NEEDLE_COLORS[rng.randi() % NEEDLE_COLORS.size()])
		ci.draw_polyline(ViewUtil.quad_pts(base, mid, tip, 6), col, 1.25, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## A few short needles in front of a hidden fighter standing at `ground`.
static func draw_front(ci: CanvasItem, ground: Vector2, t: float, seed_id: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_id * 31 + 5
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, 0.0, ground))
	for i in 7:
		var x: float = -9.0 + float(i) * 3.0 + rng.randf() * 1.5
		var ang: float = -PI * 0.5 + (x / 9.0) * 0.55 + (rng.randf() - 0.5) * 0.3
		var needle_len: float = 9.0 + rng.randf() * 6.0
		var tip := Vector2(x, 1.0) + Vector2(cos(ang), sin(ang)) * needle_len + Vector2(sin(t * 1.4 + float(i)) * 0.5, 0.0)
		ci.draw_line(Vector2(x, 1.0), tip, ViewColors.h(NEEDLE_COLORS[rng.randi() % 5]), 1.3, true)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

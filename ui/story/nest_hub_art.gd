## Backdrop of the nest hub: a cosy winter night seen from inside the pines. A deep blue sky with soft snow falling, and the big silk nest
## (the same drawing as in the battle) glowing warm, with the caterpillars curled up inside. Pure decoration; it fills its parent.
class_name NestHubArt
extends Control

var _t: float = 0.0
var _ctx := ViewCtx.new()
var _fx := NestFx.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctx.cold_active = true
	_ctx.nest_destroyed = false
	_ctx.nest_frac = 1.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var vs: Vector2 = size
	var sky := PackedColorArray([Color("#101a3a"), Color("#101a3a"), Color("#2a2f55"), Color("#2a2f55")])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]), sky)
	# the nest, sitting low on the left third (or behind the panel on a narrow screen)
	var k: float = clampf(minf(vs.x * 0.34, vs.y * 0.8) / 170.0, 0.8, 2.6)
	var c := Vector2(vs.x * (0.22 if vs.x > 820.0 else 0.5), vs.y * 0.62)
	ViewUtil.radial(self, c, 10.0, 260.0 * k, [[0.0, Color(1.0, 0.72, 0.35, 0.55)], [0.5, Color(1.0, 0.55, 0.2, 0.2)], [1.0, Color(1.0, 0.5, 0.2, 0.0)]], 0.8 + 0.2 * sin(_t * 1.7), "nest_hub_glow")
	var size_px := Vector2(170.0, 110.0)
	_ctx.t_now = _t
	_ctx.nest = {"hp": 300, "max_hp": 300}
	_ctx.nest_rect = Rect2(Vector2.ZERO - size_px * 0.5, size_px)
	draw_set_transform_matrix(Transform2D(0.0, Vector2(k, k), 0.0, c))
	NestArt.draw_back(self, _ctx, _fx)
	NestArt.draw_front(self, _ctx)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var ground := Rect2(0.0, c.y + 55.0 * k, vs.x, vs.y - (c.y + 55.0 * k))
	draw_rect(ground, Color("#d7e3f2"))
	draw_rect(Rect2(ground.position, Vector2(vs.x, 4.0)), Color(1, 1, 1, 0.7))
	_draw_snow(vs)


func _draw_snow(vs: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 60:
		var x0: float = rng.randf()
		var y0: float = rng.randf()
		var sp: float = rng.randf_range(0.03, 0.09)
		var sz: float = rng.randf_range(1.2, 3.4)
		var ph: float = rng.randf_range(0.0, TAU)
		var p := Vector2(fposmod(x0 + sin(_t * 0.5 + ph) * 0.02, 1.0) * vs.x, fposmod(y0 + _t * sp, 1.0) * vs.y)
		draw_circle(p, sz, Color(1, 1, 1, 0.55 + 0.3 * sin(_t + ph)))

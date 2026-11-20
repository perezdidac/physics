## Draws the static and animated parts of a platformer level, procedurally: earth and bark blocks, slopes, one-way platforms as
## giant pine needles, needle tufts, sap-drop nutrients, checkpoints and the sunny goal. Actors and effects are sibling nodes.
class_name PlatformWorldView
extends Node2D

var sim: PlatformSim = null
var layout: PlatformLayout = null
var t_now: float = 0.0
## Level mode: "" (egg), "DIG" (only sap and checkpoints are drawn here: the soil is the dig view's) or "FLY" (night: the goal is moonlight).
var mode: String = ""
## Night darkness 0..1 over the ground, slopes and needles (sap, flags and the goal stay bright).
var night: float = 0.0
## World rectangle on screen; things outside are skipped.
var view_rect: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)

## Registry ids this view draws through (checked by the registry test).
const ART_KINDS: Array[String] = ["platform:puddle", "platform:goal", "platform:tuft", "platform:needle", "platform:checkpoint", "platform:nutrient"]

var _actx := ArtContext.new()

const EARTH := "#6b4a2f"
const EARTH_DARK := "#44301e"
const EARTH_LIGHT := "#8a6540"
const LITTER := "#a58a4e"
const MOSS := "#7d8f3f"
const SPECK_COLORS: Array[String] = ["#4e3622", "#8f6c44", "#3a2a1a", "#b09460", "#5c4a2b"]

## Per solid: PackedVector2Array of speck positions (world) and PackedFloat32Array of sizes.
var _specks: Array[PackedVector2Array] = []
var _speck_sizes: Array[PackedFloat32Array] = []


## Binds the level and prepares the texture details of the solid blocks.
func setup(p_sim: PlatformSim, p_layout: PlatformLayout) -> void:
	sim = p_sim
	layout = p_layout
	_specks.clear()
	_speck_sizes.clear()
	for i in layout.solids.size():
		var r: Rect2 = layout.solids[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(r.position.x * 13.0 + r.position.y * 7.0) + i
		var n: int = clampi(int(r.get_area() / 420.0), 6, 420)
		var pts := PackedVector2Array()
		var sizes := PackedFloat32Array()
		for k in n:
			pts.append(r.position + Vector2(rng.randf() * r.size.x, 9.0 + rng.randf() * maxf(1.0, r.size.y - 9.0)))
			sizes.append(1.5 + rng.randf() * rng.randf() * 5.5)
		_specks.append(pts)
		_speck_sizes.append(sizes)


func _draw() -> void:
	if layout == null:
		return
	_actx.t = t_now
	_actx.night = night
	var view: Rect2 = view_rect.grow(60.0)
	if mode == "DIG":
		_draw_pickups(view)
		return
	for i in layout.solids.size():
		if layout.solids[i].intersects(view):
			_draw_solid(i)
	for s in layout.slopes:
		if s.size() == 2 and Rect2(minf(s[0].x, s[1].x), minf(s[0].y, s[1].y), absf(s[1].x - s[0].x), absf(s[1].y - s[0].y)).grow(8.0).intersects(view):
			_draw_slope(s)
	for i in layout.puddles.size():
		if layout.puddles[i].grow(20.0).intersects(view):
			ArtRegistry.draw("platform:puddle", self, {"i": i, "rect": layout.puddles[i], "storm": layout.storm}, _actx)
	ArtRegistry.draw("platform:goal", self, {"goal": layout.goal, "view": view, "moonlit": mode == "FLY"}, _actx)
	for i in layout.tufts.size():
		var r: Rect2 = layout.tufts[i]
		if r.grow(30.0).intersects(view):
			var left: float = sim.tuft_flattened[i] if i < sim.tuft_flattened.size() else 0.0
			ArtRegistry.draw("platform:tuft", self, {"rect": r, "left": left, "time": PlatformSim.TUFT_FLATTEN_TIME}, _actx)
	for r in layout.platforms:
		if r.grow(30.0).intersects(view):
			ArtRegistry.draw("platform:needle", self, r, _actx)
	_draw_pickups(view)


## Checkpoint flags and sap drops.
func _draw_pickups(view: Rect2) -> void:
	for i in layout.checkpoints.size():
		if view.has_point(layout.checkpoints[i]):
			ArtRegistry.draw("platform:checkpoint", self, {"i": i, "p": layout.checkpoints[i], "lit": sim.checkpoint_idx >= i}, _actx)
	var taken: Array[bool] = sim.nutrients_taken
	for i in layout.nutrients.size():
		if i < taken.size() and bool(taken[i]):
			continue
		if view.has_point(layout.nutrients[i]):
			ArtRegistry.draw("platform:nutrient", self, {"i": i, "p": layout.nutrients[i]}, _actx)


# ---------------------------------------------------------------- ground

func _draw_solid(i: int) -> void:
	var r: Rect2 = layout.solids[i]
	draw_rect(r, ViewColors.h(EARTH))
	# darker towards the bottom
	var dark: Color = ViewColors.h(EARTH_DARK)
	var bottom := PackedColorArray([Color(dark, 0.0), Color(dark, 0.0), Color(dark, 0.65), Color(dark, 0.65)])
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), bottom)
	var pts: PackedVector2Array = _specks[i]
	var sizes: PackedFloat32Array = _speck_sizes[i]
	var x0: float = view_rect.position.x - 10.0
	var x1: float = view_rect.end.x + 10.0
	for k in pts.size():
		var p: Vector2 = pts[k]
		if p.x < x0 or p.x > x1:
			continue
		var sz: float = sizes[k]
		var col: Color = ViewColors.h(SPECK_COLORS[k % SPECK_COLORS.size()])
		if sz > 4.0:
			ViewUtil.fill_ellipse(self, p, sz, sz * 0.7, col, 0.3 * float(k % 5))
		else:
			draw_rect(Rect2(p, Vector2(sz, sz * 0.7)), Color(col, 0.7))
		if k % 7 == 0:
			draw_line(p, p + Vector2(sz * 4.0, sz * 0.8), Color(ViewColors.h(EARTH_DARK), 0.55), 1.2, true)
	_draw_litter_top(Vector2(maxf(r.position.x, x0), r.position.y), Vector2(minf(r.end.x, x1), r.position.y))
	draw_line(Vector2(r.position.x, r.position.y + 0.5), Vector2(r.end.x, r.position.y + 0.5), ViewColors.h(EARTH_DARK), 1.5)
	for edge_x: float in [r.position.x, r.end.x]:
		draw_line(Vector2(edge_x, r.position.y), Vector2(edge_x, r.end.y), Color(ViewColors.h(EARTH_DARK), 0.6), 2.0)
	if night > 0.0:
		var clip: Rect2 = r.intersection(view_rect.grow(40.0))
		draw_rect(clip, Color(0.03, 0.05, 0.16, 0.62 * night))
		# a thin moonlit rim along the top
		draw_line(Vector2(clip.position.x, r.position.y - 0.5), Vector2(clip.end.x, r.position.y - 0.5), Color(0.7, 0.8, 1.0, 0.35 * night), 1.6)


## A band of pine litter and moss along a top edge from `a` to `b`, with little needles sticking up.
func _draw_litter_top(a: Vector2, b: Vector2) -> void:
	if b.x <= a.x:
		return
	var h: float = 7.0
	var quad := PackedVector2Array([a, b, b + Vector2(0.0, h), a + Vector2(0.0, h)])
	draw_polygon(quad, PackedColorArray([ViewColors.h(MOSS), ViewColors.h(MOSS), ViewColors.h(LITTER), ViewColors.h(LITTER)]))
	var x: float = floorf(a.x / 11.0) * 11.0
	while x < b.x:
		if x >= a.x:
			var yy: float = lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
			var hh: float = 3.0 + fmod(absf(x) * 0.37, 5.0)
			var lean: float = sin(x * 0.7 + t_now * 1.1) * 0.8 + (fmod(absf(x), 3.0) - 1.0)
			draw_line(Vector2(x, yy + 1.0), Vector2(x + lean, yy - hh), ViewColors.h(MOSS if int(x) % 2 == 0 else LITTER), 1.2, true)
		x += 11.0


func _draw_slope(s: PackedVector2Array) -> void:
	var a: Vector2 = s[0]
	var b: Vector2 = s[1]
	var hi: Vector2 = a if a.y < b.y else b
	var lo: Vector2 = b if a.y < b.y else a
	var corner := Vector2(hi.x, lo.y)
	draw_colored_polygon(PackedVector2Array([hi, lo, corner]), ViewColors.h(EARTH))
	draw_colored_polygon(PackedVector2Array([hi, lo, corner]), Color(ViewColors.h(EARTH_DARK), 0.25))
	var dir: Vector2 = (lo - hi).normalized()
	var n := Vector2(dir.y, -dir.x) * -1.0
	if n.y > 0.0:
		n = -n
	var band := PackedVector2Array([hi, lo, lo - n * 7.0, hi - n * 7.0])
	draw_polygon(band, PackedColorArray([ViewColors.h(MOSS), ViewColors.h(MOSS), ViewColors.h(LITTER), ViewColors.h(LITTER)]))
	var steps: int = maxi(2, int(a.distance_to(b) / 12.0))
	for k in steps:
		var p: Vector2 = hi.lerp(lo, (float(k) + 0.5) / float(steps))
		draw_line(p, p + n * (4.0 + fmod(float(k) * 1.7, 3.0)) + Vector2(sin(t_now + float(k)) * 0.6, 0.0), ViewColors.h(MOSS), 1.2, true)
	draw_line(hi, lo, ViewColors.h(EARTH_DARK), 1.5)
	if night > 0.0:
		draw_colored_polygon(PackedVector2Array([hi, lo, corner]), Color(0.03, 0.05, 0.16, 0.62 * night))

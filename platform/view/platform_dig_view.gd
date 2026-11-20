## The DIG-mode world: a soil cross-section. The soil itself is a shader over a mask texture (one texel per cell, updated only in the
## dirty rectangles the sim reports, never redrawn as a whole); this node adds the turf on the surface, rocks, roots, falling stones,
## noise rings and the warm safe chamber. All data is pushed by the screen (it knows the sim); the node keeps no game state.
class_name PlatformDigView
extends Node2D

## Draws the soil rectangle with the shader (a child drawn behind this node).
class SoilLayer extends Node2D:
	var rect: Rect2 = Rect2()

	func _draw() -> void:
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			draw_rect(rect, Color.WHITE)

const ROCK_DARK := "#4b463e"
const ROCK_LIGHT := "#aaa395"

var world_size: Vector2 = Vector2(1024.0, 1024.0)
var cell: float = 4.0
var surface_y: float = 120.0
var goal: Rect2 = Rect2()
## Water surface (world y); a huge value means dry.
var water_y: float = 100000.0
var t_now: float = 0.0
var view_rect: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
## Sim stones (PlatformStone: pos, state, timer, crumble) and noise rings (PlatformRing: pos, radius, fade()).
var stones: Array = []
var rings: Array = []
## Cells rewritten by the last `refresh_cells` call and the number of calls so far (tests check that digging is incremental).
var last_update_cells: int = 0
## Seconds underwater as a fraction of the time that costs a heart (0..1) and where the pupa is (for the breath ring).
var drown: float = 0.0
var player_pos: Vector2 = Vector2.ZERO
var update_calls: int = 0
## Texture uploads so far (at most one per frame, however many sim steps changed cells).
var uploads: int = 0

var _img: Image = null
var _tex: ImageTexture = null
var _cell_value: Callable = Callable()
var _soil := SoilLayer.new()
var _mat := ShaderMaterial.new()
var _grid: Vector2i = Vector2i.ONE
var _pending: bool = false


## Builds the mask texture from `cell_value` (Callable (cx: int, cy: int) -> int: 0 air, 1 soil, 2 rock, 3 root, as PlatformDig.cell_at).
func setup(p_world: Vector2, p_cell: float, p_surface_y: float, cell_value: Callable) -> void:
	world_size = p_world
	cell = maxf(p_cell, 1.0)
	surface_y = p_surface_y
	_cell_value = cell_value
	_grid = Vector2i(maxi(1, ceili(world_size.x / cell)), maxi(1, ceili(world_size.y / cell)))
	_img = Image.create(_grid.x, _grid.y, false, Image.FORMAT_RGB8)
	for y in _grid.y:
		for x in _grid.x:
			_img.set_pixel(x, y, _texel(x, y))
	_tex = ImageTexture.create_from_image(_img)
	var sh := Shader.new()
	sh.code = PlatformSoilShader.CODE
	_mat.shader = sh
	_mat.set_shader_parameter("mask", _tex)
	_mat.set_shader_parameter("world_size", Vector2(_grid.x, _grid.y) * cell)
	_mat.set_shader_parameter("surface_y", surface_y)
	_soil.material = _mat
	_soil.show_behind_parent = true
	if _soil.get_parent() == null:
		add_child(_soil)


func _texel(x: int, y: int) -> Color:
	var v: int = int(_cell_value.call(x, y))
	return Color(1.0 if v == 0 else 0.0, 1.0 if v == 2 else 0.0, 1.0 if v == 3 else 0.0, 1.0)


## Rewrites the texels of the cell rectangle `r` from the sim (only those); the texture is uploaded once, by the next `refresh`.
func refresh_cells(r: Rect2i) -> void:
	if _img == null:
		return
	var c: Rect2i = r.intersection(Rect2i(Vector2i.ZERO, _grid))
	for y in range(c.position.y, c.end.y):
		for x in range(c.position.x, c.end.x):
			_img.set_pixel(x, y, _texel(x, y))
	last_update_cells = c.size.x * c.size.y
	update_calls += 1
	_pending = true


## True when the cell at (cx, cy) is open in the mask texture (for tests).
func mask_open(cx: int, cy: int) -> bool:
	return _img != null and cx >= 0 and cy >= 0 and cx < _grid.x and cy < _grid.y and _img.get_pixel(cx, cy).r > 0.5


## Deterministic jitter in -1..1.
static func _jit(i: int, k: int) -> float:
	return fposmod(sin(float(i * 131 + k * 17) * 12.9898) * 43758.5453, 2.0) - 1.0


## Bumps the shader time and redraws.
func refresh() -> void:
	if _pending:
		_pending = false
		uploads += 1
		_tex.update(_img)
	_mat.set_shader_parameter("time", t_now)
	_mat.set_shader_parameter("water_y", water_y)
	_soil.rect = view_rect.grow(40.0).intersection(Rect2(Vector2.ZERO, world_size))
	_soil.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var view: Rect2 = view_rect.grow(60.0)
	_draw_turf(view)
	if goal.size.x > 0.0 and goal.grow(160.0).intersects(view):
		_draw_chamber()
	for s in stones:
		var st: String = ViewUtil.gs(s, "state", "REST")
		var sp: Vector2 = ViewUtil.g(s, "pos", Vector2.ZERO)
		if st != "GONE" and view.has_point(sp):
			_draw_stone(sp, st, ViewUtil.gf(s, "crumble"), ViewUtil.gf(s, "timer"))
	for rg in rings:
		_draw_ring(rg)
	if drown > 0.02:
		_draw_breath()


## Surface height at `x` (flat: the pupa walks on it).
func surface_at(_x: float) -> float:
	return surface_y


## Grass blades, little flowers and pine needles on the surface.
func _draw_turf(view: Rect2) -> void:
	if view.position.y > surface_y + 30.0 or view.end.y < surface_y - 40.0:
		return
	var x0: float = floorf(maxf(view.position.x, 0.0) / 5.0) * 5.0
	var x1: float = minf(view.end.x, world_size.x)
	var x: float = x0
	while x < x1:
		var h: float = hash_f(x)
		var base: float = surface_at(x)
		var blade: float = 5.0 + h * 9.0
		var sway: float = sin(t_now * 1.6 + x * 0.09) * 2.0
		var col: Color = ViewColors.h("#7aa83c") if h > 0.35 else ViewColors.h("#5d8a2e")
		if h > 0.82:
			col = ViewColors.h("#a3c24f")
		draw_line(Vector2(x, base + 1.0), Vector2(x + sway + (h - 0.5) * 3.0, base - blade), col, 1.6, true)
		x += 5.0
	# a light bright edge and a darker mat right under it
	var pts := PackedVector2Array()
	var xx: float = x0
	while xx <= x1:
		pts.append(Vector2(xx, surface_at(xx) + 0.5))
		xx += 10.0
	if pts.size() >= 2:
		draw_polyline(pts, ViewColors.h("#a6c75a"), 2.0, true)
	var f: float = floorf(x0 / 170.0) * 170.0
	while f < x1:
		var fh: float = hash_f(f + 3.0)
		var fx: float = f + fh * 140.0
		if fx >= x0 and fx <= x1:
			var fy: float = surface_at(fx)
			draw_line(Vector2(fx, fy), Vector2(fx, fy - 12.0 - fh * 6.0), ViewColors.h("#4f7a28"), 1.4, true)
			var fcol: Color = ViewColors.h("#f4d44a") if fh > 0.5 else ViewColors.h("#f2f0e6")
			for q in 5:
				var an: float = float(q) / 5.0 * TAU + t_now * 0.4
				ViewUtil.fill_ellipse(self, Vector2(fx, fy - 13.0 - fh * 6.0) + Vector2(cos(an), sin(an)) * 2.6, 2.0, 2.0, fcol)
			draw_circle(Vector2(fx, fy - 13.0 - fh * 6.0), 1.6, ViewColors.h("#e08a1e"))
		f += 170.0


## Cheap deterministic 0..1 hash of a float.
static func hash_f(v: float) -> float:
	return fposmod(sin(v * 12.9898) * 43758.5453, 1.0)


## The safe chamber: a warm glow, a little nest of pine needles and floating motes of light.
func _draw_chamber() -> void:
	var c: Vector2 = goal.get_center()
	var r: float = maxf(goal.size.x, goal.size.y) * 0.75
	for q in 7:
		draw_circle(c, r * (1.0 - float(q) * 0.13), Color(1.0, 0.82, 0.4, 0.05 + float(q) * 0.018 + 0.01 * sin(t_now * 2.0)))
	for q in 7:
		var fq: float = float(q)
		var mx: float = c.x + sin(t_now * 0.7 + fq * 2.3) * goal.size.x * 0.4
		var my: float = c.y + goal.size.y * 0.4 - fposmod(t_now * (10.0 + fq * 2.0) + fq * 31.0, goal.size.y * 0.9)
		draw_circle(Vector2(mx, my), 1.8, Color(1.0, 0.95, 0.7, 0.75))
	# nest
	var nest := Vector2(c.x, goal.end.y - 3.0)
	ViewUtil.fill_ellipse(self, nest, goal.size.x * 0.34, 7.0, ViewColors.h("#7a5a2c"))
	for q in 16:
		var a: float = float(q) / 15.0
		var nx: float = nest.x + (a - 0.5) * goal.size.x * 0.62
		draw_line(Vector2(nx, nest.y + 2.0), Vector2(nx + sin(float(q) * 3.1) * 8.0, nest.y - 5.0 - fposmod(float(q) * 2.7, 4.0)), ViewColors.h("#c49a4e") if q % 2 == 0 else ViewColors.h("#a37a38"), 1.4, true)
	# a tiny lamp-like glowing sap drop above it
	var bob: float = sin(t_now * 2.0) * 3.0
	draw_circle(c + Vector2(0.0, -goal.size.y * 0.1 + bob), 7.0, Color(1.0, 0.92, 0.55, 0.45))
	draw_circle(c + Vector2(0.0, -goal.size.y * 0.1 + bob), 3.6, Color(1.0, 0.98, 0.8, 0.95))


## A 28 px stone. WOBBLE shakes it, FALL adds speed streaks, `crumble` (0..PlatformDig.CRUMBLE_TIME) draws growing cracks.
func _draw_stone(c: Vector2, state: String, crumble: float, timer: float) -> void:
	var half: float = 14.0
	var id: int = int(c.x) % 97
	if state == "FALL":
		for q in 4:
			var ox: float = (float(q) - 1.5) * half * 0.5
			draw_line(Vector2(c.x + ox, c.y - half - 6.0 - float(q % 2) * 12.0), Vector2(c.x + ox, c.y - half - 26.0 - float(q) * 6.0), Color(1.0, 1.0, 1.0, 0.25), 1.5, true)
	elif state == "WOBBLE":
		c += Vector2(sin(t_now * 70.0) * 1.6 * clampf(timer * 4.0, 0.3, 1.0), 0.0)
		# a few crumbs trickle down from underneath
		for q in 3:
			var fq: float = float(q)
			var ty: float = fposmod(t_now * 60.0 + fq * 9.0, 18.0)
			draw_rect(Rect2(c.x - 8.0 + fq * 8.0, c.y + half + ty, 2.0, 2.0), Color(0.45, 0.31, 0.19, 1.0 - ty / 18.0))
	var pts := PackedVector2Array()
	for q in 10:
		var a: float = float(q) / 10.0 * TAU
		var k: float = 1.0 + _jit(id, q) * 0.12
		pts.append(c + Vector2(cos(a) * half * k, sin(a) * half * k))
	var cols := PackedColorArray()
	for p in pts:
		var u: float = clampf(((p.x - c.x) + (p.y - c.y)) / (half * 4.0) + 0.5, 0.0, 1.0)
		cols.append(ViewColors.h(ROCK_LIGHT).lerp(ViewColors.h(ROCK_DARK), u))
	draw_polygon(pts, cols)
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Color(0.17, 0.15, 0.12), 2.2, true)
	draw_line(c + Vector2(-half * 0.2, -half * 0.1), c + Vector2(half * 0.3, half * 0.45), Color(0.2, 0.18, 0.14, 0.7), 1.4, true)
	ViewUtil.fill_ellipse(self, c + Vector2(-half * 0.35, -half * 0.4), half * 0.28, half * 0.18, Color(1.0, 1.0, 0.95, 0.3), -0.5)
	if crumble > 0.0:
		var k2: float = clampf(crumble / 0.5, 0.0, 1.0)
		for q in 3:
			var fq2: float = float(q)
			var a0: Vector2 = c + Vector2(-half * 0.8 + fq2 * half * 0.7, -half * 0.8)
			draw_polyline(PackedVector2Array([a0, a0 + Vector2(3.0, half * 0.7 * k2), a0 + Vector2(-2.0, half * 1.2 * k2)]), Color(0.1, 0.08, 0.06, 0.9), 1.4, true)


## A noise ring: two thin sandy circles that fade as they grow.
func _draw_ring(rg: Variant) -> void:
	var p: Vector2 = ViewUtil.g(rg, "pos", Vector2.ZERO)
	var r: float = ViewUtil.gf(rg, "radius")
	var a: float = clampf(1.0 - r / maxf(ViewUtil.gf(rg, "max_radius", 300.0), 1.0), 0.0, 1.0)
	if r < 2.0:
		return
	draw_arc(p, r, 0.0, TAU, 48, Color(1.0, 0.9, 0.55, 0.6 * a), 3.0, true)
	draw_arc(p, r * 0.92, 0.0, TAU, 48, Color(1.0, 0.95, 0.75, 0.3 * a), 1.5, true)
	draw_arc(p, r * 1.07, 0.0, TAU, 48, Color(1.0, 0.8, 0.4, 0.16 * a), 1.5, true)


## Bubbles and a red ring that closes while the pupa is underwater: the heart goes when it is full.
func _draw_breath() -> void:
	var c: Vector2 = player_pos
	draw_arc(c, 22.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(drown, 0.0, 1.0), 32, Color(1.0, 0.35 + 0.4 * (1.0 - drown), 0.3, 0.9), 3.0, true)
	for q in 4:
		var fq: float = float(q)
		var ph: float = fposmod(t_now * 0.9 + fq * 0.27, 1.0)
		var bp := Vector2(c.x + sin(t_now * 3.0 + fq * 2.0) * 8.0 + (fq - 1.5) * 4.0, c.y - 14.0 - ph * 36.0)
		draw_arc(bp, 2.5 + fq * 0.5, 0.0, TAU, 10, Color(0.85, 0.95, 1.0, 0.8 * (1.0 - ph)), 1.2, true)

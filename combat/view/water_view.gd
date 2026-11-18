## Water of the battle: the dark back strip behind the terrain and the animated front surface with foam, sun column,
## fireball reflections and glints (port of drawWaterBack / drawWaterFront, renderer.js:2746-2845).
class_name WaterView
extends RefCounted

const TERRAIN_W: float = 3200.0
const TERRAIN_H: float = 820.0
const LEFT: float = -4800.0
const RIGHT: float = TERRAIN_W + 4800.0
const BOTTOM: float = TERRAIN_H + 3600.0


## Dark translucent strip behind the terrain.
static func draw_back(ci: CanvasItem, ctx: ViewCtx, x0: float, x1: float) -> void:
	var a: float = maxf(LEFT, snappedf(x0 - 64.0, 32.0))
	var b: float = minf(RIGHT, x1 + 64.0)
	var pts := PackedVector2Array([Vector2(a, BOTTOM)])
	var x: float = a
	while x <= b:
		pts.append(Vector2(x, ctx.water_y - 4.0 + sin(x * 0.018 + ctx.t_now * 2.1) * 4.0))
		x += 32.0
	pts.append(Vector2(b, BOTTOM))
	ci.draw_colored_polygon(pts, ViewColors.WATER_BACK)


## Surface polygon + foam crest. `x0..x1` is the visible world range.
static func draw_front(ci: CanvasItem, ctx: ViewCtx, facts: Dictionary, ripples: Array, x0: float, x1: float) -> void:
	var top: Color = facts["water_top"]
	var deep: Color = facts["water_deep"]
	var wy0: float = ctx.water_y
	var wy1: float = TERRAIN_H + 220.0
	var a: float = maxf(LEFT, snappedf(x0 - 64.0, 28.0))
	var b: float = minf(RIGHT, x1 + 64.0)
	var wave_speed: float = ctx.t_now * (2.8 + ctx.wind * 0.025)
	var surface := PackedVector2Array()
	var x: float = a
	while x <= b:
		var wy: float = wy0 + sin(x * 0.022 - wave_speed) * 4.5 + cos(x * 0.05 + ctx.t_now * 1.6) * 2.0
		for rp in ripples:
			var dist: float = absf(x - float(rp["x"]))
			if dist < 260.0:
				wy += sin(dist * 0.09 - float(rp["phase"]) * 14.0) * float(rp["amp"]) * (1.0 - dist / 260.0) * float(rp["life"])
		surface.append(Vector2(x, wy))
		x += 28.0
	# Filled in vertical bands so the WATER_Y..TERRAIN_H+220 gradient is exact; below that the deep colour continues.
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for p in surface:
		pts.append(p)
		cols.append(top)
	var y_mid: float = wy1
	for i in range(surface.size() - 1, -1, -1):
		pts.append(Vector2(surface[i].x, y_mid))
		cols.append(deep)
	ci.draw_polygon(pts, cols)
	var base: PackedVector2Array = PackedVector2Array([Vector2(surface[0].x, y_mid), Vector2(surface[surface.size() - 1].x, y_mid), Vector2(surface[surface.size() - 1].x, BOTTOM), Vector2(surface[0].x, BOTTOM)])
	ci.draw_colored_polygon(base, deep)
	var warm: bool = ctx.map_id == "MONTSERRAT" or ctx.map_id == "CASTELLFOLLIT"
	ci.draw_polyline(surface, Color(1.0, 0.8784, 0.6667, 0.58) if warm else Color(0.9216, 0.9725, 1.0, 0.56), 2.4, true)
	# Shimmering glints (normal blend).
	var glint: Color = Color(1.0, 0.8431, 0.5686, 0.24) if warm else Color(0.7647, 0.9333, 1.0, 0.24)
	for row in 3:
		var ry: float = ctx.water_y + 14.0 + float(row) * 18.0
		var sx: float = -400.0
		while sx < TERRAIN_W + 400.0:
			var shx: float = sx + sin(ctx.t_now * 2.1 + float(row) * 1.7 + sx * 0.01) * 22.0 + ctx.wind * 0.25
			var shl: float = 28.0 + sin(ctx.t_now * 3.4 + sx * 0.03 + float(row)) * 14.0
			if shl > 18.0:
				ci.draw_line(Vector2(shx, ry), Vector2(shx + shl, ry + sin(sx + ctx.t_now) * 1.5), glint, 1.6, true)
			sx += 110.0


## Sun column and fireball reflections (the canvas 'screen' part; draw it on an additive node).
static func draw_reflections(ci: CanvasItem, ctx: ViewCtx, fireballs: Array) -> void:
	var warm: bool = ctx.map_id == "MONTSERRAT" or ctx.map_id == "CASTELLFOLLIT"
	var sun_col: Color = Color(1.0, 0.7647, 0.4314, 0.14) if warm else Color(0.7843, 0.9216, 1.0, 0.13)
	var sun_x: float = TERRAIN_W * 0.68
	for band in 7:
		var by: float = ctx.water_y + 8.0 + float(band) * 11.0
		var bw: float = (95.0 - float(band) * 9.0) + sin(ctx.t_now * 3.2 + float(band) * 1.4) * 18.0
		var bx: float = sun_x + sin(ctx.t_now * 2.1 + float(band)) * 10.0
		ci.draw_rect(Rect2(bx - bw * 0.5, by, bw, 4.5), sun_col)
	for fb in fireballs:
		if float(fb["life"]) > 0.0 and float(fb["y"]) < ctx.water_y + 60.0:
			var ra: float = clampf(float(fb["life"]) * 0.38, 0.0, 0.42)
			var r: float = float(fb["r"]) * 1.35
			var c: Color = Color(1.0, 0.9216, 0.549) if fb["holy"] else Color(1.0, 0.5882, 0.2157)
			ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(1.0, 0.33), 0.0, Vector2(float(fb["x"]), ctx.water_y + 28.0)))
			ViewUtil.radial(ci, Vector2.ZERO, 4.0, r, [[0.0, Color(c, 1.0)], [1.0, Color(1.0, 0.3529, 0.0784, 0.0)]], ra, "water_refl_" + c.to_html(false))
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)

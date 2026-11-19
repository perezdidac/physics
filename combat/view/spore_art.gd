## The Beauveria fungus clouds of the Processó stage (rects of the level, `ctx.spores`): soft greenish puffs that drift and breathe inside their
## rectangle, a faint dashed rim so the danger zone is readable, floating spore dots and, on the turn that hurts whoever stands in them, a pulse
## (ctx.spore_pulse, 1 -> 0) that flushes the cloud a sick red-green and sends a ring outwards.
class_name SporeArt
extends RefCounted

const PUFF: Color = Color(0.58, 0.82, 0.38)
const PUFF_PALE: Color = Color(0.84, 0.95, 0.62)
const RIM: Color = Color("#b6e86a")
const SICK: Color = Color("#d4e34a")


static func draw(ci: CanvasItem, ctx: ViewCtx) -> void:
	for i in ctx.spores.size():
		_cloud(ci, ctx.spores[i], i, ctx.t_now, ctx.spore_pulse)


static func _cloud(ci: CanvasItem, rect: Rect2, idx: int, t: float, pulse: float) -> void:
	var c: Vector2 = rect.get_center()
	var hw: float = rect.size.x * 0.5
	var hh: float = rect.size.y * 0.5
	var breathe: float = 0.5 + 0.5 * sin(t * 1.3 + float(idx))
	# the soft base glow
	ViewUtil.fill_ellipse(ci, c, hw * 0.98, hh * 0.98, Color(PUFF, 0.06 + 0.04 * breathe + 0.12 * pulse))
	var n: int = clampi(int(rect.size.x * rect.size.y / 2600.0), 7, 26)
	for k in n:
		var a: float = float(k) * 2.399963 + float(idx) * 1.3
		var u: float = sqrt((float(k) + 0.5) / float(n))
		var drift := Vector2(sin(t * 0.6 + float(k) * 1.7) * hw * 0.08, cos(t * 0.5 + float(k) * 2.3) * hh * 0.1)
		var p: Vector2 = c + Vector2(cos(a) * hw * 0.82 * u, sin(a) * hh * 0.82 * u) + drift
		var rad: float = clampf(minf(hw, hh) * (0.42 + 0.12 * sin(t * 0.9 + float(k))), 14.0, 70.0)
		var col: Color = PUFF if k % 3 != 0 else PUFF_PALE
		if pulse > 0.0:
			col = col.lerp(SICK, pulse * 0.6)
		ViewUtil.radial(ci, p, 0.0, rad, [[0.0, Color(col, 0.5)], [0.6, Color(col, 0.24)], [1.0, Color(col, 0.0)]], 0.85, "spore_%s" % col.to_html(true))
	for k in 16:
		var ph: float = fmod(t * 0.25 + float(k) * 0.173 + float(idx) * 0.31, 1.0)
		var sx: float = c.x + sin(float(k) * 12.9898 + float(idx)) * hw * 0.92 + sin(t * 0.8 + float(k)) * 6.0
		var sy: float = rect.end.y - ph * rect.size.y
		ci.draw_circle(Vector2(sx, sy), 1.3 + float(k % 3) * 0.5, Color(PUFF_PALE, sin(ph * PI) * 0.8))
	var rim: PackedVector2Array = ViewUtil.ellipse_pts(c, hw, hh, 0.0, 40)
	rim.append(rim[0])
	ViewUtil.dashed(ci, rim, 10.0, 8.0, Color(RIM, 0.42 + 0.35 * pulse), 1.6)
	if pulse > 0.0:
		var grow: float = 1.0 + (1.0 - pulse) * 0.35
		ci.draw_arc(c, hw * grow, 0.0, TAU, 40, Color(SICK, pulse * 0.9), 3.0 + pulse * 3.0, true)

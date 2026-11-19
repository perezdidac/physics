## The Calosoma beetle (Calosoma sycophanta) of the Processó stage, procedural, side view facing right: a metallic green and gold ground beetle with
## ridged elytra, a small dark head with sharp mandibles, long thin legs and long antennae. It is the caterpillar hunter, so it looks quick and a bit
## wicked. Fields read from the fighter: walk_cycle, facing, hurt_timer, bat_swing_timer (the bite), flip_angle.
class_name CalosomaArt
extends RefCounted

const GREEN: Color = Color("#2f8f5b")
const GREEN_DARK: Color = Color("#0f4a33")
const GOLD: Color = Color("#d9b43c")
const COPPER: Color = Color("#b8642a")
const INK: Color = Color("#10201a")


static func draw(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	var t: float = ctx.t_now
	var walk: float = ViewUtil.gf(f, "walk_cycle")
	var facing: float = ViewUtil.gf(f, "facing", -1.0)
	var r: float = ViewUtil.gf(f, "r", 12.0)
	var s: float = r / 12.0
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var bite: float = clampf(ViewUtil.gf(f, "bat_swing_timer") / 0.48, 0.0, 1.0)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var grounded: bool = ViewUtil.gb(f, "grounded", true)
	var bob: float = absf(sin(walk * 0.5)) * 1.1 if grounded else 0.0
	var origin := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + (r - 4.0 if drowning else 0.0))
	ci.draw_set_transform_matrix(Transform2D(ViewUtil.gf(f, "flip_angle"), Vector2(facing * s, s), 0.0, origin))
	var ground: float = r / s - 0.3
	# six long legs, three on each side, scissoring with the walk cycle
	for i in 6:
		var near: bool = i < 3
		var k: int = i % 3
		var hip := Vector2(-6.0 + float(k) * 6.0, -ground * 0.62 - bob)
		var ph: float = walk + float(k) * 2.1 + (0.0 if near else PI)
		var sw: float = sin(ph) * 5.5 if grounded else 2.0
		var lift: float = maxf(0.0, cos(ph)) * 3.0 if grounded else 4.0
		var knee: Vector2 = hip + Vector2(float(k - 1) * 4.0 + sw * 0.4, -5.0 - lift * 0.5)
		var foot := Vector2(hip.x + float(k - 1) * 7.5 + sw, ground - lift)
		var col: Color = INK if near else Color(INK, 0.6)
		ci.draw_polyline(PackedVector2Array([hip, knee, foot]), col, 1.5, true)
	var by: float = -ground * 0.78 - bob
	# elytra: a long metallic dome, green with a copper-gold rim and rows of golden pits
	ViewUtil.ellipse_fs(ci, Vector2(-4.0, by), 13.5, 7.6, GREEN, INK, 1.5, -0.04)
	ViewUtil.fill_ellipse(ci, Vector2(-5.0, by - 2.6), 10.5, 3.2, Color(0.75, 1.0, 0.8, 0.28), -0.05)
	ci.draw_arc(Vector2(-4.0, by), 11.6, PI * 0.1, PI * 0.9, 14, Color(GOLD, 0.95), 2.0, true)
	ci.draw_arc(Vector2(-4.0, by), 12.0, PI * 1.05, PI * 1.95, 14, Color(COPPER, 0.8), 1.4, true)
	for row in 3:
		var yy: float = by - 3.5 + float(row) * 3.2
		for col_i in 5:
			var xx: float = -13.0 + float(col_i) * 4.2 + float(row % 2) * 2.0
			ci.draw_circle(Vector2(xx, yy), 0.95, GOLD if (col_i + row) % 2 == 0 else COPPER)
	ci.draw_line(Vector2(-4.0, by - 7.0), Vector2(-4.0, by + 7.0), Color(GREEN_DARK, 0.7), 1.0, true)
	# pronotum (the shield behind the head) and the head
	ViewUtil.ellipse_fs(ci, Vector2(8.6, by - 0.6), 4.4, 5.2, GOLD.darkened(0.15), INK, 1.4, 0.06)
	ViewUtil.fill_ellipse(ci, Vector2(8.0, by - 2.4), 2.4, 1.6, Color(1.0, 0.95, 0.7, 0.55))
	var head := Vector2(14.6, by + 0.2)
	ViewUtil.ellipse_fs(ci, head, 3.8, 3.6, Color("#18332a"), INK, 1.3)
	# mandibles snapping on a bite
	var open: float = sin(bite * PI) * 3.2
	ci.draw_polyline(PackedVector2Array([head + Vector2(2.4, 1.0), head + Vector2(6.8, 1.6 + open), head + Vector2(5.4, 3.4 + open)]), INK, 1.6, true)
	ci.draw_polyline(PackedVector2Array([head + Vector2(2.4, 0.2), head + Vector2(6.8, -0.6 - open * 0.2), head + Vector2(5.6, -2.0)]), INK, 1.4, true)
	# eye and long antennae
	ci.draw_circle(head + Vector2(1.0, -1.2), 1.5, Color("#f6e7a8"))
	ci.draw_circle(head + Vector2(1.4, -1.2), 0.75, Color("#a8261c") if bite > 0.0 else INK)
	var wig: float = sin(t * 8.0 + float(ViewUtil.gi(f, "id"))) * 1.4
	for a in [-0.5, 0.2]:
		var base: Vector2 = head + Vector2(2.4, -2.6)
		ci.draw_polyline(ViewUtil.quad_pts(base, base + Vector2(6.0, -6.0 + a * 4.0), base + Vector2(13.0 + wig, -3.0 + a * 7.0), 8), INK, 1.1, true)
	if hurt > 0.0:
		ViewUtil.fill_ellipse(ci, Vector2(0.0, by), 15.0, 8.0, Color(1.0, 0.25, 0.2, clampf(hurt, 0.0, 1.0) * 0.4))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

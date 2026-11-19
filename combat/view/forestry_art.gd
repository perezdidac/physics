## Procedural art of the forestry brigade of El Bolsó: the workers (kind FORESTRY_WORKER: orange hi-vis vest, orange helmet, a branch-cutting
## pole over the shoulder that swings down when they strike) and the Capatàs (the BRIGADE_BOSS foreman: bigger, white helmet, a big moustache,
## a clipboard, his own pole; WINDED = sitting on the ground catching his breath, sweat drops flying and the clipboard used as a fan).
## Both are comic and affectionate: workers doing their job, a little clumsy. Drawn in a unit space of 12 px per `radius` so they scale with
## the fighter, facing right and mirrored by `facing`.
class_name ForestryArt
extends RefCounted

const SKIN: Color = Color("#f1b184")
const SKIN_SHADE: Color = Color("#d48d63")
const VEST: Color = Color("#ff7a18")
const VEST_DARK: Color = Color("#d85a08")
const SHIRT: Color = Color("#4f6b8a")
const TROUSERS: Color = Color("#34425e")
const BOOT: Color = Color("#3a2a1e")
const HELMET_ORANGE: Color = Color("#ff8f1f")
const HELMET_WHITE: Color = Color("#f6f3ea")
const INK: Color = Color("#1a1410")
const STRIPE: Color = Color("#f4f0b0")
const WOOD: Color = Color("#8d5a2b")
const STEEL: Color = Color("#aab3bd")


static func draw_worker(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	_person(ci, f, ctx, {"foreman": false})


static func draw_foreman(ci: CanvasItem, f: Variant, ctx: ViewCtx) -> void:
	_person(ci, f, ctx, {"foreman": true, "winded": ctx.boss_state == "WINDED"})


static func _person(ci: CanvasItem, f: Variant, ctx: ViewCtx, o: Dictionary) -> void:
	var t: float = ctx.t_now
	var r: float = ViewUtil.gf(f, "r", 12.0)
	var foreman: bool = bool(o["foreman"])
	var u: float = r / 12.0 * (1.2 if foreman else 1.0)
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var winded: bool = bool(o.get("winded", false))
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var hurt: float = clampf(ViewUtil.gf(f, "hurt_timer"), 0.0, 1.0)
	var walk: float = ViewUtil.gf(f, "walk_cycle")
	var moving: bool = absf(ViewUtil.gf(f, "vx")) > 6.0 or ViewUtil.gb(f, "walking")
	var swing: float = clampf(ViewUtil.gf(f, "bat_swing_timer") / 0.48, 0.0, 1.0)
	var origin := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") + (r * 0.5 if drowning else 0.0))
	var bob: float = 0.0 if winded else (absf(sin(walk * 0.5)) * 0.8 if moving else sin(t * 2.2 + float(ViewUtil.gi(f, "id"))) * 0.35)
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(facing * u, u), 0.0, origin))
	ViewUtil.fill_ellipse(ci, Vector2(0.0, 12.4), 9.0 if not foreman else 11.0, 1.6, Color(0.0, 0.0, 0.0, 0.2))
	var vest: Color = VEST
	var trousers: Color = TROUSERS
	if hurt > 0.0:
		vest = vest.lerp(Color(1.0, 0.3, 0.25), hurt * 0.5)
	if winded:
		_draw_sitting(ci, t, foreman, vest, trousers)
	else:
		_draw_standing(ci, f, t, walk, moving, bob, swing, foreman, vest, trousers, ctx)
	if drowning:
		ci.draw_rect(Rect2(-14.0, 4.0, 28.0, 14.0), Color(0.3, 0.55, 0.75, 0.55))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _draw_standing(ci: CanvasItem, f: Variant, t: float, walk: float, moving: bool, bob: float, swing: float, foreman: bool, vest: Color, trousers: Color, ctx: ViewCtx) -> void:
	var belly: float = 1.5 if foreman else 0.0
	# legs
	for side in 2:
		var ph: float = walk + (PI if side == 1 else 0.0)
		var foot := Vector2(sin(ph) * (4.0 if moving else 0.5) + (side - 0.5) * 2.0, 12.0 - maxf(0.0, cos(ph)) * (2.5 if moving else 0.0))
		var hip := Vector2((side - 0.5) * 3.2, 3.0 - bob)
		ci.draw_line(hip, foot - Vector2(0.0, 1.0), trousers.darkened(0.2 if side == 0 else 0.0), 4.4, true)
		ViewUtil.ellipse_fs(ci, foot + Vector2(1.6, 0.0), 3.6, 1.9, BOOT, INK, 0.8)
	# far arm, then the pole behind the body if it rests on the shoulder
	var pole: Dictionary = _pole_pose(f, swing, foreman, ctx)
	ci.draw_line(Vector2(-1.5, -5.0 - bob), Vector2(-4.5 + sin(walk) * 2.0, 1.0 - bob), SHIRT.darkened(0.2), 3.4, true)
	# torso
	var torso := Rect2(-5.2 - belly, -8.0 - bob, 10.4 + belly * 1.6, 12.4)
	ViewUtil.round_rect_fs(ci, torso, 3.6, SHIRT, INK, 0.9)
	ViewUtil.round_rect_fs(ci, Rect2(torso.position.x + 0.8, torso.position.y + 0.8, torso.size.x - 1.6, torso.size.y - 1.2), 3.2, vest, VEST_DARK, 0.8)
	ci.draw_line(Vector2(torso.position.x + 1.0, 0.2 - bob), Vector2(torso.end.x - 1.0, 0.2 - bob), STRIPE, 1.4, true)
	ci.draw_line(Vector2(torso.position.x + 1.0, -3.6 - bob), Vector2(torso.end.x - 1.0, -3.6 - bob), STRIPE, 1.4, true)
	ci.draw_line(Vector2(-2.0, torso.position.y + 1.0), Vector2(-2.0, torso.end.y - 0.6), Color(STRIPE, 0.8), 1.2, true)
	ci.draw_line(Vector2(2.4, torso.position.y + 1.0), Vector2(2.4, torso.end.y - 0.6), Color(STRIPE, 0.8), 1.2, true)
	ci.draw_line(Vector2(torso.position.x + 1.0, 3.8 - bob), Vector2(torso.end.x - 1.0, 3.8 - bob), Color(INK, 0.9), 1.8, true)
	ViewUtil.rect_fs(ci, Rect2(-1.0, 3.0 - bob, 2.4, 1.8), Color("#d8b24a"), INK, 0.5)
	_head(ci, t, Vector2(1.4, -13.2 - bob), foreman, false, f)
	# clipboard (foreman): held in the far hand against the belly
	if foreman:
		_clipboard(ci, Vector2(-1.0, -1.5 - bob), -0.12, 1.0)
	# near arm and the pole
	var hand: Vector2 = pole["hand"]
	ci.draw_line(Vector2(2.0, -5.5 - bob), hand, SHIRT, 3.6, true)
	ci.draw_circle(hand, 1.9, SKIN)
	_draw_pole(ci, pole)
	_launcher(ci, ctx, foreman)


## Where the pole is held: the hand, and the angle and length of the shaft. Resting on the shoulder, raised while the Capatàs winds up the
## LINE attack, and swinging down while `swing` runs.
static func _pole_pose(f: Variant, swing: float, foreman: bool, ctx: ViewCtx) -> Dictionary:
	var length: float = 34.0 if foreman else 26.0
	var angle: float = -2.0
	var hand := Vector2(3.4, -1.0)
	if swing > 0.0:
		angle = lerpf(1.0, -2.7, swing)
	elif foreman and ctx.boss != null and f == ctx.boss and str(ctx.boss_intent.get("kind", "")) == "LINE":
		angle = -2.55 + sin(ctx.t_now * 9.0) * 0.07
		hand = Vector2(4.0, -4.0)
	return {"hand": hand, "angle": angle, "length": length}


## The branch-cutting pole: a wooden shaft with a hooked steel saw blade at the end.
static func _draw_pole(ci: CanvasItem, pole: Dictionary) -> void:
	var hand: Vector2 = pole["hand"]
	var a: float = pole["angle"]
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(-d.y, d.x)
	var tip: Vector2 = hand + d * float(pole["length"])
	var butt: Vector2 = hand - d * 7.0
	ci.draw_line(butt, tip, INK, 3.0, true)
	ci.draw_line(butt, tip, WOOD, 1.9, true)
	var blade := PackedVector2Array([tip - d * 1.0 + n * 1.6, tip + d * 6.0 + n * 3.4, tip + d * 9.0 - n * 0.5, tip + d * 3.0 - n * 1.0])
	ViewUtil.fill_poly(ci, blade, STEEL)
	ci.draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2], blade[3], blade[0]]), INK, 0.8, true)
	for k in 4:
		var q: Vector2 = tip + d * (1.5 + float(k) * 1.7) + n * (1.7 + float(k) * 0.55)
		ci.draw_line(q, q + d * 0.9 + n * 1.3, INK, 0.7, true)


## The nest-shooting cartridge launcher: a stubby tube on the shoulder, only while the Capatàs has announced the CARTRIDGE attack.
static func _launcher(ci: CanvasItem, ctx: ViewCtx, foreman: bool) -> void:
	if not foreman or str(ctx.boss_intent.get("attack_id", "")) != "CARTRIDGE":
		return
	var p := Vector2(-1.0, -9.0)
	ci.draw_line(p, p + Vector2(15.0, -9.0), INK, 6.0, true)
	ci.draw_line(p, p + Vector2(15.0, -9.0), Color("#5a6470"), 4.2, true)
	ci.draw_circle(p + Vector2(15.5, -9.3), 3.0, Color("#ffcf4a"))
	ci.draw_circle(p + Vector2(15.5, -9.3), 1.4, INK)


static func _head(ci: CanvasItem, t: float, c: Vector2, foreman: bool, winded: bool, f: Variant) -> void:
	var radius: float = 6.0 if foreman else 5.4
	ViewUtil.circle_fs(ci, c, radius, SKIN, INK, 0.9)
	ViewUtil.fill_ellipse(ci, c + Vector2(-0.5, 2.0), radius * 0.8, radius * 0.45, Color(SKIN_SHADE, 0.45))
	var blink: bool = fmod(t * 0.8 + float(ViewUtil.gi(f, "id")) * 1.7, 4.5) > 4.38
	var eye := c + Vector2(2.6, -0.8)
	if winded:
		ci.draw_line(eye + Vector2(-1.6, 0.0), eye + Vector2(1.4, 0.4), INK, 1.1, true)
		ci.draw_line(eye + Vector2(-1.4, -2.2), eye + Vector2(1.8, -1.6), INK, 1.0, true)
	elif blink:
		ci.draw_line(eye + Vector2(-1.4, 0.0), eye + Vector2(1.4, 0.0), INK, 1.0, true)
	else:
		ci.draw_circle(eye, 1.5, Color.WHITE)
		ci.draw_circle(eye + Vector2(0.5, 0.1), 0.85, INK)
		ci.draw_line(eye + Vector2(-1.8, -2.2), eye + Vector2(1.8, -1.9 if not foreman else -2.8), INK, 1.0, true)
	ViewUtil.fill_ellipse(ci, c + Vector2(radius * 0.95, 0.9), 1.5, 1.3, SKIN_SHADE)
	if foreman:
		# the big moustache: two curled lobes under the nose
		var m := c + Vector2(radius * 0.55, 2.7)
		ViewUtil.ellipse_fs(ci, m + Vector2(-2.6, 0.3), 3.6, 1.6, Color("#3a2514"), INK, 0.5, 0.25)
		ViewUtil.ellipse_fs(ci, m + Vector2(2.4, 0.3), 3.6, 1.6, Color("#3a2514"), INK, 0.5, -0.25)
		ci.draw_circle(m + Vector2(-5.8, -0.2), 0.9, Color("#3a2514"))
		ci.draw_circle(m + Vector2(5.2, -0.2), 0.9, Color("#3a2514"))
	if winded:
		ViewUtil.fill_ellipse(ci, c + Vector2(radius * 0.6, 4.6), 1.5, 1.8, Color("#5a1f1f"))
	elif not foreman:
		ci.draw_arc(c + Vector2(3.0, 2.4), 1.9, 0.2, PI - 0.3, 6, INK, 0.9, true)
	_helmet(ci, c, radius, foreman, winded)


static func _helmet(ci: CanvasItem, c: Vector2, radius: float, foreman: bool, winded: bool) -> void:
	var col: Color = HELMET_WHITE if foreman else HELMET_ORANGE
	var push: float = -1.6 if winded else 0.0
	var dome := PackedVector2Array()
	for i in 13:
		var a: float = PI + float(i) / 12.0 * PI
		dome.append(c + Vector2(push + cos(a) * (radius + 0.9), -0.6 - 0.6 + sin(a) * (radius + 1.0)))
	ViewUtil.fill_poly(ci, dome, col)
	ci.draw_polyline(dome, INK, 0.9, true)
	ci.draw_line(c + Vector2(push - radius - 1.3, -1.2), c + Vector2(push + radius + 4.4, -1.2), INK, 2.6, true)
	ci.draw_line(c + Vector2(push - radius - 1.0, -1.2), c + Vector2(push + radius + 4.0, -1.2), col.darkened(0.12), 1.6, true)
	ci.draw_line(c + Vector2(push + 0.2, -radius - 1.4), c + Vector2(push + 0.2, -2.0), Color(0.0, 0.0, 0.0, 0.25), 1.6, true)
	ci.draw_line(c + Vector2(push - 1.8, -radius - 0.6), c + Vector2(push - 1.8, -2.0), Color(1.0, 1.0, 1.0, 0.35), 1.4, true)
	if foreman:
		ViewUtil.circle_fs(ci, c + Vector2(push + 3.6, -radius * 0.55), 1.8, Color("#e2b43c"), INK, 0.5)


static func _clipboard(ci: CanvasItem, p: Vector2, rot: float, k: float) -> void:
	var pts := PackedVector2Array()
	for c in [Vector2(-3.4, -4.4), Vector2(3.4, -4.4), Vector2(3.4, 4.4), Vector2(-3.4, 4.4)]:
		pts.append(p + (c as Vector2).rotated(rot) * k)
	ViewUtil.fill_poly(ci, pts, Color("#9a6a3a"))
	ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), INK, 0.9, true)
	var paper := PackedVector2Array()
	for c in [Vector2(-2.7, -3.4), Vector2(2.7, -3.4), Vector2(2.7, 3.7), Vector2(-2.7, 3.7)]:
		paper.append(p + (c as Vector2).rotated(rot) * k)
	ViewUtil.fill_poly(ci, paper, Color("#fbf8ee"))
	for i in 4:
		var y: float = -2.0 + float(i) * 1.6
		ci.draw_line(p + Vector2(-1.9, y).rotated(rot) * k, p + Vector2(1.9 - float(i % 2), y).rotated(rot) * k, Color(INK, 0.55), 0.6, true)
	ViewUtil.fill_ellipse(ci, p + Vector2(0.0, -4.4).rotated(rot) * k, 1.6 * k, 0.9 * k, Color("#c9ced4"), rot)


## WINDED: sitting on the ground, leaning back, legs stretched out, panting; the clipboard fans him and sweat flies.
static func _draw_sitting(ci: CanvasItem, t: float, foreman: bool, vest: Color, trousers: Color) -> void:
	var lean: float = -0.22 + sin(t * 7.0) * 0.03
	# legs stretched forward along the ground
	for side in 2:
		var hip := Vector2(-2.0, 9.2)
		var foot := Vector2(11.0 + float(side) * 2.0, 10.8 - float(side) * 0.5)
		ci.draw_line(hip, foot, trousers.darkened(0.2 if side == 0 else 0.0), 4.6, true)
		ViewUtil.ellipse_fs(ci, foot + Vector2(1.8, -0.6), 3.4, 2.2, BOOT, INK, 0.8, -0.5)
	var pivot := Vector2(-2.0, 9.4)
	var xf := Transform2D(lean, Vector2.ONE, 0.0, pivot)
	var local := PackedVector2Array()
	for p: Vector2 in [Vector2(-8.0, 0.0), Vector2(8.0, 0.0), Vector2(8.0, -14.0), Vector2(-8.0, -14.0)]:
		local.append(xf * p)
	ViewUtil.fill_poly(ci, local, SHIRT)
	var vest_pts := PackedVector2Array()
	for p: Vector2 in [Vector2(-7.0, -0.5), Vector2(7.0, -0.5), Vector2(7.0, -13.0), Vector2(-7.0, -13.0)]:
		vest_pts.append(xf * p)
	ViewUtil.fill_poly(ci, vest_pts, vest)
	ci.draw_polyline(PackedVector2Array([vest_pts[0], vest_pts[1], vest_pts[2], vest_pts[3], vest_pts[0]]), VEST_DARK, 1.0, true)
	ci.draw_line(xf * Vector2(-7.0, -4.0), xf * Vector2(7.0, -4.0), STRIPE, 1.4, true)
	ci.draw_line(xf * Vector2(-7.0, -8.5), xf * Vector2(7.0, -8.5), STRIPE, 1.4, true)
	var head: Vector2 = xf * Vector2(1.0, -19.0) + Vector2(0.0, sin(t * 7.0) * 0.7)
	_head(ci, t, head, foreman, true, null)
	# the clipboard as a fan, in front of the face
	var fan: float = sin(t * 11.0) * 0.5
	_clipboard(ci, head + Vector2(11.0, 3.0), 0.8 + fan, 1.2)
	ci.draw_line(xf * Vector2(3.0, -12.0), head + Vector2(10.0, 4.5), SHIRT, 3.4, true)
	# sweat drops and breath puffs
	for k in 3:
		var ph: float = fmod(t * 1.4 + float(k) * 0.33, 1.0)
		var d := head + Vector2(-5.0 - float(k) * 3.0 - ph * 5.0, -6.0 - ph * 6.0 + ph * ph * 20.0)
		ViewUtil.fill_poly(ci, PackedVector2Array([d + Vector2(0.0, -2.6), d + Vector2(1.5, 0.4), d + Vector2(-1.5, 0.4)]), Color(0.55, 0.82, 1.0, 1.0 - ph))
		ci.draw_circle(d + Vector2(0.0, 0.5), 1.5, Color(0.55, 0.82, 1.0, 1.0 - ph))
		var pu: float = fmod(t * 1.1 + float(k) * 0.37, 1.0)
		ci.draw_circle(head + Vector2(8.0 + pu * 8.0, 4.0 - pu * 5.0), 1.4 + pu * 2.4, Color(1.0, 1.0, 1.0, 0.65 * (1.0 - pu)))
	# the pole lies on the ground next to him
	ci.draw_line(Vector2(-12.0, 12.2), Vector2(-26.0, 12.0), INK, 3.0, true)
	ci.draw_line(Vector2(-12.0, 12.2), Vector2(-26.0, 12.0), WOOD, 1.9, true)

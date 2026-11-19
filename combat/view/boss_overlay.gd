## World-space overlays of a boss level (any BossDef): what the boss is about to do (target rings on the marked caterpillars, the danger
## circle of an area / gust with "move away" arrows, the intent label bubble), the "VULNERABLE!" tag and the status icons over fighters
## (PARASITE: little eggs and the turns left). Everything reads the ViewCtx (the sim state of the frame); nothing is stored.
class_name BossOverlay
extends RefCounted

const DANGER: Color = Color("#ff4a3d")
const SAFE: Color = Color("#9aa3ad")
const GOLD: Color = Color("#ffd24a")
## Longest label bubble (screen px) before the text is shortened.
const BUBBLE_SIZE: float = 14.0


static func draw(ci: CanvasItem, ctx: ViewCtx) -> void:
	if ctx.boss != null and ViewUtil.gb(ctx.boss, "alive"):
		var slots: Dictionary = _slots(ctx)
		_draw_intent(ci, ctx, slots)
		if ctx.boss_vulnerable:
			_draw_vulnerable(ci, ctx, float(slots["tag_y"]), bool(slots["up"]))
	_draw_statuses(ci, ctx)


## Where the boss's texts go: above it (the label bubble over the "VULNERABLE!" tag) or, when that would be under the HUD, below it.
static func _slots(ctx: ViewCtx) -> Dictionary:
	var bpos: Vector2 = ViewUtil.pos(ctx.boss)
	var r: float = ViewUtil.gf(ctx.boss, "r", 16.0)
	var has_label: bool = str(ctx.boss_intent.get("label", "")) != ""
	var up: bool = not under_hud(ctx, Vector2(bpos.x, bpos.y - r - 60.0))
	var bob: float = sin(ctx.t_now * 6.0) * 3.0
	if up:
		return {"up": true, "tag_y": bpos.y - r * 1.6 - 22.0 + bob, "label_y": bpos.y - r - 26.0 - (30.0 if ctx.boss_vulnerable else 0.0)}
	return {"up": false, "label_y": bpos.y + r + 10.0, "tag_y": bpos.y + r + 34.0 + (46.0 if has_label else 0.0) + bob}


## Font size that stays about BUBBLE_SIZE px on screen whatever the camera zoom.
static func _screen_size(ctx: ViewCtx, px: float) -> int:
	return roundi(clampf(px / maxf(0.3, ctx.scale_px), 9.0, 40.0))


static func _fighter(ctx: ViewCtx, id: int) -> Variant:
	for f in ctx.fighters:
		if ViewUtil.gi(f, "id") == id:
			return f
	return null


## The BossDef.attacks entry of the announced intent ({} when none).
static func attack_of(ctx: ViewCtx) -> Dictionary:
	var i: int = int(ctx.boss_intent.get("attack_index", -1))
	var list: Variant = ViewUtil.g(ctx.boss_def, "attacks", [])
	if i < 0 or not list is Array or i >= (list as Array).size():
		return {}
	return (list as Array)[i]


## True when the marked fighter is no longer in danger: the sim settled the mark as dodged, it hid, or it is farther than `dodge` px.
static func is_dodged(mark: Dictionary, f: Variant, dodge: float) -> bool:
	if mark.has("dodged"):
		return bool(mark["dodged"])
	if f == null or not ViewUtil.gb(f, "alive") or ViewUtil.gb(f, "hidden"):
		return true
	return dodge > 0.0 and ViewUtil.pos(f).distance_to(mark.get("pos", ViewUtil.pos(f))) > dodge


# ---------------------------------------------------------------- intent

static func _draw_intent(ci: CanvasItem, ctx: ViewCtx, slots: Dictionary) -> void:
	var intent: Dictionary = ctx.boss_intent
	if intent.is_empty():
		return
	var atk: Dictionary = attack_of(ctx)
	var kind: String = str(intent.get("kind", ""))
	var t: float = ctx.t_now
	var bpos: Vector2 = ViewUtil.pos(ctx.boss)
	var label_at := Vector2(bpos.x, float(slots["label_y"]))
	var marks: Array = intent.get("targets", [])
	if kind == "AREA" or kind == "GUST" or kind == "STATUS":
		_draw_area(ci, intent.get("pos", bpos), float(intent.get("radius", 100.0)), kind == "GUST", t)
	if kind == "LINE" and intent.get("rect") is Rect2:
		NestFx.draw_band(ci, ctx, intent["rect"], t)
	if kind == "MOVE":
		_draw_destination(ci, intent.get("pos", bpos), bpos, t)
	for mark in marks:
		var f: Variant = _fighter(ctx, int(mark["id"]))
		var dodge: float = float(atk.get("dodge", 0.0))
		var dodged: bool = is_dodged(mark, f, dodge)
		_draw_mark(ci, mark, f, dodge, dodged, bpos, t)
	if str(intent.get("label", "")) != "":
		draw_bubble(ci, ctx, str(intent["label"]), label_at, GOLD if kind != "AREA" and kind != "GUST" and kind != "LINE" else DANGER, not bool(slots["up"]))


## The danger circle of an area attack: translucent fill, dashed rim and arrows pointing outwards (the way to run).
static func _draw_area(ci: CanvasItem, pos: Vector2, radius: float, gust: bool, t: float) -> void:
	var col: Color = Color("#8fd8f2") if gust else DANGER
	var pulse: float = 0.5 + 0.5 * sin(t * 5.0)
	ViewUtil.fill_ellipse(ci, pos, radius, radius, Color(col, 0.10 + 0.06 * pulse))
	ViewUtil.dashed_circle(ci, pos, radius, 14.0, 9.0, Color(col, 0.9), 3.0)
	for k in 8:
		var a: float = float(k) * TAU / 8.0 + (0.0 if k % 2 == 0 else 0.2)
		var dir := Vector2(cos(a), sin(a))
		var r0: float = radius * (0.30 + 0.06 * pulse) + float(k % 2) * radius * 0.1
		var r1: float = r0 + radius * 0.24
		_arrow(ci, pos + dir * r0, pos + dir * r1, Color(col, 0.85), 3.0, maxf(6.0, radius * 0.07))


## Where a moving boss is going (a perch): a pulsing gold ring with an arrow pointing down at it and a dotted line from the boss.
static func _draw_destination(ci: CanvasItem, pos: Vector2, from: Vector2, t: float) -> void:
	var pulse: float = sin(t * 6.0)
	ViewUtil.dashed(ci, PackedVector2Array([from, pos]), 5.0, 8.0, Color(GOLD, 0.45), 1.6)
	ViewUtil.dashed_circle(ci, pos, 24.0 + pulse * 2.0, 8.0, 6.0, Color(GOLD, 0.9), 2.4)
	_arrow(ci, pos + Vector2(0.0, -46.0 + pulse * 3.0), pos + Vector2(0.0, -26.0), Color(GOLD, 0.95), 3.0, 10.0)


static func _arrow(ci: CanvasItem, from: Vector2, to: Vector2, col: Color, w: float, head: float) -> void:
	var d: Vector2 = (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	ci.draw_line(from, to - d * head * 0.5, col, w, true)
	ViewUtil.fill_poly(ci, PackedVector2Array([to, to - d * head + n * head * 0.62, to - d * head - n * head * 0.62]), col)


## Target ring on a marked caterpillar, the circle it must leave to dodge and a dotted line from the boss; grey once it is safe.
static func _draw_mark(ci: CanvasItem, mark: Dictionary, f: Variant, dodge: float, dodged: bool, bpos: Vector2, t: float) -> void:
	var col: Color = SAFE if dodged else DANGER
	var mpos: Vector2 = mark.get("pos", bpos)
	if dodge > 0.0:
		ViewUtil.fill_ellipse(ci, mpos, dodge, dodge, Color(col, 0.05 if dodged else 0.09))
		ViewUtil.dashed_circle(ci, mpos, dodge, 8.0, 7.0, Color(col, 0.35 if dodged else 0.6), 1.6)
	if f == null or not ViewUtil.gb(f, "alive"):
		return
	var fpos: Vector2 = ViewUtil.pos(f)
	var ring: float = ViewUtil.gf(f, "r", 10.0) + 9.0 + (0.0 if dodged else sin(t * 8.0) * 1.8)
	var ia: float = 0.55 if dodged else 1.0
	ci.draw_arc(fpos, ring, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 0.55 * ia), 4.4, true)
	ci.draw_arc(fpos, ring, 0.0, TAU, 32, Color(col, ia), 2.6, true)
	for k in 4:
		var a: float = float(k) * PI * 0.5 + (0.0 if dodged else t * 1.5)
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(fpos + d * (ring - 4.0), fpos + d * (ring + 6.0), Color(col, ia), 2.4, true)
	if not dodged:
		ViewUtil.dashed(ci, PackedVector2Array([bpos, fpos]), 6.0, 7.0, Color(col, 0.5), 1.6)


## True when world point `p` falls inside the band of the screen the HUD covers at the top.
static func under_hud(ctx: ViewCtx, p: Vector2) -> bool:
	var sy: float = ctx.view_size.y * 0.5 + (p.y - ctx.cam_pos.y) * ctx.scale_px
	return sy < (130.0 if ctx.view_size.y <= 540.0 else 200.0)


## A speech-bubble-like label (constant on-screen size) with a pointer, centred on `at`; the text is kept inside the world width.
## With `below` the bubble hangs under `at` and the pointer is on its top edge (used when there is no room above, under the HUD).
static func draw_bubble(ci: CanvasItem, ctx: ViewCtx, text: String, at: Vector2, col: Color, below: bool = false) -> void:
	var size: int = _screen_size(ctx, BUBBLE_SIZE)
	var k: float = float(size) / BUBBLE_SIZE
	var tw: float = ViewUtil.text_w(text, size) + 22.0 * k
	var h: float = 24.0 * k
	var p := Vector2(clampf(at.x, tw * 0.5 + 4.0, 3200.0 - tw * 0.5 - 4.0), at.y)
	var top: float = p.y + 8.0 * k if below else maxf(p.y, h + 4.0) - h
	var rect := Rect2(p.x - tw * 0.5, top, tw, h)
	ViewUtil.fill_round_rect(ci, rect, h * 0.45, Color(0.0588, 0.0706, 0.098, 0.93))
	ViewUtil.stroke_round_rect(ci, rect, h * 0.45, col, 2.0 * k)
	if below:
		ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(p.x - 5.0 * k, top + 1.0), Vector2(p.x + 5.0 * k, top + 1.0), Vector2(p.x, top - 7.0 * k)]), col)
	else:
		ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(p.x - 5.0 * k, rect.end.y - 1.0), Vector2(p.x + 5.0 * k, rect.end.y - 1.0), Vector2(p.x, rect.end.y + 7.0 * k)]), col)
	ViewUtil.text(ci, text, Vector2(p.x, top + h * 0.5 + float(size) * 0.36), size, ViewColors.SPEECH_TEXT)


# ---------------------------------------------------------------- vulnerable

static func _draw_vulnerable(ci: CanvasItem, ctx: ViewCtx, tag_y: float, up: bool) -> void:
	var x: float = ViewUtil.gf(ctx.boss, "x")
	var size: int = _screen_size(ctx, 17.0)
	var text: String = ViewUtil.tr_text("BOSS_VULNERABLE").to_upper()
	var at := Vector2(x, tag_y)
	ViewUtil.text(ci, text, at + Vector2(1.5, 1.5), size, Color(0.0, 0.0, 0.0, 0.7))
	ViewUtil.text(ci, text, at, size, GOLD)
	var k: float = float(size) / 17.0
	if up:
		var ay: float = at.y + float(size) * 0.45 + 3.0
		ViewUtil.fill_poly(ci, PackedVector2Array([Vector2(at.x, ay + 9.0 * k), Vector2(at.x - 6.0 * k, ay), Vector2(at.x + 6.0 * k, ay)]), GOLD)


# ---------------------------------------------------------------- statuses

static func _draw_statuses(ci: CanvasItem, ctx: ViewCtx) -> void:
	for f in ctx.fighters:
		var st: Variant = ViewUtil.g(f, "statuses", {})
		if not st is Dictionary or (st as Dictionary).is_empty() or not ViewUtil.gb(f, "alive") or ViewUtil.gb(f, "drowning"):
			continue
		var n: int = 0
		var base := Vector2(ViewUtil.gf(f, "x"), ViewUtil.gf(f, "y") - (74.0 if f == ctx.active else 44.0))
		for id: String in st:
			draw_status(ci, id, int((st as Dictionary)[id]), base + Vector2(float(n) * 30.0, 0.0), ctx.t_now)
			n += 1


## One status badge centred on `at`: a dark pill with the icon of the status and the turns left.
static func draw_status(ci: CanvasItem, id: String, turns: int, at: Vector2, t: float) -> void:
	var rect := Rect2(at.x - 14.0, at.y - 8.5, 28.0, 17.0)
	ViewUtil.fill_round_rect(ci, rect, 8.0, Color(0.0431, 0.0549, 0.0863, 0.88))
	ViewUtil.stroke_round_rect(ci, rect, 8.0, Color("#d88aff"), 1.4)
	if id == "PARASITE":
		_eggs_icon(ci, at + Vector2(-6.5, 0.5), t)
	else:
		ci.draw_circle(at + Vector2(-6.5, 0.0), 4.2, Color("#d88aff"))
		ViewUtil.text(ci, "!", at + Vector2(-6.5, 3.4), 10, Color("#241230"))
	ViewUtil.text(ci, str(turns), at + Vector2(7.0, 4.0), 12, ViewColors.NAME_TEXT)


## Three little pale eggs in a clump (the fly's eggs on the caterpillar's back).
static func _eggs_icon(ci: CanvasItem, c: Vector2, t: float) -> void:
	var wob: float = sin(t * 4.0) * 0.4
	for p: Vector3 in [Vector3(-2.6, 1.6, 0.0), Vector3(2.4, 1.8, 0.0), Vector3(0.0, -2.2 + wob, 0.0)]:
		var e: Vector2 = c + Vector2(p.x, p.y)
		ViewUtil.ellipse_fs(ci, e, 2.7, 3.4, Color("#f6efd2"), Color("#6b5a2a"), 0.9, 0.3 * p.x)
		ci.draw_circle(e + Vector2(-0.6, -0.9), 0.55, Color(1, 1, 1, 0.9))

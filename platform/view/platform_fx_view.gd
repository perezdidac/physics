## Small effects of the platformer drawn in front of the actors: pickup sparkles, dust puffs, floating texts, and the few needles
## of a tuft in front of a hidden egg.
class_name PlatformFxView
extends Node2D

## Registry ids this view draws through (checked by the registry test).
const ART_KINDS: Array[String] = ["tuft_front", "platform:pupa", "platform:moth"]

var _actx := ArtContext.new()

var t_now: float = 0.0
## Where Perleta hides: needles are drawn at this ground point while `hiding` is true.
var hide_ground: Vector2 = Vector2.ZERO
var hiding: bool = false

## Seconds since the egg started hatching, or -1 when no hatching is shown.
var hatch_t: float = -1.0
var hatch_pos: Vector2 = Vector2.ZERO

const HATCH_CRACK: float = 0.9
## Seconds before the pupa's husk splits and the moth comes out.
const META_CRACK: float = 1.3
## Seconds between two eggs of the final scene.
const EGG_GAP: float = 0.28
const EGG_COUNT: int = 7
const SHELL := "#f6efdc"
const SHELL_EDGE := "#b8a77f"

## Seconds since the pupa started to open (-1 = not shown) and where.
var meta_t: float = -1.0
var meta_pos: Vector2 = Vector2.ZERO
## Seconds since the moth started to lay her eggs (-1 = not shown) and where.
var lay_t: float = -1.0
var lay_pos: Vector2 = Vector2.ZERO
var lay_dir: float = 1.0

var _sparks: Array[Dictionary] = []
var _texts: Array[Dictionary] = []


## A burst of `count` glowing sparks around `pos`.
func sparkle(pos: Vector2, color: Color, count: int = 12) -> void:
	for i in count:
		var a: float = float(i) / float(count) * TAU + randf() * 0.4
		var sp: float = 50.0 + randf() * 110.0
		_sparks.append({"p": pos, "v": Vector2(cos(a), sin(a)) * sp, "life": 0.0, "max": 0.45 + randf() * 0.3, "c": color, "s": 2.0 + randf() * 2.5, "g": 0.0})


## Dust kicked up at the feet.
func dust(pos: Vector2, count: int = 6) -> void:
	for i in count:
		var dir: float = -1.0 if i % 2 == 0 else 1.0
		_sparks.append({"p": pos + Vector2(randf() * 6.0 * dir, 0.0), "v": Vector2(dir * (20.0 + randf() * 50.0), -10.0 - randf() * 25.0), "life": 0.0, "max": 0.35 + randf() * 0.2, "c": Color(0.85, 0.74, 0.55, 0.7), "s": 3.0 + randf() * 2.0, "g": 30.0})


## A short poof of dust and sparks where an ant was stomped.
func poof(pos: Vector2) -> void:
	dust(pos + Vector2(0.0, 8.0), 8)
	sparkle(pos, Color(1.0, 0.95, 0.7, 1.0), 8)


## Soil crumbs thrown from `pos` in direction `dir` (the pupa digging).
func crumbs(pos: Vector2, dir: Vector2, count: int = 2) -> void:
	for i in count:
		var spread: Vector2 = Vector2(randf() - 0.5, randf() - 0.7) * 70.0
		var cols: Array[Color] = [Color(0.45, 0.31, 0.19, 1.0), Color(0.36, 0.24, 0.14, 1.0), Color(0.58, 0.42, 0.26, 1.0)]
		_sparks.append({"p": pos, "v": dir * (40.0 + randf() * 50.0) + spread, "life": 0.0, "max": 0.35 + randf() * 0.25, "c": cols[i % 3], "s": 2.0 + randf() * 1.8, "g": 90.0})


## A cloud of soil dust, `count` puffs (a stone landing).
func soil_dust(pos: Vector2, count: int = 10) -> void:
	for i in count:
		var dir: float = -1.0 if i % 2 == 0 else 1.0
		_sparks.append({"p": pos + Vector2(randf() * 14.0 * dir, -randf() * 4.0), "v": Vector2(dir * (30.0 + randf() * 70.0), -20.0 - randf() * 40.0), "life": 0.0, "max": 0.5 + randf() * 0.4, "c": Color(0.6, 0.45, 0.3, 0.75), "s": 4.0 + randf() * 4.0, "g": 10.0})


## Shows the pupa's husk cracking and the moth unfolding her wings at `pos`.
func metamorphosis(pos: Vector2) -> void:
	meta_t = 0.0
	meta_pos = pos


## Shows the moth laying her eggs one by one around `pos` (`dir` is her facing).
func lay_eggs(pos: Vector2, dir: float) -> void:
	lay_t = 0.0
	lay_pos = pos
	lay_dir = dir


## A rising text at `pos`.
func float_text(pos: Vector2, text: String, color: Color) -> void:
	_texts.append({"p": pos, "t": text, "c": color, "life": 0.0})


## Shows the egg cracking and a tiny caterpillar popping out at `pos` (the egg's centre).
func hatch(pos: Vector2) -> void:
	hatch_t = 0.0
	hatch_pos = pos


## Advances the effects by `dt`.
func update(dt: float) -> void:
	if hatch_t >= 0.0:
		var before: float = hatch_t
		hatch_t += dt
		if before < HATCH_CRACK and hatch_t >= HATCH_CRACK:
			sparkle(hatch_pos + Vector2(0.0, -6.0), Color(1.0, 0.95, 0.65, 1.0), 22)
	if meta_t >= 0.0:
		var before_m: float = meta_t
		meta_t += dt
		if before_m < META_CRACK and meta_t >= META_CRACK:
			sparkle(meta_pos, Color(1.0, 0.95, 0.7, 1.0), 26)
	if lay_t >= 0.0:
		var n_before: int = mini(int(lay_t / EGG_GAP), EGG_COUNT)
		lay_t += dt
		var n_now: int = mini(int(lay_t / EGG_GAP), EGG_COUNT)
		if n_now > n_before:
			sparkle(_egg_pos(n_now - 1), Color(1.0, 0.95, 0.75, 1.0), 8)
	for s in _sparks:
		s["life"] += dt
		s["v"] = (s["v"] as Vector2) * (1.0 - minf(dt * 3.0, 1.0)) + Vector2(0.0, s["g"] * dt * 3.0)
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * dt
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s["life"] < s["max"])
	for tx in _texts:
		tx["life"] += dt
		tx["p"] = (tx["p"] as Vector2) + Vector2(0.0, -34.0 * dt)
	_texts = _texts.filter(func(tx: Dictionary) -> bool: return tx["life"] < 1.3)
	queue_redraw()


## Number of live sparks and texts (for tests).
func live_count() -> int:
	return _sparks.size() + _texts.size()


func _draw() -> void:
	if hatch_t >= 0.0:
		_draw_hatch()
	if meta_t >= 0.0:
		_draw_meta()
	if lay_t >= 0.0:
		_draw_lay()
	if hiding:
		_actx.t = t_now
		ArtRegistry.draw("tuft_front", self, {"ground": hide_ground, "seed": 3}, _actx)
	for s in _sparks:
		var k: float = 1.0 - float(s["life"]) / float(s["max"])
		var col: Color = s["c"]
		draw_circle(s["p"], float(s["s"]) * (0.4 + 0.6 * k), Color(col.r, col.g, col.b, col.a * k))
	for tx in _texts:
		var k: float = clampf(1.3 - float(tx["life"]), 0.0, 1.0)
		var col: Color = tx["c"]
		ViewUtil.text(self, str(tx["t"]), (tx["p"] as Vector2) + Vector2(1.0, 1.0), 16, Color(0, 0, 0, 0.5 * minf(k * 2.0, 1.0)))
		ViewUtil.text(self, str(tx["t"]), tx["p"], 16, Color(col.r, col.g, col.b, minf(k * 2.0, 1.0)))


## Wobbling shell with a growing crack, then the two halves fall apart and the caterpillar hops up and waves.
func _draw_hatch() -> void:
	var shell: Color = ViewColors.h(SHELL)
	var edge: Color = ViewColors.h(SHELL_EDGE)
	var c: Vector2 = hatch_pos + Vector2(0.0, 3.0)
	var t: float = hatch_t
	var split: float = clampf((t - HATCH_CRACK) / 0.35, 0.0, 1.0)
	# glow
	draw_circle(c + Vector2(0.0, -8.0), 40.0 + 10.0 * sin(t * 6.0), Color(1.0, 0.92, 0.55, 0.18 + 0.12 * split))
	var wob: float = sin(t * 38.0) * 0.12 * clampf(t / HATCH_CRACK, 0.0, 1.0) * (1.0 - split)
	var egg_c: Vector2 = c + Vector2(0.0, -2.0)
	if split <= 0.0:
		draw_set_transform(egg_c + Vector2(0.0, 11.0), wob, Vector2.ONE)
		var body := PackedVector2Array(ViewUtil.ellipse_pts(Vector2(0.0, -11.0), 11.5, 13.5))
		draw_colored_polygon(body, shell)
		draw_polyline(_closed(body), edge, 1.5, true)
		var k: float = clampf(t / HATCH_CRACK, 0.0, 1.0)
		var crack := PackedVector2Array([Vector2(-10.0, -12.0), Vector2(-6.0, -15.0), Vector2(-3.0, -10.0), Vector2(1.0, -16.0), Vector2(5.0, -10.0), Vector2(8.0, -14.0), Vector2(11.0, -11.0)])
		var shown: int = clampi(int(ceilf(k * float(crack.size()))), 0, crack.size())
		if shown >= 2:
			draw_polyline(crack.slice(0, shown), Color(0.25, 0.18, 0.1, 0.9), 1.8, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# the caterpillar, popping up behind the two halves
	var rise: float = clampf((t - HATCH_CRACK) / 0.5, 0.0, 1.0)
	var pop: float = sin(rise * PI * 0.5)
	var bounce: float = absf(sin((t - HATCH_CRACK) * 6.0)) * 5.0 * clampf(rise * 2.0 - 0.6, 0.0, 1.0)
	_draw_baby(c + Vector2(0.0, 2.0 - 20.0 * pop - bounce), rise)
	# bottom half: a cup tilting slightly; top half: flung up and sideways, spinning
	draw_set_transform(c + Vector2(0.0, 11.0 + 4.0 * split), 0.12 * split, Vector2.ONE)
	var cup := PackedVector2Array()
	for p in ViewUtil.ellipse_pts(Vector2(0.0, -11.0), 11.5, 13.5):
		if p.y >= -12.0 + (sin(p.x * 0.9) * 2.5):
			cup.append(p)
	if cup.size() >= 3:
		draw_colored_polygon(cup, shell)
		draw_polyline(cup, edge, 1.5, true)
	var fly: float = split
	draw_set_transform(c + Vector2(-8.0 * fly - 6.0 * fly * fly * 5.0, 6.0 - 34.0 * fly + 60.0 * pow(maxf(t - HATCH_CRACK - 0.35, 0.0), 2.0)), -0.7 * fly - maxf(t - HATCH_CRACK - 0.35, 0.0), Vector2.ONE)
	var lid := PackedVector2Array()
	for p in ViewUtil.ellipse_pts(Vector2(0.0, 0.0), 11.5, 13.5):
		if p.y < -1.0 + (sin(p.x * 0.9) * 2.5):
			lid.append(p)
	if lid.size() >= 3:
		draw_colored_polygon(lid, shell)
		draw_polyline(lid, edge, 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out


## A tiny caterpillar: four furry segments, big eyes and a happy mouth, waving a front leg.
func _draw_baby(center: Vector2, k: float) -> void:
	var c := Vector2.ZERO
	draw_set_transform(center, 0.0, Vector2(1.7, 1.7))
	var dark: Color = ViewColors.h("#3b2a1a")
	var seg_cols: Array[String] = ["#c9a26a", "#b98a4e", "#c9a26a", "#b98a4e"]
	for i in 4:
		var sp := c + Vector2(-9.0 + 6.0 * float(3 - i), -sin(t_now * 9.0 + float(i)) * 1.2 + float(i) * 2.0 * (1.0 - k))
		ViewUtil.fill_ellipse(self, sp, 5.5, 5.0, ViewColors.h(seg_cols[i]))
		ViewUtil.stroke_ellipse(self, sp, 5.5, 5.0, dark, 1.0)
		for h in 3:
			var hx: float = sp.x - 2.5 + float(h) * 2.5
			draw_line(Vector2(hx, sp.y - 4.5), Vector2(hx + (float(h) - 1.0) * 1.5, sp.y - 8.0), Color(1.0, 0.7, 0.3, 0.85), 1.0, true)
	var head := c + Vector2(11.0, -1.0)
	ViewUtil.fill_ellipse(self, head, 6.5, 6.0, ViewColors.h("#5a3a22"))
	ViewUtil.stroke_ellipse(self, head, 6.5, 6.0, dark, 1.0)
	for ex: float in [-1.8, 2.6]:
		draw_circle(head + Vector2(ex, -1.0), 2.1, Color.WHITE)
		draw_circle(head + Vector2(ex + 0.6, -0.8), 1.0, Color(0.1, 0.07, 0.05, 1.0))
	draw_arc(head + Vector2(0.5, 1.2), 2.4, 0.3, PI - 0.3, 6, Color(1.0, 0.8, 0.7, 1.0), 1.0, true)
	var wave: float = sin(t_now * 12.0) * 0.5
	draw_line(c + Vector2(6.0, 3.0), c + Vector2(10.0 + wave * 3.0, -8.0), dark, 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The husk wobbles and cracks, splits, and a moth with crumpled wings climbs out and spreads them.
func _draw_meta() -> void:
	var t: float = meta_t
	var c: Vector2 = meta_pos
	var split: float = clampf((t - META_CRACK) / 0.4, 0.0, 1.0)
	draw_circle(c, 46.0 + 10.0 * sin(t * 6.0), Color(1.0, 0.92, 0.6, 0.12 + 0.14 * split))
	if t < META_CRACK:
		var k: float = clampf(t / META_CRACK, 0.0, 1.0)
		_actx.t = t_now
		ArtRegistry.draw("platform:pupa", self, {"r": 11.0, "o": {"wiggle": k, "blink": 1.0, "base": Transform2D(sin(t * 40.0) * 0.1 * k, Vector2(1.8, 1.8), 0.0, c)}}, _actx)
		var crack := PackedVector2Array([c + Vector2(-8.0, -22.0), c + Vector2(-2.0, -14.0), c + Vector2(-6.0, -6.0), c + Vector2(2.0, 2.0), c + Vector2(-3.0, 10.0), c + Vector2(4.0, 18.0)])
		var shown: int = clampi(int(ceilf(k * float(crack.size()))), 0, crack.size())
		if shown >= 2:
			draw_polyline(crack.slice(0, shown), Color(1.0, 0.95, 0.6, 0.95), 2.2, true)
		return
	var rise: float = clampf((t - META_CRACK) / 1.0, 0.0, 1.0)
	var open: float = clampf((t - META_CRACK - 0.5) / 1.1, 0.0, 1.0)
	# the empty husk sinks and fades
	draw_set_transform(c + Vector2(0.0, 10.0 * split), 0.2 * split, Vector2(1.8, 1.8))
	var husk := PackedVector2Array()
	for p in ViewUtil.ellipse_pts(Vector2(0.0, 0.0), 7.0, 12.0):
		husk.append(p)
	draw_colored_polygon(husk, Color(0.45, 0.3, 0.18, 0.7 * (1.0 - open)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the moth: small and wet at first, then big with open wings
	var sc: float = lerpf(0.9, 1.9, open)
	var mpos: Vector2 = c + Vector2(0.0, -22.0 * sin(rise * PI * 0.5) - 6.0 * open)
	_actx.t = t_now
	ArtRegistry.draw("platform:moth", self, {"r": 13.0, "o": {"facing": 1.0, "flap": lerpf(0.9, -0.2 + sin(t_now * 8.0) * 0.5, open), "glow": open, "base": Transform2D(0.0, Vector2(sc, sc), 0.0, mpos)}}, _actx)


func _egg_pos(i: int) -> Vector2:
	var fi: float = float(i)
	return lay_pos + Vector2(lay_dir * (-30.0 + fi * 12.0) + sin(fi * 2.1) * 6.0, 26.0 + absf(sin(fi * 1.7)) * 10.0)


## Eggs appear one after the other, glowing, while a soft light grows around them.
func _draw_lay() -> void:
	var n: int = mini(int(lay_t / EGG_GAP) + 1, EGG_COUNT)
	var glow: float = clampf(lay_t / 2.0, 0.0, 1.0)
	var mid: Vector2 = lay_pos + Vector2(0.0, 34.0)
	for q in 6:
		draw_circle(mid, (150.0 - float(q) * 20.0) * (0.5 + 0.5 * glow), Color(1.0, 0.92, 0.6, 0.02 + 0.02 * float(q) * glow))
	for i in n:
		var born: float = lay_t - float(i) * EGG_GAP
		var pop: float = clampf(born / 0.25, 0.0, 1.0)
		var k: float = 1.0 + 0.3 * sin(pop * PI) * (1.0 - pop)
		var p: Vector2 = _egg_pos(i) + Vector2(0.0, -14.0 * (1.0 - pop))
		draw_circle(p, 12.0 * k, Color(1.0, 0.95, 0.7, 0.2 * pop))
		ViewUtil.fill_ellipse(self, p, 5.2 * k, 6.6 * k, ViewColors.h(SHELL))
		ViewUtil.stroke_ellipse(self, p, 5.2 * k, 6.6 * k, ViewColors.h(SHELL_EDGE), 1.0)
		ViewUtil.fill_ellipse(self, p + Vector2(-1.5, -2.0), 1.5, 2.2, Color(1.0, 1.0, 1.0, 0.6))

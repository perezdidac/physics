## The FLY-mode scenery and enemies, drawn procedurally: street lamps (post, lantern, a warm light cone, a halo and a swirl that shows the
## pull), pheromone traps (sticky delta traps), nightjars with their sight area, and the shadows. One instance per layer:
## "back" (lamp posts and cones, traps; drawn under the moth) and "front" (nightjars, halos, swirls, shadows; drawn over her so a
## shadow darkens her). It reads the sim's PlatformFly and the layout; it keeps no game state apart from fades.
class_name PlatformFlyView
extends Node2D

## Registry ids this view draws through (checked by the registry test).
const ART_KINDS: Array[String] = ["platform:nightjar"]

var _actx := ArtContext.new()

const LAMP_WARM := Color(1.0, 0.82, 0.45, 1.0)
const POST := "#2e2a33"

## "back" or "front".
var layer_name: String = "back"
var fly: Variant = null
var layout: PlatformLayout = null
var t_now: float = 0.0
var view_rect: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
## Where the player is (swirl particles and the "!" of the nightjars follow her).
var player_pos: Vector2 = Vector2.ZERO

var _posts: Array[float] = []
var _shadow_a: Array[float] = []
var _jar_prev: Array[Vector2] = []
var _jar_cur: Array[Vector2] = []
var _jar_state: Array[String] = []
var _jar_mark_t: Array[float] = []
var _interp: float = 1.0


## Binds the level; computes the foot of every lamp post (the first solid under it, or the bottom of the world).
func setup(p_fly: Variant, p_layout: PlatformLayout) -> void:
	fly = p_fly
	layout = p_layout
	_posts.clear()
	for l in layout.lights:
		var foot: float = layout.size.y
		for r in layout.solids:
			if l.x >= r.position.x and l.x <= r.end.x and r.position.y > l.y and r.position.y < foot:
				foot = r.position.y
		_posts.append(foot)
	_shadow_a.clear()
	for i in layout.shadows.size():
		_shadow_a.append(1.0)
	_jar_prev.clear()
	_jar_cur.clear()
	_jar_state.clear()
	_jar_mark_t.clear()
	for n in _jars():
		_jar_prev.append(ViewUtil.g(n, "pos", Vector2.ZERO))
		_jar_cur.append(ViewUtil.g(n, "pos", Vector2.ZERO))
		_jar_state.append("PATROL")
		_jar_mark_t.append(0.0)


func _jars() -> Array:
	return ViewUtil.g(fly, "nightjars", []) as Array


## Records bird positions at the end of a simulation step (for interpolation).
func record(first: bool) -> void:
	var jars: Array = _jars()
	for i in jars.size():
		var p: Vector2 = ViewUtil.g(jars[i], "pos", Vector2.ZERO)
		_jar_prev[i] = p if first else _jar_cur[i]
		_jar_cur[i] = p


## Advances fades and redraws.
func present(alpha: float, delta: float) -> void:
	var jars: Array = _jars()
	for i in jars.size():
		var st: String = ViewUtil.gs(jars[i], "state", "PATROL")
		if st != _jar_state[i]:
			_jar_state[i] = st
			_jar_mark_t[i] = 0.0
		_jar_mark_t[i] += delta
	for i in layout.shadows.size():
		var on: bool = bool(fly.call("shadow_active", i))
		_shadow_a[i] = move_toward(_shadow_a[i], 1.0 if on else 0.0, delta * 3.5)
	_interp = alpha
	queue_redraw()


func _draw() -> void:
	if layout == null or fly == null:
		return
	var view: Rect2 = view_rect.grow(260.0)
	if layer_name == "back":
		for i in layout.lights.size():
			var l: Vector3 = layout.lights[i]
			if Rect2(l.x - l.z, l.y - l.z, l.z * 2.0, l.z * 2.0 + 300.0).intersects(view):
				_lamp_back(i, l)
		for i in layout.traps.size():
			if layout.traps[i].grow(80.0).intersects(view):
				_trap(i, layout.traps[i])
	else:
		for i in layout.lights.size():
			var l: Vector3 = layout.lights[i]
			if Rect2(l.x - l.z, l.y - l.z, l.z * 2.0, l.z * 2.0).intersects(view):
				_lamp_front(i, l)
		var jars: Array = _jars()
		for i in jars.size():
			_nightjar(i, jars[i])
		for i in layout.shadows.size():
			_shadow(i)


# ---------------------------------------------------------------- lamps

## Post, lantern and the warm cone of light below it.
func _lamp_back(i: int, l: Vector3) -> void:
	var c := Vector2(l.x, l.y)
	var foot: float = _posts[i] if i < _posts.size() else layout.size.y
	var post: Color = ViewColors.h(POST)
	if foot > c.y + 14.0:
		draw_rect(Rect2(c.x - 3.0, c.y + 12.0, 6.0, foot - c.y - 12.0), post)
		draw_rect(Rect2(c.x - 1.0, c.y + 12.0, 2.0, foot - c.y - 12.0), Color(1.0, 1.0, 1.0, 0.1))
		draw_rect(Rect2(c.x - 7.0, foot - 8.0, 14.0, 8.0), post)
	# light cone: bright at the lantern, gone at the bottom
	var f: float = float(fly.call("lamp_pull", i))
	var flick: float = 0.92 + 0.08 * sin(t_now * 9.0 + float(i) * 2.0) * sin(t_now * 3.1 + float(i))
	var depth: float = minf(l.z * 1.5, maxf(foot - c.y, 60.0))
	var half: float = l.z * 0.62
	var a0: float = (0.34 + 0.2 * f) * flick
	var cone := PackedVector2Array([c + Vector2(-9.0, 8.0), c + Vector2(9.0, 8.0), c + Vector2(half, depth), c + Vector2(-half, depth)])
	var top := Color(LAMP_WARM, a0)
	var bot := Color(LAMP_WARM, 0.0)
	draw_polygon(cone, PackedColorArray([top, top, bot, bot]))
	var inner := PackedVector2Array([c + Vector2(-6.0, 8.0), c + Vector2(6.0, 8.0), c + Vector2(half * 0.45, depth * 0.8), c + Vector2(-half * 0.45, depth * 0.8)])
	var top2 := Color(1.0, 0.95, 0.75, a0 * 0.55)
	draw_polygon(inner, PackedColorArray([top2, top2, Color(top2, 0.0), Color(top2, 0.0)]))
	# lantern housing
	draw_colored_polygon(PackedVector2Array([c + Vector2(-11.0, -8.0), c + Vector2(11.0, -8.0), c + Vector2(15.0, -15.0), c + Vector2(0.0, -23.0), c + Vector2(-15.0, -15.0)]), post)
	draw_rect(Rect2(c.x - 11.0, c.y + 7.0, 22.0, 4.0), post)
	draw_rect(Rect2(c.x - 9.0, c.y - 8.0, 18.0, 15.0), Color(1.0, 0.93, 0.62, 0.95))
	for q in 2:
		draw_line(Vector2(c.x - 3.0 + float(q) * 6.0, c.y - 8.0), Vector2(c.x - 3.0 + float(q) * 6.0, c.y + 7.0), Color(post, 0.55), 1.2)
	draw_rect(Rect2(c.x - 11.0, c.y - 8.0, 22.0, 15.0), post, false, 2.0)


## Halo, the swirl that shows the pull and little moths dancing round the bulb.
func _lamp_front(i: int, l: Vector3) -> void:
	var c := Vector2(l.x, l.y)
	var f: float = float(fly.call("lamp_pull", i))
	var flick: float = 0.92 + 0.08 * sin(t_now * 9.0 + float(i) * 2.0)
	for q in 6:
		draw_circle(c, 46.0 - float(q) * 7.0, Color(1.0, 0.85, 0.45, (0.035 + 0.02 * float(q)) * flick))
	draw_circle(c, 9.0, Color(1.0, 0.98, 0.85, 0.95))
	# the pull: a faint dashed edge at the radius, and arms of a spiral flowing in (brighter as she is dragged harder)
	var edge_a: float = 0.08 + 0.3 * f
	ViewUtil.dashed_circle(self, c, l.z, 10.0, 14.0, Color(1.0, 0.85, 0.5, edge_a), 1.5)
	var arms: int = 3
	for a in arms:
		var pts := PackedVector2Array()
		for k in 18:
			var u: float = float(k) / 17.0
			var rr: float = lerpf(l.z * 0.96, 16.0, u)
			var an: float = float(a) / float(arms) * TAU + u * 3.6 - t_now * (0.8 + 1.4 * f)
			pts.append(c + Vector2(cos(an), sin(an)) * rr)
		draw_polyline(pts, Color(1.0, 0.88, 0.55, 0.05 + 0.22 * f), 1.6, true)
		# a mote riding the arm
		var ph: float = fposmod(t_now * (0.35 + 0.5 * f) + float(a) / float(arms), 1.0)
		var rr2: float = lerpf(l.z * 0.96, 16.0, ph)
		var an2: float = float(a) / float(arms) * TAU + ph * 3.6 - t_now * (0.8 + 1.4 * f)
		draw_circle(c + Vector2(cos(an2), sin(an2)) * rr2, 2.0, Color(1.0, 0.95, 0.75, 0.25 + 0.6 * f))
	# little moths fluttering round the lamp
	for q in 4:
		var fq: float = float(q)
		var an3: float = t_now * (1.1 + fq * 0.25) + fq * 1.7 + float(i)
		var rr3: float = 22.0 + 9.0 * sin(t_now * 1.3 + fq * 2.0)
		var mp: Vector2 = c + Vector2(cos(an3) * rr3, sin(an3 * 1.3) * rr3 * 0.7)
		var wing: float = sin(t_now * 26.0 + fq * 3.0) * 2.4
		draw_colored_polygon(PackedVector2Array([mp, mp + Vector2(-4.0, -2.0 - wing), mp + Vector2(-5.5, 1.0)]), Color(0.9, 0.85, 0.75, 0.85))
		draw_colored_polygon(PackedVector2Array([mp, mp + Vector2(4.0, -2.0 - wing), mp + Vector2(5.5, 1.0)]), Color(0.9, 0.85, 0.75, 0.85))
		draw_circle(mp, 1.1, Color(0.35, 0.28, 0.2, 0.9))


# ---------------------------------------------------------------- traps

## A pheromone trap: a hanging delta trap with a green roof and a glossy sticky floor, a few unlucky insects stuck on it and sweet scent
## curling up from the lure.
func _trap(i: int, r: Rect2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t_now * 3.0 + float(i))
	# string to the top
	var top_x: float = r.get_center().x
	draw_line(Vector2(top_x, r.position.y - 36.0), Vector2(top_x, r.position.y - 6.0), Color(0.75, 0.7, 0.6, 0.9), 1.6, true)
	draw_circle(Vector2(top_x, r.position.y - 36.0), 2.4, Color(0.75, 0.7, 0.6, 0.9))
	# warning glow
	ViewUtil.fill_ellipse(self, r.get_center(), r.size.x * 0.75 + 12.0, r.size.y * 0.8 + 10.0, Color(1.0, 0.45, 0.6, 0.06 + 0.05 * pulse))
	# sticky floor
	var floor_r := Rect2(r.position.x + 2.0, r.position.y + r.size.y * 0.42, r.size.x - 4.0, r.size.y * 0.58)
	ViewUtil.fill_round_rect(self, floor_r, 3.0, ViewColors.h("#f2b428"))
	ViewUtil.fill_round_rect(self, Rect2(floor_r.position.x + 3.0, floor_r.position.y + 2.0, floor_r.size.x - 6.0, 3.0), 1.5, Color(1.0, 0.98, 0.8, 0.65))
	for q in 3:
		var gx: float = floor_r.position.x + floor_r.size.x * (0.2 + 0.3 * float(q))
		draw_line(Vector2(gx, floor_r.end.y), Vector2(gx + 1.0, floor_r.end.y + 4.0 + 3.0 * sin(t_now * 1.2 + float(q) + float(i))), Color(0.95, 0.72, 0.15, 0.9), 2.0, true)
		draw_circle(Vector2(gx + 1.0, floor_r.end.y + 5.0 + 3.0 * sin(t_now * 1.2 + float(q) + float(i))), 1.8, Color(0.98, 0.78, 0.2, 0.95))
	# stuck insects
	for q in 3:
		var bx: float = floor_r.position.x + floor_r.size.x * (0.18 + 0.32 * float(q))
		var by: float = floor_r.position.y + floor_r.size.y * 0.5
		ViewUtil.fill_ellipse(self, Vector2(bx, by), 3.2, 1.8, Color(0.2, 0.15, 0.1), float(q) * 0.7)
		draw_line(Vector2(bx - 3.0, by - 1.0), Vector2(bx - 5.0, by - 3.0), Color(0.2, 0.15, 0.1, 0.8), 1.0)
		draw_line(Vector2(bx + 3.0, by - 1.0), Vector2(bx + 5.0, by - 3.5), Color(0.2, 0.15, 0.1, 0.8), 1.0)
	# green roof
	var roof := PackedVector2Array([Vector2(r.position.x - 5.0, r.position.y + r.size.y * 0.46), Vector2(r.position.x + r.size.x * 0.5, r.position.y - 7.0), Vector2(r.end.x + 5.0, r.position.y + r.size.y * 0.46)])
	draw_colored_polygon(roof, ViewColors.h("#3e8a4c"))
	draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2]]), ViewColors.h("#245a30"), 2.0, true)
	draw_line(roof[0].lerp(roof[1], 0.5) + Vector2(2.0, 2.0), roof[1] + Vector2(-2.0, 3.0), Color(1.0, 1.0, 1.0, 0.25), 2.0, true)
	# the lure capsule and its scent
	var lc := Vector2(top_x, r.position.y + r.size.y * 0.3)
	ViewUtil.fill_ellipse(self, lc, 2.6, 4.2, ViewColors.h("#f0e8d4"))
	for q in 3:
		var pts := PackedVector2Array()
		var ph: float = fposmod(t_now * 0.6 + float(q) / 3.0 + float(i) * 0.3, 1.0)
		for k in 8:
			var u: float = float(k) / 7.0
			pts.append(Vector2(top_x + sin(u * 6.0 + t_now * 2.0 + float(q) * 2.0) * (4.0 + 5.0 * u), r.position.y - 4.0 - u * 26.0 - ph * 6.0))
		draw_polyline(pts, Color(1.0, 0.55, 0.75, 0.35 * (1.0 - ph)), 1.5, true)


# ---------------------------------------------------------------- nightjars

func _nightjar(i: int, n: Variant) -> void:
	var p: Vector2 = _jar_prev[i].lerp(_jar_cur[i], _interp)
	if _jar_prev[i].distance_to(_jar_cur[i]) > 200.0:
		p = _jar_cur[i]
	var state: String = ViewUtil.gs(n, "state", "PATROL")
	var facing: float = float(ViewUtil.gi(n, "facing", 1))
	var radius: float = ViewUtil.gf(n, "radius", 16.0)
	var vel: Vector2 = ViewUtil.g(n, "vel", Vector2.ZERO)
	var chase: bool = state == "CHASE"
	# sight: a soft pale disc of the sight range (the sim sees all round), brighter in front of the bird
	var sight: float = 220.0
	var col: Color = Color(1.0, 0.35, 0.25) if chase else Color(1.0, 0.92, 0.5)
	var pulse: float = 0.5 + 0.5 * sin(t_now * 6.0)
	ViewUtil.dashed_circle(self, p, sight, 12.0, 12.0, Color(col, 0.18 + (0.14 * pulse if chase else 0.0)), 1.5)
	var fwd := Vector2(facing, 0.0)
	var cone := PackedVector2Array([p + fwd * radius * 0.7])
	for k in 9:
		var an: float = (float(k) / 8.0 - 0.5) * 1.1
		cone.append(p + Vector2(cos(an) * facing, sin(an)) * sight)
	draw_polygon(cone, PackedColorArray([Color(col, 0.22), Color(col, 0.0), Color(col, 0.0), Color(col, 0.0), Color(col, 0.0), Color(col, 0.0), Color(col, 0.0), Color(col, 0.0), Color(col, 0.0), Color(col, 0.0)]))
	var o := {"base": Transform2D(0.0, Vector2(facing, 1.0), 0.0, p), "flap": sin(ViewUtil.gf(n, "flap") * 1.0), "alert": 1.0 if chase else 0.0, "chase": chase, "vy": vel.y}
	_actx.t = t_now
	ArtRegistry.draw("platform:nightjar", self, {"r": radius, "o": o}, _actx)
	var mt: float = _jar_mark_t[i]
	if (state == "CHASE" or state == "RETURN") and mt < 1.2:
		var mark: String = "!" if state == "CHASE" else "?"
		var mc: Color = Color(1.0, 0.3, 0.25) if state == "CHASE" else Color(1.0, 0.85, 0.3)
		ViewUtil.text(self, mark, p + Vector2(0.0, -radius - 12.0 - mt * 10.0), 24, Color(mc, clampf(1.2 - mt, 0.0, 1.0)))


# ---------------------------------------------------------------- shadows

## A dark, soft-edged area: the moth is hidden while she is inside while it is active; an inactive one shows only a faint outline.
func _shadow(i: int) -> void:
	var r: Rect2 = fly.call("shadow_rect", i)
	var a: float = _shadow_a[i]
	if not r.grow(40.0).intersects(view_rect):
		return
	# soft edges fade inwards over 18 px, so what looks dark is really the hiding area
	var feather: float = minf(18.0, minf(r.size.x, r.size.y) * 0.4)
	var layers: int = 9
	for k in layers:
		var inset: float = feather * float(k) / float(layers)
		draw_rect(r.grow(-inset), Color(0.02, 0.03, 0.09, (0.5 / float(layers)) * a))
	# slow drifting wisps so it reads as a patch of dark, not a box
	for q in 5:
		var fq: float = float(q)
		var wx: float = r.position.x + fposmod(fq * 61.0 + t_now * 9.0, r.size.x)
		var wy: float = r.position.y + r.size.y * (0.15 + 0.7 * fposmod(fq * 0.37 + 0.1 * sin(t_now * 0.5 + fq), 1.0))
		ViewUtil.fill_ellipse(self, Vector2(wx, wy), 26.0, 7.0, Color(0.0, 0.0, 0.05, 0.14 * a))
	var edge: Color = Color(0.55, 0.62, 0.9, 0.3 * (1.0 - a))
	if a < 0.99:
		ViewUtil.dashed(self, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), 8.0, 8.0, edge, 1.5)

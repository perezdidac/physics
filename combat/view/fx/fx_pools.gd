## Particle / effect pools of the battle (particles, fireballs, smoke, shockwaves, water plumes, ripples, bubbles, floating
## texts, speech bubbles). Spawned from the sim `effect` signal, updated and drawn by the view (main.js:353-438, renderer.js).
class_name FxPools
extends RefCounted

## JS smoke colours by sim style name.
const SMOKE_STYLES: Dictionary = {
	"dark": "rgba(32, 28, 26, 0.78)", "urticating": "rgba(168, 85, 235, 0.58)", "silk": "rgba(248, 244, 232, 0.78)",
	"ember": "rgba(235, 128, 52, 0.72)", "steam": "rgba(255, 242, 210, 0.82)", "dust": "rgba(210, 195, 175, 0.55)",
	"muzzle": "rgba(220, 210, 195, 0.5)", "flour": "rgba(248, 244, 236, 0.78)", "stone": "rgba(185, 175, 158, 0.65)",
}

## Pool caps (web build, one thread): when a pool is full the oldest entry is dropped.
const MAX_PARTICLES := 700
const MAX_SMOKES := 180
const MAX_FIREBALLS := 24
const MAX_SHOCKWAVES := 24
const MAX_PLUMES := 12
const MAX_RIPPLES := 12
const MAX_BUBBLES := 80
const MAX_FLOATS := 40

var rng := RandomNumberGenerator.new()
var particles: Array[Dictionary] = []
var fireballs: Array[Dictionary] = []
var smokes: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []
var plumes: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var bubbles: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var speeches: Array[Dictionary] = []
var touch_ripples: Array[Dictionary] = []


func _init() -> void:
	rng.randomize()


## Removes everything (new match).
func clear() -> void:
	particles.clear()
	fireballs.clear()
	smokes.clear()
	shockwaves.clear()
	plumes.clear()
	ripples.clear()
	bubbles.clear()
	floats.clear()
	speeches.clear()
	touch_ripples.clear()


## Drops the oldest entries of `pool` beyond `limit`.
func _cap(pool: Array[Dictionary], limit: int) -> void:
	while pool.size() > limit:
		pool.pop_front()


# ------------------------------------------------------------------ spawning

## Entry point for the sim `effect(kind, params)` signal. Kinds emitted by the sim: urticating_hairs, smoke (count + style),
## sparks, embers, debris, fireball, shockwave, water_plunge, flora_uproot, wine_splash, beam, bubbles, jet_flame, skid_smoke.
func spawn(kind: String, p: Dictionary) -> void:
	var x: float = float(p.get("x", 0.0))
	var y: float = float(p.get("y", 0.0))
	match kind:
		"smoke":
			if p.has("count"):
				spawn_smoke(x, y, int(p["count"]), SMOKE_STYLES.get(str(p.get("style", "dark")), p.get("color", "rgba(32, 28, 26, 0.78)")))
			else:
				add_smoke(p)
		"fireball":
			add_fireball(p)
		"shockwave":
			var sp: Dictionary = p.duplicate()
			if str(sp.get("color", "")) == "":
				sp["color"] = "255, 225, 175"
			add_shockwave(sp)
		"bubbles":
			add_bubble({"x": x, "y": y, "r": 2.0 + rng.randf() * 3.5, "vy": -45.0 - rng.randf() * 35.0})
		"urticating_hairs":
			spawn_hairs(x, y, int(p.get("count", 24)))
		"sparks":
			spawn_sparks(x, y, int(p.get("count", 10)))
		"embers":
			spawn_embers(x, y, int(p.get("count", 8)))
		"debris":
			spawn_debris(x, y, int(p.get("count", 8)))
		"water_plunge":
			spawn_water_plunge(x, y, float(p.get("scale", 1.0)))
		"flora_uproot":
			spawn_uproot(x, y, p)
		"wine_splash":
			spawn_wine(x, y)
		"beam":
			add_particle({"is_beam": true, "x1": p.get("x1", 0.0), "y1": p.get("y1", 0.0), "x2": p.get("x2", 0.0), "y2": p.get("y2", 0.0),
				"life": p.get("life", 0.22), "decay": 1.0})
		"jet_flame":
			add_particle({"x": x, "y": y, "vx": (rng.randf() - 0.5) * 35.0, "vy": 90.0 + rng.randf() * 60.0, "w": 3.0, "h": 3.0,
				"life": 0.35, "decay": 1.4, "color": "#ffae42" if rng.randf() > 0.4 else "#ff4e22", "is_spark": true})
		"skid_smoke":
			add_smoke({"x": x, "y": y, "vx": float(p.get("vx", 0.0)) + (rng.randf() - 0.5) * 20.0, "vy": -15.0 - rng.randf() * 25.0,
				"r": 4.0 + rng.randf() * 5.0, "vr": 10.0, "life": 0.45, "decay": 1.2, "color": "rgba(155, 132, 108, 0.48)"})
		_:
			pass


func add_particle(p: Dictionary) -> void:
	var d: Dictionary = {
		"x": float(p.get("x", 0.0)), "y": float(p.get("y", 0.0)), "vx": float(p.get("vx", 0.0)), "vy": float(p.get("vy", 0.0)),
		"w": float(p.get("w", 3.0)), "h": float(p.get("h", 3.0)), "rot": float(p.get("rot", 0.0)), "vrot": float(p.get("vrot", 0.0)),
		"life": float(p.get("life", 1.0)), "decay": float(p.get("decay", 1.0)), "color": ViewColors.parse(p.get("color", "#ffffff")),
		"is_beam": bool(p.get("is_beam", false)), "is_ember": bool(p.get("is_ember", false)), "is_hair": bool(p.get("is_hair", false)),
		"is_spark": bool(p.get("is_spark", false)), "collides": bool(p.get("collides_terrain", false)),
		"x1": float(p.get("x1", 0.0)), "y1": float(p.get("y1", 0.0)), "x2": float(p.get("x2", 0.0)), "y2": float(p.get("y2", 0.0)),
	}
	particles.append(d)
	_cap(particles, MAX_PARTICLES)


func add_smoke(p: Dictionary) -> void:
	smokes.append({
		"x": float(p.get("x", 0.0)), "y": float(p.get("y", 0.0)), "vx": float(p.get("vx", 0.0)), "vy": float(p.get("vy", 0.0)),
		"r": float(p.get("r", 10.0)), "vr": float(p.get("vr", 20.0)), "life": float(p.get("life", 1.0)), "decay": float(p.get("decay", 0.7)),
		"color": ViewColors.parse(p.get("color", "rgba(32, 28, 26, 0.78)")),
	})
	_cap(smokes, MAX_SMOKES)


func add_fireball(p: Dictionary) -> void:
	fireballs.append({
		"x": float(p.get("x", 0.0)), "y": float(p.get("y", 0.0)), "r": float(p.get("r", 10.0)), "max_r": float(p.get("max_r", 30.0)),
		"life": float(p.get("life", 1.0)), "decay": float(p.get("decay", 2.35)), "urt": bool(p.get("urticating", p.get("is_urticating", false))),
		"holy": bool(p.get("is_holy", false)),
	})
	_cap(fireballs, MAX_FIREBALLS)


func add_shockwave(p: Dictionary) -> void:
	shockwaves.append({
		"x": float(p.get("x", 0.0)), "y": float(p.get("y", 0.0)), "r": float(p.get("r", 8.0)), "max_r": float(p.get("max_r", 60.0)),
		"alpha": float(p.get("alpha", 1.0)), "color": ViewColors.parse(p.get("color", "255, 225, 175")),
	})
	_cap(shockwaves, MAX_SHOCKWAVES)


func add_plume(p: Dictionary) -> void:
	plumes.append({
		"x": float(p.get("x", 0.0)), "y": float(p.get("y", 0.0)), "h": float(p.get("h", 0.0)), "max_h": float(p.get("max_h", 80.0)),
		"w": float(p.get("w", 26.0)), "ring_r": float(p.get("ring_r", 8.0)), "max_ring_r": float(p.get("max_ring_r", 75.0)), "life": float(p.get("life", 1.0)),
	})
	_cap(plumes, MAX_PLUMES)


func add_ripple(p: Dictionary) -> void:
	ripples.append({"x": float(p.get("x", 0.0)), "amp": float(p.get("amp", 14.0)), "life": float(p.get("life", 1.0)), "phase": 0.0})
	_cap(ripples, MAX_RIPPLES)


func add_bubble(p: Dictionary) -> void:
	bubbles.append({
		"x": float(p.get("x", 0.0)), "y": float(p.get("y", 0.0)), "r": float(p.get("r", 3.0)), "vy": float(p.get("vy", -50.0)),
		"wobble": float(p.get("wobble", rng.randf() * TAU)),
	})
	_cap(bubbles, MAX_BUBBLES)


## Floating text (sim `float_text` signal).
func add_float_text(pos: Vector2, text: String, color: Color, life: float) -> void:
	floats.append({"x": pos.x, "y": pos.y, "text": text, "color": color, "life": life})
	_cap(floats, MAX_FLOATS)


## Speech bubble over a fighter (replaces the previous bubble of the same fighter).
func add_speech(fighter: Variant, text: String, life: float) -> void:
	for i in range(speeches.size() - 1, -1, -1):
		if speeches[i]["fighter"] == fighter:
			speeches.remove_at(i)
	speeches.append({"fighter": fighter, "text": text, "life": life})


## Expanding ring used by the touch gestures (screen px).
func add_touch_ripple(pos: Vector2, label: String, color: Color) -> void:
	touch_ripples.append({"x": pos.x, "y": pos.y, "r": 8.0, "life": 1.0, "label": label, "color": color})


# ---- JS spawner functions

func spawn_hairs(x: float, y: float, count: int) -> void:
	for i in count:
		var a: float = rng.randf() * TAU
		var sp: float = 40.0 + rng.randf() * 190.0
		add_particle({"x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp - 45.0, "w": 7.0, "h": 1.5, "rot": a, "vrot": (rng.randf() - 0.5) * 14.0,
			"life": 1.15, "decay": 0.75 + rng.randf() * 0.4, "color": "#d88aff" if rng.randf() > 0.45 else "#ffae42", "is_hair": true})


func spawn_sparks(x: float, y: float, count: int) -> void:
	for i in count:
		var a: float = rng.randf() * TAU
		var sp: float = 100.0 + rng.randf() * 290.0
		add_particle({"x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp - 60.0, "w": 2.0, "h": 2.0, "life": 1.0,
			"decay": 1.4 + rng.randf() * 1.4, "color": "#ffd166" if rng.randf() > 0.35 else "#ff6b35", "is_spark": true})


func spawn_embers(x: float, y: float, count: int) -> void:
	for i in count:
		var a: float = -PI * 0.1 - rng.randf() * PI * 0.8
		var sp: float = 75.0 + rng.randf() * 240.0
		add_particle({"x": x, "y": y, "vx": cos(a) * sp + (rng.randf() - 0.5) * 60.0, "vy": sin(a) * sp - 40.0, "w": 3.2, "h": 3.2,
			"life": 1.35 + rng.randf() * 0.6, "decay": 0.72 + rng.randf() * 0.35, "color": "#ff9e3b" if rng.randf() > 0.45 else "#ff4d29",
			"is_ember": true, "collides_terrain": true})


func spawn_debris(x: float, y: float, count: int) -> void:
	for i in count:
		var a: float = rng.randf() * TAU
		var sp: float = 60.0 + rng.randf() * 220.0
		add_particle({"x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp - 55.0, "w": 3.0 + rng.randf() * 5.0, "h": 3.0 + rng.randf() * 5.0,
			"rot": rng.randf() * 6.0, "vrot": (rng.randf() - 0.5) * 12.0, "life": 1.15, "decay": 0.75 + rng.randf() * 0.6,
			"color": "#5c5552" if rng.randf() > 0.5 else "#786248", "collides_terrain": true})


func spawn_smoke(x: float, y: float, count: int, color: Variant) -> void:
	for i in count:
		var a: float = rng.randf() * TAU
		var sp: float = 12.0 + rng.randf() * 58.0
		add_smoke({"x": x + (rng.randf() - 0.5) * 16.0, "y": y + (rng.randf() - 0.5) * 16.0, "vx": cos(a) * sp, "vy": sin(a) * sp - 20.0,
			"r": 10.0 + rng.randf() * 18.0, "vr": 18.0 + rng.randf() * 22.0, "life": 1.0, "decay": 0.55 + rng.randf() * 0.45, "color": color})


func spawn_water_plunge(wx: float, wy: float, sc: float) -> void:
	add_plume({"x": wx, "y": wy, "h": 0.0, "max_h": (65.0 + rng.randf() * 25.0) * sc, "w": 26.0 * sc, "ring_r": 8.0, "max_ring_r": 75.0 * sc, "life": 1.0})
	add_ripple({"x": wx, "amp": 14.0 * sc, "life": 1.0})
	for i in int(floor(28.0 * sc)):
		var a: float = -PI * 0.18 - rng.randf() * PI * 0.64
		var sp: float = (80.0 + rng.randf() * 230.0) * sc
		add_particle({"x": wx + (rng.randf() - 0.5) * 18.0, "y": wy, "vx": cos(a) * sp, "vy": sin(a) * sp, "w": 3.5 + rng.randf() * 2.5,
			"h": 3.5 + rng.randf() * 2.5, "life": 1.0, "decay": 1.05, "color": "#d6f2ff" if rng.randf() > 0.4 else "#7ec8e3"})


func spawn_uproot(x: float, y: float, p: Dictionary) -> void:
	var ex: float = float(p.get("from_x", p.get("ex", x)))
	var kind: String = str(p.get("type", ""))
	var col: String = "#e8f4ff" if kind == "TAULL" else ("#e67e22" if kind == "CASTELLFOLLIT" else "#7cb342")
	for i in 3:
		add_particle({"x": x, "y": y - 4.0, "vx": (x - ex) * 2.2 + (rng.randf() - 0.5) * 90.0, "vy": -90.0 - rng.randf() * 110.0, "w": 4.5, "h": 2.5,
			"rot": rng.randf() * 6.0, "vrot": (rng.randf() - 0.5) * 14.0, "life": 1.1, "decay": 0.8, "color": col})


func spawn_wine(x: float, y: float) -> void:
	for i in 22:
		var a: float = rng.randf() * TAU
		var sp: float = 60.0 + rng.randf() * 190.0
		add_particle({"x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp - 50.0, "w": 4.0, "h": 4.0, "life": 1.25, "decay": 0.85,
			"color": "#9e1b34" if rng.randf() < 0.6 else "#d83b56", "collides_terrain": true})


## Cosmetic puffs shed by flying projectiles (the JS spawns them inside the projectile step).
func spawn_projectile_puffs(projectiles: Array) -> void:
	for p in projectiles:
		var ptype: String = ViewUtil.gs(p, "type")
		var x: float = ViewUtil.gf(p, "x")
		var y: float = ViewUtil.gf(p, "y")
		if (ptype == "BAZOOKA" or ptype == "URTICARIA" or ptype == "BOMBLER") and rng.randf() < 0.72:
			var col: String = "rgba(225, 215, 200, 0.45)"
			if ptype == "URTICARIA":
				col = "rgba(200, 120, 255, 0.55)"
			elif ptype == "BOMBLER":
				col = "rgba(255, 145, 55, 0.55)"
			add_smoke({"x": x, "y": y, "vx": (rng.randf() - 0.5) * 14.0, "vy": (rng.randf() - 0.5) * 14.0, "r": 3.5 if ptype == "BOMBLER" else 4.8,
				"vr": 14.0, "life": 0.55, "decay": 1.0, "color": col})
		elif ptype == "HOLY" and rng.randf() < 0.75:
			add_particle({"x": x + (rng.randf() - 0.5) * 8.0, "y": y + (rng.randf() - 0.5) * 8.0, "vx": -ViewUtil.gf(p, "vx") * 0.1 + (rng.randf() - 0.5) * 30.0,
				"vy": -20.0 + (rng.randf() - 0.5) * 30.0, "w": 2.8, "h": 2.8, "life": 0.55, "decay": 1.2,
				"color": "#ffe57f" if rng.randf() < 0.65 else "#d92626", "is_spark": true})
		elif ptype == "CARQUINYOLI" and rng.randf() < 0.45:
			add_particle({"x": x, "y": y, "vx": (rng.randf() - 0.5) * 40.0, "vy": -15.0 + rng.randf() * 25.0, "w": 2.4, "h": 2.4,
				"rot": rng.randf() * 6.0, "vrot": 8.0, "life": 0.5, "decay": 1.3, "color": "#fff5df" if rng.randf() < 0.5 else "#c87d32"})


# ------------------------------------------------------------------ update

## Advances every pool by `dt` (slowed game time). `terrain` answers is_solid for bouncing debris.
func update(dt: float, wind: float, terrain: Object, water_y: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		if not p["is_beam"]:
			p["vy"] = float(p["vy"]) + (95.0 if p["is_hair"] else 420.0) * dt
			var nx: float = float(p["x"]) + (float(p["vx"]) + (wind * 0.8 if p["is_hair"] else 0.0)) * dt
			var ny: float = float(p["y"]) + float(p["vy"]) * dt
			if p["collides"] and ny < water_y and terrain != null and bool(terrain.call("is_solid", nx, ny)):
				if not bool(terrain.call("is_solid", float(p["x"]), ny)):
					p["vx"] = -float(p["vx"]) * 0.55
				else:
					p["vy"] = -absf(float(p["vy"])) * (0.52 if p["is_ember"] else 0.42)
					p["vx"] = float(p["vx"]) * 0.74
				p["vrot"] = float(p["vrot"]) * 0.65
			else:
				p["x"] = nx
				p["y"] = ny
			if p["collides"] and float(p["y"]) >= water_y:
				if p["is_ember"]:
					p["life"] = 0.0
				else:
					p["vy"] = float(p["vy"]) * 0.35
					p["vx"] = float(p["vx"]) * 0.5
			p["rot"] = float(p["rot"]) + float(p["vrot"]) * dt
		p["life"] = float(p["life"]) - float(p["decay"]) * dt
		if float(p["life"]) <= 0.0:
			particles.remove_at(i)
	for i in range(fireballs.size() - 1, -1, -1):
		var fb: Dictionary = fireballs[i]
		fb["r"] = float(fb["r"]) + (float(fb["max_r"]) - float(fb["r"])) * 10.0 * dt
		fb["y"] = float(fb["y"]) - 18.0 * dt
		fb["life"] = float(fb["life"]) - float(fb["decay"]) * dt
		if not (float(fb["life"]) > 0.0):
			fireballs.remove_at(i)
	for i in range(ripples.size() - 1, -1, -1):
		var rp: Dictionary = ripples[i]
		rp["phase"] = float(rp["phase"]) + dt
		rp["life"] = float(rp["life"]) - 0.85 * dt
		if not (float(rp["life"]) > 0.0):
			ripples.remove_at(i)
	for i in range(smokes.size() - 1, -1, -1):
		var s: Dictionary = smokes[i]
		s["x"] = float(s["x"]) + (float(s["vx"]) + wind * 0.25) * dt
		s["y"] = float(s["y"]) + float(s["vy"]) * dt
		s["r"] = float(s["r"]) + float(s["vr"]) * dt
		s["life"] = float(s["life"]) - float(s["decay"]) * dt
		if float(s["life"]) <= 0.0:
			smokes.remove_at(i)
	for i in range(shockwaves.size() - 1, -1, -1):
		var sw: Dictionary = shockwaves[i]
		sw["r"] = float(sw["r"]) + (float(sw["max_r"]) - float(sw["r"])) * 9.0 * dt
		sw["alpha"] = float(sw["alpha"]) - 2.4 * dt
		if float(sw["alpha"]) <= 0.0:
			shockwaves.remove_at(i)
	for i in range(plumes.size() - 1, -1, -1):
		var wp: Dictionary = plumes[i]
		wp["h"] = sin((1.0 - float(wp["life"])) * PI) * float(wp["max_h"])
		wp["ring_r"] = float(wp["ring_r"]) + (float(wp["max_ring_r"]) - float(wp["ring_r"])) * 5.0 * dt
		wp["life"] = float(wp["life"]) - 1.65 * dt
		if float(wp["life"]) <= 0.0:
			plumes.remove_at(i)
	for i in range(bubbles.size() - 1, -1, -1):
		var b: Dictionary = bubbles[i]
		b["y"] = float(b["y"]) + float(b["vy"]) * dt
		if float(b["y"]) <= water_y + 2.0:
			bubbles.remove_at(i)
	for i in range(floats.size() - 1, -1, -1):
		var ft: Dictionary = floats[i]
		ft["y"] = float(ft["y"]) - 26.0 * dt
		ft["life"] = float(ft["life"]) - dt
		if float(ft["life"]) <= 0.0:
			floats.remove_at(i)
	for i in range(speeches.size() - 1, -1, -1):
		speeches[i]["life"] = float(speeches[i]["life"]) - dt
		if float(speeches[i]["life"]) <= 0.0:
			speeches.remove_at(i)
	for i in range(touch_ripples.size() - 1, -1, -1):
		var trp: Dictionary = touch_ripples[i]
		trp["r"] = float(trp["r"]) + 75.0 * dt
		trp["life"] = float(trp["life"]) - 2.1 * dt
		if float(trp["life"]) <= 0.0:
			touch_ripples.remove_at(i)


# ------------------------------------------------------------------ drawing

## Fireballs (drawn with an additive material = canvas 'screen').
func draw_fireballs(ci: CanvasItem) -> void:
	for fb in fireballs:
		var alpha: float = clampf(float(fb["life"]), 0.0, 1.0)
		var r: float = float(fb["r"])
		var stops: Array
		var key: String
		if fb["urt"]:
			stops = [[0.0, Color(1.0, 0.9216, 1.0, 1.0)], [0.4, Color(0.8235, 0.4118, 1.0, 0.82)], [0.75, Color(0.4902, 0.1569, 0.7451, 0.45)], [1.0, Color(0.3529, 0.0784, 0.549, 0.0)]]
			key = "fb_urt"
		else:
			stops = [[0.0, Color(1.0, 0.9882, 0.8824, 1.0)], [0.32, Color(1.0, 0.7765, 0.2941, 0.92)], [0.68, Color(0.949, 0.3216, 0.1098, 0.65)], [1.0, Color(0.4706, 0.0941, 0.0392, 0.0)]]
			key = "fb_norm"
		ViewUtil.radial(ci, Vector2(float(fb["x"]), float(fb["y"])), r * 0.08, r, stops, alpha, key)


## Smoke, shockwaves, water plumes, particles.
func draw_main(ci: CanvasItem) -> void:
	for s in smokes:
		var col: Color = s["color"]
		var r: float = float(s["r"])
		var a: float = maxf(0.0, float(s["life"]) * 0.72) * col.a
		ViewUtil.radial(ci, Vector2(float(s["x"]), float(s["y"])), 1.0, r,
			[[0.0, Color(col.r, col.g, col.b, 1.0)], [1.0, Color(0.1176, 0.1098, 0.1098, 0.0)]], a, "smoke_" + col.to_html(false))
	for sw in shockwaves:
		var c: Color = sw["color"]
		ci.draw_arc(Vector2(float(sw["x"]), float(sw["y"])), float(sw["r"]), 0.0, TAU, 40, Color(c.r, c.g, c.b, float(sw["alpha"]) * 0.68), 3.2, true)
	for wp in plumes:
		_draw_plume(ci, wp)
	for p in particles:
		_draw_particle(ci, p)


func _draw_plume(ci: CanvasItem, wp: Dictionary) -> void:
	var a: float = clampf(float(wp["life"]), 0.0, 1.0)
	var x: float = float(wp["x"])
	var y: float = float(wp["y"])
	var h: float = float(wp["h"])
	var w: float = float(wp["w"])
	var pts := PackedVector2Array([Vector2(x - w * 0.6, y + 4.0)])
	pts.append_array(ViewUtil.quad_pts(Vector2(x - w * 0.6, y + 4.0), Vector2(x, y - h * 1.4), Vector2(x + w * 0.6, y + 4.0), 12))
	var cols := PackedColorArray()
	for p in pts:
		var tt: float = clampf((p.y - (y - h)) / maxf(1.0, h + 8.0), 0.0, 1.0)
		var c: Color = Color(0.9216, 0.9804, 1.0, 0.92).lerp(Color(0.4314, 0.7647, 0.9216, 0.2), tt)
		c.a *= a
		cols.append(c)
	ci.draw_polygon(pts, cols)
	ViewUtil.stroke_ellipse(ci, Vector2(x, y), float(wp["ring_r"]), float(wp["ring_r"]) * 0.22, Color(0.9216, 0.9804, 1.0, 0.85 * a), 3.0)


func _draw_particle(ci: CanvasItem, p: Dictionary) -> void:
	var a: float = clampf(float(p["life"]), 0.0, 1.0)
	var col: Color = p["color"]
	var at := Vector2(float(p["x"]), float(p["y"]))
	if p["is_beam"]:
		ci.draw_line(Vector2(float(p["x1"]), float(p["y1"])), Vector2(float(p["x2"]), float(p["y2"])), Color(1.0, 0.9333, 0.7255, 0.85 * a), 3.0, true)
	elif p["is_ember"]:
		ViewUtil.radial(ci, at, 0.5, 5.5, [[0.0, Color(1.0, 0.9765, 0.8392, 1.0)], [0.45, Color(col.r, col.g, col.b, 1.0)], [1.0, Color(1.0, 0.3137, 0.0784, 0.0)]], a, "ember_" + col.to_html(false))
	elif p["is_hair"]:
		ci.draw_set_transform_matrix(Transform2D(float(p["rot"]), Vector2.ONE, 0.0, at))
		ci.draw_polyline(ViewUtil.quad_pts(Vector2(-4, 0), Vector2(0, -2), Vector2(4, 0), 5), Color(col, col.a * a), 1.6, true)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	elif p["is_spark"]:
		ci.draw_line(at, at - Vector2(float(p["vx"]), float(p["vy"])) * 0.028, Color(col, col.a * a), 2.2, true)
	else:
		ci.draw_set_transform_matrix(Transform2D(float(p["rot"]), Vector2.ONE, 0.0, at))
		ci.draw_rect(Rect2(-float(p["w"]) * 0.5, -float(p["h"]) * 0.5, float(p["w"]), float(p["h"])), Color(col, col.a * a))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Explosion point light (additive).
func draw_flash(ci: CanvasItem, flash: float, pos: Vector2) -> void:
	if flash <= 0.01:
		return
	ViewUtil.radial(ci, pos, 8.0, 360.0, [[0.0, Color(1.0, 0.8039, 0.4706, 1.0)], [0.5, Color(1.0, 0.451, 0.1569, 0.46)], [1.0, Color(1.0, 0.3529, 0.0784, 0.0)]], flash * 0.82, "flash")


## Bubbles, speech bubbles and floating texts (drawn after the water front).
func draw_top(ci: CanvasItem, t: float) -> void:
	for b in bubbles:
		var c := Vector2(float(b["x"]) + sin(t * 8.0 + float(b["wobble"])) * 3.0, float(b["y"]))
		ci.draw_circle(c, float(b["r"]), Color(0.7059, 0.902, 1.0, 0.28))
		ci.draw_arc(c, float(b["r"]), 0.0, TAU, 12, Color(0.8627, 0.9608, 1.0, 0.85), 1.4, true)
	for sb in speeches:
		var f: Variant = sb["fighter"]
		if f == null or not ViewUtil.gb(f, "alive") or ViewUtil.gb(f, "drowning"):
			continue
		var a: float = clampf(float(sb["life"]) * 1.5, 0.0, 1.0)
		var txt: String = str(sb["text"])
		var tw: float = ViewUtil.text_w(txt, 11) + 16.0
		var bx: float = ViewUtil.gf(f, "x")
		var by: float = ViewUtil.gf(f, "y") - 54.0
		ViewUtil.fill_round_rect(ci, Rect2(bx - tw / 2.0, by - 14.0, tw, 20.0), 4.0, Color(ViewColors.SPEECH_BG, ViewColors.SPEECH_BG.a * a))
		ViewUtil.stroke_round_rect(ci, Rect2(bx - tw / 2.0, by - 14.0, tw, 20.0), 4.0, Color(ViewColors.SPEECH_BORDER, a), 1.3)
		ViewUtil.text(ci, txt, Vector2(bx, by), 11, Color(ViewColors.SPEECH_TEXT, a))
	for ft in floats:
		var a2: float = clampf(float(ft["life"]), 0.0, 1.0)
		var c2: Color = ft["color"]
		ViewUtil.text(ci, str(ft["text"]), Vector2(float(ft["x"]) + 1.0, float(ft["y"]) + 1.0), 13, Color(0, 0, 0, a2))
		ViewUtil.text(ci, str(ft["text"]), Vector2(float(ft["x"]), float(ft["y"])), 13, Color(c2, c2.a * a2))

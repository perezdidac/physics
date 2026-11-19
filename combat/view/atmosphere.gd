## Render-only sky state of a match: per-match sky palette, cloud flock, mountain ridges, birds, wind ribbons and weather
## particles (port of regenerateMatchAtmosphere + the visual half of updateDynamicWind, state.js).
class_name ViewAtmosphere
extends RefCounted

const TERRAIN_W: float = 3200.0

var rng := RandomNumberGenerator.new()
var map_id: String = "MONTSERRAT"
var weather: String = "POLLEN"
var palette: Array[Color] = []
var cloud_style: String = "CUMULUS"
var mountain_style: String = "PYRENEAN_PEAKS"
var clouds: Array[Dictionary] = []
var ridge_far: PackedFloat32Array = PackedFloat32Array()
var ridge_near: PackedFloat32Array = PackedFloat32Array()
var ribbons: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var particles: Array[Dictionary] = []


## Builds everything for a map. `sky` is the 5-colour palette of the map (before the per-match shift).
func generate(map_facts: Dictionary) -> void:
	rng.randomize()
	map_id = str(map_facts["id"])
	weather = str(map_facts["weather"])
	_make_palette(map_facts["sky"])
	_make_clouds()
	_make_ridges()
	_make_extras()


func _make_palette(sky: Array) -> void:
	var rs: float = (rng.randf() - 0.5) * 28.0 / 255.0
	var gs: float = (rng.randf() - 0.5) * 22.0 / 255.0
	var bs: float = (rng.randf() - 0.5) * 30.0 / 255.0
	palette.clear()
	for c in sky:
		var col: Color = c
		palette.append(Color(clampf(col.r + rs, 0.0, 1.0), clampf(col.g + gs, 0.0, 1.0), clampf(col.b + bs, 0.0, 1.0), 1.0))


func _make_clouds() -> void:
	var styles: Array[String] = ["CUMULUS", "LENTICULAR", "CIRRUS_STREAKS", "BILLOWING_ANVIL"]
	cloud_style = styles[rng.randi() % styles.size()]
	clouds.clear()
	var total: int = 12 if cloud_style == "CIRRUS_STREAKS" else 9
	for idx in total:
		var tier: int = 0 if idx % 3 == 0 else (1 if idx % 3 == 1 else 2)
		var z: float = 0.09 if tier == 0 else (0.20 if tier == 1 else 0.36)
		var sc: float
		if tier == 0:
			sc = 0.40 + rng.randf() * 0.25
		elif tier == 1:
			sc = 0.50 + rng.randf() * 0.30
		else:
			sc = 0.55 + rng.randf() * 0.30
		var lobe_count: int = 4 if cloud_style == "LENTICULAR" else 5 + rng.randi() % 4
		var lobes: Array[Dictionary] = []
		for l in lobe_count:
			var frac: float = float(l) / float(maxi(1, lobe_count - 1)) - 0.5
			var lb: Dictionary = {}
			if cloud_style == "LENTICULAR":
				lb = {"ox": frac * 90.0 * sc, "oy": (float(l) - 1.5) * 7.0 * sc,
					"rx": (68.0 - absf(frac) * 35.0 + rng.randf() * 14.0) * sc, "ry": (10.0 + (1.0 - absf(frac)) * 7.0) * sc}
			elif cloud_style == "CIRRUS_STREAKS":
				lb = {"ox": frac * 155.0 * sc + (rng.randf() - 0.5) * 22.0, "oy": sin(frac * 4.0) * 6.0 * sc,
					"rx": (52.0 + rng.randf() * 28.0) * sc, "ry": (6.5 + rng.randf() * 5.5) * sc}
			elif cloud_style == "BILLOWING_ANVIL":
				var lift: float = -28.0 * sc if l == int(floor(float(lobe_count) * 0.5)) else 0.0
				lb = {"ox": frac * 105.0 * sc + (rng.randf() - 0.5) * 14.0, "oy": absf(frac) * 22.0 * sc + lift,
					"rx": (38.0 + (1.0 - absf(frac)) * 36.0 + rng.randf() * 14.0) * sc, "ry": (28.0 + (1.0 - absf(frac)) * 28.0 + rng.randf() * 12.0) * sc}
			else:
				var top: float = 14.0 * sc if l == int(floor(float(lobe_count) * 0.5)) else 0.0
				lb = {"ox": frac * 115.0 * sc + (rng.randf() - 0.5) * 16.0, "oy": absf(frac) * 18.0 * sc - top + (rng.randf() - 0.5) * 8.0,
					"rx": (34.0 + (1.0 - absf(frac)) * 32.0 + rng.randf() * 14.0) * sc, "ry": (22.0 + (1.0 - absf(frac)) * 20.0 + rng.randf() * 10.0) * sc}
			lobes.append(lb)
		var cy: float
		if tier == 0:
			cy = 30.0 + rng.randf() * 50.0
		elif tier == 1:
			cy = 55.0 + rng.randf() * 70.0
		else:
			cy = 80.0 + rng.randf() * 70.0
		clouds.append({
			"x": float(idx) / float(total) * 3800.0 - 300.0 + (rng.randf() - 0.5) * 120.0, "y": cy, "z": z, "tier": tier,
			"base_drift": (rng.randf() - 0.5) * 8.0, "bob_phase": rng.randf() * TAU, "lobes": lobes,
			"passes": _union_passes(lobes),
		})


func _make_ridges() -> void:
	var styles: Array[String] = ["AGULLES_NEEDLES", "ENFORCADURA_TWIN", "VOLCANIC_CONES", "PYRENEAN_PEAKS", "COASTAL_CAPES", "CASTLE_RIDGES"]
	mountain_style = styles[rng.randi() % styles.size()]
	var seed_far: float = rng.randf() * 100.0
	var seed_near: float = rng.randf() * 100.0 + 37.5
	ridge_far.clear()
	ridge_near.clear()
	for i in 97:
		var u: float = float(i) / 96.0
		var h_far: float = 0.42 + ViewNoise.fbm(u * 4.5 + seed_far, seed_far, 4) * 0.35
		var h_near: float = 0.54 + ViewNoise.fbm(u * 6.2 + seed_near, seed_near, 4) * 0.32
		if mountain_style == "AGULLES_NEEDLES" or map_id == "MONTSERRAT":
			h_far -= pow(absf(sin(u * PI * 14.0 + seed_far)), 2.2) * 0.16
			h_near -= pow(absf(sin(u * PI * 18.0 + seed_near)), 2.4) * 0.14
		elif mountain_style == "ENFORCADURA_TWIN" or map_id == "PEDRAFORCA":
			h_far -= exp(-pow((u - 0.42) / 0.08, 2.0)) * 0.24 + exp(-pow((u - 0.58) / 0.08, 2.0)) * 0.22 - exp(-pow((u - 0.50) / 0.04, 2.0)) * 0.18
		elif mountain_style == "VOLCANIC_CONES" or map_id == "CASTELLFOLLIT":
			h_near -= maxf(0.0, 0.22 - absf(u - 0.35) * 1.4) + maxf(0.0, 0.18 - absf(u - 0.72) * 1.3)
		elif mountain_style == "CASTLE_RIDGES" or map_id == "MONTBLANC" or map_id == "TARRACO":
			h_near = floorf(h_near * 18.0 + 0.5) / 18.0
		ridge_far.append(clampf(h_far, 0.18, 0.85))
		ridge_near.append(clampf(h_near, 0.28, 0.90))


func _make_extras() -> void:
	ribbons.clear()
	for i in 16:
		ribbons.append({
			"x": rng.randf() * 3200.0, "y": 70.0 + rng.randf() * 540.0, "z": 0.45 + rng.randf() * 0.65,
			"len": 65.0 + rng.randf() * 85.0, "amp": 4.0 + rng.randf() * 7.0, "phase": rng.randf() * TAU, "alpha": 0.16 + rng.randf() * 0.22,
		})
	birds.clear()
	for i in 12:
		birds.append({
			"x": rng.randf() * 3400.0, "y": 65.0 + float(i % 4) * 28.0 + rng.randf() * 85.0, "z": 0.16 + float(i % 3) * 0.08,
			"speed": 22.0 + rng.randf() * 18.0, "dir": 1.0 if i % 2 == 0 else -1.0, "wing_phase": rng.randf() * TAU, "size": 5.5 + float(i % 3) * 1.8,
		})
	particles.clear()
	for i in 110:
		particles.append({
			"x": rng.randf() * 3200.0, "y": rng.randf() * 760.0, "z": 0.5 + rng.randf(), "r": 1.0 + rng.randf() * 1.8,
			"vx": (rng.randf() - 0.5) * 18.0, "vy": 25.0 + rng.randf() * 65.0, "phase": rng.randf() * TAU,
		})


## Visual drift of clouds, ribbons and birds (updateDynamicWind, visual half). `wind` is the sim's integer wind.
func update(dt: float, wind: float, t_now: float) -> void:
	for c in clouds:
		var speed: float = (wind * 0.58 + float(c["base_drift"]) + 12.0) * (0.45 + float(c["z"]) * 1.6)
		var cx: float = float(c["x"]) + speed * dt
		if cx > TERRAIN_W + 450.0:
			cx -= TERRAIN_W + 900.0
		if cx < -450.0:
			cx += TERRAIN_W + 900.0
		c["x"] = cx
	for r in ribbons:
		var vx: float = (14.0 if absf(wind) < 6.0 else wind * 2.6) * float(r["z"])
		var rx: float = float(r["x"]) + vx * dt
		r["y"] = float(r["y"]) + sin(t_now * 2.2 + float(r["phase"])) * 8.0 * dt
		if rx > TERRAIN_W + 250.0:
			rx -= TERRAIN_W + 500.0
		if rx < -250.0:
			rx += TERRAIN_W + 500.0
		r["x"] = rx
	for b in birds:
		var bvx: float = (float(b["dir"]) * float(b["speed"]) + wind * 0.25) * (0.6 + float(b["z"]))
		var bx: float = float(b["x"]) + bvx * dt
		if bx > TERRAIN_W + 350.0:
			bx = -340.0
		if bx < -350.0:
			bx = TERRAIN_W + 340.0
		b["x"] = bx


## Unions the lobes of a cloud into one outline per drawing pass (shadow, body, crown) so translucent fills do not double up.
static func _union_passes(lobes: Array[Dictionary]) -> Array:
	var specs: Array = [[7.0, 0.98, 0.88, 0.0], [2.0, 1.0, 0.92, 0.0], [-4.0, 0.92, 0.82, -2.0]]
	var out: Array = []
	for sp in specs:
		var cur: Array[PackedVector2Array] = []
		for lb in lobes:
			var e: PackedVector2Array = ViewUtil.ellipse_pts(Vector2(float(lb["ox"]) + float(sp[3]), float(lb["oy"]) + float(sp[0])), float(lb["rx"]) * float(sp[1]), float(lb["ry"]) * float(sp[2]), 0.0, 20)
			var next: Array[PackedVector2Array] = []
			for p in cur:
				if Geometry2D.intersect_polygons(p, e).size() > 0:
					var m: Array[PackedVector2Array] = Geometry2D.merge_polygons(p, e)
					var best: PackedVector2Array = m[0]
					var best_area: float = 0.0
					for q in m:
						var area: float = absf(_area(q))
						if area > best_area:
							best_area = area
							best = q
					e = best
				else:
					next.append(p)
			next.append(e)
			cur = next
		out.append(cur)
	return out


static func _area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	for i in poly.size():
		var j: int = (i + 1) % poly.size()
		a += poly[i].x * poly[j].y - poly[j].x * poly[i].y
	return a * 0.5

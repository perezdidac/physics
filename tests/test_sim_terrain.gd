## Terrain: structural checks for all 8 maps, queries, craters (against a brute-force JS port) and girders.
##   godot --headless --path . res://tests/TestSimTerrain.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _flat(ter: TerrainSim, top: int) -> void:
	ter.mask.fill(0)
	for y in range(top, TerrainSim.H):
		for x in TerrainSim.W:
			ter.mask[y * TerrainSim.W + x] = 1


func _ready() -> void:
	var ml: MapList = load("res://data/maps/map_list.tres")
	_check(ml.maps.size() == 8, "8 maps in the list")
	var wl: WeaponList = load("res://data/weapons/weapon_list.tres")
	var classic: Array = wl.weapons.filter(func(w: WeaponDef) -> bool: return not w.story_only)
	_check(classic.size() == 16 and wl.weapons[15].id == "GANXO" and wl.weapons[9].default_ammo == 1, "16 weapons in JS order")
	var total_ms: int = 0
	var runs: int = 0
	for map_idx in 8:
		for seed_v in 3:
			var ter := TerrainSim.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = 100 + map_idx * 10 + seed_v
			var t0: int = Time.get_ticks_msec()
			ter.generate(ml.maps[map_idx], rng, true)
			total_ms += Time.get_ticks_msec() - t0
			runs += 1
			_structure(ter, "map %d seed %d (%s, %s)" % [map_idx, seed_v, ter.archetype_id, ter.texture_style])
	print("terrain generation: %d runs, average %.0f ms" % [runs, total_ms / float(runs)])
	_queries()
	_crater_matches_js()
	_cavern_pruning()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _structure(ter: TerrainSim, label: String) -> void:
	var w: int = TerrainSim.W
	var h: int = TerrainSim.H
	var ok_range: bool = true
	for x in range(120, w - 120):
		var sy: float = ter.surface_y[x]
		if sy < 165.0 or sy > 795.0:
			ok_range = false
	_check(ok_range, label + ": surface height inside 165..795")
	var outside: int = 0
	for y in h:
		for x in 120:
			outside += ter.mask[y * w + x] + ter.mask[y * w + (w - 80 + x % 80)]
	_check(outside == 0, label + ": no terrain left of x=120 or right of x=3080")
	var bad: int = 0
	for x in range(120, w - 120, 7):
		var sy: int = int(floorf(ter.surface_y[x]))
		for y in range(676, h):
			if (ter.mask[y * w + x] == 1) != (y >= sy):
				bad += 1
	_check(bad == 0, label + ": below y=676 the mask is plain surface fill (caverns only above)")
	var carved: int = 0
	for cav in ter.caverns:
		var cx: int = int(cav["cx"])
		var cy: int = int(cav["cy"])
		if cy < 676 and not ter.is_solid(cx, cy) and ter.is_solid(cx, ter.surface_y[clampi(cx, 0, w - 1)] + 5.0):
			carved += 1
	_check(carved >= 1, label + ": at least one cavern centre is hollow under solid ground")
	_check(ter.stamps.size() >= 4 and ter.tree_spots.size() >= 1, label + ": stamps and trees recorded (%d/%d)" % [ter.stamps.size(), ter.tree_spots.size()])
	_check(ter.water_y == 700.0 and ter.valley_spots.size() == 3, label + ": water_y 700 and 3 valley spots")
	var tiers_ok: bool = true
	for x in range(240, 2960, 97):
		var tiers: PackedInt32Array = ter.find_all_walkable_surfaces_at_x(x)
		for ty in tiers:
			var air: int = 0
			while air < 26 and ter.mask[(ty - 1 - air) * w + x] == 0:
				air += 1
			if ter.mask[ty * w + x] != 1 or air < 26:
				tiers_ok = false
	_check(tiers_ok, label + ": walkable tiers are solid cells under 26+ px of air")


func _queries() -> void:
	var ter := TerrainSim.new()
	_flat(ter, 400)
	_check(ter.is_solid(10.5, 400.2) and not ter.is_solid(10.5, 399.9), "is_solid floors coordinates")
	_check(not ter.is_solid(-1.0, 500.0) and not ter.is_solid(3200.0, 500.0) and not ter.is_solid(10.0, 820.0) and not ter.is_solid(10.0, -1.0), "is_solid is false out of bounds")
	var n: Vector2 = ter.surface_normal(1000.0, 400.0)
	_check(absf(n.x) < 1e-9 and absf(n.y + 1.0) < 1e-9, "flat ground normal is (0,-1)")
	_check(ter.surface_normal(1000.0, 100.0) == Vector2(0.0, -1.0), "normal in empty air defaults to (0,-1)")
	_check(ter.find_surface_y(1000.0, 40.0) == 400.0 and ter.find_surface_y(1000.0, 500.0) == 500.0, "find_surface_y scans down")
	var tiers: PackedInt32Array = ter.find_all_walkable_surfaces_at_x(500.0)
	_check(tiers.size() == 1 and tiers[0] == 400, "one walkable tier on flat ground")
	var rects: Array[Rect2i] = []
	ter.terrain_changed.connect(func(r: Rect2i) -> void: rects.append(r))
	ter.carve_crater(1000.0, 400.0, 50.0)
	_check(rects.size() == 1 and rects[0].has_point(Vector2i(1000, 400)), "carve_crater emits terrain_changed")
	_check(not ter.is_solid(1000.0, 420.0) and ter.is_solid(1000.0, 460.0) and ter.is_solid(1000.0, 480.0), "crater removes a disc")
	ter.build_girder(2000.0, 300.0, 0.0, 82.0, 16.0)
	_check(ter.is_solid(2000.0, 300.0) and ter.is_solid(1965.0, 300.0) and not ter.is_solid(2000.0, 320.0), "girder builds a solid bar")
	_check(ter.stamps.back()["kind"] == "GIRDER", "girder recorded as stamp")


func _crater_matches_js() -> void:
	var ter := TerrainSim.new()
	_flat(ter, 400)
	var ref := PackedByteArray(ter.mask)
	var cx: float = 1234.3
	var cy: float = 395.7
	var radius: float = 61.0
	var r: int = int(ceilf(radius))
	for y in range(maxi(0, int(floorf(cy - r - 6))), mini(TerrainSim.H - 1, int(ceilf(cy + r + 6))) + 1):
		for x in range(maxi(0, int(floorf(cx - r - 6))), mini(TerrainSim.W - 1, int(ceilf(cx + r + 6))) + 1):
			var dist: float = Vector2(x - cx, y - cy).length()
			var jitter: float = (SimNoise.noise2d(x * 0.09, y * 0.09) - 0.5) * 4.5
			if dist + jitter <= radius:
				ref[y * TerrainSim.W + x] = 0
	ter.carve_crater(cx, cy, radius)
	var diff: int = 0
	for i in ref.size():
		if ref[i] != ter.mask[i]:
			diff += 1
	_check(diff == 0, "pruned carve_crater equals the naive JS algorithm (%d differing pixels)" % diff)


func _cavern_pruning() -> void:
	var ml: MapList = load("res://data/maps/map_list.tres")
	var ter := TerrainSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	ter.generate(ml.maps[2], rng, true)
	# Naive check of the cavern predicate in a region around the first cavern, on the pre-stamp rule.
	var cav: Dictionary = ter.caverns[0]
	var diff: int = 0
	var checked: int = 0
	for x in range(int(cav["cx"] - cav["rx"] * 1.3), int(cav["cx"] + cav["rx"] * 1.3), 3):
		for y in range(int(cav["cy"] - cav["ry"] * 1.3), int(cav["cy"] + cav["ry"] * 1.3), 2):
			if x < 0 or x >= TerrainSim.W or y < 0 or y >= TerrainSim.H:
				continue
			var sy: int = int(floorf(ter.surface_y[x]))
			if y - sy <= 32 or y >= 676:
				continue
			var cav_n: float = SimNoise.fbm(x * 0.018 + ter.map_seed, y * 0.018, 3) * 0.32
			var inside: bool = false
			for c in ter.caverns:
				var dx: float = (x - float(c["cx"])) / float(c["rx"])
				var dy: float = (y - float(c["cy"])) / float(c["ry"])
				if dx * dx + dy * dy < 0.88 + cav_n:
					inside = true
			checked += 1
			# Stamps may legitimately fill a hollow later, but never empty solid ground outside a cavern.
			if not inside and ter.mask[y * TerrainSim.W + x] == 0:
				diff += 1
	_check(checked > 500 and diff == 0, "no hollow pixels outside the cavern ellipses (%d checked, %d wrong)" % [checked, diff])

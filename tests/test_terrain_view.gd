## Terrain view: change coalescing (one upload per frame), exact scorch data from the sim, girder added pixels, stamp
## classification, solid-fill speed path of the generator.
##   godot --headless --path . res://tests/TestTerrainView.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	var ml: MapList = load("res://data/maps/map_list.tres")
	var ter := TerrainSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	var t0: int = Time.get_ticks_msec()
	ter.generate(ml.maps[2], rng, true)
	print("generate: %d ms" % (Time.get_ticks_msec() - t0))
	_solid_fill(ter)
	_sim_exposes_changes(ter)
	_stamp_classes()
	await _view(ter)
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _solid_fill(ter: TerrainSim) -> void:
	var bad: int = 0
	for x in range(120, TerrainSim.W - 120):
		if ter.mask[(TerrainSim.H - 1) * TerrainSim.W + x] != 1:
			bad += 1
		var sy: int = int(floorf(ter.surface_y[x]))
		if sy > 0 and ter.mask[(sy - 1) * TerrainSim.W + x] == 1 and ter.mask[0 * TerrainSim.W + x] == 1:
			bad += 1
	var odd: int = 0
	for i in range(0, ter.mask.size(), 97):
		if ter.mask[i] > 1:
			odd += 1
	_check(bad == 0 and odd == 0 and ter.mask.size() == TerrainSim.W * TerrainSim.H, "native column fill: bottom row solid, mask values 0/1")


func _sim_exposes_changes(ter: TerrainSim) -> void:
	ter.carve_crater(1400.4, 500.0, 25.5)
	_check(ter.last_change_kind == "carve" and is_equal_approx(float(ter.last_carve["x"]), 1400.4) and is_equal_approx(float(ter.last_carve["r"]), 25.5), "carve_crater exposes kind and exact centre / radius")
	var before: PackedByteArray = ter.mask.duplicate()
	ter.build_girder(1000.0, 300.0, 0.4)
	var rect: Rect2i = ter.last_build["rect"]
	var added: PackedByteArray = ter.last_build["added"]
	var n_added: int = 0
	var expected: int = 0
	for yy in rect.size.y:
		for xx in rect.size.x:
			var i: int = (rect.position.y + yy) * TerrainSim.W + rect.position.x + xx
			if before[i] == 0 and ter.mask[i] == 1:
				expected += 1
			n_added += added[yy * rect.size.x + xx]
	_check(ter.last_change_kind == "build" and n_added == expected and expected > 100, "build_girder exposes the newly solid pixels (%d)" % expected)


func _stamp_classes() -> void:
	var tree: Dictionary = {"kind": "TREE", "style": "DOUGLAS_FIR", "x": 500, "y": 400, "scale": 1.0, "crown_y": 340}
	_check(TerrainStamps.kind_id(tree) == TerrainStamps.K_TREE and TerrainStamps.tree_style(tree) == 1, "stamp class: fir tree")
	_check(TerrainStamps.kind_id({"kind": "TERRACE"}) == TerrainStamps.K_TERRACE, "stamp class: terrace")
	_check(TerrainStamps.kind_id({"kind": "WATCHTOWER"}) == TerrainStamps.K_STONE and TerrainStamps.rows_below_surface({"kind": "WATCHTOWER"}) == 14, "stamp class: watchtower is stone, 14 rows below the surface")
	_check(TerrainStamps.kind_id({"kind": "VIADUCT"}) == TerrainStamps.K_VIADUCT and TerrainStamps.kind_id({"kind": "ROCK_ARCH"}) == TerrainStamps.K_ARCH, "stamp class: viaduct / arch")
	var box: Rect2i = TerrainStamps.box({"kind": "MONOLITHS", "x": 100, "y": 200})
	_check(box == Rect2i(43, 131, 115, 82), "stamp box: monoliths")


func _view(ter: TerrainSim) -> void:
	var view := TerrainView.new()
	add_child(view)
	var t0: int = Time.get_ticks_usec()
	view.setup(ter)
	print("TerrainView.setup (CPU part): %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	_check(view._baker != null and not view.visible, "setup creates the baker and hides the terrain while the first bake renders")
	ter.terrain_changed.connect(view.on_terrain_changed)
	for k in 5:
		ter.carve_crater(1500.0 + k * 20.0, 520.0, 14.0)
	_check(view.uploads == 0 and view._rects.size() == 5, "carves are queued, nothing uploaded yet")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(view.uploads == 1 and view.scorch_count == 5, "five carves in one frame -> one upload batch, five scorch passes")
	t0 = Time.get_ticks_usec()
	ter.carve_crater(2000.0, 500.0, 40.0)
	view.flush()
	print("one carve (sim + view update): %.2f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	ter.build_girder(1200.0, 250.0, 0.0)
	view.flush()
	_check(view.uploads == 3 and view._events.is_empty() and view._rects.is_empty(), "girder flushed, queues empty")
	view.queue_free()

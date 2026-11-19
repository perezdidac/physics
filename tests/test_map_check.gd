## Map checker: generates many matches (the 8 maps x several seeds, classic setup plus the story COMBAT levels), drops a few
## supply crates in each, and counts object problems: footprints that overlap, objects on trees/towers, floating or buried
## objects, objects in water, fighters that cannot reach each other. Fails above a tiny threshold (see MAX_*).
##   godot --headless --path . res://tests/TestMapCheck.tscn
## Deep scan: CUCS_MAPCHECK_SEEDS=60 godot --headless --path . res://tests/TestMapCheck.tscn
extends Node

const DEFAULT_SEEDS: int = 5
const DROPS: int = 4
## Allowed problems as a fraction of all objects: a fighter that finds no free place within reach is kept where it is.
const MAX_FRACTION: float = 0.001
## Fighters that may end up stranded (as a fraction of all fighters) when a map has no roomy ground near the spawn point.
const MAX_UNREACHABLE_FRACTION: float = 0.015

var failures: int = 0
var kind_counts: Dictionary = {}


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	var n_seeds: int = DEFAULT_SEEDS
	var env: String = OS.get_environment("CUCS_MAPCHECK_SEEDS")
	if env.is_valid_int():
		n_seeds = maxi(1, env.to_int())
	var total: Dictionary = _empty()
	var start: int = Time.get_ticks_msec()
	var map_count: int = (load("res://data/maps/map_list.tres") as MapList).maps.size()
	for m in map_count:
		var row: Dictionary = _empty()
		for s in n_seeds:
			var cfg := MatchConfig.new()
			cfg.map_idx = m
			cfg.seed = 7001 + s * 131 + m * 17
			cfg.game_mode = "2P_LOCAL"
			cfg.worms_per_team = 1 + (s + m) % 6
			_add(row, _analyse(cfg, true))
		print("map %d: %s" % [m, _fmt(row)])
		_add(total, row)
	var story: Dictionary = _empty()
	var story_runs: int = 0
	var levels: LevelList = load("res://data/levels/level_list.tres")
	var template: LevelDef = null
	for lv in levels.levels:
		var level: LevelDef = lv
		if template == null and level.enemy_unit != null and level.player_unit != null:
			template = level
		if level.mode != "COMBAT":
			continue
		for s in n_seeds:
			_add(story, _analyse(_story_cfg(level, level.map_idx, level.seed + s * 977), false))
			story_runs += 1
	# The story setup (squads, hiding spots) on every map, with the first level that has ants (even if it is a platform level now).
	if template != null:
		for m in map_count:
			for s in n_seeds:
				_add(story, _analyse(_story_cfg(template, m, template.seed + s * 977 + m), false))
				story_runs += 1
	print("story (%d runs): %s" % [story_runs, _fmt(story)])
	_add(total, story)
	print("TOTAL: %s  (%.0f s)" % [_fmt(total), (Time.get_ticks_msec() - start) / 1000.0])
	print("classic objects by kind (all matches): %s" % str(kind_counts))
	_check(int(total["overlap"]) <= MAX_FRACTION * int(total["objects"]), "objects overlapping each other: %d" % total["overlap"])
	_check(int(total["stamp"]) <= MAX_FRACTION * int(total["objects"]), "objects on trees/towers/arches: %d" % total["stamp"])
	_check(int(total["buried"]) <= MAX_FRACTION * int(total["objects"]), "buried objects: %d" % total["buried"])
	_check(int(total["floating"]) <= MAX_FRACTION * int(total["objects"]), "floating objects: %d" % total["floating"])
	_check(int(total["water"]) <= MAX_FRACTION * int(total["objects"]), "objects in the water: %d" % total["water"])
	_check(int(total["unreachable"]) <= MAX_UNREACHABLE_FRACTION * int(total["fighters"]), "stranded fighters: %d" % total["unreachable"])
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)


static func _story_cfg(level: LevelDef, map_idx: int, seed_v: int) -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.level = level
	cfg.map_idx = map_idx
	cfg.seed = seed_v
	cfg.game_mode = "1P_CPU"
	cfg.worms_per_team = level.player_names.size()
	return cfg


static func _empty() -> Dictionary:
	return {"objects": 0, "overlap": 0, "stamp": 0, "buried": 0, "floating": 0, "water": 0, "unreachable": 0, "fighters": 0}


static func _add(into: Dictionary, other: Dictionary) -> void:
	for k in into:
		into[k] = int(into[k]) + int(other[k])


static func _fmt(d: Dictionary) -> String:
	return "objects %d, overlap %d, on-structure %d, buried %d, floating %d, in-water %d, fighters %d (unreachable %d)" % [
		d["objects"], d["overlap"], d["stamp"], d["buried"], d["floating"], d["water"], d["fighters"], d["unreachable"]]


## Builds one match and counts its problems.
func _analyse(cfg: MatchConfig, classic: bool) -> Dictionary:
	var sim := CombatSim.new()
	sim.setup(cfg)
	for i in DROPS:
		SimSetup.spawn_supply_drop(sim)
	var out: Dictionary = _empty()
	var terrain: TerrainSim = sim.terrain
	var fps: Array[Dictionary] = SimPlacement.footprints(sim)
	var stamps: Array[Rect2] = SimPlacement.stamp_rects(terrain)
	out["objects"] = fps.size()
	if classic:
		for fp in fps:
			kind_counts[fp["kind"]] = int(kind_counts.get(fp["kind"], 0)) + 1
	for i in fps.size():
		var rect: Rect2 = fps[i]["rect"]
		var kind: String = fps[i]["kind"]
		var x: float = fps[i]["x"]
		var sy: float = fps[i]["sy"]
		for j in range(i + 1, fps.size()):
			if rect.intersects(fps[j]["rect"]):
				out["overlap"] += 1
				if OS.get_environment("CUCS_MAPCHECK_VERBOSE") != "":
					print("  overlap %s(%d,%d) / %s(%d,%d) map %d seed %d" % [kind, x, sy, fps[j]["kind"], fps[j]["x"], fps[j]["sy"], cfg.map_idx, cfg.seed])
		if SimPlacement.hits_stamp(stamps, rect):
			out["stamp"] += 1
			if OS.get_environment("CUCS_MAPCHECK_VERBOSE") != "":
				print("  on-structure %s(%d,%d) map %d seed %d level %s" % [kind, x, sy, cfg.map_idx, cfg.seed, cfg.level != null])
		if not SimPlacement.supported(terrain, x, sy):
			out["floating"] += 1
			if OS.get_environment("CUCS_MAPCHECK_VERBOSE") != "":
				print("  floating %s(%d,%d) map %d seed %d level %s" % [kind, x, sy, cfg.map_idx, cfg.seed, cfg.level.id if cfg.level != null else "-"])
		elif SimPlacement.buried_fraction(terrain, rect) > SimPlacement.buried_limit(kind):
			out["buried"] += 1
			if OS.get_environment("CUCS_MAPCHECK_VERBOSE") != "":
				print("  buried %s(%d,%d) map %d seed %d" % [kind, x, sy, cfg.map_idx, cfg.seed])
		if sy > terrain.water_y - 20.0 and kind != "UPDRAFT":
			out["water"] += 1
	out["fighters"] = sim.fighters.size()
	if classic and sim.fighters.size() > 1:
		out["unreachable"] = _unreachable(sim)
	return out


## Fighters stuck on a tiny island: walking and leaping from them (SimNav, ants' reach) covers less than MIN_ROOM columns.
func _unreachable(sim: CombatSim) -> int:
	var nav := SimNav.new(sim.terrain, false)
	var bad: int = 0
	for f in sim.fighters:
		if f.alive and nav.reachable(Vector2(f.x, f.y), true).size() < SimPlacement.MIN_ROOM:
			bad += 1
	return bad

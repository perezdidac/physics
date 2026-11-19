## Ants climb cliffs over time instead of snapping up them: runs the story setup with ants on every map (the player passes every turn)
## and measures how far an ant moves in one frame, and that it tilts (SimFighter.climb) on walls.
##   godot --headless --path . res://tests/TestMapCheckClimb.tscn
extends Node

const DT: float = 1.0 / 60.0
## Longest distance (px) an ant may move in a single frame (a climb is ~1.3 px; a fall, its landing and the slide after it are physics, not counted).
const MAX_FRAME_MOVE: float = 4.0
const SECONDS: float = 150.0

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	var template: LevelDef = load("res://data/levels/egg_2.tres")
	var maps: int = (load("res://data/maps/map_list.tres") as MapList).maps.size()
	var worst: float = 0.0
	var wall_frames: int = 0
	var max_tilt: float = 0.0
	var wall_climbs: int = 0
	for m in maps:
		var sim := CombatSim.new()
		var cfg := MatchConfig.new()
		cfg.level = template
		cfg.map_idx = m
		cfg.seed = template.seed + m
		cfg.game_mode = "1P_CPU"
		cfg.worms_per_team = template.player_names.size()
		sim.setup(cfg)
		var last: Dictionary = {}
		var prev_wall: bool = false
		for i in int(SECONDS / DT):
			if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
				sim.end_turn()
			sim.step(DT)
			sim.advance_real(DT)
			if sim.turn_phase == CombatSim.Phase.GAME_OVER:
				break
			for f in sim.fighters:
				if f.team != 1 or not f.alive:
					continue
				var p := Vector2(f.x, f.y)
				if last.has(f.id) and f.grounded and not f.sliding and last[f.id][1]:
					worst = maxf(worst, p.distance_to(last[f.id][0]))
				last[f.id] = [p, f.grounded and not f.sliding]
				max_tilt = maxf(max_tilt, absf(f.climb))
			var wall: bool = sim.active_fighter != null and absf(sim.active_fighter.climb) > 1.0
			wall_frames += 1 if wall else 0
			wall_climbs += 1 if wall and not prev_wall else 0
			prev_wall = wall
	print("worst ant move per frame: %.2f px, wall climbs: %d (%d frames), max tilt %.2f rad" % [worst, wall_climbs, wall_frames, max_tilt])
	_check(worst <= MAX_FRAME_MOVE, "an ant never moves more than %d px in one frame (%.2f)" % [int(MAX_FRAME_MOVE), worst])
	_check(max_tilt > 0.2, "ants tilt along slopes (max %.2f rad)" % max_tilt)
	_check(wall_climbs > 0, "ants climb walls with a visible tilt (%d climbs)" % wall_climbs)
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)
